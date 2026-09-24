import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/utils/api_date.dart';

/// Messenger, part 2 (chat-service migration 0011): protected chats,
/// disappearing messages, stickers, voice transcripts, reports and
/// moderation.

/// Protection of a conversation (`protection` of `GET /chats/{id}`).
class ChatProtection {
  const ChatProtection({
    this.noForward = false,
    this.screenshotProtection = false,
    this.disappearingTtl = 0,
  });

  /// «Запретить пересылку и копирование».
  final bool noForward;

  /// «Защита от скриншотов».
  final bool screenshotProtection;

  /// Seconds; 0 = disappearing messages off.
  final int disappearingTtl;

  static const ttlOptions = [0, 86400, 604800, 2592000];

  bool get active =>
      noForward || screenshotProtection || disappearingTtl > 0;

  factory ChatProtection.fromJson(Map<String, dynamic>? j) => j == null
      ? const ChatProtection()
      : ChatProtection(
          noForward: j['no_forward'] == true,
          screenshotProtection: j['screenshot_protection'] == true,
          disappearingTtl: (j['disappearing_ttl'] as num?)?.toInt() ?? 0,
        );

  Map<String, dynamic> toJson() => {
    'no_forward': noForward,
    'screenshot_protection': screenshotProtection,
    'disappearing_ttl': disappearingTtl,
  };

  ChatProtection copyWith({
    bool? noForward,
    bool? screenshotProtection,
    int? disappearingTtl,
  }) => ChatProtection(
    noForward: noForward ?? this.noForward,
    screenshotProtection: screenshotProtection ?? this.screenshotProtection,
    disappearingTtl: disappearingTtl ?? this.disappearingTtl,
  );

  @override
  bool operator ==(Object other) =>
      other is ChatProtection &&
      other.noForward == noForward &&
      other.screenshotProtection == screenshotProtection &&
      other.disappearingTtl == disappearingTtl;

  @override
  int get hashCode =>
      Object.hash(noForward, screenshotProtection, disappearingTtl);
}

/// Sticker of a message (`sticker`) or a pack.
class ChatSticker {
  const ChatSticker({
    required this.id,
    this.packId = '',
    this.emoji = '',
    this.width = 512,
    this.height = 512,
    this.mimeType = 'image/png',
  });
  final String id;
  final String packId;
  final String emoji;
  final int width;
  final int height;
  final String mimeType;

  factory ChatSticker.fromJson(Map<String, dynamic> j) => ChatSticker(
    id: (j['id'] as String?) ?? '',
    packId: (j['pack_id'] as String?) ?? '',
    emoji: (j['emoji'] as String?) ?? '',
    width: (j['width'] as num?)?.toInt() ?? 512,
    height: (j['height'] as num?)?.toInt() ?? 512,
    mimeType: (j['mime_type'] as String?) ?? 'image/png',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'pack_id': packId,
    'emoji': emoji,
    'width': width,
    'height': height,
    'mime_type': mimeType,
  };

  /// `body` of `POST /chats/{id}/messages` for `type: sticker`.
  String toMessageBody() => '{"sticker_id":"$id"}';

  /// The sticker id of a sticker message body (or null).
  static String? idFromBody(String body) =>
      RegExp(r'"sticker_id"\s*:\s*"([0-9a-fA-F-]{36})"')
          .firstMatch(body)
          ?.group(1)
          ?.toLowerCase();
}

class ChatStickerPack {
  const ChatStickerPack({
    required this.id,
    required this.title,
    this.author = '',
    this.isDefault = false,
    this.coverStickerId = '',
    this.stickers = const [],
  });
  final String id;
  final String title;
  final String author;
  final bool isDefault;
  final String coverStickerId;
  final List<ChatSticker> stickers;

