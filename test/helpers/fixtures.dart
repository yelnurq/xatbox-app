/// JSON fixtures shaped exactly like the OpenAPI schemas.
abstract final class Fixtures {
  static const token =
      'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789_-AbCdE'; // 43 chars

  static Map<String, dynamic> me({
    List<String> permissions = const ['mail.read', 'mail.send'],
  }) => {
    'id': '11111111-1111-4111-8111-111111111111',
    'email': 'user@example.kz',
    'display_name': 'Тест Пользователь',
    'tenant_id': '22222222-2222-4222-8222-222222222222',
    'organization_id': '33333333-3333-4333-8333-333333333333',
    'department_id': '44444444-4444-4444-8444-444444444444',
    'department_name': 'IT',
    'roles': [
      {'role': 'member', 'scope_type': 'tenant'},
    ],
    'permissions': permissions,
    'avatar_updated_at': '2026-09-01T10:00:00Z',
  };

  static Map<String, dynamic> loginResponse({List<String>? permissions}) => {
    'token': token,
    'user': {
      'id': '11111111-1111-4111-8111-111111111111',
      'email': 'user@example.kz',
      'display_name': 'Тест Пользователь',
      'tenant_id': '22222222-2222-4222-8222-222222222222',
      'roles': <Map<String, dynamic>>[],
      'permissions': permissions ?? ['mail.read', 'mail.send'],
    },
  };

  static Map<String, dynamic> summary({
    int inboxUnread = 3,
    int smartUnread = 2,
  }) => {
    'mailbox': {'id': 'mb1', 'address': 'user@example.kz'},
    'folders': [
      {
        'id': 'a',
        'name': 'Inbox',
        'type': 'inbox',
        'unread': inboxUnread,
        'total': 10,
      },
      {'id': 'b', 'name': 'Sent', 'type': 'sent', 'unread': 0, 'total': 4},
      {'id': 'c', 'name': 'Drafts', 'type': 'drafts', 'unread': 0, 'total': 1},
      {'id': 'd', 'name': 'Junk', 'type': 'spam', 'unread': 1, 'total': 1},
      {'id': 'e', 'name': 'Trash', 'type': 'trash', 'unread': 0, 'total': 0},
      {
        'id': 'bookmarks',
        'name': 'Bookmarks',
        'type': 'bookmarks',
        'color': 'amber',
        'unread': 0,
        'total': 2,
      },
      {
        'id': 'f0f0',
        'name': 'Рассылки',
        'type': 'custom:f0f0',
        'color': 'sky',
        'accounts': 2,
        'unread': smartUnread,
        'total': 5,
      },
      {
        'id': 'b1b1',
        'name': 'Важное',
        'type': 'bookmark:b1b1',
        'color': 'rose',
        'unread': 0,
        'total': 1,
      },
    ],
  };

  static Map<String, dynamic> message(
    int i, {
    bool read = false,
    bool starred = false,
  }) => {
    'id': 'm$i',
    'message_id': 'msg$i@example.kz',
    'from': 'sender$i@example.kz',
    'from_display': 'Отправитель $i',
    'subject': 'Тема письма $i',
    'snippet': 'Превью письма $i',
    'date': '2026-09-1${i % 5}T08:00:00Z',
    'is_read': read,
    'is_starred': starred,
    'has_attachments': i.isEven,
    'thread_id': 't$i',
  };

  static List<Map<String, dynamic>> messages(int count, {int from = 1}) => [
    for (var i = from; i < from + count; i++) message(i),
  ];

  static Map<String, dynamic> page(
    List<Map<String, dynamic>> messages, {
    required int total,
    int limit = 50,
    int offset = 0,
    int? nextOffset,
  }) => {
    'messages': messages,
    'total': total,
    'limit': limit,
    'offset': offset,
    'next_offset': ?nextOffset,
  };

