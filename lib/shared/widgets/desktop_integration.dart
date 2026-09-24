import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/auth/auth_providers.dart';
import '../../core/auth/auth_session.dart';
import '../../core/localization/localization.dart';
import '../../core/platform/desktop.dart';
import '../../core/errors/error_reporting_providers.dart';
import '../../core/platform/desktop_commands.dart';
import '../../core/platform/desktop_crash.dart';
import '../../core/platform/desktop_settings.dart';
import '../../core/platform/desktop_shell.dart';
import '../../core/preferences/app_preferences.dart';
import '../../core/routing/app_router.dart';
import '../../core/routing/routes.dart';
import '../../features/about/data/feedback_api.dart';
import '../../features/calls/presentation/calls_providers.dart';
import '../../features/chat/chat_badge.dart';
import '../../features/chat/presentation/chat_providers.dart';
import '../../features/mail/presentation/compose_screen.dart';
import '../../features/mail/presentation/compose_window.dart';
import '../../features/calendar/domain/ics_invite.dart';
import '../../features/calendar/presentation/event_edit_screen.dart';
import '../../features/mail/data/mail_models.dart';
import '../../features/mail/presentation/mail_home_screen.dart';
import '../../features/mail/presentation/mail_providers.dart';
import '../../features/mail/presentation/mail_undo_send.dart';
import '../../features/mail/presentation/message_window.dart';
import '../utils/diagnostic_log.dart';
import 'desktop_drop_target.dart';

/// The desktop app's texts in the chosen language, for places outside the
/// widget tree (tray menu, jump list, taskbar badge).
AppLocalizations desktopL10n(Ref ref) =>
    _l10nFor(ref.watch(appPreferencesProvider.select((p) => p.languageCode)));

/// The same without a dependency (callbacks, timers).
AppLocalizations desktopL10nOf(Ref ref) => _l10nFor(ref.read(appPreferencesProvider).languageCode);

AppLocalizations _l10nFor(String? chosen) {
  final code = chosen ?? Platform.localeName.split(RegExp('[_-]')).first;
  final supported = AppLocalization.supportedLocales.map((l) => l.languageCode);
  return lookupAppLocalizations(Locale(supported.contains(code) ? code : 'ru'));
}

/// Runs [DesktopCommand]s: a `mailto:` link or a jump list task of a second
/// launch, «Новое письмо» / «Почта»… of the tray menu. Before sign-in the
/// last command waits and runs once the shell is there.
class DesktopCommandRunner {
  DesktopCommandRunner(this._ref);

  final Ref _ref;
  DesktopCommand? _pending;

  void run(DesktopCommand command) {
    unawaited(bringWindowToFront());
    if (_ref.read(authStateProvider).status != AuthStatus.authenticated) {
      _pending = command;
      return;
    }
    switch (command) {
      case DesktopCompose(:final mailto, :final files):
        _ref
            .read(composeWindowProvider.notifier)
            .open(
              mailto == null
                  ? ComposeArgs.files([for (final f in files) (path: f, name: p.basename(f))])
                  : ComposeArgs.restore(
                      ComposeSnapshot(
                        modeName: ComposeMode.blank.name,
                        to: mailto.to.join(', '),
                        cc: mailto.cc.join(', '),
                        bcc: mailto.bcc.join(', '),
                        subject: mailto.subject,
                        body: mailto.body,
                      ),
                    ),
            );
      case DesktopOpen(:final module):
        final route = switch (module) {
          DesktopModuleTarget.mail => Routes.mail,
          DesktopModuleTarget.chat => _ref.read(chatEnabledProvider) ? Routes.chat : Routes.mail,
          DesktopModuleTarget.calls => _ref.read(callsEnabledProvider) ? Routes.calls : Routes.mail,
          DesktopModuleTarget.calendar => Routes.calendar,
          DesktopModuleTarget.contacts => Routes.contacts,
        };
        _ref.read(appRouterProvider).go(route);
      case DesktopOpenMessage(:final messageId):
        // The inbox with the message in the reading pane.
        _ref.read(appRouterProvider).go(Routes.mail);
        _ref.read(selectedFolderProvider.notifier).select(MailFolderType.inbox);
        _ref.read(mailOpenMessageProvider.notifier).open(messageId);
      case DesktopReply(:final messageId):
        unawaited(_reply(messageId));
      case DesktopShow():
        break; // brought to the front above
      case DesktopOpenEml(:final path):
        _ref.read(messageWindowsProvider.notifier).openEml(path);
      case DesktopOpenIcs(:final path):
        unawaited(_openIcs(path));
    }
  }

  /// A `.ics` opened with XatBox: the new-event form, filled from the file.
  Future<void> _openIcs(String path) async {
    try {
      final invite = IcsInvite.parse(await File(path).readAsString());
      if (invite == null) return;
      final router = _ref.read(appRouterProvider);
      router.go(Routes.calendar);
      unawaited(router.push(Routes.calendarNew, extra: EventEditArgs.invite(invite)));
    } on Object catch (e) {
      DiagnosticLog.warn('calendar', 'ics not opened', error: e);
    }
  }

