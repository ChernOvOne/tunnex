import '../model/server_config.dart';
import '../model/protocol.dart';

/// Generates xray-core JSON config from ServerConfig
class XrayConfig {
  XrayConfig._();

  static Map<String, dynamic> generate({
    required ServerConfig server,
    String dnsServer = '8.8.8.8',
  }) {
    return {
      'log': {'loglevel': 'info'},
      'inbounds': [
        {
          'tag': 'tun',
          'port': 0,
          'protocol': 'tun',
          'settings': {
            'name': 'xray0',
            'mtu': 1500,
            'userLevel': 8,
          },
          'sniffing': {
            'enabled': true,
            'destOverride': ['http', 'tls'],
          },
        },
      ],
      'outbounds': [
        _buildOutbound(server),
        {'tag': 'direct', 'protocol': 'freedom'},
        {'tag': 'block', 'protocol': 'blackhole'},
      ],
      'dns': {
        'servers': [
          _plainDns(dnsServer),
          {'address': _plainDns(dnsServer), 'domains': ['geosite:geolocation-!cn']},
        ],
      },
      'routing': {
        'domainStrategy': 'AsIs',
        'rules': [
          {'type': 'field', 'outboundTag': 'direct', 'ip': ['geoip:private']},
        ],
      },
      'stats': {},
      'policy': {
        'system': {
          'statsOutboundUplink': true,
          'statsOutboundDownlink': true,
        },
      },
    };
  }

  /// Convert DoH/DoT to plain DNS IP for xray compatibility
  static String _plainDns(String dns) {
    if (dns.startsWith('https://dns.google')) return '8.8.8.8';
    if (dns.startsWith('https://cloudflare')) return '1.1.1.1';
    if (dns.startsWith('https://dns.quad9')) return '9.9.9.9';
    if (dns.startsWith('https://') || dns.startsWith('tls://')) return '8.8.8.8';
    return dns;
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
    final user = <String, dynamic>{
      'id': s.uuid,
      'encryption': s.encryption.isEmpty ? 'none' : s.encryption,
    };
    if (s.flow.isNotEmpty) user['flow'] = s.flow;

    return {
      'tag': 'proxy',
      'protocol': 'vless',
      'settings': {
        'vnext': [
          {
            'address': s.address,
            'port': s.port,
            'users': [user],
          },
        ],
      },
      'streamSettings': _buildStreamSettings(s),
    };
  }

  static Map<String, dynamic> _buildVmess(ServerConfig s) {
    return {
      'tag': 'proxy',
      'protocol': 'vmess',
      'settings': {
        'vnext': [
          {
            'address': s.address,
            'port': s.port,
            'users': [
              {
                'id': s.uuid,
                'alterId': 0,
                'security': s.encryption.isEmpty ? 'auto' : s.encryption,
              },
            ],
          },
        ],
      },
      'streamSettings': _buildStreamSettings(s),
    };
  }

  static Map<String, dynamic> _buildTrojan(ServerConfig s) {
    return {
      'tag': 'proxy',
      'protocol': 'trojan',
      'settings': {
        'servers': [
          {
            'address': s.address,
            'port': s.port,
            'password': s.uuid,
          },
        ],
      },
      'streamSettings': _buildStreamSettings(s),
    };
  }

  static Map<String, dynamic> _buildShadowsocks(ServerConfig s) {
    return {
      'tag': 'proxy',
      'protocol': 'shadowsocks',
      'settings': {
        'servers': [
          {
            'address': s.address,
            'port': s.port,
            'password': s.uuid,
            'method': s.method.isEmpty ? 'aes-256-gcm' : s.method,
          },
        ],
      },
      'streamSettings': _buildStreamSettings(s),
    };
  }

  static Map<String, dynamic> _buildStreamSettings(ServerConfig s) {
    final stream = <String, dynamic>{};

    // Network type (xhttp = splithttp in xray)
    String networkType = s.network.isEmpty ? 'tcp' : s.network;
    if (networkType == 'splithttp') networkType = 'xhttp';
    stream['network'] = networkType;

    // Transport settings
    switch (s.network) {
      case 'ws':
        final ws = <String, dynamic>{};
        if (s.path.isNotEmpty) ws['path'] = s.path;
        if (s.host.isNotEmpty) ws['headers'] = {'Host': s.host};
        stream['wsSettings'] = ws;
      case 'grpc':
        final grpc = <String, dynamic>{};
        if (s.path.isNotEmpty) grpc['serviceName'] = s.path;
        stream['grpcSettings'] = grpc;
      case 'xhttp' || 'splithttp':
        final xhttp = <String, dynamic>{};
        if (s.path.isNotEmpty) xhttp['path'] = s.path;
        if (s.host.isNotEmpty) xhttp['host'] = s.host;
        stream['xhttpSettings'] = xhttp;
      case 'h2' || 'http':
        final http = <String, dynamic>{};
        if (s.path.isNotEmpty) http['path'] = s.path;
        if (s.host.isNotEmpty) http['host'] = [s.host];
        stream['httpSettings'] = http;
      case 'tcp':
        if (s.headerType == 'http') {
          final tcp = <String, dynamic>{
            'header': <String, dynamic>{
              'type': 'http',
            },
          };
          if (s.host.isNotEmpty || s.path.isNotEmpty) {
            final request = <String, dynamic>{};
            if (s.path.isNotEmpty) request['path'] = [s.path];
            if (s.host.isNotEmpty) {
              request['headers'] = {
                'Host': [s.host]
              };
            }
            tcp['header']['request'] = request;
          }
          stream['tcpSettings'] = tcp;
        }
    }

    // Security
    switch (s.security) {
      case 'tls':
        stream['security'] = 'tls';
        final tls = <String, dynamic>{'allowInsecure': false};
        if (s.sni.isNotEmpty) tls['serverName'] = s.sni;
        if (s.fingerprint.isNotEmpty) tls['fingerprint'] = s.fingerprint;
        if (s.alpn.isNotEmpty) {
          tls['alpn'] = s.alpn.split(',').map((a) => a.trim()).toList();
        }
        stream['tlsSettings'] = tls;
      case 'reality':
        stream['security'] = 'reality';
        final reality = <String, dynamic>{};
        if (s.sni.isNotEmpty) reality['serverName'] = s.sni;
        if (s.fingerprint.isNotEmpty) reality['fingerprint'] = s.fingerprint;
        if (s.publicKey.isNotEmpty) reality['publicKey'] = s.publicKey;
        if (s.shortId.isNotEmpty) reality['shortId'] = s.shortId;
        if (s.spiderX.isNotEmpty) reality['spiderX'] = s.spiderX;
        stream['realitySettings'] = reality;
      default:
        stream['security'] = 'none';
    }

    return stream;
  }
}
