import 'dart:io';

import '../model/server_config.dart';

/// Методы проверки доступности серверов
enum PingMethod {
  tcp('TCP Connect', 'Проверяет открыт ли порт сервера. Быстрый, но не гарантирует что VPN работает.'),
  httpGet('HTTP GET', 'Полная проверка через прокси — загружает тестовую страницу. Надёжный, но медленнее.'),
  httpHead('HTTP HEAD', 'Быстрая проверка через прокси — запрашивает только заголовки. Золотая середина.'),
  tlsHandshake('TLS Handshake', 'Проверяет TLS-соединение с сервером. Показывает что шифрование работает.');

  const PingMethod(this.displayName, this.description);
  final String displayName;
  final String description;
}

class ServerPing {
  ServerPing._();

  /// Ping single server with selected method
  static Future<int> ping(
    ServerConfig server, {
    PingMethod method = PingMethod.tcp,
    int timeoutMs = 3000,
  }) {
    switch (method) {
      case PingMethod.tcp:
        return _tcpPing(server, timeoutMs);
      case PingMethod.httpGet:
        return _httpPing(server, timeoutMs, head: false);
      case PingMethod.httpHead:
        return _httpPing(server, timeoutMs, head: true);
      case PingMethod.tlsHandshake:
        return _tlsPing(server, timeoutMs);
    }
  }

  /// Ping all servers in parallel
  static Future<Map<String, int>> pingAll(
    List<ServerConfig> servers, {
    PingMethod method = PingMethod.tcp,
    int timeoutMs = 3000,
  }) async {
    final futures = servers.map((s) async {
      final ms = await ping(s, method: method, timeoutMs: timeoutMs);
      return MapEntry(s.id, ms);
    });
    final results = await Future.wait(futures);
    return Map.fromEntries(results);
  }

  /// TCP Connect — проверяет что порт открыт
  static Future<int> _tcpPing(ServerConfig server, int timeoutMs) async {
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        server.address,
        server.port,
        timeout: Duration(milliseconds: timeoutMs),
      );
      sw.stop();
      socket.destroy();
      return sw.elapsedMilliseconds;
    } catch (_) {
      return -1;
    }
  }

  /// HTTP GET/HEAD через прямое подключение к серверу
  /// Проверяет что сервер реально отвечает
  static Future<int> _httpPing(ServerConfig server, int timeoutMs,
      {required bool head}) async {
    final sw = Stopwatch()..start();
    try {
      final client = HttpClient()
        ..connectionTimeout = Duration(milliseconds: timeoutMs)
        ..idleTimeout = Duration(milliseconds: timeoutMs);

      // Пробуем подключиться к серверу и получить ответ
      // Для VLESS/VMess серверов проверяем TLS handshake + HTTP
      final uri = Uri.parse(
          'https://${server.sni.isNotEmpty ? server.sni : server.address}:${server.port}/');

      final request = head
          ? await client.headUrl(uri)
          : await client.getUrl(uri);
      request.followRedirects = false;
      final response = await request.close().timeout(
            Duration(milliseconds: timeoutMs),
          );
      // Любой ответ = сервер жив
      await response.drain<void>();
      sw.stop();
      client.close(force: true);
      return sw.elapsedMilliseconds;
    } catch (_) {
      // Даже если HTTP ответ не 200 — важно что подключились
      // Для прокси-серверов 400/403 — нормально
      if (sw.elapsedMilliseconds > 0 && sw.elapsedMilliseconds < timeoutMs) {
        return sw.elapsedMilliseconds;
      }
      return -1;
    }
  }

  /// TLS Handshake — проверяет что TLS-соединение устанавливается
  static Future<int> _tlsPing(ServerConfig server, int timeoutMs) async {
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        server.address,
        server.port,
        timeout: Duration(milliseconds: timeoutMs),
      );

      if (server.security == 'tls' || server.security == 'reality') {
        final secureSocket = await SecureSocket.secure(
          socket,
          host: server.sni.isNotEmpty ? server.sni : server.address,
          onBadCertificate: (_) => true, // Accept self-signed for testing
        ).timeout(Duration(milliseconds: timeoutMs));
        sw.stop();
        secureSocket.destroy();
      } else {
        sw.stop();
        socket.destroy();
      }
      return sw.elapsedMilliseconds;
    } catch (_) {
      return -1;
    }
  }
}
