import 'package:sembast/sembast.dart';

import '../../../core/storage/app_database.dart';

/// Recent queries of the unified search (newest first), on this device.
class RecentSearchStore {
  RecentSearchStore(this._db);

  final AppDatabase _db;
  static final _store = stringMapStoreFactory.store('search_recent');
  static const _key = 'queries';

  /// How many queries are kept.
  static const max = 8;

  Future<List<String>> read() async {
    final row = await _store.record(_key).get(_db.db);
    final items = row?['items'];
    return items is List ? items.whereType<String>().toList() : const [];
  }

  Future<void> write(List<String> queries) =>
      _store.record(_key).put(_db.db, {'items': queries});

  Future<void> clear() => _store.record(_key).delete(_db.db);

  /// [query] moved to the front, case-insensitive duplicates dropped (pure).
  static List<String> push(List<String> current, String query) {
    final q = query.trim();
    if (q.isEmpty) return current;
    return [
      q,
      ...current.where((c) => c.toLowerCase() != q.toLowerCase()),
    ].take(max).toList();
  }
}
