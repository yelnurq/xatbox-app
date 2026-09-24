import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/websocket/realtime_client.dart';
import '../../../shared/utils/diagnostic_log.dart';
import 'chat_api.dart';
import 'chat_cache.dart';
import 'chat_models.dart';

/// Orchestrates REST, WebSocket and the local cache:
/// * cache-first reads, network refresh;
/// * one [events] stream for every change (live frames and delta-sync rows);
/// * delta sync per conversation after every (re)connect (ТЗ п.5.4, п.24.17);
/// * a persistent outbox flushed idempotently (same client_message_id);
/// * delivered acks and read marks.
class ChatRepository {
  ChatRepository({
    required ChatApi api,
    required ChatCache cache,
    required RealtimeClient socket,
    required String Function() selfId,
    Future<Directory> Function()? mediaRoot,
  }) : _api = api, // ignore: prefer_initializing_formals
       _cache = cache, // ignore: prefer_initializing_formals
       _socket = socket, // ignore: prefer_initializing_formals
       _selfId = selfId, // ignore: prefer_initializing_formals
       _mediaRoot = mediaRoot ?? getApplicationSupportDirectory {
    _socketSub = _socket.frames.listen(_onFrame);
    _statusSub = _socket.status.listen(_onStatus);
  }

  final ChatApi _api;
  final ChatCache _cache;
  final RealtimeClient _socket;
  final String Function() _selfId;

  /// Parent of the `chat_media` directory (app support dir; a temp dir in tests).
  final Future<Directory> Function() _mediaRoot;

  /// Cached group avatars are re-validated after this age.
  static const avatarMaxAge = Duration(hours: 24);

  final _events = StreamController<ChatEvent>.broadcast();
  final _syncState = StreamController<bool>.broadcast();
  final _pendingAcks = <String>{};
  Timer? _ackTimer;
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  StreamSubscription<RealtimeStatus>? _statusSub;
  bool _flushing = false;
  bool _syncing = false;
  static const _uuid = Uuid();

  Stream<ChatEvent> get events => _events.stream;
  Stream<RealtimeStatus> get connection => _socket.status;
  RealtimeStatus get connectionStatus => _socket.current;
  Stream<int?> get socketCloses => _socket.closes;

  /// True while a delta sync is running (UI shows "updating…").
  Stream<bool> get syncing => _syncState.stream;
  ChatCache get cache => _cache;
  ChatApi get api => _api;
  String get selfId => _selfId();

  void start() => _socket.start();
  Future<void> stop() => _socket.stop();
  void kick() => _socket.kick();

  Future<void> dispose() async {
    await _socketSub?.cancel();
    await _statusSub?.cancel();
    _ackTimer?.cancel();
    await _events.close();
    await _syncState.close();
  }

  // ---- socket plumbing ----------------------------------------------------------

  void _onStatus(RealtimeStatus s) {
    if (s == RealtimeStatus.connected) {
      unawaited(syncAll());
      unawaited(flushOutbox());
    }
  }

  void _onFrame(Map<String, dynamic> frame) {
    final type = frame['type'];
    if (type is! String || type.isEmpty) return;
    if (type.startsWith('auth.') || type == 'pong' || type == 'error') return;
    final ev = ChatEvent.fromFrame(frame);
    if (isEphemeral(type)) {
      // Typing / recording / call signalling never touch the cache.
      if (!_events.isClosed) _events.add(ev);
      return;
    }
    unawaited(_apply(ev, fromLive: true));
  }

  /// Frames that only matter to the live UI (no cache write, no seq).
  static bool isEphemeral(String type) =>
      type.startsWith('typing.') ||
      type.startsWith('voice_recording.') ||
      type.startsWith('call.') ||
      // Folders of the user's other devices: no conversation data.
      type == 'chat_folders.updated';

  /// Applies an event to the cache and republishes it. Durable events carry a
  /// seq; the cursor advances only when the sequence is contiguous, otherwise
  /// a delta sync fills the gap.
  Future<void> _apply(ChatEvent ev, {required bool fromLive}) async {
    if (ev.conversationId.isNotEmpty && ev.seq > 0) {
      final synced = await _cache.syncedSeq(ev.conversationId);
      if (fromLive && synced > 0 && ev.seq > synced + 1) {
        // Missed something: fetch the gap through the log instead.
        unawaited(syncConversation(ev.conversationId));
        return;
      }
      if (ev.seq <= synced && fromLive) return; // already applied
    }
    await _applyToCache(ev);
    if (ev.seq > 0 && ev.conversationId.isNotEmpty) {
      await _cache.setSyncedSeq(ev.conversationId, ev.seq);
    }
    if (!_events.isClosed) _events.add(ev);
  }

