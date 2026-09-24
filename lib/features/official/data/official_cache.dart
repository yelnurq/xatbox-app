import 'package:sembast/sembast.dart';

import '../../../core/storage/app_database.dart';
import 'official_models.dart';

class CachedOfficialList {
  const CachedOfficialList({required this.messages, this.savedAt});
  final List<OfficialMessage> messages;
  final DateTime? savedAt;
}

/// Last loaded official messages (for offline reading) and the messages the
/// user sent from this device (to reopen their statistics). Bound to the
/// account that stored them; wiped on sign-out.
class OfficialCache {
  OfficialCache(this._db);

  final AppDatabase _db;
  static final _store = stringMapStoreFactory.store('official_messages');
  static const _listKey = 'list';
  static const _sentKey = 'sent';

  /// Local list of sent messages is capped (newest kept).
  static const maxSent = 100;

  Future<CachedOfficialList?> read({required String ownerId}) async {
    if (ownerId.isEmpty) return null;
    final row = await _store.record(_listKey).get(_db.db);
    if (row == null || row['owner_id'] != ownerId) return null;
    return CachedOfficialList(
      messages: ((row['messages'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => OfficialMessage.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      savedAt: DateTime.tryParse((row['saved_at'] as String?) ?? ''),
    );
  }

  Future<void> write({
    required String ownerId,
    required List<OfficialMessage> messages,
    required DateTime savedAt,
  }) async {
    if (ownerId.isEmpty) return;
    await _store.record(_listKey).put(_db.db, {
      'owner_id': ownerId,
      'saved_at': savedAt.toUtc().toIso8601String(),
      'messages': [for (final m in messages) m.toJson()],
    });
  }

  Future<List<SentOfficial>> readSent({required String ownerId}) async {
    if (ownerId.isEmpty) return const [];
    final row = await _store.record(_sentKey).get(_db.db);
    if (row == null || row['owner_id'] != ownerId) return const [];
    return ((row['sent'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => SentOfficial.fromJson(Map<String, dynamic>.from(e)))
        .where((s) => s.id.isNotEmpty)
        .toList();
  }

  Future<void> writeSent({
    required String ownerId,
    required List<SentOfficial> sent,
  }) async {
    if (ownerId.isEmpty) return;
    await _store.record(_sentKey).put(_db.db, {
      'owner_id': ownerId,
      'sent': [for (final s in sent.take(maxSent)) s.toJson()],
    });
  }

  Future<void> clear() => _store.drop(_db.db);
}
