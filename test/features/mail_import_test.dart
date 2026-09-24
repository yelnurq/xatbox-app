import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/api/api_client.dart';
import 'package:xatbox_mobile/core/api/api_exception.dart';
import 'package:xatbox_mobile/features/mail/data/mail_api.dart';
import 'package:xatbox_mobile/features/mail/data/mail_settings_models.dart';
import 'package:xatbox_mobile/features/mail/presentation/settings/mail_import_screen.dart';

import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Importing one's own mail: `GET /mail/imports`, `POST /mail/import`,
/// `POST /mail/imports/{id}/retry`, `DELETE /mail/imports/{id}`.
Map<String, dynamic> _import({
  String id = 'imp-1',
  String status = 'running',
  String filename = 'ivanov@kaztbu.edu.kz.tgz',
  int total = 100,
  int imported = 40,
  int skipped = 5,
  int failed = 0,
  int notMail = 3,
  String currentFolder = 'Входящие/2024',
  String error = '',
  bool fileAvailable = true,
}) => {
  'id': id,
  'target_address': 'ivanov@kaztbu.edu.kz',
  'mailbox_created': false,
  'user_created': false,
  'password_imported': false,
  'format': 'tgz',
  'filename': filename,
  'size_bytes': 5 * 1024 * 1024,
  'status': status,
  'messages_total': total,
  'messages_imported': imported,
  'messages_skipped': skipped,
  'messages_failed': failed,
  'items_not_mail': notMail,
  'bytes_imported': 1024,
  'current_folder': currentFolder,
  'folders': {
    'Входящие': {'imported': imported, 'skipped': skipped, 'failed': failed},
  },
  'error': error,
  'file_available': fileAvailable,
  'created_at': '2026-09-01T10:00:00Z',
};

