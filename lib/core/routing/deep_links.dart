import 'routes.dart';

/// Deep-link scheme from ТЗ п.24.20:
///
/// * `xatbox://mail/{id}`
/// * `xatbox://chat/{conversation_id}`
/// * `xatbox://chat/{conversation_id}/message/{message_id}`
/// * `xatbox://call/{call_id}`
/// * `xatbox://official[/{id}]` — official messages (list / one message)
/// * `xatbox://tasks` and `xatbox://tasks/{id}` — «Мои задачи»
/// * `xatbox://meet/{code}` and `https://…/xatbox/calls/api/v1/meet/{code}`
///   — pre-join of a scheduled meeting
///
/// Launcher entry points (app icon shortcuts, home screen widget):
///
/// * `xatbox://new/chat` — new message, `xatbox://new/call` — new call
/// * `xatbox://chat/saved` — «Избранное», `xatbox://search` — unified search
/// * `xatbox://today` — «Сегодня»
///
/// OS links arrive through app_links (`link_router.dart`; Android intent
/// filter, iOS URL type) and open once signed in, so a link never bypasses
/// the session check.
abstract final class DeepLinks {
  static const scheme = 'xatbox';

  /// Meeting codes (`abc-defg-hjk`) and guest tokens (`g` + 32 symbols).
  static final _meetCode = RegExp(r'^(?:[a-z0-9]{3}-[a-z0-9]{4}-[a-z0-9]{3}|g[a-z0-9]{32})$');

  /// `https://…/xatbox/calls/api/v1/meet/<code>` (Android App Link).
  static String? _httpsMeeting(Uri uri) {
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final n = segs.length;
    if (n < 4 || segs[n - 2] != 'meet' || segs[n - 3] != 'v1' || segs[n - 4] != 'api') return null;
    return _meetCode.hasMatch(segs.last) ? Routes.meetPath(segs.last) : null;
  }

  static String? toRoute(Uri uri) {
    if (uri.scheme == 'https') return _httpsMeeting(uri);
    if (uri.scheme != scheme) return null;
    final segments = [
      uri.host,
      ...uri.pathSegments,
    ].where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    switch (segments.first) {
      case 'mail':
        if (segments.length >= 2) return Routes.mailMessagePath(segments[1]);
        return Routes.mail;
      case 'chat':
        // Conversation ids are UUIDs, so "saved" cannot collide.
        if (segments.length >= 2 && segments[1] == 'saved') {
          return Routes.chatSaved;
        }
        if (segments.length >= 2) {
          return Routes.chatConversationPath(segments[1]);
        }
        return Routes.chat;
      case 'new':
        if (segments.length >= 2 && segments[1] == 'chat') {
          return Routes.chatNew;
        }
        if (segments.length >= 2 && segments[1] == 'call') {
          return Routes.callsNew;
        }
        return null;
      case 'search':
        return Routes.search;
      case 'today':
        return Routes.today;
      case 'call':
        if (segments.length >= 2) return Routes.callDetailsPath(segments[1]);
        return Routes.calls;
      case 'meet':
        // xatbox://meet/{code}: pre-join of a scheduled meeting.
        if (segments.length >= 2 && _meetCode.hasMatch(segments[1])) {
          return Routes.meetPath(segments[1]);
        }
        return Routes.calls;
      case 'official':
        if (segments.length >= 2) return Routes.officialMessagePath(segments[1]);
        return Routes.official;
      case 'calendar':
        // xatbox://calendar/event/{id}[?occ=…]
        if (segments.length >= 3 && segments[1] == 'event') {
          return Routes.calendarEventPath(
            segments[2],
            uri.queryParameters['occ'],
          );
        }
        return Routes.calendar;
      case 'tasks':
        if (segments.length >= 2) return Routes.taskPath(segments[1]);
        return Routes.tasks;
    }
    return null;
  }
}
