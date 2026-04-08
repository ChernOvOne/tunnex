import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/config/xray_config_windows.dart';

class WindowsVpnService {
  Process? _xrayProcess;
  bool _proxyEnabled = false;
  WindowsVpnMode _mode = WindowsVpnMode.tun;

  Future<String> get _xrayPath async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      '$exeDir/xray/xray.exe',
      '$exeDir/data/flutter_assets/xray/xray.exe',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    throw Exception('xray.exe not found');
  }

  Future<String> get _xrayDir async {
    return File(await _xrayPath).parent.path;
  }

  Future<void> start(
    String configJson, {
    required void Function(String state) onStateChanged,
    WindowsVpnMode mode = WindowsVpnMode.tun,
  }) async {
    _mode = mode;
    onStateChanged('connecting');

    try {
      final appDir = await getApplicationSupportDirectory();
      final configFile = File('${appDir.path}/xray-config.json');
      await configFile.writeAsString(configJson);

      final xrayExe = await _xrayPath;
      final workDir = await _xrayDir;
      debugPrint('Starting xray ($mode): $xrayExe');

      if (mode == WindowsVpnMode.tun) {
        // TUN requires admin — use PowerShell elevation
        _xrayProcess = await Process.start(
          'powershell',
          [
            '-Command',
            'Start-Process',
            '-FilePath', '"$xrayExe"',
            '-ArgumentList', '"run -c ${configFile.path}"',
            '-Verb', 'RunAs',
            '-WindowStyle', 'Hidden',
            '-Wait',
          ],
          workingDirectory: workDir,
        );
      } else {
        _xrayProcess = await Process.start(
          xrayExe,
          ['run', '-c', configFile.path],
          workingDirectory: workDir,
        );
      }

      // Monitor output
      bool started = false;
      _xrayProcess!.stderr.transform(utf8.decoder).listen((line) {
        debugPrint('xray: $line');
        if (!started && (line.contains('started') || line.contains('Reading config'))) {
          started = true;
          if (mode == WindowsVpnMode.systemProxy) _enableSystemProxy();
          onStateChanged('connected');
        }
      });

      _xrayProcess!.stdout.transform(utf8.decoder).listen((line) {
        debugPrint('xray stdout: $line');
      });

      _xrayProcess!.exitCode.then((code) {
        debugPrint('xray exited: $code');
        if (mode == WindowsVpnMode.systemProxy) _disableSystemProxy();
        onStateChanged('disconnected');
      });

      // Timeout fallback
      Future.delayed(const Duration(seconds: 4), () {
        if (!started && _xrayProcess != null) {
          started = true;
          if (mode == WindowsVpnMode.systemProxy) _enableSystemProxy();
          onStateChanged('connected');
        }
      });
    } catch (e) {
      debugPrint('Failed to start xray: $e');
      onStateChanged('disconnected');
      rethrow;
    }
  }

  Future<void> stop() async {
    if (_mode == WindowsVpnMode.systemProxy) _disableSystemProxy();

    // Kill xray process
    _xrayProcess?.kill();
    _xrayProcess = null;

    // Also kill any orphaned xray.exe (TUN mode uses elevated process)
    try {
      await Process.run('taskkill', ['/F', '/IM', 'xray.exe']);
    } catch (_) {}
  }

  // --- System Proxy ---

  Future<void> _enableSystemProxy() async {
    if (_proxyEnabled) return;
    try {
      const regPath = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';
      await Process.run('reg', ['add', regPath, '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', '1', '/f']);
      await Process.run('reg', ['add', regPath, '/v', 'ProxyServer', '/t', 'REG_SZ', '/d', '127.0.0.1:${XrayConfigWindows.httpPort}', '/f']);
      await Process.run('reg', ['add', regPath, '/v', 'ProxyOverride', '/t', 'REG_SZ', '/d', 'localhost;127.*;10.*;192.168.*;<local>', '/f']);
      _proxyEnabled = true;
    } catch (e) {
      debugPrint('Failed to set proxy: $e');
    }
  }

  Future<void> _disableSystemProxy() async {
    if (!_proxyEnabled) return;
    try {
      const regPath = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';
      await Process.run('reg', ['add', regPath, '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', '0', '/f']);
      _proxyEnabled = false;
    } catch (e) {
      debugPrint('Failed to disable proxy: $e');
    }
  }

  // --- Traffic Stats via xray gRPC API ---

  Future<Map<String, int>> getStats() async {
    try {
      final result = await Process.run(
        await _xrayPath,
        ['api', 'statsquery', '-server=127.0.0.1:${XrayConfigWindows.apiPort}', '-pattern='],
        runInShell: false,
      ).timeout(const Duration(seconds: 2));

      if (result.exitCode != 0) return {'up': 0, 'down': 0};

      final output = result.stdout as String;
      int up = 0, down = 0;

      // Parse "stat: { name: "outbound>>>proxy>>>traffic>>>uplink" value: 12345 }"
      for (final line in output.split('\n')) {
        if (line.contains('uplink')) {
          final match = RegExp(r'value:\s*(\d+)').firstMatch(line);
          if (match != null) up += int.parse(match.group(1)!);
        } else if (line.contains('downlink')) {
          final match = RegExp(r'value:\s*(\d+)').firstMatch(line);
          if (match != null) down += int.parse(match.group(1)!);
        }
      }

      return {'up': up, 'down': down};
    } catch (_) {
      return {'up': 0, 'down': 0};
    }
  }
}
