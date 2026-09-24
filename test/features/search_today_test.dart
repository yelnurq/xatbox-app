import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/auth/auth_session.dart';
import 'package:xatbox_mobile/core/network/network_status.dart';
import 'package:xatbox_mobile/core/preferences/app_preferences.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/conversation_screen.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_home_screen.dart';
import 'package:xatbox_mobile/features/search/data/recent_searches.dart';
import 'package:xatbox_mobile/features/search/presentation/search_providers.dart';
import 'package:xatbox_mobile/features/settings/appearance_screen.dart';
import 'package:xatbox_mobile/features/today/presentation/today_screen.dart';
import 'package:xatbox_mobile/shared/widgets/app_shell.dart';

import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// «Единый поиск» and «Сегодня» through the real router.
void main() {
  late TestHarness h;
  tearDown(() => h.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 20]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  void useRussian(WidgetTester tester) {
    // A 360×800 phone.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localeTestValue = const Locale('ru');
    tester.platformDispatcher.localesTestValue = const [Locale('ru')];
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: const XatBoxApp(),
      ),
    );
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    unawaited(h.container.read(chatRepositoryProvider).stop());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 30));
  }

  const hitId = 'msg-hit-1';

  /// Mail + chat user: Bob is a colleague, a chat and a mail sender.
  Future<void> stubAll({
    List<Override> overrides = const [],
    FixedNetworkMonitor? network,
  }) async {
    h = await TestHarness.create(
      storedToken: Fixtures.token,
      chatBaseUrl: 'http://chat.local/api/v1',
      overrides: overrides,
      network: network,
    );
    h.adapter.onJson('GET', '/me', Fixtures.me());
    h.adapter.onJson('GET', '/mail/summary', Fixtures.summary(inboxUnread: 2));
    h.adapter.on('GET', '/mail/messages', (r) {
      final q = r.query['q'] as String?;
      final page = q == null
          ? Fixtures.page(Fixtures.messages(2), total: 2)
          : Fixtures.page([
              {...Fixtures.message(7), 'subject': 'Отчёт для Bob'},
            ], total: 1);
      return FakeResponse(200, json: page);
    });
    h.chatAdapter.onJson(
      'GET',
      '/chats',
      ChatFixtures.chats([
        ChatFixtures.conversation(
          unread: 2,
          lastMessage: ChatFixtures.message(id: 'last', seq: 1, body: 'привет'),
        ),
      ]),
    );
    h.chatAdapter.onPattern(
      'POST',
      r'^/push/devices$',
      (_) => const FakeResponse(204),
    );
    h.chatAdapter.onPattern(
      'GET',
      r'^/chats/[^/]+/messages$',
      (_) => FakeResponse(200, json: ChatFixtures.messages(const [])),
    );
    h.chatAdapter.on('GET', '/users', (r) {
      final q = ((r.query['q'] as String?) ?? '').toLowerCase();
      return FakeResponse(
        200,
        json: {
          'users': [if ('bob'.contains(q)) ChatFixtures.user()],
        },
      );
    });
    h.chatAdapter.onJson('GET', '/search', {
      'messages': [
        ChatFixtures.message(id: hitId, seq: 5, body: 'Bob, посмотри отчёт'),
      ],
    });
  }

  Future<void> typeQuery(WidgetTester tester, String q) async {
    await tester.enterText(find.byKey(const Key('unified_search_field')), q);
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
  }

  testWidgets(
    'search runs across people, chats and mail; a message hit opens the chat',
    (tester) async {
      useRussian(tester);
      await stubAll();
      await pumpApp(tester);

      h.links.emit(Uri.parse('xatbox://search'));
      await settle(tester);
      expect(find.byKey(const Key('unified_search_field')), findsOneWidget);

      await typeQuery(tester, 'Bob');
      expect(find.byKey(const Key('search_section_contacts')), findsOneWidget);
      expect(find.byKey(const Key('search_section_chats')), findsOneWidget);
      expect(find.byKey(const Key('search_section_mail')), findsOneWidget);
      // Calendar needs its permission: no section.
      expect(find.byKey(const Key('search_section_calendar')), findsNothing);
      expect(find.byKey(const Key('search_offline_hint')), findsNothing);
      expect(
        h.adapter
            .of('GET', '/mail/messages')
            .where((r) => r.query['q'] == 'Bob'),
        hasLength(1),
      );
      expect(h.chatAdapter.of('GET', '/search').single.query['q'], 'Bob');
      expect(find.byKey(const ValueKey('search_mail_m7')), findsOneWidget);

      final hit = find.byKey(const ValueKey('search_message_$hitId'));
      await tester.ensureVisible(hit);
      await tester.pump();
      await tester.tap(hit);
      await settle(tester, 30);
      expect(find.byType(ConversationScreen), findsOneWidget);
      // The query was remembered.
      expect(h.container.read(recentSearchesProvider), ['Bob']);

      await finish(tester);
    },
  );

  testWidgets('«Показать все» opens the mail search pre-filled', (
    tester,
  ) async {
    useRussian(tester);
    await stubAll();
    await pumpApp(tester);
    h.links.emit(Uri.parse('xatbox://search'));
    await settle(tester);
    await typeQuery(tester, 'Bob');

    await tester.tap(find.byKey(const Key('search_more_mail')));
    await settle(tester, 30);
    expect(find.byType(MailHomeScreen), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const Key('mail_search_field')),
    );
    expect(field.controller!.text, 'Bob');

    await finish(tester);
  });

  testWidgets('offline: cached sections only, with the hint', (tester) async {
    useRussian(tester);
    await stubAll(network: FixedNetworkMonitor(NetworkKind.none));
    await pumpApp(tester);
    h.links.emit(Uri.parse('xatbox://search'));
    await settle(tester);
    final searchesBefore = h.chatAdapter.of('GET', '/search').length;
    await typeQuery(tester, 'Bob');

    expect(find.byKey(const Key('search_offline_hint')), findsOneWidget);
    expect(find.text('Офлайн — только сохранённое'), findsOneWidget);
    // No server search while offline; the chat title still matches.
    expect(h.chatAdapter.of('GET', '/search').length, searchesBefore);
    expect(
      h.adapter.of('GET', '/mail/messages').where((r) => r.query['q'] != null),
      isEmpty,
    );
    expect(
      find.byKey(const ValueKey('search_chat_${ChatFixtures.conv}')),
      findsOneWidget,
    );

    await finish(tester);
  });

  testWidgets('«Сегодня» as start screen: sections render and navigate', (
    tester,
  ) async {
    useRussian(tester);
    await stubAll(
      overrides: [
        initialAppPreferencesProvider.overrideWithValue(
          const AppPreferences(startScreen: StartScreen.today),
        ),
      ],
    );
    await pumpApp(tester);

    expect(find.byType(TodayScreen), findsOneWidget);
    // «Сегодня» lives under «Ещё» of the glass bar, which is lit.
    expect(find.byKey(const Key('tab_more')), findsOneWidget);
    expect(find.byKey(const Key('today_greeting')), findsOneWidget);
    expect(find.byKey(const Key('today_mail')), findsOneWidget);
    expect(find.byKey(const Key('today_chats')), findsOneWidget);
    expect(find.byKey(const Key('today_new_chat')), findsOneWidget);
    // Calendar / calls unavailable → no sections.
    expect(find.byKey(const Key('today_events')), findsNothing);
    expect(find.byKey(const Key('today_calls')), findsNothing);
    // Today starts no request of its own: the inbox list is not fetched.
    expect(h.adapter.of('GET', '/mail/messages'), isEmpty);

    await tester.tap(
      find.byKey(const ValueKey('today_chat_${ChatFixtures.conv}')),
    );
    await settle(tester, 30);
    expect(find.byType(ConversationScreen), findsOneWidget);

    await finish(tester);
  });

  testWidgets('«Сегодня»: official messages to acknowledge and urgent tasks', (
    tester,
  ) async {
    useRussian(tester);
    await stubAll(
      overrides: [
        initialAppPreferencesProvider.overrideWithValue(
          const AppPreferences(startScreen: StartScreen.today),
        ),
      ],
    );
    final me = Fixtures.me(
      permissions: ['mail.read', 'mail.send', 'official.read', 'tasks.manage.self'],
    );
    h.adapter.onJson('GET', '/me', me);
    h.adapter.onJson('GET', '/notifications', {'notifications': <Object>[], 'unread': 0});
    h.adapter.onJson('GET', '/official', {
      'messages': [
        {
          'id': 'o1',
          'sender_name': 'Ректор',
          'sender_role': 'org_admin',
          'title': 'Приказ о дежурстве',
          'body': 'Текст',
          'requires_acknowledgement': true,
          'created_at': '2026-09-14 09:00:00+00',
          'read_at': '2026-09-14 10:00:00+00',
        },
        {
          'id': 'o2',
          'sender_name': 'Ректор',
          'sender_role': 'org_admin',
          'title': 'Прочитанное объявление',
          'body': 'Текст',
          'requires_acknowledgement': false,
          'created_at': '2026-09-13 09:00:00+00',
          'read_at': '2026-09-13 10:00:00+00',
        },
      ],
    });
    Map<String, dynamic> task(String id, String? due, {String status = 'todo'}) => {
      'id': id,
      'owner_user_id': me['id'],
      'title': 'Задача $id',
      'description': '',
      'priority': 'normal',
      'status': status,
      'source_type': 'manual',
      'due_at': ?due,
      'created_at': '2026-09-01 09:00:00+00',
    };
    h.adapter.onJson('GET', '/tasks', {
      'tasks': [
        task('late', '2020-01-01 09:00:00+00'),
        task('someday', null),
        task('finished', '2020-01-01 09:00:00+00', status: 'done'),
      ],
    });
    await pumpApp(tester);

    expect(find.byKey(const Key('today_official')), findsOneWidget);
    expect(find.byKey(const ValueKey('today_official_o1')), findsOneWidget);
    expect(find.byKey(const ValueKey('today_official_o2')), findsNothing);
    await tester.scrollUntilVisible(find.byKey(const Key('today_tasks')), 200);
    expect(find.byKey(const ValueKey('today_task_late')), findsOneWidget);
    expect(find.byKey(const ValueKey('today_task_someday')), findsNothing);
    expect(find.byKey(const ValueKey('today_task_finished')), findsNothing);

    await finish(tester);
  });

  testWidgets('appearance: «Начальный экран» is saved', (tester) async {
    useRussian(tester);
    // Tall view: the whole settings list is built.
    tester.view.physicalSize = const Size(1080, 7200);
    h = await TestHarness.create(chatBaseUrl: 'http://chat.local/api/v1');
    await tester.pumpWidget(
      wrapWidget(const AppearanceScreen(), container: h.container),
    );
    await tester.pump();
    final segment = find
        .descendant(
          of: find.byKey(const Key('appearance_start_screen')),
          matching: find.text('Сегодня'),
        )
        .first;
    await tester.ensureVisible(segment);
    await tester.pump();
    await tester.tap(segment);
    await settle(tester);
    expect(
      h.container.read(appPreferencesProvider).startScreen,
      StartScreen.today,
    );
    final stored = await tester.runAsync(
      () => h.container.read(appPreferencesStoreProvider).read(),
    );
    expect(stored!.startScreen, StartScreen.today);
  });

  group('pure', () {
    test('start route and redirect', () {
      expect(startRoute(StartScreen.today, chatEnabled: false), Routes.today);
      expect(startRoute(StartScreen.chat, chatEnabled: true), Routes.chat);
      expect(startRoute(StartScreen.chat, chatEnabled: false), Routes.mail);
      expect(
        authRedirect(
          AuthStatus.authenticated,
          Routes.splash,
          home: Routes.today,
        ),
        Routes.today,
      );
      final tabs = AppShell.tabBranches();
      expect(tabs, [AppShell.mailBranch, AppShell.chatBranch, AppShell.calendarBranch, AppShell.tasksBranch]);
      expect(AppShell.tabBranches(chat: false, calendar: false), [AppShell.mailBranch, AppShell.tasksBranch]);
      // Modules without a tab light «Ещё» (the index after the tabs).
      expect(AppShell.tabIndexOf(AppShell.todayBranch, tabs), tabs.length);
      expect(AppShell.tabIndexOf(AppShell.callsBranch, tabs), tabs.length);
      expect(AppShell.tabIndexOf(AppShell.calendarBranch, tabs), 2);
    });

    test('preference round trip and recent queries', () {
      const p = AppPreferences(startScreen: StartScreen.chat);
      expect(AppPreferences.fromJson(p.toJson()).startScreen, StartScreen.chat);
      expect(AppPreferences.fromJson(const {}).startScreen, StartScreen.mail);
      expect(RecentSearchStore.push(['bob', 'x'], 'Bob'), ['Bob', 'x']);
      expect(
        RecentSearchStore.push(List.generate(8, (i) => 'q$i'), 'new').length,
        RecentSearchStore.max,
      );
    });
  });
}
