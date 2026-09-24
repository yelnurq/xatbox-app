import 'dart:convert';

import '../../../shared/utils/api_date.dart';
import 'chat_messenger2.dart';
import 'chat_poll.dart';
import 'chat_request.dart';
import 'chat_status.dart';

export 'chat_messenger2.dart'
    show ChatProtection, ChatSticker, ChatTranscript;
export 'chat_poll.dart' show ChatPoll, ChatPollOption;
export 'chat_request.dart' show ChatRequest;
export 'chat_status.dart' show ChatStatusPreset, ChatUserStatus;

/// Conversation as returned by the Chat Service (`GET /chats`).
class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.type,
    required this.title,
    required this.hasAvatar,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.lastSeq,
    required this.unread,
    required this.memberCount,
    required this.myRole,
    required this.settings,
    this.lastMessage,
    this.pinnedMessageId,
    this.members = const [],
    this.peer,
    this.description = '',
    this.protection = const ChatProtection(),
    this.isPublic = false,
    this.commentsEnabled = false,
  });

  final String id;
  final String type; // direct | group | saved | channel | requests
  final String title;
  final bool hasAvatar;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int lastSeq;
  final ChatMessage? lastMessage;
  final String? pinnedMessageId;
  final int unread;
  final int memberCount;
  final List<ChatMember> members;
  final ChatUser? peer;
  final String myRole;
  final ChatMemberSettings settings;

  /// Group description (≤500 characters, admins edit it).
  final String description;

  /// Protected chat settings (no forwarding, screenshots, disappearing).
  final ChatProtection protection;

  /// Channels: listed in «Каналы организации» (chat_broadcast.dart).
  final bool isPublic;

  /// Channels: subscribers may comment on posts.
  final bool commentsEnabled;

  bool get isGroup => type == 'group';

  /// One-to-one chat.
  bool get isDirect => type == 'direct';

  /// Announcement channel: owner/admins post, members subscribe.
  bool get isChannel => type == 'channel';

  /// «Избранное»: the user's own notes chat.
  bool get isSaved => type == 'saved';

  /// «Заявки»: the user's requests to the outside service (desktop only
  /// for now; the list asks for it with `with_requests=1`).
  bool get isRequests => type == 'requests';

  /// Unread messages, or the "marked as unread" flag (shown as a dot).
  bool get hasUnread => unread > 0 || (settings.markedUnread && !isSaved);
  bool get isAdmin => myRole == 'owner' || myRole == 'admin';
  bool get isMuted =>
      settings.mutedUntil != null &&
      settings.mutedUntil!.isAfter(DateTime.now());

  factory ChatConversation.fromJson(Map<String, dynamic> j) => ChatConversation(
    id: j['id'] as String,
    type: (j['type'] as String?) ?? 'direct',
    title: (j['title'] as String?) ?? '',
    hasAvatar: j['has_avatar'] == true,
    createdBy: (j['created_by'] as String?) ?? '',
    createdAt: parseApiDate(j['created_at'] as String?),
    updatedAt: parseApiDate(j['updated_at'] as String?),
    lastSeq: (j['last_seq'] as num?)?.toInt() ?? 0,
    lastMessage: j['last_message'] is Map
        ? ChatMessage.fromJson(
            (j['last_message'] as Map).cast<String, dynamic>(),
          )
        : null,
    pinnedMessageId: j['pinned_message_id'] as String?,
    unread: (j['unread'] as num?)?.toInt() ?? 0,
    memberCount: (j['member_count'] as num?)?.toInt() ?? 0,
    members: ((j['members'] as List?) ?? const [])
        .map((e) => ChatMember.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    peer: j['peer'] is Map
        ? ChatUser.fromJson((j['peer'] as Map).cast<String, dynamic>())
        : null,
    myRole: (j['my_role'] as String?) ?? 'member',
    settings: ChatMemberSettings.fromJson(
      (j['settings'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    description: (j['description'] as String?) ?? '',
    protection: ChatProtection.fromJson(
      (j['protection'] as Map?)?.cast<String, dynamic>(),
    ),
    isPublic: j['is_public'] == true,
    commentsEnabled: j['comments_enabled'] == true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'has_avatar': hasAvatar,
    'created_by': createdBy,
    'created_at': createdAt?.toUtc().toIso8601String(),
    'updated_at': updatedAt?.toUtc().toIso8601String(),
    'last_seq': lastSeq,
    'last_message': ?lastMessage?.toJson(),
    'pinned_message_id': ?pinnedMessageId,
    'unread': unread,
    'member_count': memberCount,
    'members': members.map((m) => m.toJson()).toList(),
    'peer': ?peer?.toJson(),
    'my_role': myRole,
    'settings': settings.toJson(),
    'description': description,
    'protection': protection.toJson(),
    'is_public': isPublic,
    'comments_enabled': commentsEnabled,
  };

  ChatConversation copyWith({
    String? title,
    int? lastSeq,
    ChatMessage? lastMessage,
    int? unread,
    DateTime? updatedAt,
    ChatUser? peer,
    List<ChatMember>? members,
    int? memberCount,
    ChatMemberSettings? settings,
    String? pinnedMessageId,
    bool clearPinned = false,
    bool? hasAvatar,
    String? description,
    ChatProtection? protection,
    bool? commentsEnabled,
  }) => ChatConversation(
    id: id,
    type: type,
    title: title ?? this.title,
    hasAvatar: hasAvatar ?? this.hasAvatar,
    createdBy: createdBy,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastSeq: lastSeq ?? this.lastSeq,
    lastMessage: lastMessage ?? this.lastMessage,
    pinnedMessageId: clearPinned
        ? null
        : (pinnedMessageId ?? this.pinnedMessageId),
    unread: unread ?? this.unread,
    memberCount: memberCount ?? this.memberCount,
    members: members ?? this.members,
    peer: peer ?? this.peer,
    myRole: myRole,
    settings: settings ?? this.settings,
    description: description ?? this.description,
    protection: protection ?? this.protection,
    isPublic: isPublic,
    commentsEnabled: commentsEnabled ?? this.commentsEnabled,
  );
}

class ChatMemberSettings {
  const ChatMemberSettings({
    this.mutedUntil,
    this.pinned = false,
    this.archived = false,
    this.lastReadSeq = 0,
    this.markedUnread = false,
  });
  final DateTime? mutedUntil;
  final bool pinned;
  final bool archived;
  final int lastReadSeq;

  /// "Mark as unread" (per user, synced to the user's other devices).
  final bool markedUnread;

  factory ChatMemberSettings.fromJson(Map<String, dynamic> j) =>
      ChatMemberSettings(
        mutedUntil: parseApiDate(j['muted_until'] as String?),
        pinned: j['pinned'] == true,
        archived: j['archived'] == true,
        lastReadSeq: (j['last_read_seq'] as num?)?.toInt() ?? 0,
        markedUnread: j['marked_unread'] == true,
      );

  Map<String, dynamic> toJson() => {
    'muted_until': ?mutedUntil?.toUtc().toIso8601String(),
    'pinned': pinned,
    'archived': archived,
    'last_read_seq': lastReadSeq,
    'marked_unread': markedUnread,
  };

  ChatMemberSettings copyWith({int? lastReadSeq, bool? markedUnread}) =>
      ChatMemberSettings(
        mutedUntil: mutedUntil,
        pinned: pinned,
        archived: archived,
        lastReadSeq: lastReadSeq ?? this.lastReadSeq,
        markedUnread: markedUnread ?? this.markedUnread,
      );
}

/// Server-side preview of the first link of a text message
/// (`link_preview`); the image is proxied by the Chat Service.
class ChatLinkPreview {
  const ChatLinkPreview({
    required this.url,
    this.title = '',
    this.description = '',
    this.siteName = '',
    this.hasImage = false,
    this.imageWidth,
    this.imageHeight,
  });
  final String url;
  final String title;
  final String description;
  final String siteName;
  final bool hasImage;
  final int? imageWidth;
  final int? imageHeight;

  Uri? get uri => Uri.tryParse(url);

  factory ChatLinkPreview.fromJson(Map<String, dynamic> j) => ChatLinkPreview(
    url: (j['url'] as String?) ?? '',
    title: (j['title'] as String?) ?? '',
    description: (j['description'] as String?) ?? '',
    siteName: (j['site_name'] as String?) ?? '',
    hasImage: j['has_image'] == true,
    imageWidth: (j['image_width'] as num?)?.toInt(),
    imageHeight: (j['image_height'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'url': url,
    'title': title,
    'description': description,
    'site_name': siteName,
    'has_image': hasImage,
    'image_width': ?imageWidth,
    'image_height': ?imageHeight,
  };
}

/// Tabs of «Медиа, файлы, ссылки, голосовые» (`GET /chats/{id}/media?kind=`).
enum ChatMediaKind {
  media,
  file,
  link,
  voice;

  String get apiName => name;
}

/// One row of the media listing: an attachment of a message, or a link.
class ChatMediaEntry {
  const ChatMediaEntry({required this.message, this.attachment, this.url});
  final ChatMessage message;
  final ChatAttachment? attachment;
  final String? url;

  factory ChatMediaEntry.fromJson(Map<String, dynamic> j) {
    final message = ChatMessage.fromJson(
      (j['message'] as Map).cast<String, dynamic>(),
    );
    return ChatMediaEntry(
      message: message,
      attachment: j['attachment'] is Map
          ? ChatAttachment.fromJson(
              (j['attachment'] as Map).cast<String, dynamic>(),
            )
          : null,
      url: j['url'] as String?,
    );
  }
}

class ChatMember {
  const ChatMember({
    required this.userId,
    required this.role,
    required this.displayName,
    required this.email,
    this.online = false,
    this.status,
  });
  final String userId;
  final String role;
  final String displayName;
  final String email;
  final bool online;

  /// Public status («На паре», …); null when none.
  final ChatUserStatus? status;

  String get label => displayName.isNotEmpty ? displayName : email;

  factory ChatMember.fromJson(Map<String, dynamic> j) => ChatMember(
    userId: j['user_id'] as String,
    role: (j['role'] as String?) ?? 'member',
    displayName: (j['display_name'] as String?) ?? '',
    email: (j['email'] as String?) ?? '',
    online: j['online'] == true,
    status: ChatUserStatus.fromJsonOrNull(j['status']),
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'role': role,
    'display_name': displayName,
    'email': email,
    'online': online,
    'status': ?status?.toJson(),
  };

  ChatMember copyWith({
    bool? online,
    ChatUserStatus? status,
    bool clearStatus = false,
  }) => ChatMember(
    userId: userId,
    role: role,
    displayName: displayName,
    email: email,
    online: online ?? this.online,
    status: clearStatus ? null : (status ?? this.status),
  );
}

/// Safe display profile of a colleague (`GET /users`, `peer`).
class ChatUser {
  const ChatUser({
    required this.userId,
    required this.email,
    required this.displayName,
    this.online = false,
    this.lastSeenAt,
    this.status,
    this.presenceHidden = false,
  });
  final String userId;
  final String email;
  final String displayName;
  final bool online;
  final DateTime? lastSeenAt;

  /// Public status («На совещании до 15:00»); null when none.
  final ChatUserStatus? status;

  /// The peer hides the online status (no «когда появится в сети»).
  final bool presenceHidden;

  String get label => displayName.isNotEmpty ? displayName : email;

  factory ChatUser.fromJson(Map<String, dynamic> j) => ChatUser(
    userId: j['user_id'] as String,
    email: (j['email'] as String?) ?? '',
    displayName: (j['display_name'] as String?) ?? '',
    online: j['online'] == true,
    lastSeenAt: parseApiDate(j['last_seen_at'] as String?),
    status: ChatUserStatus.fromJsonOrNull(j['status']),
    presenceHidden: j['presence_hidden'] == true,
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'email': email,
    'display_name': displayName,
    'online': online,
    'last_seen_at': ?lastSeenAt?.toUtc().toIso8601String(),
    'status': ?status?.toJson(),
    if (presenceHidden) 'presence_hidden': true,
  };

  ChatUser copyWith({
    bool? online,
    DateTime? lastSeenAt,
    ChatUserStatus? status,
    bool clearStatus = false,
  }) => ChatUser(
    userId: userId,
    email: email,
    displayName: displayName,
    online: online ?? this.online,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    status: clearStatus ? null : (status ?? this.status),
    presenceHidden: presenceHidden,
  );
}

class ChatAttachment {
  const ChatAttachment({
    required this.id,
    required this.conversationId,
    required this.filename,
    required this.mimeType,
    required this.size,
    required this.kind,
    required this.hasThumbnail,
    required this.scanStatus,
    this.width,
    this.height,
    this.durationMs,
  });
  final String id;
  final String conversationId;
  final String filename;
  final String mimeType;
  final int size;
  final String kind; // image | video | audio | voice | document
  final bool hasThumbnail;
  final String scanStatus;
  final int? width;
  final int? height;
  final int? durationMs;

  factory ChatAttachment.fromJson(Map<String, dynamic> j) => ChatAttachment(
    id: j['id'] as String,
    conversationId: (j['conversation_id'] as String?) ?? '',
    filename: (j['filename'] as String?) ?? '',
    mimeType: (j['mime_type'] as String?) ?? '',
    size: (j['size'] as num?)?.toInt() ?? 0,
    kind: (j['kind'] as String?) ?? 'document',
    hasThumbnail: j['has_thumbnail'] == true,
    scanStatus: (j['scan_status'] as String?) ?? '',
    width: (j['width'] as num?)?.toInt(),
    height: (j['height'] as num?)?.toInt(),
    durationMs: (j['duration_ms'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversation_id': conversationId,
    'filename': filename,
    'mime_type': mimeType,
    'size': size,
    'kind': kind,
    'has_thumbnail': hasThumbnail,
    'scan_status': scanStatus,
    'width': ?width,
    'height': ?height,
    'duration_ms': ?durationMs,
  };
}

/// Colleague card of a `contact` message. The client sends only
/// `{"user_id": …}` as a JSON string in `body`; the server resolves and
/// returns this object next to the message.
class ChatContact {
  const ChatContact({
    required this.userId,
    this.displayName = '',
    this.email = '',
  });
  final String userId;
  final String displayName;
  final String email;

  String get label => displayName.isNotEmpty ? displayName : email;

  factory ChatContact.fromJson(Map<String, dynamic> j) => ChatContact(
    userId: (j['user_id'] as String?) ?? '',
    displayName: (j['display_name'] as String?) ?? '',
    email: (j['email'] as String?) ?? '',
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'display_name': displayName,
    'email': email,
  };

  /// `body` of `POST /chats/{id}/messages` for `type: contact`.
  String toMessageBody() => jsonEncode({'user_id': userId});

  /// The user id from a contact message body (or null when malformed).
  static String? userIdFromBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['user_id'] is String) {
        return decoded['user_id'] as String;
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}

class ChatReaction {
  const ChatReaction({
    required this.reaction,
    required this.count,
    required this.userIds,
    required this.me,
  });
  final String reaction;
  final int count;
  final List<String> userIds;
  final bool me;

  factory ChatReaction.fromJson(Map<String, dynamic> j) => ChatReaction(
    reaction: (j['reaction'] as String?) ?? '',
    count: (j['count'] as num?)?.toInt() ?? 0,
    userIds: ((j['user_ids'] as List?) ?? const []).cast<String>(),
    me: j['me'] == true,
  );

  Map<String, dynamic> toJson() => {
    'reaction': reaction,
    'count': count,
    'user_ids': userIds,
    'me': me,
  };
}

class ChatReplyPreview {
  const ChatReplyPreview({
    required this.id,
    required this.senderId,
    required this.type,
    required this.body,
    required this.deleted,
  });
  final String id;
  final String senderId;
  final String type;
  final String body;
  final bool deleted;

  factory ChatReplyPreview.fromJson(Map<String, dynamic> j) => ChatReplyPreview(
    id: j['id'] as String,
    senderId: (j['sender_id'] as String?) ?? '',
    type: (j['type'] as String?) ?? 'text',
    body: (j['body'] as String?) ?? '',
    deleted: j['deleted'] == true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'sender_id': senderId,
    'type': type,
    'body': body,
    'deleted': deleted,
  };
}

/// Original author of a forwarded message (`forwarded_from`, newer servers).
class ChatForwardedFrom {
  const ChatForwardedFrom({
    required this.messageId,
    required this.senderId,
    this.displayName = '',
  });
  final String messageId;
  final String senderId;
  final String displayName;

  factory ChatForwardedFrom.fromJson(Map<String, dynamic> j) =>
      ChatForwardedFrom(
        messageId: (j['message_id'] as String?) ?? '',
        senderId: (j['sender_id'] as String?) ?? '',
        displayName: (j['display_name'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
    'message_id': messageId,
    'sender_id': senderId,
    'display_name': displayName,
  };
}

/// Delivery / read receipt of one member for an own message.
class ChatReceipt {
  const ChatReceipt({required this.userId, this.deliveredAt, this.readAt});
  final String userId;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  factory ChatReceipt.fromJson(Map<String, dynamic> j) => ChatReceipt(
    userId: (j['user_id'] as String?) ?? '',
    deliveredAt: parseApiDate(j['delivered_at'] as String?),
    readAt: parseApiDate(j['read_at'] as String?),
  );
}

/// Message. `pending`/`failed` exist only on the client (outbox state).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.seq,
    required this.type,
    required this.body,
    required this.clientMessageId,
    required this.createdAt,
    this.replyToId,
    this.replyTo,
    this.forwardOfId,
    this.mentions = const [],
    this.attachments = const [],
    this.reactions = const [],
    this.editedAt,
    this.deletedAt,
    this.status = 'sent',
    this.deliveredCount = 0,
    this.readCount = 0,
    this.recipientCount = 0,
    this.pending = false,
    this.failed = false,
    this.localFilePath,
    this.contact,
    this.forwardedFrom,
    this.linkPreview,
    this.expiresAt,
    this.sticker,
    this.transcript,
    this.poll,
    this.request,
    this.views,
    this.threadRootId,
    this.commentCount,
  });

  final String id;

  /// Channel post comments: the post this message comments on.
  final String? threadRootId;

  /// Channel posts (comments enabled): number of comments.
  final int? commentCount;
  final String conversationId;
  final String senderId;
  final int seq;

  /// Preview of the first link (filled asynchronously by the server).
  final ChatLinkPreview? linkPreview;

  /// Disappearing messages: removed for everyone after this moment.
  final DateTime? expiresAt;

  /// `type: sticker` messages.
  final ChatSticker? sticker;

  /// Shared transcript of a voice message.
  final ChatTranscript? transcript;

  /// `type: poll` messages (chat_poll.dart).
  final ChatPoll? poll;

  /// `type: request` / `request_update` messages (chat_request.dart).
  final ChatRequest? request;

  /// Channel posts: how many subscribers read it.
  final int? views;
  final String type;
  final String body;
  final String clientMessageId;
  final DateTime createdAt;

  /// Set for `type: contact` messages.
  final ChatContact? contact;
  final String? replyToId;
  final ChatReplyPreview? replyTo;
  final String? forwardOfId;

  /// Original author of a forwarded message (null on older servers).
  final ChatForwardedFrom? forwardedFrom;
  final List<String> mentions;
  final List<ChatAttachment> attachments;
  final List<ChatReaction> reactions;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final String status; // sent | delivered | read (own messages)
  final int deliveredCount;
  final int readCount;
  final int recipientCount;
  final bool pending;
  final bool failed;
  final String? localFilePath;

  bool get isDeleted => deletedAt != null;
  bool get isSystem => type == 'system';
  bool get isContact => type == 'contact';
  bool get isSticker => type == 'sticker';
  bool get isPoll => type == 'poll';

  /// A filed request («Заявки» chat).
  bool get isRequest => type == 'request';

  /// The bot's answer about a request («Заявки» chat).
  bool get isRequestUpdate => type == 'request_update';

  /// Server-inserted «Автоответ» of a user with a status (1:1 chats).
  bool get isAutoReply => type == 'auto_reply';

  /// Rendered as a centred service pill, not a bubble.
  bool get isServiceLike => isSystem || isAutoReply;

  /// A comment of a channel post (never part of the main feed).
  bool get isComment => threadRootId != null && threadRootId!.isNotEmpty;

  /// Disappearing message whose timer ran out (removed locally).
  bool isExpiredAt(DateTime now) =>
      expiresAt != null && !expiresAt!.isAfter(now);

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: j['id'] as String,
    conversationId: (j['conversation_id'] as String?) ?? '',
    senderId: (j['sender_id'] as String?) ?? '',
    seq: (j['seq'] as num?)?.toInt() ?? 0,
    type: (j['type'] as String?) ?? 'text',
    body: (j['body'] as String?) ?? '',
    clientMessageId: (j['client_message_id'] as String?) ?? '',
    createdAt:
        parseApiDate(j['created_at'] as String?) ?? DateTime.now().toUtc(),
    replyToId: j['reply_to_id'] as String?,
    replyTo: j['reply_to'] is Map
        ? ChatReplyPreview.fromJson(
            (j['reply_to'] as Map).cast<String, dynamic>(),
          )
        : null,
    forwardOfId: j['forward_of_id'] as String?,
    forwardedFrom: j['forwarded_from'] is Map
        ? ChatForwardedFrom.fromJson(
            (j['forwarded_from'] as Map).cast<String, dynamic>(),
          )
        : null,
    mentions: ((j['mentions'] as List?) ?? const []).cast<String>(),
    attachments: ((j['attachments'] as List?) ?? const [])
        .map((e) => ChatAttachment.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    reactions: ((j['reactions'] as List?) ?? const [])
        .map((e) => ChatReaction.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    editedAt: parseApiDate(j['edited_at'] as String?),
    deletedAt: parseApiDate(j['deleted_at'] as String?),
    status: (j['status'] as String?) ?? 'sent',
    deliveredCount: (j['delivered_count'] as num?)?.toInt() ?? 0,
    readCount: (j['read_count'] as num?)?.toInt() ?? 0,
    recipientCount: (j['recipient_count'] as num?)?.toInt() ?? 0,
    pending: j['_pending'] == true,
    failed: j['_failed'] == true,
    localFilePath: j['_local_file'] as String?,
    contact: j['contact'] is Map
        ? ChatContact.fromJson((j['contact'] as Map).cast<String, dynamic>())
        : null,
    linkPreview: j['link_preview'] is Map
        ? ChatLinkPreview.fromJson(
            (j['link_preview'] as Map).cast<String, dynamic>(),
          )
        : null,
    expiresAt: parseApiDate(j['expires_at'] as String?),
    sticker: j['sticker'] is Map
        ? ChatSticker.fromJson((j['sticker'] as Map).cast<String, dynamic>())
        : null,
    transcript: j['transcript'] is Map
        ? ChatTranscript.fromJson(
            (j['transcript'] as Map).cast<String, dynamic>(),
          )
        : null,
    poll: j['poll'] is Map
        ? ChatPoll.fromJson((j['poll'] as Map).cast<String, dynamic>())
        : null,
    request: j['request'] is Map
        ? ChatRequest.fromJson((j['request'] as Map).cast<String, dynamic>())
        : null,
    views: (j['views'] as num?)?.toInt(),
    threadRootId: j['thread_root_id'] as String?,
    commentCount: (j['comment_count'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversation_id': conversationId,
    'sender_id': senderId,
    'seq': seq,
    'type': type,
    'body': body,
    'client_message_id': clientMessageId,
    'created_at': createdAt.toUtc().toIso8601String(),
    'reply_to_id': ?replyToId,
    'reply_to': ?replyTo?.toJson(),
    'forward_of_id': ?forwardOfId,
    'forwarded_from': ?forwardedFrom?.toJson(),
    'mentions': mentions,
    'attachments': attachments.map((a) => a.toJson()).toList(),
    'reactions': reactions.map((r) => r.toJson()).toList(),
    'edited_at': ?editedAt?.toUtc().toIso8601String(),
    'deleted_at': ?deletedAt?.toUtc().toIso8601String(),
    'status': status,
    'delivered_count': deliveredCount,
    'read_count': readCount,
    'recipient_count': recipientCount,
    if (pending) '_pending': true,
    if (failed) '_failed': true,
    '_local_file': ?localFilePath,
    'contact': ?contact?.toJson(),
    'link_preview': ?linkPreview?.toJson(),
    'expires_at': ?expiresAt?.toUtc().toIso8601String(),
    'sticker': ?sticker?.toJson(),
    'transcript': ?transcript?.toJson(),
    'poll': ?poll?.toJson(),
    'request': ?request?.toJson(),
    'views': ?views,
    'thread_root_id': ?threadRootId,
    'comment_count': ?commentCount,
  };

  ChatMessage copyWith({
    String? body,
    List<ChatReaction>? reactions,
    DateTime? editedAt,
    DateTime? deletedAt,
    String? status,
    int? deliveredCount,
    int? readCount,
    bool? pending,
    bool? failed,
    ChatLinkPreview? linkPreview,
    bool clearLinkPreview = false,
    ChatTranscript? transcript,
    bool clearTranscript = false,
    ChatPoll? poll,
    int? views,
    int? commentCount,
  }) => ChatMessage(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    seq: seq,
    type: type,
    body: body ?? this.body,
    clientMessageId: clientMessageId,
    createdAt: createdAt,
    replyToId: replyToId,
    replyTo: replyTo,
    forwardOfId: forwardOfId,
    forwardedFrom: forwardedFrom,
    mentions: mentions,
    attachments: attachments,
    reactions: reactions ?? this.reactions,
    editedAt: editedAt ?? this.editedAt,
    deletedAt: deletedAt ?? this.deletedAt,
    status: status ?? this.status,
    deliveredCount: deliveredCount ?? this.deliveredCount,
    readCount: readCount ?? this.readCount,
    recipientCount: recipientCount,
    pending: pending ?? this.pending,
    failed: failed ?? this.failed,
    localFilePath: localFilePath,
    contact: contact,
    linkPreview: clearLinkPreview ? null : (linkPreview ?? this.linkPreview),
    expiresAt: expiresAt,
    sticker: sticker,
    transcript: clearTranscript ? null : (transcript ?? this.transcript),
    poll: poll ?? this.poll,
    request: request,
    views: views ?? this.views,
    threadRootId: threadRootId,
    commentCount: commentCount ?? this.commentCount,
  );
}

class ChatSettings {
  const ChatSettings({
    this.showLastSeen = true,
    this.showOnline = true,
    this.readReceipts = true,
    this.pushPreview = true,
  });
  final bool showLastSeen;
  final bool showOnline;
  final bool readReceipts;
  final bool pushPreview;

  factory ChatSettings.fromJson(Map<String, dynamic> j) => ChatSettings(
    showLastSeen: j['show_last_seen'] != false,
    showOnline: j['show_online'] != false,
    readReceipts: j['read_receipts'] != false,
    pushPreview: j['push_preview'] != false,
  );

  Map<String, dynamic> toJson() => {
    'show_last_seen': showLastSeen,
    'show_online': showOnline,
    'read_receipts': readReceipts,
    'push_preview': pushPreview,
  };

  ChatSettings copyWith({
    bool? showLastSeen,
    bool? showOnline,
    bool? readReceipts,
    bool? pushPreview,
  }) => ChatSettings(
    showLastSeen: showLastSeen ?? this.showLastSeen,
    showOnline: showOnline ?? this.showOnline,
    readReceipts: readReceipts ?? this.readReceipts,
    pushPreview: pushPreview ?? this.pushPreview,
  );
}

/// One realtime / delta-sync event. `type` follows ТЗ п.5.3.
class ChatEvent {
  const ChatEvent({
    required this.type,
    required this.conversationId,
    required this.seq,
    required this.payload,
  });
  final String type;
  final String conversationId;
  final int seq; // 0 for ephemeral events
  final Map<String, dynamic> payload;

  factory ChatEvent.fromFrame(Map<String, dynamic> frame) => ChatEvent(
    type: (frame['type'] as String?) ?? '',
    conversationId: (frame['conversation_id'] as String?) ?? '',
    seq: (frame['seq'] as num?)?.toInt() ?? 0,
    payload: frame,
  );

  /// From `GET /chats/{id}/events` rows (payload is nested).
  factory ChatEvent.fromLogRow(Map<String, dynamic> row) {
    final payload = (row['payload'] as Map?)?.cast<String, dynamic>() ?? {};
    return ChatEvent(
      type: (row['type'] as String?) ?? '',
      conversationId: (row['conversation_id'] as String?) ?? '',
      seq: (row['seq'] as num?)?.toInt() ?? 0,
      payload: {
        ...payload,
        'conversation_id': row['conversation_id'],
        'seq': row['seq'],
      },
    );
  }

  static final _parsed = Expando<ChatMessage>();

  /// The `message` of the payload, parsed once per event (several listeners
  /// read it).
  ChatMessage? get message {
    final raw = payload['message'];
    if (raw is! Map) return null;
    return _parsed[raw] ??= ChatMessage.fromJson(raw.cast<String, dynamic>());
  }
  String get userId => (payload['user_id'] as String?) ?? '';
  String get messageId => (payload['message_id'] as String?) ?? '';
}

/// Queued outgoing message (survives restarts; retried idempotently with
/// the same client_message_id — ТЗ п.5.4, п.24.17).
class OutboxItem {
  const OutboxItem({
    required this.clientMessageId,
    required this.conversationId,
    required this.type,
    required this.body,
    required this.createdAt,
    this.replyToId,
    this.forwardOfId,
    this.attachmentIds = const [],
    this.localFilePath,
    this.localFileName,
    this.voice = false,
    this.durationMs,
    this.mentions = const [],
    this.attempts = 0,
    this.failed = false,
    this.errorCode,
    this.contact,
  });

  /// Local copy of the picked colleague for a queued contact message (the
  /// request itself carries only the JSON body).
  final ChatContact? contact;

  final String clientMessageId;
  final String conversationId;
  final String type;
  final String body;
  final DateTime createdAt;
  final String? replyToId;
  final String? forwardOfId;
  final List<String> attachmentIds;

  /// Local file still to be uploaded (attachment message).
  final String? localFilePath;
  final String? localFileName;
  final bool voice;
  final int? durationMs;
  final List<String> mentions;
  final int attempts;
  final bool failed;
  final String? errorCode;

  factory OutboxItem.fromJson(Map<String, dynamic> j) => OutboxItem(
    clientMessageId: j['client_message_id'] as String,
    conversationId: j['conversation_id'] as String,
    type: (j['type'] as String?) ?? 'text',
    body: (j['body'] as String?) ?? '',
    createdAt:
        parseApiDate(j['created_at'] as String?) ?? DateTime.now().toUtc(),
    replyToId: j['reply_to_id'] as String?,
    forwardOfId: j['forward_of_id'] as String?,
    attachmentIds: ((j['attachment_ids'] as List?) ?? const []).cast<String>(),
    localFilePath: j['local_file'] as String?,
    localFileName: j['local_file_name'] as String?,
    voice: j['voice'] == true,
    durationMs: (j['duration_ms'] as num?)?.toInt(),
    mentions: ((j['mentions'] as List?) ?? const []).cast<String>(),
    attempts: (j['attempts'] as num?)?.toInt() ?? 0,
    failed: j['failed'] == true,
    errorCode: j['error_code'] as String?,
    contact: j['contact'] is Map
        ? ChatContact.fromJson((j['contact'] as Map).cast<String, dynamic>())
        : null,
  );

  Map<String, dynamic> toJson() => {
    'client_message_id': clientMessageId,
    'conversation_id': conversationId,
    'type': type,
    'body': body,
    'created_at': createdAt.toUtc().toIso8601String(),
    'reply_to_id': ?replyToId,
    'forward_of_id': ?forwardOfId,
    'attachment_ids': attachmentIds,
    'local_file': ?localFilePath,
    'local_file_name': ?localFileName,
    'voice': voice,
    'duration_ms': ?durationMs,
    'mentions': mentions,
    'attempts': attempts,
    'failed': failed,
    'error_code': ?errorCode,
    'contact': ?contact?.toJson(),
  };

  OutboxItem copyWith({
    List<String>? attachmentIds,
    int? attempts,
    bool? failed,
    String? errorCode,
    bool clearLocalFile = false,
  }) => OutboxItem(
    clientMessageId: clientMessageId,
    conversationId: conversationId,
    type: type,
    body: body,
    createdAt: createdAt,
    replyToId: replyToId,
    forwardOfId: forwardOfId,
    attachmentIds: attachmentIds ?? this.attachmentIds,
    localFilePath: clearLocalFile ? null : localFilePath,
    localFileName: localFileName,
    voice: voice,
    durationMs: durationMs,
    mentions: mentions,
    attempts: attempts ?? this.attempts,
    failed: failed ?? this.failed,
    errorCode: errorCode ?? this.errorCode,
    contact: contact,
  );

  /// Placeholder message shown in the list while queued.
  ChatMessage toPendingMessage(String selfId) => ChatMessage(
    id: 'pending:$clientMessageId',
    conversationId: conversationId,
    senderId: selfId,
    seq: 0,
    type: type,
    body: body,
    clientMessageId: clientMessageId,
    createdAt: createdAt,
    replyToId: replyToId,
    mentions: mentions,
    pending: !failed,
    failed: failed,
    localFilePath: localFilePath,
    contact: contact,
    attachments: localFilePath == null
        ? const []
        : [
            ChatAttachment(
              id: 'local:$clientMessageId',
              conversationId: conversationId,
              filename: localFileName ?? '',
              mimeType: '',
              size: 0,
              kind: voice ? 'voice' : 'document',
              hasThumbnail: false,
              scanStatus: 'pending',
              durationMs: durationMs,
            ),
          ],
  );
}
