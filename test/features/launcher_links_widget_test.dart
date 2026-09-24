import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/conversation_screen.dart';
import 'package:xatbox_mobile/features/home_widget/saved_chat_launcher_screen.dart';

import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// App icon shortcuts / widget taps arrive as `xatbox://` links and go through
/// the real router once signed in.
void main() {
  late TestHarness h;
  tearDown(() => h.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 20]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('«Поиск» opens the unified search; «Избранное» resolves and opens the saved chat', (tester) async {
    tester.platformDispatcher.localeTestValue = const Locale('ru');
    tester.platformDispatcher.localesTestValue = const [Locale('ru')];
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    h = await TestHarness.create(storedToken: Fixtures.token, chatBaseUrl: 'http://chat.local/api/v1');
    // A user with mail (compose FAB in the mail tab) — the chat FAB has its own
    // heroTag, so opening a chat from the shell must not assert.
    h.adapter.onJson('GET', '/me', Fixtures.me(permissions: const ['mail.read', 'mail.send']));
    h.adapter.onJson('GET', '/mail/summary', Fixtures.summary());
    h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats([ChatFixtures.conversation()]));
    h.chatAdapter.onPattern('POST', r'^/push/devices$', (_) => const FakeResponse(204));
    final saved = ChatFixtures.conversation(id: 'saved-1', title: '')..['type'] = 'saved';
    h.chatAdapter.onJson('POST', '/chats/saved', saved);
    h.chatAdapter.onPattern(
      'GET',
      r'^/chats/[^/]+/messages$',
      (_) => FakeResponse(200, json: ChatFixtures.messages(const [])),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(container: h.container, child: const XatBoxApp()),
    );
    await settle(tester);

    h.links.emit(Uri.parse('xatbox://search'));
    await settle(tester);
    expect(find.byKey(const Key('unified_search_field')), findsOneWidget);

    h.links.emit(Uri.parse('xatbox://chat/saved'));
    await settle(tester, 30);
    expect(h.chatAdapter.of('POST', '/chats/saved'), hasLength(1));
    expect(find.byType(SavedChatLauncherScreen), findsNothing);
    expect(find.byType(ConversationScreen), findsOneWidget);

    // Stop the chat socket (ping timer) before the pending-timer check.
    unawaited(h.container.read(chatRepositoryProvider).stop());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 30));
  });
}
