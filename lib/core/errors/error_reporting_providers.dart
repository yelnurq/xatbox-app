import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat/presentation/chat_providers.dart';
import '../auth/auth_providers.dart';
import '../auth/auth_session.dart';
import '../lifecycle/app_visibility.dart';
import '../network/network_status.dart';
import '../preferences/app_preferences.dart';
import 'error_reporter.dart';

final errorReportQueueProvider = Provider<ErrorReportQueue>(
  (ref) => ErrorReportQueue(ref.watch(appDatabaseProvider)),
);

/// The reporter used by the app; tests override it with their own instance.
final errorReporterProvider = Provider<ErrorReporter>(
  (_) => ErrorReporter.instance,
);

/// Wires [ErrorReporter] to the queue, the Chat Service client, the setting,
/// the session and connectivity. Read once from `main.dart`.
final errorReportingProvider = Provider<ErrorReporter>((ref) {
  final reporter = ref.watch(errorReporterProvider);
  final queue = ref.watch(errorReportQueueProvider);
  reporter.attach(queue);

  final env = ref.watch(appEnvProvider);
  if (env.chatEnabled) {
    final client = ref.watch(chatApiClientProvider);
    reporter.sender = (reports) async {
      await client.postJson(
        '/client-errors',
        body: {'reports': reports},
        expectedStatuses: const {202},
      );
    };
  } else {
    reporter.sender = null;
  }

  final session = ref.watch(authSessionProvider);
  reporter.canSend = () =>
      session.status == AuthStatus.authenticated &&
      ref.read(isOnlineProvider);

  void flushSoon() => unawaited(reporter.flush());

  ref.listen<bool>(
    appPreferencesProvider.select((p) => p.sendErrorReports),
    (_, enabled) {
      reporter.enabled = enabled;
      // Turning reports off also drops what was waiting to be sent.
      if (!enabled) unawaited(queue.clear().catchError((Object _) {}));
    },
    fireImmediately: true,
  );
  ref.listen<bool>(isOnlineProvider, (was, online) {
    if (online && was != true) flushSoon();
  });
  var wasSignedIn = session.status == AuthStatus.authenticated;
  void onSession() {
    final signedIn = session.status == AuthStatus.authenticated;
    if (signedIn && !wasSignedIn) flushSoon();
    wasSignedIn = signedIn;
  }

  session.addListener(onSession);
  final first = Timer(const Duration(seconds: 10), flushSoon);
  // Only while the app is visible (no background wake-ups); a flush that fell
  // due while hidden runs on return.
  final periodic = ForegroundPeriodic(
    ref.read(appVisibilityProvider),
    const Duration(minutes: 15),
    flushSoon,
  );
  ref.onDispose(() {
    session.removeListener(onSession);
    first.cancel();
    periodic.dispose();
  });
  return reporter;
});
