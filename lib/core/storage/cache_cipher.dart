import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';
import 'package:sembast/sembast.dart';

import '../../shared/utils/diagnostic_log.dart';

/// Encryption of the local cache file (`xatbox_cache.db`).
///
/// The cache holds the last pages of the mail folders, recently opened
/// messages, chats and the profile snapshot. A sign-out wipes all of it, but
/// while somebody is signed in it sits in their profile directory, and on a
/// shared university computer that directory is readable. Every record is
/// therefore written as AES-256-GCM, with a key that lives in the operating
/// system's own secret store (Keychain, Keystore, DPAPI, libsecret) and
/// never in the file.
///
/// Encryption is best effort by design: where the secret store cannot be
/// reached — a Linux session with no keyring, a device whose Keystore entry
/// was lost — the cache is opened unencrypted, exactly as before, because a
/// mail client that will not start is worse than a readable cache.
const cacheAad = 'xatbox-cache-v1';

/// Written into the database's metadata; a file with another signature is
/// not this codec's and is migrated (or dropped) rather than misread.
const cacheCodecSignature = 'xatbox-aes-gcm-v1';

const _nonceLength = 12;
const _tagBits = 128;
const cacheKeyLength = 32;

/// The key this install encrypts its cache with.
abstract class CacheKeyStore {
  /// The stored key, creating one on first use; null when the secret store
  /// cannot be used at all.
  Future<Uint8List?> readOrCreate();
}

class SecureCacheKeyStore implements CacheKeyStore {
  const SecureCacheKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? _default;

  static const _default = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    // The cache is read while the phone is still locked (a background sync,
    // a push), so the key has to be readable then too.
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  static const _key = 'xatbox.cache_key';
  final FlutterSecureStorage _storage;

  @override
  Future<Uint8List?> readOrCreate() async {
    try {
      final existing = await _storage.read(key: _key);
      if (existing != null) {
        final raw = base64.decode(existing);
        if (raw.length == cacheKeyLength) return raw;
        // A truncated or foreign value is replaced rather than trusted.
        await _storage.delete(key: _key);
      }
      final fresh = generateCacheKey();
      await _storage.write(key: _key, value: base64.encode(fresh));
      return fresh;
    } on Object catch (e) {
      DiagnosticLog.warn('cache', 'cache key unavailable (${e.runtimeType})');
      return null;
    }
  }
}

/// 32 random bytes from a CSPRNG.
Uint8List generateCacheKey() {
  final rnd = Random.secure();
  return Uint8List.fromList(
    List.generate(cacheKeyLength, (_) => rnd.nextInt(256)),
  );
}

/// The sembast codec: one AES-256-GCM box per record, `base64(nonce ||
/// ciphertext || tag)`, so a record that was tampered with fails to decode
/// instead of being read.
SembastCodec cacheCodec(Uint8List key) => SembastCodec(
  signature: cacheCodecSignature,
  codec: _CacheContentCodec(key),
);

class _CacheContentCodec extends Codec<Object?, String> {
  _CacheContentCodec(this.key)
    : assert(key.length == cacheKeyLength, 'cache key must be 32 bytes');

  final Uint8List key;

  @override
  Converter<Object?, String> get encoder => _CacheEncoder(key);

  @override
  Converter<String, Object?> get decoder => _CacheDecoder(key);
}

GCMBlockCipher _cipher(
  Uint8List key,
  Uint8List nonce, {
  required bool encrypt,
}) => GCMBlockCipher(AESEngine())
  ..init(
    encrypt,
    AEADParameters(
      KeyParameter(key),
      _tagBits,
      nonce,
      Uint8List.fromList(utf8.encode(cacheAad)),
    ),
  );

class _CacheEncoder extends Converter<Object?, String> {
  _CacheEncoder(this.key);
  final Uint8List key;

  @override
  String convert(Object? input) {
    final rnd = Random.secure();
    final nonce = Uint8List.fromList(
      List.generate(_nonceLength, (_) => rnd.nextInt(256)),
    );
    final plain = Uint8List.fromList(utf8.encode(json.encode(input)));
    final sealed = _cipher(key, nonce, encrypt: true).process(plain);
    return base64.encode(Uint8List.fromList([...nonce, ...sealed]));
  }
}

class _CacheDecoder extends Converter<String, Object?> {
  _CacheDecoder(this.key);
  final Uint8List key;

  @override
  Object? convert(String input) {
    final raw = base64.decode(input);
    if (raw.length < _nonceLength + _tagBits ~/ 8) {
      throw const FormatException('cache record too short');
    }
    final plain = _cipher(
      key,
      Uint8List.sublistView(raw, 0, _nonceLength),
      encrypt: false,
    ).process(Uint8List.sublistView(raw, _nonceLength));
    return json.decode(utf8.decode(plain));
  }
}