  Future<void> _applyToCache(ChatEvent ev) async {
    switch (ev.type) {
      case 'message.created':
        final m = ev.message;
        if (m == null) return;
        // Channel post comments live in their thread only: no feed row, no
        // unread, no last message (the post's count comes with
        // `post.comments`).
        if (m.isComment) {
          await _bumpSeq(ev);
          return;
        }
        await _cache.putMessage(m);
        if (m.senderId != selfId && !m.isSystem) _queueAck(m.id);
        // Own message that was in the outbox: drop the queued copy.
        if (m.senderId == selfId) await _cache.removeOutbox(m.clientMessageId);
        final conv = await _cache.conversation(m.conversationId);
        if (conv != null) {
          final unread = m.senderId == selfId || m.isSystem
              ? conv.unread
              : conv.unread + 1;
          await _cache.putConversation(
            conv.copyWith(
              lastMessage: m,
              lastSeq: ev.seq,
              updatedAt: m.createdAt,
              unread: unread,
            ),
          );
        } else {
          await _refreshConversation(m.conversationId);
        }
      // Disappearing message expired on the server: gone for everyone.
      case 'message.deleted' when ev.payload['expired'] == true:
        await _cache.removeMessage(ev.conversationId, ev.messageId);
        await _bumpSeq(ev);
        final conv = await _cache.conversation(ev.conversationId);
        if (conv?.lastMessage?.id == ev.messageId) {
          await _refreshConversation(ev.conversationId);
        }
      case 'message.updated' ||
          'message.deleted' ||
          'message.reaction' ||
          'message.delivered' ||
          'message.link_preview' ||
          'message.transcript' ||
          'poll.updated' ||
          'post.comments':
        final cur = await _cache.messageById(ev.conversationId, ev.messageId);
        final next = cur == null ? null : applyToMessage(cur, ev, selfId);
        if (next != null) {
          await _cache.putMessage(next);
          final conv = await _cache.conversation(ev.conversationId);
          if (conv != null && conv.lastMessage?.id == next.id) {
            await _cache.putConversation(conv.copyWith(lastMessage: next));
          }
        }
        await _bumpSeq(ev);
      case 'message.hidden':
        // «Удалить у меня» from this or another device of the user.
        if (ev.userId.isNotEmpty && ev.userId != selfId) return;
        await _cache.removeMessage(ev.conversationId, ev.messageId);
        await _bumpSeq(ev);
        final conv = await _cache.conversation(ev.conversationId);
        if (conv?.lastMessage?.id == ev.messageId) {
          await _refreshConversation(ev.conversationId);
        }
      case 'message.read':
        final upTo = (ev.payload['up_to_seq'] as num?)?.toInt() ?? 0;
        if (ev.userId == selfId) {
          final conv = await _cache.conversation(ev.conversationId);
          if (conv != null) {
            await _cache.putConversation(
              conv.copyWith(
                unread: 0,
                settings: conv.settings.copyWith(lastReadSeq: upTo),
              ),
            );
          }
        } else {
          // Other member read up to seq: our own messages ≤ seq gain a read.
          // Only those rows are read and rewritten (one transaction).
          final msgs = await _cache.ownUnreadUpTo(
            ev.conversationId,
            selfId,
            upTo,
          );
          final updated = [
            for (final m in msgs)
              if (m.senderId == selfId && m.seq <= upTo && m.status != 'read')
                applyRead(m),
          ];
          if (updated.isNotEmpty) await _cache.putMessages(updated);
        }
        await _bumpSeq(ev);
      case 'chat.updated':
        final change = ev.payload['change'];
        final conv = await _cache.conversation(ev.conversationId);
        if ((change == 'members_removed' || change == 'member_left') &&
            ev.userId == selfId) {
          await _cache.removeConversation(ev.conversationId);
        } else if (change == 'marked_unread' &&
            conv != null &&
            ev.payload['marked_unread'] is bool) {
          await _cache.putConversation(
            conv.copyWith(
              settings: conv.settings.copyWith(
                markedUnread: ev.payload['marked_unread'] as bool,
              ),
            ),
          );
        } else {
          if (change == 'avatar') await _dropAvatar(ev.conversationId);
          await _refreshConversation(ev.conversationId);
        }
      case 'presence.changed':
        await _applyPresence(
          ev.userId,
          ev.payload['online'] == true,
          status: ev.payload.containsKey('status')
              ? (ChatUserStatus.fromJsonOrNull(ev.payload['status']),)
              : null,
        );
      case 'user.status':
        await _applyStatus(
          ev.userId,
          ChatUserStatus.fromJsonOrNull(ev.payload['status']),
        );
      default:
        break; // typing.* / voice_recording.* are UI-only
    }
  }

  Future<void> _bumpSeq(ChatEvent ev) async {
    final conv = await _cache.conversation(ev.conversationId);
    if (conv != null && ev.seq > conv.lastSeq) {
      await _cache.putConversation(conv.copyWith(lastSeq: ev.seq));
    }
  }

  /// Updates only the conversations that contain [userId], in one batch.
  /// [status] (a record, so "cleared" differs from "not sent") comes with
  /// newer `presence.changed` frames.
  Future<void> _applyPresence(
    String userId,
    bool online, {
    (ChatUserStatus?,)? status,
  }) async {
    if (userId.isEmpty) return;
    final changedList = <ChatConversation>[];
    for (final c in await _cache.conversations()) {
      final next = applyUserToConversation(
        c,
        userId,
        online: online,
        status: status,
      );
      if (!identical(next, c)) changedList.add(next);
    }
    await _cache.putConversations(changedList);
  }

  /// `user.status`: the status of [userId] on every cached peer / member.
  Future<void> _applyStatus(String userId, ChatUserStatus? status) async {
    if (userId.isEmpty) return;
    final changedList = <ChatConversation>[];
    for (final c in await _cache.conversations()) {
      final next = applyUserToConversation(c, userId, status: (status,));
      if (!identical(next, c)) changedList.add(next);
    }
    await _cache.putConversations(changedList);
  }

