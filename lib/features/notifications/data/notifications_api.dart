import '../../../core/api/api_client.dart';
import 'notification_models.dart';

/// Mail API notifications (`/notifications*`). The list endpoint has no query
/// parameters and no pagination; the two mark endpoints read no body.
class NotificationsApi {
  NotificationsApi(this._client);
  final ApiClient _client;

  Future<NotificationPage> list() async {
    final json = await _client.getJson('/notifications');
    final items = ((json['notifications'] as List?) ?? const [])
        .map((e) => AppNotification.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    final unread = (json['unread'] as num?)?.toInt() ??
        items.where((n) => !n.isRead).length;
    return NotificationPage(items: items, unread: unread);
  }

  /// `POST /notifications/{id}/read` → 204 (idempotent).
  Future<void> markRead(String id) async {
    await _client.postJson(
      '/notifications/${Uri.encodeComponent(id)}/read',
      expectedStatuses: const {204},
    );
  }

  /// `POST /notifications/read-all` → 204 (also marks items beyond the 100).
  Future<void> markAllRead() async {
    await _client.postJson(
      '/notifications/read-all',
      expectedStatuses: const {204},
    );
  }
}
