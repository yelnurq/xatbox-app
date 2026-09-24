import 'package:sembast/sembast.dart';

import '../../../core/storage/app_database.dart';
import 'contact_models.dart';

class CachedDirectory {
  const CachedDirectory({required this.contacts, this.savedAt});
  final List<Contact> contacts;
  final DateTime? savedAt;
}

/// Last loaded directory page (≤ 1000 rows) and the department list for
/// offline reading. Bound to the user who loaded them, so another account
/// never sees a foreign list. Wiped on sign-out.
class ContactsCache {
  ContactsCache(this._db);

  final AppDatabase _db;
  static final _store = stringMapStoreFactory.store('contacts_directory');
  static const _key = 'directory';
  static const _departmentsKey = 'departments';

  Future<CachedDirectory?> read({required String ownerId}) async {
    if (ownerId.isEmpty) return null;
    final row = await _store.record(_key).get(_db.db);
    if (row == null || row['owner_id'] != ownerId) return null;
    final users = ((row['users'] as List?) ?? const [])
        .map((e) => Contact.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return CachedDirectory(
      contacts: users,
      savedAt: DateTime.tryParse((row['saved_at'] as String?) ?? ''),
    );
  }

  Future<void> write({
    required String ownerId,
    required List<Contact> contacts,
    required DateTime savedAt,
  }) async {
    if (ownerId.isEmpty) return;
    await _store.record(_key).put(_db.db, {
      'owner_id': ownerId,
      'saved_at': savedAt.toUtc().toIso8601String(),
      'users': [for (final c in contacts) c.toJson()],
    });
  }

  Future<List<Department>?> readDepartments({required String ownerId}) async {
    if (ownerId.isEmpty) return null;
    final row = await _store.record(_departmentsKey).get(_db.db);
    if (row == null || row['owner_id'] != ownerId) return null;
    return ((row['departments'] as List?) ?? const [])
        .map((e) => Department.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> writeDepartments({
    required String ownerId,
    required List<Department> departments,
  }) async {
    if (ownerId.isEmpty) return;
    await _store.record(_departmentsKey).put(_db.db, {
      'owner_id': ownerId,
      'departments': [for (final d in departments) d.toJson()],
    });
  }

  Future<void> clear() => _store.drop(_db.db);
}

/// Favourite colleagues: a local, per-account list (ids with a snapshot so a
/// favourite outside the loaded page still shows). Survives sign-out, like
/// device preferences; another account on the device never sees it.
class ContactsFavouritesStore {
  ContactsFavouritesStore(this._db);

  final AppDatabase _db;
  static final _store = stringMapStoreFactory.store('contacts_favourites');

  Future<List<Contact>> read({required String ownerId}) async {
    if (ownerId.isEmpty) return const [];
    final row = await _store.record(ownerId).get(_db.db);
    return ((row?['contacts'] as List?) ?? const [])
        .map((e) => Contact.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((c) => c.id.isNotEmpty)
        .toList();
  }

  Future<void> write({
    required String ownerId,
    required List<Contact> contacts,
  }) async {
    if (ownerId.isEmpty) return;
    await _store.record(ownerId).put(_db.db, {
      'contacts': [for (final c in contacts) c.toJson()],
    });
  }
}
