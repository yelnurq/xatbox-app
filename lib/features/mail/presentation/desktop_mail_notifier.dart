import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/localization/localization.dart';
import '../../../core/notifications/local_notification_hub.dart';
import '../../../core/platform/desktop.dart';
import '../../../core/platform/desktop_commands.dart';
import '../../../core/platform/desktop_settings.dart';
import '../../../core/platform/desktop_shell.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/routes.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../../shared/widgets/desktop_integration.dart';
import '../../chat/data/desktop_notifications.dart';
import '../../chat/data/push_notifications.dart';
import '../../settings/data/notification_preferences.dart';
import '../data/mail_models.dart';
import 'mail_providers.dart';

/// Toast payload of a new message: `mail:<message id>`.
const mailToastPrefix = 'mail:';

/// The unread inbox messages not seen before, newest first (pure,
/// unit-tested).
List<MailListItem> newMailToNotify(List<MailListItem> unread, Set<String> known) => [
  for (final m in unread)
    if (!m.isRead && !known.contains(m.id)) m,
];

/// Texts of the Windows toast buttons and of «N more».
class MailToastTexts {
  const MailToastTexts({
    required this.reply,
    required this.markRead,
    required this.delete,
    required this.noSubject,
    required this.more,
  });
  final String reply;
  final String markRead;
  final String delete;
  final String noSubject;
  final String Function(int count) more;
}

/// New mail on the desktop app. The server pushes new mail to phones and
/// browsers only, so the app looks itself: the inbox summary every
/// [interval] (which also keeps the counts and the taskbar badge fresh), and
/// the unread list when the count grew. Each new message gets a toast with
/// «Ответить», «Прочитано», «Удалить» (at most [maxToasts], then one «ещё
/// N»), except while XatBox is in front on the mail page.
class DesktopMailWatcher {
  DesktopMailWatcher(this._ref);

  static const interval = Duration(seconds: 45);
  static const maxToasts = 3;

  final Ref _ref;
  final _known = <String>{};
  Timer? _timer;
  bool _seeded = false;
  int _lastUnread = 0;
  bool _busy = false;

  void start() {
    _timer ??= Timer.periodic(interval, (_) => unawaited(tick()));
    unawaited(tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> tick() async {
    if (_busy) return;
    _busy = true;
    try {
      final summary = _ref.read(mailSummaryProvider.notifier);
      await summary.refresh();
      if (!_ref.mounted) return;
      final unread = _ref.read(mailSummaryProvider).summary?.inboxUnreadTotal ?? 0;
      final grew = unread > _lastUnread;
      _lastUnread = unread;
      if (_seeded && !grew) return;
      final page = await _ref.read(mailApiProvider).listMessages(const MailListQuery(unread: true, limit: 10));
      if (!_ref.mounted) return;
      final fresh = _seeded ? newMailToNotify(page.messages, _known) : const <MailListItem>[];
      _known.addAll(page.messages.map((m) => m.id));
      _seeded = true;
      if (fresh.isEmpty) return;
      // The open inbox shows them without a manual refresh.
      final query = _ref.read(currentMailQueryProvider);
      if (query.folder == MailFolderType.inbox) unawaited(_ref.read(mailListProvider(query).notifier).refresh());
      await _notify(fresh);
    } on Object catch (e) {
      DiagnosticLog.warn('mail', 'new mail check failed', error: e);
    } finally {
      _busy = false;
    }
  }

  Future<void> _notify(List<MailListItem> fresh) async {
    if (!_ref.read(desktopSettingsProvider).mailNotifications) return;
    if (inQuietHours(_ref.read(notificationPreferencesProvider).prefs.quietHours, DateTime.now())) return;
    final path = _ref.read(appRouterProvider).routerDelegate.currentConfiguration.uri.path;
    if (path.startsWith(Routes.mail) && await desktopWindowFocused()) return;
    final texts = mailToastTexts(desktopL10nOf(_ref));
    for (final m in fresh.take(maxToasts)) {
      final payload = '$mailToastPrefix${m.id}';
      final subject = m.subject.trim().isEmpty ? texts.noSubject : m.subject.trim();
      await showDesktopToast(
        id: stableNotificationId(payload),
        title: m.senderLabel,
        body: m.snippet.trim().isEmpty ? subject : '$subject\n${m.snippet.trim()}',
        payload: payload,
        details: NotificationDetails(
          windows: Platform.isWindows
              ? WindowsNotificationDetails(
                  actions: [
                    for (final (id, label) in [
                      (LocalNotificationHub.mailReplyActionId, texts.reply),
                      (LocalNotificationHub.mailReadActionId, texts.markRead),
                      (LocalNotificationHub.mailDeleteActionId, texts.delete),
                    ])
                      WindowsAction(content: label, arguments: LocalNotificationHub.windowsActionArguments(id, payload)),
                  ],
                )
              : null,
          macOS: Platform.isMacOS ? const DarwinNotificationDetails(categoryIdentifier: LocalNotificationHub.macMailCategoryId) : null,
        ),
      );
    }
    if (fresh.length > maxToasts) {
      await showDesktopToast(
        id: stableNotificationId('mail:more'),
        title: 'XatBox',
        body: texts.more(fresh.length - maxToasts),
        payload: '${mailToastPrefix}inbox',
      );
    }
    await DesktopShell.flash();
  }
}

/// The toast texts in the app's language.
MailToastTexts mailToastTexts(AppLocalizations l10n) => MailToastTexts(
  reply: l10n.mailReply,
  markRead: l10n.mailMarkRead,
  delete: l10n.delete,
  noSubject: l10n.mailNoSubject,
  more: l10n.desktopMailMore,
);

/// Watched once from the app root while signed in on the desktop app: new
/// mail toasts and what their buttons do.
final desktopMailWatcherProvider = Provider<void>((ref) {
  if (!desktopBackgroundWork) return;
  final signedIn = ref.watch(authStateProvider.select((s) => s.status)) == AuthStatus.authenticated;
  if (!signedIn) return;
  final watcher = DesktopMailWatcher(ref)..start();
  ref.onDispose(watcher.stop);

  final runner = ref.read(desktopCommandRunnerProvider);
  bool onTap(String payload) {
    if (!payload.startsWith(mailToastPrefix)) return false;
    final id = payload.substring(mailToastPrefix.length);
    runner.run(id == 'inbox' ? const DesktopOpen(DesktopModuleTarget.mail) : DesktopOpenMessage(id));
    return true;
  }

  LocalNotificationHub.addListener(onTap);
  ref.onDispose(() => LocalNotificationHub.removeListener(onTap));
  LocalNotificationHub.onMailAction = (action, payload) {
    if (!payload.startsWith(mailToastPrefix)) return;
    final id = payload.substring(mailToastPrefix.length);
    final repo = ref.read(mailRepositoryProvider);
    Future<void> guarded(Future<void> Function() f) async {
      try {
        await f();
        ref.read(mailSummaryProvider.notifier).refresh();
      } on Object catch (e) {
        DiagnosticLog.warn('mail', 'toast action failed', error: e);
      }
    }

    switch (action) {
      case LocalNotificationHub.mailReplyActionId:
        runner.run(DesktopReply(id));
      case LocalNotificationHub.mailReadActionId:
        unawaited(guarded(() => repo.setRead(id, true)));
      case LocalNotificationHub.mailDeleteActionId:
        unawaited(guarded(() => repo.delete(id, permanent: false)));
    }
  };
  ref.onDispose(() => LocalNotificationHub.onMailAction = null);
});
