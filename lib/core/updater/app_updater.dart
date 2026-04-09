import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String body;
  final bool hasUpdate;

  const UpdateInfo({
    this.version = '',
    this.downloadUrl = '',
    this.body = '',
    this.hasUpdate = false,
  });
}

class AppUpdater {
  static const _currentVersion = '2.0.1';
  static const _repo = 'ChernOvOne/tunnex';

  static Future<UpdateInfo> checkUpdate() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://api.github.com/repos/$_repo/releases/latest',
        options: Options(headers: {'Accept': 'application/vnd.github+json'}),
      ).timeout(const Duration(seconds: 10));

      final data = response.data as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String? ?? '').replaceAll('v', '');
      final body = data['body'] as String? ?? '';
      final assets = data['assets'] as List? ?? [];

      if (tagName.isEmpty || tagName == _currentVersion) {
        return const UpdateInfo();
      }

      // Compare versions
      if (!_isNewer(tagName, _currentVersion)) {
        return const UpdateInfo();
      }

      // Find download URL for current platform
      String downloadUrl = '';
      final platform = Platform.isWindows ? 'Setup' : 'arm64';
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.contains(platform)) {
          downloadUrl = asset['browser_download_url'] as String? ?? '';
          break;
        }
      }

      return UpdateInfo(
        version: tagName,
        downloadUrl: downloadUrl,
        body: body,
        hasUpdate: downloadUrl.isNotEmpty,
      );
    } catch (e) {
      debugPrint('Update check failed: $e');
      return const UpdateInfo();
    }
  }

  static Future<String?> download(
    String url, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final fileName = url.split('/').last;
      final filePath = '${dir.path}/$fileName';

      final dio = Dio();
      await dio.download(
        url,
        filePath,
        onReceiveProgress: onProgress,
      );

      return filePath;
    } catch (e) {
      debugPrint('Download failed: $e');
      return null;
    }
  }

  static Future<void> installAndRestart(String filePath) async {
    if (Platform.isWindows) {
      await Process.start(filePath, ['/SILENT'], mode: ProcessStartMode.detached);
      exit(0);
    } else if (Platform.isAndroid) {
      try {
        const channel = MethodChannel('com.tunnex/vpn');
        await channel.invokeMethod('installApk', {'path': filePath});
      } catch (e) {
        debugPrint('Install APK failed: $e');
      }
    }
  }

  static String get currentVersion => _currentVersion;

  static bool _isNewer(String remote, String local) {
    final r = remote.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final l = local.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final rv = i < r.length ? r[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (rv > lv) return true;
      if (rv < lv) return false;
    }
    return false;
  }
}
