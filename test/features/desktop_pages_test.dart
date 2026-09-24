import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/localization/localization.dart';
import 'package:xatbox_mobile/core/platform/desktop.dart';
import 'package:xatbox_mobile/core/platform/desktop_layout.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_list_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/conversation_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/new_chat_screen.dart';
import 'package:xatbox_mobile/features/mail/presentation/compose_screen.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_home_screen.dart';
import 'package:xatbox_mobile/features/mail/presentation/message_detail_screen.dart';
import 'package:xatbox_mobile/features/profile/profile_screen.dart';
import 'package:xatbox_mobile/features/settings/desktop_settings_screen.dart';

import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Desktop pages beyond the calendar: links from elsewhere open inside the
/// module (chat pane, reading pane), the floating composer never loses or
/// leaves a draft behind, C means «new» in the open module, settings rows
/// stay in the settings layout.
void main() {
  Future<void> settle(WidgetTester tester, [int steps = 12]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<TestHarness> launch(WidgetTester tester) async {
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
    h.adapter.onPattern('GET', r'^/mail/messages/m\d+$', (req) {
      return FakeResponse(200, json: Fixtures.detail(id: req.path.split('/').last));
    });
    final conv = ChatFixtures.conversation(title: 'Болат', lastSeq: 1);
    h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats([conv]));
    h.chatAdapter.onJson('GET', '/chats/${ChatFixtures.conv}', conv);
    h.chatAdapter.onJson(
      'GET',
      '/chats/${ChatFixtures.conv}/messages',
      ChatFixtures.messages([ChatFixtures.message(id: 'x1', seq: 1, body: 'Привет')]),
    );
    h.chatAdapter.onPattern('POST', r'^/push/devices$', (_) => const FakeResponse(204));
    h.chatAdapter.onJson('GET', '/users', {'users': [ChatFixtures.user(name: 'Болат Сейтов')]});
    h.adapter.onJson('GET', '/me/sessions', {'sessions': <Object>[]});
    await tester.pumpWidget(UncontrolledProviderScope(container: h.container, child: const XatBoxApp()));
    await settle(tester);
    return h;
  }

  /// Stops the messenger's socket (its ping timer) before the test ends.
  Future<void> finish(WidgetTester tester, TestHarness h) async {
    unawaited(h.container.read(chatRepositoryProvider).stop());
    await tester.pump(const Duration(seconds: 10));
  }

  String location(TestHarness h) => h.container.read(appRouterProvider).routerDelegate.currentConfiguration.uri.path;

  testWidgets('a chat opened from another module opens in the messenger pane', (tester) async {
    final h = await launch(tester);
    final router = h.container.read(appRouterProvider);
    router.go(Routes.contacts);
    await settle(tester);
    // As a toast, a contact's «Написать» or search do.
    unawaited(router.push(Routes.chatConversationPath(ChatFixtures.conv)));
    await settle(tester, 20);
    expect(location(h), Routes.chat);
    expect(router.canPop(), isFalse);
    expect(find.byType(ChatListScreen), findsOneWidget);
    final pane = tester.widget<ConversationScreen>(find.byType(ConversationScreen));
    expect(pane.embedded, isTrue);
    expect(find.text('Привет'), findsOneWidget);
    await finish(tester, h);
  });

  testWidgets('a letter opened from another module opens in the reading pane', (tester) async {
    final h = await launch(tester);
    final router = h.container.read(appRouterProvider);
    router.go(Routes.settings);
    await settle(tester);
    unawaited(router.push(Routes.mailMessagePath('m2')));
    await settle(tester, 20);
    expect(location(h), Routes.mail);
    expect(find.byType(MailHomeScreen), findsOneWidget);
    expect(tester.widget<MessageDetailScreen>(find.byType(MessageDetailScreen)).messageId, 'm2');
    await finish(tester, h);
  });

  testWidgets('composer: 🗑 after an autosave asks, then deletes the saved draft', (tester) async {
    final h = await launch(tester);
    h.adapter.onJson('POST', '/mail/drafts', {'id': 'd1'}, status: 201);
    h.adapter.onJson('DELETE', '/mail/messages/d1', const {});
    await tester.tap(find.byKey(const Key('compose_button')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('compose_subject')), 'План');
    for (var i = 0; i < 70; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(h.adapter.of('POST', '/mail/drafts'), hasLength(1));

    await tester.tap(find.byKey(const Key('compose_discard')));
    await settle(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.byKey(const Key('compose_discard_confirm')));
    await settle(tester);
    expect(h.adapter.of('DELETE', '/mail/messages/d1'), hasLength(1));
    expect(find.byType(ComposeScreen), findsNothing);
    // Nothing saves it again afterwards.
    await finish(tester, h);
    expect(h.adapter.of('POST', '/mail/drafts'), hasLength(1));
  });

  testWidgets('composer: the minimised bar shows the subject; its ✕ saves the draft', (tester) async {
    final h = await launch(tester);
    h.adapter.onJson('POST', '/mail/drafts', {'id': 'd1'}, status: 201);
    await tester.tap(find.byKey(const Key('compose_button')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('compose_subject')), 'Отчёт кафедры');
    await tester.tap(find.byKey(const Key('compose_window_minimize')));
    await settle(tester);
    expect(find.descendant(of: find.byKey(const Key('compose_window_restore')), matching: find.text('Отчёт кафедры')), findsOneWidget);

    await tester.tap(find.byKey(const Key('compose_window_bar_close')));
    await settle(tester);
    expect(h.adapter.of('POST', '/mail/drafts'), hasLength(1));
    expect(h.adapter.of('POST', '/mail/drafts').single.json['subject'], 'Отчёт кафедры');
    expect(find.byType(ComposeScreen), findsNothing);
    await finish(tester, h);
  });

  testWidgets('C in the messenger starts a new chat, not a letter', (tester) async {
    final h = await launch(tester);
    h.container.read(appRouterProvider).go(Routes.chat);
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await settle(tester);
    expect(find.byType(NewChatScreen), findsOneWidget);
    expect(find.byType(ComposeScreen), findsNothing);
    await finish(tester, h);
  });

  testWidgets('messenger: right click on a chat opens its menu at the pointer', (tester) async {
    final h = await launch(tester);
    h.container.read(appRouterProvider).go(Routes.chat);
    await settle(tester);
    await tester.tap(
      find.byKey(const ValueKey('chat_${ChatFixtures.conv}')),
      buttons: kSecondaryButton,
      kind: PointerDeviceKind.mouse,
    );
    await settle(tester);
    expect(find.byKey(const Key('chat_menu_mark_unread')), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    await finish(tester, h);
  });

  testWidgets('settings: rows switch the section in place; profile names roles', (tester) async {
    final h = await launch(tester);
    final router = h.container.read(appRouterProvider);
    router.go(Routes.settings);
    await settle(tester);
    await tester.tap(find.byKey(const Key('settings_mail')));
    await settle(tester);
    expect(location(h), Routes.settingsMail);
    expect(router.canPop(), isFalse);
    expect(tester.widget<DesktopSettingsScreen>(find.byType(DesktopSettingsScreen)).section, DesktopSettingsSection.mail);

    router.go(Routes.profile);
    await settle(tester);
    expect(find.byType(ProfileScreen), findsOneWidget);
    // One panel: no app bar of its own inside the settings card.
    expect(find.descendant(of: find.byType(ProfileScreen), matching: find.byType(AppBar)), findsNothing);
    await finish(tester, h);
  });

  test('role codes read as names', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
    expect(roleLabel(l10n, 'org_admin'), 'Администратор организации');
    expect(roleLabel(l10n, 'organization_admin'), 'Администратор организации');
    expect(roleLabel(l10n, 'some_new_role'), 'some new role');
  });

  testWidgets('Ctrl+K: the command palette filters, Enter runs', (tester) async {
    final h = await launch(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(find.byKey(const Key('command_palette')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('command_palette_field')), 'new mess');
    await settle(tester);
    expect(find.byKey(const Key('palette_new_mail')), findsOneWidget);
    expect(find.byKey(const Key('palette_go_chat')), findsNothing);
    expect(find.byKey(const Key('palette_search')), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.byKey(const Key('command_palette')), findsNothing);
    expect(find.byType(ComposeScreen), findsOneWidget);
    await finish(tester, h);
  });

  testWidgets('contacts: right click opens the contact menu at the pointer', (tester) async {
    final h = await launch(tester);
    h.container.read(appRouterProvider).go(Routes.contacts);
    await settle(tester, 20);
    await tester.tap(find.text('Болат Сейтов').first, buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
    await settle(tester);
    expect(find.byKey(const Key('contact_menu_mail')), findsOneWidget);
    expect(find.byKey(const Key('contact_menu_copy')), findsOneWidget);
    await tester.tap(find.byKey(const Key('contact_menu_mail')));
    await settle(tester);
    expect(find.byType(ComposeScreen), findsOneWidget);
    await finish(tester, h);
  });
}
