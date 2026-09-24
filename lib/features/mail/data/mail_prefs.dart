import 'package:sembast/sembast.dart';

import '../../../core/storage/app_database.dart';

/// Local mail UI preferences. Not a cache: survives "Clear cache".
class MailPrefsStore {
  MailPrefsStore(this._db);

  final AppDatabase _db;
  static final _store = stringMapStoreFactory.store('mail_prefs');
  static const _key = 'list';

  /// Conversation (`threads=1`) list mode; [fallback] until the user
  /// has chosen (desktop: on, as the web lists conversations).
  Future<bool> readThreadsMode({bool fallback = false}) async {
    final json = await _store.record(_key).get(_db.db);
    final saved = json?['threads'];
    return saved is bool ? saved : fallback;
  }

  Future<void> writeThreadsMode(bool enabled) =>
      _store.record(_key).put(_db.db, {'threads': enabled}, merge: true);

  static const _uxKey = 'ux';
  static const _recentKey = 'recent_recipients';

  /// Swipe actions and the undo-send delay (raw map, see `MailUxSettings`).
  Future<Map<String, Object?>> readUx() async =>
      Map<String, Object?>.of(await _store.record(_uxKey).get(_db.db) ?? const {});

  Future<void> writeUx(Map<String, Object?> values) =>
      _store.record(_uxKey).put(_db.db, values, merge: true);

  /// Recently used recipient addresses, most recent first.
  Future<List<String>> readRecentRecipients() async {
    final json = await _store.record(_recentKey).get(_db.db);
    return ((json?['addresses'] as List?) ?? const []).whereType<String>().toList();
  }

  Future<void> writeRecentRecipients(List<String> addresses) =>
      _store.record(_recentKey).put(_db.db, {'addresses': addresses});

  Future<void> clearRecentRecipients() => _store.record(_recentKey).delete(_db.db);
}
