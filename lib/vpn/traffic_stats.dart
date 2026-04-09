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
    // Windows: 3s interval (PowerShell is heavy), Android: 1s
    final interval = Platform.isWindows ? 3 : 1;
    _timer = Timer.periodic(Duration(seconds: interval), (_) => _poll());
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
      // Use netsh (lightweight, no PowerShell overhead)
      final result = await Process.run('netsh', [
        'interface', 'ip', 'show', 'interface', 'tunnex'
      ]).timeout(const Duration(seconds: 2));

      if (result.exitCode != 0) {
        // Try with wildcard name
        final r2 = await Process.run('netstat', ['-e']).timeout(const Duration(seconds: 2));
        if (r2.exitCode == 0) {
          // Parse netstat -e for total bytes
          final lines = (r2.stdout as String).split('\n');
          for (final line in lines) {
            if (line.contains('Bytes') || line.contains('Байт')) {
              final nums = RegExp(r'(\d+)').allMatches(line).map((m) => int.parse(m.group(0)!)).toList();
              if (nums.length >= 2) {
                final curDown = nums[0];
                final curUp = nums[1];
                final deltaUp = curUp > _lastWinUp ? curUp - _lastWinUp : 0;
                final deltaDown = curDown > _lastWinDown ? curDown - _lastWinDown : 0;
                _lastWinUp = curUp;
                _lastWinDown = curDown;
                // Scale to per-second (interval is 3s)
                return {'up': deltaUp ~/ 3, 'down': deltaDown ~/ 3};
              }
            }
          }
        }
        return {'up': 0, 'down': 0};
      }

      // Parse interface stats
      final output = result.stdout as String;
      final bytesIn = RegExp(r'(?:Bytes In|Входящие байты)[^\d]*(\d+)').firstMatch(output);
      final bytesOut = RegExp(r'(?:Bytes Out|Исходящие байты)[^\d]*(\d+)').firstMatch(output);

      final curDown = bytesIn != null ? int.parse(bytesIn.group(1)!) : 0;
      final curUp = bytesOut != null ? int.parse(bytesOut.group(1)!) : 0;

      final deltaUp = curUp > _lastWinUp ? curUp - _lastWinUp : 0;
      final deltaDown = curDown > _lastWinDown ? curDown - _lastWinDown : 0;
      _lastWinUp = curUp;
      _lastWinDown = curDown;

      return {'up': deltaUp ~/ 3, 'down': deltaDown ~/ 3};
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
