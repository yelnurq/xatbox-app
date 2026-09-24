import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/notifications/local_notification_hub.dart';
import 'package:xatbox_mobile/core/platform/desktop.dart';
import 'package:xatbox_mobile/core/platform/desktop_commands.dart';
import 'package:xatbox_mobile/core/platform/desktop_keys.dart';
import 'package:xatbox_mobile/core/platform/desktop_shell.dart';
import 'package:xatbox_mobile/features/chat/data/chat_notification_actions.dart';
import 'package:xatbox_mobile/features/mail/data/mail_models.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_print.dart';
import 'package:xatbox_mobile/features/mail/presentation/message_window.dart';
import 'package:xatbox_mobile/shared/widgets/desktop_drop_target.dart';

import '../helpers/fixtures.dart';

void main() {
  group('mailto links', () {
    test('addresses, copies, subject and body (RFC 6068)', () {
      final link = parseMailto(
        'mailto:a@kaztbu.edu.kz,name+tag@kaztbu.edu.kz?cc=c@x.kz;d@x.kz&bcc=e@x.kz'
        '&subject=%D0%9F%D1%80%D0%B8%D0%B2%D0%B5%D1%82%20%D0%BC%D0%B8%D1%80&body=line%201%0D%0Aline+2',
      );
      expect(link, isNotNull);
      expect(link!.to, ['a@kaztbu.edu.kz', 'name+tag@kaztbu.edu.kz']);
      expect(link.cc, ['c@x.kz', 'd@x.kz']);
      expect(link.bcc, ['e@x.kz']);
      expect(link.subject, 'Привет мир');
      expect(link.body, 'line 1\nline+2', reason: '+ is not a space in mailto');
    });

    test('to= in the query, upper case scheme, broken escapes, not a mailto', () {
      expect(parseMailto('MAILTO:?to=x@y.kz&subject=a%zz')!.to, ['x@y.kz']);
      expect(parseMailto('MAILTO:?to=x@y.kz&subject=a%zz')!.subject, 'a%zz');
      expect(parseMailto('mailto:')!.to, isEmpty);
      expect(parseMailto('https://kaztbu.edu.kz'), isNull);
    });

    test('command line: mailto, --compose, --open=<module>; the rest is ignored', () {
      expect(parseDesktopArguments(['mailto:a@b.kz']), [const DesktopCompose(mailto: MailtoLink(to: ['a@b.kz']))]);
      expect(parseDesktopArguments([DesktopArguments.compose]), [const DesktopCompose()]);
      expect(parseDesktopArguments([DesktopArguments.open(DesktopModuleTarget.chat)]), [
        const DesktopOpen(DesktopModuleTarget.chat),
      ]);
      expect(parseDesktopArguments(['--open=nowhere', '--flag', '--hidden']), isEmpty);
      expect(parseDesktopArguments(const []), isEmpty);
    });
  });

  group('window placement', () {
    const screen = Rect.fromLTWH(0, 0, 1920, 1040);
    const second = Rect.fromLTWH(1920, 0, 1280, 984);

    test('kept on a connected screen, dropped when its monitor is gone', () {
      const saved = WindowPlacement(Rect.fromLTWH(2000, 40, 1100, 800), maximized: true);
      expect(WindowPlacement.usable(saved, [screen, second])!.bounds, saved.bounds);
      expect(WindowPlacement.usable(saved, [screen, second])!.maximized, isTrue);
      expect(WindowPlacement.usable(saved, [screen]), isNull);
      expect(WindowPlacement.usable(null, [screen]), isNull);
    });

    test('size within the minimum and the screen; JSON round trip', () {
      const tiny = WindowPlacement(Rect.fromLTWH(10, 10, 300, 200));
      final fixed = WindowPlacement.usable(tiny, [screen])!;
      expect(fixed.bounds.size, desktopMinWindowSize);
      const huge = WindowPlacement(Rect.fromLTWH(0, 0, 5000, 3000));
      expect(WindowPlacement.usable(huge, [screen])!.bounds.size, screen.size);
      final json = const WindowPlacement(Rect.fromLTWH(5, 6, 1200, 900), maximized: true).toJson();
      final back = WindowPlacement.fromJson(json)!;
      expect(back.bounds, const Rect.fromLTWH(5, 6, 1200, 900));
      expect(back.maximized, isTrue);
      expect(WindowPlacement.fromJson({'x': 1}), isNull);
      expect(WindowPlacement.fromJson('nonsense'), isNull);
    });
  });

  group('Windows toasts', () {
    test('a button carries its action and the payload; a body tap has none', () {
      const payload = 'push:{"conversation_id":"c1"}';
      final args = LocalNotificationHub.windowsActionArguments(chatReplyActionId, payload);
      // What flutter_local_notifications_windows reports for a button.
      final pressed = LocalNotificationHub.normalizeWindowsResponse(
        NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotification,
          payload: args,
          actionId: args,
          data: const {'reply': 'Иду'},
        ),
      );
      expect(pressed.actionId, chatReplyActionId);
      expect(pressed.payload, payload);
      expect(pressed.input, 'Иду');
      expect(isChatNotificationAction(pressed), isTrue);

      final tapped = LocalNotificationHub.normalizeWindowsResponse(
        const NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotification,
          payload: payload,
          actionId: payload,
        ),
      );
      expect(tapped.actionId, isNull);
      expect(tapped.payload, payload);
      expect(isChatNotificationAction(tapped), isFalse);

      final call = LocalNotificationHub.normalizeWindowsResponse(
        NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotification,
          payload: LocalNotificationHub.windowsActionArguments(LocalNotificationHub.callAcceptActionId, 'call-7'),
        ),
      );
      expect(call.actionId, LocalNotificationHub.callAcceptActionId);
      expect(call.payload, 'call-7');
    });

    test('taskbar badge text', () {
      expect(DesktopShell.badgeLabel(7), '7');
      expect(DesktopShell.badgeLabel(99), '99');
      expect(DesktopShell.badgeLabel(100), '99+');
      expect(DesktopShell.available, isFalse, reason: 'tests run as the phone app');
    });
  });

  group('print', () {
    MailMessageDetail detail(String html) => MailMessageDetail.fromJson({
      ...Fixtures.detail(bodyHtml: html),
      'subject': 'Отчёт <2026> & план',
    });
    const labels = MailPrintLabels(
      from: 'От',
      to: 'Кому',
      cc: 'Копия',
      date: 'Дата',
      attachments: 'Вложения',
      noSubject: '(без темы)',
    );

    test('escaped header, prepared body, nothing runs but the print script', () {
      final html = mailPrintHtml(
        detail('<p>Текст</p><script>alert(1)</script><img src="https://tracker.example/p.gif">'),
        labels: labels,
        date: '18 сентября 2026',
        language: 'ru',
        nonce: 'n0nce',
      );
      expect(html, contains('<title>Отчёт &lt;2026&gt; &amp; план</title>'));
      expect(html, contains("script-src 'nonce-n0nce'"));
      expect(html, contains('<p>Текст</p>'));
      expect(html, isNot(contains('alert(1)')));
      expect(html, contains('https://tracker.example/p.gif'), reason: 'pictures load, as on the web');
      expect(html, contains('<td>Кому</td><td>user@example.kz</td>'));
      expect(html, contains('<td>Копия</td><td>cc@example.kz</td>'));
      expect('<script'.allMatches(html).length, 1);
    });
  });

  group('message windows', () {
    test('one window per message, brought to the front; moved and resized within limits', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(messageWindowsProvider.notifier);
      n.open('m1');
      n.open('m2');
      n.open('m1');
      final windows = container.read(messageWindowsProvider);
      expect(windows.map((w) => w.messageId), ['m2', 'm1']);
      final id = windows.last.id;
      n.move(id, const Offset(-5000, -5000), const Size(1200, 800));
      expect(container.read(messageWindowsProvider).last.offset.dy, 0);
      n.resize(id, const Offset(-5000, -5000));
      expect(container.read(messageWindowsProvider).last.size, MessageWindowsNotifier.minSize);
      n.show(id, 'm3');
      expect(container.read(messageWindowsProvider).last.messageId, 'm3');
      n.close(id);
      expect(container.read(messageWindowsProvider).map((w) => w.messageId), ['m2']);
    });
  });

  test('the command key: Ctrl on Windows and Linux, ⌘ on the Mac', () {
    expect(commandShortcut(LogicalKeyboardKey.keyN).control, isTrue);
    expect(commandKeyLabel, 'Ctrl');
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final mac = commandShortcut(LogicalKeyboardKey.keyN, shift: true);
      expect((mac.meta, mac.control, mac.shift), (true, false, true));
      expect(commandKeyLabel, '⌘');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  group('keyboard and files (desktop)', () {
    setUp(() => debugDesktopOverride = true);
    tearDown(() => debugDesktopOverride = null);

    testWidgets('single keys outside text fields, Ctrl keys everywhere, nothing under a dialog', (tester) async {
      final pressed = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopKeyBindings(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyJ): () => pressed.add('j'),
                const SingleActivator(LogicalKeyboardKey.keyP, control: true): () => pressed.add('ctrl+p'),
              },
              child: const TextField(key: Key('field')),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      expect(pressed, ['j']);

      await tester.tap(find.byKey(const Key('field')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      expect(pressed, ['j'], reason: 'typing J in a field is text');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(pressed, ['j', 'ctrl+p']);

      FocusManager.instance.primaryFocus?.unfocus();
      showDialog<void>(context: tester.element(find.byType(TextField)), builder: (_) => const AlertDialog(content: Text('d')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      expect(pressed, ['j', 'ctrl+p'], reason: 'a dialog is on top');
      expect(DesktopKeyBindings.hasModifier(const SingleActivator(LogicalKeyboardKey.keyA)), isFalse);
      expect(DesktopKeyBindings.hasModifier(const CharacterActivator('?')), isFalse);
      expect(DesktopKeyBindings.hasModifier(const SingleActivator(LogicalKeyboardKey.enter, control: true)), isTrue);
    });

    testWidgets('dropped files go to the deepest area under the pointer', (tester) async {
      final page = <String>[];
      final composer = <String>[];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DesktopDropTarget(
            onFiles: page.addAll,
            child: Stack(
              children: [
                const SizedBox.expand(),
                Positioned(
                  right: 0,
                  bottom: 0,
                  width: 200,
                  height: 150,
                  child: DesktopDropTarget(onFiles: composer.addAll, child: const SizedBox.expand()),
                ),
              ],
            ),
          ),
        ),
      );
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(DesktopFileRouter.drop(['a.pdf'], Offset(size.width - 20, size.height - 20)), isTrue);
      expect(DesktopFileRouter.drop(['b.docx'], const Offset(10, 10)), isTrue);
      expect(composer, ['a.pdf']);
      expect(page, ['b.docx']);
    });
  });
}
