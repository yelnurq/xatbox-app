import 'dart:convert';

import 'package:sembast/utils/database_utils.dart';

import '../../../core/storage/app_database.dart';
import 'chat_models.dart';
import 'media_auto_download.dart';

/// Local chat cache (ТЗ п.13, п.24.16): the conversation list, the most
/// recent messages per conversation (bounded), the outbox, drafts and the
/// sync cursor per conversation. Never the whole history.
///
/// Messages live in one sembast store per conversation (`chat_msgs:<id>`,
/// key = zero-padded seq), so reads, trims and receipts touch only that
/// conversation. Conversations are mirrored in memory after the first read.
class ChatCache {
  ChatCache(this._db, {int? maxMessagesPerConversation})
    : _limit = maxMessagesPerConversation ?? chatMessageLimitDefault,
      _limitLoaded = maxMessagesPerConversation != null;

  final AppDatabase _db;
  int _limit;
  bool _limitLoaded;

  /// Current layout of the message stores (see [_migrate]).
  static const schemaVersion = 2;
  static const _schemaKey = 'schema_version';

  /// Rows written to a conversation since its last trim; trimming runs once
  /// this many rows have accumulated instead of after every write.
  static const trimSlack = 20;

  /// Device preferences kept in the meta store; they survive [clear].
  static const prefMediaAutoDownload = 'pref:media_auto_download';
  static const prefMessagesLimit = 'pref:messages_per_conversation';
  static const prefRecentEmoji = 'pref:recent_emoji';

  /// «Запись голосовых»: hold (default) or tap to record.
  static const prefVoiceRecordMode = 'pref:voice_record_mode';
  static const _prefKeys = [
    prefMediaAutoDownload,
    prefMessagesLimit,
    prefRecentEmoji,
    prefVoiceRecordMode,
  ];

  int get maxMessagesPerConversation => _limit;
  set maxMessagesPerConversation(int v) {
    _limit = v;
    _limitLoaded = true;
  }

  /// The user's "messages kept per conversation" (persisted).
  Future<int> messageLimit() async {
    if (!_limitLoaded) {
      final stored = int.tryParse(await readMeta(prefMessagesLimit) ?? '');
      if (stored != null && stored > 0) _limit = stored;
      _limitLoaded = true;
    }
    return _limit;
  }

  /// Persists a new limit and trims every conversation to it.
  Future<void> setMessageLimit(int limit) async {
    maxMessagesPerConversation = limit;
    await writeMeta(prefMessagesLimit, '$limit');
    await _ready();
    for (final name in _messageStoreNames()) {
      await trim(name.substring(_msgStorePrefix.length));
    }
  }

  Future<MediaAutoDownload> mediaAutoDownload() async =>
      MediaAutoDownload.parse(await readMeta(prefMediaAutoDownload));

  Future<void> setMediaAutoDownload(MediaAutoDownload v) =>
      writeMeta(prefMediaAutoDownload, v.storageValue);

  static final _convStore = stringMapStoreFactory.store('chat_conversations');
  static final _legacyMsgStore = stringMapStoreFactory.store('chat_messages');
  static final _outbox = stringMapStoreFactory.store('chat_outbox');
  static final _meta = stringMapStoreFactory.store('chat_meta');
  static const _msgStorePrefix = 'chat_msgs:';

  static StoreRef<String, Map<String, Object?>> _msgStore(String convId) =>
      stringMapStoreFactory.store('$_msgStorePrefix$convId');

  static String _msgKey(int seq) => seq.toString().padLeft(12, '0');

  Iterable<String> _messageStoreNames() => getNonEmptyStoreNames(
    _db.db,
  ).where((n) => n.startsWith(_msgStorePrefix)).toList();

  // ---- schema --------------------------------------------------------------------

  Future<void>? _migration;
  Future<void> _ready() => _migration ??= _migrate();

  /// v1 kept every message in one `chat_messages` store keyed `conv:seq`
  /// (reads scanned all conversations with a regex). v2 moves the rows into
  /// per-conversation stores once; the old store is dropped.
  Future<void> _migrate() async {
    final row = await _meta.record(_schemaKey).get(_db.db);
    final version = (row?['value'] as num?)?.toInt() ?? 1;
    if (version >= schemaVersion) return;
    if (await _legacyMsgStore.count(_db.db) == 0) {
      // Fresh install or already empty: nothing to move.
      await _meta.record(_schemaKey).put(_db.db, {'value': schemaVersion});
      return;
    }
    await _db.db.transaction((txn) async {
      final rows = await _legacyMsgStore.find(txn);
      for (final r in rows) {
        final conv = r.value['conversation_id'];
        final seq = (r.value['seq'] as num?)?.toInt() ?? 0;
        if (conv is! String || conv.isEmpty || seq <= 0) continue;
        await _msgStore(conv).record(_msgKey(seq)).put(txn, r.value);
      }
      await _legacyMsgStore.drop(txn);
      await _meta.record(_schemaKey).put(txn, {'value': schemaVersion});
    });
  }

  // ---- conversations -----------------------------------------------------------

  /// Decoded conversations; loaded once, then kept in step with every write.
  Map<String, ChatConversation>? _convs;