  static Map<String, dynamic> detail({
    String id = 'm1',
    String bodyHtml = '',
    List<Map<String, dynamic>> attachments = const [],
  }) => {
    'id': id,
    'message_id': 'msg1@example.kz',
    'folder': 'inbox',
    'from': 'sender1@example.kz',
    'from_display': 'Отправитель 1',
    'recipients': [
      {'kind': 'to', 'address': 'user@example.kz'},
      {'kind': 'cc', 'address': 'cc@example.kz'},
    ],
    'subject': 'Тема письма 1',
    'body_text': 'Привет!\nЭто тестовое письмо.',
    'body_html': bodyHtml,
    'date': '2026-09-11T08:00:00Z',
    'is_read': true,
    'is_starred': false,
    'has_attachments': attachments.isNotEmpty,
    'attachments': attachments,
    'thread': [
      {
        'id': id,
        'subject': 'Тема письма 1',
        'from': 'sender1@example.kz',
        'date': '2026-09-11T08:00:00Z',
      },
    ],
  };

  static Map<String, dynamic> attachment({
    String id = 'blob1',
    String name = 'report.docx',
  }) => {
    'id': id,
    'filename': name,
    'content_type': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'size_bytes': 12345,
  };

  // ---- mail: invitations, settings ------------------------------------------

  static Map<String, dynamic> icsAttachment({String id = 'blob_ics'}) => {
    'id': id,
    'filename': 'invite.ics',
    'content_type': 'text/calendar; method=REQUEST',
    'size_bytes': 1024,
  };

  /// `MailCalendarInvitationPreview`.
  static Map<String, dynamic> invitationPreview({
    String method = 'REQUEST',
    String blobId = 'blob_ics',
    String? eventId,
    String? status,
  }) => {
    'invitation': {
      'method': method,
      'uid': 'uid-1@example.kz',
      'sequence': 0,
      'title': 'Защита проекта',
      'description': '',
      'location': 'Ауд. 305',
      'starts_at': '2026-09-18T09:00:00Z',
      'ends_at': '2026-09-18T10:00:00Z',
      'timezone': 'Asia/Almaty',
      'status': 'CONFIRMED',
      'organizer_email': 'boss@example.kz',
      'organizer_name': 'Болат Сейтов',
      'attendees': ['user@example.kz'],
    },
    'blob_id': blobId,
    'event_id': ?eventId,
    'status': ?status,
  };

  /// `MailSettingsPersonalSignature`.
  static Map<String, dynamic> signature({
    String text = 'Тест Пользователь\nKazTBU',
    bool isDefault = true,
  }) => {
    'text': text,
    'html': '<div>${text.replaceAll('\n', '<br>')}</div>',
    'is_default': isDefault,
    'default_text': 'Тест Пользователь\nKazTBU',
  };

  /// `MailSettingsSignaturePreview`.
  static Map<String, dynamic> signaturePreview({
    bool personal = true,
    bool mandatory = true,
  }) => {
    'personal': personal,
    if (personal) 'personal_text': 'Тест Пользователь',
    if (personal) 'personal_html': '<div>Тест Пользователь</div>',
    'signature_id': '55555555-5555-4555-8555-555555555555',
    'name': 'Официальная',
    'version': 3,
    'mandatory': mandatory,
    'applied': personal || mandatory,
    'text': 'КазТБУ · +7 700 000 00 00',
    'html': '<div>КазТБУ · +7 700 000 00 00</div>',
    'missing': <String>[],
  };

  /// `MailSettingsVacation`.
  static Map<String, dynamic> vacation({bool enabled = false}) => {
    'enabled': enabled,
    'subject': '',
    'body': enabled ? 'Нет на месте' : '',
    'starts_on': '',
    'ends_on': '',
    'time_zone': 'Asia/Almaty',
    'active_now': enabled,
    'pending': enabled,
    'sync': {'state': 'synced', 'synced_at': '2026-09-01T10:00:00Z'},
  };

  /// `MailSettingsSenderRule`.
  static Map<String, dynamic> senderRule({
    String id = '66666666-6666-4666-8666-666666666666',
    String kind = 'domain',
    String pattern = 'spam.example.com',
    String note = '',
  }) => {
    'id': id,
    'list': 'block',
    'kind': kind,
    'pattern': pattern,
    'note': note,
    'created_at': '2026-09-01T10:00:00Z',
  };
}
