import 'dart:io';

import '../model/server_config.dart';

class TcpPing {
  TcpPing._();

  /// Ping a single server, returns latency in ms or -1 on failure
  static Future<int> ping(ServerConfig server, {int timeoutMs = 3000}) async {
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        server.address,
        server.port,
        timeout: Duration(milliseconds: timeoutMs),
      );
      stopwatch.stop();
      socket.destroy();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      return -1;
    }
  }

  /// Ping all servers in parallel, returns map of server.id -> latency ms
  static Future<Map<String, int>> pingAll(
    List<ServerConfig> servers, {
    int timeoutMs = 3000,
  }) async {
    final futures = servers.map((s) async {
      final ms = await ping(s, timeoutMs: timeoutMs);
      return MapEntry(s.id, ms);
    });
    final results = await Future.wait(futures);
    return Map.fromEntries(results);
  }
}
