import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AES-like XOR encryption for local storage
/// Not military grade but prevents plain-text credential exposure on disk
class SecureStorage {
  static Uint8List? _key;

  /// Get or generate encryption key (stored in SharedPreferences)
  static Future<Uint8List> _getKey() async {
    if (_key != null) return _key!;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('_sk');
    if (stored != null) {
      _key = base64Decode(stored);
    } else {
      // Generate random 32-byte key
      final random = Random.secure();
      _key = Uint8List.fromList(
          List.generate(32, (_) => random.nextInt(256)));
      await prefs.setString('_sk', base64Encode(_key!));
    }
    return _key!;
  }

  /// Encrypt string data
  static Future<String> encrypt(String plainText) async {
    final key = await _getKey();
    final data = utf8.encode(plainText);

    // Generate random IV
    final random = Random.secure();
    final iv = Uint8List.fromList(
        List.generate(16, (_) => random.nextInt(256)));

    // XOR with key stream derived from key + IV
    final keyStream = _deriveKeyStream(key, iv, data.length);
    final encrypted = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      encrypted[i] = data[i] ^ keyStream[i];
    }

    // Prepend IV + HMAC for integrity
    final hmac = Hmac(sha256, key);
    final mac = hmac.convert(encrypted).bytes;

    // Format: base64(iv + mac[0:8] + encrypted)
    final result = Uint8List(16 + 8 + encrypted.length);
    result.setRange(0, 16, iv);
    result.setRange(16, 24, mac.sublist(0, 8));
    result.setRange(24, result.length, encrypted);

    return base64Encode(result);
  }

  /// Decrypt string data
  static Future<String> decrypt(String cipherText) async {
    final key = await _getKey();
    final raw = base64Decode(cipherText);

    if (raw.length < 24) throw Exception('Invalid encrypted data');

    final iv = raw.sublist(0, 16);
    final storedMac = raw.sublist(16, 24);
    final encrypted = raw.sublist(24);

    // Verify HMAC
    final hmac = Hmac(sha256, key);
    final mac = hmac.convert(encrypted).bytes;
    for (int i = 0; i < 8; i++) {
      if (storedMac[i] != mac[i]) throw Exception('Data integrity check failed');
    }

    // Decrypt
    final keyStream = _deriveKeyStream(key, Uint8List.fromList(iv), encrypted.length);
    final decrypted = Uint8List(encrypted.length);
    for (int i = 0; i < encrypted.length; i++) {
      decrypted[i] = encrypted[i] ^ keyStream[i];
    }

    return utf8.decode(decrypted);
  }

  /// Derive key stream using SHA-256 in counter mode
  static Uint8List _deriveKeyStream(Uint8List key, Uint8List iv, int length) {
    final stream = BytesBuilder();
    int counter = 0;
    while (stream.length < length) {
      final input = Uint8List(key.length + iv.length + 4);
      input.setRange(0, key.length, key);
      input.setRange(key.length, key.length + iv.length, iv);
      input[input.length - 4] = (counter >> 24) & 0xFF;
      input[input.length - 3] = (counter >> 16) & 0xFF;
      input[input.length - 2] = (counter >> 8) & 0xFF;
      input[input.length - 1] = counter & 0xFF;
      stream.add(sha256.convert(input).bytes);
      counter++;
    }
    return Uint8List.fromList(stream.toBytes().sublist(0, length));
  }

  /// Read encrypted file, returns null if not exists
  static Future<String?> readEncrypted(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    if (!await file.exists()) {
      // Try reading unencrypted (migration)
      final plainFile = File('${dir.path}/${filename.replaceAll('.enc', '')}');
      if (await plainFile.exists()) {
        // Migrate: read plain, encrypt, delete plain
        final plain = await plainFile.readAsString();
        await writeEncrypted(filename, plain);
        await plainFile.delete();
        return plain;
      }
      return null;
    }
    try {
      final encrypted = await file.readAsString();
      return await decrypt(encrypted);
    } catch (e) {
      debugPrint('SecureStorage: decrypt error: $e');
      return null;
    }
  }

  /// Write encrypted file
  static Future<void> writeEncrypted(String filename, String data) async {
    final dir = await getApplicationDocumentsDirectory();
    final encrypted = await encrypt(data);
    await File('${dir.path}/$filename').writeAsString(encrypted);
  }
}
