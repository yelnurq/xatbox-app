import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_list_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/conversation_screen.dart';

import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Widget tests for the chat list and the conversation screen against the
/// fake Chat API and a fake WebSocket the test drives as the server.
void main() {
  late TestHarness h;
  tearDown(() => h.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 8]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Real-async sign-in (widget tests run under FakeAsync, so the HTTP round
  /// trip must happen in runAsync); then the lifecycle provider starts the socket.
  /// Stops the socket (ping timer) and lets debounce timers expire before the
  /// framework checks for pending timers.
  Future<void> finish(WidgetTester tester) async {
    // Not awaited: under FakeAsync the microtasks complete during pump().
    unawaited(h.container.read(chatRepositoryProvider).stop());
    await tester.pump(const Duration(seconds: 10));
  }

  Future<void> signIn(WidgetTester tester) async {
    h.adapter.onJson('GET', '/me', Fixtures.me());
    await tester.runAsync(() => h.session.restore());
    h.container.read(chatLifecycleProvider);
  }

  testWidgets(
    'chat list shows conversations, unread badge and updates live on message.created',
    (tester) async {
      h = await TestHarness.create(
        storedToken: Fixtures.token,
        chatBaseUrl: 'http://chat.local/api/v1',
      );
      h.chatAdapter.onJson(
        'GET',
        '/chats',
        ChatFixtures.chats([
          ChatFixtures.conversation(
            unread: 2,
            lastMessage: ChatFixtures.message(
              id: 'm1',
              seq: 1,
              body: 'Привет!',
            ),
          ),
        ]),
      );
      h.chatAdapter.onJson(
        'GET',
        '/chats/${ChatFixtures.conv}',
        ChatFixtures.conversation(unread: 2),
      );
      h.chatAdapter.onJson(
        'GET',
        '/chats/${ChatFixtures.conv}/events',
        ChatFixtures.events(const []),
      );
      await signIn(tester);

      await tester.pumpWidget(
        wrapWidget(const ChatListScreen(), container: h.container),
      );
      await settle(tester);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Привет!'), findsOneWidget);
      expect(find.text('2'), findsOneWidget, reason: 'unread badge');
      expect(h.container.read(chatUnreadBadgeProvider), 2);
      // A closed row paints no swipe actions under it (a glass skin's
      // see-through tile would show them); a swipe uncovers them.
      expect(find.byKey(const ValueKey('swipe_pin_${ChatFixtures.conv}')), findsNothing);
      await tester.drag(find.text('Bob'), const Offset(-300, 0));
      await settle(tester);
      expect(find.byKey(const ValueKey('swipe_pin_${ChatFixtures.conv}')), findsOneWidget);
      await tester.tap(find.text('Bob'));
      await settle(tester);
      expect(find.byKey(const ValueKey('swipe_pin_${ChatFixtures.conv}')), findsNothing);

      // The fake server pushes a new message over the socket: list updates without polling.
      final listCalls = h.chatAdapter.of('GET', '/chats').length;
      final socket = h.socketFactory.last;
      expect(socket.sent.first['type'], 'auth');
      socket.serverSend({
        'type': 'message.created',
        'conversation_id': ChatFixtures.conv,
        'seq': 2,
        'message': ChatFixtures.message(
          id: 'm2',
          seq: 2,
          body: 'Новое сообщение',
        ),
      });
      await settle(tester);
      expect(find.text('Новое сообщение'), findsOneWidget);
      expect(find.text('3'), findsOneWidget, reason: 'unread incremented');
      expect(
        h.chatAdapter.of('GET', '/chats').length,
        listCalls,
        reason: 'no list refetch on live event',
      );
      // Delivered ack was sent back over the socket.
      expect(
        socket.sent.any(
          (f) =>
              f['type'] == 'ack.delivered' &&
              (f['message_ids'] as List).contains('m2'),
        ),
        isTrue,
      );
      await finish(tester);
    },
  );

  testWidgets(
    'conversation screen renders history, sends with a client id, shows pending then sent, marks read',
    (tester) async {
      h = await TestHarness.create(
        storedToken: Fixtures.token,
        chatBaseUrl: 'http://chat.local/api/v1',
      );
      h.chatAdapter.onJson(
        'GET',
        '/chats',
        ChatFixtures.chats([ChatFixtures.conversation(unread: 1, lastSeq: 2)]),
      );
      h.chatAdapter.onJson(
        'GET',
        '/chats/${ChatFixtures.conv}',
        ChatFixtures.conversation(unread: 1, lastSeq: 2),
      );
      h.chatAdapter.onJson(
        'GET',
        '/chats/${ChatFixtures.conv}/messages',
        ChatFixtures.messages([
          ChatFixtures.message(
            id: 'm1',
            seq: 1,
            body: 'Первое',
            sender: ChatFixtures.me,
            status: 'read',
          ),
          ChatFixtures.message(id: 'm2', seq: 2, body: 'Второе'),
        ]),
      );
      h.chatAdapter.onJson(
        'GET',
        '/chats/${ChatFixtures.conv}/events',
        ChatFixtures.events(const []),
      );
      h.chatAdapter.onJson('POST', '/messages/m2/read', null, status: 204);
      await signIn(tester);

      await tester.pumpWidget(
        wrapWidget(
          const ConversationScreen(conversationId: ChatFixtures.conv),
          container: h.container,
        ),
      );
      await settle(tester);
      expect(find.text('Первое'), findsOneWidget);
      expect(find.text('Второе'), findsOneWidget);
      expect(
        h.chatAdapter.of('POST', '/messages/m2/read'),
        hasLength(1),
        reason: 'opening marks the newest message read',
      );

      // Send: pending bubble first, then the server copy replaces it.
      h.chatAdapter.on('POST', '/chats/${ChatFixtures.conv}/messages', (r) {
        final cid = r.json['client_message_id'] as String;
        return FakeResponse(
          201,
          json: ChatFixtures.message(
            id: 'm3',
            seq: 3,
            body: r.json['body'] as String,
            sender: ChatFixtures.me,
            clientId: cid,
          ),
        );
      });
      await tester.enterText(find.byKey(const Key('chat_input')), 'Ответ');
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat_send')));
      await settle(tester);
      final sent = h.chatAdapter
          .of('POST', '/chats/${ChatFixtures.conv}/messages')
          .single
          .json;
      expect(sent['client_message_id'], isNotEmpty);
      expect(sent['body'], 'Ответ');
      expect(sent.keys.toSet(), {
        'client_message_id',
        'type',
        'body',
      }, reason: 'only documented fields');
      expect(find.text('Ответ'), findsOneWidget);
      expect(
        h.container.read(chatRepositoryProvider).cache.outbox(),
        completion(isEmpty),
      );

      // Peer reads it: status icon changes to read (done_all in brand colour).
      h.socketFactory.last.serverSend({
        'type': 'message.read',
        'conversation_id': ChatFixtures.conv,
        'seq': 4,
        'user_id': ChatFixtures.peer,
        'up_to_seq': 3,
      });
      await settle(tester);
      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == LucideIcons.checkCheck),
        findsWidgets,
      );

      // Typing indicator appears and disappears without touching the API.
      h.socketFactory.last.serverSend({
        'type': 'typing.started',
        'conversation_id': ChatFixtures.conv,
        'user_id': ChatFixtures.peer,
        'display_name': 'Bob',
      });
      await settle(tester);
      expect(find.textContaining('печатает'), findsOneWidget);
      h.socketFactory.last.serverSend({
        'type': 'typing.stopped',
        'conversation_id': ChatFixtures.conv,
        'user_id': ChatFixtures.peer,
      });
      await settle(tester);
      expect(find.textContaining('печатает'), findsNothing);
      await finish(tester);
    },
  );

  testWidgets(
    'offline send stays pending and is flushed after reconnect with the same id',
    (tester) async {
      h = await TestHarness.create(
        storedToken: Fixtures.token,
        chatBaseUrl: 'http://chat.local/api/v1',
      );
      h.chatAdapter.onJson(
        'GET',
        '/chats',
        ChatFixtures.chats([ChatFixtures.conversation()]),
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
      h.chatAdapter.onOffline('POST', '/chats/${ChatFixtures.conv}/messages');
      await signIn(tester);

      await tester.pumpWidget(
        wrapWidget(
          const ConversationScreen(conversationId: ChatFixtures.conv),
          container: h.container,
        ),
      );
      await settle(tester);
      await tester.enterText(find.byKey(const Key('chat_input')), 'офлайн');
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat_send')));
      await settle(tester);
      expect(find.text('офлайн'), findsOneWidget);
      expect(
        find.byIcon(LucideIcons.clock),
        findsOneWidget,
        reason: 'pending status',
      );
      final firstId = h.chatAdapter
          .of('POST', '/chats/${ChatFixtures.conv}/messages')
          .single
          .json['client_message_id'];

      // Network is back; the socket reconnect triggers a flush with the same id.
      h.chatAdapter.on(
        'POST',
        '/chats/${ChatFixtures.conv}/messages',
        (r) => FakeResponse(
          201,
          json: ChatFixtures.message(
            id: 'm9',
            seq: 1,
            body: 'офлайн',
            sender: ChatFixtures.me,
            clientId: r.json['client_message_id'] as String,
          ),
        ),
      );
      h.socketFactory.last.serverClose(1001);
      await settle(tester, 30);
      final calls = h.chatAdapter.of(
        'POST',
        '/chats/${ChatFixtures.conv}/messages',
      );
      expect(calls.length, greaterThanOrEqualTo(2));
      expect(calls.last.json['client_message_id'], firstId);
      expect(find.byIcon(LucideIcons.clock), findsNothing);
      expect(
        find.text('офлайн'),
        findsOneWidget,
        reason: 'no duplicate bubble',
      );
      await finish(tester);
    },
  );
}
