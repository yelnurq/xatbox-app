import '../../../shared/utils/api_date.dart';

/// One in-app notification (`NotificationItem` of the Mail API).
///
/// Timestamps come in PostgreSQL text form (`2026-09-14 10:21:33.123456+00`),
/// parsed by [parseApiDate].
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.targetUrl,
    required this.createdAt,
    this.readAt,
  });

  final String id;

  /// `message`, `mention`, `assigned_task`, `reminder`, `calendar_reminder`,
  /// `calendar.invited`, `calendar.rsvp`, `calendar.<action>`, `official`…
  final String kind;
  final String title;
  final String body;

  /// Web app path (may be empty); mapped by `notificationTargetLocation`.
  final String targetUrl;
  final DateTime? createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        kind: (json['kind'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        body: (json['body'] as String?) ?? '',
        targetUrl: (json['target_url'] as String?) ?? '',
        createdAt: parseApiDate(json['created_at'] as String?),
        readAt: parseApiDate(json['read_at'] as String?),
      );

  AppNotification markedRead(DateTime at) => isRead
      ? this
      : AppNotification(
          id: id,
          kind: kind,
          title: title,
          body: body,
          targetUrl: targetUrl,
          createdAt: createdAt,
          readAt: at,
        );
}

/// `NotificationList`: at most the 100 most recent items, newest first.
class NotificationPage {
  const NotificationPage({required this.items, required this.unread});
  final List<AppNotification> items;

  /// Unread among the returned items (not all unread notifications).
  final int unread;

  /// Server cap of `GET /notifications`.
  static const maxItems = 100;
}
