import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import 'chat_models.dart';

/// REST client of the Chat Service. Uses its own [ApiClient] (different base
/// URL) but the same bearer token and the same global 401 handling as Mail.
class ChatApi {
  ChatApi(this._client);
  final ApiClient _client;

  Map<String, dynamic> _q(Map<String, dynamic> raw) => {
    for (final e in raw.entries)
      if (e.value != null) e.key: e.value,
  };

  // ---- me / settings ---------------------------------------------------------

  Future<Map<String, dynamic>> me() => _client.getJson('/me');

  Future<ChatSettings> getSettings() async =>
      ChatSettings.fromJson(await _client.getJson('/me/settings'));

  Future<ChatSettings> putSettings(ChatSettings s) async =>
      ChatSettings.fromJson(
        await _client.putJson('/me/settings', body: s.toJson()),
      );

  /// `DELETE /session` — drops the server-side auth cache entry and this
  /// device's push registration.
  Future<void> endSession(String deviceId) async {
    await _client.deleteJson(
      '/session',
      query: {'device_id': deviceId},
      expectedStatuses: const {204},
    );
  }

  Future<List<ChatUser>> searchUsers(String q, {int limit = 50}) async {
    final json = await _client.getJson(
      '/users',
      query: _q({'q': q.isEmpty ? null : q, 'limit': limit}),
    );
    return ((json['users'] as List?) ?? const [])
        .map((e) => ChatUser.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // ---- conversations -------------------------------------------------------------

  Future<({List<ChatConversation> chats, String nextCursor})> listChats({
    String? cursor,
    int limit = 50,
    bool archived = false,
    bool withRequests = false,
  }) async {
    final json = await _client.getJson(
      '/chats',
      query: _q({
        'cursor': cursor,
        'limit': limit,
        'archived': archived ? '1' : null,
        // «Заявки»: only clients that show the chat ask for it (older app
        // builds do not know the chat type and never get it).
        'with_requests': withRequests ? '1' : null,
      }),
    );
    return (
      chats: ((json['chats'] as List?) ?? const [])
          .map(
            (e) =>
                ChatConversation.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList(),
      nextCursor: (json['next_cursor'] as String?) ?? '',
    );
  }

  Future<ChatConversation> getChat(String id) async =>
      ChatConversation.fromJson(
        await _client.getJson('/chats/${Uri.encodeComponent(id)}'),
      );

  Future<ChatConversation> createDirect(String userId) async =>
      ChatConversation.fromJson(
        await _client.postJson(
          '/chats',
          body: {'type': 'direct', 'user_id': userId},
          expectedStatuses: const {200, 201},
        ),
      );

  Future<ChatConversation> createGroup(
    String title,
    List<String> memberIds,
  ) async => ChatConversation.fromJson(
    await _client.postJson(
      '/chats',
      body: {'type': 'group', 'title': title, 'member_ids': memberIds},
      expectedStatuses: const {201},
    ),
  );

  /// `POST /chats/saved` — the caller's «Избранное» (created on first use).
  Future<ChatConversation> ensureSaved() async => ChatConversation.fromJson(
    await _client.postJson(
      '/chats/saved',
      expectedStatuses: const {200, 201},
    ),
  );

  /// `POST /requests` — files a request in the caller's «Заявки» chat. The
  /// message (and the bot's confirmation) also arrive over the socket.
  Future<ChatMessage> submitRequest({
    required String clientMessageId,
    required String what,
    required String room,
    required String date,
  }) async => ChatMessage.fromJson(
    await _client.postJson(
      '/requests',
      body: {
        'client_message_id': clientMessageId,
        'what': what,
        'room': room,
        'date': date,
      },
      expectedStatuses: const {200, 201},
    ),
  );

  Future<ChatConversation> patchChat(
    String id, {
    String? title,
    String? pinnedMessageId,
    bool clearPinned = false,
    DateTime? mutedUntil,
    bool unmute = false,
    bool? pinned,
    bool? archived,
    bool? markedUnread,
    String? description,
  }) async {
    final body = <String, dynamic>{
      'title': ?title,
      'pinned_message_id': ?pinnedMessageId,
      if (clearPinned) 'clear_pinned_message': true,
      if (unmute)
        'muted_until': ''
      else
        'muted_until': ?mutedUntil?.toUtc().toIso8601String(),
      'pinned': ?pinned,
      'archived': ?archived,
      'marked_unread': ?markedUnread,
      'description': ?description,
    };
    return ChatConversation.fromJson(
      await _client.patchJson('/chats/${Uri.encodeComponent(id)}', body: body),
    );
  }

  Future<ChatConversation> addMember(
    String chatId,
    String userId, {
    String role = 'member',
  }) async => ChatConversation.fromJson(
    await _client.postJson(
      '/chats/${Uri.encodeComponent(chatId)}/members',
      body: {'user_id': userId, 'role': role},
      expectedStatuses: const {200},
    ),
  );

  Future<void> removeMember(String chatId, String userId) async {
    await _client.deleteJson(
      '/chats/${Uri.encodeComponent(chatId)}/members/${Uri.encodeComponent(userId)}',
      expectedStatuses: const {204},
    );
  }

  Future<void> setRole(String chatId, String userId, String role) async {
    await _client.putJson(
      '/chats/${Uri.encodeComponent(chatId)}/members/${Uri.encodeComponent(userId)}/role',
      body: {'role': role},
    );
  }

  Future<ChatConversation> setAvatar(
    String chatId,
    String attachmentId,
  ) async => ChatConversation.fromJson(
    await _client.postJson(
      '/chats/${Uri.encodeComponent(chatId)}/avatar',
      body: {'attachment_id': attachmentId},
      expectedStatuses: const {200},
    ),
  );

  // ---- messages ---------------------------------------------------------------------

  Future<List<ChatMessage>> listMessages(
    String chatId, {
    int? beforeSeq,
    int? afterSeq,
    int limit = 50,
  }) async {
    final json = await _client.getJson(
      '/chats/${Uri.encodeComponent(chatId)}/messages',
      query: _q({
        'before_seq': beforeSeq,
        'after_seq': afterSeq,
        'limit': limit,
      }),
    );
    return ((json['messages'] as List?) ?? const [])
        .map((e) => ChatMessage.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<ChatEvent>> listEvents(
    String chatId, {
    required int afterSeq,
    int limit = 200,
  }) async {
    final json = await _client.getJson(
      '/chats/${Uri.encodeComponent(chatId)}/events',
      query: {'after_seq': afterSeq, 'limit': limit},
    );
    return ((json['events'] as List?) ?? const [])
        .map((e) => ChatEvent.fromLogRow((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// `POST /chats/{id}/messages` — 201 created, 200 idempotent replay.
  Future<ChatMessage> sendMessage(
    String chatId, {
    required String clientMessageId,
    String type = 'text',
    String body = '',
    String? replyToId,
    String? forwardOfId,
    List<String> attachmentIds = const [],
    List<String> mentions = const [],
  }) async {
    final json = await _client.postJson(
      '/chats/${Uri.encodeComponent(chatId)}/messages',
      body: {
        'client_message_id': clientMessageId,
        'type': type,
        'body': body,
        'reply_to_id': ?replyToId,
        'forward_of_id': ?forwardOfId,
        if (attachmentIds.isNotEmpty) 'attachment_ids': attachmentIds,
        if (mentions.isNotEmpty) 'mentions': mentions,
      },
      expectedStatuses: const {200, 201},
    );
    return ChatMessage.fromJson(json);
  }

  Future<ChatMessage> getMessage(String id) async => ChatMessage.fromJson(
    await _client.getJson('/messages/${Uri.encodeComponent(id)}'),
  );

  Future<ChatMessage> editMessage(String id, String body) async =>
      ChatMessage.fromJson(
        await _client.patchJson(
          '/messages/${Uri.encodeComponent(id)}',
          body: {'body': body},
        ),
      );

  Future<void> deleteMessage(String id) async {
    await _client.deleteJson(
      '/messages/${Uri.encodeComponent(id)}',
      expectedStatuses: const {204},
    );
  }

  /// `POST /messages/{id}/hide` — «Удалить у меня» (only for the caller).
  Future<void> hideMessage(String id) async {
    await _client.postJson(
      '/messages/${Uri.encodeComponent(id)}/hide',
      expectedStatuses: const {204},
    );
  }

  /// `GET /chats/{id}/media?kind=` — attachments or links, newest first.
  Future<({List<ChatMediaEntry> items, String nextCursor})> listMedia(
    String chatId, {
    required ChatMediaKind kind,
    String? cursor,
    int limit = 30,
  }) async {
    final json = await _client.getJson(
      '/chats/${Uri.encodeComponent(chatId)}/media',
      query: _q({
        'kind': kind.apiName,
        'cursor': (cursor?.isEmpty ?? true) ? null : cursor,
        'limit': limit,
      }),
    );
    return (
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .where((e) => e['message'] is Map)
          .map((e) => ChatMediaEntry.fromJson(e.cast<String, dynamic>()))
          .toList(),
      nextCursor: (json['next_cursor'] as String?) ?? '',
    );
  }

  /// Proxied link preview picture (`GET /messages/{id}/link-preview/image`).
  Future<void> downloadLinkPreviewImage(
    String messageId, {
    required String savePath,
  }) => _downloadTo(
    '/messages/${Uri.encodeComponent(messageId)}/link-preview/image',
    savePath,
  );

  /// REST fallback for delivery acks (normally sent over the socket).
  Future<void> markDelivered(String messageId) async {
    await _client.postJson(
      '/messages/${Uri.encodeComponent(messageId)}/delivered',
      expectedStatuses: const {204},
    );
  }

  Future<void> markRead(String messageId) async {
    await _client.postJson(
      '/messages/${Uri.encodeComponent(messageId)}/read',
      expectedStatuses: const {204},
    );
  }

  Future<bool> toggleReaction(String messageId, String reaction) async {
    final json = await _client.postJson(
      '/messages/${Uri.encodeComponent(messageId)}/reactions',
      body: {'reaction': reaction},
      expectedStatuses: const {200},
    );
    return json['active'] == true;
  }

  Future<void> typing(
    String chatId, {
    String kind = 'typing',
    required bool started,
  }) async {
    await _client.postJson(
      '/chats/${Uri.encodeComponent(chatId)}/typing',
      body: {'kind': kind, 'started': started},
      expectedStatuses: const {204},
    );
  }

  /// Message search; [conversationId] narrows it to one chat.
  Future<List<ChatMessage>> search(
    String q, {
    int limit = 30,
    String? conversationId,
  }) async {
    final json = await _client.getJson(
      '/search',
      query: _q({'q': q, 'limit': limit, 'conversation_id': conversationId}),
    );
    return ((json['messages'] as List?) ?? const [])
        .map((e) => ChatMessage.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// `GET /messages/{id}/receipts` — who got / read an own message.
  Future<List<ChatReceipt>> receipts(String messageId) async {
    final json = await _client.getJson(
      '/messages/${Uri.encodeComponent(messageId)}/receipts',
    );
    return ((json['receipts'] as List?) ?? const [])
        .map((e) => ChatReceipt.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // ---- attachments --------------------------------------------------------------------

  /// Multipart upload (`file` field; `voice`/`duration_ms` for voice notes).
  Future<ChatAttachment> upload(
    String chatId, {
    required String filePath,
    required String filename,
    bool voice = false,
    int? durationMs,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final form = FormData();
    if (voice) form.fields.add(const MapEntry('voice', '1'));
    if (durationMs != null) {
      form.fields.add(MapEntry('duration_ms', '$durationMs'));
    }
    form.files.add(
      MapEntry(
        'file',
        await MultipartFile.fromFile(filePath, filename: filename),
      ),
    );
    final res = await _client.send(
      () => _client.dio.post<dynamic>(
        '/chats/${Uri.encodeComponent(chatId)}/attachments',
        data: form,
        onSendProgress: onProgress,
        cancelToken: cancelToken,
      ),
      expectedStatuses: const {201},
    );
    return ChatAttachment.fromJson(
      ApiClient.asJsonObject(res.data, '/attachments'),
    );
  }

  /// Downloads an attachment (or its thumbnail) to [savePath].
  Future<void> download(
    String attachmentId, {
    required String savePath,
    bool thumbnail = false,
    CancelToken? cancelToken,
  }) => _downloadTo(
    '/attachments/${Uri.encodeComponent(attachmentId)}${thumbnail ? '/thumbnail' : ''}',
    savePath,
    cancelToken: cancelToken,
  );

  /// `GET /chats/{id}/avatar` (bearer, members only) to [savePath].
  Future<void> downloadChatAvatar(String chatId, {required String savePath}) =>
      _downloadTo('/chats/${Uri.encodeComponent(chatId)}/avatar', savePath);

  Future<void> _downloadTo(
    String path,
    String savePath, {
    CancelToken? cancelToken,
  }) async {
    await _client.send(
      () => _client.dio.download(
        path,
        savePath,
        cancelToken: cancelToken,
        options: Options(headers: {'Accept': '*/*'}),
      ),
    );
    if (!File(savePath).existsSync()) {
      throw const UnexpectedApiException('download produced no file');
    }
  }

  // ---- push --------------------------------------------------------------------------

  Future<void> registerDevice({
    required String platform,
    required String token,
    required String deviceId,
    String locale = '',
    String? kind,
    String? pushKey,
  }) async {
    await _client.postJson(
      '/push/devices',
      body: {
        'platform': platform,
        'token': token,
        'device_id': deviceId,
        'locale': locale,
        // `voip` = iOS PushKit token for incoming calls (docs/CALLS-API.md §4.1).
        'kind': ?kind,
        // base64 AES-256 key: the server encrypts FCM payloads for this
        // device so Google never sees names or text.
        'push_key': ?pushKey,
      },
      expectedStatuses: const {204},
    );
  }

  Future<void> unregisterDevice({
    required String platform,
    required String token,
    required String deviceId,
  }) async {
    await _client.send(
      () => _client.dio.delete<dynamic>(
        '/push/devices',
        data: {'platform': platform, 'token': token, 'device_id': deviceId},
      ),
      expectedStatuses: const {204},
    );
  }
}
