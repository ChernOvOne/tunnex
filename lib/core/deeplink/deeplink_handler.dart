import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repository/server_repository.dart';
import '../model/protocol.dart';
import '../parser/protocol_parser.dart';

enum DeeplinkAction {
  addSubscription,
  importServer,
  none,
}

class DeeplinkResult {
  final DeeplinkAction action;
  final String? subscriptionUrl;
  final String? serverUri;
  final String? error;

  const DeeplinkResult({
    this.action = DeeplinkAction.none,
    this.subscriptionUrl,
    this.serverUri,
    this.error,
  });
}

class DeeplinkHandler {
  final AppLinks _appLinks = AppLinks();
  final Ref _ref;
  StreamSubscription? _sub;

  DeeplinkHandler(this._ref);

  Future<void> init() async {
    // Handle initial link (cold start)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (_) {}

    // Handle links while app is running
    _sub = _appLinks.uriLinkStream.listen(_handleUri);
  }

  void _handleUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();

    // tunnex://subscribe?url=...
    if (scheme == 'tunnex' && uri.host == 'subscribe') {
      final url = uri.queryParameters['url'];
      if (url != null && url.isNotEmpty) {
        _ref.read(subscriptionsProvider.notifier).add(url);
      }
      return;
    }

    // tunnex://import?config=...
    if (scheme == 'tunnex' && uri.host == 'import') {
      final config = uri.queryParameters['config'];
      if (config != null && config.isNotEmpty) {
        _importServer(config);
      }
      return;
    }

    // https://tunnex.app/sub?url=...
    if ((scheme == 'http' || scheme == 'https') &&
        uri.host == 'tunnex.app' &&
        uri.path == '/sub') {
      final url = uri.queryParameters['url'];
      if (url != null && url.isNotEmpty) {
        _ref.read(subscriptionsProvider.notifier).add(url);
      }
      return;
    }

    // Protocol URIs: vless://, vmess://, trojan://, ss://
    if (Protocol.fromScheme(scheme) != null) {
      _importServer(uri.toString());
      return;
    }
  }

  void _importServer(String uri) {
    final server = ProtocolParser.parse(uri);
    if (server != null) {
      _ref.read(serversProvider.notifier).reload();
      // Add via server repository directly
      _ref.read(serverRepositoryProvider).add(server).then((_) {
        _ref.invalidate(serversProvider);
      });
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}

final deeplinkHandlerProvider = Provider<DeeplinkHandler>((ref) {
  final handler = DeeplinkHandler(ref);
  ref.onDispose(() => handler.dispose());
  return handler;
});
