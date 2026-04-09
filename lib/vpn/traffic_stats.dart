import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'vpn_service.dart';

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
        stats = await _getWindowsStats();
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

  int _lastWinUp = 0;
  int _lastWinDown = 0;

  Future<Map<String, int>> _getWindowsStats() async {
    try {
      // Use Windows network adapter statistics (much more reliable than xray API)
      final result = await Process.run('powershell', ['-Command',
        "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; "
        "Get-NetAdapterStatistics -Name 'tunnex*' -ErrorAction SilentlyContinue | "
        "Select-Object ReceivedBytes, SentBytes -First 1 | ConvertTo-Json"
      ]).timeout(const Duration(seconds: 3));

      if (result.exitCode != 0) return {'up': 0, 'down': 0};

      final json = (result.stdout as String).trim();
      if (json.isEmpty || !json.startsWith('{')) {
        // No TUN adapter stats — try Proxy mode (system network)
        return {'up': 0, 'down': 0};
      }

      final data = Map<String, dynamic>.from(
          const JsonDecoder().convert(json) as Map);
      final curUp = (data['SentBytes'] as int?) ?? 0;
      final curDown = (data['ReceivedBytes'] as int?) ?? 0;

      // Calculate delta
      final deltaUp = curUp > _lastWinUp ? curUp - _lastWinUp : 0;
      final deltaDown = curDown > _lastWinDown ? curDown - _lastWinDown : 0;
      _lastWinUp = curUp;
      _lastWinDown = curDown;

      return {'up': deltaUp, 'down': deltaDown};
    } catch (_) {
      return {'up': 0, 'down': 0};
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
