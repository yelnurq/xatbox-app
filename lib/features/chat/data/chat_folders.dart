import '../../../core/api/api_client.dart';
import '../../../shared/utils/api_date.dart';
import 'chat_models.dart';

/// A user chat folder (`GET/PUT /me/chat-folders`).
class ChatFolder {
  const ChatFolder({
    required this.id,
    required this.name,
    this.emoji = '',
    this.chatIds = const [],
    this.types = const [],
    this.unreadOnly = false,
    this.excludeMuted = false,
  });

  final String id;
  final String name;
  final String emoji;

  /// Explicitly included conversations (the saved chat only this way).
  final List<String> chatIds;

  /// Included chat types: `direct`, `group`, `channel`.
  final List<String> types;
  final bool unreadOnly;
  final bool excludeMuted;

  static const maxFolders = 10;
  static const maxName = 32;
  static const maxEmoji = 8;
  static const maxChats = 200;
  static const allTypes = ['direct', 'group', 'channel'];

  factory ChatFolder.fromJson(Map<String, dynamic> j) => ChatFolder(
    id: (j['id'] as String?) ?? '',
    name: (j['name'] as String?) ?? '',
    emoji: (j['emoji'] as String?) ?? '',
    chatIds: ((j['chat_ids'] as List?) ?? const [])
        .whereType<String>()
        .toList(),
    types: ((j['types'] as List?) ?? const []).whereType<String>().toList(),
    unreadOnly: j['unread_only'] == true,
    excludeMuted: j['exclude_muted'] == true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'chat_ids': chatIds,
    'types': types,
    'unread_only': unreadOnly,
    'exclude_muted': excludeMuted,
  };

  ChatFolder copyWith({
    String? name,
    String? emoji,
    List<String>? chatIds,
    List<String>? types,
    bool? unreadOnly,
    bool? excludeMuted,
  }) => ChatFolder(
    id: id,
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    chatIds: chatIds ?? this.chatIds,
    types: types ?? this.types,
    unreadOnly: unreadOnly ?? this.unreadOnly,
    excludeMuted: excludeMuted ?? this.excludeMuted,
  );

  /// Null when the folder satisfies the server rules, else the failing field
  /// (`name`, `emoji`, `chats`, `empty`).
  String? validate() {
    final n = name.trim().runes.length;
    if (n < 1 || n > maxName) return 'name';
    if (emoji.runes.length > maxEmoji) return 'emoji';
    if (chatIds.length > maxChats) return 'chats';
    if (chatIds.isEmpty && types.isEmpty) return 'empty';
    return null;
  }

  /// Whether [c] belongs to the folder at [now] (pure, unit-tested):
  /// explicit id or included type (the saved chat only by id), then the
  /// unread-only and exclude-muted narrowing.
  bool matches(ChatConversation c, DateTime now) {
    final byId = chatIds.contains(c.id);
    final byType = !c.isSaved && types.contains(c.type);
    if (!byId && !byType) return false;
    if (unreadOnly && !(c.unread > 0 || c.settings.markedUnread)) return false;
    if (excludeMuted) {
      final until = c.settings.mutedUntil;
      if (until != null && until.isAfter(now)) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is ChatFolder &&
      other.id == id &&
      other.name == name &&
      other.emoji == emoji &&
      _sameList(other.chatIds, chatIds) &&
      _sameList(other.types, types) &&
      other.unreadOnly == unreadOnly &&
      other.excludeMuted == excludeMuted;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    emoji,
    Object.hashAll(chatIds),
    Object.hashAll(types),
    unreadOnly,
    excludeMuted,
  );

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

typedef ChatFoldersPayload = ({List<ChatFolder> folders, DateTime? updatedAt});

List<ChatFolder> parseChatFolders(Object? raw) => ((raw as List?) ?? const [])
    .whereType<Map>()
    .map((e) => ChatFolder.fromJson(e.cast<String, dynamic>()))
    .toList();

class ChatFoldersApi {
  ChatFoldersApi(this._client);
  final ApiClient _client;

  static const path = '/me/chat-folders';

  ChatFoldersPayload _parse(Map<String, dynamic> json) => (
    folders: parseChatFolders(json['folders']),
    updatedAt: parseApiDate(json['updated_at'] as String?),
  );

  Future<ChatFoldersPayload> fetch() async => _parse(await _client.getJson(path));

  /// Full ordered replacement.
  Future<ChatFoldersPayload> save(List<ChatFolder> folders) async => _parse(
    await _client.putJson(
      path,
      body: {'folders': [for (final f in folders) f.toJson()]},
    ),
  );
}
