import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'vpn_service.dart';
import 'vpn_service_windows.dart';

class TrafficStats {
  final int uploadSpeed;
  final int downloadSpeed;
  final int totalUpload;
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

  ref.listen(vpnStateProvider, (prev, next) {
    if (next == VpnState.connected) {
      notifier.startPolling();
    } else if (next == VpnState.disconnected) {
      notifier.stopPolling();
    }
  });

  if (ref.read(vpnStateProvider) == VpnState.connected) {
    notifier.startPolling();
  }

  ref.onDispose(() => notifier.stopPolling());
  return notifier;
});

class TrafficStatsNotifier extends StateNotifier<TrafficStats> {
  static const _channel = MethodChannel('com.tunnex/vpn');
  final WindowsVpnService? _winService =
      Platform.isWindows ? WindowsVpnService() : null;

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
      Map<String, int> stats;

      if (Platform.isWindows) {
        stats = await _winService!.getStats();
      } else {
        final result =
            await _channel.invokeMapMethod<String, dynamic>('getStats');
        stats = {
          'up': (result?['up'] as int?) ?? 0,
          'down': (result?['down'] as int?) ?? 0,
        };
      }

      final up = stats['up'] ?? 0;
      final down = stats['down'] ?? 0;
      _totalUp += up;
      _totalDown += down;
      state = TrafficStats(
        uploadSpeed: up,
        downloadSpeed: down,
        totalUpload: _totalUp,
        totalDownload: _totalDown,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
