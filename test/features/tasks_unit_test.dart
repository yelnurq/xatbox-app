import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/api/api_client.dart';
import 'package:xatbox_mobile/core/api/api_exception.dart';
import 'package:xatbox_mobile/core/routing/deep_links.dart';
import 'package:xatbox_mobile/core/routing/link_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/core/storage/app_database.dart';
import 'package:xatbox_mobile/features/tasks/data/task_models.dart';
import 'package:xatbox_mobile/features/tasks/data/tasks_api.dart';
import 'package:xatbox_mobile/features/tasks/data/tasks_cache.dart';

import '../helpers/fake_http.dart';

const _me = '11111111-1111-4111-8111-111111111111';
const _colleague = '55555555-5555-4555-8555-555555555555';

Map<String, dynamic> taskJson({
  String id = 't1',
  String owner = _me,
  String status = 'todo',
  String? due,
  String? reminder,
  String sourceType = 'manual',
  String? sourceId,
}) => {
  'id': id,
  'owner_user_id': owner,
  'title': 'Задача $id',
  'description': '',
  'priority': 'normal',
  'status': status,
  'source_type': sourceType,
  'source_id': ?sourceId,
  'due_at': ?due,
  'reminder_at': ?reminder,
  'created_at': '2026-09-14 09:00:00.123456+00',
};

Map<String, dynamic> boardJson({
  String id = 'b1',
  String name = 'Доска',
  String owner = _me,
  String role = 'owner',
}) => {
  'id': id,
  'name': name,
  'description': '',
  'position': 0,
  'owner_user_id': owner,
  'role': role,
  'members': <Map<String, dynamic>>[],
  'task_count': 0,
  'open_count': 0,
  'created_at': '2026-09-14 09:00:00+00',
};

