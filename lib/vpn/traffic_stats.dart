import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'vpn_service.dart';

class TrafficStats {
  final int uploadSpeed; // bytes per second (delta)
  final int downloadSpeed;
  final int totalUpload; // session total bytes
  final int totalDownload;

  const TrafficStats({
    this.uploadSpeed = 0,
    this.downloadSpeed = 0,
    this.totalUpload = 0,
    this.totalDownload = 0,
  });
}

final trafficStatsProvider =
    StateNotifierProvider<TrafficStatsNotifier, TrafficStats>((ref) {
  final notifier = TrafficStatsNotifier();

  // Start/stop polling based on VPN state
  final sub = ref.listen(vpnStateProvider, (prev, next) {
    if (next == VpnState.connected) {
      notifier.startPolling();
    } else if (next == VpnState.disconnected) {
      notifier.stopPolling();
    }
  });

  // Also check current state at creation
  final currentState = ref.read(vpnStateProvider);
  if (currentState == VpnState.connected) {
    notifier.startPolling();
  }

  ref.onDispose(() {
    notifier.stopPolling();
  });

  return notifier;
});

class TrafficStatsNotifier extends StateNotifier<TrafficStats> {
  static const _channel = MethodChannel('com.tunnex/vpn');
  Timer? _timer;
  int _totalUp = 0;
  int _totalDown = 0;

  TrafficStatsNotifier() : super(const TrafficStats());

  void startPolling() {
    _totalUp = 0;
    _totalDown = 0;
    state = const TrafficStats();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('getStats');
      if (result != null) {
        final up = (result['up'] as int?) ?? 0;
        final down = (result['down'] as int?) ?? 0;
        _totalUp += up;
        _totalDown += down;
        state = TrafficStats(
          uploadSpeed: up,
          downloadSpeed: down,
          totalUpload: _totalUp,
          totalDownload: _totalDown,
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