  /// Pure fold of a presence and/or status change of [userId] into a
  /// conversation; returns [c] itself when the user is not in it.
  static ChatConversation applyUserToConversation(
    ChatConversation c,
    String userId, {
    bool? online,
    (ChatUserStatus?,)? status,
  }) {
    var conv = c;
    final peer = c.peer;
    if (peer != null && peer.userId == userId) {
      var p = peer;
      if (online != null) {
        p = p.copyWith(
          online: online,
          lastSeenAt: online ? null : DateTime.now().toUtc(),
        );
      }
      if (status != null) {
        p = p.copyWith(status: status.$1, clearStatus: status.$1 == null);
      }
      conv = conv.copyWith(peer: p);
    }
    if (c.members.any((m) => m.userId == userId)) {
      conv = conv.copyWith(
        members: [
          for (final m in c.members)
            if (m.userId != userId)
              m
            else
              m.copyWith(
                online: online,
                status: status?.$1,
                clearStatus: status != null && status.$1 == null,
              ),
        ],
      );
    }
    return conv;
  }

  /// Pure fold of an edit / delete / reaction / delivery event into a
  /// message (shared by the cache and the open conversation). Null when the
  /// event does not change it.
  static ChatMessage? applyToMessage(
    ChatMessage cur,
    ChatEvent ev,
    String selfId,
  ) {
    switch (ev.type) {
      case 'message.updated':
        return cur.copyWith(
          body: (ev.payload['body'] as String?) ?? cur.body,
          editedAt: DateTime.now().toUtc(),
        );
      case 'message.deleted':
        return cur.copyWith(body: '', deletedAt: DateTime.now().toUtc());
      case 'message.reaction':
        return cur.copyWith(
          reactions: applyReaction(
            cur.reactions,
            (ev.payload['reaction'] as String?) ?? '',
            ev.userId,
            ev.payload['active'] == true,
            selfId,
          ),
        );
      case 'message.transcript':
        final raw = ev.payload['transcript'];
        return raw is Map
            ? cur.copyWith(
                transcript: ChatTranscript.fromJson(
                  raw.cast<String, dynamic>(),
                ),
              )
            : null;
      case 'message.link_preview':
        final raw = ev.payload['link_preview'];
        if (raw is Map) {
          return cur.copyWith(
            linkPreview: ChatLinkPreview.fromJson(raw.cast<String, dynamic>()),
          );
        }
        return cur.linkPreview == null
            ? null
            : cur.copyWith(clearLinkPreview: true);
      case 'post.comments':
        final count = (ev.payload['comment_count'] as num?)?.toInt();
        return count == null || count == cur.commentCount
            ? null
            : cur.copyWith(commentCount: count);
      case 'poll.updated':
        // Results of a poll; the copy for other members has no my_votes.
        final raw = ev.payload['poll'];
        if (raw is! Map) return null;
        final update = ChatPoll.fromJson(raw.cast<String, dynamic>());
        return cur.copyWith(poll: cur.poll?.mergeUpdate(update) ?? update);
      case 'message.delivered':
        if (cur.senderId != selfId) return null;
        final delivered = cur.deliveredCount + 1;
        return cur.copyWith(
          deliveredCount: delivered,
          status: cur.status == 'read'
              ? 'read'
              : (delivered >= cur.recipientCount && cur.recipientCount > 0
                    ? 'delivered'
                    : cur.status),
        );
    }
    return null;
  }

  /// One more member read an own message.
  static ChatMessage applyRead(ChatMessage m) {
    final read = m.readCount + 1;
    return m.copyWith(
      readCount: read,
      status: read >= m.recipientCount && m.recipientCount > 0
          ? 'read'
          : m.status,
    );
  }

  /// Pure reaction fold, unit-tested.
  static List<ChatReaction> applyReaction(
    List<ChatReaction> current,
    String reaction,
    String userId,
    bool active,
    String selfId,
  ) {
    final out = <ChatReaction>[];
    var found = false;
    for (final r in current) {
      if (r.reaction != reaction) {
        out.add(r);
        continue;
      }
      found = true;
      final users = r.userIds.where((u) => u != userId).toList();
      if (active) users.add(userId);
      if (users.isNotEmpty) {
        out.add(
          ChatReaction(
            reaction: reaction,
            count: users.length,
            userIds: users,
            me: users.contains(selfId),
          ),
        );
      }
    }
    if (!found && active) {
      out.add(
        ChatReaction(
          reaction: reaction,
          count: 1,
          userIds: [userId],
          me: userId == selfId,
        ),
      );
    }
    return out;
  }

  Future<void> _refreshConversation(String id) async {
    try {
      final conv = await _api.getChat(id);
      await _cache.putConversation(conv);
    } on ApiException catch (e) {
      if (e.statusCode == 404) await _cache.removeConversation(id);
    } on AppException catch (e) {
      DiagnosticLog.warn('chat', 'conversation refresh failed', error: e);
    }
  }

  // ---- delivered acks -----------------------------------------------------------------

  void _queueAck(String messageId) {
    _pendingAcks.add(messageId);
    _ackTimer ??= Timer(const Duration(milliseconds: 300), _flushAcks);
  }

  void _flushAcks() {
    _ackTimer = null;
    if (_pendingAcks.isEmpty) return;
    final ids = _pendingAcks.toList();
    _pendingAcks.clear();
    if (_socket.isConnected) {
      _socket.send({'type': 'ack.delivered', 'message_ids': ids});
    } else {
      // REST fallback (one by one, best effort).
      for (final id in ids) {
        unawaited(
          _api
              .markDelivered(id)
              .catchError(
                (Object e) => DiagnosticLog.warn(
                  'chat',
                  'delivered ack failed',
                  error: e,
                ),
              ),
        );
      }
    }
  }

  // ---- sync --------------------------------------------------------------------------------

