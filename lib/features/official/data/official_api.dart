import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../contacts/data/contact_models.dart';
import '../../contacts/data/contacts_api.dart';
import 'official_models.dart';

/// Mail API official messages (`/official*`) plus the directory lookups the
/// compose screen needs (`GET /departments`, `GET /directory/users`), all on
/// the Mail API client: the ids must belong to the same organization.
class OfficialApi {
  OfficialApi(this._client);
  final ApiClient _client;

  static String _path(String id, String action) =>
      '/official/${Uri.encodeComponent(id)}/$action';

  /// `GET /official`: newest first, at most 200, no pagination.
  Future<List<OfficialMessage>> list() async {
    final json = await _client.getJson('/official');
    return ((json['messages'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => OfficialMessage.fromJson(e.cast<String, dynamic>()))
        .where((m) => m.id.isNotEmpty)
        .toList();
  }

  /// `POST /official/{id}/read` → 204 (idempotent, first `read_at` kept).
  Future<void> markRead(String id) async {
    await _client.postJson(_path(id, 'read'), expectedStatuses: const {204});
  }

  /// `POST /official/{id}/acknowledge` → 204. 404 `OFFICIAL_NOT_FOUND` also
  /// when the message does not require acknowledgement.
  Future<void> acknowledge(String id) async {
    await _client.postJson(
      _path(id, 'acknowledge'),
      expectedStatuses: const {204},
    );
  }

  /// `POST /official` → 201. A body the server cannot decode yields an
  /// **empty 200** instead of an error; that is reported as
  /// [UnexpectedApiException] so it is never mistaken for success.
  Future<OfficialCreated> create(OfficialDraft draft) async {
    final json = await _client.postJson(
      '/official',
      body: draft.toJson(),
      expectedStatuses: const {200, 201},
    );
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const UnexpectedApiException(
        'POST /official answered without a created message',
        statusCode: 200,
      );
    }
    return OfficialCreated(
      id: id,
      recipientCount: (json['recipient_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// `GET /official/{id}/stats` (aggregate counts only).
  Future<OfficialStats> stats(String id) async =>
      OfficialStats.fromJson(await _client.getJson(_path(id, 'stats')));

  /// `GET /departments`, archived ones dropped, sorted by name.
  Future<List<Department>> departments() async {
    final list = await ContactsApi(_client).departments();
    return list.where((d) => !d.isArchived).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// `GET /directory/users?q=` (active staff of the caller's organization).
  Future<List<Contact>> searchUsers(String query, {int limit = 100}) async {
    final q = query.trim();
    final json = await _client.getJson(
      '/directory/users',
      query: {if (q.isNotEmpty) 'q': q, 'limit': limit},
    );
    return ((json['users'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Contact.fromJson(e.cast<String, dynamic>()))
        .where((c) => c.id.isNotEmpty)
        .toList();
  }
}