  factory ChatStickerPack.fromJson(Map<String, dynamic> j) => ChatStickerPack(
    id: (j['id'] as String?) ?? '',
    title: (j['title'] as String?) ?? '',
    author: (j['author'] as String?) ?? '',
    isDefault: j['is_default'] == true,
    coverStickerId: (j['cover_sticker_id'] as String?) ?? '',
    stickers: ((j['stickers'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => ChatSticker.fromJson(e.cast<String, dynamic>()))
        .toList(),
  );
}

/// Shared transcript of a voice message (`transcript`).
class ChatTranscript {
  const ChatTranscript({required this.status, this.text = '', this.language = ''});

  /// pending | done | failed
  final String status;
  final String text;
  final String language;

  bool get pending => status == 'pending';
  bool get done => status == 'done';
  bool get failed => status == 'failed';

  factory ChatTranscript.fromJson(Map<String, dynamic> j) => ChatTranscript(
    status: (j['status'] as String?) ?? 'pending',
    text: (j['text'] as String?) ?? '',
    language: (j['language'] as String?) ?? '',
  );

  Map<String, dynamic> toJson() => {
    'status': status,
    'text': text,
    if (language.isNotEmpty) 'language': language,
  };
}

/// `GET /features`.
class ChatFeatures {
  const ChatFeatures({
    this.transcription = false,
    this.transcriptionMaxSeconds = 600,
    this.stickers = false,
    this.reports = false,
    this.protectedChats = false,
    this.moderation = false,
    this.moderationGlobal = false,
    this.stickerAdmin = false,
    this.translation = false,
    this.translationMaxChars = 5000,
  });
  final bool transcription;
  final int transcriptionMaxSeconds;
  final bool stickers;
  final bool reports;
  final bool protectedChats;

  /// May open «Модерация» (organization moderator or a group admin).
  final bool moderation;
  final bool moderationGlobal;
  final bool stickerAdmin;

  /// Message translation (`POST /translate`, `/messages/{id}/translate`).
  final bool translation;
  final int translationMaxChars;

  /// Older servers without `GET /features`.
  static const none = ChatFeatures();

  factory ChatFeatures.fromJson(Map<String, dynamic> j) => ChatFeatures(
    transcription: j['transcription'] == true,
    transcriptionMaxSeconds:
        (j['transcription_max_seconds'] as num?)?.toInt() ?? 600,
    stickers: j['stickers'] == true,
    reports: j['reports'] == true,
    protectedChats: j['protected_chats'] == true,
    moderation: j['moderation'] == true,
    moderationGlobal: j['moderation_global'] == true,
    stickerAdmin: j['sticker_admin'] == true,
    translation: j['translation'] == true,
    translationMaxChars:
        (j['translation_max_chars'] as num?)?.toInt() ?? 5000,
  );
}

/// Reasons of «Пожаловаться».
enum ChatReportReason {
  spam,
  abuse,
  confidential,
  other;

  String get apiName => name;

  static ChatReportReason parse(String? s) =>
      values.where((v) => v.name == s).firstOrNull ?? other;
}

/// Moderation actions on a report.
enum ModerationAction {
  deleteMessage('delete_message'),
  warn('warn'),
  removeMember('remove_member'),
  mute('mute'),
  dismiss('dismiss');

  const ModerationAction(this.apiName);
  final String apiName;

  static ModerationAction? parse(String? s) =>
      values.where((v) => v.apiName == s).firstOrNull;
}

/// A report in the moderation queue (`GET /moderation/reports`).
class ChatReport {
  const ChatReport({
    required this.id,
    required this.conversationId,
    required this.messageId,
    required this.reason,
    required this.status,
    this.conversationType = 'group',
    this.conversationTitle = '',
    this.reporterId = '',
    this.reporterName = '',
    this.reportedUserId = '',
    this.reportedUserName = '',
    this.comment = '',
    this.resolution,
    this.snapshotType = 'text',
    this.snapshotBody = '',
    this.snapshotAttachments = const [],
    this.createdAt,
    this.resolvedAt,
    this.context = const [],
    this.reportedIsMember = false,
    this.restrictedUntil,
  });

  final String id;
  final String conversationId;
  final String conversationType;
  final String conversationTitle;
  final String messageId;
  final String reporterId;
  final String reporterName;
  final String reportedUserId;
  final String reportedUserName;
  final ChatReportReason reason;
  final String comment;

  /// open | resolved | dismissed
  final String status;
  final ModerationAction? resolution;
  final String snapshotType;
  final String snapshotBody;
  final List<String> snapshotAttachments;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  /// ±5 messages around the reported one (details only), raw JSON.
  final List<Map<String, dynamic>> context;
  final bool reportedIsMember;
  final DateTime? restrictedUntil;

  bool get isOpen => status == 'open';
  bool get isGroupLike =>
      conversationType != 'direct' && conversationType != 'saved';

  factory ChatReport.fromJson(Map<String, dynamic> j) {
    final snap = (j['snapshot'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ChatReport(
      id: (j['id'] as String?) ?? '',
      conversationId: (j['conversation_id'] as String?) ?? '',
      conversationType: (j['conversation_type'] as String?) ?? 'group',
      conversationTitle: (j['conversation_title'] as String?) ?? '',
      messageId: (j['message_id'] as String?) ?? '',
      reporterId: (j['reporter_id'] as String?) ?? '',
      reporterName: (j['reporter_name'] as String?) ?? '',
      reportedUserId: (j['reported_user_id'] as String?) ?? '',
      reportedUserName: (j['reported_user_name'] as String?) ?? '',
      reason: ChatReportReason.parse(j['reason'] as String?),
      comment: (j['comment'] as String?) ?? '',
      status: (j['status'] as String?) ?? 'open',
      resolution: ModerationAction.parse(j['resolution'] as String?),
      snapshotType: (snap['type'] as String?) ?? 'text',
      snapshotBody: (snap['body'] as String?) ?? '',
      snapshotAttachments: ((snap['attachments'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      createdAt: parseApiDate(j['created_at'] as String?),
      resolvedAt: parseApiDate(j['resolved_at'] as String?),
      context: ((j['context'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(),
      reportedIsMember: j['reported_is_member'] == true,
      restrictedUntil: parseApiDate(j['restricted_until'] as String?),
    );
  }
}

class ChatReportsPage {
  const ChatReportsPage({
    required this.reports,
    this.nextCursor = '',
    this.openCount = 0,
    this.global = false,
  });
  final List<ChatReport> reports;
  final String nextCursor;
  final int openCount;
  final bool global;
}

/// REST client of the part-2 endpoints (same client as [ChatApi]).
class ChatMessenger2Api {
  ChatMessenger2Api(this._client);
  final ApiClient _client;

  String _id(String id) => Uri.encodeComponent(id);

  Future<ChatFeatures> features() async {
    try {
      return ChatFeatures.fromJson(await _client.getJson('/features'));
    } on ApiException catch (e) {
      if (e.statusCode == 404) return ChatFeatures.none; // older server
      rethrow;
    }
  }

  /// `PUT /chats/{id}/protection`; returns the conversation JSON.
  Future<Map<String, dynamic>> setProtection(
    String chatId, {
    bool? noForward,
    bool? screenshotProtection,
    int? disappearingTtl,
  }) => _client.putJson(
    '/chats/${_id(chatId)}/protection',
    body: {
      'no_forward': ?noForward,
      'screenshot_protection': ?screenshotProtection,
      'disappearing_ttl': ?disappearingTtl,
    },
  );

  /// `POST /messages/{id}/report` → the neutral status (`open`/`reviewed`).
  Future<String> report(
    String messageId, {
    required ChatReportReason reason,
    String comment = '',
  }) async {
    final json = await _client.postJson(
      '/messages/${_id(messageId)}/report',
      body: {'reason': reason.apiName, 'comment': comment},
      expectedStatuses: const {200, 201},
    );
    return ((json['report'] as Map?)?['status'] as String?) ?? 'open';
  }

  Future<ChatReportsPage> reports({
    String status = 'open',
    String? cursor,
  }) async {
    final json = await _client.getJson(
      '/moderation/reports',
      query: {
        'status': status,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    return ChatReportsPage(
      reports: ((json['reports'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ChatReport.fromJson(e.cast<String, dynamic>()))
          .toList(),
      nextCursor: (json['next_cursor'] as String?) ?? '',
      openCount: (json['open_count'] as num?)?.toInt() ?? 0,
      global: json['global'] == true,
    );
  }

  Future<ChatReport> reportDetails(String id) async {
    final json = await _client.getJson('/moderation/reports/${_id(id)}');
    return ChatReport.fromJson(
      (json['report'] as Map).cast<String, dynamic>(),
    );
  }

  Future<ChatReport> moderate(
    String reportId,
    ModerationAction action, {
    int? hours,
    String note = '',
  }) async {
    final json = await _client.postJson(
      '/moderation/reports/${_id(reportId)}/actions',
      body: {
        'action': action.apiName,
        'hours': ?hours,
        if (note.isNotEmpty) 'note': note,
      },
      expectedStatuses: const {200},
    );
    return ChatReport.fromJson(
      (json['report'] as Map).cast<String, dynamic>(),
    );
  }

  Future<List<ChatStickerPack>> stickerPacks() async {
    final json = await _client.getJson('/sticker-packs');
    return ((json['packs'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => ChatStickerPack.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// Downloads a sticker image to [savePath].
  Future<void> downloadSticker(String stickerId, String savePath) async {
    await _client.send(
      () => _client.dio.download(
        '/stickers/${_id(stickerId)}/image',
        savePath,
        options: Options(headers: {'Accept': 'image/*'}),
      ),
    );
    if (!File(savePath).existsSync()) {
      throw const UnexpectedApiException('download produced no file');
    }
  }

  /// `POST /messages/{id}/transcribe` (202 queued, 200 current).
  Future<ChatTranscript> transcribe(String messageId) async {
    final json = await _client.postJson(
      '/messages/${_id(messageId)}/transcribe',
      expectedStatuses: const {200, 202},
    );
    final raw = json['transcript'];
    return raw is Map
        ? ChatTranscript.fromJson(raw.cast<String, dynamic>())
        : const ChatTranscript(status: 'pending');
  }
}
