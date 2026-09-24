import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/features/chat/data/chat_models.dart';
import 'package:xatbox_mobile/features/chat/data/desktop_notifications.dart';
import 'package:xatbox_mobile/features/chat/data/push_notifications.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_home_screen.dart';
import 'package:xatbox_mobile/features/settings/settings_screen.dart';
import 'package:xatbox_mobile/features/settings/data/notification_preferences.dart';
import 'package:xatbox_mobile/core/platform/desktop.dart';
import 'package:xatbox_mobile/core/platform/desktop_layout.dart';
import 'package:xatbox_mobile/core/platform/desktop_zoom.dart';
import 'package:xatbox_mobile/features/mail/presentation/compose_screen.dart';
import 'package:xatbox_mobile/features/mail/presentation/folder_drawer.dart';
import 'package:xatbox_mobile/shared/widgets/app_sheet.dart';
import 'package:xatbox_mobile/shared/widgets/desktop_frame.dart';

import '../helpers/chat_fixtures.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

Future<void> settle(WidgetTester tester, [int steps = 10]) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('desktop chat notifications', () {
    // The fixture message of seq 3 is created at 10:03 UTC.
    final now = DateTime.utc(2026, 9, 14, 10, 4);

    ChatEvent created({String sender = ChatFixtures.peer, List<String> mentions = const [], String type = 'text'}) =>
        ChatEvent.fromFrame({
          'type': 'message.created',
          'conversation_id': ChatFixtures.conv,
          'seq': 3,
          'message': ChatFixtures.message(
            id: 'm3',
            seq: 3,
            body: 'three',
            sender: sender,
            mentions: mentions,
            type: type,
          ),
        });

    ChatConversation conversation({bool group = false, Map<String, dynamic>? settings}) {
      final json = ChatFixtures.conversation(group: group, title: group ? 'Кафедра' : 'Bob');
      if (settings != null) json['settings'] = {...json['settings'] as Map<String, dynamic>, ...settings};
      return ChatConversation.fromJson(json);
    }

    Map<String, String>? data({
      ChatEvent? event,
      ChatConversation? conv,
      NotificationPreferences prefs = const NotificationPreferences(),
      DateTime? at,
    }) => desktopChatNotificationData(
      event: event ?? created(),
      conversation: conv ?? conversation(),
      selfId: ChatFixtures.me,
      prefs: prefs,
      now: at ?? now,
      preview: 'three',
    );

    test('a new direct message becomes a push-shaped toast', () {
      final d = data()!;
      expect(d['type'], 'chat.message');
      expect(d['conversation_id'], ChatFixtures.conv);
      final content = buildPushNotificationContent(d)!;
      expect(content.title, 'Bob');
      expect(content.body, 'three');
      // The tap payload routes through the same handler as a phone push.
      expect(decodePushTapPayload(content.payload)!['conversation_id'], ChatFixtures.conv);
    });

    test('group toasts carry the sender and the chat title', () {
      final content = buildPushNotificationContent(data(conv: conversation(group: true))!)!;
      expect(content.title, 'Кафедра');
      expect(content.body, 'Bob: three');
    });

    test('own messages, muted chats and catch-up after a reconnect stay quiet', () {
      expect(data(event: created(sender: ChatFixtures.me)), isNull);
      expect(data(conv: conversation(settings: {'muted_until': '2099-01-01T00:00:00Z'})), isNull);
      expect(data(at: now.add(const Duration(hours: 1))), isNull);
      expect(data(event: created(type: 'system')), isNull);
    });

    test('notification preferences apply as on the server', () {
      expect(data(prefs: const NotificationPreferences(directMessages: false)), isNull);
      const mentionsOnly = NotificationPreferences(groupMentionsOnly: true);
      expect(data(conv: conversation(group: true), prefs: mentionsOnly), isNull);
      final mention = data(
        event: created(mentions: [ChatFixtures.me]),
        conv: conversation(group: true),
        prefs: mentionsOnly,
      );
      expect(mention?['type'], 'chat.mention');
    });

    test('quiet hours (local time, across midnight)', () {
      final local = DateTime(2026, 9, 14, 23, 30);
      final quiet = NotificationPreferences(
        quietHours: const QuietHoursPrefs(enabled: true, start: '22:00', end: '07:00'),
      );
      final event = ChatEvent.fromFrame({
        'type': 'message.created',
        'conversation_id': ChatFixtures.conv,
        'seq': 3,
        'message': {...ChatFixtures.message(id: 'm3', seq: 3), 'created_at': local.toUtc().toIso8601String()},
      });
      expect(data(event: event, prefs: quiet, at: local), isNull);
      expect(data(event: event, at: local), isNotNull);
    });
  });

  group('desktop shell', () {
    test('every location belongs to its module (the top bar label)', () {
      expect(DesktopNav.moduleOf(Routes.mail), DesktopModule.mail);
      expect(DesktopNav.moduleOf(Routes.mailMessagePath('m1')), DesktopModule.mail);
      expect(DesktopNav.moduleOf('/official/m/1'), DesktopModule.official);
      expect(DesktopNav.moduleOf(Routes.chatConversationPath('c1')), DesktopModule.chat);
      expect(DesktopNav.moduleOf(Routes.call), DesktopModule.calls);
      expect(DesktopNav.moduleOf(Routes.callsNew), DesktopModule.calls);
      expect(DesktopNav.moduleOf(Routes.meetPath('abc')), DesktopModule.calls);
      expect(DesktopNav.moduleOf(Routes.calendarEventPath('e1')), DesktopModule.calendar);
      expect(DesktopNav.moduleOf(Routes.taskPath('t1')), DesktopModule.tasks);
      expect(DesktopNav.moduleOf(Routes.contactProfilePath('u1')), DesktopModule.contacts);
      expect(DesktopNav.moduleOf(Routes.settingsAppearance), DesktopModule.settings);
      expect(DesktopNav.moduleOf(Routes.profile), DesktopModule.settings);
    });

    test('no shell before sign-in', () {
      expect(DesktopNav.hiddenOn(Routes.login), isTrue);
      expect(DesktopNav.hiddenOn(Routes.splash), isTrue);
      expect(DesktopNav.hiddenOn(Routes.mail), isFalse);
    });

    test('zoom steps like a browser, clamped at both ends', () {
      expect(DesktopZoom.step(1.0, 1), 1.1);
      expect(DesktopZoom.step(1.0, -1), 0.9);
      expect(DesktopZoom.step(DesktopZoom.steps.last, 1), DesktopZoom.steps.last);
      expect(DesktopZoom.step(DesktopZoom.steps.first, -1), DesktopZoom.steps.first);
      expect(DesktopZoom.label(1.25), '125%');
    });
  });

  Future<TestHarness> pumpDesktop(WidgetTester tester) async {
    debugDesktopOverride = true;
    addTearDown(() => debugDesktopOverride = null);
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localeTestValue = const Locale('ru');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final h = await TestHarness.create(
      storedToken: Fixtures.token,
      overrides: [desktopLayoutProvider.overrideWithValue(true)],
    );
    addTearDown(h.dispose);
    h.stubSignedIn();
    await tester.pumpWidget(UncontrolledProviderScope(container: h.container, child: const XatBoxApp()));
    await settle(tester);
    return h;
  }

  testWidgets('desktop layout: the web shell — one sidebar, the top bar, no bottom bar', (tester) async {
    await pumpDesktop(tester);

    expect(find.byType(MailHomeScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    // One folder sidebar (the shell's), not a second one inside mail.
    expect(find.byType(FolderDrawer), findsOneWidget);
    expect(find.byKey(const Key('desktop_search')), findsOneWidget);
    expect(find.byKey(const Key('topbar_theme')), findsOneWidget);
    expect(find.byKey(const Key('topbar_account')), findsOneWidget);
    // Mail has no app bar of its own; its controls sit on the list bar.
    expect(find.byKey(const Key('notifications_bell')), findsNothing);
    expect(find.byKey(const Key('mail_settings_button')), findsOneWidget);
    expect(find.byKey(const Key('compose_fab')), findsNothing);
    // No «Сегодня» on desktop.
    expect(find.byKey(const Key('tab_today')), findsNothing);

    // The module rail: round buttons, no «Задачи» / «Официальные».
    expect(find.byKey(const Key('desktop_rail_mail')), findsOneWidget);
    expect(find.byKey(const Key('desktop_rail_calendar')), findsOneWidget);
    expect(find.byKey(const Key('desktop_rail_tasks')), findsNothing);
    expect(find.byKey(const Key('sidebar_tasks')), findsNothing);
    expect(find.byKey(const Key('sidebar_official')), findsNothing);
    // The folder sidebar is mail's: open beside the mail list.
    expect(tester.getSize(find.byType(FolderDrawer)).width, greaterThan(0));

    await tester.tap(find.byKey(const Key('desktop_rail_settings')));
    await settle(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    // Other modules get the folder sidebar's width.
    expect(find.byKey(const Key('folder_inbox')).hitTestable(), findsNothing);

    await tester.tap(find.byKey(const Key('desktop_rail_mail')));
    await settle(tester);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(MailHomeScreen), findsOneWidget);
  });

  testWidgets('desktop: the sidebar collapses to round icons', (tester) async {
    await pumpDesktop(tester);
    await tester.tap(find.byKey(const Key('sidebar_collapse')));
    await settle(tester);
    expect(find.byKey(const Key('sidebar_expand')), findsOneWidget);
    expect(tester.getSize(find.byType(FolderDrawer)).width, DesktopNav.sidebarCollapsedWidth);
    await tester.tap(find.byKey(const Key('sidebar_expand')));
    await settle(tester);
    expect(tester.getSize(find.byType(FolderDrawer)).width, DesktopNav.sidebarWidth);
  });

  testWidgets('desktop composer: recipients become chips, the draft saves itself', (tester) async {
    final h = await pumpDesktop(tester);
    h.adapter.onJson('POST', '/mail/drafts', {'id': 'd1'}, status: 201);
    await tester.tap(find.byKey(const Key('compose_button')));
    await settle(tester);

    await tester.enterText(find.byKey(const Key('compose_to')), 'bob@example.kz,');
    await settle(tester, 2);
    expect(find.byKey(const Key('recipient_chip_bob@example.kz')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('compose_to')), 'wrong-address ');
    await settle(tester, 2);
    expect(find.byKey(const Key('recipient_chip_wrong-address')), findsOneWidget);
    // Backspace in the empty field takes the last chip back for editing.
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await settle(tester, 2);
    expect(find.byKey(const Key('recipient_chip_wrong-address')), findsNothing);

    await tester.enterText(find.byKey(const Key('compose_subject')), 'План');
    // Three quiet seconds: saved without a button, «Черновик сохранён».
    for (var i = 0; i < 70; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(h.adapter.of('POST', '/mail/drafts'), hasLength(1));
    expect(h.adapter.of('POST', '/mail/drafts').single.json['to'], ['bob@example.kz', 'wrong-address']);
    expect(find.byKey(const Key('compose_draft_saved')), findsOneWidget);
  });

  testWidgets('desktop: compose opens as a floating window over the mail', (tester) async {
    await pumpDesktop(tester);
    await tester.tap(find.byKey(const Key('compose_button')));
    await settle(tester);
    expect(find.byType(ComposeScreen), findsOneWidget);
    // The page behind stays: the composer is a window, not a route.
    expect(find.byType(MailHomeScreen), findsOneWidget);
    expect(tester.getSize(find.byType(ComposeScreen)), const Size(580, 520));

    await tester.tap(find.byKey(const Key('compose_window_minimize')));
    await settle(tester);
    expect(find.byKey(const Key('compose_window_restore')), findsOneWidget);
    await tester.tap(find.byKey(const Key('compose_window_restore')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('compose_window_close')));
    await settle(tester);
    expect(find.byType(ComposeScreen), findsNothing);
  });

  group('showAppSheet', () {
    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppSheet<void>(context: context, builder: (_) => const Text('sheet body')),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('sheet body'), findsOneWidget);
    }

    testWidgets('a bottom sheet on phones', (tester) async {
      await open(tester);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(DesktopSheetDialog), findsNothing);
    });

    testWidgets('a centred dialog on the desktop', (tester) async {
      debugDesktopOverride = true;
      addTearDown(() => debugDesktopOverride = null);
      await open(tester);
      expect(find.byType(DesktopSheetDialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
    });
  });
}
