import '../model/server_config.dart';
import '../model/protocol.dart';

/// Generates sing-box JSON config from ServerConfig
class SingboxConfig {
  SingboxConfig._();

  static Map<String, dynamic> generate({
    required ServerConfig server,
    List<String> includePackages = const [],
    List<String> excludePackages = const [],
    bool bypassMode = true,
    String dnsServer = 'https://dns.google/dns-query',
  }) {
    return {
      'log': {
        'level': 'warn',
        'timestamp': true,
      },
      'dns': _buildDns(dnsServer),
      'inbounds': [
        _buildTunInbound(
          includePackages: includePackages,
          excludePackages: excludePackages,
          bypassMode: bypassMode,
        ),
      ],
      'outbounds': [
        _buildOutbound(server),
        {'type': 'direct', 'tag': 'direct'},
        {'type': 'dns', 'tag': 'dns-out'},
        {'type': 'block', 'tag': 'block'},
      ],
      'route': _buildRoute(),
    };
  }

  static Map<String, dynamic> generateUrlTest({
    required List<ServerConfig> servers,
    List<String> includePackages = const [],
    List<String> excludePackages = const [],
    bool bypassMode = true,
    String dnsServer = 'https://dns.google/dns-query',
  }) {
    final outbounds = <Map<String, dynamic>>[];
    final tags = <String>[];

    for (int i = 0; i < servers.length; i++) {
      final ob = _buildOutbound(servers[i]);
      ob['tag'] = 'proxy-$i';
      outbounds.add(ob);
      tags.add('proxy-$i');
    }

    final urlTest = {
      'type': 'urltest',
      'tag': 'auto',
      'outbounds': tags,
      'url': 'https://www.gstatic.com/generate_204',
      'interval': '3m',
      'tolerance': 50,
    };

    return {
      'log': {
        'level': 'warn',
        'timestamp': true,
      },
      'dns': _buildDns(dnsServer),
      'inbounds': [
        _buildTunInbound(
          includePackages: includePackages,
          excludePackages: excludePackages,
          bypassMode: bypassMode,
        ),
      ],
      'outbounds': [
        urlTest,
        ...outbounds,
        {'type': 'direct', 'tag': 'direct'},
        {'type': 'dns', 'tag': 'dns-out'},
        {'type': 'block', 'tag': 'block'},
      ],
      'route': _buildRoute(defaultOutbound: 'auto'),
    };
  }

  static Map<String, dynamic> _buildDns(String dnsServer) {
    final needsResolver = dnsServer.startsWith('https://') ||
        dnsServer.startsWith('tls://') ||
        dnsServer.startsWith('quic://');

    final servers = <Map<String, dynamic>>[
      {
        'tag': 'remote-dns',
        'address': dnsServer,
        'detour': 'proxy',
        if (needsResolver) 'address_resolver': 'bootstrap-dns',
      },
      {
        'tag': 'direct-dns',
        'address': '8.8.8.8',
        'detour': 'direct',
      },
      if (needsResolver)
        {
          'tag': 'bootstrap-dns',
          'address': '8.8.8.8',
          'detour': 'direct',
        },
    ];

    return {
      'servers': servers,
      'rules': [
        {
          'outbound': ['any'],
          'server': 'direct-dns',
        },
      ],
      'strategy': 'prefer_ipv4',
    };
  }

  static Map<String, dynamic> _buildTunInbound({
    List<String> includePackages = const [],
    List<String> excludePackages = const [],
    bool bypassMode = true,
  }) {
    final tun = <String, dynamic>{
      'type': 'tun',
      'tag': 'tun-in',
      'address': ['172.19.0.1/30', 'fdfe:dcba:9876::1/126'],
      'mtu': 9000,
      'auto_route': true,
      'strict_route': true,
      'stack': 'system',
    };

    if (bypassMode && includePackages.isNotEmpty) {
      tun['include_package'] = includePackages;
    } else if (!bypassMode && excludePackages.isNotEmpty) {
      tun['exclude_package'] = excludePackages;
    }

    return tun;
  }

  static Map<String, dynamic> _buildOutbound(ServerConfig server) {
    switch (server.protocol) {
      case Protocol.vless:
        return _buildVless(server);
      case Protocol.vmess:
        return _buildVmess(server);
      case Protocol.trojan:
        return _buildTrojan(server);
      case Protocol.shadowsocks:
        return _buildShadowsocks(server);
    }
  }

