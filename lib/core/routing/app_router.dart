import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/calendar/data/calendar_models.dart';
import '../../features/calendar/presentation/calendar_lists_screens.dart';
import '../../features/calendar/presentation/calendar_screen.dart';
import '../../features/calendar/presentation/event_detail_screen.dart';
import '../../features/calendar/presentation/event_edit_screen.dart';
import '../../features/calls/data/call_models.dart';
import '../../features/calls/presentation/call_details_screen.dart';
import '../../features/calls/presentation/call_screen.dart';
import '../../features/calls/presentation/calls_screen.dart';
import '../../features/calls/presentation/meeting_prejoin_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/chat/presentation/chat_media_screen.dart';
import '../../features/chat/presentation/chat_providers.dart';
import '../../features/chat/presentation/comments/channel_thread_screen.dart';
import '../../features/chat/presentation/chat_share_screen.dart';
import '../../features/chat/presentation/conversation_screen.dart';
import '../../features/chat/presentation/group_info_screen.dart';
import '../../features/chat/presentation/moderation/moderation_screens.dart';
import '../../features/chat/presentation/new_chat_screen.dart';
import '../../features/contacts/data/contact_models.dart';
import '../../features/contacts/presentation/contact_profile_screen.dart';
import '../../features/contacts/presentation/contacts_desktop.dart';
import '../../features/contacts/presentation/contacts_screen.dart';
import '../../features/mail/presentation/compose_screen.dart';
import '../../features/mail/presentation/mail_home_screen.dart';
import '../../features/mail/presentation/message_detail_screen.dart';
import '../../features/mail/presentation/settings/mail_settings_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/official/data/official_models.dart';
import '../../features/official/presentation/official_compose_screen.dart';
import '../../features/official/presentation/official_detail_screen.dart';
import '../../features/official/presentation/official_list_screen.dart';
import '../../features/official/presentation/official_stats_screen.dart';
import '../../features/about/data/feedback_api.dart';
import '../../features/about/presentation/about_screen.dart';
import '../../features/about/presentation/report_problem_screen.dart';
import '../../features/home_widget/saved_chat_launcher_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/search/presentation/unified_search_screen.dart';
import '../../features/today/presentation/today_screen.dart';
import '../../features/tasks/presentation/tasks_board.dart';
import '../../features/sessions/sessions_screen.dart';
import '../../features/update/presentation/update_screen.dart';
import '../../features/settings/appearance_screen.dart';
import '../../features/settings/desktop_settings_screen.dart';
import '../../features/settings/notification_settings_screen.dart';
import '../../features/settings/security_screen.dart';
import '../../features/mail/presentation/settings/mail_clients_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/desktop_page.dart';
import '../auth/auth_providers.dart';
import '../auth/auth_session.dart';
import '../platform/desktop_layout.dart';
import '../platform/desktop_modal_observer.dart';
import '../platform/launcher_requests.dart';
import '../preferences/app_preferences.dart';
import 'routes.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// The tab for Настройки → Оформление → «Начальный экран» (pure).
String startRoute(StartScreen screen, {required bool chatEnabled}) =>
    switch (screen) {
      StartScreen.today => Routes.today,
      StartScreen.chat when chatEnabled => Routes.chat,
      _ => Routes.mail,
    };

