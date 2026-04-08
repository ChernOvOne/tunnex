import '../model/server_config.dart';
import 'xray_config.dart';

enum WindowsVpnMode { systemProxy, tun }

/// Windows-specific xray config with TUN or System Proxy mode
class XrayConfigWindows {
  XrayConfigWindows._();

  static const int httpPort = 10809;
  static const int socksPort = 10808;
  static const int apiPort = 10813;

  static Map<String, dynamic> generate({
    required ServerConfig server,
    String dnsServer = '8.8.8.8',
    WindowsVpnMode mode = WindowsVpnMode.tun,
  }) {
    final config = XrayConfig.generate(server: server, dnsServer: dnsServer);

    if (mode == WindowsVpnMode.tun) {
      config['inbounds'] = [
        {
          'tag': 'tun-in',
          'port': 0,
          'protocol': 'tun',
          'settings': {
            'name': 'tunnex-tun',
            'mtu': 1500,
            'userLevel': 0,
          },
          'sniffing': {
            'enabled': true,
            'destOverride': ['http', 'tls'],
          },
        },
      ];
    } else {
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
    }

    // API for traffic stats (localhost only, with tag for routing)
    config['api'] = {
      'tag': 'api',
      'services': ['StatsService'],
    };

    // Add API routing rule
    final routing = config['routing'] as Map<String, dynamic>;
    final rules = routing['rules'] as List;
    rules.insert(0, {
      'type': 'field',
      'inboundTag': ['api'],
      'outboundTag': 'api',
    });

    // API inbound (dokodemo-door on localhost)
    (config['inbounds'] as List).add({
      'tag': 'api-in',
      'port': apiPort,
      'listen': '127.0.0.1',
      'protocol': 'dokodemo-door',
      'settings': {'address': '127.0.0.1'},
    });

    // API outbound
    (config['outbounds'] as List).add({
      'tag': 'api',
      'protocol': 'blackhole',
    });

    return config;
  }

  static String _generateSessionPassword() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'tx${now.toRadixString(36)}';
  }
}
