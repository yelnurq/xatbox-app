import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/api/api_exception.dart';
import '../../data/chat_comments.dart';
import '../../data/chat_models.dart';
import '../../data/chat_repository.dart';
import '../chat_providers.dart';

final chatCommentsApiProvider = Provider<ChatCommentsApi>(
  (ref) => ChatCommentsApi(ref.watch(chatApiClientProvider)),
);

typedef ChannelThreadKey = ({String conversationId, String postId});

@immutable
class ChannelThreadState {
  const ChannelThreadState({
    this.post,
    this.comments = const [],
    this.loading = true,
    this.loadingOlder = false,
    this.hasMore = false,
    this.enabled = true,
    this.error,
  });

  final ChatMessage? post;

  /// Ascending by seq; pending sends at the end.
  final List<ChatMessage> comments;
  final bool loading;
  final bool loadingOlder;
  final bool hasMore;

  /// The channel accepts comments.
  final bool enabled;
  final Object? error;

  ChannelThreadState copyWith({
    ChatMessage? post,
    List<ChatMessage>? comments,
    bool? loading,
    bool? loadingOlder,
    bool? hasMore,
    bool? enabled,
    Object? error,
    bool clearError = false,
  }) => ChannelThreadState(
    post: post ?? this.post,
    comments: comments ?? this.comments,
    loading: loading ?? this.loading,
    loadingOlder: loadingOlder ?? this.loadingOlder,
    hasMore: hasMore ?? this.hasMore,
    enabled: enabled ?? this.enabled,
    error: clearError ? null : (error ?? this.error),
  );
}

/// One post thread: the post, its comments (live over the socket) and
/// sending (`POST /messages/{postId}/comments`, idempotent by
/// client_message_id, failed sends can be retried).
class ChannelThreadNotifier extends Notifier<ChannelThreadState> {
  ChannelThreadNotifier(this.key);
  final ChannelThreadKey key;

  static const pageSize = 50;
  static const _uuid = Uuid();

  /// Unsent requests by client_message_id (retry).
  final Map<String, Future<ChatMessage> Function()> _requests = {};

  ChatCommentsApi get _api => ref.read(chatCommentsApiProvider);
  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  ChannelThreadState build() {
    final repo = ref.watch(chatRepositoryProvider);
    final sub = repo.events.listen(_onEvent);
    ref.onDispose(sub.cancel);
    Future.microtask(load);
    return const ChannelThreadState();
  }