  /// Reloads the conversation list and replays missed events per conversation.
  Future<void> syncAll() async {
    if (_syncing) return;
    _syncing = true;
    _syncState.add(true);
    try {
      final list = await loadConversations(fromNetwork: true);
      for (final c in list) {
        final synced = await _cache.syncedSeq(c.id);
        if (c.lastSeq > synced) await syncConversation(c.id, known: c);
      }
    } on AppException catch (e) {
      DiagnosticLog.warn('chat', 'sync failed', error: e);
    } finally {
      _syncing = false;
      _syncState.add(false);
    }
  }

  /// Delta sync for one conversation: replay the event log after the local
  /// cursor. When the cursor is unknown (fresh install) or too far behind,
  /// load the latest page instead.
  Future<void> syncConversation(String id, {ChatConversation? known}) async {
    try {
      final synced = await _cache.syncedSeq(id);
      final conv = known ?? await _api.getChat(id);
      if (synced == 0 || conv.lastSeq - synced > 500) {
        final page = await _api.listMessages(id, limit: 50);
        await _cache.putMessages(page);
        await _cache.putConversation(conv);
        await _cache.setSyncedSeq(id, conv.lastSeq);
        _events.add(
          ChatEvent(
            type: 'sync.reloaded',
            conversationId: id,
            seq: 0,
            payload: const {},
          ),
        );
        return;
      }
      var cursor = synced;
      while (cursor < conv.lastSeq) {
        final batch = await _api.listEvents(id, afterSeq: cursor);
        if (batch.isEmpty) break;
        for (final ev in batch) {
          await _apply(ev, fromLive: false);
          cursor = ev.seq;
        }
      }
      await _cache.setSyncedSeq(id, conv.lastSeq);
      await _refreshConversation(id);
      _events.add(
        ChatEvent(
          type: 'sync.done',
          conversationId: id,
          seq: 0,
          payload: const {},
        ),
      );
    } on AppException catch (e) {
      DiagnosticLog.warn('chat', 'conversation sync failed', error: e);
    }
  }

  // ---- conversations ---------------------------------------------------------------

  Future<List<ChatConversation>> cachedConversations() =>
      _cache.conversations();

  Future<List<ChatConversation>> loadConversations({
    bool fromNetwork = true,
  }) async {
    if (!fromNetwork) return _cache.conversations();
    final all = <ChatConversation>[];
    String? cursor;
    do {
      final page = await _api.listChats(cursor: cursor, withRequests: true);
      all.addAll(page.chats);
      cursor = page.nextCursor.isEmpty ? null : page.nextCursor;
    } while (cursor != null && all.length < 500);
    // Drop conversations that vanished server-side (left / removed). The
    // default list omits archived chats, so those are kept.
    final ids = all.map((c) => c.id).toSet();
    for (final c in await _cache.conversations()) {
      if (!ids.contains(c.id) && !c.settings.archived) {
        await _cache.removeConversation(c.id);
      }
    }
    await _cache.putConversations(all);
    return _cache.conversations();
  }

  /// Archived chats (`GET /chats?archived=1` returns every chat including
  /// the archived ones; only those are kept). Stored in the cache so they
  /// open instantly.
  Future<List<ChatConversation>> loadArchived() async {
    final all = <ChatConversation>[];
    String? cursor;
    do {
      final page = await _api.listChats(
        cursor: cursor,
        archived: true,
        withRequests: true,
      );
      all.addAll(page.chats.where((c) => c.settings.archived));
      cursor = page.nextCursor.isEmpty ? null : page.nextCursor;
    } while (cursor != null && all.length < 500);
    await _cache.putConversations(all);
    return all..sort(ChatCache.compareConversations);
    // (callers reload the list from the cache)
  }

  Future<ChatConversation?> conversation(
    String id, {
    bool refresh = false,
  }) async {
    if (!refresh) {
      final cached = await _cache.conversation(id);
      if (cached != null) return cached;
    }
    await _refreshConversation(id);
    return _cache.conversation(id);
  }

  Future<ChatConversation> createDirect(String userId) async {
    final conv = await _api.createDirect(userId);
    await _cache.putConversation(conv);
    await _cache.setSyncedSeq(conv.id, conv.lastSeq);
    return conv;
  }

  Future<ChatConversation> createGroup(
    String title,
    List<String> memberIds,
  ) async {
    final conv = await _api.createGroup(title, memberIds);
    await _cache.putConversation(conv);
    await _cache.setSyncedSeq(conv.id, conv.lastSeq);
    return conv;
  }

  Future<ChatConversation> patchChat(
    String id, {
    String? title,
    DateTime? mutedUntil,
    bool unmute = false,
    bool? pinned,
    bool? archived,
    String? pinnedMessageId,
    bool clearPinned = false,
    bool? markedUnread,
    String? description,
  }) async {
    final conv = await _api.patchChat(
      id,
      title: title,
      mutedUntil: mutedUntil,
      unmute: unmute,
      pinned: pinned,
      archived: archived,
      pinnedMessageId: pinnedMessageId,
      clearPinned: clearPinned,
      markedUnread: markedUnread,
      description: description,
    );
    await _cache.putConversation(conv);
    _events.add(
      ChatEvent(
        type: 'chat.local',
        conversationId: id,
        seq: 0,
        payload: const {},
      ),
    );
    return conv;
  }

  Future<ChatConversation> addMember(String chatId, String userId) async {
    final conv = await _api.addMember(chatId, userId);
    await _cache.putConversation(conv);
    return conv;
  }

