import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import 'task_models.dart';

/// One answer of `GET /directory/users`.
class TaskDirectoryPage {
  const TaskDirectoryPage(this.users, {this.hasMore = false, this.offset = 0});
  final List<TaskAssignee> users;

  /// The directory holds more colleagues after this page.
  final bool hasMore;
  final int offset;
}

/// Mail API tasks (`/tasks`, `/tasks/{id}`), the boards they are grouped on
/// (`/tasks/boards`) plus the two directory calls the assignee picker needs
/// (`GET /departments`, `GET /directory/users`).
class TasksApi {
  TasksApi(this._client);
  final ApiClient _client;

  /// `GET /tasks`: what the caller owns, what they assigned to someone
  /// else, and everything on the boards they own or were given. No paging —
  /// the app groups the list by `board_id` itself. [archived] asks for the
  /// archive alone instead of the live tasks.
  Future<List<Task>> list({bool archived = false}) async {
    final json = await _client.getJson(archived ? '/tasks?archived=1' : '/tasks');
    return ((json['tasks'] as List?) ?? const [])
        .map((e) => Task.fromJson((e as Map).cast<String, dynamic>()))
        .where((t) => t.id.isNotEmpty)
        .toList();
  }

  /// `POST /tasks` → 201 `{id}`. An undecodable body makes the server answer
  /// an empty 200, which is treated as a failure.
  Future<String> create(TaskDraft draft) async {
    final json = await _client.postJson(
      '/tasks',
      body: draft.toJson(),
      expectedStatuses: const {201},
    );
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const UnexpectedApiException('POST /tasks without id');
    }
    return id;
  }

  /// `PATCH /tasks/{id}` → 204 (the task's owner, or the owner / an editor
  /// of its board; others get 404). An empty 200 means the body was
  /// rejected without changes.
  Future<void> update(String id, TaskPatch patch) async {
    await _client.send(
      () => _client.dio.patch<dynamic>(
        '/tasks/${Uri.encodeComponent(id)}',
        data: patch.toJson(),
      ),
      expectedStatuses: const {204},
    );
  }

  // ---- boards -------------------------------------------------------------

  /// `GET /tasks/boards`: the boards the caller owns, then the ones shared
  /// with them. A service released before boards has no such route and
  /// answers 404 — with the router's plain-text body rather than the error
  /// envelope, so both shapes are read as "no boards" and the app shows the
  /// personal list alone.
  Future<List<TaskBoard>> boards() async {
    try {
      final json = await _client.getJson('/tasks/boards');
      return ((json['boards'] as List?) ?? const [])
          .map((e) => TaskBoard.fromJson((e as Map).cast<String, dynamic>()))
          .where((b) => b.id.isNotEmpty)
          .toList();
    } on AppException catch (e) {
      final status = switch (e) {
        ApiException(:final statusCode) => statusCode,
        UnexpectedApiException(:final statusCode) => statusCode,
        _ => null,
      };
      if (status == 404 || status == 405) return const [];
      rethrow;
    }
  }

  /// `POST /tasks/boards` → 201 `{id}`. An undecodable body makes the server
  /// answer an empty 200, which is treated as a failure.
  Future<String> createBoard(TaskBoardDraft draft) async {
    final json = await _client.postJson(
      '/tasks/boards',
      body: draft.toJson(),
      expectedStatuses: const {201},
    );
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const UnexpectedApiException('POST /tasks/boards without id');
    }
    return id;
  }

  /// `PATCH /tasks/boards/{id}` → 204 (owner only; others get 404).
  Future<void> updateBoard(String id, TaskBoardPatch patch) async {
    await _client.send(
      () => _client.dio.patch<dynamic>(
        '/tasks/boards/${Uri.encodeComponent(id)}',
        data: patch.toJson(),
      ),
      expectedStatuses: const {204},
    );
  }

  /// `DELETE /tasks/boards/{id}` → 204 (owner only). The tasks that were on
  /// the board go back to their owners' personal lists.
  Future<void> deleteBoard(String id) async {
    await _client.deleteJson(
      '/tasks/boards/${Uri.encodeComponent(id)}',
      expectedStatuses: const {204},
    );
  }

  /// `PUT /tasks/boards/{id}/members` → 204 (owner only). [members] replaces
  /// the whole list, so leaving a colleague out removes their access.
  Future<void> setBoardMembers(String id, List<TaskBoardMember> members) async {
    await _client.send(
      () => _client.dio.put<dynamic>(
        '/tasks/boards/${Uri.encodeComponent(id)}/members',
        data: {'members': [for (final m in members) m.toMemberRequest()]},
      ),
      expectedStatuses: const {204},
    );
  }

  /// `DELETE /tasks/{id}` → 204 (owner or a board editor), reminders
  /// included.
  Future<void> delete(String id) async {
    await _client.deleteJson(
      '/tasks/${Uri.encodeComponent(id)}',
      expectedStatuses: const {204},
    );
  }

  /// One page of the organization's directory (`GET /directory/users`), for
  /// picking the colleagues a board is shared with. Unlike
  /// [assignableUsers] this is the whole organization: sharing a board makes
  /// nobody responsible for anything.
  Future<TaskDirectoryPage> directory(
    String query, {
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    final q = query.trim();
    final from = offset < 0 ? 0 : offset;
    final json = await _client.getJson(
      '/directory/users',
      query: {
        if (q.isNotEmpty) 'q': q,
        'limit': limit,
        if (from > 0) 'offset': from,
      },
      cancelToken: cancelToken,
    );
    final users = ((json['users'] as List?) ?? const [])
        .map((e) => TaskAssignee.fromJson((e as Map).cast<String, dynamic>()))
        .where((u) => u.id.isNotEmpty)
        .toList();
    final hasMore = json['has_more'] is bool
        ? json['has_more'] as bool
        : users.length >= limit;
    return TaskDirectoryPage(users, hasMore: hasMore, offset: from);
  }

  /// Colleagues the caller can assign to: active members of the departments
  /// whose `manager_user_id` is [managerId] (the server's rule for
  /// `tasks.assign.department`). The caller is excluded.
  Future<List<TaskAssignee>> assignableUsers(
    String managerId, {
    CancelToken? cancelToken,
  }) async {
    final deps = await _client.getJson('/departments');
    final managed = ((deps['departments'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .where(
          (d) =>
              d['manager_user_id'] == managerId &&
              (d['status'] as String? ?? 'active') != 'archived' &&
              (d['id'] as String? ?? '').isNotEmpty,
        )
        .map((d) => d['id'] as String)
        .toList();
    final users = <String, TaskAssignee>{};
    for (final depId in managed) {
      final json = await _client.getJson(
        '/directory/users',
        query: {'department_id': depId, 'limit': 1000},
        cancelToken: cancelToken,
      );
      for (final raw in (json['users'] as List?) ?? const []) {
        final u = TaskAssignee.fromJson((raw as Map).cast<String, dynamic>());
        if (u.id.isNotEmpty && u.id != managerId) users[u.id] = u;
      }
    }
    return users.values.toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  }
}
