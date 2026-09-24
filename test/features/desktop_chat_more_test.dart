import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/platform/desktop.dart';
import 'package:xatbox_mobile/core/platform/desktop_layout.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_composer.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/conversation_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/group_info_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/message_bubble.dart';
import 'package:xatbox_mobile/features/chat/presentation/new_chat_screen.dart';

import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Desktop messenger like the web's: the details panel beside the chat,
/// the hover bar and the menu at the pointer on messages, the keys (Esc,
/// Ctrl+F, ↑, Alt+↑/↓), «Новый чат» as a modal.
void main() {
  const second = 'c0000000-0000-4000-8000-000000000002';
  const created = 'c0000000-0000-4000-8000-000000000003';

  Future<void> settle(WidgetTester tester, [int steps = 12]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<TestHarness> launch(WidgetTester tester, {bool open = true}) async {
    debugDesktopOverride = true;
    addTearDown(() => debugDesktopOverride = null);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localeTestValue = const Locale('ru');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final h = await TestHarness.create(
      storedToken: Fixtures.token,
      chatBaseUrl: 'http://chat.local/api/v1',
      overrides: [desktopLayoutProvider.overrideWithValue(true)],
    );
    addTearDown(h.dispose);
    h.stubSignedIn(messages: Fixtures.messages(3), total: 3);
    final conv = ChatFixtures.conversation(title: 'Болат', lastSeq: 2);
    final other = ChatFixtures.conversation(id: second, title: 'Карина', lastSeq: 1);
    h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats([conv, other]));
    h.chatAdapter.onJson('GET', '/chats/${ChatFixtures.conv}', conv);
    h.chatAdapter.onJson('GET', '/chats/$second', other);
    h.chatAdapter.onJson(
      'GET',
      '/chats/${ChatFixtures.conv}/messages',
      ChatFixtures.messages([
        ChatFixtures.message(id: 'x1', seq: 1, body: 'Привет'),
        ChatFixtures.message(id: 'x2', seq: 2, body: 'Мой ответ', sender: ChatFixtures.me),
      ]),
    );
    h.chatAdapter.onJson(
      'GET',
      '/chats/$second/messages',
      ChatFixtures.messages([ChatFixtures.message(id: 'y1', seq: 1, body: 'Добрый день', convId: second)]),
    );
    h.chatAdapter.onPattern(
      'POST',
      r'^/messages/[^/]+/reactions$',
      (_) => const FakeResponse(200, json: {'active': true}),
    );
    h.chatAdapter.onPattern('POST', r'^/messages/[^/]+/read$', (_) => const FakeResponse(204));
    h.chatAdapter.onPattern('POST', r'^/push/devices$', (_) => const FakeResponse(204));
    h.chatAdapter.onJson('GET', '/users', {
      'users': [ChatFixtures.user(name: 'Болат Сейтов')],
    });
    h.adapter.onJson('GET', '/me/sessions', {'sessions': <Object>[]});
    await tester.pumpWidget(UncontrolledProviderScope(container: h.container, child: const XatBoxApp()));
    await settle(tester);
    h.container.read(appRouterProvider).go(Routes.chat);
    await settle(tester);
    if (open) {
      h.container.read(chatSelectedConversationProvider.notifier).select(ChatFixtures.conv);
      await settle(tester, 20);
    }
    return h;
  }

  /// Stops the messenger's socket (its ping timer) before the test ends.
  Future<void> finish(WidgetTester tester, TestHarness h) async {
    unawaited(h.container.read(chatRepositoryProvider).stop());
    await tester.pump(const Duration(seconds: 10));
  }

  String? selected(TestHarness h) => h.container.read(chatSelectedConversationProvider);

  Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  }

  Future<void> alt(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  }

  testWidgets('ⓘ opens the details panel beside the chat; Esc closes it, then the chat', (tester) async {
    final h = await launch(tester);
    expect(find.byKey(const Key('chat_info_panel')), findsNothing);
    await tester.tap(find.byKey(const Key('chat_info_toggle')));
    await settle(tester);
    expect(find.byKey(const Key('chat_info_panel')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('chat_info_panel'))).width, 340);
    expect(find.byType(GroupInfoScreen), findsOneWidget);
    // Nothing was pushed: the messenger stays the page.
    expect(h.container.read(appRouterProvider).canPop(), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byType(GroupInfoScreen), findsNothing);
    expect(selected(h), ChatFixtures.conv);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(selected(h), isNull);
    expect(find.byType(ConversationScreen), findsNothing);
    await finish(tester, h);
  });

  testWidgets('the title opens the panel; its ✕ closes it', (tester) async {
    final h = await launch(tester);
    await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.text('Болат')).first);
    await settle(tester);
    expect(find.byType(GroupInfoScreen), findsOneWidget);
    expect(h.container.read(appRouterProvider).canPop(), isFalse);
    await tester.tap(find.byKey(const Key('chat_info_panel_close')));
    await settle(tester);
    expect(find.byType(GroupInfoScreen), findsNothing);
    await finish(tester, h);
  });

  testWidgets('hovering a message shows the web bar: reactions, reply, ⋯', (tester) async {
    final h = await launch(tester);
    expect(find.byKey(const ValueKey('hover_bar_x1')), findsNothing);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('Привет')));
    await settle(tester);
    expect(find.byKey(const ValueKey('hover_bar_x1')), findsOneWidget);
    expect(find.byKey(const ValueKey('hover_react_x1_👍')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hover_react_x1_👍')));
    await settle(tester);
    final reactions = h.chatAdapter.of('POST', '/messages/x1/reactions');
    expect(reactions, hasLength(1));
    expect(reactions.single.json['reaction'], '👍');

    await tester.tap(find.byKey(const ValueKey('hover_reply_x1')));
    await settle(tester);
    expect(tester.widget<ChatComposer>(find.byType(ChatComposer)).replyTo?.id, 'x1');

    // The reply bar moved the rows: point at the message again.
    await mouse.moveTo(
      tester.getCenter(find.descendant(of: find.byType(MessageBubble), matching: find.text('Привет'))),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('hover_more_x1')));
    await settle(tester);
    expect(find.byKey(const Key('message_menu_reply')), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    await mouse.moveTo(Offset.zero);
    await finish(tester, h);
  });

  testWidgets('right click on a message opens the menu at the pointer, not the sheet', (tester) async {
    final h = await launch(tester);
    await tester.tap(find.text('Мой ответ'), buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
    await settle(tester);
    expect(find.byKey(const Key('message_menu_edit')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu_react_👍')), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.byKey(const Key('message_menu_edit')));
    await settle(tester);
    expect(tester.widget<ChatComposer>(find.byType(ChatComposer)).editing?.id, 'x2');
    // Esc drops the edit first; the chat stays open.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(tester.widget<ChatComposer>(find.byType(ChatComposer)).editing, isNull);
    expect(selected(h), ChatFixtures.conv);
    await finish(tester, h);
  });

  testWidgets('double click on a message reacts ❤️', (tester) async {
    final h = await launch(tester);
    await tester.tap(find.text('Привет'), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('Привет'), kind: PointerDeviceKind.mouse);
    await settle(tester);
    final reactions = h.chatAdapter.of('POST', '/messages/x1/reactions');
    expect(reactions, hasLength(1));
    expect(reactions.single.json['reaction'], '❤️');
    await finish(tester, h);
  });

  testWidgets('Ctrl+F opens the in-chat search; Esc in it closes the search only', (tester) async {
    final h = await launch(tester);
    await ctrl(tester, LogicalKeyboardKey.keyF);
    await settle(tester);
    expect(find.byKey(const Key('chat_search_field')), findsOneWidget);
    expect(tester.testTextInput.hasAnyClients, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byKey(const Key('chat_search_field')), findsNothing);
    expect(selected(h), ChatFixtures.conv);
    await finish(tester, h);
  });

  testWidgets('↑ in the empty composer edits the last own message', (tester) async {
    final h = await launch(tester);
    await tester.tap(find.byKey(const Key('chat_input')));
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await settle(tester);
    expect(tester.widget<ChatComposer>(find.byType(ChatComposer)).editing?.id, 'x2');
    await finish(tester, h);
  });

  testWidgets('Alt+↓ / Alt+↑ switch to the next / previous chat of the list', (tester) async {
    final h = await launch(tester);
    await alt(tester, LogicalKeyboardKey.arrowDown);
    await settle(tester, 20);
    expect(selected(h), second);
    expect(find.text('Добрый день'), findsOneWidget);
    await alt(tester, LogicalKeyboardKey.arrowUp);
    await settle(tester, 20);
    expect(selected(h), ChatFixtures.conv);
    // The first chat stays the first.
    await alt(tester, LogicalKeyboardKey.arrowUp);
    await settle(tester);
    expect(selected(h), ChatFixtures.conv);
    await finish(tester, h);
  });

  testWidgets('✎ opens «Новый чат» as a modal; «Создать» opens the group in the pane', (tester) async {
    final h = await launch(tester, open: false);
    h.chatAdapter.onJson(
      'POST',
      '/chats',
      ChatFixtures.conversation(id: created, title: 'Кафедра', group: true),
      status: 201,
    );
    h.chatAdapter.onJson(
      'GET',
      '/chats/$created',
      ChatFixtures.conversation(id: created, title: 'Кафедра', group: true),
    );
    h.chatAdapter.onJson('GET', '/chats/$created/messages', ChatFixtures.messages([]));
    await tester.tap(find.byKey(const Key('chat_new_button')));
    await settle(tester);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.descendant(of: find.byType(Dialog), matching: find.byType(NewChatScreen)), findsOneWidget);
    expect(tester.getSize(find.byType(NewChatScreen)).width, NewChatScreen.dialogWidth);
    expect(h.container.read(appRouterProvider).routerDelegate.currentConfiguration.uri.path, Routes.chat);

    // Group mode: the footer's «Создать», no floating button.
    await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.byType(TextButton)).first);
    await settle(tester);
    expect(find.byType(FloatingActionButton), findsNothing);
    final submit = find.byKey(const Key('new_chat_submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.enterText(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)).at(1), 'Кафедра');
    await tester.tap(find.byKey(const ValueKey('user_${ChatFixtures.peer}')));
    await settle(tester);
    await tester.tap(submit);
    await settle(tester, 20);

    final posts = h.chatAdapter.of('POST', '/chats');
    expect(posts, hasLength(1));
    expect(posts.single.json['type'], 'group');
    expect(find.byType(Dialog), findsNothing);
    expect(selected(h), created);
    expect(h.container.read(appRouterProvider).routerDelegate.currentConfiguration.uri.path, Routes.chat);
    await finish(tester, h);
  });

  testWidgets('C opens the modal; a colleague opens the direct chat in the pane', (tester) async {
    final h = await launch(tester, open: false);
    h.chatAdapter.onJson('POST', '/chats', ChatFixtures.conversation(title: 'Болат'), status: 201);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await settle(tester);
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('user_${ChatFixtures.peer}')));
    await settle(tester, 20);
    expect(h.chatAdapter.of('POST', '/chats').single.json['type'], 'direct');
    expect(find.byType(Dialog), findsNothing);
    expect(selected(h), ChatFixtures.conv);
    expect(find.byType(ConversationScreen), findsOneWidget);
    await finish(tester, h);
  });
}
