import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/api/api_exception.dart';
import 'package:xatbox_mobile/core/storage/cache_policy.dart';
import 'package:xatbox_mobile/features/mail/data/mail_cache.dart';
import 'package:xatbox_mobile/features/mail/data/mail_models.dart';
import 'package:xatbox_mobile/features/mail/data/mail_repository.dart';
import 'package:xatbox_mobile/features/mail/presentation/compose_screen.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_providers.dart';

import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

void main() {
  late TestHarness h;
  tearDown(() => h.dispose());

  group('MailCache', () {
    test(
      'keeps at most one page per folder and a bounded LRU of messages',
      () async {
        h = await TestHarness.create();
        final cache = MailCache(
          h.db,
          policy: const CachePolicy(
            maxListItemsPerFolder: 3,
            maxCachedMessages: 2,
          ),
        );

        final items = Fixtures.messages(5).map(MailListItem.fromJson).toList();
        await cache.writeList('inbox', items, total: 50);
        final list = await cache.readList('inbox');
        expect(list!.items, hasLength(3));
        expect(list.total, 50);

        for (final id in ['m1', 'm2', 'm3']) {
          await cache.writeMessage(
            MailMessageDetail.fromJson(Fixtures.detail(id: id)),
          );
        }
        final stats = await cache.stats();
        expect(stats.cachedMessages, 2);
        expect(await cache.readMessage('m1'), isNull, reason: 'oldest evicted');
        expect(await cache.readMessage('m3'), isNotNull);

        await cache.patchListItem('m2', isRead: true, isStarred: true);
        final patched = (await cache.readList('inbox'))!.items
            .firstWhere((i) => i.id == 'm2');
        expect(patched.isRead, isTrue);
        expect(patched.isStarred, isTrue);

        await cache.removeListItem('m2');
        expect(
          (await cache.readList('inbox'))!.items.map((i) => i.id),
          isNot(contains('m2')),
        );

        await cache.clear();
        expect(await cache.readList('inbox'), isNull);
        expect((await cache.stats()).cachedMessages, 0);
      },
    );
  });

  group('MailRepository', () {
    test('getMessage: network first, cache fallback when offline', () async {
      h = await TestHarness.create();
      final repo = h.container.read(mailRepositoryProvider);
      h.adapter.onJson('GET', '/mail/messages/m1', Fixtures.detail());
      final first = await repo.getMessage('m1');
      expect(first.fromCache, isFalse);

      h.adapter.onOffline('GET', '/mail/messages/m1');
      final second = await repo.getMessage('m1');
      expect(second.fromCache, isTrue);
      expect(second.detail.subject, 'Тема письма 1');

      h.adapter.onOffline('GET', '/mail/messages/none');
      await expectLater(
        repo.getMessage('none'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('mutations emit events and update the cached list', () async {
      h = await TestHarness.create();
      final repo = h.container.read(mailRepositoryProvider);
      final events = <MailEvent>[];
      repo.events.listen(events.add);

      h.adapter.onJson(
        'GET',
        '/mail/messages',
        Fixtures.page(Fixtures.messages(2), total: 2),
      );
      await repo.fetchPage(const MailListQuery());
      h.adapter.onJson('PATCH', '/mail/messages/m1', {'status': 'ok'});
      await repo.setRead('m1', true);
      h.adapter.onJson('DELETE', '/mail/messages/m2', {'status': 'ok'});
      await repo.delete('m2', permanent: false);
      await Future<void>.delayed(Duration.zero);

      expect(events.whereType<MailFlagsChanged>().single.id, 'm1');
      expect(events.whereType<MailMessageRemoved>().single.movedTo, 'trash');
      expect(events.whereType<MailSummaryStale>(), hasLength(2));
      final cached = await repo.cachedFirstPage(const MailListQuery());
      expect(cached!.items.map((i) => i.id), ['m1']);
      expect(cached.items.single.isRead, isTrue);
    });

    test('send from a draft deletes the draft copy afterwards', () async {
      h = await TestHarness.create();
      final repo = h.container.read(mailRepositoryProvider);
      h.adapter.onJson('POST', '/mail/send', {
        'message_id': 'msg_1',
      }, status: 202);
      h.adapter.onJson('DELETE', '/mail/messages/d1', {'status': 'ok'});
      await repo.send(
        const MailSendRequest(to: ['a@b.kz']),
        draftIdToDelete: 'd1',
      );
      expect(h.adapter.of('DELETE', '/mail/messages/d1'), hasLength(1));
      expect(
        h.adapter.of('POST', '/mail/drafts/d1/send'),
        isEmpty,
        reason: 'draft send loses HTML/attachments',
      );
    });
  });

  group('MailListNotifier', () {
    test(
      'loads page 1, then loadMore appends page 2 and stops at total',
      () async {
        h = await TestHarness.create();
        h.adapter.on('GET', '/mail/messages', (r) {
          final offset = int.parse(r.query['offset'] as String);
          return FakeResponse(
            200,
            json: offset == 0
                ? Fixtures.page(
                    Fixtures.messages(2),
                    total: 3,
                    limit: 2,
                    offset: 0,
                  )
                : Fixtures.page(
                    Fixtures.messages(1, from: 3),
                    total: 3,
                    limit: 2,
                    offset: 2,
                  ),
          );
        });
        const query = MailListQuery(limit: 2);
        final sub = h.container.listen(mailListProvider(query), (_, _) {});
        await _settle();
        var state = h.container.read(mailListProvider(query));
        expect(state.status, MailListStatus.ready);
        expect(state.items.map((i) => i.id), ['m1', 'm2']);
        expect(state.hasMore, isTrue);

        await h.container.read(mailListProvider(query).notifier).loadMore();
        state = h.container.read(mailListProvider(query));
        expect(state.items.map((i) => i.id), ['m1', 'm2', 'm3']);
        expect(state.hasMore, isFalse);
        sub.close();
      },
    );

    test(
      'offline with cached page shows cached rows flagged fromCache',
      () async {
        h = await TestHarness.create();
        final repo = h.container.read(mailRepositoryProvider);
        h.adapter.onJson(
          'GET',
          '/mail/messages',
          Fixtures.page(Fixtures.messages(2), total: 2),
        );
        await repo.fetchPage(const MailListQuery());
        h.adapter.onOffline('GET', '/mail/messages');

        const query = MailListQuery();
        final sub = h.container.listen(mailListProvider(query), (_, _) {});
        await _settle();
        final state = h.container.read(mailListProvider(query));
        expect(state.items, hasLength(2));
        expect(state.fromCache, isTrue);
        expect(state.error, isA<NetworkException>());
        sub.close();
      },
    );
  });

  group('ComposeDraftValues', () {
    final original = MailMessageDetail.fromJson({
      ...Fixtures.detail(attachments: [Fixtures.attachment()]),
      'recipients': [
        {'kind': 'to', 'address': 'user@example.kz'},
        {'kind': 'to', 'address': 'other@example.kz'},
        {'kind': 'cc', 'address': 'cc@example.kz'},
      ],
    });
    String header(MailMessageDetail m) => 'hdr';

    test('reply targets the sender and threads by RFC Message-ID', () {
      final v = ComposeDraftValues.from(
        ComposeArgs(mode: ComposeMode.reply, original: original),
        selfEmail: 'user@example.kz',
        quoteHeader: header,
        forwardHeader: 'fwd',
      );
      expect(v.to, ['sender1@example.kz']);
      expect(v.subject, 'Re: Тема письма 1');
      expect(v.inReplyTo, 'msg1@example.kz');
      expect(v.body, contains('> Привет!'));
    });

    test('blank message to a contact prefills the recipient', () {
      final v = ComposeDraftValues.from(
        const ComposeArgs.to(['colleague@example.kz']),
        selfEmail: 'user@example.kz',
        quoteHeader: header,
        forwardHeader: 'fwd',
      );
      expect(v.to, ['colleague@example.kz']);
      expect(v.subject, isEmpty);
      expect(v.body, isEmpty);
    });

    test('reply all excludes self, keeps other recipients and cc', () {
      final v = ComposeDraftValues.from(
        ComposeArgs(mode: ComposeMode.replyAll, original: original),
        selfEmail: 'user@example.kz',
        quoteHeader: header,
        forwardHeader: 'fwd',
      );
      expect(v.to, ['sender1@example.kz', 'other@example.kz']);
      expect(v.cc, ['cc@example.kz']);
    });

    test('forward has no recipients, Fwd: subject and carries attachments to re-upload', () {
      final v = ComposeDraftValues.from(
        ComposeArgs(mode: ComposeMode.forward, original: original),
        selfEmail: 'user@example.kz',
        quoteHeader: header,
        forwardHeader: 'fwd',
      );
      expect(v.to, isEmpty);
      expect(v.subject, 'Fwd: Тема письма 1');
      expect(v.inReplyTo, isNull);
      expect(v.forwardedAttachments.single.id, 'blob1');
    });

    test('validation mirrors the send rules', () {
      expect(
        ComposeValidation.check(
          to: const [],
          cc: const [],
          bcc: const [],
          subject: '',
          attachmentCount: 0,
        ).error,
        ComposeError.recipientsRequired,
      );
      expect(
        ComposeValidation.check(
          to: const ['a@b.kz'],
          cc: const ['Name <x@y.kz>'],
          bcc: const [],
          subject: '',
          attachmentCount: 0,
        ).invalidAddress,
        'Name <x@y.kz>',
      );
      expect(
        ComposeValidation.check(
          to: const ['a@b.kz'],
          cc: const [],
          bcc: const [],
          subject: 'ж' * 251,
          attachmentCount: 0,
        ).error,
        ComposeError.subjectTooLong,
        reason: '251 Cyrillic letters = 502 bytes',
      );
      expect(
        ComposeValidation.check(
          to: const ['a@b.kz'],
          cc: const [],
          bcc: const [],
          subject: 'ok',
          attachmentCount: 21,
        ).error,
        ComposeError.tooManyAttachments,
      );
      expect(
        ComposeValidation.check(
          to: const ['a@b.kz'],
          cc: const [],
          bcc: const [],
          subject: 'ok',
          attachmentCount: 1,
        ).error,
        isNull,
      );
    });
  });
}

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
