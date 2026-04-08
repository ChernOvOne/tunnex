import 'dart:convert';

import '../model/protocol.dart';
import '../model/server_config.dart';

class ProtocolParser {
  ProtocolParser._();

  static ServerConfig? parse(String uri) {
    final trimmed = uri.trim();
    if (trimmed.startsWith('vless://')) return _parseVless(trimmed);
    if (trimmed.startsWith('vmess://')) return _parseVmess(trimmed);
    if (trimmed.startsWith('trojan://')) return _parseTrojan(trimmed);
    if (trimmed.startsWith('ss://')) return _parseShadowsocks(trimmed);
    return null;
  }

  static List<ServerConfig> parseSubscription(String content) {
    String decoded;
    try {
      decoded = utf8.decode(base64Decode(_normalizeBase64(content.trim())));
    } catch (_) {
      decoded = content;
    }
    return decoded
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => parse(l))
        .whereType<ServerConfig>()
        .toList();
  }

  static ServerConfig? _parseVless(String uri) {
    try {
      final parsed = Uri.parse(uri);
      final uuid = parsed.userInfo;
      if (uuid.isEmpty) return null;
      final address = parsed.host;
      if (address.isEmpty) return null;
      final port = parsed.port > 0 ? parsed.port : 443;
      final remarks = parsed.fragment.isNotEmpty
          ? Uri.decodeComponent(parsed.fragment)
          : '';

      return ServerConfig.create(
        remarks: remarks,
        protocol: Protocol.vless,
        address: address,
        port: port,
        uuid: uuid,
        encryption: parsed.queryParameters['encryption'] ?? 'none',
        network: parsed.queryParameters['type'] ?? 'tcp',
        headerType: parsed.queryParameters['headerType'] ?? '',
        host: parsed.queryParameters['host'] ?? '',
        path: parsed.queryParameters['path'] ?? '',
        security: parsed.queryParameters['security'] ?? 'none',
        sni: parsed.queryParameters['sni'] ?? '',
        fingerprint: parsed.queryParameters['fp'] ?? 'chrome',
        alpn: parsed.queryParameters['alpn'] ?? '',
        publicKey: parsed.queryParameters['pbk'] ?? '',
        shortId: parsed.queryParameters['sid'] ?? '',
        spiderX: parsed.queryParameters['spx'] ?? '',
        flow: parsed.queryParameters['flow'] ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static ServerConfig? _parseVmess(String uri) {
    try {
      final encoded = uri.substring('vmess://'.length);
      final json = utf8.decode(base64Decode(_normalizeBase64(encoded)));
      final obj = jsonDecode(json) as Map<String, dynamic>;

      return ServerConfig.create(
        remarks: obj['ps'] as String? ?? '',
        protocol: Protocol.vmess,
        address: obj['add'] as String? ?? '',
        port: int.tryParse('${obj['port']}') ?? 443,
        uuid: obj['id'] as String? ?? '',
        encryption: obj['scy'] as String? ?? 'auto',
        network: obj['net'] as String? ?? 'tcp',
        headerType: obj['type'] as String? ?? '',
        host: obj['host'] as String? ?? '',
        path: obj['path'] as String? ?? '',
        security: obj['tls'] as String? ?? '',
        sni: obj['sni'] as String? ?? '',
        fingerprint: obj['fp'] as String? ?? 'chrome',
        alpn: obj['alpn'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static ServerConfig? _parseTrojan(String uri) {
    try {
      final parsed = Uri.parse(uri);
      final password = parsed.userInfo;
      if (password.isEmpty) return null;
      final address = parsed.host;
      if (address.isEmpty) return null;
      final port = parsed.port > 0 ? parsed.port : 443;
      final remarks = parsed.fragment.isNotEmpty
          ? Uri.decodeComponent(parsed.fragment)
          : '';

      return ServerConfig.create(
        remarks: remarks,
        protocol: Protocol.trojan,
        address: address,
        port: port,
        uuid: password,
        network: parsed.queryParameters['type'] ?? 'tcp',
        security: parsed.queryParameters['security'] ?? 'tls',
        sni: parsed.queryParameters['sni'] ?? '',
        fingerprint: parsed.queryParameters['fp'] ?? 'chrome',
        alpn: parsed.queryParameters['alpn'] ?? '',
        host: parsed.queryParameters['host'] ?? '',
        path: parsed.queryParameters['path'] ?? '',
        headerType: parsed.queryParameters['headerType'] ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static ServerConfig? _parseShadowsocks(String uri) {
    try {
      final withoutScheme = uri.substring('ss://'.length);
      final fragmentIndex = withoutScheme.indexOf('#');
      final remarks = fragmentIndex >= 0
          ? Uri.decodeComponent(withoutScheme.substring(fragmentIndex + 1))
          : '';
      final mainPart = fragmentIndex >= 0
          ? withoutScheme.substring(0, fragmentIndex)
          : withoutScheme;

      final atIndex = mainPart.indexOf('@');
      if (atIndex >= 0) {
        String userInfo;
        try {
          userInfo = utf8.decode(
              base64Decode(_normalizeBase64(mainPart.substring(0, atIndex))));
        } catch (_) {
          userInfo = mainPart.substring(0, atIndex);
        }

        final hostPort = mainPart.substring(atIndex + 1);
        final colonIndex = hostPort.lastIndexOf(':');
        final address = hostPort.substring(0, colonIndex);
        final port =
            int.tryParse(hostPort.substring(colonIndex + 1).split('?')[0]) ??
                443;

        final parts = userInfo.split(':');
        final method = parts.isNotEmpty ? parts[0] : 'aes-256-gcm';
        final password = parts.length > 1 ? parts.sublist(1).join(':') : '';

        return ServerConfig.create(
          remarks: remarks,
          protocol: Protocol.shadowsocks,
          address: address,
          port: port,
          uuid: password,
          method: method,
        );
      } else {
        // Legacy format: base64 encoded entirely
        final decoded = utf8.decode(
            base64Decode(_normalizeBase64(mainPart.split('?')[0])));
        return _parseShadowsocks('ss://$decoded#$remarks');
      }
    } catch (_) {
      return null;
    }
  }

  // --- URI builders ---

  static String toUri(ServerConfig server) {
    switch (server.protocol) {
      case Protocol.vless:
        return _buildVlessUri(server);
      case Protocol.vmess:
        return _buildVmessUri(server);
      case Protocol.trojan:
        return _buildTrojanUri(server);
      case Protocol.shadowsocks:
        return _buildSsUri(server);
    }
  }

  static String _buildVlessUri(ServerConfig s) {
    final params = <String>[];
    if (s.encryption.isNotEmpty) params.add('encryption=${s.encryption}');
    if (s.network.isNotEmpty) params.add('type=${s.network}');
    if (s.security.isNotEmpty) params.add('security=${s.security}');
    if (s.sni.isNotEmpty) params.add('sni=${s.sni}');
    if (s.fingerprint.isNotEmpty) params.add('fp=${s.fingerprint}');
    if (s.alpn.isNotEmpty) params.add('alpn=${s.alpn}');
    if (s.host.isNotEmpty) params.add('host=${s.host}');
    if (s.path.isNotEmpty) params.add('path=${Uri.encodeComponent(s.path)}');
    if (s.flow.isNotEmpty) params.add('flow=${s.flow}');
    if (s.publicKey.isNotEmpty) params.add('pbk=${s.publicKey}');
    if (s.shortId.isNotEmpty) params.add('sid=${s.shortId}');
    if (s.spiderX.isNotEmpty) {
      params.add('spx=${Uri.encodeComponent(s.spiderX)}');
    }
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final fragment =
        s.remarks.isNotEmpty ? '#${Uri.encodeComponent(s.remarks)}' : '';
    return 'vless://${s.uuid}@${s.address}:${s.port}$query$fragment';
  }

  static String _buildVmessUri(ServerConfig s) {
    final obj = {
      'v': '2',
      'ps': s.remarks,
      'add': s.address,
      'port': s.port.toString(),
      'id': s.uuid,
      'aid': '0',
      'scy': s.encryption.isEmpty ? 'auto' : s.encryption,
      'net': s.network,
      'type': s.headerType,
      'host': s.host,
      'path': s.path,
      'tls': s.security,
      'sni': s.sni,
      'alpn': s.alpn,
      'fp': s.fingerprint,
    };
    return 'vmess://${base64Encode(utf8.encode(jsonEncode(obj)))}';
  }

  static String _buildTrojanUri(ServerConfig s) {
    final params = <String>[];
    if (s.network.isNotEmpty) params.add('type=${s.network}');
    if (s.security.isNotEmpty) params.add('security=${s.security}');
    if (s.sni.isNotEmpty) params.add('sni=${s.sni}');
    if (s.fingerprint.isNotEmpty) params.add('fp=${s.fingerprint}');
    if (s.host.isNotEmpty) params.add('host=${s.host}');
    if (s.path.isNotEmpty) params.add('path=${Uri.encodeComponent(s.path)}');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final fragment =
        s.remarks.isNotEmpty ? '#${Uri.encodeComponent(s.remarks)}' : '';
    return 'trojan://${s.uuid}@${s.address}:${s.port}$query$fragment';
  }

  static String _buildSsUri(ServerConfig s) {
    final userInfo = base64Encode(utf8.encode('${s.method}:${s.uuid}'));
    final fragment =
        s.remarks.isNotEmpty ? '#${Uri.encodeComponent(s.remarks)}' : '';
    return 'ss://$userInfo@${s.address}:${s.port}$fragment';
  }

  /// Normalize base64 (add padding if needed)
  static String _normalizeBase64(String input) {
    String s = input.replaceAll(RegExp(r'\s'), '');
    // URL-safe to standard
    s = s.replaceAll('-', '+').replaceAll('_', '/');
    // Add padding
    final remainder = s.length % 4;
    if (remainder > 0) {
      s += '=' * (4 - remainder);
    }
    return s;
  }
}
