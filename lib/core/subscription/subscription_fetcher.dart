import 'dart:convert';

import 'package:dio/dio.dart';

import '../model/server_config.dart';
import '../model/subscription.dart';
import '../parser/protocol_parser.dart';

class SubscriptionResult {
  final Subscription subscription;
  final List<ServerConfig> servers;
  final String? announce;
  final bool hwidLimitReached;

  const SubscriptionResult({
    required this.subscription,
    required this.servers,
    this.announce,
    this.hwidLimitReached = false,
  });
}

class SubscriptionFetcher {
  final Dio _dio;

  SubscriptionFetcher({Dio? dio}) : _dio = dio ?? Dio();

  Future<SubscriptionResult> fetch({
    required Subscription subscription,
    required String hwid,
    required String deviceModel,
    required String osVersion,
  }) async {
    final response = await _dio.get(
      subscription.url,
      options: Options(
        headers: {
          'User-Agent': 'Tunnex/1.0',
          'x-hwid': hwid,
          'x-device-os': 'Android',
          'x-ver-os': osVersion,
          'x-device-model': deviceModel,
        },
        responseType: ResponseType.plain,
      ),
    );

    final headers = response.headers;

    // Parse subscription-userinfo
    int upload = 0, download = 0, total = 0, expire = 0;
    final userInfo = headers.value('subscription-userinfo');
    if (userInfo != null) {
      for (final part in userInfo.split(';')) {
        final kv = part.trim().split('=');
        if (kv.length != 2) continue;
        final key = kv[0].trim();
        final value = int.tryParse(kv[1].trim()) ?? 0;
        switch (key) {
          case 'upload':
            upload = value;
          case 'download':
            download = value;
          case 'total':
            total = value;
          case 'expire':
            expire = value;
        }
      }
    }

    // Parse profile-title
    String name = subscription.name;
    final profileTitle = headers.value('profile-title');
    if (profileTitle != null && profileTitle.isNotEmpty) {
      if (profileTitle.startsWith('base64:')) {
        try {
          name = utf8.decode(base64Decode(profileTitle.substring(7)));
        } catch (_) {
          name = profileTitle;
        }
      } else {
        name = profileTitle;
      }
    }

    // Parse content-disposition for username
    String username = subscription.username;
    final contentDisposition = headers.value('content-disposition');
    if (contentDisposition != null) {
      final match =
          RegExp(r'filename=(.+)').firstMatch(contentDisposition);
      if (match != null) {
        username = match.group(1)?.trim() ?? username;
      }
    }

    // Support URL
    final supportUrl =
        headers.value('support-url') ?? subscription.supportUrl;

    // HWID
    final hwidLimitReached =
        headers.value('x-hwid-max-devices-reached') != null;

    // Announce (base64)
    String? announce;
    final announceHeader = headers.value('announce');
    if (announceHeader != null && announceHeader.isNotEmpty) {
      try {
        announce = utf8.decode(base64Decode(announceHeader));
      } catch (_) {
        announce = announceHeader;
      }
    }

    // Parse servers from body
    final body = response.data as String? ?? '';
    final servers = ProtocolParser.parseSubscription(body).map((s) {
      return s.copyWith(subscriptionId: subscription.id);
    }).toList();

    final updatedSub = subscription.copyWith(
      name: name,
      uploadBytes: upload,
      downloadBytes: download,
      totalBytes: total,
      expireTimestamp: expire,
      username: username,
      supportUrl: supportUrl,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
    );

    return SubscriptionResult(
      subscription: updatedSub,
      servers: servers,
      announce: announce,
      hwidLimitReached: hwidLimitReached,
    );
  }
}
