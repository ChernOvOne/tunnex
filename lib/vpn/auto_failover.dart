import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/model/server_config.dart';
import '../core/ping/server_ping.dart';
import '../data/preferences/app_preferences.dart';
import '../data/providers.dart';
import '../data/repository/server_repository.dart';
import 'vpn_service.dart';

/// Event notification for UI
final failoverEventProvider = StateProvider<String?>((ref) => null);

final autoFailoverProvider = Provider<AutoFailover>((ref) {
  final failover = AutoFailover(ref);

  ref.listen(vpnStateProvider, (prev, next) {
    if (next == VpnState.connected) {
      failover.start();
    } else {
      failover.stop();
    }
  });

  ref.onDispose(() => failover.stop());
  return failover;
});

class AutoFailover {
  final Ref _ref;
  Timer? _timer;
  int _failCount = 0;
  static const _checkInterval = Duration(seconds: 30);
  static const _maxFails = 2;

  AutoFailover(this._ref);

  void start() {
    _failCount = 0;
    _timer?.cancel();
    _timer = Timer.periodic(_checkInterval, (_) => _check());
    debugPrint('AutoFailover: started');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    debugPrint('AutoFailover: stopped');
  }

  Future<void> _check() async {
    if (_ref.read(vpnStateProvider) != VpnState.connected) return;

    // Health check: try to connect to a known endpoint
    final alive = await _healthCheck();

    if (alive) {
      _failCount = 0;
      return;
    }

    _failCount++;
    debugPrint('AutoFailover: health check failed ($_failCount/$_maxFails)');
    _ref.read(failoverEventProvider.notifier).state =
        'Проверка соединения... ($_failCount/$_maxFails)';

    if (_failCount >= _maxFails) {
      _failCount = 0;
      _ref.read(failoverEventProvider.notifier).state =
          'Сервер недоступен. Переключаемся...';
      await _switchToNextServer();
    }
  }

  Future<bool> _healthCheck() async {
    try {
      final socket = await Socket.connect('1.1.1.1', 443,
          timeout: const Duration(seconds: 3));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _switchToNextServer() async {
    debugPrint('AutoFailover: switching server');

    final servers = _ref.read(filteredServersProvider);
    final currentId = _ref.read(selectedServerIdProvider);
    if (servers.length < 2) return;

    // Ping all except current
    final others = servers.where((s) => s.id != currentId).toList();
    final methodName = _ref.read(appPreferencesProvider).pingMethod;
    final method = PingMethod.values.firstWhere(
      (m) => m.name == methodName,
      orElse: () => PingMethod.tcp,
    );

    final results = await ServerPing.pingAll(others, method: method, timeoutMs: 2000);

    // Find best alive
    final alive = results.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    if (alive.isEmpty) {
      debugPrint('AutoFailover: no alive servers found');
      return;
    }

    final bestId = alive.first.key;
    final best = others.firstWhere((s) => s.id == bestId);
    final serverName = best.remarks.isNotEmpty ? best.remarks : best.address;
    debugPrint('AutoFailover: switching to $serverName (${alive.first.value}ms)');
    _ref.read(failoverEventProvider.notifier).state =
        'Переключено на $serverName (${alive.first.value}мс)';

    // Update selection
    _ref.read(selectedServerIdProvider.notifier).state = bestId;
    _ref.read(appPreferencesProvider).setSelectedServerId(bestId);

    // Reconnect
    final vpn = _ref.read(vpnStateProvider.notifier);
    await vpn.disconnect();
    await Future.delayed(const Duration(milliseconds: 500));

    final vpnData = _ref.read(vpnConfigProvider);
    if (vpnData != null) {
      final prefs = _ref.read(appPreferencesProvider);
      await vpn.connect(
        vpnData['config']!,
        core: vpnData['core']!,
        splitBypass: prefs.splitTunnelBypassMode,
        splitApps: prefs.splitTunnelApps,
        windowsMode: prefs.windowsVpnMode,
      );
    }
  }
}
