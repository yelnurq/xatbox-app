import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:xatbox_mobile/core/storage/app_database.dart';
import 'package:xatbox_mobile/core/storage/cache_cipher.dart';

/// A key store that answers from memory: the real one talks to the
/// Keychain / Keystore, which a unit test has none of.
class _FixedKeys implements CacheKeyStore {
  _FixedKeys(this.key);
  final Uint8List? key;

  @override
  Future<Uint8List?> readOrCreate() async => key;
}

void main() {
  late Directory tmp;
  late String path;
  final key = generateCacheKey();

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('xatbox_cache_test');
    path = '${tmp.path}/xatbox_cache.db';
    addTearDown(() => tmp.delete(recursive: true));
  });

  final store = StoreRef<String, Object?>.main();

  test('the mail on disk is not readable as text', () async {
    final db = await AppDatabase.openAt(path, keys: _FixedKeys(key));
    await store.record('msg').put(db.db, {
      'subject': 'Приказ об отпуске',
      'from': 'rector@kaztbu.edu.kz',
    });
    await db.close();

    final onDisk = await File(path).readAsString();
    expect(onDisk, isNot(contains('Приказ')));
    expect(onDisk, isNot(contains('rector@kaztbu.edu.kz')));
    // sembast stores the signature sealed with the same codec, so the file
    // announces that it has one without naming it.
    expect(onDisk, contains('"codec":'));

    final reopened = await AppDatabase.openAt(path, keys: _FixedKeys(key));
    expect(await store.record('msg').get(reopened.db), {
      'subject': 'Приказ об отпуске',
      'from': 'rector@kaztbu.edu.kz',
    });
    await reopened.close();
  });

  test('an older plaintext cache is carried over, not thrown away', () async {
    final plain = await databaseFactoryIo.openDatabase(path);
    await store.record('folder').put(plain, {'inbox': 42});
    await plain.close();
    expect(await File(path).readAsString(), contains('inbox'));

    final db = await AppDatabase.openAt(path, keys: _FixedKeys(key));
    expect(await store.record('folder').get(db.db), {'inbox': 42});
    await db.close();

    // …and what was carried over is encrypted from then on.
    expect(await File(path).readAsString(), isNot(contains('inbox')));
  });

  test(
    'a cache written under a key this install no longer has is dropped',
    () async {
      final old = await AppDatabase.openAt(path, keys: _FixedKeys(key));
      await store.record('msg').put(old.db, {'subject': 'Приказ'});
      await old.close();

      final db = await AppDatabase.openAt(
        path,
        keys: _FixedKeys(generateCacheKey()),
      );
      // Empty, and usable: everything in the cache is a copy of what the
      // server still has.
      expect(await store.record('msg').get(db.db), isNull);
      await store.record('msg').put(db.db, {'subject': 'Новый'});
      expect(await store.record('msg').get(db.db), {'subject': 'Новый'});
      await db.close();
    },
  );

  test('without a secret store the cache still opens', () async {
    final db = await AppDatabase.openAt(path, keys: _FixedKeys(null));
    await store.record('msg').put(db.db, {'subject': 'Приказ'});
    expect(await store.record('msg').get(db.db), {'subject': 'Приказ'});
    await db.close();
    // Unencrypted, exactly as before — a mail client that will not start
    // would be worse.
    expect(await File(path).readAsString(), contains('Приказ'));
  });

  group('the record codec', () {
    test('a record survives a round trip', () {
      final codec = cacheCodec(key).codec!;
      const value = {
        'subject': 'Хат',
        'unread': true,
        'count': 3,
        'tags': ['a', 'b'],
        'nested': {'x': null},
      };
      expect(codec.decode(codec.encode(value)), value);
    });

    test('every write gets its own nonce', () {
      final codec = cacheCodec(key).codec!;
      const value = {'subject': 'Хат'};
      expect(codec.encode(value), isNot(codec.encode(value)));
    });

    test('a tampered record is refused, not read', () {
      final codec = cacheCodec(key).codec!;
      final sealed = base64.decode(codec.encode({'admin': false}));
      // Flip a bit in the ciphertext; GCM's tag is what catches it.
      sealed[sealed.length - 20] ^= 0x01;
      expect(() => codec.decode(base64.encode(sealed)), throwsA(isA<Object>()));
    });

    test('another install cannot read this one', () {
      final mine = cacheCodec(key).codec!;
      final theirs = cacheCodec(generateCacheKey()).codec!;
      final sealed = mine.encode({'subject': 'Приказ'});
      expect(() => theirs.decode(sealed), throwsA(isA<Object>()));
    });
  });
}
