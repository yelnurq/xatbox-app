import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/utils/diagnostic_log.dart';
import '../../shared/widgets/desktop_integration.dart';
import '../auth/auth_providers.dart';
import '../platform/desktop.dart';
import 'app_router.dart';
import 'deep_links.dart';
import 'routes.dart';

/// OS deep links (`xatbox://…`) behind an interface (fake in tests).
abstract class DeepLinkSource {
  Future<Uri?> initial();
  Stream<Uri> get links;
}

class AppLinksSource implements DeepLinkSource {
  final _links = AppLinks();

  @override
  Future<Uri?> initial() async {
    try {
      return await _links.getInitialLink();
    } on Object catch (e) {
      DiagnosticLog.warn('links', 'initial link unavailable', error: e);
      return null;
    }
  }

  @override
  Stream<Uri> get links => _links.uriLinkStream.handleError(
    (Object e) => DiagnosticLog.warn('links', 'link stream failed', error: e),
  );
}

class NoDeepLinks implements DeepLinkSource {
  const NoDeepLinks();

  @override
  Future<Uri?> initial() async => null;

  @override
  Stream<Uri> get links => const Stream.empty();
}

final deepLinkSourceProvider = Provider<DeepLinkSource>(
  (_) => AppLinksSource(),
);

/// In-app location requested from outside the app (deep link, push tap).
/// It waits until the session is authenticated and the auth redirect has
/// landed on the main screen.
class PendingNavigationNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void request(String? location) => state = location;
  void consume() => state = null;
}

final pendingNavigationProvider =
    NotifierProvider<PendingNavigationNotifier, String?>(
      PendingNavigationNotifier.new,
    );

/// Where a tapped push should lead (data keys from backend/platform/push).
/// Chat conversations and calls are handled by their modules; this covers
/// everything else. Unknown payloads open nothing.
String? pushTapLocation(Map<String, dynamic> data) {
  final link = data['link'] ?? data['deep_link'];
  if (link is String) {
    final uri = Uri.tryParse(link);
    final location = uri == null ? null : DeepLinks.toRoute(uri);
    if (location != null) return location;
  }
  final type = data['type'] is String ? data['type'] as String : '';
  // Official messages: `official.created` event / notification kind `official`.
  final official = data['official_message_id'];
  if (official is String && official.isNotEmpty) {
    return Routes.officialMessagePath(official);
  }
  if (type == 'official.created' || type == 'official' || data['kind'] == 'official') {
    return Routes.official;
  }
  final eventId = data['event_id'];
  if (eventId is String &&
      eventId.isNotEmpty &&
      (type.startsWith('calendar.') || data.containsKey('kind'))) {
    return Routes.calendarEventPath(eventId);
  }
  final task = data['task_id'];
  if (task is String && task.isNotEmpty && data['conversation_id'] == null) {
    return Routes.taskPath(task);
  }
  final conversation = data['conversation_id'];
  if (conversation is String && conversation.isNotEmpty) {
    return Routes.chatConversationPath(conversation);
  }
  final message = data['message_id'];
  if (type.startsWith('mail.') && message is String && message.isNotEmpty) {
    return Routes.mailMessagePath(message);
  }
  if (type.startsWith('call.') || data.containsKey('call_id')) {
    return Routes.calls;
  }
  return null;
}

/// Listens to OS links and opens pending locations once signed in.
final externalNavigationProvider = Provider<void>((ref) {
  final router = ref.watch(appRouterProvider);
  final session = ref.watch(authSessionProvider);
  final source = ref.watch(deepLinkSourceProvider);

  void open() {
    if (!ref.mounted) return;
    final location = ref.read(pendingNavigationProvider);
    if (location == null || !session.isAuthenticated) return;
    final current = router.routeInformationProvider.value.uri.path;
    if (current == Routes.splash || current == Routes.login) {
      // Let the auth redirect reach the main screen first.
      SchedulerBinding.instance.addPostFrameCallback((_) => open());
      return;
    }
    ref.read(pendingNavigationProvider.notifier).consume();
    unawaited(router.push(location));
  }

  void handle(Uri uri) {
    // macOS: mailto: links come through app_links too (XatBox as the
    // email app); on Windows the runner hands them over (desktop_shell).
    if (isDesktop && uri.scheme.toLowerCase() == 'mailto') {
      ref.read(desktopCommandRunnerProvider).runAll([uri.toString()]);
      return;
    }
    final location = DeepLinks.toRoute(uri);
    if (location == null) {
      DiagnosticLog.info('links', 'unsupported link ignored');
      return;
    }
    ref.read(pendingNavigationProvider.notifier).request(location);
  }

  ref.listen(pendingNavigationProvider, (_, _) => open());
  session.addListener(open);
  ref.onDispose(() => session.removeListener(open));
  unawaited(
    source.initial().then((uri) {
      if (uri != null && ref.mounted) handle(uri);
    }),
  );
  final sub = source.links.listen(handle);
  ref.onDispose(sub.cancel);
});
