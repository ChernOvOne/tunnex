import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class HwidHelper {
  static String? _cachedHwid;
  static String? _cachedModel;
  static String? _cachedOsVersion;

  static Future<String> getHwid() async {
    if (_cachedHwid != null) return _cachedHwid!;

    final info = DeviceInfoPlugin();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = await info.androidInfo;
      final androidId = android.id; // ANDROID_ID equivalent
      final raw = '$androidId-${android.board}-${android.device}';
      _cachedHwid = sha256.convert(utf8.encode(raw)).toString().substring(0, 32);
    } else {
      // Fallback for other platforms
      _cachedHwid = sha256
          .convert(utf8.encode('tunnex-${DateTime.now().microsecondsSinceEpoch}'))
          .toString()
          .substring(0, 32);
    }
    return _cachedHwid!;
  }

  static Future<String> getDeviceModel() async {
    if (_cachedModel != null) return _cachedModel!;
    final info = DeviceInfoPlugin();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = await info.androidInfo;
      _cachedModel = '${android.manufacturer} ${android.model}';
    } else {
      _cachedModel = 'Unknown';
    }
    return _cachedModel!;
  }

  static Future<String> getOsVersion() async {
    if (_cachedOsVersion != null) return _cachedOsVersion!;
    final info = DeviceInfoPlugin();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = await info.androidInfo;
      _cachedOsVersion = android.version.release;
    } else {
      _cachedOsVersion = 'Unknown';
    }
    return _cachedOsVersion!;
  }
}
