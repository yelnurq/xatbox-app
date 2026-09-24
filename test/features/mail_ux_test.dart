import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/auth/auth_providers.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/features/contacts/data/contact_models.dart';
import 'package:xatbox_mobile/features/contacts/presentation/contacts_providers.dart';
import 'package:xatbox_mobile/features/mail/data/mail_models.dart';
import 'package:xatbox_mobile/features/mail/presentation/compose_screen.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_providers.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_to_chat.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_undo_send.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_ux_settings.dart';
import 'package:xatbox_mobile/features/mail/presentation/recipient_autocomplete.dart';
import 'package:xatbox_mobile/shared/widgets/avatar_cache.dart';

import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Mail UX: swipe actions, «Отменить отправку», recipient autocomplete,
/// forward-to-chat text.
void main() {
  group('pure logic', () {
    test('ux settings: defaults and tolerant parsing', () {
      const d = MailUxSettings();
      expect(d.swipeLeft, MailSwipeAction.trash);
      expect(d.swipeRight, MailSwipeAction.read);
      expect(d.undoSendSeconds, 5);
      final parsed = MailUxSettings.fromJson({
        'swipe_left': 'bookmark',
        'swipe_right': 'bogus',
        'undo_send_seconds': 7,
      });
      expect(parsed.swipeLeft, MailSwipeAction.bookmark);
      expect(parsed.swipeRight, MailSwipeAction.read);
      expect(parsed.undoSendSeconds, 5);
      final round = MailUxSettings.fromJson(
        const MailUxSettings(
          swipeLeft: MailSwipeAction.none,
          undoSendSeconds: 20,
        ).toJson(),
      );
      expect(round.swipeLeft, MailSwipeAction.none);
      expect(round.undoSendSeconds, 20);
    });

    test('archive folder only when the mailbox has one', () {
      expect(mailArchiveFolderOf(null), isNull);
      expect(
        mailArchiveFolderOf(MailSummary.fromJson(Fixtures.summary())),
        isNull,
      );
    });

    test('recipient tokens', () {
      expect(RecipientSuggest.currentToken('a@b.kz, бол'), 'бол');
      expect(RecipientSuggest.currentToken('бол'), 'бол');
      expect(RecipientSuggest.previousAddresses('A@b.kz; c@d.kz, x'), [
        'a@b.kz',
        'c@d.kz',
      ]);
      expect(RecipientSuggest.replaceCurrent('бол', 'b@x.kz'), 'b@x.kz, ');
      expect(
        RecipientSuggest.replaceCurrent('a@b.kz,бол', 'b@x.kz'),
        'a@b.kz, b@x.kz, ',
      );
    });

    test('recipient ranking: prefix first, recent ahead, entered skipped', () {
      const directory = [
        Contact(
          id: '1',
          email: 'bolat@example.kz',
          displayName: 'Болат Сейтов',
          position: 'Декан',
          department: 'Деканат',
        ),
        Contact(
          id: '2',
          email: 'asel@example.kz',
          displayName: 'Асель Болатова',
        ),
        Contact(id: '3', email: 'abol@example.kz', displayName: 'Abol'),
      ];
      final list = RecipientSuggest.rank(
        query: 'бол',
        directory: directory,
        recent: const ['old@bolashak.kz'],
      );
      expect(list.first.email, 'bolat@example.kz');
      expect(list.first.details, 'Декан · Деканат');
      expect(list.map((s) => s.email), contains('asel@example.kz'));
      expect(list.map((s) => s.email), isNot(contains('abol@example.kz')));

      final recentFirst = RecipientSuggest.rank(
        query: 'bol',
        directory: directory,
        recent: const ['bolashak@example.kz'],
      );
      expect(recentFirst.first.email, 'bolashak@example.kz');
      expect(recentFirst.first.recent, isTrue);
      expect(recentFirst[1].email, 'bolat@example.kz');

      final skipped = RecipientSuggest.rank(
        query: 'bol',
        directory: directory,
        recent: const [],
        exclude: const ['bolat@example.kz'],
      );
      expect(skipped.map((s) => s.email), isNot(contains('bolat@example.kz')));
      expect(
        RecipientSuggest.rank(
          query: ' ',
          directory: directory,
          recent: const [],
        ),
        isEmpty,
      );
    });

    test('recent recipients merge: newest first, deduped, valid only', () {
      expect(
        MailRecentRecipientsNotifier.merge(
          ['a@b.kz', 'c@d.kz'],
          ['C@d.kz', 'bad', 'e@f.kz'],
        ),
        ['c@d.kz', 'e@f.kz', 'a@b.kz'],
      );
    });

    test('forward to chat text: subject, sender, date, excerpt', () {
      final m = MailMessageDetail.fromJson(Fixtures.detail());
      final text = MailToChat.text(
        m,
        subjectLabel: 'Тема',
        fromLabel: 'От',
        dateLabel: 'Дата',
        noSubject: '(без темы)',
        date: '11 сент. 2026 г., 13:00',
      );
      expect(
        text,
        'Тема: Тема письма 1\n'
        'От: Отправитель 1 <sender1@example.kz>\n'
        'Дата: 11 сент. 2026 г., 13:00\n'
        '\nПривет!\nЭто тестовое письмо.',
      );
      final long = MailToChat.excerpt('слово ' * 400, limit: 100);
      expect(long.length, lessThanOrEqualTo(101));
      expect(long.endsWith('…'), isTrue);
      expect(MailToChat.excerpt('a\n\n\n\nb'), 'a\n\nb');
    });
  });

  group('widgets', () {
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
      h.adapter.onPattern(
        'PATCH',
        r'^/mail/messages/[^/]+$',
        (_) => const FakeResponse(200, json: {'status': 'ok'}),
      );
      h.adapter.onPattern(
        'DELETE',
        r'^/mail/messages/[^/]+$',
        (_) => const FakeResponse(200, json: {'status': 'ok'}),
      );
      tester.platformDispatcher.localeTestValue = const Locale('ru');
      tester.platformDispatcher.localesTestValue = const [Locale('ru')];
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.runAsync(() => h.session.restore());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const XatBoxApp(),
        ),
      );
      await settle(tester);
    }

    Future<void> push(
      WidgetTester tester,
      String route, {
      Object? extra,
    }) async {
      unawaited(h.container.read(appRouterProvider).push(route, extra: extra));
      await settle(tester, 20);
    }

    testWidgets(
      'swipe right toggles read, swipe left trashes with Undo; off during multi-select',
      (tester) async {
        await launch(tester);
        expect(find.byKey(const Key('message_m1')), findsOneWidget);

        await tester.drag(
          find.byKey(const Key('message_m1')),
          const Offset(500, 0),
        );
        await settle(tester);
        expect(h.adapter.of('PATCH', '/mail/messages/m1').single.json, {
          'is_read': true,
        });

        await tester.drag(
          find.byKey(const Key('message_m2')),
          const Offset(-500, 0),
        );
        await settle(tester);
        expect(h.adapter.of('DELETE', '/mail/messages/m2'), hasLength(1));
        expect(find.byKey(const Key('message_m2')), findsNothing);
        await tester.tap(find.text('Отменить'));
        await settle(tester);
        expect(h.adapter.of('PATCH', '/mail/messages/m2').single.json, {
          'folder': 'inbox',
        });

        // Multi-select: swipes do nothing.
        await tester.longPress(find.byKey(const Key('message_m1')));
        await settle(tester);
        await tester.drag(
          find.byKey(const Key('message_m1')),
          const Offset(500, 0),
        );
        await settle(tester);
        expect(h.adapter.of('PATCH', '/mail/messages/m1'), hasLength(1));
      },
    );

    testWidgets('swipe left in Trash asks before deleting forever', (
      tester,
    ) async {
      await launch(tester);
      h.adapter.onJson(
        'GET',
        '/mail/messages',
        Fixtures.page([
          {...Fixtures.message(7), 'folder': 'trash'},
        ], total: 1),
      );
      h.container.read(selectedFolderProvider.notifier).select('trash');
      await settle(tester, 20);
      expect(find.byKey(const Key('message_m7')), findsOneWidget);

      await tester.drag(
        find.byKey(const Key('message_m7')),
        const Offset(-500, 0),
      );
      await settle(tester);
      expect(
        find.text('Письмо будет удалено безвозвратно. Продолжить?'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('delete_forever_cancel')));
      await settle(tester);
      expect(h.adapter.of('DELETE', '/mail/messages/m7'), isEmpty);

      await tester.drag(
        find.byKey(const Key('message_m7')),
        const Offset(-500, 0),
      );
      await settle(tester);
      await tester.tap(find.byKey(const Key('delete_forever_confirm')));
      await settle(tester);
      expect(h.adapter.of('DELETE', '/mail/messages/m7'), hasLength(1));
    });

    Future<void> fillComposer(WidgetTester tester) async {
      await tester.enterText(find.byKey(const Key('compose_to')), 'a@b.kz');
      await tester.enterText(find.byKey(const Key('compose_subject')), 'Тема');
      await tester.enterText(find.byKey(const Key('compose_body')), 'Текст');
      await tester.pump();
    }

    String fieldText(WidgetTester tester, String key) =>
        tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

    testWidgets(
      'undo send: draft saved first, «Отменить» reopens the composer intact and nothing is sent',
      (tester) async {
        await launch(tester);
        h.adapter.onJson('POST', '/mail/drafts', {
          'status': 'ok',
          'id': 'd1',
        }, status: 201);
        h.adapter.onJson('POST', '/mail/send', {
          'message_id': 'msg_a',
        }, status: 202);
        await push(
          tester,
          Routes.mailCompose,
          extra: const ComposeArgs.blank(),
        );
        await fillComposer(tester);

        await tester.tap(find.byKey(const Key('compose_send')));
        await settle(tester);
        expect(find.byType(ComposeScreen), findsNothing);
        expect(h.adapter.of('POST', '/mail/drafts').single.json, {
          'to': ['a@b.kz'],
          'cc': <String>[],
          'bcc': <String>[],
          'subject': 'Тема',
          'text': 'Текст',
          'html': '<div>Текст</div>',
        });
        expect(h.adapter.of('POST', '/mail/send'), isEmpty);
        expect(find.text('Письмо отправляется…'), findsOneWidget);

        await tester.tap(find.text('Отменить'));
        await settle(tester, 20);
        expect(find.byType(ComposeScreen), findsOneWidget);
        expect(fieldText(tester, 'compose_to'), 'a@b.kz');
        expect(fieldText(tester, 'compose_subject'), 'Тема');
        expect(fieldText(tester, 'compose_body'), 'Текст');
        expect(h.container.read(mailUndoSendProvider), isEmpty);

        await tester.pump(const Duration(seconds: 30));
        await settle(tester);
        expect(h.adapter.of('POST', '/mail/send'), isEmpty);
        expect(
          h.adapter.of('DELETE', '/mail/messages/d1'),
          isEmpty,
          reason: 'undo deletes nothing',
        );
      },
    );

    testWidgets(
      'undo send: after the delay the full form (reply, attachments) is sent exactly once and the draft removed',
      (tester) async {
        await launch(tester);
        unawaited(
          h.container
              .read(mailUxSettingsProvider.notifier)
              .update(const MailUxSettings(undoSendSeconds: 10)),
        );
        h.adapter.onJson('PUT', '/mail/drafts/d0', {
          'status': 'ok',
          'id': 'd1',
        });
        h.adapter.onJson('POST', '/mail/send', {
          'message_id': 'msg_a',
        }, status: 202);
        const snapshot = ComposeSnapshot(
          modeName: 'reply',
          to: 'a@b.kz',
          subject: 'Re: Тема',
          body: 'Ответ',
          inReplyTo: 'msg1@example.kz',
          draftId: 'd0',
          attachments: [
            ComposeAttachmentSnapshot(
              name: 'photo.jpg',
              size: 2048,
              staged: MailComposeAttachment(
                id: 'att_abc',
                filename: 'photo.jpg',
                contentType: 'image/jpeg',
                sizeBytes: 2048,
              ),
            ),
          ],
        );
        await push(
          tester,
          Routes.mailCompose,
          extra: ComposeArgs.restore(snapshot),
        );
        expect(find.text('photo.jpg'), findsOneWidget);
        await tester.tap(find.byKey(const Key('compose_send')));
        await settle(tester);
        expect(h.adapter.of('PUT', '/mail/drafts/d0'), hasLength(1));
        expect(h.adapter.of('POST', '/mail/attachments'), isEmpty);

        await tester.pump(const Duration(seconds: 8));
        expect(h.adapter.of('POST', '/mail/send'), isEmpty);
        await tester.pump(const Duration(seconds: 3));
        await settle(tester);
        expect(h.adapter.of('POST', '/mail/send').single.json, {
          'to': ['a@b.kz'],
          'subject': 'Re: Тема',
          'text': 'Ответ',
          'html': '<div>Ответ</div>',
          'in_reply_to': 'msg1@example.kz',
          'attachment_ids': ['att_abc'],
        });
        expect(h.adapter.of('DELETE', '/mail/messages/d1'), hasLength(1));
        expect(find.text('Письмо отправлено'), findsOneWidget);
        await tester.pump(const Duration(seconds: 30));
        await settle(tester);
        expect(h.adapter.of('POST', '/mail/send'), hasLength(1));
        expect(
          h.container.read(mailRecentRecipientsProvider),
          contains('a@b.kz'),
        );
      },
    );

    testWidgets('undo send off: sends immediately without a draft', (
      tester,
    ) async {
      await launch(tester);
      unawaited(
        h.container
            .read(mailUxSettingsProvider.notifier)
            .update(const MailUxSettings(undoSendSeconds: 0)),
      );
      h.adapter.onJson('POST', '/mail/send', {
        'message_id': 'msg_a',
      }, status: 202);
      await push(tester, Routes.mailCompose, extra: const ComposeArgs.blank());
      await fillComposer(tester);
      await tester.tap(find.byKey(const Key('compose_send')));
      await settle(tester, 20);
      expect(h.adapter.of('POST', '/mail/send'), hasLength(1));
      expect(h.adapter.of('POST', '/mail/drafts'), isEmpty);
    });

    testWidgets(
      'recipient autocomplete: directory colleague with position, pick fills the address',
      (tester) async {
        await launch(tester);
        final self = h.container.read(currentUserProvider)!.id;
        await tester.runAsync(
          () => h.container
              .read(contactsCacheProvider)
              .write(
                ownerId: self,
                contacts: const [
                  Contact(
                    id: 'u1',
                    email: 'bolat@example.kz',
                    displayName: 'Болат Сейтов',
                    position: 'Декан',
                    department: 'Деканат',
                  ),
                  Contact(
                    id: 'u2',
                    email: 'anna@example.kz',
                    displayName: 'Anna Smith',
                  ),
                ],
                savedAt: DateTime(2026, 9, 1),
              ),
        );
        await push(
          tester,
          Routes.mailCompose,
          extra: const ComposeArgs.blank(),
        );
        await tester.enterText(
          find.byKey(const Key('compose_to')),
          'x@y.kz, бол',
        );
        await settle(tester, 20);
        expect(
          find.byKey(const ValueKey('recipient_suggestion_bolat@example.kz')),
          findsOneWidget,
        );
        expect(find.textContaining('Декан · Деканат'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('recipient_suggestion_anna@example.kz')),
          findsNothing,
        );
        await tester.tap(
          find.byKey(const ValueKey('recipient_suggestion_bolat@example.kz')),
        );
        await settle(tester);
        expect(fieldText(tester, 'compose_to'), 'x@y.kz, bolat@example.kz, ');
        expect(
          find.byKey(const ValueKey('recipient_suggestion_bolat@example.kz')),
          findsNothing,
        );
      },
    );
  });
}
