import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/api/api_client.dart';
import 'package:xatbox_mobile/core/api/api_exception.dart';
import 'package:xatbox_mobile/features/mail/data/mail_api.dart';
import 'package:xatbox_mobile/features/mail/data/mail_models.dart';

import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';

void main() {
  late FakeHttpAdapter adapter;
  late MailApi api;

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

  group('GET /mail/messages', () {
    test('sends only documented query parameters', () async {
      adapter.onJson(
        'GET',
        '/mail/messages',
        Fixtures.page(Fixtures.messages(2), total: 2),
      );
      await api.listMessages(
        const MailListQuery(
          folder: 'inbox',
          q: ' отчёт ',
          unread: true,
          limit: 20,
          offset: 40,
        ),
      );
      final q = adapter.of('GET', '/mail/messages').single.query;
      expect(q, {
        'folder': 'inbox',
        'q': 'отчёт',
        'unread': '1',
        'limit': '20',
        'offset': '40',
      });
    });

    test(
      'bookmark:<id> ignores filters but always sends an explicit limit',
      () async {
        adapter.onJson(
          'GET',
          '/mail/messages',
          Fixtures.page(const [], total: 0),
        );
        await api.listMessages(
          const MailListQuery(
            folder: 'bookmark:abc',
            q: 'x',
            unread: true,
            starred: true,
            threads: true,
          ),
        );
        final q = adapter.of('GET', '/mail/messages').single.query;
        expect(q, {'folder': 'bookmark:abc', 'limit': '50', 'offset': '0'});
      },
    );

    test('limit is clamped to 1..100', () {
      expect(const MailListQuery(limit: 500).toQueryParameters()['limit'], 100);
      expect(const MailListQuery(limit: 0).toQueryParameters()['limit'], 1);
      expect(const MailListQuery(offset: -5).toQueryParameters()['offset'], 0);
    });

    test('parses both date formats and optional thread fields', () async {
      adapter.onJson('GET', '/mail/messages', {
        'messages': [
          {
            ...Fixtures.message(1),
            'date': '2026-08-20 08:49:50.801968+00',
            'thread_count': 3,
            'thread_unread': 1,
          },
          Fixtures.message(2),
        ],
        'total': 2,
        'limit': 50,
        'offset': 0,
      });
      final page = await api.listMessages(const MailListQuery());
      expect(
        page.messages[0].date,
        DateTime.utc(2026, 8, 20, 8, 49, 50, 801, 968),
      );
      expect(page.messages[0].threadCount, 3);
      expect(page.messages[0].threadUnread, 1);
      expect(page.messages[1].threadUnread, isNull);
      expect(page.messages[1].date, DateTime.utc(2026, 9, 12, 8));
    });

    test('NO_MAILBOX propagates as ApiException', () async {
      adapter.onError('GET', '/mail/messages', 404, 'NO_MAILBOX');
      await expectLater(
        api.listMessages(const MailListQuery()),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'NO_MAILBOX'),
        ),
      );
    });
  });

  group('paging rules', () {
    test('message mode: next = offset + length, stop at total', () {
      final p1 = MailMessagePage.fromJson(
        Fixtures.page(Fixtures.messages(50), total: 120, offset: 0),
      );
      expect(p1.computeNextOffset(), 50);
      final p3 = MailMessagePage.fromJson(
        Fixtures.page(
          Fixtures.messages(20, from: 101),
          total: 120,
          offset: 100,
        ),
      );
      expect(p3.computeNextOffset(), isNull);
      final empty = MailMessagePage.fromJson(
        Fixtures.page(const [], total: 120, offset: 100),
      );
      expect(empty.computeNextOffset(), isNull);
    });

    test(
      'conversation mode: use next_offset; stop when >= total or <= offset',
      () {
        expect(
          MailMessagePage.fromJson(
            Fixtures.page(
              Fixtures.messages(10),
              total: 100,
              offset: 0,
              nextOffset: 37,
            ),
          ).computeNextOffset(),
          37,
        );
        expect(
          MailMessagePage.fromJson(
            Fixtures.page(
              Fixtures.messages(10),
              total: 100,
              offset: 90,
              nextOffset: 100,
            ),
          ).computeNextOffset(),
          isNull,
        );
        expect(
          MailMessagePage.fromJson(
            Fixtures.page(
              Fixtures.messages(10),
              total: 100,
              offset: 40,
              nextOffset: 40,
            ),
          ).computeNextOffset(),
          isNull,
        );
      },
    );
  });

  group('mutations', () {
    test('PATCH sends only the given fields', () async {
      adapter.onJson('PATCH', '/mail/messages/m1', {'status': 'ok'});
      await api.patchMessage('m1', isStarred: true);
      expect(adapter.of('PATCH', '/mail/messages/m1').single.json, {
        'is_starred': true,
      });

      adapter.onJson('PATCH', '/mail/messages/m2', {'status': 'ok'});
      await api.patchMessage('m2', isRead: false, folder: 'trash');
      expect(adapter.of('PATCH', '/mail/messages/m2').single.json, {
        'is_read': false,
        'folder': 'trash',
      });
    });

    test('DELETE expects 200 and encodes the id', () async {
      adapter.onJson('DELETE', '/mail/messages/a%2Fb', {'status': 'ok'});
      await api.deleteMessage('a/b');
      expect(adapter.of('DELETE', '/mail/messages/a%2Fb'), hasLength(1));
    });

    test('report sends kind and returns the target folder', () async {
      adapter.onJson('POST', '/mail/messages/m1/report', {
        'kind': 'ham',
        'folder': 'inbox',
        'learned': false,
      });
      expect(await api.reportMessage('m1', MailReportKind.ham), 'inbox');
      expect(adapter.of('POST', '/mail/messages/m1/report').single.json, {
        'kind': 'ham',
      });
    });
  });

  group('compose', () {
    test(
      'POST /mail/send: only documented, non-empty fields; 202 → msg id',
      () async {
        adapter.onJson('POST', '/mail/send', {
          'message_id': 'msg_abc',
        }, status: 202);
        final id = await api.send(
          const MailSendRequest(
            to: ['a@b.kz'],
            subject: 'S',
            text: 'T',
            inReplyTo: 'msg1@example.kz',
            attachmentIds: ['att_x'],
          ),
        );
        expect(id, 'msg_abc');
        final body = adapter.of('POST', '/mail/send').single.json;
        expect(body, {
          'to': ['a@b.kz'],
          'subject': 'S',
          'text': 'T',
          'in_reply_to': 'msg1@example.kz',
          'attachment_ids': ['att_x'],
        });
        expect(body.containsKey('from'), isFalse);
        expect(body.containsKey('references'), isFalse);
      },
    );

    test('INVALID_MESSAGE carries the server detail', () async {
      adapter.on(
        'POST',
        '/mail/send',
        (_) => FakeResponse.error(
          400,
          'INVALID_MESSAGE',
          message: 'too many recipients (max 100)',
        ),
      );
      await expectLater(
        api.send(const MailSendRequest(to: ['a@b.kz'])),
        throwsA(
          isA<ApiException>().having(
            (e) => e.serverMessage,
            'msg',
            contains('max 100'),
          ),
        ),
      );
    });

    test(
      'drafts: create returns id (201), update returns the NEW id',
      () async {
        adapter.onJson('POST', '/mail/drafts', {'id': 'd1'}, status: 201);
        adapter.onJson('PUT', '/mail/drafts/d1', {'status': 'ok', 'id': 'd2'});
        expect(
          await api.createDraft(
            const MailDraftRequest(to: ['a@b.kz'], subject: 's'),
          ),
          'd1',
        );
        expect(
          await api.updateDraft('d1', const MailDraftRequest(subject: 's2')),
          'd2',
        );
        expect(adapter.of('POST', '/mail/drafts').single.json, {
          'to': ['a@b.kz'],
          'cc': <String>[],
          'bcc': <String>[],
          'subject': 's',
          'text': '',
        });
      },
    );

    test(
      'attachment upload is multipart with the file in field "file"',
      () async {
        adapter.onJson(
          'POST',
          '/mail/attachments',
          Fixtures.attachment(id: 'att_new', name: 'a.txt'),
          status: 201,
        );
        final staged = await api.uploadAttachment(
          filename: 'a.txt',
          bytes: Uint8List.fromList('hello'.codeUnits),
        );
        expect(staged.id, 'att_new');
        final req = adapter.of('POST', '/mail/attachments').single;
        expect(
          req.headers['content-type'].toString(),
          contains('multipart/form-data'),
        );
        expect(req.body, contains('name="file"'));
        expect(req.body, contains('filename="a.txt"'));
        expect(req.body, contains('hello'));
      },
    );

    test('ATTACHMENT_TOO_LARGE (413) is an ApiException', () async {
      adapter.onError('POST', '/mail/attachments', 413, 'ATTACHMENT_TOO_LARGE');
      await expectLater(
        api.uploadAttachment(filename: 'x', bytes: Uint8List(1)),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'ATTACHMENT_TOO_LARGE',
          ),
        ),
      );
    });
  });

  group('summary', () {
    test('parses all folder kinds and computes the inbox badge', () async {
      adapter.onJson(
        'GET',
        '/mail/summary',
        Fixtures.summary(inboxUnread: 3, smartUnread: 2),
      );
      final s = await api.summary();
      expect(s.folders.map((f) => f.type), contains('custom:f0f0'));
      expect(s.folders.map((f) => f.type), contains('bookmark:b1b1'));
      expect(s.folderByType('spam')!.name, 'Junk');
      expect(
        s.inboxUnreadTotal,
        5,
        reason: 'smart folder unread is subtracted server-side',
      );
    });
  });

  group('detail', () {
    test('parses recipients, attachments, thread; office docs flagged for PDF preview', () async {
      adapter.onJson(
        'GET',
        '/mail/messages/m1',
        Fixtures.detail(attachments: [Fixtures.attachment()]),
      );
      final d = await api.getMessage('m1');
      expect(d.to, ['user@example.kz']);
      expect(d.cc, ['cc@example.kz']);
      expect(d.attachments.single.isOfficeDocument, isTrue);
      expect(d.thread, hasLength(1));
      expect(d.deleteIsPermanent, isFalse);
    });
  });
}
