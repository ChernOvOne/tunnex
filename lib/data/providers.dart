import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/singbox_config.dart';
import '../core/config/xray_config_windows.dart';
import '../core/config/xray_config.dart';
import '../core/model/server_config.dart';
import '../core/model/subscription.dart';
import '../core/subscription/hwid_helper.dart';
import '../core/subscription/subscription_fetcher.dart';
import 'preferences/app_preferences.dart';
import 'repository/server_repository.dart';
import 'repository/subscription_repository.dart';

// --- Subscriptions ---

final subscriptionsProvider =
    StateNotifierProvider<SubscriptionsNotifier, List<Subscription>>((ref) {
  return SubscriptionsNotifier(ref);
});

class SubscriptionsNotifier extends StateNotifier<List<Subscription>> {
  final Ref _ref;
  final _fetcher = SubscriptionFetcher();

  SubscriptionsNotifier(this._ref) : super([]) {
    _load().then((_) => _autoRefresh());
  }

  Future<void> _load() async {
    final repo = _ref.read(subscriptionRepositoryProvider);
    state = await repo.getAll();
  }

  /// Auto-refresh all subscriptions on app start
  Future<void> _autoRefresh() async {
    for (final sub in state) {
      await refresh(sub.id);
    }
  }

  Future<String?> add(String url) async {
    final repo = _ref.read(subscriptionRepositoryProvider);
    // Check duplicate
    final existing = await repo.getByUrl(url);
    if (existing != null) return 'Подписка уже добавлена';

    final sub = Subscription.create(url: url);
    await repo.add(sub);
    state = await repo.getAll();

    // Auto-fetch
    await refresh(sub.id);
    return null;
  }

  Future<SubscriptionResult?> refresh(String subscriptionId) async {
    final repo = _ref.read(subscriptionRepositoryProvider);
    final serverRepo = _ref.read(serverRepositoryProvider);
    final sub = await repo.getById(subscriptionId);
    if (sub == null) return null;

    try {
      final result = await _fetcher.fetch(
        subscription: sub,
        hwid: await HwidHelper.getHwid(),
        deviceModel: await HwidHelper.getDeviceModel(),
        osVersion: await HwidHelper.getOsVersion(),
      );

      await repo.update(result.subscription);
      await serverRepo.replaceForSubscription(subscriptionId, result.servers);

      state = await repo.getAll();
      _ref.invalidate(serversProvider);

      return result;
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String id) async {
    final repo = _ref.read(subscriptionRepositoryProvider);
    final serverRepo = _ref.read(serverRepositoryProvider);
    await repo.remove(id);
    await serverRepo.removeBySubscription(id);
    state = await repo.getAll();
    _ref.invalidate(serversProvider);
  }
}

// --- Servers ---

final serversProvider =
    StateNotifierProvider<ServersNotifier, List<ServerConfig>>((ref) {
  return ServersNotifier(ref);
});

class ServersNotifier extends StateNotifier<List<ServerConfig>> {
  final Ref _ref;

  ServersNotifier(this._ref) : super([]) {
    _load();
  }

  Future<void> _load() async {
    final repo = _ref.read(serverRepositoryProvider);
    state = await repo.getAll();
  }

  Future<void> reload() async {
    await _load();
  }
}

// --- Selected subscription ---

final selectedSubscriptionIdProvider =
    StateProvider<String?>((ref) {
  return ref.read(appPreferencesProvider).selectedSubscriptionId;
});

// --- Selected server ---

final selectedServerIdProvider = StateProvider<String?>((ref) {
  return ref.read(appPreferencesProvider).selectedServerId;
});

// --- Filtered servers (by active subscription) ---

final filteredServersProvider = Provider<List<ServerConfig>>((ref) {
  final subId = ref.watch(selectedSubscriptionIdProvider);
  final allServers = ref.watch(serversProvider);
  if (subId == null) return allServers;
  return allServers.where((s) => s.subscriptionId == subId).toList();
});

// --- Selected server object ---

final selectedServerProvider = Provider<ServerConfig?>((ref) {
  final id = ref.watch(selectedServerIdProvider);
  if (id == null) return null;
  final servers = ref.watch(serversProvider);
  try {
    return servers.firstWhere((s) => s.id == id);
  } catch (_) {
    return null;
  }
});

// --- Active subscription object ---

final activeSubscriptionProvider = Provider<Subscription?>((ref) {
  final id = ref.watch(selectedSubscriptionIdProvider);
  if (id == null) return null;
  final subs = ref.watch(subscriptionsProvider);
  try {
    return subs.firstWhere((s) => s.id == id);
  } catch (_) {
    return null;
  }
});

// --- Generate VPN config ---

final vpnConfigProvider = Provider<Map<String, String>?>((ref) {
  final server = ref.watch(selectedServerProvider);
  if (server == null) return null;

  final prefs = ref.read(appPreferencesProvider);
  final core = prefs.vpnCore; // 'xray' or 'singbox'

  final Map<String, dynamic> config;
  if (Platform.isWindows) {
    final winMode = prefs.windowsVpnMode == 'tun'
        ? WindowsVpnMode.tun
        : WindowsVpnMode.systemProxy;
    config = XrayConfigWindows.generate(
      server: server,
      dnsServer: prefs.dnsServer,
      mode: winMode,
    );
  } else if (core == 'singbox') {
    config = SingboxConfig.generate(
      server: server,
      includePackages: prefs.splitTunnelApps,
      bypassMode: prefs.splitTunnelBypassMode,
      dnsServer: prefs.dnsServer,
    );
  } else {
    config = XrayConfig.generate(
      server: server,
      dnsServer: prefs.dnsServer,
    );
  }

  return {'core': core, 'config': jsonEncode(config)};
});
