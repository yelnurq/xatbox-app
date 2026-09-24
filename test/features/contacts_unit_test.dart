import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/api/api_exception.dart';
import 'package:xatbox_mobile/features/chat/data/chat_models.dart';
import 'package:xatbox_mobile/features/contacts/data/contact_models.dart';
import 'package:xatbox_mobile/features/contacts/data/contacts_api.dart';
import 'package:xatbox_mobile/features/contacts/presentation/contacts_providers.dart';

import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

Contact _c(
  String id,
  String name, {
  String email = '',
  bool online = false,
  String dept = '',
  String deptId = '',
}) => Contact(
  id: id,
  email: email.isEmpty ? '$id@example.kz' : email,
  displayName: name,
  online: online,
  department: dept,
  departmentId: deptId,
);

Future<void> _flush() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

String _shape(ContactRow r) => switch (r) {
  ContactHeaderRow(:final title) => 'H:$title',
  ContactItemRow(:final contact, :final section) => '$section:${contact.id}',
};

void main() {
  group('groupContacts', () {
    test('alphabetical sections: Cyrillic, Latin, then #; Ё under Е', () {
      final sections = groupContacts([
        _c('1', 'Болат Сейтов'),
        _c('2', 'алия Нурланова'),
        _c('3', 'Ержан'),
        _c('4', 'Ёлка Иванова'),
        _c('5', 'Anna Smith'),
        _c('6', '', email: 'bob@example.kz'),
        _c('7', '42 Support'),
        _c('8', 'Азамат'),
        _c('1', 'Болат Сейтов'), // duplicate id
        _c('self', 'Тест Пользователь'),
      ], excludeId: 'self');

      expect(sections.map((s) => s.letter).toList(), [
        'А',
        'Б',
        'Е',
        'A',
        'B',
        '#',
      ]);
      expect(sections[0].contacts.map((c) => c.id), [
        '8',
        '2',
      ], reason: 'case-insensitive order inside a section');
      expect(sections[1].contacts, hasLength(1), reason: 'duplicates dropped');
      expect(sections[2].contacts.map((c) => c.label), [
        'Ёлка Иванова',
        'Ержан',
      ]);
      expect(sections[4].contacts.single.label, 'bob@example.kz');
      expect(
        sections.expand((s) => s.contacts).any((c) => c.id == 'self'),
        isFalse,
      );
    });

    test('empty input gives no sections', () {
      expect(groupContacts(const []), isEmpty);
    });

    test('by department: sorted by name, people without one last', () {
      final sections = groupContactsByDepartment([
        _c('1', 'Болат', dept: 'Бухгалтерия', deptId: 'd1'),
        _c('2', 'Алия', dept: 'IT', deptId: 'd2'),
        _c('3', 'Вера'),
        _c('4', 'Азамат', dept: 'Бухгалтерия', deptId: 'd1'),
        _c('self', 'Я', dept: 'IT', deptId: 'd2'),
      ], noDepartment: 'Без отдела', excludeId: 'self');
      expect(sections.map((s) => s.letter), ['IT', 'Бухгалтерия', 'Без отдела']);
      expect(sections[1].contacts.map((c) => c.id), ['4', '1']);
      expect(sections[1].departmentId, 'd1');
      expect(sections[0].contacts.single.id, '2');
    });

    test('Contact parses the Chat Service user and matches locally', () {
      final c = Contact.fromJson({
        ...ChatFixtures.user(name: 'Bob', online: true),
        'last_seen_at': '2026-09-14 10:21:33.123456+00',
      });
      expect(c.id, ChatFixtures.peer);
      expect(c.online, isTrue);
      expect(c.lastSeenAt, DateTime.utc(2026, 9, 14, 10, 21, 33, 123, 456));
      expect(c.matches('BOB@'), isTrue);
      expect(c.matches('alice'), isFalse);
      expect(Contact.fromJson(c.toJson()).email, c.email);
    });

    test('Contact keeps the directory fields and round-trips the cache', () {
      final c = Contact.fromJson({
        'user_id': 'u1',
        'email': 'alia@example.kz',
        'display_name': 'Алия',
        'mailbox_address': 'a.nurlanova@example.kz',
        'department_id': 'd1',
        'department_name': 'Бухгалтерия',
        'job_title': 'Главный бухгалтер',
        'avatar_updated_at': '2026-09-01T08:00:00Z',
      });
      expect(c.mailbox, 'a.nurlanova@example.kz');
      expect(c.mailAddress, 'a.nurlanova@example.kz');
      expect(c.departmentId, 'd1');
      expect(c.position, 'Главный бухгалтер');
      expect(c.matches('nurlanova'), isTrue);
      final back = Contact.fromJson(c.toJson());
      expect(
        [back.mailbox, back.departmentId, back.department, back.position],
        [c.mailbox, c.departmentId, c.department, c.position],
      );
      expect(back.avatarUpdatedAt, c.avatarUpdatedAt);

      final same = Contact.fromJson({
        'user_id': 'u2',
        'email': 'Bob@example.kz',
        'mailbox_address': 'bob@example.kz',
      });
      expect(same.mailbox, isEmpty, reason: 'mailbox equal to the login');
      expect(same.mailAddress, 'Bob@example.kz');

      final vcard = c.toVCard();
      expect(vcard, contains('FN:Алия'));
      expect(vcard, contains('ORG:;Бухгалтерия'));
      expect(vcard, contains('EMAIL;TYPE=INTERNET:a.nurlanova@example.kz'));
      expect(vcard.startsWith('BEGIN:VCARD'), isTrue);
    });

    test('Department parses the directory department', () {
      final d = Department.fromJson({
        'id': 'd1',
        'name': 'Бухгалтерия',
        'description': 'Учёт',
        'manager_user_id': 'u9',
        'manager_name': '',
        'manager_email': 'e@example.kz',
        'employee_count': 7,
        'status': 'archived',
      });
      expect(d.isArchived, isTrue);
      expect(d.hasManager, isTrue);
      expect(d.managerLabel, 'e@example.kz');
      expect(Department.fromJson(d.toJson()).employeeCount, 7);
    });

    test('matchRanges finds every case-insensitive occurrence', () {
      expect(matchRanges('Болат Болатов', 'бол'), [(0, 3), (6, 9)]);
      expect(matchRanges('Anna', ' '), isEmpty);
      expect(matchRanges('Anna', 'x'), isEmpty);
    });
  });

  group('buildContactRows', () {
    final contacts = [
      _c('1', 'Болат', dept: 'IT', deptId: 'd2'),
      _c('2', 'Алия', online: true),
      _c('3', 'Anna', dept: 'IT', deptId: 'd2'),
      _c('self', 'Я'),
    ];
    const recent = [
      ChatUser(userId: '1', email: '1@example.kz', displayName: 'Болат'),
      ChatUser(userId: '3', email: '3@example.kz', displayName: 'Anna'),
      ChatUser(userId: 'gone', email: 'g@example.kz', displayName: 'Гость'),
    ];

    ContactRows build({
      ContactsView view = const ContactsView(),
      String query = '',
      List<Contact>? favourites,
    }) => buildContactRows(
      contacts: contacts,
      view: view,
      favourites: favourites ?? [_c('3', 'Anna (old)')],
      recent: recent,
      query: query,
      noDepartment: 'Без отдела',
      favouritesTitle: 'Fav',
      recentTitle: 'Recent',
      selfId: 'self',
    );

    test('favourites and recent on top; index points at letter headers', () {
      final rows = build();
      expect(rows.rows.map(_shape), [
        'H:Fav',
        'fav:3',
        'H:Recent',
        'recent:1',
        'recent:gone',
        'H:А',
        ':2',
        'H:Б',
        ':1',
        'H:A',
        ':3',
      ]);
      final fav = rows.rows[1] as ContactItemRow;
      expect(fav.contact.label, 'Anna', reason: 'fresh data over snapshot');
      expect(rows.index, {'А': 5, 'Б': 7, 'A': 9});
      expect(rows.visibleCount, 3);
    });

    test('search and filters hide the top sections', () {
      expect(build(query: 'ан').rows.map(_shape), ['H:А', ':2', 'H:Б', ':1', 'H:A', ':3']);
      expect(
        build(view: const ContactsView(filter: ContactsFilter.online)).rows.map(_shape),
        ['H:А', ':2'],
      );
      final favs = build(
        view: const ContactsView(filter: ContactsFilter.favourites),
        favourites: [_c('3', 'Anna'), _c('far', 'Далёкий')],
      );
      expect(favs.rows.map(_shape), ['H:Д', ':far', 'H:A', ':3']);
    });

    test('department grouping has no alphabet index', () {
      final rows = build(
        view: const ContactsView(byDepartment: true),
        query: 'x',
      );
      expect(rows.rows.map(_shape), ['H:IT', ':3', ':1', 'H:Без отдела', ':2']);
      expect(rows.index, isEmpty);
    });
  });

  test('recentChatPeers: direct chats with messages, newest first', () {
    Map<String, dynamic> conv(String id, String peer, String at, {bool msg = true}) => {
      ...ChatFixtures.conversation(),
      'id': id,
      'type': 'direct',
      'peer': ChatFixtures.user(id: peer, name: peer),
      'updated_at': at,
      'last_message': msg
          ? {
              ...ChatFixtures.message(id: 'm$id', seq: 1, convId: id),
              'created_at': at,
            }
          : null,
    };
    final convs = [
      conv('c1', 'old', '2026-09-10T10:00:00Z'),
      conv('c2', 'new', '2026-09-14T10:00:00Z'),
      conv('c3', 'silent', '2026-09-15T10:00:00Z', msg: false),
      conv('c4', 'self', '2026-09-15T11:00:00Z'),
      {...conv('c5', 'grp', '2026-09-15T12:00:00Z'), 'type': 'group'},
    ].map(ChatConversation.fromJson);
    expect(
      recentChatPeers(convs, selfId: 'self').map((u) => u.userId),
      ['new', 'old'],
    );
  });

  group('ContactsRepository', () {
    late TestHarness h;
    tearDown(() => h.dispose());

    /// [pageSize] mimics the desktop shell, which walks the directory
    /// page by page instead of pulling it all at once.
    Future<void> signedIn({int? pageSize}) async {
      h = await TestHarness.create(
        storedToken: Fixtures.token,
        chatBaseUrl: 'http://chat.local/api/v1',
        overrides: [
          if (pageSize != null)
            contactsPageSizeProvider.overrideWithValue(pageSize),
        ],
      );
      h.adapter.onJson('GET', '/me', Fixtures.me());
      await h.session.restore();
    }

    final users = [
      ChatFixtures.user(name: 'Bob', online: true),
      {
        ...ChatFixtures.user(id: 'u-alia', name: 'Алия'),
        'department_id': 'd1',
        'department_name': 'Бухгалтерия',
      },
    ];
    final ownerId = Fixtures.me()['id'] as String;

    test(
      'requests /users with limit 1000 (q / department only when set) and caches the full list',
      () async {
        await signedIn();
        h.chatAdapter.on(
          'GET',
          '/users',
          (r) => FakeResponse(
            200,
            json: {
              'users': r.query['department_id'] == 'd1' ? [users[1]] : users,
              'limit': 1000,
              'has_more': false,
            },
          ),
        );
        final repo = h.container.read(contactsRepositoryProvider);

        final all = await repo.load('');
        expect(all.fromCache, isFalse);
        expect(all.hasMore, isFalse);
        expect(all.contacts, hasLength(2));
        final first = h.chatAdapter.of('GET', '/users').single;
        expect(first.query, {'limit': '1000'});

        await repo.load(' Bo ');
        expect(h.chatAdapter.of('GET', '/users').last.query, {
          'q': 'Bo',
          'limit': '1000',
        });

        final dept = await repo.colleagues('d1');
        expect(dept.single.id, 'u-alia');
        expect(h.chatAdapter.of('GET', '/users').last.query, {
          'department_id': 'd1',
          'limit': '1000',
        });

        final cache = h.container.read(contactsCacheProvider);
        final cached = await cache.read(ownerId: ownerId);
        expect(
          cached!.contacts,
          hasLength(2),
          reason: 'search / department results do not overwrite the cache',
        );
        expect(cached.contacts[1].departmentId, 'd1');
        expect(await cache.read(ownerId: 'someone-else'), isNull);
      },
    );

    test('a full page reports more; an old service (cap 200) is retried', () async {
      await signedIn();
      h.chatAdapter.onJson('GET', '/users', {'users': users, 'limit': 2});
      final repo = h.container.read(contactsRepositoryProvider);
      expect((await repo.load('')).hasMore, isTrue);

      final many = [
        for (var i = 0; i < 120; i++)
          ChatFixtures.user(id: 'u-$i', name: 'User $i'),
      ];
      h.chatAdapter.on('GET', '/users', (r) {
        // Pre-1000 service: over-limit → its default of 50, no `limit` key.
        final l = int.parse(r.query['limit'] as String);
        return FakeResponse(
          200,
          json: {'users': l > 200 ? many.take(50).toList() : many},
        );
      });
      final legacy = await repo.load('');
      expect(legacy.contacts, hasLength(120));
      expect(
        h.chatAdapter.of('GET', '/users').reversed.take(2).map((r) => r.query['limit']),
        ['200', '1000'],
      );
    });

    test('offline: serves the cached list, filtered by the query', () async {
      await signedIn();
      h.chatAdapter.onJson('GET', '/users', {'users': users});
      final repo = h.container.read(contactsRepositoryProvider);
      await repo.load('');

      h.chatAdapter.onOffline('GET', '/users');
      final offline = await repo.load('');
      expect(offline.fromCache, isTrue);
      expect(offline.error, isA<NetworkException>());
      expect(offline.contacts, hasLength(2));

      final filtered = await repo.load('али');
      expect(filtered.fromCache, isTrue);
      expect(filtered.contacts.single.displayName, 'Алия');

      final byDept = await repo.load('', departmentId: 'd1');
      expect(byDept.contacts.single.id, 'u-alia');

      expect(
        await repo.find('u-alia'),
        isNotNull,
        reason: 'no /users/{id} route: lookup in the cache',
      );

      await contactsSignOut(h.container);
      await expectLater(
        repo.load(''),
        throwsA(isA<NetworkException>()),
        reason: 'nothing cached after sign-out',
      );
    });

    test('find: GET /users/{id} first, cache when offline, null when unknown', () async {
      await signedIn();
      h.chatAdapter.onJson('GET', '/users', {'users': users});
      final repo = h.container.read(contactsRepositoryProvider);
      await repo.load('');

      h.chatAdapter.onPattern(
        'GET',
        r'^/users/[^/]+$',
        (_) => FakeResponse(
          200,
          json: {
            'user': {
              ...users[0],
              'online': false,
              'last_seen_at': '2026-09-15T08:00:00Z',
              'department_name': 'IT',
            },
          },
        ),
      );
      final fresh = await repo.find(ChatFixtures.peer);
      expect(fresh!.department, 'IT');
      expect(fresh.online, isFalse);
      expect(
        h.chatAdapter.requests.last.path,
        '/users/${ChatFixtures.peer}',
      );

      h.chatAdapter.onPattern(
        'GET',
        r'^/users/[^/]+$',
        (_) => throw const SocketException('offline'),
      );
      // Exact routes win over patterns; drop none — patterns are appended, so
      // register the offline one on the concrete path too.
      h.chatAdapter.onOffline('GET', '/users/${ChatFixtures.peer}');
      final cached = await repo.find(ChatFixtures.peer);
      expect(cached!.online, isTrue, reason: 'cached copy');

      h.chatAdapter.onError('GET', '/users/nobody', 404, 'USER_NOT_FOUND');
      expect(await repo.find('nobody'), isNull);
    });

    test('departments are cached; unavailable → cached or empty', () async {
      await signedIn();
      final repo = h.container.read(contactsRepositoryProvider);
      h.chatAdapter.onError('GET', '/departments', 403, 'FORBIDDEN');
      expect(await repo.departments(), isEmpty);

      h.chatAdapter.onJson('GET', '/departments', {
        'departments': [
          {'id': 'd2', 'name': 'юристы', 'employee_count': 2, 'status': 'active'},
          {
            'id': 'd1',
            'name': 'Бухгалтерия',
            'manager_user_id': 'u9',
            'manager_name': 'Ержан',
            'employee_count': 7,
            'status': 'active',
          },
        ],
      });
      final list = await repo.departments();
      expect(list.map((d) => d.id), ['d1', 'd2']);

      h.chatAdapter.onOffline('GET', '/departments');
      final offline = await repo.departments();
      expect(offline.first.managerName, 'Ержан');
    });

    test('favourites persist per account', () async {
      await signedIn();
      final notifier = h.container.read(contactsFavouritesProvider.notifier);
      await _flush();
      await notifier.toggle(_c('u-alia', 'Алия'));
      expect(h.container.read(contactsFavouriteIdsProvider), {'u-alia'});
      final store = h.container.read(contactsFavouritesStoreProvider);
      expect((await store.read(ownerId: ownerId)).single.id, 'u-alia');
      expect(await store.read(ownerId: 'someone-else'), isEmpty);

      await notifier.toggle(_c('u-alia', 'Алия'));
      expect(await store.read(ownerId: ownerId), isEmpty);
    });

    test('permission errors are not masked by the cache', () async {
      await signedIn();
      h.chatAdapter.onJson('GET', '/users', {'users': users});
      final repo = h.container.read(contactsRepositoryProvider);
      await repo.load('');
      h.chatAdapter.onError('GET', '/users', 403, 'FORBIDDEN');
      await expectLater(repo.load(''), throwsA(isA<ApiException>()));
    });

    test('desktop pages the directory by 50 and keeps the offline copy', () async {
      await signedIn(pageSize: ContactsApi.pageSize);
      final many = [
        for (var i = 0; i < 130; i++)
          ChatFixtures.user(id: 'u-${i.toString().padLeft(3, '0')}', name: 'User $i'),
      ];
      h.chatAdapter.on('GET', '/users', (r) {
        final limit = int.parse(r.query['limit'] as String);
        final offset = int.parse((r.query['offset'] as String?) ?? '0');
        final slice = many.skip(offset).take(limit).toList();
        return FakeResponse(200, json: {
          'users': slice,
          'limit': limit,
          'offset': offset,
          'has_more': offset + slice.length < many.length,
        });
      });

      h.container.read(contactsProvider);
      await _flush();
      var state = h.container.read(contactsProvider);
      expect(state.contacts, hasLength(50));
      expect(state.hasMore, isTrue);
      expect(h.chatAdapter.of('GET', '/users').single.query, {'limit': '50'});

      await h.container.read(contactsProvider.notifier).loadMore();
      state = h.container.read(contactsProvider);
      expect(state.contacts, hasLength(100));
      expect(state.hasMore, isTrue);
      expect(h.chatAdapter.of('GET', '/users').last.query, {
        'limit': '50',
        'offset': '50',
      });

      await h.container.read(contactsProvider.notifier).loadMore();
      state = h.container.read(contactsProvider);
      expect(state.contacts, hasLength(130));
      expect(state.hasMore, isFalse, reason: 'the directory is exhausted');
      expect(state.contacts.map((c) => c.id).toSet(), hasLength(130));

      await h.container.read(contactsProvider.notifier).loadMore();
      expect(
        h.chatAdapter.of('GET', '/users'), hasLength(3),
        reason: 'nothing left to ask for',
      );

      final cached = await h.container
          .read(contactsCacheProvider)
          .read(ownerId: ownerId);
      expect(
        cached!.contacts,
        hasLength(130),
        reason: 'the pages walked so far are the offline copy',
      );
    });

    test('a service that ignores offset stops the endless list', () async {
      await signedIn(pageSize: ContactsApi.pageSize);
      // Pre-paging service: every page is the first one.
      h.chatAdapter.onJson('GET', '/users', {
        'users': users,
        'limit': 50,
        'has_more': true,
      });
      h.container.read(contactsProvider);
      await _flush();
      expect(h.container.read(contactsProvider).contacts, hasLength(2));

      await h.container.read(contactsProvider.notifier).loadMore();
      final state = h.container.read(contactsProvider);
      expect(state.contacts, hasLength(2), reason: 'no repeated colleagues');
      expect(state.hasMore, isFalse);
    });

    test('notifier: cache first, then network; offline keeps the cached list', () async {
      await signedIn();
      h.chatAdapter.onJson('GET', '/users', {'users': users});
      await h.container.read(contactsRepositoryProvider).load('');

      h.chatAdapter.on(
        'GET',
        '/users',
        (_) => throw const SocketException('offline'),
      );
      h.container.read(contactsProvider);
      await _flush();
      final state = h.container.read(contactsProvider);
      expect(state.loaded, isTrue);
      expect(state.fromCache, isTrue);
      expect(state.error, isA<NetworkException>());
      expect(state.contacts, hasLength(2));
      expect(
        h.container.read(contactsSectionsProvider).map((s) => s.letter),
        ['А', 'B'],
      );
    });
  });
}
