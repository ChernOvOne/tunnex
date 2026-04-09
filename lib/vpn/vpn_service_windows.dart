import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/config/xray_config_windows.dart';

class WindowsVpnService {
  Process? _xrayProcess;
  Process? _tunProcess;
  bool _proxyEnabled = false;
  WindowsVpnMode _mode = WindowsVpnMode.systemProxy;
  bool _stopping = false;
  String? _lastServerIp;
  String? _defaultGateway;
  bool _tunAdapterReady = false; // Reuse existing adapter

  Future<String> get _xrayPath async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    for (final path in ['$exeDir/xray/tunnex-core.exe', '$exeDir/tunnex-core.exe', '$exeDir/xray/xray.exe']) {
      if (File(path).existsSync()) return path;
    }
    throw Exception('xray.exe not found');
  }

  Future<String> get _tun2socksPath async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    for (final path in [
      '$exeDir/xray/tun2socks-windows-amd64.exe',
      '$exeDir/tun2socks-windows-amd64.exe',
    ]) {
      if (File(path).existsSync()) return path;
    }
    throw Exception('tun2socks not found');
  }

  Future<String> get _xrayDir async => File(await _xrayPath).parent.path;

  Future<void> start(
    String configJson, {
    required void Function(String state) onStateChanged,
    WindowsVpnMode mode = WindowsVpnMode.systemProxy,
  }) async {
    _mode = mode;
    onStateChanged('connecting');

    try {
      _stopping = true;
      // Only kill xray on reconnect, keep tun2socks alive for TUN reuse
      _xrayProcess?.kill(); _xrayProcess = null;
      try { await Process.run('taskkill', ['/F', '/IM', 'tunnex-core.exe']); } catch (_) {}
      if (_mode == WindowsVpnMode.systemProxy) await _disableSystemProxy();
      // Remove old server route
      if (_lastServerIp != null) {
        await Process.run('route', ['delete', _lastServerIp!, 'mask', '255.255.255.255']).catchError((_){});
      }
      // Wait for port (max 2s, not 5s)
      final port = mode == WindowsVpnMode.tun
          ? XrayConfigWindows.socksPort : XrayConfigWindows.httpPort;
      for (int i = 0; i < 4; i++) {
        try {
          final s = await ServerSocket.bind('127.0.0.1', port);
          await s.close(); break;
        } catch (_) { await Future.delayed(const Duration(milliseconds: 300)); }
      }
      _stopping = false;

      final appDir = await getApplicationSupportDirectory();
      final configFile = File('${appDir.path}/xray-config.json');
      await configFile.writeAsString(configJson);
      final logFile = File('${appDir.path}/tunnex-vpn.log');
      final log = logFile.openWrite(mode: FileMode.write);
      log.writeln('=== ${DateTime.now()} mode=$mode ===');

      // Start xray
      final xrayExe = await _xrayPath;
      final workDir = await _xrayDir;
      _xrayProcess = await Process.start(xrayExe, ['run', '-c', configFile.path],
          workingDirectory: workDir);
      _xrayProcess!.stderr.transform(utf8.decoder).listen((l) => log.writeln('[xray] $l'));
      _xrayProcess!.exitCode.then((code) {
        if (!_stopping) {
          if (_mode == WindowsVpnMode.systemProxy) _disableSystemProxy();
          onStateChanged('disconnected');
        }
      });

      // Wait for xray (fast — 200ms intervals)
      for (int i = 0; i < 10; i++) {
        try {
          final s = await Socket.connect('127.0.0.1', port, timeout: const Duration(milliseconds: 300));
          s.destroy(); break;
        } catch (_) { await Future.delayed(const Duration(milliseconds: 200)); }
      }
      log.writeln('[app] xray started on port $port');

      if (mode == WindowsVpnMode.tun) {
        // Extract server IP from config to exclude from TUN
        final configMap = jsonDecode(configJson) as Map<String, dynamic>;
        String? serverIp;
        try {
          final outbounds = configMap['outbounds'] as List;
          final proxy = outbounds.firstWhere((o) => o['tag'] == 'proxy');
          final settings = proxy['settings'] as Map<String, dynamic>;
          if (settings.containsKey('vnext')) {
            serverIp = settings['vnext'][0]['address'];
          } else if (settings.containsKey('servers')) {
            serverIp = settings['servers'][0]['address'];
          }
        } catch (_) {}
        // Resolve domain to IP if needed
        if (serverIp != null && !RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(serverIp)) {
          try {
            final addresses = await InternetAddress.lookup(serverIp);
            if (addresses.isNotEmpty) {
              final resolved = addresses.first.address;
              log.writeln('[app] Resolved $serverIp → $resolved');
              serverIp = resolved;
            }
          } catch (e) {
            log.writeln('[app] DNS resolve failed: $e');
          }
        }
        log.writeln('[app] server IP: $serverIp');
        await _startTun(log, serverIp: serverIp);
      } else {
        await _enableSystemProxy();
        log.writeln('[app] proxy enabled');
      }
      await log.close();
      onStateChanged('connected');
    } catch (e) {
      debugPrint('Start failed: $e');
      _stopping = false;
      onStateChanged('disconnected');
    }
  }

  /// TUN mode — app must run as admin!
  Future<void> _startTun(IOSink log, {String? serverIp}) async {
    final tun2socks = await _tun2socksPath;
    final workDir = await _xrayDir;

    // Check if tun2socks already running with adapter
    if (_tunProcess != null && _tunAdapterReady) {
      log.writeln('[TUN] Reusing existing TUN adapter (fast reconnect)');
    } else {
      log.writeln('[TUN] Starting tun2socks...');

      _tunProcess = await Process.start(tun2socks, [
        '-device', 'tun://tunnex',
        '-proxy', 'socks5://tunnex:tunnex@127.0.0.1:${XrayConfigWindows.socksPort}',
        '-tcp-auto-tuning',
        '-mtu', '9000',
        '-loglevel', 'error',
      ], workingDirectory: workDir,
         environment: {'GOMAXPROCS': '2'}, // limit CPU cores for Go runtime
      );

      _tunProcess!.stderr.transform(utf8.decoder).listen((l) {
        log.writeln('[tun2socks] $l');
      });

      _tunProcess!.exitCode.then((code) {
        debugPrint('tun2socks exited: $code');
        _tunAdapterReady = false;
      });

      // Wait for adapter (fast — 200ms intervals)
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        final check = await Process.run('netsh', ['interface', 'show', 'interface']);
        if ((check.stdout as String).contains('tunnex')) {
          log.writeln('[TUN] Adapter ready in ${(i + 1) * 200}ms');
          _tunAdapterReady = true;
          break;
        }
      }
      if (!_tunAdapterReady) {
        log.writeln('[TUN] FAILED — adapter not created. Run as Administrator!');
        throw Exception('TUN adapter failed — run as Administrator');
      }
    }

    // Configure (fast — just update routes)
    {
      final check = await Process.run('netsh', ['interface', 'show', 'interface']);
      if ((check.stdout as String).contains('tunnex')) {
        log.writeln('[TUN] Configuring routes...');

        // Get default gateway (cache it)
        if (_defaultGateway == null || _defaultGateway!.isEmpty) {
          // Method 1: PowerShell Get-NetRoute
          final gwResult = await Process.run('powershell', ['-Command',
            '(Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Where-Object {\$_.NextHop -ne "0.0.0.0"} | Sort-Object RouteMetric | Select-Object -First 1).NextHop']);
          _defaultGateway = (gwResult.stdout as String).trim();

          // Method 2: ipconfig fallback
          if (_defaultGateway == null || _defaultGateway!.isEmpty || _defaultGateway == '::') {
            final ipcResult = await Process.run('ipconfig', []);
            final match = RegExp(r'(?:Default Gateway|Основной шлюз)[.\s]*:\s*([\d.]+)').firstMatch(ipcResult.stdout as String);
            if (match != null) _defaultGateway = match.group(1);
          }
        }
        final defaultGw = _defaultGateway!;
        log.writeln('[TUN] Gateway: $defaultGw');

        // Configure IP + routes
        await Process.run('netsh', ['interface', 'ip', 'set', 'address', 'name=tunnex', 'static', '10.0.0.2', '255.255.255.0', '10.0.0.1']);
        await Process.run('netsh', ['interface', 'ip', 'set', 'dns', 'name=tunnex', 'static', '8.8.8.8']);

        // CRITICAL: Route VPN server through REAL gateway (avoid loop!)
        if (serverIp != null && defaultGw.isNotEmpty) {
          await Process.run('route', ['add', serverIp, 'mask', '255.255.255.255', defaultGw, 'metric', '1']);
          _lastServerIp = serverIp;
          log.writeln('[TUN] Server route: $serverIp → $defaultGw');
        }

        // Route everything else through TUN
        await Process.run('route', ['add', '0.0.0.0', 'mask', '128.0.0.0', '10.0.0.1', 'metric', '3']);
        await Process.run('route', ['add', '128.0.0.0', 'mask', '128.0.0.0', '10.0.0.1', 'metric', '3']);

        log.writeln('[TUN] Routes configured');
        log.writeln('[TUN] SUCCESS');
      } else {
        log.writeln('[TUN] WARNING: adapter gone');
        _tunAdapterReady = false;
      }
    }
  }

  Future<void> stop() async {
    _stopping = true;
    if (_mode == WindowsVpnMode.systemProxy) {
      await _disableSystemProxy();
    } else {
      // Remove routes
      await Process.run('route', ['delete', '0.0.0.0', 'mask', '128.0.0.0']).catchError((_) {});
      await Process.run('route', ['delete', '128.0.0.0', 'mask', '128.0.0.0']).catchError((_) {});
      if (_lastServerIp != null) {
        await Process.run('route', ['delete', _lastServerIp!, 'mask', '255.255.255.255']).catchError((_) {});
        _lastServerIp = null;
      }
    }
    _tunProcess?.kill(); _tunProcess = null;
    _xrayProcess?.kill(); _xrayProcess = null;
    try { await Process.run('taskkill', ['/F', '/IM', 'tunnex-core.exe']); } catch (_) {}
    try { await Process.run('taskkill', ['/F', '/IM', 'tun2socks-windows-amd64.exe']); } catch (_) {}
    _stopping = false;
  }

  // --- System Proxy ---
  Future<void> _enableSystemProxy() async {
    if (_proxyEnabled) return;
    try {
      const reg = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';
      await Process.run('reg', ['add', reg, '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', '1', '/f']);
      await Process.run('reg', ['add', reg, '/v', 'ProxyServer', '/t', 'REG_SZ', '/d', '127.0.0.1:${XrayConfigWindows.httpPort}', '/f']);
      await Process.run('reg', ['add', reg, '/v', 'ProxyOverride', '/t', 'REG_SZ', '/d', 'localhost;127.*;10.*;192.168.*;<local>', '/f']);
      _proxyEnabled = true;
    } catch (_) {}
  }

  Future<void> _disableSystemProxy() async {
    if (!_proxyEnabled) return;
    try {
      const reg = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';
      await Process.run('reg', ['add', reg, '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', '0', '/f']);
    } catch (_) {}
    _proxyEnabled = false;
  }

  // --- Stats ---
  Future<Map<String, int>> getStats() async {
    try {
      final xrayExe = await _xrayPath;
      final result = await Process.run(xrayExe,
        ['api', 'statsquery', '-server=127.0.0.1:${XrayConfigWindows.apiPort}', '-pattern='],
      ).timeout(const Duration(seconds: 2));
      if (result.exitCode != 0) return {'up': 0, 'down': 0};
      int up = 0, down = 0;
      for (final line in (result.stdout as String).split('\n')) {
        final m = RegExp(r'value:\s*(\d+)').firstMatch(line);
        if (m != null) {
          if (line.contains('uplink')) up += int.parse(m.group(1)!);
          if (line.contains('downlink')) down += int.parse(m.group(1)!);
        }
      }
      return {'up': up, 'down': down};
    } catch (_) { return {'up': 0, 'down': 0}; }
  }
}
