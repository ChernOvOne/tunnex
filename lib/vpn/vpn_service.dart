import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/xray_config_windows.dart';
import 'vpn_service_windows.dart';

enum VpnState { disconnected, connecting, connected, disconnecting }

/// Last VPN error for UI display
final vpnErrorProvider = StateProvider<String?>((ref) => null);

final vpnStateProvider =
    StateNotifierProvider<VpnStateNotifier, VpnState>((ref) {
  return VpnStateNotifier();
});

class VpnStateNotifier extends StateNotifier<VpnState> {
  String? _lastError;
  String? get lastError => _lastError;

  // Android
  static const _channel = MethodChannel('com.tunnex/vpn');
  static const _eventChannel = EventChannel('com.tunnex/vpn_state');
  StreamSubscription? _eventSub;

  // Windows
  final WindowsVpnService? _windowsService =
      Platform.isWindows ? WindowsVpnService() : null;

  VpnStateNotifier() : super(VpnState.disconnected) {
    if (Platform.isAndroid) {
      _listenToEvents();
      _syncState();
    }
  }

  void _listenToEvents() {
    _eventSub = _eventChannel.receiveBroadcastStream().listen((event) {
      state = _parseState(event as String?);
    });
  }

  Future<void> _syncState() async {
    try {
      final stateStr = await _channel.invokeMethod<String>('getState');
      state = _parseState(stateStr);
    } catch (_) {}
  }

  VpnState _parseState(String? s) {
    switch (s) {
      case 'connected': return VpnState.connected;
      case 'connecting': return VpnState.connecting;
      case 'disconnecting': return VpnState.disconnecting;
      default: return VpnState.disconnected;
    }
  }

  Future<void> connect(
    String configJson, {
    String core = 'xray',
    bool splitBypass = true,
    List<String> splitApps = const [],
    String serverName = '',
    String windowsMode = 'tun',
  }) async {
    state = VpnState.connecting;

    try {
      if (Platform.isWindows) {
        final mode = windowsMode == 'tun'
            ? WindowsVpnMode.tun
            : WindowsVpnMode.systemProxy;
        await _windowsService!.start(configJson,
            onStateChanged: (s) => state = _parseState(s),
            mode: mode);
      } else {
        // Request battery optimization exemption (first time)
        try { await _channel.invokeMethod('requestBatteryOptimization'); } catch (_) {}

        await _channel.invokeMethod('start', {
          'config': configJson,
          'core': core,
          'splitBypass': splitBypass,
          'splitApps': splitApps,
          'serverName': serverName,
        });
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('VPN error: $_lastError');
      state = VpnState.disconnected;
      rethrow;
    }
  }

  Future<void> disconnect() async {
    state = VpnState.disconnecting;
    try {
      if (Platform.isWindows) {
        await _windowsService!.stop();
        state = VpnState.disconnected;
      } else {
        await _channel.invokeMethod('stop');
      }
    } catch (_) {
      state = VpnState.disconnected;
    }
  }

  Future<bool> requestPermission() async {
    if (Platform.isWindows) return true; // No VPN permission on Windows
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }
}
