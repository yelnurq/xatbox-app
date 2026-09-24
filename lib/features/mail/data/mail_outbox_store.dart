import 'package:sembast/sembast.dart';

import '../../../core/storage/app_database.dart';
import 'mail_models.dart';

/// A letter sent while the desktop app had no network, waiting in
/// «Исходящие» to go out when the connection returns.
class MailOutboxItem {
  const MailOutboxItem({
    required this.id,
    required this.request,
    required this.queuedAt,
    this.draftId,
    this.failed = false,
    this.sending = false,
    this.error,
  });

  final String id;
  final MailSendRequest request;
  final DateTime queuedAt;

  /// The draft copy to delete once the letter is sent (undo-send flow).
  final String? draftId;

  /// The server refused it (not a network failure): no automatic retry.
  final bool failed;

  /// Being sent right now (not stored).
  final bool sending;

  /// Why it was refused, while the app runs (not stored).
  final Object? error;

  MailOutboxItem copyWith({bool? failed, bool? sending, Object? error, bool clearError = false}) => MailOutboxItem(
    id: id,
    request: request,
    queuedAt: queuedAt,
    draftId: draftId,
    failed: failed ?? this.failed,
    sending: sending ?? this.sending,
    error: clearError ? null : (error ?? this.error),
  );

  Map<String, Object?> toJson() => {
    'request': request.toJson(),
    'queued_at': queuedAt.toUtc().toIso8601String(),
    'draft_id': ?draftId,
    'failed': failed,
  };

  static MailOutboxItem fromJson(String id, Map<String, Object?> json) => MailOutboxItem(
    id: id,
    request: MailSendRequest.fromJson(Map<String, dynamic>.from(json['request']! as Map)),
    queuedAt: DateTime.tryParse((json['queued_at'] as String?) ?? '') ?? DateTime.now().toUtc(),
    draftId: json['draft_id'] as String?,
    failed: json['failed'] == true,
  );
}

/// The desktop mail outbox in the app database. Kept apart from MailCache:
/// «Очистить кэш» must not drop letters that were never sent.
class MailOutboxStore {
  MailOutboxStore(this._db);

  final AppDatabase _db;
  static final _store = stringMapStoreFactory.store('mail_outbox');

  /// Oldest first (the order they were sent in).
  Future<List<MailOutboxItem>> all() async {
    final records = await _store.find(_db.db);
    final items = <MailOutboxItem>[];
    for (final r in records) {
      try {
        items.add(MailOutboxItem.fromJson(r.key, r.value));
      } on Object {
        // A record of an older layout: skip it rather than block the queue.
      }
    }
    items.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
    return items;
  }

  Future<void> put(MailOutboxItem item) => _store.record(item.id).put(_db.db, item.toJson());

  Future<void> remove(String id) => _store.record(id).delete(_db.db);

  Future<void> clear() => _store.delete(_db.db);
}
