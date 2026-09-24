import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/api/api_client.dart';
import 'package:xatbox_mobile/core/api/api_exception.dart';
import 'package:xatbox_mobile/core/routing/deep_links.dart';
import 'package:xatbox_mobile/core/routing/link_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/core/storage/app_database.dart';
import 'package:xatbox_mobile/features/official/data/official_api.dart';
import 'package:xatbox_mobile/features/official/data/official_cache.dart';
import 'package:xatbox_mobile/features/official/data/official_models.dart';
import 'package:xatbox_mobile/features/official/data/official_repository.dart';

import '../helpers/fake_http.dart';

Map<String, dynamic> _message({
  String id = 'o1',
  bool ack = false,
  String? readAt,
  String? acknowledgedAt,
}) => {
  'id': id,
  'sender_name': 'Директор',
  'sender_role': 'org_admin',
  'title': 'Приказ',
  'body': '<b>не HTML</b>\nвторая строка',
  'requires_acknowledgement': ack,
  'created_at': '2026-09-14 09:00:00+00',
  'read_at': ?readAt,
  'acknowledged_at': ?acknowledgedAt,
};

void main() {
  group('OfficialMessage.fromJson', () {
    test('parses PostgreSQL timestamptz text and keeps the body verbatim', () {
      final m = OfficialMessage.fromJson(
        _message(
          ack: true,
          readAt: '2026-09-14 10:21:33.123456+00',
          acknowledgedAt: '2026-09-14 12:00:00+05',
        ),
      );
      expect(m.createdAt, DateTime.utc(2026, 9, 14, 9));
      expect(m.readAt, DateTime.utc(2026, 9, 14, 10, 21, 33, 123, 456));
      expect(m.acknowledgedAt, DateTime.utc(2026, 9, 14, 7));
      expect(m.body, '<b>не HTML</b>\nвторая строка');
      expect(m.isRead, isTrue);
      expect(m.awaitsAcknowledgement, isFalse);
    });

    test('omitted read_at / acknowledged_at mean unread, not acknowledged', () {
      final m = OfficialMessage.fromJson(_message(ack: true));
      expect(m.readAt, isNull);
      expect(m.acknowledgedAt, isNull);
      expect(m.isRead, isFalse);
      expect(m.awaitsAcknowledgement, isTrue);
    });

    test('tolerates missing optional-in-practice fields', () {
      final m = OfficialMessage.fromJson({'id': 'x'});
      expect(m.title, '');
      expect(m.requiresAcknowledgement, isFalse);
      expect(m.createdAt, isNull);
    });

    test('cache round trip', () {
      final m = OfficialMessage.fromJson(
        _message(ack: true, readAt: '2026-09-14 10:00:00+00'),
      );
      final back = OfficialMessage.fromJson(m.toJson());
      expect(back.readAt, m.readAt);
      expect(back.createdAt, m.createdAt);
      expect(back.acknowledgedAt, isNull);
      expect(back.toJson().containsKey('acknowledged_at'), isFalse);
    });

    test('draft sends only documented keys', () {
      expect(
        const OfficialDraft(
          title: ' T ',
          body: ' B ',
          wholeOrganization: true,
          departmentIds: ['d1'],
        ).toJson(),
        {
          'title': 'T',
          'body': 'B',
          'requires_acknowledgement': false,
          'whole_organization': true,
        },
      );
      expect(
        const OfficialDraft(
          title: 'T',
          body: 'B',
          requiresAcknowledgement: true,
          departmentIds: ['d1'],
          userIds: ['u1'],
        ).toJson(),
        {
          'title': 'T',
          'body': 'B',
          'requires_acknowledgement': true,
          'department_ids': ['d1'],
          'user_ids': ['u1'],
        },
      );
    });
  });

  group('OfficialApi', () {
    late FakeHttpAdapter adapter;
    late OfficialApi api;

    setUp(() {
      adapter = FakeHttpAdapter();
      api = OfficialApi(
        ApiClient(
          baseUrl: 'http://test.local/api/v1',
          userAgent: 'test',
          adapter: adapter,
          tokenReader: () => 'tok',
          onUnauthenticated: () {},
        ),
      );
    });

    test('GET /official', () async {
      adapter.onJson('GET', '/official', {
        'messages': [_message(id: 'a'), _message(id: 'b', ack: true)],
      });
      final list = await api.list();
      expect(list.map((m) => m.id), ['a', 'b']);
      expect(list[1].requiresAcknowledgement, isTrue);
    });

    test('read and acknowledge expect 204 without a body', () async {
      adapter.onPattern(
        'POST',
        r'^/official/[^/]+/(read|acknowledge)$',
        (_) => const FakeResponse(204),
      );
      await api.markRead('o1');
      await api.acknowledge('o1');
      expect(adapter.of('POST', '/official/o1/read').single.body, isEmpty);
      expect(adapter.of('POST', '/official/o1/acknowledge'), hasLength(1));
    });

    test('acknowledge 404 surfaces OFFICIAL_NOT_FOUND', () async {
      adapter.onError(
        'POST',
        '/official/o1/acknowledge',
        404,
        'OFFICIAL_NOT_FOUND',
      );
      expect(
        api.acknowledge('o1'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'OFFICIAL_NOT_FOUND',
          ),
        ),
      );
    });

    test('POST /official 201', () async {
      adapter.onJson('POST', '/official', {
        'id': 'new',
        'recipient_count': 7,
      }, status: 201);
      final created = await api.create(
        const OfficialDraft(title: 'T', body: 'B', userIds: ['u1']),
      );
      expect(created.id, 'new');
      expect(created.recipientCount, 7);
      expect(adapter.of('POST', '/official').single.json['user_ids'], ['u1']);
    });

    test(
      'POST /official empty 200 (undecodable body) is not a success',
      () async {
        adapter.on('POST', '/official', (_) => const FakeResponse(200));
        expect(
          api.create(
            const OfficialDraft(title: 'T', body: 'B', userIds: ['u1']),
          ),
          throwsA(isA<UnexpectedApiException>()),
        );
      },
    );

    test('stats and directory lookups', () async {
      adapter.onJson('GET', '/official/o1/stats', {
        'sent': 10,
        'delivered': 10,
        'read': 4,
        'acknowledged': 2,
      });
      adapter.onJson('GET', '/departments', {
        'departments': [
          {'id': 'd2', 'name': 'Бухгалтерия', 'status': 'active'},
          {'id': 'd1', 'name': 'Архив', 'status': 'archived'},
          {'id': 'd3', 'name': 'АХО', 'status': 'active'},
        ],
      });
      adapter.onJson('GET', '/directory/users', {
        'users': [
          {
            'id': 'u1',
            'display_name': 'Иван',
            'email': 'i@x.kz',
            'mailbox_address': 'i@x.kz',
            'is_online': false,
          },
        ],
        'limit': 100,
      });
      final stats = await api.stats('o1');
      expect([stats.sent, stats.read, stats.acknowledged], [10, 4, 2]);
      expect((await api.departments()).map((d) => d.id), ['d3', 'd2']);
      final users = await api.searchUsers(' ив ');
      expect(users.single.id, 'u1');
      expect(adapter.of('GET', '/directory/users').single.query['q'], 'ив');
    });
  });

  group('OfficialRepository', () {
    test(
      'serves the cached list offline and remembers sent messages',
      () async {
        final db = await AppDatabase.inMemory();
        addTearDown(db.close);
        final adapter = FakeHttpAdapter();
        final repo = OfficialRepository(
          api: OfficialApi(
            ApiClient(
              baseUrl: 'http://test.local/api/v1',
              userAgent: 'test',
              adapter: adapter,
              tokenReader: () => 'tok',
              onUnauthenticated: () {},
            ),
          ),
          cache: OfficialCache(db),
          selfId: () => 'me',
        );
        adapter.onJson('GET', '/official', {
          'messages': [_message()],
        });
        expect((await repo.load()).fromCache, isFalse);

        adapter.onOffline('GET', '/official');
        final offline = await repo.load();
        expect(offline.fromCache, isTrue);
        expect(offline.messages.single.id, 'o1');

        adapter.onError('GET', '/official', 403, 'FORBIDDEN');
        expect(repo.load(), throwsA(isA<ApiException>()));

        adapter.onJson('POST', '/official', {
          'id': 's1',
          'recipient_count': 3,
        }, status: 201);
        await repo.create(
          const OfficialDraft(title: 'T', body: 'B', wholeOrganization: true),
        );
        final sent = await repo.sent();
        expect(sent.single.id, 's1');
        expect(sent.single.recipientCount, 3);
      },
    );
  });

  group('routing', () {
    test('deep links', () {
      expect(
        DeepLinks.toRoute(Uri.parse('xatbox://official')),
        Routes.official,
      );
      expect(
        DeepLinks.toRoute(Uri.parse('xatbox://official/o1')),
        '/official/m/o1',
      );
    });

    test('push taps', () {
      expect(
        pushTapLocation({
          'type': 'official.created',
          'official_message_id': 'o2',
        }),
        '/official/m/o2',
      );
      expect(pushTapLocation({'kind': 'official'}), Routes.official);
    });
  });
}
