/// JSON fixtures shaped like `NotificationList` / `NotificationItem`.
abstract final class NotificationFixtures {
  static Map<String, dynamic> item({
    required String id,
    String kind = 'message',
    String title = 'Уведомление',
    String body = 'Текст',
    String targetUrl = '',
    bool read = false,
  }) => {
    'id': id,
    'kind': kind,
    'title': title,
    'body': body,
    'target_url': targetUrl,
    'created_at': '2026-09-14 10:21:33.123456+00',
    if (read) 'read_at': '2026-09-14 11:00:00+00',
  };

  /// `count` items `n1…nN`; the first [unread] are unread.
  static Map<String, dynamic> list(int count, {int unread = 0}) => {
    'notifications': [
      for (var i = 1; i <= count; i++)
        item(id: 'n$i', title: 'Уведомление $i', read: i > unread),
    ],
    'unread': unread,
  };

  static Map<String, dynamic> of(List<Map<String, dynamic>> items) => {
    'notifications': items,
    'unread': items.where((n) => n['read_at'] == null).length,
  };
}
