import 'package:uuid/uuid.dart';
import 'protocol.dart';

class ServerConfig {
  final String id;
  final String remarks;
  final Protocol protocol;
  final String address;
  final int port;
  final String uuid; // also used as password for trojan/ss
  final String encryption;
  final String network; // tcp, ws, grpc, http, httpupgrade, quic
  final String headerType;
  final String host;
  final String path;
  final String security; // tls, reality, none
  final String sni;
  final String fingerprint;
  final String alpn;
  final String publicKey; // Reality
  final String shortId; // Reality
  final String spiderX;
  final String flow;
  final String method; // Shadowsocks cipher
  final String subscriptionId;
  final int testResult; // ping ms, -1 = not tested

  const ServerConfig({
    required this.id,
    this.remarks = '',
    this.protocol = Protocol.vless,
    this.address = '',
    this.port = 443,
    this.uuid = '',
    this.encryption = 'none',
    this.network = 'tcp',
    this.headerType = '',
    this.host = '',
    this.path = '',
    this.security = 'tls',
    this.sni = '',
    this.fingerprint = 'chrome',
    this.alpn = '',
    this.publicKey = '',
    this.shortId = '',
    this.spiderX = '',
    this.flow = '',
    this.method = 'aes-256-gcm',
    this.subscriptionId = '',
    this.testResult = -1,
  });

  factory ServerConfig.create({
    String? remarks,
    Protocol protocol = Protocol.vless,
    String address = '',
    int port = 443,
    String uuid = '',
    String encryption = 'none',
    String network = 'tcp',
    String headerType = '',
    String host = '',
    String path = '',
    String security = 'tls',
    String sni = '',
    String fingerprint = 'chrome',
    String alpn = '',
    String publicKey = '',
    String shortId = '',
    String spiderX = '',
    String flow = '',
    String method = 'aes-256-gcm',
    String subscriptionId = '',
  }) {
    return ServerConfig(
      id: const Uuid().v4(),
      remarks: remarks ?? '',
      protocol: protocol,
      address: address,
      port: port,
      uuid: uuid,
      encryption: encryption,
      network: network,
      headerType: headerType,
      host: host,
      path: path,
      security: security,
      sni: sni,
      fingerprint: fingerprint,
      alpn: alpn,
      publicKey: publicKey,
      shortId: shortId,
      spiderX: spiderX,
      flow: flow,
      method: method,
      subscriptionId: subscriptionId,
    );
  }

  ServerConfig copyWith({
    String? id,
    String? remarks,
    Protocol? protocol,
    String? address,
    int? port,
    String? uuid,
    String? encryption,
    String? network,
    String? headerType,
    String? host,
    String? path,
    String? security,
    String? sni,
    String? fingerprint,
    String? alpn,
    String? publicKey,
    String? shortId,
    String? spiderX,
    String? flow,
    String? method,
    String? subscriptionId,
    int? testResult,
  }) {
    return ServerConfig(
      id: id ?? this.id,
      remarks: remarks ?? this.remarks,
      protocol: protocol ?? this.protocol,
      address: address ?? this.address,
      port: port ?? this.port,
      uuid: uuid ?? this.uuid,
      encryption: encryption ?? this.encryption,
      network: network ?? this.network,
      headerType: headerType ?? this.headerType,
      host: host ?? this.host,
      path: path ?? this.path,
      security: security ?? this.security,
      sni: sni ?? this.sni,
      fingerprint: fingerprint ?? this.fingerprint,
      alpn: alpn ?? this.alpn,
      publicKey: publicKey ?? this.publicKey,
      shortId: shortId ?? this.shortId,
      spiderX: spiderX ?? this.spiderX,
      flow: flow ?? this.flow,
      method: method ?? this.method,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      testResult: testResult ?? this.testResult,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'remarks': remarks,
        'protocol': protocol.name,
        'address': address,
        'port': port,
        'uuid': uuid,
        'encryption': encryption,
        'network': network,
        'headerType': headerType,
        'host': host,
        'path': path,
        'security': security,
        'sni': sni,
        'fingerprint': fingerprint,
        'alpn': alpn,
        'publicKey': publicKey,
        'shortId': shortId,
        'spiderX': spiderX,
        'flow': flow,
        'method': method,
        'subscriptionId': subscriptionId,
        'testResult': testResult,
      };

  factory ServerConfig.fromJson(Map<String, dynamic> json) => ServerConfig(
        id: json['id'] as String? ?? const Uuid().v4(),
        remarks: json['remarks'] as String? ?? '',
        protocol: Protocol.values.firstWhere(
          (p) => p.name == json['protocol'],
          orElse: () => Protocol.vless,
        ),
        address: json['address'] as String? ?? '',
        port: json['port'] as int? ?? 443,
        uuid: json['uuid'] as String? ?? '',
        encryption: json['encryption'] as String? ?? 'none',
        network: json['network'] as String? ?? 'tcp',
        headerType: json['headerType'] as String? ?? '',
        host: json['host'] as String? ?? '',
        path: json['path'] as String? ?? '',
        security: json['security'] as String? ?? 'tls',
        sni: json['sni'] as String? ?? '',
        fingerprint: json['fingerprint'] as String? ?? 'chrome',
        alpn: json['alpn'] as String? ?? '',
        publicKey: json['publicKey'] as String? ?? '',
        shortId: json['shortId'] as String? ?? '',
        spiderX: json['spiderX'] as String? ?? '',
        flow: json['flow'] as String? ?? '',
        method: json['method'] as String? ?? 'aes-256-gcm',
        subscriptionId: json['subscriptionId'] as String? ?? '',
        testResult: json['testResult'] as int? ?? -1,
      );
}
