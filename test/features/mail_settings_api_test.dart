import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/api/api_client.dart';
import 'package:xatbox_mobile/core/api/api_exception.dart';
import 'package:xatbox_mobile/features/calendar/domain/calendar_time.dart';
import 'package:xatbox_mobile/features/mail/data/mail_api.dart';
import 'package:xatbox_mobile/features/mail/data/mail_message_extras.dart';
import 'package:xatbox_mobile/features/mail/data/mail_models.dart';
import 'package:xatbox_mobile/features/mail/data/mail_repository.dart';
import 'package:xatbox_mobile/features/mail/data/mail_settings_models.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_providers.dart';
import 'package:xatbox_mobile/features/mail/presentation/settings/vacation_settings_screen.dart';

import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// The Mail API rejects unknown JSON fields: every body is compared whole.
void main() {
  late FakeHttpAdapter adapter;
  late MailApi api;

  setUpAll(CalendarZones.ensureInitialized);

  setUp(() {
    adapter = FakeHttpAdapter();
    api = MailApi(
      ApiClient(
        baseUrl: 'http://test.local/api/v1',
        userAgent: 'test',
        adapter: adapter,
        tokenReader: () => 'tok',
        onUnauthenticated: () {},
      ),
    );
  });

  group('signature', () {
    test('PUT /mail/signature sends exactly {text}', () async {
      adapter.onJson(
        'PUT',
        '/mail/signature',
        Fixtures.signature(text: 'Иван\nKazTBU', isDefault: false),
      );
      final saved = await api.updateSignature('Иван\nKazTBU');
      expect(adapter.of('PUT', '/mail/signature').single.json, {
        'text': 'Иван\nKazTBU',
      });
      expect(saved.isDefault, isFalse);
      expect(saved.text, 'Иван\nKazTBU');
    });

    test('SIGNATURE_TOO_LONG surfaces as ApiException', () async {
      adapter.onError('PUT', '/mail/signature', 400, 'SIGNATURE_TOO_LONG');
      await expectLater(
        api.updateSignature('x' * 3000),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'SIGNATURE_TOO_LONG'),
        ),
      );
    });

    test('preview lists the parts in send order', () async {
      adapter.onJson('GET', '/mail/signature-preview', Fixtures.signaturePreview());
      final p = await api.signaturePreview();
      expect(p.applied, isTrue);
      expect(p.appendedParts, ['Тест Пользователь', 'КазТБУ · +7 700 000 00 00']);

      adapter.onJson(
        'GET',
        '/mail/signature-preview',
        Fixtures.signaturePreview(personal: false, mandatory: false),
      );
      final none = await api.signaturePreview();
      expect(none.appendedParts, isEmpty, reason: 'non-mandatory org text is not appended');
    });
  });

  group('vacation', () {
    test('PUT /mail/vacation is a full replacement with exactly six fields', () async {
      adapter.onJson('PUT', '/mail/vacation', Fixtures.vacation(enabled: true));
      await api.updateVacation(
        const MailVacationUpdate(
          enabled: true,
          subject: '  Отпуск ',
          body: 'Нет на месте\r\nдо 22 сентября ',
          startsOn: '2026-09-15',
          endsOn: '2026-09-22',
          timeZone: 'Asia/Almaty',
        ),
      );
      expect(adapter.of('PUT', '/mail/vacation').single.json, {
        'enabled': true,
        'subject': 'Отпуск',
        'body': 'Нет на месте\nдо 22 сентября',
        'starts_on': '2026-09-15',
        'ends_on': '2026-09-22',
        'time_zone': 'Asia/Almaty',
      });

      await api.updateVacation(const MailVacationUpdate(enabled: false));
      expect(adapter.of('PUT', '/mail/vacation').last.json, {
        'enabled': false,
        'subject': '',
        'body': '',
        'starts_on': '',
        'ends_on': '',
        'time_zone': 'Asia/Almaty',
      });
    });

    test('client validation follows the server order', () {
      expect(
        validateVacation(MailVacationUpdate(enabled: false, subject: 'a' * 201)),
        VacationProblem.subjectTooLong,
      );
      expect(
        validateVacation(MailVacationUpdate(enabled: false, body: 'ж' * 4001)),
        VacationProblem.bodyTooLong,
      );
      expect(
        validateVacation(const MailVacationUpdate(enabled: true, body: '  ')),
        VacationProblem.bodyRequired,
      );
      expect(
        validateVacation(
          const MailVacationUpdate(
            enabled: true,
            body: 'x',
            startsOn: '2026-09-22',
            endsOn: '2026-09-15',
          ),
        ),
        VacationProblem.dates,
      );
      expect(
        validateVacation(
          const MailVacationUpdate(enabled: false, timeZone: 'Mars/Olympus'),
        ),
        VacationProblem.zone,
      );
      expect(
        validateVacation(
          const MailVacationUpdate(
            enabled: true,
            body: 'x',
            startsOn: '2026-09-15',
            endsOn: '2026-09-15',
          ),
        ),
        isNull,
      );
    });

    test('GET parses status and sync', () async {
      adapter.onJson('GET', '/mail/vacation', {
        ...Fixtures.vacation(enabled: true),
        'sync': {'state': 'failed'},
      });
      final v = await api.vacation();
      expect(v.activeNow, isTrue);
      expect(v.sync.isFailed, isTrue);
    });
  });

  group('sender rules', () {
    test('POST sends {value, note} (no list); note omitted when empty', () async {
      adapter.onJson(
        'POST',
        '/mail/sender-rules',
        Fixtures.senderRule(note: 'рассылка'),
        status: 201,
      );
      final rule = await api.addSenderRule(
        value: ' spam.example.com ',
        note: ' рассылка ',
      );
      expect(rule.pattern, 'spam.example.com');
      expect(adapter.of('POST', '/mail/sender-rules').single.json, {
        'value': 'spam.example.com',
        'note': 'рассылка',
      });

      await api.addSenderRule(value: '203.0.113.7');
      expect(adapter.of('POST', '/mail/sender-rules').last.json, {
        'value': '203.0.113.7',
      });
    });

    test('409 RULE_EXISTS and DELETE 204 with an empty body', () async {
      adapter.onError('POST', '/mail/sender-rules', 409, 'RULE_EXISTS');
      await expectLater(
        api.addSenderRule(value: 'spam.example.com'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'RULE_EXISTS')),
      );

      const id = '66666666-6666-4666-8666-666666666666';
      adapter.on('DELETE', '/mail/sender-rules/$id', (_) => const FakeResponse(204));
      await api.deleteSenderRule(id);
      final req = adapter.of('DELETE', '/mail/sender-rules/$id').single;
      expect(req.body, isEmpty);
    });

    test('GET parses rules, limit and sync', () async {
      adapter.onJson('GET', '/mail/sender-rules', {
        'rules': [
          Fixtures.senderRule(),
          Fixtures.senderRule(id: 'r2', kind: 'network', pattern: '198.51.100.0/24'),
        ],
        'limit': 500,
        'sync': {'state': 'pending'},
      });
      final list = await api.senderRules();
      expect(list.rules.map((r) => r.kind), ['domain', 'network']);
      expect(list.limit, 500);
      expect(list.sync.isPending, isTrue);
    });
  });

  group('bookmark folders', () {
    test('create sends exactly {name}; delete expects 200', () async {
      adapter.onJson('POST', '/mail/bookmark-folders', {
        'id': 'f1',
        'name': 'Проекты',
        'color': 'amber',
        'mailbox_id': 'x',
      }, status: 201);
      final f = await api.createBookmarkFolder('  Проекты ');
      expect(adapter.of('POST', '/mail/bookmark-folders').single.json, {
        'name': 'Проекты',
      });
      expect(f.folderType, 'bookmark:f1');

      adapter.onJson('DELETE', '/mail/bookmark-folders/f1', {'status': 'deleted'});
      await api.deleteBookmarkFolder('f1');
      expect(adapter.of('DELETE', '/mail/bookmark-folders/f1'), hasLength(1));

      adapter.onError('POST', '/mail/bookmark-folders', 409, 'FOLDER_EXISTS');
      await expectLater(
        api.createBookmarkFolder('Проекты'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'FOLDER_EXISTS')),
      );
    });
  });

  group('message extras', () {
    test('report phishing sends {kind: phishing} and moves to spam', () async {
      final h = await TestHarness.create();
      addTearDown(h.dispose);
      final repo = h.container.read(mailRepositoryProvider);
      final events = <MailEvent>[];
      repo.events.listen(events.add);
      h.adapter.onJson('POST', '/mail/messages/m1/report', {
        'kind': 'phishing',
        'folder': 'spam',
        'learned': true,
      });
      expect(await repo.report('m1', MailReportKind.phishing), 'spam');
      expect(h.adapter.of('POST', '/mail/messages/m1/report').single.json, {
        'kind': 'phishing',
      });
      await Future<void>.delayed(Duration.zero);
      expect(events.whereType<MailMessageRemoved>().single.movedTo, 'spam');
    });

    test('invitation respond: blob_id in query AND body, status only otherwise', () async {
      adapter.onJson(
        'POST',
        '/mail/messages/m1/calendar-invitation/respond',
        {'event_id': 'ev1', 'status': 'tentative'},
      );
      final res = await api.respondToInvitation(
        'm1',
        blobId: 'blob_ics',
        status: MailRsvp.tentative,
      );
      final req = adapter
          .of('POST', '/mail/messages/m1/calendar-invitation/respond')
          .single;
      expect(req.query, {'blob_id': 'blob_ics'});
      expect(req.json, {'blob_id': 'blob_ics', 'status': 'tentative'});
      expect(res.eventId, 'ev1');
    });

    test('invitation preview: query, parsing and ICS error codes', () async {
      adapter.onJson(
        'GET',
        '/mail/messages/m1/calendar-invitation',
        Fixtures.invitationPreview(eventId: 'ev1', status: 'accepted'),
      );
      final p = await api.calendarInvitation('m1', blobId: 'blob_ics');
      expect(
        adapter.of('GET', '/mail/messages/m1/calendar-invitation').single.query,
        {'blob_id': 'blob_ics'},
      );
      expect(p.invitation.method, MailInvitationMethod.request);
      expect(p.invitation.startsAt, DateTime.utc(2026, 9, 18, 9));
      expect(p.invitation.organizerLabel, 'Болат Сейтов');
      expect(p.eventId, 'ev1');
      expect(p.status, 'accepted');

      for (final (status, code) in const [
        (404, 'ICS_NOT_FOUND'),
        (400, 'INVALID_ICS'),
        (400, 'ICS_TOO_LARGE'),
      ]) {
        adapter.onError('GET', '/mail/messages/m2/calendar-invitation', status, code);
        await expectLater(
          api.calendarInvitation('m2'),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', code)),
        );
      }
      expect(
        adapter.of('GET', '/mail/messages/m2/calendar-invitation').first.query,
        isEmpty,
        reason: 'blob_id is optional',
      );
    });

    test('delivery events parse PostgreSQL timestamps; empty result', () async {
      adapter.onJson('GET', '/mail/messages/m1/events', {
        'status': 'partially_delivered',
        'recipients': [
          {'address': 'a@b.kz', 'status': 'delivered'},
          {'address': 'c@d.kz', 'status': 'failed', 'error': 'mailbox full'},
        ],
        'events': [
          {'type': 'email.accepted', 'created_at': '2026-08-20 08:49:50.801968+00'},
        ],
      });
      final r = await api.messageEvents('m1');
      expect(r.recipients.last.error, 'mailbox full');
      expect(
        r.events.single.createdAt,
        DateTime.utc(2026, 8, 20, 8, 49, 50, 801, 968),
      );

      adapter.onJson('GET', '/mail/messages/m2/events', {
        'status': '',
        'recipients': <Object>[],
        'events': <Object>[],
      });
      expect((await api.messageEvents('m2')).isEmpty, isTrue);
    });

    test('attachments recognised as calendar invitations', () {
      expect(MailAttachment.fromJson(Fixtures.icsAttachment()).isCalendarInvitation, isTrue);
      expect(
        MailAttachment.fromJson({
          ...Fixtures.attachment(),
          'filename': 'meeting',
          'content_type': 'TEXT/CALENDAR',
        }).isCalendarInvitation,
        isTrue,
      );
      expect(MailAttachment.fromJson(Fixtures.attachment()).isCalendarInvitation, isFalse);
    });
  });

  group('conversation mode', () {
    test('threads=1 is sent only for folders that support it', () {
      expect(
        const MailListQuery(threads: true).toQueryParameters()['threads'],
        '1',
      );
      expect(MailFolderType.supportsThreads('inbox'), isTrue);
      expect(MailFolderType.supportsThreads('drafts'), isFalse);
      expect(MailFolderType.supportsThreads('bookmarks'), isFalse);
      expect(MailFolderType.supportsThreads('bookmark:x'), isFalse);
    });

    test('the mode is persisted and restored', () async {
      final h = await TestHarness.create();
      addTearDown(h.dispose);
      final sub = h.container.listen(mailThreadsModeProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(h.container.read(mailThreadsModeProvider), isFalse);
      await h.container.read(mailThreadsModeProvider.notifier).set(true);
      expect(h.container.read(currentMailQueryProvider).threads, isTrue);
      sub.close();

      expect(await h.container.read(mailPrefsStoreProvider).readThreadsMode(), isTrue);
      h.container.invalidate(mailThreadsModeProvider);
      final sub2 = h.container.listen(mailThreadsModeProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(h.container.read(mailThreadsModeProvider), isTrue);
      sub2.close();
    });
  });
}
