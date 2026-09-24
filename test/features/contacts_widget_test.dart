import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/features/calls/presentation/call_screen.dart';
import 'package:xatbox_mobile/features/calls/presentation/calls_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/conversation_screen.dart';
import 'package:xatbox_mobile/features/contacts/data/contact_models.dart';
import 'package:xatbox_mobile/features/contacts/presentation/contact_profile_screen.dart';
import 'package:xatbox_mobile/features/contacts/presentation/contacts_providers.dart';
import 'package:xatbox_mobile/features/contacts/presentation/contacts_screen.dart';

import '../helpers/call_fakes.dart';
import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Contacts tab through the real app: directory → profile → «Написать» opens
/// the direct chat; call buttons follow the calls flag; offline cache banner;
/// favourites, filters, grouping, fast scroll and the profile cards.
void main() {
  late TestHarness h;
  tearDown(() => h.dispose());

  const self = '11111111-1111-4111-8111-111111111111';
  final directory = [
    ChatFixtures.user(name: 'Болат Сейтов', online: true),
    {
      ...ChatFixtures.user(id: 'u-alia', name: 'Алия Нурланова'),
      'department_id': 'd1',
      'department_name': 'Бухгалтерия',
    },
    ChatFixtures.user(id: 'u-anna', name: 'Anna Smith'),
    ChatFixtures.user(id: self, name: 'Тест Пользователь'),
  ];

  Future<void> settle(WidgetTester tester, [int steps = 12]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> finish(WidgetTester tester) async {
    unawaited(h.container.read(callControllerProvider.notifier).hangUp());
    await tester.pump(const Duration(seconds: 1));
    unawaited(h.container.read(chatRepositoryProvider).stop());
    await tester.pump(const Duration(seconds: 10));
  }

  void useRussian(WidgetTester tester) {
    tester.platformDispatcher.localeTestValue = const Locale('ru');
    tester.platformDispatcher.localesTestValue = const [Locale('ru')];
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }

  /// A 360×800 phone: any RenderFlex overflow fails the test.
  void usePhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  void stubDirectory([List<Map<String, dynamic>>? users]) {
    h.chatAdapter.on('GET', '/users', (r) {
      final q = ((r.query['q'] as String?) ?? '').toLowerCase();
      final found = (users ?? directory)
          .where((u) => (u['display_name'] as String).toLowerCase().contains(q))
          .toList();
      return FakeResponse(200, json: {'users': found});
    });
  }

  Future<void> signedInWidgetHarness(WidgetTester tester) async {
    h = await TestHarness.create(
      storedToken: Fixtures.token,
      chatBaseUrl: 'http://chat.local/api/v1',
    );
    h.adapter.onJson('GET', '/me', Fixtures.me());
    await tester.runAsync(() => h.session.restore());
  }

  testWidgets(
    'directory with sections and search → profile → «Написать» opens the direct chat',
    (tester) async {
      useRussian(tester);
      final native = FakeCallNative();
      h = await TestHarness.create(
        storedToken: Fixtures.token,
        chatBaseUrl: 'http://chat.local/api/v1',
        callsBaseUrl: 'http://calls.local/api/v1',
        overrides: [
          callNativeProvider.overrideWithValue(native),
          callMediaFactoryProvider.overrideWithValue(FakeCallMedia.new),
        ],
      );
      h.stubSignedIn();
      h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats(const []));
      h.chatAdapter.onPattern(
        'POST',
        r'^/push/devices$',
        (_) => const FakeResponse(204),
      );
      FakeCallServer(h.callsAdapter, selfId: self, selfName: 'Тест Пользователь');
      stubDirectory();

      await tester.runAsync(() => h.session.restore());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const XatBoxApp(),
        ),
      );
      await settle(tester);

      await tester.tap(find.byKey(const Key('tab_more')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('more_contacts')));
      await settle(tester);
      expect(find.byType(ContactsScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('contacts_section_А')), findsOneWidget);
      expect(find.byKey(const ValueKey('contacts_section_Б')), findsOneWidget);
      expect(find.byKey(const ValueKey('contacts_section_A')), findsOneWidget);
      expect(find.text('Болат Сейтов'), findsOneWidget);
      expect(find.text('Тест Пользователь'), findsNothing, reason: 'self hidden');
      expect(find.byKey(const Key('contact_online_dot')), findsOneWidget);
      expect(find.text('Бухгалтерия'), findsOneWidget, reason: 'department');
      expect(h.chatAdapter.of('GET', '/users').first.query, {'limit': '1000'});

      // Debounced search: one request after typing stops.
      final before = h.chatAdapter.of('GET', '/users').length;
      await tester.enterText(find.byKey(const Key('contacts_search')), 'бол');
      await tester.pump(const Duration(milliseconds: 100));
      expect(h.chatAdapter.of('GET', '/users').length, before);
      await settle(tester);
      expect(h.chatAdapter.of('GET', '/users').length, before + 1);
      expect(h.chatAdapter.of('GET', '/users').last.query['q'], 'бол');
      expect(find.text('Алия Нурланова'), findsNothing);
      expect(find.text('Болат Сейтов'), findsOneWidget);
      final highlighted = tester.widget<Text>(find.text('Болат Сейтов'));
      expect(
        highlighted.textSpan,
        isNotNull,
        reason: 'the match is highlighted',
      );

      await tester.tap(find.byKey(const ValueKey('contact_${ChatFixtures.peer}')));
      await settle(tester);
      expect(find.byType(ContactProfileScreen), findsOneWidget);
      expect(find.byKey(const Key('contact_profile_name')), findsOneWidget);
      expect(find.byKey(const Key('contact_audio_call')), findsOneWidget);
      expect(find.byKey(const Key('contact_video_call')), findsOneWidget);
      expect(find.byKey(const Key('contact_write_email')), findsOneWidget);

      h.chatAdapter.on(
        'POST',
        '/chats',
        (_) => FakeResponse(201, json: ChatFixtures.conversation()),
      );
      h.chatAdapter.onJson(
        'GET',
        '/chats/${ChatFixtures.conv}',
        ChatFixtures.conversation(),
      );
      h.chatAdapter.onJson(
        'GET',
        '/chats/${ChatFixtures.conv}/messages',
        ChatFixtures.messages(const []),
      );
      h.chatAdapter.onJson(
        'GET',
        '/chats/${ChatFixtures.conv}/events',
        ChatFixtures.events(const []),
      );
      await tester.tap(find.byKey(const Key('contact_write')));
      await settle(tester);
      expect(find.byType(ConversationScreen), findsOneWidget);
      expect(h.chatAdapter.of('POST', '/chats').single.json, {
        'type': 'direct',
        'user_id': ChatFixtures.peer,
      });

      // Back to the profile and start an audio call.
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.byType(ContactProfileScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('contact_audio_call')));
      await settle(tester, 20);
      expect(find.byType(CallScreen), findsOneWidget);
      final create = h.callsAdapter.of('POST', '/calls').single.json;
      expect(create['callee_ids'], [ChatFixtures.peer]);
      expect(create['type'], 'audio');
      await finish(tester);
    },
  );

  const bob = Contact(
    id: ChatFixtures.peer,
    email: 'bob@example.kz',
    displayName: 'Bob',
  );

  testWidgets('call buttons are hidden when calls are disabled', (tester) async {
    h = await TestHarness.create(
      storedToken: Fixtures.token,
      chatBaseUrl: 'http://chat.local/api/v1',
    );
    expect(h.container.read(callsEnabledProvider), isFalse);
    await tester.pumpWidget(
      wrapWidget(
        const ContactProfileScreen(userId: ChatFixtures.peer, initial: bob),
        container: h.container,
      ),
    );
    await settle(tester);
    expect(find.text('Bob'), findsWidgets);
    expect(find.byKey(const Key('contact_write')), findsOneWidget);
    expect(find.byKey(const Key('contact_audio_call')), findsNothing);
    expect(find.byKey(const Key('contact_video_call')), findsNothing);
  });

  testWidgets('call buttons are shown when calls are enabled', (tester) async {
    h = await TestHarness.create(
      storedToken: Fixtures.token,
      chatBaseUrl: 'http://chat.local/api/v1',
      callsBaseUrl: 'http://calls.local/api/v1',
    );
    await tester.pumpWidget(
      wrapWidget(
        const ContactProfileScreen(userId: ChatFixtures.peer, initial: bob),
        container: h.container,
      ),
    );
    await settle(tester);
    expect(find.byKey(const Key('contact_audio_call')), findsOneWidget);
    expect(find.byKey(const Key('contact_video_call')), findsOneWidget);
  });

  testWidgets('phone «Мои»: a personal contact is added and listed', (tester) async {
    useRussian(tester);
    h = await TestHarness.create(storedToken: Fixtures.token, chatBaseUrl: 'http://chat.local/api/v1');
    h.stubSignedIn();
    stubDirectory();
    await tester.runAsync(() => h.session.restore());
    await tester.pumpWidget(wrapWidget(const ContactsScreen(), container: h.container));
    await settle(tester);

    await tester.ensureVisible(find.byKey(const Key('contacts_filter_mine')));
    await tester.tap(find.byKey(const Key('contacts_filter_mine')));
    await settle(tester);
    expect(find.byKey(const Key('contacts_mine_list')), findsOneWidget);
    await tester.tap(find.byKey(const Key('contacts_mine_add')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('personal_name')), 'Айгерим Садыкова');
    await tester.enterText(find.byKey(const Key('personal_email')), 'aigerim@example.kz');
    await tester.tap(find.byKey(const Key('personal_save')));
    await settle(tester);
    expect(find.text('Айгерим Садыкова'), findsOneWidget);
  });

  testWidgets('chat disabled: explanatory empty state, no request', (tester) async {
    h = await TestHarness.create(storedToken: Fixtures.token);
    await tester.pumpWidget(
      wrapWidget(const ContactsScreen(), container: h.container),
    );
    await tester.pump();
    expect(
      find.text(
        'Справочник сотрудников работает через сервис чата, а он не настроен в этой сборке.',
      ),
      findsOneWidget,
    );
    expect(h.chatAdapter.requests, isEmpty);
  });

  testWidgets('offline: cached directory with a banner', (tester) async {
    h = await TestHarness.create(
      storedToken: Fixtures.token,
      chatBaseUrl: 'http://chat.local/api/v1',
    );
    h.adapter.onJson('GET', '/me', Fixtures.me());
    await tester.runAsync(() async {
      await h.session.restore();
      await h.container
          .read(contactsCacheProvider)
          .write(
            ownerId: self,
            contacts: [Contact.fromJson(directory[1]), bob],
            savedAt: DateTime.utc(2026, 9, 14),
          );
    });
    h.chatAdapter.onOffline('GET', '/users');

    await tester.pumpWidget(
      wrapWidget(const ContactsScreen(), container: h.container),
    );
    await settle(tester);
    expect(find.byKey(const Key('contacts_offline_banner')), findsOneWidget);
    expect(find.text('Нет сети — показаны сохранённые данные'), findsOneWidget);
    expect(find.text('Алия Нурланова'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets(
    'favourites on top, online filter, department grouping, no results (360px)',
    (tester) async {
      usePhone(tester);
      await signedInWidgetHarness(tester);
      await tester.runAsync(
        () => h.container
            .read(contactsFavouritesStoreProvider)
            .write(ownerId: self, contacts: [Contact.fromJson(directory[2])]),
      );
      stubDirectory();

      await tester.pumpWidget(
        wrapWidget(const ContactsScreen(), container: h.container),
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('contacts_special_star')), findsOneWidget);
      expect(find.byKey(const ValueKey('contact_fav_u-anna')), findsOneWidget);
      expect(find.byKey(const ValueKey('contact_u-anna')), findsOneWidget);

      await tester.tap(find.byKey(const Key('contacts_filter_online')));
      await settle(tester, 4);
      expect(find.text('Болат Сейтов'), findsOneWidget);
      expect(find.text('Алия Нурланова'), findsNothing);
      expect(find.byKey(const ValueKey('contacts_special_star')), findsNothing);

      await tester.tap(find.byKey(const Key('contacts_filter_favourites')));
      await settle(tester, 4);
      expect(find.text('Anna Smith'), findsOneWidget);
      expect(find.text('Болат Сейтов'), findsNothing);

      await tester.tap(find.byKey(const Key('contacts_filter_all')));
      await tester.tap(find.byKey(const Key('contacts_group_toggle')));
      await settle(tester, 4);
      expect(
        find.byKey(const ValueKey('contacts_section_Бухгалтерия')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('contacts_section_Без отдела')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('contacts_alphabet_index')), findsNothing);

      await tester.enterText(find.byKey(const Key('contacts_search')), 'zzz');
      await settle(tester);
      expect(find.byKey(const Key('contacts_no_results')), findsOneWidget);
      expect(find.text('Никого не нашлось'), findsOneWidget);
    },
  );

  testWidgets('alphabet index jumps; the sticky header follows', (tester) async {
    usePhone(tester);
    await signedInWidgetHarness(tester);
    const letters = 'АБВГДЕЖЗИКЛМНОПРСТУ';
    stubDirectory([
      for (final l in letters.split(''))
        for (var k = 0; k < 3; k++)
          ChatFixtures.user(id: 'u-$l$k', name: '$lстер $k'),
    ]);

    await tester.pumpWidget(
      wrapWidget(const ContactsScreen(), container: h.container),
    );
    await settle(tester);
    expect(find.byKey(const Key('contacts_sticky_header')), findsNothing);
    final index = find.byKey(const Key('contacts_alphabet_index'));
    expect(index, findsOneWidget);

    await tester.tapAt(tester.getBottomLeft(index) + const Offset(12, -2));
    await tester.pump();
    final position = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const Key('contacts_list')),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    expect(position.pixels, greaterThan(0));
    await tester.pump();
    expect(find.byKey(const Key('contacts_sticky_header')), findsOneWidget);
    expect(find.text('Устер 2'), findsOneWidget);
  });

  testWidgets(
    'profile: presence, department card with manager, colleagues, copy, favourite (360px)',
    (tester) async {
      usePhone(tester);
      await signedInWidgetHarness(tester);
      final alia = {
        ...ChatFixtures.user(id: 'u-alia', name: 'Алия Нурланова'),
        'department_id': 'd1',
        'department_name': 'Бухгалтерия',
        'mailbox_address': 'a.nurlanova@example.kz',
        'last_seen_at': DateTime.now()
            .toUtc()
            .subtract(const Duration(minutes: 5, seconds: 10))
            .toIso8601String(),
      };
      h.chatAdapter.onPattern(
        'GET',
        r'^/users/[^/]+$',
        (_) => FakeResponse(200, json: {'user': alia}),
      );
      h.chatAdapter.onJson('GET', '/departments', {
        'departments': [
          {
            'id': 'd1',
            'name': 'Бухгалтерия',
            'description': 'Учёт и отчётность',
            'manager_user_id': 'u-erzhan',
            'manager_name': 'Ержан Ахметов',
            'manager_email': 'erzhan@example.kz',
            'employee_count': 7,
            'status': 'active',
          },
        ],
      });
      h.chatAdapter.on(
        'GET',
        '/users',
        (_) => FakeResponse(
          200,
          json: {
            'users': [
              alia,
              {
                ...ChatFixtures.user(id: 'u-erzhan', name: 'Ержан Ахметов', online: true),
                'department_id': 'd1',
              },
            ],
            'limit': 1000,
          },
        ),
      );
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        wrapWidget(
          const ContactProfileScreen(userId: 'u-alia'),
          container: h.container,
        ),
      );
      await settle(tester);
      expect(find.byKey(const Key('contact_profile_name')), findsOneWidget);
      expect(find.text('был(а) 5 мин назад'), findsOneWidget);
      expect(find.byKey(const Key('contact_department_chip')), findsOneWidget);

      await tester.tap(find.byKey(const Key('contact_mailbox_row')));
      await tester.pump();
      expect(clipboard, 'a.nurlanova@example.kz');
      expect(find.text('Скопировано: a.nurlanova@example.kz'), findsOneWidget);

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.byKey(const Key('contact_department_manager')),
        200,
        scrollable: scrollable,
      );
      expect(find.text('Ержан Ахметов'), findsOneWidget);
      expect(find.text('7 сотрудников'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('contact_colleague_u-erzhan')),
        200,
        scrollable: scrollable,
      );
      expect(
        h.chatAdapter.of('GET', '/users').single.query['department_id'],
        'd1',
      );

      await tester.tap(find.byKey(const Key('contact_favourite')));
      await settle(tester, 4);
      expect(h.container.read(contactsFavouriteIdsProvider), {'u-alia'});
    },
  );
}