  Future<void> removeMember(String chatId, String userId) async {
    await _api.removeMember(chatId, userId);
    if (userId == selfId) {
      await _cache.removeConversation(chatId);
      _events.add(
        ChatEvent(
          type: 'chat.local',
          conversationId: chatId,
          seq: 0,
          payload: const {},
        ),
      );
    } else {
      await _refreshConversation(chatId);
    }
  }

  Future<void> setRole(String chatId, String userId, String role) async {
    await _api.setRole(chatId, userId, role);
    await _refreshConversation(chatId);
  }

  Future<List<ChatUser>> searchUsers(String q) => _api.searchUsers(q);

  // ---- «Заявки» ---------------------------------------------------------------------------

  /// Files a request (`POST /requests`) and stores the message right away;
  /// the bot's confirmation arrives over the socket.
  Future<ChatMessage> submitRequest({
    required String what,
    required String room,
    required String date,
  }) async {
    final msg = await _api.submitRequest(
      clientMessageId: const Uuid().v4(),
      what: what,
      room: room,
      date: date,
    );
    // The live event may already have stored it; apply again is harmless.
    await _apply(
      ChatEvent(
        type: 'message.created',
        conversationId: msg.conversationId,
        seq: msg.seq,
        payload: {'message': msg.toJson()},
      ),
      fromLive: false,
    );
    return msg;
  }

  // ---- «Избранное», mark unread, description, media -------------------------------------

  /// The caller's «Избранное»: the cached one, otherwise created / fetched
  /// with `POST /chats/saved`.
  Future<ChatConversation> savedConversation() async {
    for (final c in await _cache.conversations()) {
      if (c.isSaved) return c;
    }
    final conv = await _api.ensureSaved();
    await _cache.putConversation(conv);
    if (await _cache.syncedSeq(conv.id) == 0) {
      await _cache.setSyncedSeq(conv.id, conv.lastSeq);
    }
    _events.add(
      ChatEvent(
        type: 'chat.local',
        conversationId: conv.id,
        seq: 0,
        payload: const {},
      ),
    );
    return conv;
  }

  /// Forwards [messages] (oldest first) into «Избранное».
  Future<ChatConversation> saveToSaved(List<ChatMessage> messages) async {
    final saved = await savedConversation();
    final ordered = [...messages]..sort((a, b) => a.seq.compareTo(b.seq));
    for (final m in ordered) {
      if (m.seq <= 0) continue;
      await sendText(saved.id, '', forwardOfId: m.id);
    }
    return saved;
  }

  /// «Пометить как непрочитанное» / clears the flag.
  Future<ChatConversation> markUnread(String convId, bool value) =>
      patchChat(convId, markedUnread: value);

  Future<ChatConversation> setDescription(String convId, String text) =>
      patchChat(convId, description: text.trim());

  /// «Удалить у меня»: hidden on the server for this user, dropped locally.
  Future<void> hideMessage(ChatMessage m) async {
    await _api.hideMessage(m.id);
    await _applyToCache(
      ChatEvent(
        type: 'message.hidden',
        conversationId: m.conversationId,
        seq: 0,
        payload: {'message_id': m.id, 'user_id': selfId},
      ),
    );
    if (!_events.isClosed) {
      _events.add(
        ChatEvent(
          type: 'message.hidden',
          conversationId: m.conversationId,
          seq: 0,
          payload: {'message_id': m.id, 'user_id': selfId},
        ),
      );
    }
  }

  /// One page of the media / files / links / voice listing.
  Future<({List<ChatMediaEntry> items, String nextCursor})> listMedia(
    String convId, {
    required ChatMediaKind kind,
    String? cursor,
    int limit = 30,
  }) => _api.listMedia(convId, kind: kind, cursor: cursor, limit: limit);

  /// The proxied link preview picture on disk (downloaded once).
  Future<File> linkPreviewImageFile(ChatMessage m) async {
    final dir = Directory(p.join((await _mediaDir()).path, 'link_previews'));
    final file = File(p.join(dir.path, '${_safeName(m.id)}.jpg'));
    if (await file.exists() && await file.length() > 0) return file;
    await dir.create(recursive: true);
    final tmp = File('${file.path}.part');
    await _api.downloadLinkPreviewImage(m.id, savePath: tmp.path);
    return tmp.rename(file.path);
  }

  /// The link preview picture when it is already on disk (no network).
  Future<File?> cachedLinkPreviewImage(ChatMessage m) async {
    try {
      final file = File(
        p.join((await _mediaDir()).path, 'link_previews', '${_safeName(m.id)}.jpg'),
      );
      if (await file.exists() && await file.length() > 0) return file;
    } on FileSystemException {
      return null;
    }
    return null;
  }

  // ---- messages --------------------------------------------------------------------------

  /// Cached tail plus queued outbox items for a conversation.
  Future<List<ChatMessage>> cachedMessages(String convId) async {
    final msgs = await _cache.messages(convId);
    final pending = (await _cache.outbox(convId: convId))
        .map((o) => o.toPendingMessage(selfId));
    return [...msgs, ...pending];
  }

  /// Loads the newest page from the server and stores it.
  Future<List<ChatMessage>> loadLatest(String convId) async {
    final page = await _api.listMessages(convId, limit: 50);
    await _cache.putMessages(page);
    final conv = await _cache.conversation(convId);
    if (conv != null && page.isNotEmpty) {
      await _cache.setSyncedSeq(
        convId,
        conv.lastSeq > page.last.seq ? conv.lastSeq : page.last.seq,
      );
    }
    return page;
  }

