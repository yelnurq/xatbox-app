import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/features/calendar/domain/calendar_time.dart';
import 'package:xatbox_mobile/features/mail/presentation/compose_screen.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_providers.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_ux_settings.dart';
import 'package:xatbox_mobile/features/mail/presentation/message_detail_screen.dart';
import 'package:xatbox_mobile/features/mail/presentation/settings/mail_settings_screen.dart';
import 'package:xatbox_mobile/shared/widgets/avatar_cache.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Mail iteration-5 screens through the real router: composer formatting,
/// calendar invitation card, mail settings, phishing report, delivery
/// timeline, conversation mode.
void main() {
  setUpAll(CalendarZones.ensureInitialized);

  late TestHarness h;
  tearDown(() => h.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 12]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> launch(WidgetTester tester) async {
    h = await TestHarness.create(
      storedToken: Fixtures.token,
      overrides: [
        avatarDiskStoreProvider.overrideWithValue(MemoryAvatarDiskStore()),
      ],
    );
    h.stubSignedIn();
    tester.platformDispatcher.localeTestValue = const Locale('ru');
    tester.platformDispatcher.localesTestValue = const [Locale('ru')];
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.runAsync(() => h.session.restore());
    await tester.pumpWidget(
      UncontrolledProviderScope(container: h.container, child: const XatBoxApp()),
    );
    await settle(tester);
  }

  Future<void> push(WidgetTester tester, String route, {Object? extra}) async {
    unawaited(h.container.read(appRouterProvider).push(route, extra: extra));
    await settle(tester, 20);
  }

  Finder detailMenu() => find.descendant(
    of: find.byType(MessageDetailScreen),
    matching: find.byType(PopupMenuButton<String>),
  );

  testWidgets(
    'composer: toolbar formats, preview renders, signature preview shown; send has text and html',
    (tester) async {
      await launch(tester);
      h.adapter.onJson(
        'GET',
        '/mail/signature-preview',
        Fixtures.signaturePreview(),
      );
      h.adapter.onJson('POST', '/mail/send', {
        'message_id': 'msg_1',
      }, status: 202);
      await push(tester, Routes.mailCompose, extra: const ComposeArgs.blank());
      expect(find.byType(ComposeScreen), findsOneWidget);
      expect(
        find.byKey(const Key('compose_signature_preview')),
        findsOneWidget,
      );
      expect(find.textContaining('КазТБУ · +7 700 000 00 00'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('compose_to')), 'a@b.kz');
      await tester.enterText(find.byKey(const Key('compose_subject')), 'Тема');
      await tester.enterText(
        find.byKey(const Key('compose_body')),
        'Привет мир\nпункт',
      );
      final body = tester
          .widget<TextField>(find.byKey(const Key('compose_body')))
          .controller!;

      body.selection = const TextSelection(baseOffset: 0, extentOffset: 6);
      await tester.tap(find.byKey(const Key('fmt_bold')));
      await tester.pump();
      expect(body.text, '**Привет** мир\nпункт');

      body.selection = TextSelection.collapsed(offset: body.text.length);
      await tester.tap(find.byKey(const Key('fmt_bullets')));
      await tester.pump();
      expect(body.text, '**Привет** мир\n- пункт');

      await tester.tap(find.byKey(const Key('fmt_preview')));
      await settle(tester);
      expect(find.byKey(const Key('compose_preview')), findsOneWidget);
      expect(find.byKey(const Key('compose_body')), findsNothing);
      expect(
        tester.widget<IconButton>(find.byKey(const Key('fmt_bold'))).onPressed,
        isNull,
        reason: 'formatting is disabled while previewing',
      );

      // Immediate send (the undo-send delay is covered in mail_ux_test).
      unawaited(
        h.container
            .read(mailUxSettingsProvider.notifier)
            .update(const MailUxSettings(undoSendSeconds: 0)),
      );
      await tester.tap(find.byKey(const Key('compose_send')));
      await settle(tester, 20);
      expect(h.adapter.of('POST', '/mail/send').single.json, {
        'to': ['a@b.kz'],
        'subject': 'Тема',
        'text': 'Привет мир\n• пункт',
        'html': '<div><b>Привет</b> мир</div><ul><li>пункт</li></ul>',
      });
      expect(find.byType(ComposeScreen), findsNothing);
    },
  );

  testWidgets('composer: signature preview failure is silent', (tester) async {
    await launch(tester);
    h.adapter.onError('GET', '/mail/signature-preview', 500, 'INTERNAL');
    await push(tester, Routes.mailCompose, extra: const ComposeArgs.blank());
    expect(find.byKey(const Key('compose_signature_preview')), findsNothing);
    expect(
      find.text('Подпись добавит сервер при отправке.'),
      findsOneWidget,
      reason: 'falls back to the neutral note, no error',
    );
    expect(find.textContaining('Ошибка сервера'), findsNothing);
  });

  testWidgets(
    'invitation card: shows the event, responds with blob_id in query and body, offers the calendar',
    (tester) async {
      await launch(tester);
      h.adapter.onJson(
        'GET',
        '/mail/messages/m1',
        Fixtures.detail(attachments: [Fixtures.icsAttachment()]),
      );
      h.adapter.onJson(
        'GET',
        '/mail/messages/m1/calendar-invitation',
        Fixtures.invitationPreview(),
      );
      h.adapter.onJson(
        'POST',
        '/mail/messages/m1/calendar-invitation/respond',
        {'event_id': 'ev1', 'status': 'accepted'},
      );
      await push(tester, Routes.mailMessagePath('m1'));

      expect(find.byKey(const Key('invitation_card')), findsOneWidget);
      expect(
        h.adapter
            .of('GET', '/mail/messages/m1/calendar-invitation')
            .single
            .query,
        {'blob_id': 'blob_ics'},
      );
      expect(find.text('Защита проекта'), findsOneWidget);
      expect(find.text('Организатор: Болат Сейтов'), findsOneWidget);
      expect(find.text('Ваш ответ: нет ответа'), findsOneWidget);
      expect(find.byKey(const Key('invite_open_calendar')), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('invite_accepted')));
      await tester.tap(find.byKey(const Key('invite_accepted')));
      await settle(tester);

      final req = h.adapter
          .of('POST', '/mail/messages/m1/calendar-invitation/respond')
          .single;
      expect(req.query, {'blob_id': 'blob_ics'});
      expect(req.json, {'blob_id': 'blob_ics', 'status': 'accepted'});
      expect(find.text('Ваш ответ: принято'), findsOneWidget);
      expect(find.text('Ответ сохранён в календаре'), findsOneWidget);
      expect(find.byKey(const Key('invite_open_calendar')), findsOneWidget);
    },
  );

  testWidgets('invitation card: INVALID_ICS is explained without retry', (
    tester,
  ) async {
    await launch(tester);
    h.adapter.onJson(
      'GET',
      '/mail/messages/m1',
      Fixtures.detail(attachments: [Fixtures.icsAttachment()]),
    );
    h.adapter.onError(
      'GET',
      '/mail/messages/m1/calendar-invitation',
      400,
      'INVALID_ICS',
    );
    await push(tester, Routes.mailMessagePath('m1'));
    expect(find.text('Не удалось прочитать приглашение.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('invitation_card')),
        matching: find.text('Повторить'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'mail settings: signature loads, byte limit is checked, save sends exactly {text}',
    (tester) async {
      await launch(tester);
      h.adapter.onJson('GET', '/mail/signature', Fixtures.signature());
      h.adapter.onJson(
        'GET',
        '/mail/signature-preview',
        Fixtures.signaturePreview(),
      );
      h.adapter.onJson(
        'PUT',
        '/mail/signature',
        Fixtures.signature(text: 'Иван Петров\nДеканат', isDefault: false),
      );
      await push(tester, Routes.settingsMail);
      expect(find.byType(MailSettingsScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('mail_settings_signature')));
      await settle(tester, 20);

      expect(find.byType(SignatureSettingsScreen), findsOneWidget);
      expect(
        find.text('Сейчас используется подпись по умолчанию.'),
        findsOneWidget,
      );
      final field = tester.widget<TextField>(
        find.byKey(const Key('signature_text')),
      );
      expect(field.controller!.text, 'Тест Пользователь\nKazTBU');

      // 1001 Cyrillic letters = 2002 bytes.
      await tester.enterText(
        find.byKey(const Key('signature_text')),
        'ж' * 1001,
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('signature_save')));
      await settle(tester);
      expect(find.text('Подпись длиннее 2000 байт.'), findsOneWidget);
      expect(h.adapter.of('PUT', '/mail/signature'), isEmpty);

      await tester.enterText(
        find.byKey(const Key('signature_text')),
        'Иван Петров\nДеканат',
      );
      await tester.tap(find.byKey(const Key('signature_save')));
      await settle(tester);
      expect(h.adapter.of('PUT', '/mail/signature').single.json, {
        'text': 'Иван Петров\nДеканат',
      });
      expect(find.text('Сохранено'), findsOneWidget);
      expect(find.byKey(const Key('signature_restore')), findsOneWidget);
    },
  );

  testWidgets(
    'report phishing is confirmed first, then reports kind=phishing and closes',
    (tester) async {
      await launch(tester);
      h.adapter.onJson('GET', '/mail/messages/m1', Fixtures.detail());
      h.adapter.onJson('POST', '/mail/messages/m1/report', {
        'kind': 'phishing',
        'folder': 'spam',
        'learned': true,
      });
      await push(tester, Routes.mailMessagePath('m1'));

      await tester.tap(detailMenu());
      await settle(tester);
      await tester.tap(find.text('Сообщить о фишинге'));
      await settle(tester);
      expect(find.text('Сообщить о фишинге?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('phishing_cancel')));
      await settle(tester);
      expect(h.adapter.of('POST', '/mail/messages/m1/report'), isEmpty);
      expect(find.byType(MessageDetailScreen), findsOneWidget);

      await tester.tap(detailMenu());
      await settle(tester);
      await tester.tap(find.text('Сообщить о фишинге'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('phishing_confirm')));
      await settle(tester, 20);
      expect(h.adapter.of('POST', '/mail/messages/m1/report').single.json, {
        'kind': 'phishing',
      });
      expect(find.byType(MessageDetailScreen), findsNothing);
      expect(find.text('Сообщение о фишинге отправлено'), findsOneWidget);
    },
  );

  testWidgets('sent message: delivery timeline sheet', (tester) async {
    await launch(tester);
    h.adapter.onJson('GET', '/mail/messages/m1', {
      ...Fixtures.detail(),
      'folder': 'sent',
    });
    h.adapter.onJson('GET', '/mail/messages/m1/events', {
      'status': 'partially_delivered',
      'recipients': [
        {'address': 'ok@example.kz', 'status': 'delivered'},
        {'address': 'bad@example.kz', 'status': 'failed', 'error': 'mailbox full'},
      ],
      'events': [
        {'type': 'email.accepted', 'created_at': '2026-09-11 08:00:01.5+00'},
      ],
    });
    await push(tester, Routes.mailMessagePath('m1'));
    await tester.tap(detailMenu());
    await settle(tester);
    expect(find.text('Сообщить о фишинге'), findsOneWidget);
    await tester.tap(find.text('Статус доставки'));
    await settle(tester, 20);
    expect(find.byKey(const Key('delivery_sheet')), findsOneWidget);
    expect(find.text('Доставлено частично'), findsOneWidget);
    expect(find.text('bad@example.kz'), findsOneWidget);
    expect(find.text('Не доставлено · mailbox full'), findsOneWidget);
    expect(find.text('Принято к отправке'), findsOneWidget);
  });

  testWidgets('conversation mode toggle requests threads=1 and is remembered', (
    tester,
  ) async {
    await launch(tester);
    expect(h.adapter.of('GET', '/mail/messages'), hasLength(1));
    expect(
      h.adapter.of('GET', '/mail/messages').single.query.containsKey('threads'),
      isFalse,
    );
    await tester.tap(find.byKey(const Key('mail_threads_toggle')));
    await settle(tester);
    expect(h.adapter.of('GET', '/mail/messages').last.query['threads'], '1');
    expect(h.container.read(mailThreadsModeProvider), isTrue);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('mail_threads_toggle')))
          .isSelected,
      isTrue,
    );
  });
}
