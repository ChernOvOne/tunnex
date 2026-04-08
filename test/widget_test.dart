import 'package:flutter_test/flutter_test.dart';

import 'package:tunnex/core/parser/protocol_parser.dart';
import 'package:tunnex/core/model/protocol.dart';

void main() {
  test('Parse VLESS URI', () {
    final server = ProtocolParser.parse(
      'vless://uuid-test@example.com:443?encryption=none&type=tcp&security=reality&sni=www.microsoft.com&fp=chrome&pbk=pubkey123&sid=ab&flow=xtls-rprx-vision#Test%20Server',
    );

    expect(server, isNotNull);
    expect(server!.protocol, Protocol.vless);
    expect(server.uuid, 'uuid-test');
    expect(server.address, 'example.com');
    expect(server.port, 443);
    expect(server.security, 'reality');
    expect(server.publicKey, 'pubkey123');
    expect(server.shortId, 'ab');
    expect(server.flow, 'xtls-rprx-vision');
    expect(server.remarks, 'Test Server');
  });

  test('Parse VMess URI', () {
    // vmess is base64 JSON
    final server = ProtocolParser.parse(
      'vmess://eyJ2IjoiMiIsInBzIjoiVGVzdCIsImFkZCI6IjEuMi4zLjQiLCJwb3J0IjoiNDQzIiwiaWQiOiJ0ZXN0LWlkIiwic2N5IjoiYXV0byIsIm5ldCI6IndzIiwiaG9zdCI6ImV4YW1wbGUuY29tIiwicGF0aCI6Ii92bWVzcyIsInRscyI6InRscyIsInNuaSI6ImV4YW1wbGUuY29tIn0=',
    );

    expect(server, isNotNull);
    expect(server!.protocol, Protocol.vmess);
    expect(server.address, '1.2.3.4');
    expect(server.uuid, 'test-id');
    expect(server.network, 'ws');
  });
}
