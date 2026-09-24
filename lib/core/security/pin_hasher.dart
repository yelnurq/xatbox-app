import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256 for the local app-lock PIN. The PIN itself is never
/// stored; only salt + derived key, and those only in secure storage.
abstract final class PinHasher {
  static const defaultIterations = 20000;
  static const keyLength = 32;

  static Uint8List newSalt([Random? random]) {
    final rnd = random ?? Random.secure();
    return Uint8List.fromList(List<int>.generate(16, (_) => rnd.nextInt(256)));
  }

  static Uint8List derive(
    String pin,
    List<int> salt,
    int iterations, {
    int length = keyLength,
  }) {
    final hmac = Hmac(sha256, utf8.encode(pin));
    final out = BytesBuilder(copy: false);
    for (var block = 1; out.length < length; block++) {
      var u = hmac.convert([
        ...salt,
        (block >> 24) & 0xff,
        (block >> 16) & 0xff,
        (block >> 8) & 0xff,
        block & 0xff,
      ]).bytes;
      final t = Uint8List.fromList(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      out.add(t);
    }
    return Uint8List.sublistView(out.takeBytes(), 0, length);
  }

  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
