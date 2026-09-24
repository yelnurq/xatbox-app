import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';

import '../../../shared/utils/diagnostic_log.dart';

/// Encrypted push payloads, wire format v1 (backend/platform/push/crypto.go).
///
/// FCM data of an encrypted push: `{"v": "1", "t": "chat"|"call"|"calendar"|"other",
/// "enc": base64(nonce(12) || ciphertext || tag(16))}`. `enc` is AES-256-GCM
/// with AAD [pushPayloadAad] over a JSON object of string values — the same
/// keys an unencrypted push carried in its data (type, title, body, ids…)
/// plus sender_name, conversation_title, chat_type, channel, tag, silent.
const pushPayloadAad = 'xatbox-push-v1';
const encryptedPushVersion = '1';
const _nonceLength = 12;
const _tagBits = 128;
const pushKeyLength = 32;

bool isEncryptedPush(Map<String, dynamic> data) =>
    data['v'] == encryptedPushVersion && data['enc'] is String;

/// Decrypts `enc` with [key]. Throws on a wrong key, tampering or bad input.
Map<String, dynamic> decryptPushPayload(Uint8List key, String enc) {
  if (key.length != pushKeyLength) {
    throw ArgumentError('push key must be $pushKeyLength bytes');
  }
  final raw = base64.decode(enc);
  if (raw.length < _nonceLength + _tagBits ~/ 8) {
    throw const FormatException('push payload too short');
  }
  final cipher = GCMBlockCipher(AESEngine())
    ..init(
      false,
      AEADParameters(
        KeyParameter(key),
        _tagBits,
        Uint8List.sublistView(raw, 0, _nonceLength),
        Uint8List.fromList(utf8.encode(pushPayloadAad)),
      ),
    );
  final plain = cipher.process(Uint8List.sublistView(raw, _nonceLength));
  final decoded = jsonDecode(utf8.decode(plain));
  if (decoded is! Map) throw const FormatException('push payload is not an object');
  return {
    for (final e in decoded.entries)
      if (e.value is String) e.key.toString(): e.value,
  };
}

/// Base64 of 32 random bytes from a CSPRNG.
String generatePushKey() {
  final rnd = Random.secure();
  return base64.encode(
    Uint8List.fromList(List.generate(pushKeyLength, (_) => rnd.nextInt(256))),
  );
}

/// This install's push key. Created on the first device registration, removed
/// on sign-out (the next sign-in registers a fresh key).
abstract class PushKeyStore {
  /// Stored key, null when there is none (or it is unreadable).
  Future<Uint8List?> read();

  /// Base64 key, created and stored when missing.
  Future<String> readOrCreate();

  Future<void> clear();
}

class SecurePushKeyStore implements PushKeyStore {
  SecurePushKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? (Platform.isIOS ? _shared : _private),
      _fallback = storage == null && Platform.isIOS ? _private : null;

  /// iOS keychain access group shared with the Notification Service
  /// Extension (ios/NotificationService), which decrypts alert pushes with
  /// this key. It is the App Group id (docs/IOS.md); builds without the App
  /// Group entitlement fall back to the app's private keychain.
  static const iosKeychainGroup = 'group.kz.xatbox.xatboxMobile';

  static const _private = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    // Readable while locked: pushes arrive in the pocket.
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    // macOS: the login keychain (see SecureTokenStorage).
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  static const _shared = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      groupId: iosKeychainGroup,
    ),
  );

  static const _key = 'xatbox.push_key';
  final FlutterSecureStorage _storage;

  /// iOS only: the private keychain (older installs, missing entitlement).
  final FlutterSecureStorage? _fallback;

  @override
  Future<Uint8List?> read() async {
    final fallback = _fallback;
    try {
      final key = _decode(await _storage.read(key: _key));
      if (key != null || fallback == null) return key;
    } on Object catch (e) {
      if (fallback == null) {
        DiagnosticLog.warn('push', 'push key unreadable (${e.runtimeType})');
        return null;
      }
    }
    try {
      final legacy = await fallback.read(key: _key);
      final key = _decode(legacy);
      // Move a key of an older install to the shared group (best effort) so
      // the extension can read it.
      if (key != null) unawaited(_moveToShared(legacy!, fallback));
      return key;
    } on Object catch (e) {
      DiagnosticLog.warn('push', 'push key unreadable (${e.runtimeType})');
      return null;
    }
  }

  Future<void> _moveToShared(String value, FlutterSecureStorage from) async {
    try {
      await _storage.write(key: _key, value: value);
      await from.delete(key: _key);
    } on Object {
      // No App Group entitlement: the key stays private.
    }
  }

  @override
  Future<String> readOrCreate() async {
    final existing = await read();
    if (existing != null) return base64.encode(existing);
    final key = generatePushKey();
    // A restored backup without its Keystore entry must not block a new key.
    for (final s in [_storage, ?_fallback]) {
      try {
        await s.delete(key: _key);
      } on Object {
        // ignore: nothing to remove
      }
    }
    try {
      await _storage.write(key: _key, value: key);
    } on Object catch (e) {
      final fallback = _fallback;
      if (fallback == null) rethrow;
      DiagnosticLog.warn(
        'push',
        'shared keychain unavailable (${e.runtimeType}); private key used',
      );
      await fallback.write(key: _key, value: key);
    }
    return key;
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _key);
    try {
      await _fallback?.delete(key: _key);
    } on Object {
      // ignore: nothing to remove
    }
  }
}

class InMemoryPushKeyStore implements PushKeyStore {
  InMemoryPushKeyStore([this._value]);
  String? _value;

  @override
  Future<Uint8List?> read() async => _decode(_value);

  @override
  Future<String> readOrCreate() async => _value ??= generatePushKey();

  @override
  Future<void> clear() async => _value = null;
}

Uint8List? _decode(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    final key = base64.decode(value);
    return key.length == pushKeyLength ? key : null;
  } on FormatException {
    return null;
  }
}

/// The logical data of a push: unencrypted data as is, encrypted data
/// decrypted with this install's key. Null when it cannot be read (no key
/// after sign-out, rotated key, tampering) — such a push is dropped. Contents
/// are never logged.
Future<Map<String, dynamic>?> resolvePushData(
  Map<String, dynamic> data, {
  PushKeyStore? keys,
}) async {
  if (!isEncryptedPush(data)) {
    // A future format this build cannot read: drop instead of showing junk.
    if (data.containsKey('enc')) return null;
    return data;
  }
  final key = await (keys ?? SecurePushKeyStore()).read();
  if (key == null) {
    DiagnosticLog.warn('push', 'encrypted push without a local key; dropped');
    return null;
  }
  try {
    return decryptPushPayload(key, data['enc'] as String);
  } on Object catch (e) {
    DiagnosticLog.warn('push', 'push decryption failed (${e.runtimeType}); dropped');
    return null;
  }
}
