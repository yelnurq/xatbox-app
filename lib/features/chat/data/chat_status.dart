import '../../../core/api/api_client.dart';
import '../../../shared/utils/api_date.dart';

/// Status presets of «Статус» (chat-service `/me/status`).
enum ChatStatusPreset {
  inClass('in_class', '📚'),
  meeting('meeting', '📅'),
  businessTrip('business_trip', '✈️'),
  vacation('vacation', '🌴'),
  sick('sick', '🤒'),
  dnd('dnd', '⛔'),
  custom('custom', '💬');

  const ChatStatusPreset(this.apiName, this.emoji);
  final String apiName;

  /// Default emoji of the preset.
  final String emoji;

  static ChatStatusPreset parse(String? raw) => values.firstWhere(
    (p) => p.apiName == raw,
    orElse: () => ChatStatusPreset.custom,
  );
}

/// A user's status: preset, emoji, optional text and end time. `autoReply`
/// is present only on the caller's own status (`GET /me/status`).
class ChatUserStatus {
  const ChatUserStatus({
    required this.preset,
    this.emoji = '',
    this.text = '',
    this.until,
    this.setAt,
    this.autoReply = '',
  });

  final ChatStatusPreset preset;
  final String emoji;
  final String text;
  final DateTime? until;
  final DateTime? setAt;
  final String autoReply;

  static const maxText = 70;
  static const maxEmoji = 8;
  static const maxAutoReply = 500;

  /// Still in effect at [now] (the server never returns expired ones, but a
  /// cached copy can run out while the app is open).
  bool isActiveAt(DateTime now) => until == null || until!.isAfter(now);

  /// Emoji shown next to the label (the preset's when none was chosen).
  String get displayEmoji => emoji.isNotEmpty ? emoji : preset.emoji;

  static ChatUserStatus? fromJsonOrNull(Object? raw) {
    if (raw is! Map) return null;
    return ChatUserStatus.fromJson(raw.cast<String, dynamic>());
  }

  factory ChatUserStatus.fromJson(Map<String, dynamic> j) => ChatUserStatus(
    preset: ChatStatusPreset.parse(j['preset'] as String?),
    emoji: (j['emoji'] as String?) ?? '',
    text: (j['text'] as String?) ?? '',
    until: parseApiDate(j['until'] as String?),
    setAt: parseApiDate(j['set_at'] as String?),
    autoReply: (j['auto_reply'] as String?) ?? '',
  );

  /// Cache form (public fields; the auto-reply only when set).
  Map<String, dynamic> toJson() => {
    'preset': preset.apiName,
    'emoji': emoji,
    'text': text,
    'until': ?until?.toUtc().toIso8601String(),
    'set_at': ?setAt?.toUtc().toIso8601String(),
    if (autoReply.isNotEmpty) 'auto_reply': autoReply,
  };

  /// `PUT /me/status` body.
  Map<String, dynamic> toRequest() => {
    'preset': preset.apiName,
    'emoji': emoji,
    'text': text,
    'until': until?.toUtc().toIso8601String(),
    'auto_reply': autoReply,
  };

  /// Client-side check of the server limits; null when valid, otherwise the
  /// failing field (`text`, `emoji`, `auto_reply`, `until`).
  String? validate(DateTime now) {
    if (text.runes.length > maxText) return 'text';
    if (emoji.runes.length > maxEmoji) return 'emoji';
    if (autoReply.runes.length > maxAutoReply) return 'auto_reply';
    if (preset == ChatStatusPreset.custom &&
        text.trim().isEmpty &&
        emoji.trim().isEmpty) {
      return 'text';
    }
    final u = until;
    if (u != null &&
        (!u.isAfter(now) || u.isAfter(now.add(const Duration(days: 366))))) {
      return 'until';
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is ChatUserStatus &&
      other.preset == preset &&
      other.emoji == emoji &&
      other.text == text &&
      other.until == until &&
      other.autoReply == autoReply;

  @override
  int get hashCode => Object.hash(preset, emoji, text, until, autoReply);
}

/// «До»: how long a status lasts.
enum ChatStatusUntil { none, hour, endOfDay, endOfWeek, custom }

abstract final class ChatStatusDurations {
  /// The end time of [option] at [now] (null: no end; custom: [picked]).
  static DateTime? resolve(
    ChatStatusUntil option,
    DateTime now, {
    DateTime? picked,
  }) => switch (option) {
    ChatStatusUntil.none => null,
    ChatStatusUntil.hour => now.add(const Duration(hours: 1)),
    ChatStatusUntil.endOfDay => DateTime(now.year, now.month, now.day, 23, 59),
    // Sunday 23:59 of the current week (Monday is the first day).
    ChatStatusUntil.endOfWeek => DateTime(
      now.year,
      now.month,
      now.day + (DateTime.sunday - now.weekday),
      23,
      59,
    ),
    ChatStatusUntil.custom => picked,
  };
}

/// `GET/PUT/DELETE /me/status`.
class ChatStatusApi {
  ChatStatusApi(this._client);
  final ApiClient _client;

  static const path = '/me/status';

  Future<ChatUserStatus?> fetch() async =>
      ChatUserStatus.fromJsonOrNull((await _client.getJson(path))['status']);

  Future<ChatUserStatus?> save(ChatUserStatus status) async =>
      ChatUserStatus.fromJsonOrNull(
        (await _client.putJson(path, body: status.toRequest()))['status'],
      );

  Future<void> clear() async {
    await _client.deleteJson(path, expectedStatuses: const {204});
  }
}
