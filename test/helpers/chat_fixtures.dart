/// JSON fixtures shaped like the Chat Service API.
abstract final class ChatFixtures {
  static const me =
      '11111111-1111-4111-8111-111111111111'; // same as Fixtures.me()
  static const peer = '22222222-2222-4222-8222-222222222222';
  static const carol = '44444444-4444-4444-8444-444444444444';
  static const conv = 'c0000000-0000-4000-8000-000000000001';

  static Map<String, dynamic> user({
    String id = peer,
    String name = 'Bob',
    bool online = false,
  }) => {
    'user_id': id,
    'email': '${name.toLowerCase()}@example.kz',
    'display_name': name,
    'online': online,
  };

  static Map<String, dynamic> message({
    required String id,
    required int seq,
    String body = 'hi',
    String sender = peer,
    String convId = conv,
    String status = 'sent',
    String? clientId,
    String type = 'text',
    List<String> mentions = const [],
    List<Map<String, dynamic>> attachments = const [],
    Map<String, dynamic>? contact,
  }) => {
    'id': id,
    'conversation_id': convId,
    'sender_id': sender,
    'seq': seq,
    'type': type,
    'body': body,
    'client_message_id': clientId ?? 'cid-$id',
    'mentions': mentions,
    'attachments': attachments,
    'reactions': <Map<String, dynamic>>[],
    'created_at': '2026-09-14T10:0${seq % 10}:00Z',
    'status': status,
    'delivered_count': 0,
    'read_count': 0,
    'recipient_count': 1,
    'contact': ?contact,
  };

  static Map<String, dynamic> attachment({
    required String id,
    String kind = 'video',
    String filename = 'clip.mp4',
    String mimeType = 'video/mp4',
    bool hasThumbnail = true,
    int? width,
    int? height,
    int? durationMs,
    String convId = conv,
  }) => {
    'id': id,
    'conversation_id': convId,
    'filename': filename,
    'mime_type': mimeType,
    'size': 1048576,
    'kind': kind,
    'has_thumbnail': hasThumbnail,
    'scan_status': 'clean',
    'width': ?width,
    'height': ?height,
    'duration_ms': ?durationMs,
  };

  static Map<String, dynamic> member(
    String id,
    String name, {
    String role = 'member',
  }) => {
    'user_id': id,
    'role': role,
    'joined_at': '2026-09-14T09:00:00Z',
    'display_name': name,
    'email': '${id.substring(0, 4)}@example.kz',
  };

  static Map<String, dynamic> conversation({
    String id = conv,
    String title = 'Bob',
    int unread = 0,
    int lastSeq = 1,
    Map<String, dynamic>? lastMessage,
    bool group = false,
    bool hasAvatar = false,
    String myRole = 'owner',
    List<Map<String, dynamic>>? members,
  }) => {
    'id': id,
    'type': group ? 'group' : 'direct',
    'title': title,
    'has_avatar': hasAvatar,
    'created_by': me,
    'created_at': '2026-09-14T09:00:00Z',
    'updated_at': '2026-09-14T10:00:00Z',
    'last_seq': lastSeq,
    'last_message': ?lastMessage,
    'unread': unread,
    'member_count': members?.length ?? 2,
    'members':
        members ??
        [
          {
            'user_id': me,
            'role': 'owner',
            'joined_at': '2026-09-14T09:00:00Z',
            'display_name': 'Me',
            'email': 'user@example.kz',
          },
          {
            'user_id': peer,
            'role': 'owner',
            'joined_at': '2026-09-14T09:00:00Z',
            'display_name': 'Bob',
            'email': 'bob@example.kz',
          },
        ],
    'peer': ?(group ? null : user()),
    'my_role': myRole,
    'settings': {'pinned': false, 'archived': false, 'last_read_seq': 0},
  };

  static Map<String, dynamic> chats(List<Map<String, dynamic>> list) => {
    'chats': list,
    'next_cursor': '',
  };
  static Map<String, dynamic> messages(List<Map<String, dynamic>> list) => {
    'messages': list,
  };
  static Map<String, dynamic> events(List<Map<String, dynamic>> list) => {
    'events': list,
  };
}
