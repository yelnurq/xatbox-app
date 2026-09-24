import '../../../core/api/api_client.dart';
import '../../../shared/utils/api_date.dart';
import 'chat_models.dart';

/// Channels, polls, scheduled messages and message reminders
/// (chat-service migration 0010, `backend/chat-service/README.md`).

/// One row of «Каналы организации» (`GET /channels`).
class ChatChannelSummary {
  const ChatChannelSummary({
    required this.id,
    required this.title,
    this.description = '',
    this.hasAvatar = false,
    this.isPublic = true,
    this.subscriberCount = 0,
    this.subscribed = false,
    this.myRole = '',
  });

  final String id;
  final String title;
  final String description;
  final bool hasAvatar;
  final bool isPublic;
  final int subscriberCount;
  final bool subscribed;
  final String myRole;

  factory ChatChannelSummary.fromJson(Map<String, dynamic> j) =>
      ChatChannelSummary(
        id: j['id'] as String,
        title: (j['title'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        hasAvatar: j['has_avatar'] == true,
        isPublic: j['is_public'] != false,
        subscriberCount: (j['subscriber_count'] as num?)?.toInt() ?? 0,
        subscribed: j['subscribed'] == true,
        myRole: (j['my_role'] as String?) ?? '',
      );

  ChatChannelSummary copyWith({bool? subscribed, int? subscriberCount}) =>
      ChatChannelSummary(
        id: id,
        title: title,
        description: description,
        hasAvatar: hasAvatar,
        isPublic: isPublic,
        subscriberCount: subscriberCount ?? this.subscriberCount,
        subscribed: subscribed ?? this.subscribed,
        myRole: myRole,
      );
}

/// A voter of a public poll.
class ChatPollVoter {
  const ChatPollVoter({
    required this.userId,
    this.displayName = '',
    this.options = const [],
    this.votedAt,
  });
  final String userId;
  final String displayName;
  final List<int> options;
  final DateTime? votedAt;

  factory ChatPollVoter.fromJson(Map<String, dynamic> j) => ChatPollVoter(
    userId: (j['user_id'] as String?) ?? '',
    displayName: (j['display_name'] as String?) ?? '',
    options: ((j['options'] as List?) ?? const [])
        .whereType<num>()
        .map((e) => e.toInt())
        .toList(),
    votedAt: parseApiDate(j['voted_at'] as String?),
  );
}

/// A message the user scheduled for later (`GET /chats/{id}/scheduled`).
class ChatScheduledMessage {
  const ChatScheduledMessage({
    required this.id,
    required this.conversationId,
    required this.sendAt,
    this.body = '',
    this.replyToId,
    this.attachments = const [],
    this.status = 'pending',
    this.lastError = '',
    this.whenOnlineUserId = '',
  });

  final String id;
  final String conversationId;

  /// Send time; for «когда появится в сети» the give-up deadline.
  final DateTime sendAt;

  /// «Отправить, когда появится в сети»: the peer waited for ('' = timed).
  final String whenOnlineUserId;

  bool get whenOnline => whenOnlineUserId.isNotEmpty;

  /// The peer did not come online within the waiting period.
  bool get whenOnlineTimedOut => failed && lastError == 'WHEN_ONLINE_TIMEOUT';
  final String body;
  final String? replyToId;
  final List<ChatAttachment> attachments;

  /// pending | sending | failed.
  final String status;
  final String lastError;

  bool get failed => status == 'failed';

  factory ChatScheduledMessage.fromJson(Map<String, dynamic> j) =>
      ChatScheduledMessage(
        id: j['id'] as String,
        conversationId: (j['conversation_id'] as String?) ?? '',
        sendAt:
            parseApiDate(j['send_at'] as String?) ?? DateTime.now().toUtc(),
        body: (j['body'] as String?) ?? '',
        replyToId: j['reply_to_id'] as String?,
        attachments: ((j['attachments'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => ChatAttachment.fromJson(e.cast<String, dynamic>()))
            .toList(),
        status: (j['status'] as String?) ?? 'pending',
        lastError: (j['last_error'] as String?) ?? '',
        whenOnlineUserId: (j['when_online_user_id'] as String?) ?? '',
      );
}

/// «Напомнить»: a personal reminder about a message (`GET /reminders`).
class ChatReminder {
  const ChatReminder({
    required this.id,
    required this.messageId,
    required this.conversationId,
    required this.remindAt,
    this.note = '',
    this.status = 'pending',
    this.firedAt,
    this.message,
    this.conversationTitle = '',
    this.conversationType = '',
  });

  final String id;
  final String messageId;
  final String conversationId;
  final DateTime remindAt;
  final String note;

  /// pending | fired.
  final String status;
  final DateTime? firedAt;
  final ChatMessage? message;
  final String conversationTitle;
  final String conversationType;

  bool get pending => status == 'pending';

  factory ChatReminder.fromJson(Map<String, dynamic> j) => ChatReminder(
    id: j['id'] as String,
    messageId: (j['message_id'] as String?) ?? '',
    conversationId: (j['conversation_id'] as String?) ?? '',
    remindAt: parseApiDate(j['remind_at'] as String?) ?? DateTime.now().toUtc(),
    note: (j['note'] as String?) ?? '',
    status: (j['status'] as String?) ?? 'pending',
    firedAt: parseApiDate(j['fired_at'] as String?),
    message: j['message'] is Map
        ? ChatMessage.fromJson((j['message'] as Map).cast<String, dynamic>())
        : null,
    conversationTitle: (j['conversation_title'] as String?) ?? '',
    conversationType: (j['conversation_type'] as String?) ?? '',
  );
}

/// REST client of the broadcast features. Shares the Chat Service
/// [ApiClient] (base URL, token, 401 handling) with `ChatApi`.
class ChatBroadcastApi {
  ChatBroadcastApi(this._client);
  final ApiClient _client;

  static String _e(String s) => Uri.encodeComponent(s);

  // ---- channels -----------------------------------------------------------------

  Future<ChatConversation> createChannel({
    required String title,
    String description = '',
    bool isPublic = true,
    List<String> memberIds = const [],
  }) async => ChatConversation.fromJson(
    await _client.postJson(
      '/chats',
      body: {
        'type': 'channel',
        'title': title,
        'description': description,
        'is_public': isPublic,
        if (memberIds.isNotEmpty) 'member_ids': memberIds,
      },
      expectedStatuses: const {201},
    ),
  );

  Future<({List<ChatChannelSummary> channels, bool hasMore})> listChannels({
    String q = '',
    int limit = 50,
    int offset = 0,
  }) async {
    final json = await _client.getJson(
      '/channels',
      query: {
        if (q.isNotEmpty) 'q': q,
        'limit': limit,
        if (offset > 0) 'offset': offset,
      },
    );
    return (
      channels: ((json['channels'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ChatChannelSummary.fromJson(e.cast<String, dynamic>()))
          .toList(),
      hasMore: json['has_more'] == true,
    );
  }

  Future<ChatConversation> subscribe(String channelId) async =>
      ChatConversation.fromJson(
        await _client.postJson(
          '/channels/${_e(channelId)}/subscription',
          expectedStatuses: const {200, 201},
        ),
      );

  Future<void> unsubscribe(String channelId) async {
    await _client.deleteJson(
      '/channels/${_e(channelId)}/subscription',
      expectedStatuses: const {204},
    );
  }

  Future<({List<ChatMember> subscribers, int total})> subscribers(
    String channelId, {
    String q = '',
    int limit = 50,
    int offset = 0,
  }) async {
    final json = await _client.getJson(
      '/channels/${_e(channelId)}/subscribers',
      query: {
        if (q.isNotEmpty) 'q': q,
        'limit': limit,
        if (offset > 0) 'offset': offset,
      },
    );
    return (
      subscribers: ((json['subscribers'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ChatMember.fromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }

  Future<ChatConversation> setChannelPublic(String channelId, bool value) async =>
      ChatConversation.fromJson(
        await _client.patchJson(
          '/channels/${_e(channelId)}',
          body: {'is_public': value},
        ),
      );

  // ---- polls ----------------------------------------------------------------------

  Future<ChatMessage> createPoll(
    String chatId, {
    required String clientMessageId,
    required String question,
    required List<String> options,
    bool anonymous = true,
    bool multiple = false,
    bool quiz = false,
    int? correctOption,
    DateTime? closeAt,
  }) async => ChatMessage.fromJson(
    await _client.postJson(
      '/chats/${_e(chatId)}/polls',
      body: {
        'client_message_id': clientMessageId,
        'question': question,
        'options': options,
        'anonymous': anonymous,
        'multiple': multiple,
        'quiz': quiz,
        'correct_option': ?correctOption,
        'close_at': ?closeAt?.toUtc().toIso8601String(),
      },
      expectedStatuses: const {200, 201},
    ),
  );

  ChatPoll _poll(Map<String, dynamic> json) =>
      ChatPoll.fromJson((json['poll'] as Map?)?.cast<String, dynamic>() ?? const {});

  Future<ChatPoll> vote(String messageId, List<int> options) async => _poll(
    await _client.postJson(
      '/messages/${_e(messageId)}/poll/votes',
      body: {'options': options},
      expectedStatuses: const {200},
    ),
  );

  Future<ChatPoll> retractVote(String messageId) async => _poll(
    await _client.deleteJson(
      '/messages/${_e(messageId)}/poll/votes',
      expectedStatuses: const {200},
    ),
  );

  Future<ChatPoll> closePoll(String messageId) async => _poll(
    await _client.postJson(
      '/messages/${_e(messageId)}/poll/close',
      expectedStatuses: const {200},
    ),
  );

  Future<List<ChatPollVoter>> pollVoters(
    String messageId, {
    int? option,
    int limit = 100,
  }) async {
    final json = await _client.getJson(
      '/messages/${_e(messageId)}/poll/voters',
      query: {'option': ?option, 'limit': limit},
    );
    return ((json['voters'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => ChatPollVoter.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  // ---- scheduled messages -----------------------------------------------------------

  Future<List<ChatScheduledMessage>> listScheduled(String chatId) async {
    final json = await _client.getJson('/chats/${_e(chatId)}/scheduled');
    return ((json['scheduled'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => ChatScheduledMessage.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// Time-scheduled ([sendAt]) or, with [whenOnline], sent when the 1:1
  /// peer comes online (`WHEN_ONLINE_UNAVAILABLE` otherwise).
  Future<ChatScheduledMessage> schedule(
    String chatId, {
    DateTime? sendAt,
    bool whenOnline = false,
    String body = '',
    String? replyToId,
    List<String> attachmentIds = const [],
    List<String> mentions = const [],
  }) async => ChatScheduledMessage.fromJson(
    await _client.postJson(
      '/chats/${_e(chatId)}/scheduled',
      body: {
        if (whenOnline) 'when_online': true,
        'body': body,
        if (!whenOnline) 'send_at': sendAt!.toUtc().toIso8601String(),
        'reply_to_id': ?replyToId,
        if (attachmentIds.isNotEmpty) 'attachment_ids': attachmentIds,
        if (mentions.isNotEmpty) 'mentions': mentions,
      },
      expectedStatuses: const {201},
    ),
  );

  Future<ChatScheduledMessage> updateScheduled(
    String id, {
    String? body,
    DateTime? sendAt,
  }) async => ChatScheduledMessage.fromJson(
    await _client.patchJson(
      '/scheduled/${_e(id)}',
      body: {
        'body': ?body,
        'send_at': ?sendAt?.toUtc().toIso8601String(),
      },
    ),
  );

  Future<void> deleteScheduled(String id) async {
    await _client.deleteJson(
      '/scheduled/${_e(id)}',
      expectedStatuses: const {204},
    );
  }

  Future<ChatMessage> sendScheduledNow(String id) async => ChatMessage.fromJson(
    await _client.postJson(
      '/scheduled/${_e(id)}/send',
      expectedStatuses: const {201},
    ),
  );

  // ---- reminders -----------------------------------------------------------------------

  Future<List<ChatReminder>> listReminders() async {
    final json = await _client.getJson('/reminders');
    return ((json['reminders'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => ChatReminder.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<ChatReminder> createReminder(
    String messageId, {
    required DateTime remindAt,
    String note = '',
  }) async => ChatReminder.fromJson(
    await _client.postJson(
      '/messages/${_e(messageId)}/reminders',
      body: {
        'remind_at': remindAt.toUtc().toIso8601String(),
        if (note.isNotEmpty) 'note': note,
      },
      expectedStatuses: const {201},
    ),
  );

  Future<ChatReminder> updateReminder(
    String id, {
    DateTime? remindAt,
    String? note,
  }) async => ChatReminder.fromJson(
    await _client.patchJson(
      '/reminders/${_e(id)}',
      body: {
        'remind_at': ?remindAt?.toUtc().toIso8601String(),
        'note': ?note,
      },
    ),
  );

  Future<void> deleteReminder(String id) async {
    await _client.deleteJson(
      '/reminders/${_e(id)}',
      expectedStatuses: const {204},
    );
  }
}
