import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/platform/desktop.dart';
import 'package:xatbox_mobile/core/platform/desktop_layout.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/features/chat/data/chat_models.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_composer.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/requests/request_widgets.dart';

import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// «Заявки» (chat-service migration 0016): the desktop app lists the chat,
/// files requests through the form and shows the service's answers; the
/// phone app does not ask for the chat at all.
void main() {
  const requestsConv = 'c0000000-0000-4000-8000-0000000000aa';
  const bot = '99999999-9999-4999-8999-999999999999';
  const requestId = 'r0000000-0000-4000-8000-000000000001';

  Map<String, dynamic> request({String status = 'new', String comment = '', String updatedAt = '2026-09-22T08:00:00Z'}) => {
    'id': requestId,
    'number': 42,
    'what': 'Не работает проектор',
    'room': '305',
    'date': '2026-09-22',
    'status': status,
    'comment': comment,
    'updated_at': updatedAt,
  };

  Map<String, dynamic> requestsChat() => {
    ...ChatFixtures.conversation(id: requestsConv, title: 'Заявки', lastSeq: 3),
    'type': 'requests',
    'member_count': 1,
    'peer': null,
  };

  group('model', () {
    test('a request message keeps its request through the cache', () {
      final m = ChatMessage.fromJson({
        ...ChatFixtures.message(id: 'q1', seq: 1, type: 'request', sender: ChatFixtures.me, convId: requestsConv),
        'request': request(),
      });
      expect(m.isRequest, isTrue);
      expect(m.request!.number, 42);
      expect(m.request!.dateLabel, '22.09.2026');
      final again = ChatMessage.fromJson(jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>);
      expect(again.request!.what, 'Не работает проектор');
      expect(again.request!.status, 'new');
      expect(ChatConversation.fromJson(requestsChat()).isRequests, isTrue);
    });

    test('the newest answer decides the status', () {
      ChatMessage msg(String id, int seq, Map<String, dynamic> r) => ChatMessage.fromJson({
        ...ChatFixtures.message(id: id, seq: seq, type: 'request_update', sender: bot, convId: requestsConv),
        'request': r,
      });
      final latest = latestRequests([
        msg('a', 2, request(status: 'in_progress', updatedAt: '2026-09-22T09:00:00Z')),
        msg('b', 3, request(status: 'done', updatedAt: '2026-09-22T10:00:00Z')),
        msg('c', 1, request()),
      ]);
      expect(latest[requestId]!.status, 'done');
    });
  });

  Future<void> settle(WidgetTester tester, [int steps = 12]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<TestHarness> launch(WidgetTester tester, {required bool desktop}) async {
    if (desktop) {
      debugDesktopOverride = true;
      addTearDown(() => debugDesktopOverride = null);
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    tester.platformDispatcher.localeTestValue = const Locale('ru');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final h = await TestHarness.create(
      storedToken: Fixtures.token,
      chatBaseUrl: 'http://chat.local/api/v1',
      overrides: [if (desktop) desktopLayoutProvider.overrideWithValue(true)],
    );
    addTearDown(h.dispose);
    h.stubSignedIn(messages: Fixtures.messages(3), total: 3);
    final other = ChatFixtures.conversation(title: 'Болат', lastSeq: 1);
    h.chatAdapter.onPattern('GET', r'^/chats$', (req) {
      final withRequests = req.query['with_requests'] == '1';
      return FakeResponse(200, json: ChatFixtures.chats([if (withRequests) requestsChat(), other]));
    });
    h.chatAdapter.onJson('GET', '/chats/$requestsConv', requestsChat());
    h.chatAdapter.onJson('GET', '/chats/${ChatFixtures.conv}', other);
    h.chatAdapter.onJson(
      'GET',
      '/chats/$requestsConv/messages',
      ChatFixtures.messages([
        {
          ...ChatFixtures.message(id: 'q1', seq: 1, type: 'request', sender: ChatFixtures.me, convId: requestsConv,
              body: 'Заявка №42\nЧто случилось: Не работает проектор\nКабинет: 305\nДата: 22.09.2026'),
          'request': request(),
        },
        {
          ...ChatFixtures.message(id: 'q2', seq: 2, type: 'request_update', sender: bot, convId: requestsConv,
              body: 'Заявка №42\nЗаявка принята и передана в работу. Ответ придёт в этот чат.'),
          'request': request(),
        },
        {
          ...ChatFixtures.message(id: 'q3', seq: 3, type: 'request_update', sender: bot, convId: requestsConv,
              body: 'Заявка №42: В работе\nМастер придёт до 15:00.'),
          'request': request(status: 'in_progress', comment: 'Мастер придёт до 15:00.', updatedAt: '2026-09-22T09:00:00Z'),
        },
      ]),
    );
    h.chatAdapter.onJson('GET', '/chats/${ChatFixtures.conv}/messages', ChatFixtures.messages(const []));
    h.chatAdapter.onPattern('POST', r'^/messages/[^/]+/read$', (_) => const FakeResponse(204));
    h.chatAdapter.onPattern('POST', r'^/push/devices$', (_) => const FakeResponse(204));
    h.chatAdapter.onPattern(
      'POST',
      r'^/requests$',
      (req) => FakeResponse(201, json: {
        ...ChatFixtures.message(id: 'q4', seq: 4, type: 'request', sender: ChatFixtures.me, convId: requestsConv,
            body: 'Заявка №43'),
        'request': {...request(), 'id': 'r0000000-0000-4000-8000-000000000002', 'number': 43},
      }),
    );
    h.adapter.onJson('GET', '/me/sessions', {'sessions': <Object>[]});
    await tester.pumpWidget(UncontrolledProviderScope(container: h.container, child: const XatBoxApp()));
    await settle(tester);
    h.container.read(appRouterProvider).go(Routes.chat);
    await settle(tester, 20);
    return h;
  }

  Future<void> finish(WidgetTester tester, TestHarness h) async {
    unawaited(h.container.read(chatRepositoryProvider).stop());
    await tester.pump(const Duration(seconds: 10));
  }

  testWidgets('desktop: «Заявки» opens with the form instead of the composer', (tester) async {
    final h = await launch(tester, desktop: true);
    expect(h.chatAdapter.of('GET', '/chats').first.query['with_requests'], '1');
    expect(find.text('Заявки'), findsWidgets);

    h.container.read(chatSelectedConversationProvider.notifier).select(requestsConv);
    await settle(tester, 20);
    expect(find.byKey(const Key('request_form')), findsOneWidget);
    expect(find.byType(ChatComposer), findsNothing);
    expect(find.byKey(const Key('chat_audio_call')), findsNothing);
    expect(find.byKey(const Key('chat_info_toggle')), findsNothing);
    // The card of the filed request shows the status of the newest answer.
    final card = find.byKey(const ValueKey('request_card_$requestId'));
    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: find.byKey(const ValueKey('request_status_in_progress'))), findsOneWidget);
    expect(find.text('Мастер придёт до 15:00.'), findsOneWidget);

    // Empty fields: nothing is sent.
    await tester.tap(find.byKey(const Key('request_submit')));
    await settle(tester);
    expect(h.chatAdapter.of('POST', '/requests'), isEmpty);

    await tester.enterText(find.byKey(const Key('request_what')), '  Нет интернета  ');
    await tester.enterText(find.byKey(const Key('request_room')), '214');
    await tester.tap(find.byKey(const Key('request_submit')));
    await settle(tester);
    final sent = h.chatAdapter.of('POST', '/requests');
    expect(sent, hasLength(1));
    final body = sent.single.json;
    expect(body['what'], 'Нет интернета');
    expect(body['room'], '214');
    expect(body['date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect((body['client_message_id'] as String).isNotEmpty, isTrue);
    // The form is cleared for the next request.
    expect(tester.widget<TextField>(find.byKey(const Key('request_room'))).controller!.text, isEmpty);
    await finish(tester, h);
  });

  testWidgets('phone: «Заявки» is listed and opens with the form', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final h = await launch(tester, desktop: false);
    final lists = h.chatAdapter.of('GET', '/chats');
    expect(lists, isNotEmpty);
    expect(lists.every((r) => r.query['with_requests'] == '1'), isTrue);
    expect(find.text('Заявки'), findsWidgets);
    h.container.read(appRouterProvider).push(Routes.chatConversationPath(requestsConv));
    await settle(tester, 20);
    expect(find.byKey(const Key('request_form')), findsOneWidget);
    expect(find.byType(ChatComposer), findsNothing);
    // The narrow layout: room and date side by side, the button below.
    final room = tester.getRect(find.byKey(const Key('request_room')));
    final submit = tester.getRect(find.byKey(const Key('request_submit')));
    expect(submit.top, greaterThan(room.bottom));
    await finish(tester, h);
  });
}