/// Pure redirect rule (unit-tested): where to send the user for a given
/// session status and requested location; [home] is the start screen.
String? authRedirect(
  AuthStatus status,
  String location, {
  String home = Routes.mail,
}) {
  final onSplash = location == Routes.splash;
  final onLogin = location == Routes.login;
  switch (status) {
    case AuthStatus.unknown:
    case AuthStatus.unreachable:
      return onSplash ? null : Routes.splash;
    case AuthStatus.unauthenticated:
      return onLogin ? null : Routes.login;
    case AuthStatus.authenticated:
      return (onSplash || onLogin) ? home : null;
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(authSessionProvider);
  // Desktop: every settings section is the web settings page (section list
  // + panel); phones keep the page as it is.
  Widget settingsPage(DesktopSettingsSection section, Widget phone) =>
      ref.read(desktopLayoutProvider) ? DesktopSettingsScreen(section: section) : phone;
  // Late: the desktop redirects below move to a module through it.
  late final GoRouter router;
  router = GoRouter(
    navigatorKey: rootNavigatorKey,
    // Desktop: dialogs and viewers shade the shell around the pages too.
    observers: [if (ref.read(desktopLayoutProvider)) DesktopModalObserver.instance],
    initialLocation: Routes.splash,
    refreshListenable: session,
    redirect: (context, state) {
      // Desktop has no official-messages pages (links from notifications
      // land on mail instead); tasks are the desktop board.
      final loc = state.matchedLocation;
      if (ref.read(desktopLayoutProvider) && (loc == Routes.official || loc.startsWith('${Routes.official}/'))) {
        return Routes.mail;
      }
      return authRedirect(
      session.status,
      state.matchedLocation,
      home: startRoute(
        // Desktop has no «Сегодня»: the web shell opens on mail.
        ref.read(desktopLayoutProvider) && ref.read(appPreferencesProvider).startScreen == StartScreen.today
            ? StartScreen.mail
            : ref.read(appPreferencesProvider).startScreen,
        chatEnabled: ref.read(chatEnabledProvider),
      ),
    );
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.mail,
                builder: (_, _) => const MailHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.chat,
                builder: (_, _) => const ChatListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.calls,
                builder: (_, _) => const CallsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.contacts,
                // Desktop: «Мои контакты», colleagues and departments.
                builder: (_, _) => ref.read(desktopLayoutProvider) ? const DesktopContactsScreen() : const ContactsScreen(),
              ),
            ],
          ),
          // Index 4 (AppShell.todayBranch): listed in the bar only when it
          // is the start screen, so the four module tabs keep their indices.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.today,
                builder: (_, _) => const DesktopPage(maxWidth: 960, child: TodayScreen()),
              ),
            ],
          ),
          // 5 (AppShell.calendarBranch) and 6 (AppShell.tasksBranch): tabs of
          // the phone's glass bar; on desktop the sidebar opens them. State
          // lives in providers, so switching back restores it.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.calendar,
                builder: (_, _) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.tasks,
                // The Kanban board (the phone lays it out for a narrow screen).
                builder: (_, _) => const TasksBoardScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.contactProfile,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => DesktopPage(child: ContactProfileScreen(
          userId: state.pathParameters['id']!,
          initial: state.extra is Contact ? state.extra! as Contact : null,
        )),
      ),
      GoRoute(
        path: Routes.search,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const DesktopPage(maxWidth: 960, child: UnifiedSearchScreen()),
      ),
      GoRoute(
        path: Routes.notifications,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const DesktopPage(child: NotificationsScreen()),
      ),
      GoRoute(
        path: Routes.official,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const OfficialListScreen(),
      ),
      GoRoute(
        path: Routes.officialNew,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const DesktopPage(maxWidth: 960, child: OfficialComposeScreen()),
      ),
      GoRoute(
        path: Routes.officialMessage,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => DesktopPage(maxWidth: 960, child: OfficialDetailScreen(messageId: state.pathParameters['id']!)),
      ),
      GoRoute(
        path: Routes.officialStats,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => DesktopPage(maxWidth: 960, child: OfficialStatsScreen(
          messageId: state.pathParameters['id']!,
          sent: state.extra is SentOfficial ? state.extra! as SentOfficial : null,
        )),
      ),
      GoRoute(
        path: Routes.chatNew,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const DesktopPage(child: NewChatScreen()),
      ),
      // Launcher shortcuts (lib/features/home_widget).
      GoRoute(
        path: Routes.chatSaved,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const SavedChatLauncherScreen(),
      ),
      GoRoute(
        path: Routes.chatSearch,
        redirect: (_, _) {
          ref.read(chatSearchRequestProvider.notifier).request();
          return Routes.chat;
        },
      ),
      GoRoute(
        path: Routes.chatConversation,
        parentNavigatorKey: rootNavigatorKey,
        // Desktop: a chat opened from anywhere (a toast, search, a contact,
        // a call) opens in the messenger's right pane, as on the web.
        redirect: (_, state) {
          if (!ref.read(desktopLayoutProvider)) return null;
          ref.read(chatSelectedConversationProvider.notifier).select(state.pathParameters['id']);
          _settleOn(() => router, Routes.chat);
          return Routes.chat;
        },
        builder: (_, state) =>
            ConversationScreen(conversationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.chatInfo,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => DesktopPage(child: GroupInfoScreen(conversationId: state.pathParameters['id']!)),
      ),
      GoRoute(
        path: Routes.chatAddMembers,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => DesktopPage(child: NewChatScreen(addToConversationId: state.pathParameters['id'])),
      ),
      GoRoute(
        path: Routes.chatMedia,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => DesktopPage(maxWidth: 960, child: ChatMediaScreen(conversationId: state.pathParameters['id']!)),
      ),
      GoRoute(
        path: Routes.chatComments,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => ChannelThreadScreen(
          conversationId: state.pathParameters['id']!,
          postId: state.pathParameters['postId']!,
        ),
      ),
      GoRoute(
        path: Routes.chatShare,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const ChatShareScreen(),
      ),
      GoRoute(
        path: Routes.chatModeration,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const DesktopPage(maxWidth: 960, child: ModerationQueueScreen()),
      ),
      GoRoute(
        path: Routes.chatModerationReport,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => DesktopPage(child: ModerationReportScreen(reportId: s.pathParameters['id']!)),
      ),
      // Full-screen routes over the bottom bar.
      GoRoute(
        path: Routes.mailMessage,
        parentNavigatorKey: rootNavigatorKey,
        // Desktop: a letter opened from anywhere (a toast, search, the
        // calendar) opens in mail's reading pane (the web's `?m=`).
        redirect: (_, state) {
          if (!ref.read(desktopLayoutProvider)) return null;
          ref.read(mailOpenMessageProvider.notifier).open(state.pathParameters['id']);
          _settleOn(() => router, Routes.mail);
          return Routes.mail;
        },
        builder: (_, state) =>
            MessageDetailScreen(messageId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.mailCompose,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => DesktopPage(maxWidth: 960, child: ComposeScreen(
          args: state.extra is ComposeArgs
              ? state.extra! as ComposeArgs
              : const ComposeArgs.blank(),
        )),
      ),
      GoRoute(
        path: Routes.call,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const CallScreen(),
      ),
      GoRoute(
        path: Routes.callsNew,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const DesktopPage(child: NewCallScreen()),
      ),
      GoRoute(
        path: Routes.callDetails,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => DesktopPage(child: CallDetailsScreen(
          callId: state.pathParameters['id']!,
          initial: state.extra is CallInfo ? state.extra! as CallInfo : null,
        )),
      ),
      GoRoute(
        path: Routes.meet,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            MeetingPrejoinScreen(code: state.pathParameters['code']!),
      ),
      GoRoute(
        path: Routes.calendarNew,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => DesktopPage(child: EventEditScreen(
          args: state.extra is EventEditArgs
              ? state.extra! as EventEditArgs
              : const EventEditArgs.create(),
        )),
      ),
      GoRoute(
        path: Routes.calendarEdit,
        parentNavigatorKey: rootNavigatorKey,
        redirect: (_, state) =>
            state.extra is EventEditArgs ? null : Routes.calendar,
        builder: (_, state) => DesktopPage(child: EventEditScreen(args: state.extra! as EventEditArgs)),
      ),
      GoRoute(
        path: Routes.calendarSearch,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => DesktopPage(maxWidth: 960, child: CalendarSearchScreen(
          initialQuery: state.uri.queryParameters['q'] ?? '',
        )),
      ),
      GoRoute(
        path: Routes.calendarInvitations,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const DesktopPage(maxWidth: 960, child: CalendarInvitationsScreen()),
      ),
      GoRoute(
        path: Routes.calendarEvent,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => DesktopPage(child: EventDetailScreen(
          eventId: state.pathParameters['id']!,
          occurrenceStart: state.uri.queryParameters['occ'],
          initial: state.extra is CalendarOccurrence
              ? state.extra! as CalendarOccurrence
              : null,
        )),
      ),
      GoRoute(
        path: Routes.task,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => TasksBoardScreen(openTaskId: state.pathParameters['id']),
      ),
      GoRoute(
        path: Routes.profile,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => settingsPage(DesktopSettingsSection.profile, const ProfileScreen()),
      ),
      GoRoute(
        path: Routes.settings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => settingsPage(DesktopSettingsSection.general, const SettingsScreen()),
      ),
      GoRoute(
        path: Routes.settingsAppearance,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => settingsPage(DesktopSettingsSection.appearance, const AppearanceScreen()),
      ),
      GoRoute(
        path: Routes.settingsSecurity,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => settingsPage(DesktopSettingsSection.security, const SecurityScreen()),
      ),
      GoRoute(
        path: Routes.settingsNotifications,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => settingsPage(DesktopSettingsSection.notifications, const NotificationSettingsScreen()),
      ),
      GoRoute(
        path: Routes.settingsMailClients,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => settingsPage(DesktopSettingsSection.mailClients, const MailClientsScreen()),
      ),
      GoRoute(
        path: Routes.settingsMail,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => settingsPage(DesktopSettingsSection.mail, const MailSettingsScreen()),
      ),
      GoRoute(
        path: Routes.settingsMailSignature,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => settingsPage(DesktopSettingsSection.mailSignature, const SignatureSettingsScreen()),
      ),
      GoRoute(
        path: Routes.settingsMailVacation,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => settingsPage(DesktopSettingsSection.mailVacation, const VacationSettingsScreen()),
      ),
      GoRoute(
        path: Routes.settingsMailBlockedSenders,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => settingsPage(DesktopSettingsSection.mailBlocked, const BlockedSendersScreen()),
      ),
      GoRoute(
        path: Routes.settingsMailBookmarkFolders,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => settingsPage(DesktopSettingsSection.mailBookmarkFolders, const BookmarkFoldersScreen()),
      ),
      GoRoute(
        path: Routes.settingsMailImport,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => settingsPage(DesktopSettingsSection.mailImport, const MailImportScreen()),
      ),
      GoRoute(
        path: Routes.settingsUpdate,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const DesktopPage(child: UpdateScreen()),
      ),
      GoRoute(
        path: Routes.settingsSessions,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => settingsPage(DesktopSettingsSection.sessions, const SessionsScreen()),
      ),
      GoRoute(
        path: Routes.settingsShortcuts,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => settingsPage(DesktopSettingsSection.shortcuts, const DesktopShortcutsScreen()),
      ),
      GoRoute(
        path: Routes.settingsAbout,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => settingsPage(DesktopSettingsSection.about, const AboutScreen()),
      ),
      GoRoute(
        path: Routes.reportProblem,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => DesktopPage(child: ReportProblemScreen(
          screenshot: state.extra is FeedbackScreenshot
              ? state.extra! as FeedbackScreenshot
              : null,
        )),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// After a desktop redirect of a pushed page into a module (a chat, a
/// letter): make that module the current location, so the module rail and
/// the top bar follow and no page stays stacked under it.
void _settleOn(GoRouter Function() routerOf, String location) {
  // After the push has landed (the next frame), not during it.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final router = routerOf();
    if (router.routerDelegate.currentConfiguration.uri.path != location || router.canPop()) router.go(location);
  });
  WidgetsBinding.instance.scheduleFrame();
}
