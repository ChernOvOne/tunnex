import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

class AppPreferences {
  final SharedPreferences _prefs;

  AppPreferences(this._prefs);

  // Selected server
  String? get selectedServerId => _prefs.getString('selected_server_id');
  Future<void> setSelectedServerId(String? id) =>
      id != null ? _prefs.setString('selected_server_id', id) : _prefs.remove('selected_server_id');

  // Selected subscription
  String? get selectedSubscriptionId => _prefs.getString('selected_subscription_id');
  Future<void> setSelectedSubscriptionId(String? id) =>
      id != null ? _prefs.setString('selected_subscription_id', id) : _prefs.remove('selected_subscription_id');

  // Split tunnel mode: true = protect all (bypass), false = only selected
  bool get splitTunnelBypassMode => _prefs.getBool('split_tunnel_bypass') ?? true;
  Future<void> setSplitTunnelBypassMode(bool value) =>
      _prefs.setBool('split_tunnel_bypass', value);

  // Split tunnel apps
  List<String> get splitTunnelApps =>
      _prefs.getStringList('split_tunnel_apps') ?? defaultSplitApps;
  Future<void> setSplitTunnelApps(List<String> apps) =>
      _prefs.setStringList('split_tunnel_apps', apps);

  // DNS
  String get dnsServer => _prefs.getString('dns_server') ?? 'https://dns.google/dns-query';
  Future<void> setDnsServer(String dns) =>
      _prefs.setString('dns_server', dns);

  // Auto-connect on boot
  bool get autoConnect => _prefs.getBool('auto_connect') ?? false;
  Future<void> setAutoConnect(bool value) =>
      _prefs.setBool('auto_connect', value);

  // Was connected (for boot restore)
  bool get wasConnected => _prefs.getBool('was_connected') ?? false;
  Future<void> setWasConnected(bool value) =>
      _prefs.setBool('was_connected', value);

  // VPN core: 'xray' (singbox disabled — Go runtime conflict with dual AAR)
  String get vpnCore => 'xray';

  // Ping method: tcp, httpGet, httpHead, tlsHandshake
  String get pingMethod => _prefs.getString('ping_method') ?? 'tcp';
  Future<void> setPingMethod(String method) =>
      _prefs.setString('ping_method', method);

  static const List<String> defaultSplitApps = [
    'com.google.android.youtube',
    'com.instagram.android',
    'com.twitter.android',
    'com.twitter.android.lite',
    'org.telegram.messenger',
    'org.telegram.messenger.web',
    'com.whatsapp',
    'com.viber.voip',
    'com.zhiliaoapp.musically',
    'com.ss.android.ugc.trill',
    'com.roblox.client',
  ];
}

final appPreferencesProvider = Provider<AppPreferences>((ref) {
  return AppPreferences(ref.watch(sharedPreferencesProvider));
});
