import 'package:sembast/sembast.dart';

import 'app_database.dart';

/// Limits for the local mail cache (ТЗ п.24.16). User-adjustable through
/// [CacheSettingsStore]; modules read the current policy from it.
class CachePolicy {
  const CachePolicy({
    this.maxListItemsPerFolder = 50,
    this.maxCachedMessages = 30,
    this.maxAge = const Duration(days: 14),
  });

  /// How many list rows are kept per folder (one page).
  final int maxListItemsPerFolder;

  /// How many opened message bodies are kept (LRU by last open time).
  final int maxCachedMessages;

  /// Entries older than this are dropped on the next sweep.
  final Duration maxAge;

  static const presets = <int>[10, 30, 100];

  CachePolicy copyWith({int? maxCachedMessages}) => CachePolicy(
    maxListItemsPerFolder: maxListItemsPerFolder,
    maxCachedMessages: maxCachedMessages ?? this.maxCachedMessages,
    maxAge: maxAge,
  );
}

/// Persists the user's cache limit choice.
class CacheSettingsStore {
  CacheSettingsStore(this._db);

  final AppDatabase _db;
  static final _store = stringMapStoreFactory.store('settings');
  static const _key = 'cache';

  Future<CachePolicy> read() async {
    final json = await _store.record(_key).get(_db.db);
    if (json == null) return const CachePolicy();
    final max = json['max_cached_messages'];
    return CachePolicy(maxCachedMessages: max is int ? max : 30);
  }

  Future<void> write(CachePolicy policy) => _store.record(_key).put(_db.db, {
    'max_cached_messages': policy.maxCachedMessages,
  });
}
