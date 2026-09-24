import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import 'contact_models.dart';

/// One answer of `GET /users`.
class ContactsPage {
  const ContactsPage(this.contacts, {this.hasMore = false, this.offset = 0});
  final List<Contact> contacts;

  /// The directory holds more colleagues after this page — ask for the next
  /// one at [offset] + `contacts.length`.
  final bool hasMore;

  /// Where this page started in the directory order (display name, e-mail).
  final int offset;
}

/// Directory of the Chat Service: `GET /users` (search, department filter,
/// `limit`/`offset` paging up to 1000 rows a page), `GET /users/{id}` and
/// `GET /departments`.
class ContactsApi {
  ContactsApi(this._client);
  final ApiClient _client;

  /// The service (and the Mail API behind it) caps a page at 1000.
  static const maxLimit = 1000;

  /// What the desktop directory pulls per scroll: an organization of a
  /// thousand employees is walked page by page instead of at once.
  static const pageSize = 50;

  /// Services released before the 1000 cap answer an over-limit request
  /// with their default of 50 and cap at 200.
  static const _legacyDefault = 50;
  static const _legacyMax = 200;

  /// One page of the directory. [offset] is ignored by services released
  /// before paging — they answer the first page, so the caller sees repeats
  /// rather than gaps and stops at the first page that adds nothing new.
  Future<ContactsPage> search(
    String query, {
    int limit = maxLimit,
    int offset = 0,
    String? departmentId,
  }) async {
    final q = query.trim();
    final from = offset < 0 ? 0 : offset;
    Future<Map<String, dynamic>> fetch(int l) => _client.getJson(
      '/users',
      query: {
        if (q.isNotEmpty) 'q': q,
        if (departmentId != null && departmentId.isNotEmpty)
          'department_id': departmentId,
        'limit': l,
        if (from > 0) 'offset': from,
      },
    );
    var json = await fetch(limit);
    var effective = limit;
    if (!json.containsKey('limit') &&
        limit > _legacyMax &&
        _users(json).length == _legacyDefault) {
      effective = _legacyMax;
      json = await fetch(_legacyMax);
    }
    final users = _users(json);
    final hasMore = json['has_more'] is bool
        ? json['has_more'] as bool
        : users.length >= ((json['limit'] as num?)?.toInt() ?? effective);
    return ContactsPage(users, hasMore: hasMore, offset: from);
  }

  static List<Contact> _users(Map<String, dynamic> json) =>
      ((json['users'] as List?) ?? const [])
          .map((e) => Contact.fromJson((e as Map).cast<String, dynamic>()))
          .where((c) => c.id.isNotEmpty)
          .toList();

  /// One colleague with chat presence; null when the service does not know
  /// the id (404).
  Future<Contact?> get(String id) async {
    try {
      final json = await _client.getJson('/users/${Uri.encodeComponent(id)}');
      final raw = json['user'] is Map ? json['user'] as Map : json;
      final c = Contact.fromJson(raw.cast<String, dynamic>());
      return c.id.isEmpty ? null : c;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<Department>> departments() async {
    final json = await _client.getJson('/departments');
    return ((json['departments'] as List?) ?? const [])
        .map((e) => Department.fromJson((e as Map).cast<String, dynamic>()))
        .where((d) => d.id.isNotEmpty)
        .toList();
  }
}