void main() {
  group('Task model', () {
    test('parses PostgreSQL timestamptz text and optional fields', () {
      final t = Task.fromJson(
        taskJson(
          due: '2026-09-14 09:00:00+00',
          reminder: '2026-09-14 08:30:00+05',
          sourceType: 'email',
          sourceId: 'm1',
        ),
      );
      expect(t.dueAt, DateTime.utc(2026, 9, 14, 9));
      expect(t.reminderAt, DateTime.utc(2026, 9, 14, 3, 30));
      expect(t.createdAt!.isUtc, isTrue);
      expect(t.mailMessageId, 'm1');
      expect(t.isOwnedBy(_me), isTrue);
      expect(t.isOwnedBy(''), isFalse);

      final bare = Task.fromJson(taskJson(id: 't2'));
      expect(bare.dueAt, isNull);
      expect(bare.reminderAt, isNull);
      expect(bare.mailMessageId, isNull);

      // Cache round trip keeps every value.
      final again = Task.fromJson(t.toJson());
      expect(again.dueAt, t.dueAt);
      expect(again.reminderAt, t.reminderAt);
      expect(again.sourceId, 'm1');
    });

    test('overdue / due today / sections / badge', () {
      final now = DateTime(2026, 9, 14, 12);
      final overdue = Task.fromJson(
        taskJson(id: 'a', due: DateTime(2026, 9, 13, 18).toUtc().toString()),
      );
      final today = Task.fromJson(
        taskJson(id: 'b', due: DateTime(2026, 9, 14, 18).toUtc().toString()),
      );
      final later = Task.fromJson(
        taskJson(id: 'c', due: DateTime(2026, 9, 20, 18).toUtc().toString()),
      );
      final done = Task.fromJson(
        taskJson(
          id: 'd',
          status: 'done',
          due: DateTime(2026, 9, 1).toUtc().toString(),
        ),
      );
      final assigned = Task.fromJson(
        taskJson(
          id: 'e',
          owner: _colleague,
          due: DateTime(2026, 9, 1).toUtc().toString(),
        ),
      );
      expect(overdue.isOverdue(now), isTrue);
      expect(today.isDueToday(now), isTrue);
      expect(today.isOverdue(now), isFalse);
      expect(later.isDueToday(now), isFalse);
      expect(done.isOverdue(now), isFalse);

      final all = [overdue, today, later, assigned, done];
      final s = TaskSections.of(all, _me);
      expect(s.mine.map((t) => t.id), ['a', 'b', 'c']);
      expect(s.assigned.map((t) => t.id), ['e']);
      expect(s.done.map((t) => t.id), ['d']);
      // Assigned-by-me and done tasks do not count.
      expect(TaskSections.attentionCount(all, _me, now), 2);
    });

    test('draft and patch bodies', () {
      final draft = TaskDraft(
        title: '  Отчёт ',
        description: ' ',
        ownerUserId: _colleague,
        dueAt: DateTime.utc(2026, 9, 15, 13),
        priority: 'high',
      ).toJson();
      expect(draft, {
        'title': 'Отчёт',
        'owner_user_id': _colleague,
        'due_at': '2026-09-15T13:00:00.000Z',
        'priority': 'high',
      });
      expect(const TaskPatch(status: 'done').toJson(), {'status': 'done'});
      expect(const TaskPatch(clearDue: true).toJson(), {'due_at': ''});
      expect(const TaskPatch().isEmpty, isTrue);
    });
  });

  group('TasksApi', () {
    late FakeHttpAdapter adapter;
    late TasksApi api;

    setUp(() {
      adapter = FakeHttpAdapter();
      api = TasksApi(
        ApiClient(
          baseUrl: 'http://test.local/api/v1',
          userAgent: 'test',
          adapter: adapter,
          tokenReader: () => 'tok',
          onUnauthenticated: () {},
        ),
      );
    });

    test('GET /tasks', () async {
      adapter.onJson('GET', '/tasks', {
        'tasks': [taskJson(), taskJson(id: 't2', owner: _colleague)],
      });
      final tasks = await api.list();
      expect(tasks.map((t) => t.id), ['t1', 't2']);
    });

    test('POST /tasks 201 returns id; empty 200 is a failure', () async {
      adapter.onJson('POST', '/tasks', {'id': 'new'}, status: 201);
      expect(await api.create(const TaskDraft(title: 'X')), 'new');
      expect(adapter.of('POST', '/tasks').single.json, {'title': 'X'});

      adapter.on('POST', '/tasks', (_) => const FakeResponse(200));
      await expectLater(
        api.create(const TaskDraft(title: 'X')),
        throwsA(isA<AppException>()),
      );
    });

    test('PATCH expects 204; empty 200 and 404 fail', () async {
      adapter.on('PATCH', '/tasks/t1', (_) => const FakeResponse(204));
      await api.update('t1', const TaskPatch(status: 'done'));
      expect(adapter.of('PATCH', '/tasks/t1').single.json, {'status': 'done'});

      adapter.on('PATCH', '/tasks/t1', (_) => const FakeResponse(200));
      await expectLater(
        api.update('t1', const TaskPatch(status: 'done')),
        throwsA(isA<AppException>()),
      );

      adapter.onError('PATCH', '/tasks/t1', 404, 'TASK_NOT_FOUND');
      await expectLater(
        api.update('t1', const TaskPatch(status: 'done')),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'TASK_NOT_FOUND'),
        ),
      );
    });

    test('DELETE /tasks/{id} 204', () async {
      adapter.on('DELETE', '/tasks/t1', (_) => const FakeResponse(204));
      await api.delete('t1');
      expect(adapter.of('DELETE', '/tasks/t1'), hasLength(1));
    });

    test('assignable users: members of departments I manage', () async {
      adapter.onJson('GET', '/departments', {
        'departments': [
          {
            'id': 'd1',
            'name': 'IT',
            'manager_user_id': _me,
            'status': 'active',
          },
          {
            'id': 'd2',
            'name': 'HR',
            'manager_user_id': 'x',
            'status': 'active',
          },
          {
            'id': 'd3',
            'name': 'Old',
            'manager_user_id': _me,
            'status': 'archived',
          },
        ],
      });
      adapter.onJson('GET', '/directory/users', {
        'users': [
          {'id': _me, 'display_name': 'Я', 'email': 'me@x'},
          {'id': _colleague, 'display_name': 'Коллега', 'email': 'c@x'},
        ],
        'limit': 1000,
      });
      final users = await api.assignableUsers(_me);
      expect(users.map((u) => u.id), [_colleague]);
      final req = adapter.of('GET', '/directory/users').single;
      expect(req.query['department_id'], 'd1');
    });

    test('GET /tasks/boards; an older service without boards gives none', () async {
      adapter.onJson('GET', '/tasks/boards', {
        'boards': [
          boardJson(),
          {
            ...boardJson(id: 'b2', name: 'Приёмная кампания'),
            'owner_user_id': _colleague,
            'owner_name': 'Коллега',
            'role': 'viewer',
            'members': [
              {'user_id': _me, 'display_name': 'Я', 'role': 'viewer'},
            ],
            'open_count': 3,
            'task_count': 5,
          },
        ],
      });
      final boards = await api.boards();
      expect(boards.map((b) => b.id), ['b1', 'b2']);
      expect(boards[0].isOwner, isTrue);
      expect(boards[0].canWrite, isTrue);
      final shared = boards[1];
      expect(shared.isOwner, isFalse);
      expect(shared.canWrite, isFalse, reason: 'a viewer only reads');
      expect(shared.ownerName, 'Коллега');
      expect(shared.openCount, 3);
      expect(shared.members.single.userId, _me);

      adapter.on('GET', '/tasks/boards', (_) => const FakeResponse(404));
      expect(
        await api.boards(),
        isEmpty,
        reason: 'a service released before boards is not an error',
      );
    });

    test('board create / patch / delete / share', () async {
      adapter.onJson('POST', '/tasks/boards', {'id': 'b9'}, status: 201);
      expect(
        await api.createBoard(const TaskBoardDraft(name: '  Проект  ', color: 'violet')),
        'b9',
      );
      expect(adapter.of('POST', '/tasks/boards').single.json, {
        'name': 'Проект',
        'color': 'violet',
      });

      adapter.on('POST', '/tasks/boards', (_) => const FakeResponse(200));
      await expectLater(
        api.createBoard(const TaskBoardDraft(name: 'X')),
        throwsA(isA<AppException>()),
      );

      adapter.on('PATCH', '/tasks/boards/b9', (_) => const FakeResponse(204));
      await api.updateBoard('b9', const TaskBoardPatch(name: ' Новое '));
      expect(adapter.of('PATCH', '/tasks/boards/b9').single.json, {'name': 'Новое'});

      adapter.on('PUT', '/tasks/boards/b9/members', (_) => const FakeResponse(204));
      await api.setBoardMembers('b9', [
        const TaskBoardMember(userId: _colleague, displayName: 'Коллега'),
        const TaskBoardMember(userId: 'u3', role: TaskBoardRole.viewer),
      ]);
      expect(adapter.of('PUT', '/tasks/boards/b9/members').single.json, {
        'members': [
          {'user_id': _colleague, 'role': 'editor'},
          {'user_id': 'u3', 'role': 'viewer'},
        ],
      });

      adapter.on('DELETE', '/tasks/boards/b9', (_) => const FakeResponse(204));
      await api.deleteBoard('b9');
      expect(adapter.of('DELETE', '/tasks/boards/b9'), hasLength(1));
    });

    test('directory pages by 50 and reports whether more follow', () async {
      final many = [
        for (var i = 0; i < 130; i++)
          {'id': 'u-$i', 'display_name': 'User $i', 'email': 'u$i@x.kz'},
      ];
      adapter.on('GET', '/directory/users', (r) {
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

      final first = await api.directory('');
      expect(first.users, hasLength(50));
      expect(first.hasMore, isTrue);
      expect(adapter.of('GET', '/directory/users').single.query, {'limit': '50'});

      final last = await api.directory(' Иванов ', offset: 100);
      expect(last.users, hasLength(30));
      expect(last.hasMore, isFalse);
      expect(adapter.of('GET', '/directory/users').last.query, {
        'q': 'Иванов',
        'limit': '50',
        'offset': '100',
      });
    });
  });

  test('cache is bound to its owner', () async {
    final db = await AppDatabase.inMemory();
    addTearDown(db.close);
    final cache = TasksCache(db);
    await cache.write(
      ownerId: _me,
      tasks: [Task.fromJson(taskJson(due: '2026-09-14 09:00:00+00'))],
      savedAt: DateTime.utc(2026, 9, 14),
    );
    final read = await cache.read(ownerId: _me);
    expect(read!.tasks.single.dueAt, DateTime.utc(2026, 9, 14, 9));
    expect(await cache.read(ownerId: _colleague), isNull);
    await cache.clear();
    expect(await cache.read(ownerId: _me), isNull);
  });

  test('deep links and push payloads open tasks', () {
    expect(DeepLinks.toRoute(Uri.parse('xatbox://tasks')), Routes.tasks);
    expect(DeepLinks.toRoute(Uri.parse('xatbox://tasks/t9')), '/tasks/t9');
    expect(pushTapLocation({'task_id': 't7'}), '/tasks/t7');
  });
}
