import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum VpnState { disconnected, connecting, connected, disconnecting }

final vpnStateProvider =
    StateNotifierProvider<VpnStateNotifier, VpnState>((ref) {
  return VpnStateNotifier();
});

class VpnStateNotifier extends StateNotifier<VpnState> {
  static const _channel = MethodChannel('com.tunnex/vpn');
  static const _eventChannel = EventChannel('com.tunnex/vpn_state');

  StreamSubscription? _eventSub;

  VpnStateNotifier() : super(VpnState.disconnected) {
    _listenToEvents();
    _syncState();
  }

  void _listenToEvents() {
    _eventSub = _eventChannel.receiveBroadcastStream().listen((event) {
      final stateStr = event as String?;
      state = _parseState(stateStr);
    });
  }

  Future<void> _syncState() async {
    try {
      final stateStr = await _channel.invokeMethod<String>('getState');
      state = _parseState(stateStr);
    } catch (_) {}
  }

  VpnState _parseState(String? stateStr) {
    switch (stateStr) {
      case 'connected':
        return VpnState.connected;
      case 'connecting':
        return VpnState.connecting;
      case 'disconnecting':
        return VpnState.disconnecting;
      default:
        return VpnState.disconnected;
    }
  }

  Future<void> connect(
    String configJson, {
    String core = 'xray',
    bool splitBypass = true,
    List<String> splitApps = const [],
  }) async {
    state = VpnState.connecting;
    try {
      await _channel.invokeMethod('start', {
        'config': configJson,
        'core': core,
        'splitBypass': splitBypass,
        'splitApps': splitApps,
      });
    } catch (e) {
      state = VpnState.disconnected;
      rethrow;
    }
  }

  Future<void> disconnect() async {
    state = VpnState.disconnecting;
    try {
      await _channel.invokeMethod('stop');
      // State will be updated via EventChannel
    } catch (_) {
      state = VpnState.disconnected;
    }
  }

  Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermission');
      return result ?? false;
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
