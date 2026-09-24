import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/features/calendar/presentation/event_edit_screen.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/localization/localization.dart';
import 'package:xatbox_mobile/core/platform/desktop.dart';
import 'package:xatbox_mobile/core/platform/desktop_layout.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/mail/data/mail_prefs.dart';
import 'package:xatbox_mobile/features/mail/domain/link_check.dart';
import 'package:xatbox_mobile/features/mail/presentation/compose_screen.dart';
import 'package:xatbox_mobile/features/mail/presentation/compose_window.dart';
import 'package:xatbox_mobile/features/mail/presentation/desktop_quick_reply.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_home_screen.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_providers.dart';
import 'package:xatbox_mobile/features/mail/presentation/message_list_view.dart';
import 'package:xatbox_mobile/features/settings/desktop_settings_screen.dart';

import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Desktop mail, the web's way: the quick reply pinned open at the bottom
/// of the reading pane, Undo after Delete / Move, links confirmed only when
/// their text names another site, the mail settings as sections of the
/// settings page with «Клавиши», conversations on by default, and the
/// «Скрыть список» button.
void main() {
  Future<void> settle(WidgetTester tester, [int steps = 12]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  const html =
      '<p><a href="https://evil.example.net/login">https://bank.kz/login</a></p>'
      '<p><a href="https://docs.kaztbu.edu.kz/plan">Учебный план</a></p>';

  Future<TestHarness> launch(
    WidgetTester tester, {
    List<Override> overrides = const [],
    String bodyHtml = '',
    List<String>? permissions,
  }) async {
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
      overrides: [desktopLayoutProvider.overrideWithValue(true), ...overrides],
    );
    addTearDown(h.dispose);
    h.stubSignedIn(messages: Fixtures.messages(3), total: 3);
    if (permissions != null) h.adapter.onJson('GET', '/me', Fixtures.me(permissions: permissions));
    h.adapter.onPattern('GET', r'^/mail/messages/m\d+$', (req) {
      return FakeResponse(200, json: Fixtures.detail(id: req.path.split('/').last, bodyHtml: bodyHtml));
    });
    h.adapter.onJson('GET', '/mail/client-config', {'enabled': true, 'attachment_limit_bytes': 1024 * 1024});
    h.adapter.onJson('GET', '/mail/folders', {'folders': <Object>[]});
    h.adapter.onJson('GET', '/mail/bookmark-folders', {'folders': <Object>[]});
    h.chatAdapter.onJson('GET', '/chats', {'chats': <Object>[]});
    h.chatAdapter.onPattern('POST', r'^/push/devices$', (_) => const FakeResponse(204));
    await tester.pumpWidget(UncontrolledProviderScope(container: h.container, child: const XatBoxApp()));
    await settle(tester);
    return h;
  }

  /// Stops the messenger's socket (its ping timer) before the test ends.
  Future<void> finish(WidgetTester tester, TestHarness h) async {
    unawaited(h.container.read(chatRepositoryProvider).stop());
    await tester.pump(const Duration(seconds: 10));
  }

  Future<void> openLetter(WidgetTester tester, TestHarness h, String id) async {
    h.container.read(mailOpenMessageProvider.notifier).open(id);
    await settle(tester);
  }

  AppLocalizations l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  String location(TestHarness h) => h.container.read(appRouterProvider).routerDelegate.currentConfiguration.uri.path;

  group('quick reply', () {
    final picked = <QuickReplyFile>[
      (name: 'план.pdf', length: () async => 3, read: () async => Uint8List.fromList([1, 2, 3])),
    ];
    final picker = desktopQuickReplyFilePickerProvider.overrideWithValue(() async => picked);

    void stubUpload(TestHarness h) => h.adapter.onJson('POST', '/mail/attachments', {
      'id': 'att1',
      'filename': 'план.pdf',
      'content_type': 'application/pdf',
      'size_bytes': 3,
    }, status: 201);

    testWidgets('is open at the bottom of the pane; Ctrl+Enter sends the text and the file', (tester) async {
      final h = await launch(tester, overrides: [picker]);
      stubUpload(h);
      h.adapter.onJson('POST', '/mail/send', {'message_id': 'msg_1'}, status: 202);
      await openLetter(tester, h, 'm1');

      final field = find.byKey(const Key('quick_reply_text'));
      expect(field, findsOneWidget, reason: 'open without a click');
      expect(find.ancestor(of: field, matching: find.byType(Scrollable)), findsNothing, reason: 'not inside the scrolling letter');
      expect(find.textContaining('Ctrl+Enter'), findsWidgets);

      await tester.tap(find.byKey(const Key('quick_reply_attach')));
      await settle(tester);
      expect(find.byKey(const ValueKey('quick_reply_file_план.pdf')), findsOneWidget);
      expect(h.adapter.of('POST', '/mail/attachments'), hasLength(1));

      await tester.enterText(field, 'Спасибо, получил.');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);

      final sent = h.adapter.of('POST', '/mail/send').single.json;
      expect(sent['text'], 'Спасибо, получил.');
      expect(sent['to'], ['sender1@example.kz']);
      expect(sent['attachment_ids'], ['att1']);
      expect(sent['in_reply_to'], 'msg1@example.kz');
      final receipt = tester.widget<Text>(find.byKey(const Key('quick_reply_sent_to'))).data!;
      expect(receipt, startsWith(l10n(tester).desktopMailQuickReplySentTo('sender1@example.kz', '')));
      expect(receipt, matches(RegExp(r'sender1@example\.kz · \d\d:\d\d$')));

      await tester.tap(find.byKey(const Key('quick_reply_another')));
      await settle(tester);
      expect(find.byKey(const Key('quick_reply_text')), findsOneWidget);
      await finish(tester, h);
    });

    testWidgets('«Открыть в редакторе» carries the text and the files over', (tester) async {
      final h = await launch(tester, overrides: [picker]);
      stubUpload(h);
      h.adapter.onJson('POST', '/mail/drafts', {'id': 'd1'}, status: 201);
      await openLetter(tester, h, 'm1');
      await tester.enterText(find.byKey(const Key('quick_reply_text')), 'Черновик ответа');
      await tester.tap(find.byKey(const Key('quick_reply_attach')));
      await settle(tester);

      await tester.tap(find.byKey(const Key('quick_reply_open_composer')));
      await settle(tester);
      final args = h.container.read(composeWindowProvider)!.args;
      expect(args.restore!.body, startsWith('Черновик ответа'));
      expect(args.restore!.to, 'sender1@example.kz');
      expect(args.restore!.subject, 'Re: Тема письма 1');
      expect(args.restore!.attachments.single.staged!.id, 'att1');
      expect(find.byType(ComposeScreen), findsOneWidget);
      await finish(tester, h);
    });
  });

  group('undo', () {
    testWidgets('Delete in the reading pane: «Отменить» puts the letter back', (tester) async {
      final h = await launch(tester);
      h.adapter.onJson('DELETE', '/mail/messages/m1', const {});
      h.adapter.onJson('PATCH', '/mail/messages/m1', const {});
      await openLetter(tester, h, 'm1');
      await tester.tap(find.byKey(const Key('action_delete')));
      await settle(tester);
      expect(h.adapter.of('DELETE', '/mail/messages/m1'), hasLength(1));
      final lists = h.adapter.of('GET', '/mail/messages').length;

      await tester.tap(find.text(l10n(tester).mailUndo));
      await settle(tester);
      expect(h.adapter.of('PATCH', '/mail/messages/m1').single.json, {'folder': 'inbox'});
      expect(find.text(l10n(tester).desktopMailRestored), findsOneWidget);
      expect(h.adapter.of('GET', '/mail/messages').length, greaterThan(lists), reason: 'the list shows it again');
      await finish(tester, h);
    });

    testWidgets('«Переместить в…» on a row: «Отменить» moves it back', (tester) async {
      final h = await launch(tester);
      h.adapter.onJson('PATCH', '/mail/messages/m2', const {});
      await tester.tap(find.byKey(const ValueKey('m2')), buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
      await settle(tester);
      await tester.tap(find.byKey(const Key('row_menu_move')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('move_to_spam')));
      await settle(tester);
      expect(h.adapter.of('PATCH', '/mail/messages/m2').single.json, {'folder': 'spam'});

      await tester.tap(find.text(l10n(tester).mailUndo));
      await settle(tester);
      expect(h.adapter.of('PATCH', '/mail/messages/m2').last.json, {'folder': 'inbox'});
      expect(find.text(l10n(tester).desktopMailRestored), findsOneWidget);
      await finish(tester, h);
    });

    testWidgets('a row dragged onto «Корзина» moves there; «Отменить» moves it back', (tester) async {
      final h = await launch(tester);
      h.adapter.onJson('PATCH', '/mail/messages/m2', const {});
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('m2'))), kind: PointerDeviceKind.mouse);
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.byKey(const Key('folder_trash'))));
      await tester.pump();
      await gesture.up();
      await settle(tester);
      expect(h.adapter.of('PATCH', '/mail/messages/m2').single.json, {'folder': 'trash'});

      await tester.tap(find.text(l10n(tester).mailUndo));
      await settle(tester);
      expect(h.adapter.of('PATCH', '/mail/messages/m2').last.json, {'folder': 'inbox'});
      await finish(tester, h);
    });
  });

  group('links', () {
    test('only a text naming another host is a mismatch', () {
      expect(LinkCheck.mismatch('https://bank.kz/login', 'https://evil.example.net/login'), (shown: 'bank.kz', real: 'evil.example.net'));
      expect(LinkCheck.mismatch('www.kaztbu.edu.kz', 'https://kaztbu.edu.kz/news'), isNull);
      expect(LinkCheck.mismatch('kaztbu.edu.kz', 'https://portal.kaztbu.edu.kz/'), isNull, reason: 'a subdomain is fine');
      expect(LinkCheck.mismatch('Учебный план', 'https://evil.example.net/'), isNull, reason: 'plain words name no host');
      expect(LinkCheck.mismatchIn(html, 'https://evil.example.net/login'), isNotNull);
      expect(LinkCheck.mismatchIn(html, 'https://docs.kaztbu.edu.kz/plan'), isNull);
    });

    testWidgets('a plain link opens at once; a disguised one asks first', (tester) async {
      final launched = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), (call) async {
        if (call.method == 'launch') launched.add((call.arguments as Map)['url'] as String);
        return true;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), null));
      final h = await launch(tester, bodyHtml: html);
      await openLetter(tester, h, 'm1');

      Future<void> tapLink(String text) async {
        final link = find.textContaining(text, findRichText: true).last;
        await tester.tapAt(tester.getTopLeft(link) + const Offset(6, 6));
        await settle(tester);
      }

      await tapLink('Учебный план');
      expect(find.byType(AlertDialog), findsNothing);
      expect(launched, ['https://docs.kaztbu.edu.kz/plan']);

      await tapLink('https://bank.kz/login');
      expect(find.byKey(const Key('link_mismatch')), findsOneWidget);
      expect(find.textContaining('evil.example.net'), findsWidgets);
      await tester.tap(find.byKey(const Key('link_mismatch_open')));
      await settle(tester);
      expect(launched, ['https://docs.kaztbu.edu.kz/plan', 'https://evil.example.net/login']);
      await finish(tester, h);
    });
  });

  group('settings', () {
    testWidgets('mail rows switch to their sections in place', (tester) async {
      final h = await launch(tester);
      h.adapter.onJson('GET', '/mail/signature', Fixtures.signature());
      h.adapter.onJson('GET', '/mail/signature-preview', Fixtures.signaturePreview());
      h.adapter.onJson('GET', '/mail/vacation', Fixtures.vacation());
      final router = h.container.read(appRouterProvider);
      router.go(Routes.settingsMail);
      await settle(tester);

      for (final (row, route, section) in [
        ('mail_settings_signature', Routes.settingsMailSignature, DesktopSettingsSection.mailSignature),
        ('mail_settings_vacation', Routes.settingsMailVacation, DesktopSettingsSection.mailVacation),
      ]) {
        router.go(Routes.settingsMail);
        await settle(tester);
        await tester.tap(find.byKey(Key(row)));
        await settle(tester);
        expect(location(h), route);
        expect(router.canPop(), isFalse);
        expect(tester.widget<DesktopSettingsScreen>(find.byType(DesktopSettingsScreen)).section, section);
        expect(find.byKey(Key('settings_section_${section.name}')), findsOneWidget);
      }
      await finish(tester, h);
    });

    testWidgets('«Клавиши» lists mail, calendar and messenger keys', (tester) async {
      final h = await launch(tester);
      h.container.read(appRouterProvider).go(Routes.settings);
      await settle(tester);
      await tester.tap(find.byKey(const Key('settings_section_shortcuts')));
      await settle(tester);
      expect(location(h), Routes.settingsShortcuts);
      final list = find.byKey(const Key('settings_shortcuts'));
      expect(list, findsOneWidget);
      final l = l10n(tester);
      for (final label in [
        l.desktopShortcutsMail.toUpperCase(),
        l.calendarTitle.toUpperCase(),
        l.chatTitle.toUpperCase(),
        l.calendarNewEvent,
        l.desktopMailKeysCalendarClosePanel,
        l.chatNew,
        l.desktopMailKeysCalendarPrevNext,
      ]) {
        expect(find.descendant(of: list, matching: find.text(label)), findsOneWidget, reason: label);
      }
      await finish(tester, h);
    });
  });

  group('conversations', () {
    test('desktop lists conversations by default; a saved choice wins; phones stay off', () async {
      Future<bool?> threads({required bool desktop, bool? saved}) async {
        final h = await TestHarness.create(overrides: [desktopLayoutProvider.overrideWithValue(desktop)]);
        if (saved != null) await MailPrefsStore(h.db).writeThreadsMode(saved);
        h.container.read(mailThreadsModeProvider);
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        final value = h.container.read(mailThreadsModeProvider);
        await h.dispose();
        return value;
      }

      expect(await threads(desktop: true), isTrue);
      expect(await threads(desktop: true, saved: false), isFalse);
      expect(await threads(desktop: false), isFalse);
      expect(await threads(desktop: false, saved: true), isTrue);
    });
  });

  testWidgets('«Скрыть список» gives the letter the full width', (tester) async {
    final h = await launch(tester);
    await openLetter(tester, h, 'm1');
    expect(find.byType(MessageListView), findsOneWidget);
    await tester.tap(find.byKey(const Key('pane_toggle_list')));
    await settle(tester);
    expect(find.byType(MessageListView), findsNothing);
    expect(h.container.read(mailListHiddenProvider), isTrue);
    await tester.tap(find.byKey(const Key('pane_toggle_list')));
    await settle(tester);
    expect(find.byType(MessageListView), findsOneWidget);
    await finish(tester, h);
  });

  testWidgets('⋯ «Назначить встречу» opens the new event with the letter\'s people', (tester) async {
    final h = await launch(
      tester,
      permissions: const ['mail.read', 'mail.send', 'calendar.events.read', 'calendar.events.create', 'calendar.events.manage_own'],
    );
    await openLetter(tester, h, 'm1');
    await tester.tap(find.byKey(const Key('action_more')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('menu_schedule_meeting')));
    await settle(tester);
    expect(find.byType(EventEditScreen), findsOneWidget);
    // The subject is the title; the sender and the Cc are invited, not me.
    expect(find.descendant(of: find.byType(EventEditScreen), matching: find.text('Тема письма 1')), findsWidgets);
    expect(find.descendant(of: find.byType(EventEditScreen), matching: find.textContaining('sender1@example.kz')), findsWidgets);
    expect(find.descendant(of: find.byType(EventEditScreen), matching: find.textContaining('cc@example.kz')), findsWidgets);
    expect(find.descendant(of: find.byType(EventEditScreen), matching: find.textContaining('user@example.kz')), findsNothing);
    await tester.tap(find.byKey(const Key('event_edit_close')));
    await settle(tester);
    await finish(tester, h);
  });
}
