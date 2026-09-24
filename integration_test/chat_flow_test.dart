import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/auth/auth_session.dart';
import 'package:xatbox_mobile/features/auth/login_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_list_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/conversation_screen.dart';

import '../test/helpers/chat_fixtures.dart';
import '../test/helpers/fake_http.dart';
import '../test/helpers/fixtures.dart';
import 'support/e2e_app.dart';

/// E2E: sign in → chat tab → open a chat → send text → voice button →
/// reply → forward. Backends are fakes; no microphone is used.
void main() {
  ensureE2EBinding();

  const conv = ChatFixtures.conv;
  const group = 'c0000000-0000-4000-8000-0000000000e2';

  testWidgets('sign in, open a chat, send, voice button, reply and forward', (tester) async {
    useRussian(tester);
    muteRecorderChannel();
    final e2e = await E2E.create(withCalls: false);
    addTearDown(e2e.h.dispose);
    final h = e2e.h;

    // Mail/Auth API.
    // A full staff user: with mail.send the mail tab shows its compose FAB next
    // to the chat FAB in the tab shell; opening a chat must not hit a hero-tag
    // clash (the chat FAB has its own heroTag).
    const permissions = ['mail.read', 'mail.send', 'chat.use'];
    h.adapter.onJson('POST', '/auth/login', Fixtures.loginResponse(permissions: permissions));
    h.stubSignedIn();
    h.adapter.onJson('GET', '/me', Fixtures.me(permissions: permissions));

    // Chat API: a direct chat with Bob and a group to forward into.
    final groupJson = ChatFixtures.conversation(
      id: group,
      title: 'Проектная группа',
      group: true,
      members: [
        ChatFixtures.member(ChatFixtures.me, 'Me', role: 'owner'),
        ChatFixtures.member(ChatFixtures.peer, 'Bob'),
      ],
    );
    h.chatAdapter.onJson(
      'GET',
      '/chats',
      ChatFixtures.chats([
        ChatFixtures.conversation(
          lastSeq: 2,
          unread: 1,
          lastMessage: ChatFixtures.message(id: 'm2', seq: 2, body: 'Когда встреча?'),
        ),
        groupJson,
      ]),
    );
    h.chatAdapter.onJson('GET', '/chats/$conv', ChatFixtures.conversation(lastSeq: 2));
    h.chatAdapter.onJson(
      'GET',
      '/chats/$conv/messages',
      ChatFixtures.messages([
        ChatFixtures.message(id: 'm1', seq: 1, body: 'Привет!', sender: ChatFixtures.me, status: 'read'),
        ChatFixtures.message(id: 'm2', seq: 2, body: 'Когда встреча?'),
      ]),
    );
    h.chatAdapter.onJson('GET', '/chats/$conv/events', ChatFixtures.events(const []));
    h.chatAdapter.onJson('GET', '/chats/$group', groupJson);
    h.chatAdapter.onJson('GET', '/chats/$group/messages', ChatFixtures.messages(const []));
    h.chatAdapter.onJson('GET', '/chats/$group/events', ChatFixtures.events(const []));

    var seq = 2;
    FakeResponse echo(RecordedRequest r, String convId) {
      seq++;
      return FakeResponse(
        201,
        json: {
          ...ChatFixtures.message(
            id: 'srv$seq',
            seq: seq,
            convId: convId,
            sender: ChatFixtures.me,
            body: r.json['body'] as String,
            clientId: r.json['client_message_id'] as String,
          ),
          'reply_to_id': ?r.json['reply_to_id'],
          'forward_of_id': ?r.json['forward_of_id'],
        },
      );
    }

    h.chatAdapter.on('POST', '/chats/$conv/messages', (r) => echo(r, conv));
    h.chatAdapter.on('POST', '/chats/$group/messages', (r) => echo(r, group));

    // 1. Sign in.
    await pumpE2EApp(tester, e2e);
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.enterText(find.byKey(const Key('login_email')), 'user@example.kz');
    await tester.enterText(find.byKey(const Key('login_password')), 'secret');
    await tester.tap(find.byKey(const Key('login_submit')));
    await settle(tester, 20);
    expect(h.adapter.of('POST', '/auth/login'), hasLength(1));
    expect(h.adapter.of('POST', '/auth/login').single.json['email'], 'user@example.kz');
    expect(h.session.status, AuthStatus.authenticated);
    expect(find.byType(LoginScreen), findsNothing);

    // 2. Chat tab → list.
    await openTab(tester, 'Чат');
    expect(find.byType(ChatListScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('chat_$conv')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat_$group')), findsOneWidget);

    // 3. Open the chat.
    await tester.tap(find.byKey(const ValueKey('chat_$conv')));
    await settle(tester, 16);
    expect(find.byType(ConversationScreen), findsOneWidget);
    expect(find.text('Когда встреча?'), findsOneWidget);

    // 4. Voice: the mic is shown for an empty composer; a tap (not a hold)
    // explains the gesture. Recording itself needs a microphone.
    expect(find.byKey(const Key('chat_mic')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat_mic')));
    await settle(tester, 4);
    expect(find.text('Удерживайте для записи'), findsWidgets);
    // Dismiss the hint snackbar: it covers the send button.
    ScaffoldMessenger.of(tester.element(find.byType(ConversationScreen))).removeCurrentSnackBar();
    await settle(tester, 6);
    expect(find.text('Удерживайте для записи'), findsNothing);

    // 5. Send a text.
    await tester.enterText(find.byKey(const Key('chat_input')), 'Сегодня в 15:00');
    await settle(tester, 4);
    await tester.tap(find.byKey(const Key('chat_send')));
    await settle(tester);
    final sent = h.chatAdapter.of('POST', '/chats/$conv/messages').single.json;
    expect(sent['body'], 'Сегодня в 15:00');
    expect(sent['client_message_id'], isNotEmpty);
    expect(find.text('Сегодня в 15:00'), findsOneWidget);

    // 6. Reply to Bob's message.
    await tester.longPress(find.text('Когда встреча?'));
    await settle(tester, 6);
    await tester.tap(find.text('Ответить'));
    await settle(tester, 6);
    expect(find.byKey(const Key('composer_context')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('chat_input')), 'Подходит');
    await settle(tester, 4);
    await tester.tap(find.byKey(const Key('chat_send')));
    await settle(tester);
    final reply = h.chatAdapter.of('POST', '/chats/$conv/messages').last.json;
    expect(reply['body'], 'Подходит');
    expect(reply['reply_to_id'], 'm2');
    expect(find.byKey(const Key('composer_context')), findsNothing);
    expect(find.text('Подходит'), findsOneWidget);

    // 7. Forward Bob's message into the group.
    await tester.longPress(find.text('Когда встреча?').first);
    await settle(tester, 6);
    await tester.tap(find.text('Переслать'));
    await settle(tester, 8);
    expect(find.text('Переслать в…'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('forward_pick_$group')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('forward_send')));
    await settle(tester);
    final forwarded = h.chatAdapter.of('POST', '/chats/$group/messages').single.json;
    expect(forwarded['forward_of_id'], 'm2');
    expect(find.text('Переслано'), findsWidgets);
    expect(tester.takeException(), isNull);

    await finishE2E(tester, e2e);
  });
}