  /// Older history (cursor pagination upwards, ТЗ п.24.7). Not cached beyond
  /// the tail: history is re-fetched when needed.
  Future<List<ChatMessage>> loadOlder(
    String convId, {
    required int beforeSeq,
    int limit = 50,
  }) => _api.listMessages(convId, beforeSeq: beforeSeq, limit: limit);

  Future<ChatMessage> getMessage(String id) => _api.getMessage(id);

  /// A message by id: the cached copy when present, otherwise the server.
  Future<ChatMessage> findMessage(String convId, String id) async =>
      await _cache.messageById(convId, id) ?? await _api.getMessage(id);

  Future<List<ChatReceipt>> receipts(String messageId) =>
      _api.receipts(messageId);

  Future<void> markRead(ChatMessage m) async {
    final conv = await _cache.conversation(m.conversationId);
    if (conv != null && conv.settings.lastReadSeq >= m.seq) return;
    try {
      await _api.markRead(m.id);
      if (conv != null) {
        await _cache.putConversation(
          conv.copyWith(
            unread: 0,
            settings: conv.settings.copyWith(lastReadSeq: m.seq),
          ),
        );
        _events.add(
          ChatEvent(
            type: 'chat.local',
            conversationId: m.conversationId,
            seq: 0,
            payload: const {},
          ),
        );
      }
    } on AppException catch (e) {
      DiagnosticLog.warn('chat', 'mark read failed', error: e);
    }
  }

  Future<void> toggleReaction(ChatMessage m, String reaction) =>
      _api.toggleReaction(m.id, reaction);
  Future<ChatMessage> editMessage(String id, String body) =>
      _api.editMessage(id, body);
  Future<void> deleteMessage(String id) => _api.deleteMessage(id);
  Future<List<ChatMessage>> search(String q, {String? conversationId}) async {
    final hits = await _api.search(q, conversationId: conversationId);
    // Older servers ignore the filter: narrow on the client as well.
    return conversationId == null
        ? hits
        : hits.where((m) => m.conversationId == conversationId).toList();
  }

  // ---- drafts ------------------------------------------------------------------------------

  Future<String> draft(String convId) => _cache.draft(convId);
  Future<Map<String, String>> drafts() => _cache.drafts();
  Future<void> setDraft(String convId, String text) =>
      _cache.setDraft(convId, text);

  void typing(String convId, {bool started = true, String kind = 'typing'}) {
    if (_socket.isConnected) {
      _socket.send({
        'type': '$kind.${started ? 'start' : 'stop'}',
        'conversation_id': convId,
      });
    }
  }

  // ---- sending (outbox) ------------------------------------------------------------------

  /// Queues a text message and tries to send immediately. The placeholder is
  /// visible at once with `pending` (ТЗ п.24.17).
  Future<OutboxItem> sendText(
    String convId,
    String body, {
    String? replyToId,
    String? forwardOfId,
    List<String> mentions = const [],
  }) async {
    final item = OutboxItem(
      clientMessageId: _uuid.v4(),
      conversationId: convId,
      type: 'text',
      body: body,
      createdAt: DateTime.now().toUtc(),
      replyToId: replyToId,
      forwardOfId: forwardOfId,
      mentions: mentions,
    );
    await _cache.putOutbox(item);
    _events.add(
      ChatEvent(
        type: 'outbox.queued',
        conversationId: convId,
        seq: 0,
        payload: {'client_message_id': item.clientMessageId},
      ),
    );
    unawaited(flushOutbox());
    return item;
  }

  /// Queues a colleague card (`type: contact`, body `{"user_id": …}`).
  Future<OutboxItem> sendContact(String convId, ChatContact contact) async {
    final item = OutboxItem(
      clientMessageId: _uuid.v4(),
      conversationId: convId,
      type: 'contact',
      body: contact.toMessageBody(),
      createdAt: DateTime.now().toUtc(),
      contact: contact,
    );
    await _cache.putOutbox(item);
    _events.add(
      ChatEvent(
        type: 'outbox.queued',
        conversationId: convId,
        seq: 0,
        payload: {'client_message_id': item.clientMessageId},
      ),
    );
    unawaited(flushOutbox());
    return item;
  }

  /// Queues a sticker (`type: sticker`, body `{"sticker_id": …}`).
  Future<OutboxItem> sendSticker(String convId, ChatSticker sticker) async {
    final item = OutboxItem(
      clientMessageId: _uuid.v4(),
      conversationId: convId,
      type: 'sticker',
      body: sticker.toMessageBody(),
      createdAt: DateTime.now().toUtc(),
    );
    await _cache.putOutbox(item);
    _events.add(
      ChatEvent(
        type: 'outbox.queued',
        conversationId: convId,
        seq: 0,
        payload: {'client_message_id': item.clientMessageId},
      ),
    );
    unawaited(flushOutbox());
    return item;
  }

  /// Stores a conversation returned by another endpoint (e.g. protection)
  /// and tells the open screens.
  Future<void> putConversationLocal(ChatConversation conv) async {
    await _cache.putConversation(conv);
    if (_events.isClosed) return;
    _events.add(
      ChatEvent(
        type: 'chat.local',
        conversationId: conv.id,
        seq: 0,
        payload: const {},
      ),
    );
  }

  /// Queues a file/voice message; the file is uploaded during the flush.
  Future<OutboxItem> sendFile(
    String convId, {
    required String filePath,
    required String filename,
    bool voice = false,
    int? durationMs,
    String body = '',
  }) async {
    final item = OutboxItem(
      clientMessageId: _uuid.v4(),
      conversationId: convId,
      type: voice ? 'voice' : 'file',
      body: body,
      createdAt: DateTime.now().toUtc(),
      localFilePath: filePath,
      localFileName: filename,
      voice: voice,
      durationMs: durationMs,
    );
    await _cache.putOutbox(item);
    _events.add(
      ChatEvent(
        type: 'outbox.queued',
        conversationId: convId,
        seq: 0,
        payload: {'client_message_id': item.clientMessageId},
      ),
    );
    unawaited(flushOutbox());
    return item;
  }

