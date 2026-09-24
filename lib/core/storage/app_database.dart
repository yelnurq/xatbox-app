import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/utils/sembast_import_export.dart';

import '../../shared/utils/diagnostic_log.dart';
import 'cache_cipher.dart';

/// Local database (sembast). Holds only indexes, the last pages of mail
/// folders, a few recently opened messages and the profile snapshot — never
/// the whole mailbox (ТЗ п.24.16).
///
/// The file lives in the app-private support directory (ТЗ п.24.24) and its
/// records are encrypted with a key from the operating system's secret store
/// (see [cacheCodec]); where that store cannot be reached the database is
/// opened as it always was.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static Future<AppDatabase> open({
    CacheKeyStore keys = const SecureCacheKeyStore(),
  }) async {
    final dir = await getApplicationSupportDirectory();
    return openAt(p.join(dir.path, 'xatbox_cache.db'), keys: keys);
  }

  /// [open] once the file is known; used directly by the tests.
  @visibleForTesting
  static Future<AppDatabase> openAt(
    String path, {
    CacheKeyStore keys = const SecureCacheKeyStore(),
  }) async {
    final key = await keys.readOrCreate();
    if (key == null) {
      // No secret store: the cache is opened exactly as it was before it
      // was ever encrypted, and the app works.
      return AppDatabase._(await databaseFactoryIo.openDatabase(path));
    }
    return AppDatabase._(await _openEncrypted(path, cacheCodec(key)));
  }

  /// Opens the encrypted cache, bringing an older plaintext one over on the
  /// first run. A cache that can be read neither way — the key of a previous
  /// install is gone, the file is damaged — is dropped: everything in it is
  /// a copy of what the server still has.
  static Future<Database> _openEncrypted(
    String path,
    SembastCodec codec,
  ) async {
    try {
      return await databaseFactoryIo.openDatabase(path, codec: codec);
    } on Object catch (e) {
      DiagnosticLog.warn(
        'cache',
        'encrypted cache not opened (${e.runtimeType})',
      );
    }
    try {
      final plain = await databaseFactoryIo.openDatabase(path);
      final export = await exportDatabase(plain);
      await plain.close();
      // importDatabase removes the destination first, so the plaintext file
      // is gone once this returns.
      final migrated = await importDatabase(
        export,
        databaseFactoryIo,
        path,
        codec: codec,
      );
      DiagnosticLog.info('cache', 'cache migrated to an encrypted file');
      return migrated;
    } on Object catch (e) {
      DiagnosticLog.warn('cache', 'cache dropped (${e.runtimeType})');
      await databaseFactoryIo.deleteDatabase(path);
      return databaseFactoryIo.openDatabase(path, codec: codec);
    }
  }

  /// In-memory database for tests.
  static Future<AppDatabase> inMemory() async =>
      AppDatabase._(await newDatabaseFactoryMemory().openDatabase('test.db'));

  Future<void> close() => db.close();
}
