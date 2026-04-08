import 'package:uuid/uuid.dart';

class Subscription {
  final String id;
  final String name;
  final String url;
  final int lastUpdated; // epoch ms
  final bool autoUpdate;
  final int updateIntervalMinutes;
  final int uploadBytes;
  final int downloadBytes;
  final int totalBytes;
  final int expireTimestamp; // epoch seconds
  final String username;
  final String supportUrl;

  const Subscription({
    required this.id,
    this.name = '',
    this.url = '',
    this.lastUpdated = 0,
    this.autoUpdate = true,
    this.updateIntervalMinutes = 60,
    this.uploadBytes = 0,
    this.downloadBytes = 0,
    this.totalBytes = 0,
    this.expireTimestamp = 0,
    this.username = '',
    this.supportUrl = '',
  });

  factory Subscription.create({required String url, String name = ''}) {
    return Subscription(
      id: const Uuid().v4(),
      url: url,
      name: name,
    );
  }

  Subscription copyWith({
    String? id,
    String? name,
    String? url,
    int? lastUpdated,
    bool? autoUpdate,
    int? updateIntervalMinutes,
    int? uploadBytes,
    int? downloadBytes,
    int? totalBytes,
    int? expireTimestamp,
    String? username,
    String? supportUrl,
  }) {
    return Subscription(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      autoUpdate: autoUpdate ?? this.autoUpdate,
      updateIntervalMinutes:
          updateIntervalMinutes ?? this.updateIntervalMinutes,
      uploadBytes: uploadBytes ?? this.uploadBytes,
      downloadBytes: downloadBytes ?? this.downloadBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      expireTimestamp: expireTimestamp ?? this.expireTimestamp,
      username: username ?? this.username,
      supportUrl: supportUrl ?? this.supportUrl,
    );
  }

  double get usedBytes => (uploadBytes + downloadBytes).toDouble();

  double get usagePercent {
    if (totalBytes <= 0) return 0;
    return (usedBytes / totalBytes).clamp(0.0, 1.0);
  }

  int get daysLeft {
    if (expireTimestamp <= 0) return -1;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = expireTimestamp - now;
    if (diff <= 0) return 0;
    return (diff / 86400).ceil();
  }

  bool get isExpired {
    if (expireTimestamp <= 0) return false;
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 > expireTimestamp;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'lastUpdated': lastUpdated,
        'autoUpdate': autoUpdate,
        'updateIntervalMinutes': updateIntervalMinutes,
        'uploadBytes': uploadBytes,
        'downloadBytes': downloadBytes,
        'totalBytes': totalBytes,
        'expireTimestamp': expireTimestamp,
        'username': username,
        'supportUrl': supportUrl,
      };

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        id: json['id'] as String? ?? const Uuid().v4(),
        name: json['name'] as String? ?? '',
        url: json['url'] as String? ?? '',
        lastUpdated: json['lastUpdated'] as int? ?? 0,
        autoUpdate: json['autoUpdate'] as bool? ?? true,
        updateIntervalMinutes: json['updateIntervalMinutes'] as int? ?? 60,
        uploadBytes: json['uploadBytes'] as int? ?? 0,
        downloadBytes: json['downloadBytes'] as int? ?? 0,
        totalBytes: json['totalBytes'] as int? ?? 0,
        expireTimestamp: json['expireTimestamp'] as int? ?? 0,
        username: json['username'] as String? ?? '',
        supportUrl: json['supportUrl'] as String? ?? '',
      );
}