  Future<void> retryOutbox(String clientMessageId) async {
    final items = await _cache.outbox();
    for (final it in items) {
      if (it.clientMessageId == clientMessageId) {
        await _cache.putOutbox(it.copyWith(failed: false, attempts: 0));
      }
    }
    await flushOutbox();
  }

  Future<void> discardOutbox(String clientMessageId, String convId) async {
    await _cache.removeOutbox(clientMessageId);
    _events.add(
      ChatEvent(
        type: 'outbox.removed',
        conversationId: convId,
        seq: 0,
        payload: {'client_message_id': clientMessageId},
      ),
    );
  }

  /// Set when a flush is requested while one runs (e.g. a text queued during
  /// a file upload); the running flush then makes another pass.
  bool _flushAgain = false;

  /// Sends queued items in order. Network failures keep the item queued;
  /// 4xx answers mark it failed (user can retry or discard).
  Future<void> flushOutbox() async {
    if (_flushing) {
      _flushAgain = true;
      return;
    }
    _flushing = true;
    try {
      var completed = true;
      do {
        _flushAgain = false;
        completed = await _flushPass();
      } while (completed && _flushAgain);
    } finally {
      _flushing = false;
    }
  }

  /// One pass over the outbox; false when it stopped early (offline or a
  /// transient server error), so the queue waits for the next trigger.
  Future<bool> _flushPass() async {
    {
      for (final item in await _cache.outbox()) {
        if (item.failed) continue;
        var current = item;
        try {
          if (current.localFilePath != null && current.attachmentIds.isEmpty) {
            final att = await _api.upload(
              current.conversationId,
              filePath: current.localFilePath!,
              filename:
                  current.localFileName ?? p.basename(current.localFilePath!),
              voice: current.voice,
              durationMs: current.durationMs,
            );
            current = current.copyWith(attachmentIds: [att.id]);
            await _cache.putOutbox(current);
          }
          final msg = await _api.sendMessage(
            current.conversationId,
            clientMessageId: current.clientMessageId,
            type: current.type == 'file' || current.type == 'voice'
                ? _typeFor(current)
                : current.type,
            body: current.body,
            replyToId: current.replyToId,
            forwardOfId: current.forwardOfId,
            attachmentIds: current.attachmentIds,
            mentions: current.mentions,
          );
          await _cache.removeOutbox(current.clientMessageId);
          if (current.localFilePath != null) {
            _deleteQuietly(current.localFilePath!);
          }
          // The live event may already have stored it; apply again is harmless.
          await _apply(
            ChatEvent(
              type: 'message.created',
              conversationId: msg.conversationId,
              seq: msg.seq,
              payload: {'message': msg.toJson()},
            ),
            fromLive: false,
          );
        } on NetworkException {
          return false; // offline: keep the queue, resume on reconnect
        } on ApiException catch (e) {
          if (e.statusCode == 429 || e.statusCode >= 500) return false; // transient
          DiagnosticLog.warn('chat', 'outbox item rejected', error: e);
          await _cache.putOutbox(
            current.copyWith(
              failed: true,
              errorCode: e.code,
              attempts: current.attempts + 1,
            ),
          );
          _events.add(
            ChatEvent(
              type: 'outbox.failed',
              conversationId: current.conversationId,
              seq: 0,
              payload: {
                'client_message_id': current.clientMessageId,
                'code': e.code,
              },
            ),
          );
        } on AppException catch (e) {
          DiagnosticLog.warn('chat', 'outbox flush error', error: e);
          return false;
        } on Object catch (e) {
          // Anything else (a recording whose temporary file is gone, a codec
          // or plugin error) would otherwise keep the item queued for good,
          // with the message stuck on "sending". Mark it failed: the bubble
          // then offers retry and discard.
          DiagnosticLog.warn('chat', 'outbox item failed locally', error: e);
          await _cache.putOutbox(
            current.copyWith(
              failed: true,
              errorCode: 'LOCAL_ERROR',
              attempts: current.attempts + 1,
            ),
          );
          _events.add(
            ChatEvent(
              type: 'outbox.failed',
              conversationId: current.conversationId,
              seq: 0,
              payload: {
                'client_message_id': current.clientMessageId,
                'code': 'LOCAL_ERROR',
              },
            ),
          );
        }
      }
    }
    return true;
  }

  String _typeFor(OutboxItem item) => item.voice ? 'voice' : 'file';

