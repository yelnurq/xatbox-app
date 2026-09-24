import '../../../core/routing/deep_links.dart';
import '../../../core/routing/routes.dart';

/// Maps a notification `target_url` to an in-app route location, or `null`
/// when the app has no screen for it (no navigation then). Pure; unit-tested.
///
/// Accepted forms:
/// * `xatbox://…` deep links — delegated to [DeepLinks.toRoute];
/// * web app paths from the Mail API (optionally as absolute http(s) URLs):
///   - `/mail/calendar?event=<id>[&occ=…]` → calendar event, `/mail/calendar` → calendar;
///   - `/mail/messages[?conversation=<id>]` → chat tab. These ids belong to the
///     legacy webmail chat (`/chat/*`), which the Chat Service does not share,
///     so the conversation cannot be opened directly;
///   - `/mail/message/<id>` or `/mail[/<folder>]?message=<id>` → mail message;
///   - `/mail/official[/<id>|?id=<id>]` → official messages (list / one);
///   - `/mail/my-list` or `/mail/tasks` (`?task=<id>`) → «Мои задачи»;
///   - `/mail` → mail tab; other `/mail/*` pages → null;
/// * app paths: `/chat/c/<id>`, `/chat`, `/call[s][/<id>]`,
///   `/calendar/event/<id>`, `/calendar`, `/mail/message/<id>`, `/tasks[/<id>]`.
///
/// Callers hide task locations from users without `tasks.manage.self`
/// ([isTaskLocation]).
String? notificationTargetLocation(String? targetUrl) {
  final raw = targetUrl?.trim() ?? '';
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  if (uri.scheme == DeepLinks.scheme) return DeepLinks.toRoute(uri);
  if (uri.hasScheme && uri.scheme != 'http' && uri.scheme != 'https') {
    return null;
  }
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;
  final query = uri.queryParameters;
  String? param(String name) {
    final v = query[name]?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  switch (segments.first) {
    case 'mail':
      final rest = segments.sublist(1);
      if (rest.isEmpty) {
        final message = param('message');
        return message != null ? Routes.mailMessagePath(message) : Routes.mail;
      }
      switch (rest.first) {
        case 'calendar':
          final event =
              param('event') ??
              (rest.length >= 3 && rest[1] == 'event' ? rest[2] : null);
          return event != null
              ? Routes.calendarEventPath(event, param('occ'))
              : Routes.calendar;
        case 'messages':
          return Routes.chat;
        case 'message':
          return rest.length >= 2 ? Routes.mailMessagePath(rest[1]) : null;
        case 'official':
          final official = rest.length >= 2 ? rest[1] : param('id');
          return official != null
              ? Routes.officialMessagePath(official)
              : Routes.official;
        case 'my-list':
        case 'tasks':
          final task = param('task') ?? (rest.length >= 2 ? rest[1] : null);
          return task != null ? Routes.taskPath(task) : Routes.tasks;
      }
      final message = param('message');
      return message != null ? Routes.mailMessagePath(message) : null;
    case 'chat':
      if (segments.length >= 3 && segments[1] == 'c') {
        return Routes.chatConversationPath(segments[2]);
      }
      return segments.length == 1 ? Routes.chat : null;
    case 'call':
    case 'calls':
      return Routes.calls;
    case 'tasks':
      return segments.length >= 2 ? Routes.taskPath(segments[1]) : Routes.tasks;
    case 'calendar':
      return DeepLinks.toRoute(
        Uri(
          scheme: DeepLinks.scheme,
          host: 'calendar',
          pathSegments: segments.sublist(1),
          queryParameters: query.isEmpty ? null : query,
        ),
      );
  }
  return null;
}

/// Kinds of in-app notifications that belong to tasks (`assigned_task`, and
/// `reminder` fired for a task / «Напомнить» on a message).
bool isTaskNotificationKind(String kind) =>
    kind == 'assigned_task' || kind == 'reminder';

/// `true` for «Мои задачи» locations (hidden without the permission).
bool isTaskLocation(String location) =>
    location == Routes.tasks || location.startsWith('${Routes.tasks}/');

/// Tab roots are shell branches: navigate with `go`, everything else is pushed
/// over the current screen.
bool isTabRootLocation(String location) =>
    location == Routes.mail ||
    location == Routes.chat ||
    location == Routes.calls ||
    location == Routes.contacts;
