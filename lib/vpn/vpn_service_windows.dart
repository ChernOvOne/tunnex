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
      await stop();
      // Wait for port
      final port = mode == WindowsVpnMode.tun
          ? XrayConfigWindows.socksPort : XrayConfigWindows.httpPort;
      for (int i = 0; i < 10; i++) {
        try {
          final s = await ServerSocket.bind('127.0.0.1', port);
          await s.close(); break;
        } catch (_) { await Future.delayed(const Duration(milliseconds: 500)); }
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

      // Wait for xray
      for (int i = 0; i < 10; i++) {
        try {
          final s = await Socket.connect('127.0.0.1', port, timeout: const Duration(milliseconds: 500));
          s.destroy(); break;
        } catch (_) { await Future.delayed(const Duration(milliseconds: 500)); }
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

    log.writeln('[TUN] Starting tun2socks directly (admin mode)...');

    // Start tun2socks directly — works because app is admin
    _tunProcess = await Process.start(tun2socks, [
      '-device', 'tun://tunnex',
      '-proxy', 'socks5://tunnex:tunnex@127.0.0.1:${XrayConfigWindows.socksPort}',
    ], workingDirectory: workDir);

    _tunProcess!.stderr.transform(utf8.decoder).listen((l) {
      log.writeln('[tun2socks] $l');
      debugPrint('tun2socks: $l');
    });

    _tunProcess!.exitCode.then((code) {
      debugPrint('tun2socks DIED with code $code');
    });

    // Wait for adapter
    for (int i = 0; i < 15; i++) {
      await Future.delayed(const Duration(seconds: 1));
      final check = await Process.run('netsh', ['interface', 'show', 'interface']);
      if ((check.stdout as String).contains('tunnex')) {
        log.writeln('[TUN] Adapter found after ${i + 1}s');

        // Get default gateway before changing routes
        final gwResult = await Process.run('powershell', ['-Command',
          '(Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Sort-Object RouteMetric | Select-Object -First 1).NextHop']);
        final defaultGw = (gwResult.stdout as String).trim();
        log.writeln('[TUN] Default gateway: $defaultGw');

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
        return;
      }
      log.writeln('[TUN] Check ${i + 1}/15: waiting...');
    }
    log.writeln('[TUN] FAILED — run app as Administrator');
    throw Exception('TUN failed — run as Administrator');
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