void main() {
  group('archive name', () {
    test('an export is accepted only under its own mailbox name', () {
      const box = 'ivanov@kaztbu.edu.kz';
      expect(
        MailArchiveImport.namedFor('ivanov@kaztbu.edu.kz.tgz', box),
        isTrue,
      );
      expect(
        MailArchiveImport.namedFor('IVANOV@KazTBU.edu.kz.tar.gz', box),
        isTrue,
      );
      // Somebody else's export would put their mail in this mailbox.
      expect(
        MailArchiveImport.namedFor('petrov@kaztbu.edu.kz.tgz', box),
        isFalse,
      );
      expect(MailArchiveImport.namedFor('mail.tgz', box), isFalse);
    });
  });

  group('api', () {
    late FakeHttpAdapter adapter;
    late MailApi api;
    late Directory tmp;

    setUp(() async {
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
      tmp = await Directory.systemTemp.createTemp('xatbox_import_test');
      addTearDown(() => tmp.delete(recursive: true));
    });

    test('GET /mail/imports reads the counters and the mailbox', () async {
      adapter.onJson('GET', '/mail/imports', {
        'imports': [_import()],
        'mailbox': 'ivanov@kaztbu.edu.kz',
      });
      final list = await api.mailImports();
      expect(list.mailbox, 'ivanov@kaztbu.edu.kz');
      expect(list.hasActive, isTrue);
      final one = list.imports.single;
      expect(one.status, 'running');
      expect(one.messagesImported, 40);
      expect(one.messagesSkipped, 5);
      expect(one.itemsNotMail, 3);
      expect(one.currentFolder, 'Входящие/2024');
      expect(one.folders['Входящие']?.imported, 40);
      // 40 imported + 5 already here + 0 failed of 100.
      expect(one.progress, closeTo(0.45, 0.001));
    });

    test('a finished list stops the page polling', () async {
      adapter.onJson('GET', '/mail/imports', {
        'imports': [_import(status: 'done', imported: 100, skipped: 0)],
        'mailbox': 'ivanov@kaztbu.edu.kz',
      });
      final list = await api.mailImports();
      expect(list.hasActive, isFalse);
      expect(list.imports.single.progress, 1);
    });

    test('POST /mail/import sends the archive as multipart "file"', () async {
      final file = File('${tmp.path}/ivanov@kaztbu.edu.kz.tgz')
        ..writeAsBytesSync(List<int>.filled(2048, 7));
      adapter.onJson(
        'POST',
        '/mail/import',
        _import(status: 'queued', imported: 0, skipped: 0, total: 0),
        status: 201,
      );
      var seen = 0;
      final created = await api.uploadMailImport(
        path: file.path,
        filename: 'ivanov@kaztbu.edu.kz.tgz',
        onProgress: (sent, total) => seen = total,
      );
      expect(created.status, 'queued');
      expect(seen, greaterThan(0));
      final sent = adapter.of('POST', '/mail/import').single;
      expect(
        sent.headers['content-type'].toString(),
        contains('multipart/form-data'),
      );
      expect(sent.body, contains('name="file"'));
      expect(sent.body, contains('ivanov@kaztbu.edu.kz.tgz'));
    });

    test('an archive larger than the limit surfaces its code', () async {
      final file = File('${tmp.path}/ivanov@kaztbu.edu.kz.tgz')
        ..writeAsBytesSync(const [1, 2, 3]);
      adapter.onError('POST', '/mail/import', 413, 'ARCHIVE_TOO_LARGE');
      await expectLater(
        api.uploadMailImport(
          path: file.path,
          filename: 'ivanov@kaztbu.edu.kz.tgz',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'ARCHIVE_TOO_LARGE',
          ),
        ),
      );
    });

    test('retry and delete answer 204 with an empty body', () async {
      adapter.onJson('POST', '/mail/imports/imp-1/retry', null, status: 204);
      adapter.onJson('DELETE', '/mail/imports/imp-1', null, status: 204);
      await api.retryMailImport('imp-1');
      await api.deleteMailImport('imp-1');
      expect(adapter.of('POST', '/mail/imports/imp-1/retry'), hasLength(1));
      expect(adapter.of('DELETE', '/mail/imports/imp-1'), hasLength(1));
    });
  });

  group('screen', () {
    late TestHarness h;
    late Directory tmp;

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWidget(const MailImportScreen(), container: h.container),
      );
      await tester.pumpAndSettle();
    }

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('xatbox_import_widget');
      addTearDown(() => tmp.delete(recursive: true));
    });

    tearDown(() => h.dispose());

    testWidgets('an archive named for somebody else is refused before the '
        'upload starts', (tester) async {
      final file = File('${tmp.path}/petrov@kaztbu.edu.kz.tgz')
        ..writeAsBytesSync(const [1, 2, 3]);
      h = await TestHarness.create(
        storedToken: Fixtures.token,
        overrides: [
          mailImportFilePickerProvider.overrideWithValue(
            () async =>
                (name: 'petrov@kaztbu.edu.kz.tgz', path: file.path, size: 3),
          ),
        ],
      );
      h.stubSignedIn();
      h.adapter.onJson('GET', '/mail/imports', {
        'imports': <Object>[],
        'mailbox': 'ivanov@kaztbu.edu.kz',
      });
      await open(tester);

      await tester.tap(find.byKey(const Key('mail_import_pick')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mail_import_start')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('ivanov@kaztbu.edu.kz.tgz'),
        findsOneWidget,
        reason: 'the message names the file that would be accepted',
      );
      expect(
        h.adapter.of('POST', '/mail/import'),
        isEmpty,
        reason: 'not a byte of somebody else\'s export leaves the machine',
      );
    });

    testWidgets(
      'the person\'s own archive is uploaded and the list refreshes',
      (tester) async {
        final file = File('${tmp.path}/ivanov@kaztbu.edu.kz.tgz')
          ..writeAsBytesSync(List<int>.filled(512, 3));
        h = await TestHarness.create(
          storedToken: Fixtures.token,
          overrides: [
            mailImportFilePickerProvider.overrideWithValue(
              () async => (
                name: 'ivanov@kaztbu.edu.kz.tgz',
                path: file.path,
                size: 512,
              ),
            ),
          ],
        );
        h.stubSignedIn();
        h.adapter.onQueue('GET', '/mail/imports', [
          const FakeResponse(
            200,
            json: {'imports': <Object>[], 'mailbox': 'ivanov@kaztbu.edu.kz'},
          ),
          FakeResponse(
            200,
            json: {
              'imports': [_import(status: 'queued', imported: 0, skipped: 0)],
              'mailbox': 'ivanov@kaztbu.edu.kz',
            },
          ),
        ]);
        h.adapter.onJson(
          'POST',
          '/mail/import',
          _import(status: 'queued', imported: 0, skipped: 0),
          status: 201,
        );
        await open(tester);

        await tester.tap(find.byKey(const Key('mail_import_pick')));
        await tester.pumpAndSettle();
        // The archive is streamed off the disk, which is real I/O and needs
        // the real clock.
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const Key('mail_import_start')));
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();

        expect(h.adapter.of('POST', '/mail/import'), hasLength(1));
        expect(find.byKey(const ValueKey('mail_import_imp-1')), findsOneWidget);
      },
    );

    testWidgets(
      'a failed import offers a retry while its file is still there',
      (tester) async {
        h = await TestHarness.create(storedToken: Fixtures.token);
        h.stubSignedIn();
        h.adapter.onJson('GET', '/mail/imports', {
          'imports': [
            _import(status: 'failed', error: 'разбор архива прервался'),
          ],
          'mailbox': 'ivanov@kaztbu.edu.kz',
        });
        h.adapter.onJson(
          'POST',
          '/mail/imports/imp-1/retry',
          null,
          status: 204,
        );
        await open(tester);

        expect(find.text('разбор архива прервался'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('mail_import_retry_imp-1')));
        await tester.pumpAndSettle();
        expect(h.adapter.of('POST', '/mail/imports/imp-1/retry'), hasLength(1));
      },
    );

    testWidgets('a running import cannot be deleted out from under itself', (
      tester,
    ) async {
      h = await TestHarness.create(storedToken: Fixtures.token);
      h.stubSignedIn();
      h.adapter.onJson('GET', '/mail/imports', {
        'imports': [_import()],
        'mailbox': 'ivanov@kaztbu.edu.kz',
      });
      await open(tester);

      expect(
        find.byKey(const ValueKey('mail_import_delete_imp-1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('mail_import_retry_imp-1')),
        findsNothing,
      );
    });
  });
}
