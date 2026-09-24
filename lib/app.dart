import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/localization/localization.dart';
import 'core/network/offline_banner.dart';
import 'core/preferences/app_preferences.dart';
import 'core/routing/app_router.dart';
import 'core/routing/link_router.dart';
import 'core/routing/routes.dart';
import 'core/security/lock_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/skin_backdrop.dart';
import 'core/theme/tokens.dart';
import 'features/calendar/presentation/calendar_providers.dart';
import 'features/calls/presentation/call_controller.dart';
import 'features/calls/presentation/calls_providers.dart';
import 'features/calls/presentation/widgets/call_overlay.dart';
import 'features/chat/presentation/chat_providers.dart';
import 'features/about/presentation/shake_to_report.dart';
import 'features/update/presentation/update_gate.dart';
import 'features/home_widget/home_widget_service.dart';
import 'core/platform/desktop_layout.dart';
import 'core/platform/desktop_settings.dart';
import 'core/platform/desktop_zoom.dart';
import 'shared/widgets/desktop_frame.dart';
import 'shared/widgets/desktop_integration.dart';
import 'features/mail/presentation/desktop_mail_notifier.dart';
import 'features/mail/presentation/mail_outbox.dart';
import 'features/chat/presentation/status/desktop_auto_away.dart';
import 'features/calls/presentation/desktop_mini_call.dart';

class XatBoxApp extends ConsumerWidget {
  const XatBoxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final prefs = ref.watch(appPreferencesProvider);
    // Deep links and push taps (opened once signed in).
    ref.watch(externalNavigationProvider);
    // App icon shortcuts and the home screen widget (Android/iOS only).
    ref.watch(launcherIntegrationProvider);
    ref.watch(chatLifecycleProvider);
    ref.listen<String?>(chatOpenRequestProvider, (_, id) {
      if (id != null && id.isNotEmpty) {
        router.push(Routes.chatConversationPath(id));
        ref.read(chatOpenRequestProvider.notifier).request(null);
      }
    });
    ref.watch(calendarLifecycleProvider);
    ref.watch(callsLifecycleProvider);
    ref.watch(desktopTrayProvider);
    // Windows: mailto: links and jump list tasks, dropped files, the jump
    // list, the unread count on the taskbar button (no-op on phones).
    ref.watch(desktopShellProvider);
    ref.watch(desktopJumpListProvider);
    ref.watch(desktopUnreadBadgeProvider);
    ref.watch(desktopMailWatcherProvider);
    ref.watch(desktopHotkeysProvider);
    ref.watch(desktopAutoAwayProvider);
    ref.watch(desktopCrashReportProvider);
    // Desktop: letters kept in «Исходящие» go out when the network returns.
    ref.watch(mailOutboxLifecycleProvider);
    // An incoming call (socket/push) or a call accepted in the system UI
    // opens the call screen once.
    ref.listen<CallPhase>(callControllerProvider.select((s) => s.phase), (
      prev,
      next,
    ) {
      final opening = next == CallPhase.incoming || next == CallPhase.connecting;
      final wasIdle = prev == null || prev == CallPhase.idle || prev == CallPhase.ended;
      final location = router.routeInformationProvider.value.uri.path;
      if (opening && wasIdle && location != Routes.call) {
        router.push(Routes.call);
      }
    });
    // Reminder tap: `<event id>|<occurrence start>`.
    ref.listen<String?>(calendarOpenRequestProvider, (_, payload) {
      if (payload == null || payload.isEmpty) return;
      final i = payload.indexOf('|');
      final id = i < 0 ? payload : payload.substring(0, i);
      final occ = i < 0 ? '' : payload.substring(i + 1);
      router.push(Routes.calendarEventPath(id, occ.isEmpty ? null : occ));
      ref.read(calendarOpenRequestProvider.notifier).request(null);
    });
    // One skin = one theme. The standard skin follows the light/dark
    // preference; every other skin commits to its own brightness (web rule).
    final platform = MediaQuery.platformBrightnessOf(context);
    final palette = prefs.palette(platform);
    final theme = AppTheme.build(XatBoxTokens(palette, display: prefs.display));
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      routerConfig: router,
      // Snack bars from outside the pages (the outbox announcing sent mail).
      scaffoldMessengerKey: desktopMessengerKey,
      theme: theme,
      darkTheme: theme,
      // The resolved brightness (system UI, tests); both slots hold the skin.
      themeMode: palette.isDark ? ThemeMode.dark : ThemeMode.light,
      locale: prefs.locale,
      localizationsDelegates: AppLocalization.delegates,
      supportedLocales: AppLocalization.supportedLocales,
      localeResolutionCallback: AppLocalization.resolve,
      debugShowCheckedModeBanner: false,
      // Desktop: browser-like zoom of the whole interface (Ctrl+= / Ctrl+-).
      builder: (context, child) => DesktopZoomScope(
        enabled: ref.watch(desktopLayoutProvider),
        child: AppLockGate(
        // Mandatory updates block the app under the lock; shake-to-report
        // captures the screen below both.
        child: UpdateGate(
          child: ShakeToReport(
            child: OfflineBanner(
              // Desktop: during a call in another program, the call in a
              // small always-on-top window.
              child: DesktopMiniCallHost(
              // A minimised call floats over every page.
              child: CallOverlayHost(
                onOpen: () => router.push(Routes.call),
                // Desktop: the web shell (sidebar, top bar) around every
                // signed-in page.
                // Glass skins: the picture behind it all.
                child: SkinBackdropScope(
                  enabled: true,
                  custom: ref.watch(desktopSettingsProvider.select((s) => s.backdrop)),
                  child: DesktopFrame(
                    router: router,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// Shown instead of the app when the flavor configuration is invalid.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
