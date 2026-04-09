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
    String splitMode = 'all',
    List<String> vpnDomains = const [],
    List<String> vpnApps = const [],
    String realInterface = 'Ethernet',
  }) {
    final config = XrayConfig.generate(server: server, dnsServer: dnsServer);

    // Split tunnel with FakeDNS (works in TUN mode!)
    if (splitMode == 'selected' && vpnDomains.isNotEmpty) {
      // FakeDNS: xray assigns fake IPs to domains, routes by IP range
      config['dns'] = {
        'servers': [
          // FakeDNS for selected domains → fake IP pool
          {
            'address': 'fakedns',
            'tag': 'fakedns',
            'domains': vpnDomains.map((d) => 'domain:$d').toList(),
          },
          // Real DNS for everything else
          {'address': '8.8.8.8', 'tag': 'real-dns'},
        ],
        'queryStrategy': 'UseIP',
      };

      final routing = config['routing'] as Map<String, dynamic>;
      routing['domainStrategy'] = 'IPIfNonMatch';
      routing['rules'] = [
        // API
        {'type': 'field', 'inboundTag': ['api'], 'outboundTag': 'api'},
        // FakeDNS IPs (198.18.0.0/15) → proxy (these are VPN domains)
        {'type': 'field', 'outboundTag': 'proxy', 'ip': ['198.18.0.0/15']},
        // Selected domains by name → proxy
        {'type': 'field', 'outboundTag': 'proxy',
          'domain': vpnDomains.map((d) => 'domain:$d').toList()},
        // Private IPs → direct
        {'type': 'field', 'outboundTag': 'direct', 'ip': ['geoip:private']},
      ];

      // Default outbound = direct via REAL interface (bypass TUN!)
      final outbounds = config['outbounds'] as List;
      final directIdx = outbounds.indexWhere((o) => o['tag'] == 'direct');
      if (directIdx >= 0) {
        // Bind direct outbound to real network interface (not TUN)
        outbounds[directIdx] = {
          'tag': 'direct',
          'protocol': 'freedom',
          'settings': {'domainStrategy': 'UseIP'},
          'streamSettings': {
            'sockopt': {
              'interface': realInterface,
              'tcpKeepAliveInterval': 30,
            },
          },
        };
        // Move direct to first position (default)
        if (directIdx > 0) {
          final direct = outbounds.removeAt(directIdx);
          outbounds.insert(0, direct);
        }
      }

      // Sniffing must be enabled on TUN inbound for FakeDNS
      final inbounds = config['inbounds'] as List;
      for (final inbound in inbounds) {
        if (inbound is Map && inbound['tag'] != 'api-in') {
          inbound['sniffing'] = {
            'enabled': true,
            'destOverride': ['http', 'tls', 'fakedns'],
            'metadataOnly': false,
          };
        }
      }
    }

    // Session password for SOCKS auth
    final sessPass = _generateSessionPassword();

    if (mode == WindowsVpnMode.tun) {
      // TUN: xray provides SOCKS, tun2socks bridges TUN→SOCKS
      config['inbounds'] = [
        {
          'tag': 'socks-in',
          'port': socksPort,
          'listen': '127.0.0.1',
          'protocol': 'socks',
          'settings': {
            'auth': 'password',
            'accounts': [
              {'user': 'tunnex', 'pass': 'tunnex'},
            ],
            'udp': true,
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