  static Map<String, dynamic> _buildVless(ServerConfig s) {
    final ob = <String, dynamic>{
      'type': 'vless',
      'tag': 'proxy',
      'server': s.address,
      'server_port': s.port,
      'uuid': s.uuid,
    };

    if (s.flow.isNotEmpty) ob['flow'] = s.flow;
    ob['packet_encoding'] = 'xudp';

    _applyTransport(ob, s);
    _applyTls(ob, s);

    return ob;
  }

  static Map<String, dynamic> _buildVmess(ServerConfig s) {
    final ob = <String, dynamic>{
      'type': 'vmess',
      'tag': 'proxy',
      'server': s.address,
      'server_port': s.port,
      'uuid': s.uuid,
      'security': s.encryption.isEmpty ? 'auto' : s.encryption,
      'alter_id': 0,
    };

    _applyTransport(ob, s);
    _applyTls(ob, s);

    return ob;
  }

  static Map<String, dynamic> _buildTrojan(ServerConfig s) {
    final ob = <String, dynamic>{
      'type': 'trojan',
      'tag': 'proxy',
      'server': s.address,
      'server_port': s.port,
      'password': s.uuid,
    };

    _applyTransport(ob, s);
    _applyTls(ob, s);

    return ob;
  }

  static Map<String, dynamic> _buildShadowsocks(ServerConfig s) {
    return {
      'type': 'shadowsocks',
      'tag': 'proxy',
      'server': s.address,
      'server_port': s.port,
      'method': s.method,
      'password': s.uuid,
    };
  }

  static void _applyTransport(Map<String, dynamic> ob, ServerConfig s) {
    if (s.network == 'tcp' || s.network.isEmpty) return;

    final transport = <String, dynamic>{};

    switch (s.network) {
      case 'ws':
        transport['type'] = 'ws';
        if (s.path.isNotEmpty) transport['path'] = s.path;
        if (s.host.isNotEmpty) {
          transport['headers'] = {'Host': s.host};
        }
        break;
      case 'grpc':
        transport['type'] = 'grpc';
        if (s.path.isNotEmpty) transport['service_name'] = s.path;
        break;
      case 'http':
      case 'h2':
        transport['type'] = 'http';
        if (s.path.isNotEmpty) transport['path'] = s.path;
        if (s.host.isNotEmpty) transport['host'] = [s.host];
        break;
      case 'httpupgrade':
        transport['type'] = 'httpupgrade';
        if (s.path.isNotEmpty) transport['path'] = s.path;
        if (s.host.isNotEmpty) transport['host'] = s.host;
        break;
      case 'quic':
        transport['type'] = 'quic';
        break;
    }

    if (transport.isNotEmpty) {
      ob['transport'] = transport;
    }
  }

  static void _applyTls(Map<String, dynamic> ob, ServerConfig s) {
    if (s.security != 'tls' && s.security != 'reality') return;

    final tls = <String, dynamic>{
      'enabled': true,
    };

    if (s.sni.isNotEmpty) tls['server_name'] = s.sni;

    if (s.fingerprint.isNotEmpty) {
      tls['utls'] = {
        'enabled': true,
        'fingerprint': s.fingerprint,
      };
    }

    if (s.alpn.isNotEmpty) {
      tls['alpn'] = s.alpn.split(',').map((a) => a.trim()).toList();
    }

    if (s.security == 'reality') {
      tls['reality'] = <String, dynamic>{
        'enabled': true,
      };
      if (s.publicKey.isNotEmpty) {
        tls['reality']['public_key'] = s.publicKey;
      }
      if (s.shortId.isNotEmpty) {
        tls['reality']['short_id'] = s.shortId;
      }
    }

    ob['tls'] = tls;
  }

  static Map<String, dynamic> _buildRoute({String defaultOutbound = 'proxy'}) {
    return {
      'rules': [
        {
          'protocol': 'dns',
          'outbound': 'dns-out',
        },
        {
          'ip_is_private': true,
          'outbound': 'direct',
        },
      ],
      'auto_detect_interface': true,
      'final': defaultOutbound,
    };
  }
}