  Future<void> load() async {
    try {
      final page = await _api.list(key.postId, limit: pageSize);
      if (!ref.mounted) return;
      state = state.copyWith(
        post: page.post,
        comments: ConversationNotifier.sortMessages([
          ...page.comments,
          ...state.comments.where((m) => m.seq == 0),
        ]),
        enabled: page.commentsEnabled,
        loading: false,
        hasMore: page.comments.length >= pageSize,
        clearError: true,
      );
    } on AppException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> loadOlder() async {
    if (state.loadingOlder || !state.hasMore) return;
    final oldest = state.comments.where((m) => m.seq > 0).firstOrNull?.seq;
    if (oldest == null) return;
    state = state.copyWith(loadingOlder: true);
    try {
      final page = await _api.list(
        key.postId,
        beforeSeq: oldest,
        limit: pageSize,
      );
      if (!ref.mounted) return;
      state = state.copyWith(
        comments: ConversationNotifier.sortMessages([
          ...page.comments,
          ...state.comments,
        ]),
        loadingOlder: false,
        hasMore: page.comments.length >= pageSize,
      );
    } on AppException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loadingOlder: false, error: e);
    }
  }

  void _onEvent(ChatEvent ev) {
    if (ev.conversationId != key.conversationId) return;
    final selfId = _repo.selfId;
    switch (ev.type) {
      case 'message.created':
        final m = ev.message;
        if (m != null && m.threadRootId == key.postId) _upsert(m);
      case 'message.updated' ||
          'message.deleted' ||
          'message.reaction' ||
          'message.delivered' ||
          'message.link_preview' ||
          'message.transcript' ||
          'post.comments':
        final post = state.post;
        final nextPost = post != null && post.id == ev.messageId
            ? ChatRepository.applyToMessage(post, ev, selfId)
            : null;
        var changed = nextPost != null;
        final comments = [
          for (final m in state.comments)
            if (m.id == ev.messageId)
              () {
                final next = ChatRepository.applyToMessage(m, ev, selfId);
                if (next != null) changed = true;
                return next ?? m;
              }()
            else
              m,
        ];
        if (changed) {
          state = state.copyWith(post: nextPost, comments: comments);
        }
      case 'message.hidden':
        if (ev.userId.isNotEmpty && ev.userId != selfId) return;
        if (!state.comments.any((m) => m.id == ev.messageId)) return;
        state = state.copyWith(
          comments: [
            for (final m in state.comments)
              if (m.id != ev.messageId) m,
          ],
        );
      case 'chat.updated' || 'chat.local':
        // e.g. comments switched off by an admin.
        unawaited(_refreshEnabled());
    }
  }

  Future<void> _refreshEnabled() async {
    final conv = await _repo.conversation(key.conversationId);
    if (ref.mounted && conv != null && conv.commentsEnabled != state.enabled) {
      state = state.copyWith(enabled: conv.commentsEnabled);
    }
  }

  void _upsert(ChatMessage m) {
    bool replaced(ChatMessage x) =>
        x.id == m.id ||
        (x.seq == 0 &&
            m.clientMessageId.isNotEmpty &&
            x.clientMessageId == m.clientMessageId);
    state = state.copyWith(
      comments: ConversationNotifier.sortMessages([
        for (final x in state.comments)
          if (!replaced(x)) x,
        m,
      ]),
    );
  }

  void _markFailed(String clientMessageId, bool failed) {
    state = state.copyWith(
      comments: [
        for (final m in state.comments)
          if (m.seq == 0 && m.clientMessageId == clientMessageId)
            m.copyWith(failed: failed, pending: !failed)
          else
            m,
      ],
    );
  }

  Future<void> _run(String cid) async {
    final request = _requests[cid];
    if (request == null) return;
    try {
      final created = await request();
      _requests.remove(cid);
      if (ref.mounted) _upsert(created);
    } on AppException {
      if (ref.mounted) _markFailed(cid, true);
      rethrow;
    }
  }

  Future<void> _send({
    required String type,
    String body = '',
    String? replyToId,
    List<String> mentions = const [],
    String? localFilePath,
    String? filename,
    bool voice = false,
    int? durationMs,
  }) async {
    final cid = _uuid.v4();
    final attachmentIds = <String>[];
    state = state.copyWith(
      comments: [
        ...state.comments,
        ChatMessage(
          id: 'pending:$cid',
          conversationId: key.conversationId,
          senderId: _repo.selfId,
          seq: 0,
          type: type,
          body: body,
          clientMessageId: cid,
          createdAt: DateTime.now().toUtc(),
          replyToId: replyToId,
          mentions: mentions,
          pending: true,
          threadRootId: key.postId,
          localFilePath: localFilePath,
        ),
      ],
    );
    _requests[cid] = () async {
      if (localFilePath != null && attachmentIds.isEmpty) {
        final att = await _repo.api.upload(
          key.conversationId,
          filePath: localFilePath,
          filename: filename ?? 'file',
          voice: voice,
          durationMs: durationMs,
        );
        attachmentIds.add(att.id);
      }
      return _api.send(
        key.postId,
        clientMessageId: cid,
        type: type,
        body: body,
        replyToId: replyToId,
        attachmentIds: attachmentIds,
        mentions: mentions,
      );
    };
    await _run(cid);
  }

  Future<void> sendText(
    String text, {
    String? replyToId,
    List<String> mentions = const [],
  }) => _send(
    type: 'text',
    body: text.trim(),
    replyToId: replyToId,
    mentions: mentions,
  );

  Future<void> sendSticker(ChatSticker sticker) =>
      _send(type: 'sticker', body: sticker.toMessageBody());

  Future<void> sendFile({
    required String path,
    required String filename,
    bool voice = false,
    int? durationMs,
  }) => _send(
    type: voice ? 'voice' : 'file',
    localFilePath: path,
    filename: filename,
    voice: voice,
    durationMs: durationMs,
  );

  Future<void> retry(String clientMessageId) async {
    _markFailed(clientMessageId, false);
    await _run(clientMessageId);
  }

  void discard(String clientMessageId) {
    _requests.remove(clientMessageId);
    state = state.copyWith(
      comments: [
        for (final m in state.comments)
          if (!(m.seq == 0 && m.clientMessageId == clientMessageId)) m,
      ],
    );
  }

  Future<void> react(ChatMessage m, String emoji) =>
      _repo.toggleReaction(m, emoji);

  Future<void> delete(ChatMessage m) => _repo.deleteMessage(m.id);

  Future<void> hideForMe(ChatMessage m) => _repo.hideMessage(m);

  Future<void> edit(ChatMessage m, String body) async {
    final updated = await _repo.editMessage(m.id, body);
    if (ref.mounted) {
      state = state.copyWith(
        comments: [
          for (final x in state.comments)
            if (x.id == m.id)
              x.copyWith(body: updated.body, editedAt: updated.editedAt)
            else
              x,
        ],
      );
    }
  }
}

final channelThreadProvider = NotifierProvider.autoDispose
    .family<ChannelThreadNotifier, ChannelThreadState, ChannelThreadKey>(
      ChannelThreadNotifier.new,
    );
