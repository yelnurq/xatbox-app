import '../../../core/api/api_client.dart';
import 'chat_models.dart';

/// One page of a channel post thread (`GET /messages/{postId}/comments`).
typedef ChatCommentsPage = ({
  ChatMessage? post,
  List<ChatMessage> comments,
  bool commentsEnabled,
});

/// Channel post comments: ordinary messages of the channel with
/// `thread_root_id` = the post id.
class ChatCommentsApi {
  ChatCommentsApi(this._client);
  final ApiClient _client;

  static String _e(String s) => Uri.encodeComponent(s);

  Future<ChatCommentsPage> list(
    String postId, {
    int? beforeSeq,
    int? afterSeq,
    int limit = 50,
  }) async {
    final json = await _client.getJson(
      '/messages/${_e(postId)}/comments',
      query: {
        'before_seq': ?beforeSeq,
        'after_seq': ?afterSeq,
        'limit': limit,
      },
    );
    return (
      post: json['post'] is Map
          ? ChatMessage.fromJson((json['post'] as Map).cast<String, dynamic>())
          : null,
      comments: ((json['comments'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ChatMessage.fromJson(e.cast<String, dynamic>()))
          .toList(),
      commentsEnabled: json['comments_enabled'] != false,
    );
  }

  /// `POST /messages/{postId}/comments` — 201 created, 200 idempotent replay.
  Future<ChatMessage> send(
    String postId, {
    required String clientMessageId,
    String type = 'text',
    String body = '',
    String? replyToId,
    List<String> attachmentIds = const [],
    List<String> mentions = const [],
  }) async => ChatMessage.fromJson(
    await _client.postJson(
      '/messages/${_e(postId)}/comments',
      body: {
        'client_message_id': clientMessageId,
        'type': type,
        'body': body,
        'reply_to_id': ?replyToId,
        if (attachmentIds.isNotEmpty) 'attachment_ids': attachmentIds,
        if (mentions.isNotEmpty) 'mentions': mentions,
      },
      expectedStatuses: const {200, 201},
    ),
  );

  /// `PATCH /channels/{id} {"comments_enabled"}` (owner / admins).
  Future<ChatConversation> setCommentsEnabled(
    String channelId,
    bool value,
  ) async => ChatConversation.fromJson(
    await _client.patchJson(
      '/channels/${_e(channelId)}',
      body: {'comments_enabled': value},
    ),
  );
}