  Future<Map<String, ChatConversation>> _conversationMap() async {
    final cached = _convs;
    if (cached != null) return cached;
    final rows = await _convStore.find(_db.db);
    final map = {
      for (final r in rows)
        r.key: ChatConversation.fromJson(Map<String, dynamic>.from(r.value)),
    };
    return _convs ??= map;
  }

  /// «Избранное» first, then pinned, then by last activity.
  Future<List<ChatConversation>> conversations() async {
    final list = (await _conversationMap()).values.toList();
    list.sort(compareConversations);
    return list;
  }

  static int compareConversations(ChatConversation a, ChatConversation b) {
    if (a.isSaved != b.isSaved) return a.isSaved ? -1 : 1;
    // «Заявки» (desktop) right after «Избранное».
    if (a.isRequests != b.isRequests) return a.isRequests ? -1 : 1;
    if (a.settings.pinned != b.settings.pinned) {
      return a.settings.pinned ? -1 : 1;
    }
    return (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0));
  }

  Future<ChatConversation?> conversation(String id) async =>
      (await _conversationMap())[id];

  Future<void> putConversation(ChatConversation c) async {
    await _convStore.record(c.id).put(_db.db, c.toJson());
    _convs?[c.id] = c;
  }

  Future<void> putConversations(List<ChatConversation> list) async {
    if (list.isEmpty) return;
    await _db.db.transaction((txn) async {
      for (final c in list) {
        await _convStore.record(c.id).put(txn, c.toJson());
      }
    });
    final mirror = _convs;
    if (mirror != null) {
      for (final c in list) {
        mirror[c.id] = c;
      }
    }
  }

  Future<void> removeConversation(String id) async {
    await _ready();
    await _db.db.transaction((txn) async {
      await _convStore.record(id).delete(txn);
      await _msgStore(id).drop(txn);
    });
    _convs?.remove(id);
    _sinceTrim.remove(id);
  }

  /// Sync cursor: the last event seq applied locally for a conversation.
  Future<int> syncedSeq(String convId) async {
    final row = await _meta.record('seq:$convId').get(_db.db);
    return (row?['seq'] as num?)?.toInt() ?? 0;
  }

  Future<void> setSyncedSeq(String convId, int seq) =>
      _meta.record('seq:$convId').put(_db.db, {'seq': seq});

  // ---- messages ----------------------------------------------------------------------

  /// The newest [limit] messages of a conversation, ascending by seq.
  Future<List<ChatMessage>> messages(String convId, {int? limit}) async {
    await _ready();
    limit ??= await messageLimit();
    final rows = await _msgStore(convId).find(
      _db.db,
      finder: Finder(sortOrders: [SortOrder(Field.key, false)], limit: limit),
    );
    return [
      for (final r in rows.reversed)
        ChatMessage.fromJson(Map<String, dynamic>.from(r.value)),
    ];
  }

  Future<ChatMessage?> message(String convId, int seq) async {
    await _ready();
    final row = await _msgStore(convId).record(_msgKey(seq)).get(_db.db);
    return row == null
        ? null
        : ChatMessage.fromJson(Map<String, dynamic>.from(row));
  }

  Future<ChatMessage?> messageById(String convId, String id) async {
    await _ready();
    final row = await _msgStore(convId).findFirst(
      _db.db,
      finder: Finder(filter: Filter.equals('id', id)),
    );
    return row == null
        ? null
        : ChatMessage.fromJson(Map<String, dynamic>.from(row.value));
  }

  /// Own messages up to [upToSeq] that are not fully read yet (receipts).
  Future<List<ChatMessage>> ownUnreadUpTo(
    String convId,
    String selfId,
    int upToSeq,
  ) async {
    await _ready();
    final rows = await _msgStore(convId).find(
      _db.db,
      finder: Finder(
        filter: Filter.and([
          Filter.equals('sender_id', selfId),
          Filter.lessThanOrEquals('seq', upToSeq),
          Filter.notEquals('status', 'read'),
        ]),
      ),
    );
    return [
      for (final r in rows)
        ChatMessage.fromJson(Map<String, dynamic>.from(r.value)),
    ];
  }

  /// Stores messages (one transaction); trims a conversation only after
  /// [trimSlack] new rows.
  Future<void> putMessages(List<ChatMessage> msgs) async {
    if (msgs.isEmpty) return;
    await _ready();
    final touched = <String, int>{};
    await _db.db.transaction((txn) async {
      for (final m in msgs) {
        if (m.seq <= 0 || m.conversationId.isEmpty) continue;
        await _msgStore(
          m.conversationId,
        ).record(_msgKey(m.seq)).put(txn, m.toJson());
        touched[m.conversationId] = (touched[m.conversationId] ?? 0) + 1;
      }
    });
    for (final e in touched.entries) {
      final n = (_sinceTrim[e.key] ?? 0) + e.value;
      if (n >= trimSlack) {
        await trim(e.key);
      } else {
        _sinceTrim[e.key] = n;
      }
    }
  }

  final Map<String, int> _sinceTrim = {};

  Future<void> putMessage(ChatMessage m) => putMessages([m]);

  /// Drops one message (by id) from a conversation's store («Удалить у
  /// меня»). True when a row was removed.
  Future<bool> removeMessage(String convId, String messageId) async {
    await _ready();
    final store = _msgStore(convId);
    final key = await store.findKey(
      _db.db,
      finder: Finder(filter: Filter.equals('id', messageId)),
    );
    if (key == null) return false;
    await store.record(key).delete(_db.db);
    return true;
  }

  /// Keeps only the newest [maxMessagesPerConversation] rows of a conversation.
  Future<void> trim(String convId) async {
    _sinceTrim.remove(convId);
    await _ready();
    final keep = await messageLimit();
    final store = _msgStore(convId);
    final keys = await store.findKeys(
      _db.db,
      finder: Finder(sortOrders: [SortOrder(Field.key, false)], offset: keep),
    );
    if (keys.isEmpty) return;
    await store.records(keys).delete(_db.db);
  }

  // ---- outbox --------------------------------------------------------------------------

  Future<List<OutboxItem>> outbox({String? convId}) async {
    final rows = await _outbox.find(
      _db.db,
      finder: Finder(
        filter: convId == null
            ? null
            : Filter.equals('conversation_id', convId),
        sortOrders: [SortOrder('created_at')],
      ),
    );
    return rows
        .map((r) => OutboxItem.fromJson(Map<String, dynamic>.from(r.value)))
        .toList();
  }

  Future<void> putOutbox(OutboxItem item) =>
      _outbox.record(item.clientMessageId).put(_db.db, item.toJson());

  Future<void> removeOutbox(String clientMessageId) =>
      _outbox.record(clientMessageId).delete(_db.db);

  // ---- drafts -----------------------------------------------------------------------------

  static String _draftKey(String convId) => 'draft:$convId';

  Future<String> draft(String convId) async =>
      await readMeta(_draftKey(convId)) ?? '';

  /// Stores (or, for blank text, removes) the composer draft of a chat.
  Future<void> setDraft(String convId, String text) async {
    if (text.trim().isEmpty) {
      await _meta.record(_draftKey(convId)).delete(_db.db);
    } else {
      await writeMeta(_draftKey(convId), text);
    }
  }

  /// All drafts: conversation id → text.
  Future<Map<String, String>> drafts() async {
    final rows = await _meta.find(
      _db.db,
      finder: Finder(
        filter: Filter.custom((r) => (r.key as String).startsWith('draft:')),
      ),
    );
    return {
      for (final r in rows)
        if (r.value['value'] is String)
          r.key.substring('draft:'.length): r.value['value']! as String,
    };
  }

  // ---- recent emoji -------------------------------------------------------------------

  static const recentEmojiMax = 24;

  Future<List<String>> recentEmoji() async {
    final raw = await readMeta(prefRecentEmoji);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } on Object {
      return const [];
    }
  }

  /// Moves [emoji] to the front of the recent list (bounded).
  Future<List<String>> pushRecentEmoji(String emoji) async {
    final list = [emoji, ...(await recentEmoji()).where((e) => e != emoji)];
    final bounded = list.take(recentEmojiMax).toList();
    await writeMeta(prefRecentEmoji, jsonEncode(bounded));
    return bounded;
  }

  // ---- misc ------------------------------------------------------------------------------

  Future<String?> readMeta(String key) async {
    final row = await _meta.record(key).get(_db.db);
    final v = row?['value'];
    return v is String ? v : null;
  }

  Future<void> writeMeta(String key, String value) =>
      _meta.record(key).put(_db.db, {'value': value});

  Future<ChatCacheStats> stats() async {
    await _ready();
    var messages = 0;
    for (final name in _messageStoreNames()) {
      messages += await stringMapStoreFactory.store(name).count(_db.db);
    }
    return ChatCacheStats(
      conversations: await _convStore.count(_db.db),
      messages: messages,
      outbox: await _outbox.count(_db.db),
    );
  }

  /// Wipes chat data (sign-out / Settings). The device id survives so push
  /// registrations stay stable across sign-ins; so do device preferences
  /// (media auto-download, messages kept per conversation, recent emoji).
  Future<void> clear({bool keepDeviceId = true}) async {
    await _ready();
    final deviceId = keepDeviceId ? await readMeta('device_id') : null;
    final prefs = {for (final k in _prefKeys) k: await readMeta(k)};
    await _db.db.transaction((txn) async {
      await _convStore.delete(txn);
      for (final name in _messageStoreNames()) {
        await stringMapStoreFactory.store(name).drop(txn);
      }
      await _outbox.delete(txn);
      await _meta.delete(txn);
      await _meta.record(_schemaKey).put(txn, {'value': schemaVersion});
    });
    _convs = null;
    _sinceTrim.clear();
    if (deviceId != null) await writeMeta('device_id', deviceId);
    for (final e in prefs.entries) {
      if (e.value != null) await writeMeta(e.key, e.value!);
    }
  }
}

class ChatCacheStats {
  const ChatCacheStats({
    required this.conversations,
    required this.messages,
    required this.outbox,
  });
  final int conversations;
  final int messages;
  final int outbox;
}