  void _deleteQuietly(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } on FileSystemException {
      // ignore
    }
  }

  // ---- attachments ---------------------------------------------------------------------------

  Future<Directory> _mediaDir() async =>
      Directory(p.join((await _mediaRoot()).path, 'chat_media'));

  Future<File> _attachmentPath(ChatAttachment att, bool thumbnail) async {
    final dir = await _mediaDir();
    return File(
      p.join(
        dir.path,
        '${att.id}${thumbnail ? '_thumb.jpg' : '_${_safeName(att.filename)}'}',
      ),
    );
  }

  /// The attachment (or thumbnail) when it is already on disk; never touches
  /// the network (used when auto-download is not allowed).
  Future<File?> cachedAttachmentFile(
    ChatAttachment att, {
    bool thumbnail = false,
  }) async {
    try {
      final file = await _attachmentPath(att, thumbnail);
      if (await file.exists() && await file.length() > 0) return file;
    } on FileSystemException {
      return null;
    }
    return null;
  }

  /// Downloads an attachment (or thumbnail) into the app-private cache dir,
  /// returning the local file. Thumbnails are kept (LRU by count); originals
  /// are kept until the cache is cleared.
  Future<File> attachmentFile(
    ChatAttachment att, {
    bool thumbnail = false,
  }) async {
    final cached = await cachedAttachmentFile(att, thumbnail: thumbnail);
    if (cached != null) return cached;
    final dir = await _mediaDir();
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = await _attachmentPath(att, thumbnail);
    await _api.download(att.id, savePath: file.path, thumbnail: thumbnail);
    unawaited(_trimMedia(dir));
    return file;
  }

  /// Total size in bytes of everything under the chat media directory.
  Future<int> mediaSizeBytes() async {
    try {
      final dir = await _mediaDir();
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        if (e is File) total += await e.length();
      }
      return total;
    } on FileSystemException {
      return 0;
    }
  }

  // ---- group avatars -----------------------------------------------------------------

  Future<Directory> _avatarDir() async =>
      Directory(p.join((await _mediaDir()).path, 'avatars'));

  /// Stored copies of a group picture, newest first. File names carry the
  /// download time (`<conv>_<millis>.img`), so a new picture never collides
  /// with an image already decoded in memory.
  Future<List<File>> _avatarCopies(String convId) async {
    final dir = await _avatarDir();
    if (!await dir.exists()) return const [];
    final prefix = '${_safeName(convId)}_';
    final files = await dir
        .list()
        .where(
          (e) =>
              e is File &&
              p.basename(e.path).startsWith(prefix) &&
              e.path.endsWith('.img'),
        )
        .cast<File>()
        .toList();
    int stamp(File f) =>
        int.tryParse(
          p.basenameWithoutExtension(f.path).substring(prefix.length),
        ) ??
        0;
    files.sort((a, b) => stamp(b).compareTo(stamp(a)));
    return files;
  }

  /// Group picture on disk, downloaded with the bearer token when missing or
  /// older than [avatarMaxAge]; a stale copy is used when the refresh fails.
  Future<File?> avatarFile(String convId) async {
    File? current;
    try {
      final copies = await _avatarCopies(convId);
      current = copies.firstOrNull;
      if (current != null) {
        final name = p.basenameWithoutExtension(current.path);
        final millis = int.tryParse(name.split('_').last) ?? 0;
        final age = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(millis),
        );
        if (age < avatarMaxAge && await current.length() > 0) return current;
      }
      final dir = await _avatarDir();
      await dir.create(recursive: true);
      final now = DateTime.now().millisecondsSinceEpoch;
      final target = File(p.join(dir.path, '${_safeName(convId)}_$now.img'));
      final tmp = File('${target.path}.part');
      await _api.downloadChatAvatar(convId, savePath: tmp.path);
      final saved = await tmp.rename(target.path);
      for (final old in copies) {
        await old.delete();
      }
      return saved;
    } on AppException catch (e) {
      DiagnosticLog.warn('chat', 'avatar download failed', error: e);
      return current;
    } on FileSystemException catch (e) {
      DiagnosticLog.warn('chat', 'avatar write failed', error: e);
      return current;
    }
  }

  Future<void> _dropAvatar(String convId) async {
    try {
      for (final f in await _avatarCopies(convId)) {
        await f.delete();
      }
    } on FileSystemException {
      // ignore
    }
  }

  /// Uploads [filePath] as an attachment of the group and makes it the group
  /// picture (`POST /chats/{id}/avatar`).
  Future<ChatConversation> setGroupAvatar(
    String chatId, {
    required String filePath,
    required String filename,
  }) async {
    final att = await _api.upload(
      chatId,
      filePath: filePath,
      filename: filename,
    );
    final conv = await _api.setAvatar(chatId, att.id);
    await _dropAvatar(chatId);
    await _cache.putConversation(conv);
    _events.add(
      ChatEvent(
        type: 'chat.local',
        conversationId: chatId,
        seq: 0,
        payload: const {'change': 'avatar'},
      ),
    );
    return conv;
  }

  static String _safeName(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_');

  Future<void> _trimMedia(Directory dir, {int maxFiles = 300}) async {
    try {
      final files = await dir
          .list()
          .where((e) => e is File)
          .cast<File>()
          .toList();
      if (files.length <= maxFiles) return;
      files.sort(
        (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
      );
      for (final f in files.take(files.length - maxFiles)) {
        await f.delete();
      }
    } on FileSystemException {
      // ignore
    }
  }

  Future<void> clearMedia() async {
    try {
      final dir = await _mediaDir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } on FileSystemException {
      // ignore
    }
  }

  // ---- settings / device ---------------------------------------------------------------------

  Future<ChatSettings> settings() => _api.getSettings();
  Future<ChatSettings> updateSettings(ChatSettings s) => _api.putSettings(s);

  Future<String> deviceId() async {
    var id = await _cache.readMeta('device_id');
    if (id == null) {
      id = _uuid.v4();
      await _cache.writeMeta('device_id', id);
    }
    return id;
  }

  /// Sign-out: tell the server, stop the socket, wipe local chat data.
  Future<void> signOut() async {
    try {
      await _api.endSession(await deviceId());
    } on AppException catch (e) {
      DiagnosticLog.warn('chat', 'end session failed', error: e);
    }
    await stop();
    await _cache.clear();
    await clearMedia();
  }
}