  Future<void> _reply(String messageId) async {
    try {
      final result = await _ref.read(mailRepositoryProvider).getMessage(messageId);
      _ref.read(composeWindowProvider.notifier).open(ComposeArgs(mode: ComposeMode.reply, original: result.detail));
    } on Object catch (e) {
      DiagnosticLog.warn('mail', 'reply from notification failed', error: e);
      run(DesktopOpenMessage(messageId));
    }
  }

  void runAll(List<String> arguments) => parseDesktopArguments(arguments).forEach(run);

  /// Signed in: the command that waited.
  void flush() {
    final c = _pending;
    _pending = null;
    if (c != null) run(c);
  }
}

final desktopCommandRunnerProvider = Provider<DesktopCommandRunner>((ref) => DesktopCommandRunner(ref));

/// Windows shell integration, watched once from the app root: command lines
/// of later launches, files dropped on the window, the jump list. No-op on
/// phones.
final desktopShellProvider = Provider<void>((ref) {
  if (!isDesktop) return;
  final runner = ref.watch(desktopCommandRunnerProvider);
  ref.listen(authStateProvider.select((s) => s.status), (_, status) {
    if (status == AuthStatus.authenticated) runner.flush();
  });
  final sub = DesktopShell.arguments.listen(runner.runAll);
  ref.onDispose(sub.cancel);
  unawaited(
    DesktopShell.start().then((launches) {
      for (final a in launches) {
        runner.runAll(a);
      }
    }),
  );
  // Files dropped where no area takes them start a new message.
  DesktopFileRouter.start(fallback: (paths) => runner.run(DesktopCompose(files: paths)));
});

/// The app ended without quitting last time (DesktopCrashWatch): once signed
/// in, that run's log goes to the developers by itself, as a problem report
/// («Сообщить о проблеме» with the diagnostics), and the person is told in a
/// line at the bottom. The administrators read it on Admin → «Ошибки
/// приложений»; nobody has to remember to press «Отправить». Settings →
/// «Отправлять отчёты об ошибках» off keeps the log on the computer.
final desktopCrashReportProvider = Provider<void>((ref) {
  if (!isDesktop || DesktopCrashWatch.pending == null) return;
  Future<void> offer() async {
    final crash = DesktopCrashWatch.pending;
    if (crash == null) return;
    DesktopCrashWatch.pending = null;
    if (!ref.read(appPreferencesProvider).sendErrorReports) {
      DiagnosticLog.info('desktop', 'crash log kept: error reports are off');
      return;
    }
    // Let the shell come up first.
    await Future<void>.delayed(const Duration(seconds: 2));
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref.read(feedbackApiProvider).send(
        category: FeedbackCategory.bug,
        description: l10n.desktopCrashReport(crash.version, crash.startedAt.toLocal().toIso8601String().substring(0, 16).replaceFirst('T', ' ')),
        diagnostics: FeedbackDiagnostics(device: ref.read(errorReporterProvider).device, route: 'desktop:crash', log: crash.log),
      );
      messenger?.showSnackBar(SnackBar(content: Text(l10n.desktopCrashSent)));
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'crash report not sent', error: e);
    }
  }

  ref.listen(authStateProvider.select((s) => s.status), (_, status) {
    if (status == AuthStatus.authenticated) unawaited(offer());
  }, fireImmediately: true);
});

/// The jump list in the app's language (right click on the taskbar button).
final desktopJumpListProvider = Provider<void>((ref) {
  if (!DesktopShell.available) return;
  final l10n = desktopL10n(ref);
  final chat = ref.watch(chatEnabledProvider);
  unawaited(
    DesktopShell.setJumpList([
      JumpListTask(l10n.composeTitleNew, DesktopArguments.compose),
      JumpListTask(l10n.tabMail, DesktopArguments.open(DesktopModuleTarget.mail)),
      if (chat) JumpListTask(l10n.tabChat, DesktopArguments.open(DesktopModuleTarget.chat)),
      JumpListTask(l10n.calendarTitle, DesktopArguments.open(DesktopModuleTarget.calendar)),
    ]),
  );
});

/// Unread mail and chat on the taskbar button (a red count) and in the tray
/// icon's hover text.
final desktopUnreadBadgeProvider = Provider<void>((ref) {
  if (!isDesktop) return;
  final signedIn = ref.watch(authStateProvider.select((s) => s.status)) == AuthStatus.authenticated;
  final mail = signedIn ? ref.watch(mailUnreadBadgeProvider) : 0;
  final chat = signedIn && ref.watch(chatEnabledProvider) ? ref.watch(chatBadgeProvider) : 0;
  final total = mail + chat;
  final text = total > 0 ? desktopL10n(ref).mailUnreadCount(total) : '';
  unawaited(DesktopShell.setBadge(total, description: text));
  unawaited(DesktopTray.instance.setToolTip(total > 0 ? 'XatBox — $text' : 'XatBox'));
});

/// Ctrl+Alt+M / ⌃⌥M new message, Ctrl+Alt+X / ⌃⌥X XatBox in front, from any
/// program (switch in the desktop settings).
final desktopHotkeysProvider = Provider<void>((ref) {
  if (!DesktopShell.available) return;
  final on = ref.watch(desktopSettingsProvider.select((s) => s.globalHotkeys));
  unawaited(DesktopShell.setGlobalHotkeys(on));
});
