import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'vpn_service.dart';

/// Windows VPN service — runs xray.exe as subprocess + system proxy
class WindowsVpnService {
  Process? _xrayProcess;
  bool _proxyEnabled = false;

  /// Get path to xray.exe bundled with app
  Future<String> get _xrayPath async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    // Check in data/xray/ first (bundled), then in exe dir
    final candidates = [
      '$exeDir/data/flutter_assets/xray/xray.exe',
      '$exeDir/xray/xray.exe',
      '$exeDir/xray.exe',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    throw Exception('xray.exe not found');
  }

  Future<String> get _xrayDir async {
    final path = await _xrayPath;
    return File(path).parent.path;
  }

  Future<void> start(String configJson, {
    required void Function(String state) onStateChanged,
  }) async {
    onStateChanged('connecting');

    try {
      // Write config to temp file
      final appDir = await getApplicationSupportDirectory();
      final configFile = File('${appDir.path}/xray-config.json');
      await configFile.writeAsString(configJson);

      // Start xray process
      final xrayExe = await _xrayPath;
      debugPrint('Starting xray: $xrayExe');

      _xrayProcess = await Process.start(
        xrayExe,
        ['run', '-c', configFile.path],
        workingDirectory: await _xrayDir,
        mode: ProcessStartMode.normal,
      );

      // Monitor stdout for "started" message
      bool started = false;
      _xrayProcess!.stderr.transform(utf8.decoder).listen((line) {
        debugPrint('xray: $line');
        if (line.contains('started') && !started) {
          started = true;
          _enableSystemProxy();
          onStateChanged('connected');
        }
      });

      _xrayProcess!.exitCode.then((code) {
        debugPrint('xray exited with code $code');
        _disableSystemProxy();
        onStateChanged('disconnected');
      });

      // Timeout — if not started in 10s, assume started anyway
      Future.delayed(const Duration(seconds: 5), () {
        if (!started && _xrayProcess != null) {
          started = true;
          _enableSystemProxy();
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
    _disableSystemProxy();
    _xrayProcess?.kill();
    _xrayProcess = null;
  }

  /// Enable Windows system proxy via registry
  Future<void> _enableSystemProxy() async {
    if (_proxyEnabled) return;
    try {
      // Set HTTP proxy via reg
      await Process.run('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v', 'ProxyEnable',
        '/t', 'REG_DWORD',
        '/d', '1',
        '/f',
      ]);
      await Process.run('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v', 'ProxyServer',
        '/t', 'REG_SZ',
        '/d', '127.0.0.1:10809',
        '/f',
      ]);
      // Bypass for local addresses
      await Process.run('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v', 'ProxyOverride',
        '/t', 'REG_SZ',
        '/d', 'localhost;127.*;10.*;192.168.*;<local>',
        '/f',
      ]);
      _proxyEnabled = true;
      debugPrint('System proxy enabled: 127.0.0.1:10809');
    } catch (e) {
      debugPrint('Failed to set proxy: $e');
    }
  }

  /// Disable Windows system proxy
  Future<void> _disableSystemProxy() async {
    if (!_proxyEnabled) return;
    try {
      await Process.run('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v', 'ProxyEnable',
        '/t', 'REG_DWORD',
        '/d', '0',
        '/f',
      ]);
      _proxyEnabled = true;
      debugPrint('System proxy disabled');
    } catch (e) {
      debugPrint('Failed to disable proxy: $e');
    }
    _proxyEnabled = false;
  }

  /// Query xray stats (Windows uses API endpoint)
  Map<String, int> getStats() {
    // TODO: implement xray stats API for Windows
    return {'up': 0, 'down': 0};
  }
}
