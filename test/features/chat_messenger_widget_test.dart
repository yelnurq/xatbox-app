import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/features/chat/data/chat_cache.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_list_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/conversation_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/message_bubble.dart';

import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Messenger UX: drafts in the list, jump to a replied message with a
/// highlight, tappable links, list filters, and 360 px layouts without
/// overflow.
void main() {
  late TestHarness h;
  final openedLinks = <Uri>[];
  const conv = ChatFixtures.conv;
  const group = 'c0000000-0000-4000-8000-000000000003';

  tearDown(() => h.dispose());

  Future<void> prepare({List<Override> extra = const []}) async {
    final tmp = Directory.systemTemp.createTempSync('xatbox_messenger');
    addTearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } on FileSystemException {
        // the OS cleans temp later
      }
    });
    const recordChannel = MethodChannel('com.llfbandit.record/messages');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(recordChannel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(recordChannel, null));
    openedLinks.clear();
    h = await TestHarness.create(
      storedToken: Fixtures.token,
      chatBaseUrl: 'http://chat.local/api/v1',
      overrides: [
        chatMediaRootProvider.overrideWithValue(() async => tmp),
        chatLinkOpenerProvider.overrideWithValue((uri) async {
          openedLinks.add(uri);
          return true;
        }),
        ...extra,
      ],
    );
    h.adapter.onJson('GET', '/me', Fixtures.me());
    h.chatAdapter.onPattern(
      'POST',
      r'^/messages/[^/]+/read$',
      (_) => const FakeResponse(204),
    );
  }

  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> signIn(WidgetTester tester) =>
      tester.runAsync(() => h.session.restore());

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  }

  void useSize(WidgetTester tester, Size logical) {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = logical * 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('a stored draft is shown in the list tile; typing saves a draft', (
    tester,
  ) async {
    await prepare();
    h.chatAdapter.onJson(
      'GET',
      '/chats',
      ChatFixtures.chats([
        ChatFixtures.conversation(
          lastMessage: ChatFixtures.message(id: 'm1', seq: 1, body: 'Привет!'),
        ),
      ]),
    );
    h.chatAdapter.onJson('GET', '/chats/$conv', ChatFixtures.conversation());
    h.chatAdapter.onJson(
      'GET',
      '/chats/$conv/messages',
      ChatFixtures.messages([ChatFixtures.message(id: 'm1', seq: 1, body: 'Привет!')]),
    );
    await signIn(tester);
    await tester.runAsync(
      () => ChatCache(h.db).setDraft(conv, 'Завтра созвон в 10'),
    );

    await tester.pumpWidget(
      wrapWidget(const ChatListScreen(), container: h.container),
    );
    await settle(tester);
    final draft = find.byKey(const ValueKey('chat_draft_$conv'));
    expect(draft, findsOneWidget);
    expect(
      (tester.widget<Text>(draft).textSpan! as TextSpan).toPlainText(),
      'Черновик: Завтра созвон в 10',
    );
    expect(find.text('Привет!'), findsNothing, reason: 'the draft replaces the preview');

    // The conversation restores the draft into the composer and saves edits.
    await tester.pumpWidget(
      wrapWidget(
        const ConversationScreen(conversationId: conv),
        container: h.container,
      ),
    );
    await settle(tester);
    final input = tester.widget<TextField>(find.byKey(const Key('chat_input')));
    expect(input.controller!.text, 'Завтра созвон в 10');
    await tester.enterText(find.byKey(const Key('chat_input')), 'Новый черновик');
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester, 4);
    expect(h.container.read(chatDraftsProvider)[conv], 'Новый черновик');
    expect(
      await tester.runAsync(() => ChatCache(h.db).draft(conv)),
      'Новый черновик',
    );
    await finish(tester);
  });

  testWidgets(
    'tap on a quoted message loads older history, scrolls to it and flashes it',
    (tester) async {
      await prepare();
      final latest = [
        for (var s = 151; s <= 200; s++)
          ChatFixtures.message(id: 'm$s', seq: s, body: 'Сообщение $s'),
      ];
      latest.last['reply_to_id'] = 'm100';
      latest.last['reply_to'] = {
        'id': 'm100',
        'sender_id': ChatFixtures.peer,
        'type': 'text',
        'body': 'Сообщение 100',
        'deleted': false,
      };
      h.chatAdapter.onJson(
        'GET',
        '/chats/$conv',
        ChatFixtures.conversation(lastSeq: 200),
      );
      h.chatAdapter.on('GET', '/chats/$conv/messages', (r) {
        final before = r.query['before_seq'];
        if (before == null) {
          return FakeResponse(200, json: ChatFixtures.messages(latest));
        }
        final b = int.parse('$before');
        final limit = int.parse('${r.query['limit']}');
        return FakeResponse(
          200,
          json: ChatFixtures.messages([
            for (var s = (b - limit).clamp(1, b); s < b; s++)
              ChatFixtures.message(id: 'm$s', seq: s, body: 'Сообщение $s'),
          ]),
        );
      });
      h.chatAdapter.onJson(
        'GET',
        '/messages/m100',
        ChatFixtures.message(id: 'm100', seq: 100, body: 'Сообщение 100'),
      );
      await signIn(tester);
      await tester.pumpWidget(
        wrapWidget(
          const ConversationScreen(conversationId: conv),
          container: h.container,
        ),
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('c:cid-m100')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('reply_preview_m100')));
      await settle(tester, 30);
      expect(h.chatAdapter.of('GET', '/messages/m100'), hasLength(1));
      final page = h.chatAdapter
          .of('GET', '/chats/$conv/messages')
          .where((r) => r.query['before_seq'] != null)
          .first;
      expect(page.query['before_seq'], '151');
      final row = find.byKey(const ValueKey('c:cid-m100'));
      expect(row, findsOneWidget, reason: 'the replied message is built (scrolled into view)');
      final bubble = tester.widget<MessageBubble>(
        find.descendant(of: row, matching: find.byType(MessageBubble)),
      );
      expect(bubble.highlighted, isTrue);
      await tester.pump(const Duration(seconds: 2));
      expect(
        tester
            .widget<MessageBubble>(
              find.descendant(of: row, matching: find.byType(MessageBubble)),
            )
            .highlighted,
        isFalse,
        reason: 'the flash ends',
      );
      await finish(tester);
    },
  );

  testWidgets('links in a message are tappable; emoji-only is large', (
    tester,
  ) async {
    await prepare();
    h.chatAdapter.onJson('GET', '/chats/$conv', ChatFixtures.conversation());
    h.chatAdapter.onJson(
      'GET',
      '/chats/$conv/messages',
      ChatFixtures.messages([
        ChatFixtures.message(id: 'm1', seq: 1, body: 'Док: https://xatbox.kz/doc.'),
        ChatFixtures.message(id: 'm2', seq: 2, body: '👍'),
      ]),
    );
    await signIn(tester);
    await tester.pumpWidget(
      wrapWidget(
        const ConversationScreen(conversationId: conv),
        container: h.container,
      ),
    );
    await settle(tester);
    final text = tester.widget<Text>(find.byKey(const ValueKey('link_text_m1')));
    final link = (text.textSpan! as TextSpan).children!
        .cast<TextSpan>()
        .firstWhere((s) => s.recognizer != null);
    expect(link.text, 'https://xatbox.kz/doc');
    (link.recognizer! as TapGestureRecognizer).onTap!();
    await tester.pump();
    expect(openedLinks.single.toString(), 'https://xatbox.kz/doc');
    expect(find.byKey(const ValueKey('emoji_only_m2')), findsOneWidget);
    await finish(tester);
  });

  testWidgets('filters: unread and groups', (tester) async {
    await prepare();
    h.chatAdapter.onJson(
      'GET',
      '/chats',
      ChatFixtures.chats([
        ChatFixtures.conversation(title: 'Bob', unread: 2),
        ChatFixtures.conversation(
          id: group,
          title: 'Проектная группа',
          group: true,
          members: [
            ChatFixtures.member(ChatFixtures.me, 'Me', role: 'owner'),
            ChatFixtures.member(ChatFixtures.peer, 'Bob'),
          ],
        ),
      ]),
    );
    await signIn(tester);
    await tester.pumpWidget(
      wrapWidget(const ChatListScreen(), container: h.container),
    );
    await settle(tester);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Проектная группа'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chat_filter_groups')));
    await tester.pump();
    expect(find.text('Bob'), findsNothing);
    expect(find.text('Проектная группа'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chat_filter_unread')));
    await tester.pump();
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Проектная группа'), findsNothing);
    expect(find.byKey(const ValueKey('chat_unread_$conv')), findsOneWidget);
    await finish(tester);
  });

  testWidgets('360 px: list and a busy group conversation lay out without overflow', (
    tester,
  ) async {
    useSize(tester, const Size(360, 740));
    await prepare();
    final longName = 'Александра Константиновна Преображенская-Длинная';
    final members = [
      ChatFixtures.member(ChatFixtures.me, 'Me', role: 'owner'),
      ChatFixtures.member(ChatFixtures.peer, longName),
      ChatFixtures.member(ChatFixtures.carol, 'Карина Ахметова'),
    ];
    final groupJson = ChatFixtures.conversation(
      id: group,
      title: 'Очень длинное название рабочей группы для проверки переполнения',
      group: true,
      unread: 1234,
      members: members,
      lastSeq: 6,
      lastMessage: ChatFixtures.message(
        id: 'g6',
        seq: 6,
        convId: group,
        sender: ChatFixtures.peer,
        body: 'Длинное последнее сообщение ' * 5,
      ),
    );
    h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats([groupJson]));
    h.chatAdapter.onJson('GET', '/chats/$group', groupJson);
    final reply = ChatFixtures.message(
      id: 'g5',
      seq: 5,
      convId: group,
      sender: ChatFixtures.carol,
      body: 'Ответ ' * 30,
    );
    reply['reply_to_id'] = 'g1';
    reply['reply_to'] = {
      'id': 'g1',
      'sender_id': ChatFixtures.peer,
      'type': 'text',
      'body': 'Цитата ' * 20,
      'deleted': false,
    };
    reply['reactions'] = [
      for (final e in ['👍', '❤️', '😂', '🔥', '🎉', '👏'])
        {'reaction': e, 'count': 12, 'user_ids': [ChatFixtures.me], 'me': e == '👍'},
    ];
    final forwarded = ChatFixtures.message(
      id: 'g4',
      seq: 4,
      convId: group,
      sender: ChatFixtures.me,
      body: 'https://very-long-domain-name.example.kz/${'segment/' * 12}',
    );
    forwarded['forward_of_id'] = 'x1';
    forwarded['forwarded_from'] = {
      'message_id': 'x1',
      'sender_id': ChatFixtures.carol,
      'display_name': longName,
    };
    h.chatAdapter.onJson(
      'GET',
      '/chats/$group/messages',
      ChatFixtures.messages([
        ChatFixtures.message(id: 'g1', seq: 1, convId: group, sender: ChatFixtures.peer, body: 'Цитата ' * 20),
        ChatFixtures.message(
          id: 'g2',
          seq: 2,
          convId: group,
          sender: ChatFixtures.peer,
          type: 'file',
          body: '',
          attachments: [
            ChatFixtures.attachment(
              id: 'att-f',
              kind: 'document',
              filename: '${'очень_длинное_имя_файла_' * 6}.pdf',
              mimeType: 'application/pdf',
              hasThumbnail: false,
            ),
          ],
        ),
        ChatFixtures.message(
          id: 'g3',
          seq: 3,
          convId: group,
          sender: ChatFixtures.peer,
          type: 'voice',
          body: '',
          attachments: [
            ChatFixtures.attachment(
              id: 'att-voice',
              kind: 'voice',
              filename: 'voice.m4a',
              mimeType: 'audio/mp4',
              hasThumbnail: false,
              durationMs: 83000,
            ),
          ],
        ),
        forwarded,
        reply,
        ChatFixtures.message(id: 'g6', seq: 6, convId: group, sender: ChatFixtures.peer, body: 'Длинное последнее сообщение ' * 5),
      ]),
    );
    await signIn(tester);
    await tester.runAsync(() => ChatCache(h.db).setDraft(group, 'Черновик ' * 20));

    await tester.pumpWidget(
      wrapWidget(const ChatListScreen(), container: h.container),
    );
    await settle(tester);
    expect(find.byKey(const ValueKey('chat_$group')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      wrapWidget(
        const ConversationScreen(conversationId: group),
        container: h.container,
      ),
    );
    await settle(tester, 16);
    expect(find.byKey(const ValueKey('forwarded_g4')), findsOneWidget);
    expect(find.textContaining('Переслано от $longName'), findsOneWidget);
    expect(find.byKey(const Key('chat_unread_separator')), findsOneWidget);
    // Reply context and selection bar at 360 px too.
    await tester.longPress(find.byKey(const ValueKey('c:cid-g1')));
    await settle(tester, 6);
    await tester.tap(find.byKey(const Key('message_select')));
    await settle(tester, 6);
    expect(find.byKey(const Key('chat_selection_bar')), findsOneWidget);
    expect(find.byKey(const Key('selection_forward')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('c:cid-g2')));
    await tester.pump();
    expect(find.text('Выбрано: 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });
}
