import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Password storage uses PBKDF2-HMAC-SHA256 with a unique random salt.
/// Plaintext passwords are never written to the database or logs.
class PasswordHasher {
  PasswordHasher._();

  static const int iterations = 120000;
  static final Random _random = Random.secure();

  static Future<({String salt, String hash})> hash(String password) async {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final salt = base64Url.encode(bytes);
    final result = await compute<List<String>, String>(_derive, [
      password,
      salt,
      '$iterations',
    ]);
    return (salt: salt, hash: result);
  }

  static Future<bool> verify({
    required String password,
    required String salt,
    required String expectedHash,
  }) async {
    final actual = await compute<List<String>, String>(_derive, [
      password,
      salt,
      '$iterations',
    ]);
    final a = utf8.encode(actual);
    final b = utf8.encode(expectedHash);
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }

  /// Derives key material for encrypted backup files with the file's salt.
  static Future<List<int>> deriveKey(
    String password,
    List<int> saltBytes,
  ) async {
    final encodedSalt = base64Url.encode(saltBytes);
    final encodedKey = await compute<List<String>, String>(_derive, [
      password,
      encodedSalt,
      '$iterations',
    ]);
    return base64Url.decode(encodedKey);
  }

  static String _derive(List<String> args) {
    final password = utf8.encode(args[0]);
    final salt = base64Url.decode(args[1]);
    final count = int.tryParse(args[2]) ?? iterations;
    final hmac = Hmac(sha256, password);
    final block = <int>[...salt, 0, 0, 0, 1];
    var u = hmac.convert(block).bytes;
    final result = List<int>.from(u);
    for (var i = 1; i < count; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return base64Url.encode(result);
  }
}
