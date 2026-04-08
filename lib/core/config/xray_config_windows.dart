import '../model/server_config.dart';
import 'xray_config.dart';

/// Windows-specific xray config: uses HTTP proxy inbound instead of TUN
class XrayConfigWindows {
  XrayConfigWindows._();

  static const int httpPort = 10809;
  static const int socksPort = 10808;

  static Map<String, dynamic> generate({
    required ServerConfig server,
    String dnsServer = '8.8.8.8',
  }) {
    // Get base config from shared generator
    final config = XrayConfig.generate(server: server, dnsServer: dnsServer);

    // Replace inbounds: HTTP + SOCKS instead of TUN
    config['inbounds'] = [
      {
        'tag': 'http-in',
        'port': httpPort,
        'listen': '127.0.0.1',
        'protocol': 'http',
        'settings': {'allowTransparent': false},
        'sniffing': {
          'enabled': true,
          'destOverride': ['http', 'tls'],
        },
      },
      {
        'tag': 'socks-in',
        'port': socksPort,
        'listen': '127.0.0.1',
        'protocol': 'socks',
        'settings': {
          'auth': 'password',
          'accounts': [
            {'user': 'tunnex', 'pass': _generateSessionPassword()},
          ],
          'udp': true,
        },
        'sniffing': {
          'enabled': true,
          'destOverride': ['http', 'tls'],
        },
      },
    ];

    return config;
  }

  /// Random session password — changes each connection, prevents abuse
  static String _generateSessionPassword() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'tx${now.toRadixString(36)}';
  }
}
