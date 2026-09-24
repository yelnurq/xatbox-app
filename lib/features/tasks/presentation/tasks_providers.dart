import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/auth_session.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../data/task_models.dart';
import '../data/tasks_api.dart';
import '../data/tasks_cache.dart';

/// Permission codes of the tasks endpoints (`x-required-permission`).
abstract final class TaskPermissions {
  /// Every `/tasks` operation; the feature is hidden without it.
  static const manageSelf = 'tasks.manage.self';

  /// Assigning to a member of a department the caller manages.
  static const assignDepartment = 'tasks.assign.department';
}

final tasksEnabledProvider = Provider<bool>(
  // The desktop app shows them as a board (tasks_board.dart).
  (ref) => ref.watch(hasPermissionProvider(TaskPermissions.manageSelf)),
);

final tasksCanAssignProvider = Provider<bool>(
  (ref) =>
      ref.watch(tasksEnabledProvider) &&
      ref.watch(hasPermissionProvider(TaskPermissions.assignDepartment)),
);

/// Tasks live in the Mail API (same client, token and 401 handling).
final tasksApiProvider = Provider<TasksApi>(
  (ref) => TasksApi(ref.watch(apiClientProvider)),
);

final tasksCacheProvider = Provider<TasksCache>(
  (ref) => TasksCache(ref.watch(appDatabaseProvider)),
);

/// Injectable clock (overdue / due-today and the cache timestamp).
final tasksClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

class TasksState {
  const TasksState({
    this.tasks = const [],
    this.loading = false,
    this.loaded = false,
    this.fromCache = false,
    this.error,
  });

  final List<Task> tasks;
  final bool loading;
  final bool loaded;

  /// Showing the offline copy (the last refresh failed or is pending).
  final bool fromCache;
  final Object? error;

  TasksState copyWith({
    List<Task>? tasks,
    bool? loading,
    bool? loaded,
    bool? fromCache,
    Object? error,
    bool clearError = false,
  }) => TasksState(
    tasks: tasks ?? this.tasks,
    loading: loading ?? this.loading,
    loaded: loaded ?? this.loaded,
    fromCache: fromCache ?? this.fromCache,
    error: clearError ? null : (error ?? this.error),
  );
}

class TasksNotifier extends Notifier<TasksState> {
  TasksApi get _api => ref.read(tasksApiProvider);
  TasksCache get _cache => ref.read(tasksCacheProvider);
  String get _selfId => ref.read(currentUserProvider)?.id ?? '';

  @override
  TasksState build() {
    final signedIn =
        ref.watch(authStateProvider.select((s) => s.status)) ==
        AuthStatus.authenticated;
    if (!signedIn || !ref.watch(tasksEnabledProvider)) {
      return const TasksState();
    }
    Future.microtask(_start);
    return const TasksState(loading: true);
  }

  Future<void> _start() async {
    try {
      final cached = await _cache.read(ownerId: _selfId);
      if (ref.mounted && cached != null && !state.loaded) {
        state = state.copyWith(tasks: cached.tasks, fromCache: true);
      }
    } on Object catch (e) {
      DiagnosticLog.warn('tasks', 'cache read failed', error: e);
    }
    await refresh();
  }

  /// `GET /tasks`; on failure the cached / current list stays visible.
  Future<void> refresh() async {
    if (!ref.mounted) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final tasks = await _api.list();
      if (!ref.mounted) return;
      state = TasksState(tasks: tasks, loaded: true);
      unawaited(
        _cache
            .write(
              ownerId: _selfId,
              tasks: tasks,
              savedAt: ref.read(tasksClockProvider)(),
            )
            .catchError(
              (Object e) =>
                  DiagnosticLog.warn('tasks', 'cache write failed', error: e),
            ),
      );
    } on AppException catch (e) {
      if (!ref.mounted) return;
      DiagnosticLog.warn('tasks', 'list failed', error: e);
      state = state.copyWith(loading: false, loaded: true, error: e);
    }
  }

  /// Marks an own task done / back to todo (optimistic; rolled back and
  /// returned on failure).
  Future<AppException?> setDone(Task task, bool done) async {
    final status = done ? TaskStatus.done : TaskStatus.todo;
    if (task.status == status) return null;
    final before = state.tasks;
    state = state.copyWith(
      tasks: [
        for (final t in before)
          t.id == task.id ? t.copyWith(status: status) : t,
      ],
    );
    try {
      await _api.update(task.id, TaskPatch(status: status));
      unawaited(refresh());
      return null;
    } on AppException catch (e) {
      DiagnosticLog.warn('tasks', 'status change failed', error: e);
      if (ref.mounted) state = state.copyWith(tasks: before);
      return e;
    }
  }

  /// Desktop board: applies [patch] to an own task at once (a card dropped
  /// into another column), then `PATCH /tasks/{id}`; rolled back and
  /// returned on failure.
  Future<AppException?> move(Task task, TaskPatch patch) async {
    if (patch.isEmpty) return null;
    final before = state.tasks;
    state = state.copyWith(
      tasks: [
        for (final t in before)
          t.id == task.id ? t.patched(patch) : t,
      ],
    );
    try {
      await _api.update(task.id, patch);
      unawaited(refresh());
      return null;
    } on AppException catch (e) {
      DiagnosticLog.warn('tasks', 'move failed', error: e);
      if (ref.mounted) state = state.copyWith(tasks: before);
      return e;
    }
  }

  /// Deletes an own task (optimistic; rolled back and returned on failure).
  Future<AppException?> delete(Task task) async {
    final before = state.tasks;
    state = state.copyWith(
      tasks: [
        for (final t in before)
          if (t.id != task.id) t,
      ],
    );
    try {
      await _api.delete(task.id);
      unawaited(refresh());
      return null;
    } on AppException catch (e) {
      DiagnosticLog.warn('tasks', 'delete failed', error: e);
      if (ref.mounted) state = state.copyWith(tasks: before);
      return e;
    }
  }

  /// Sends a task to the archive or brings it back (optimistic: it leaves
  /// the list at once; rolled back and returned on failure).
  Future<AppException?> setArchived(Task task, bool archived) async {
    if (task.archived == archived) return null;
    final before = state.tasks;
    state = state.copyWith(
      tasks: [
        for (final t in before)
          if (t.id != task.id) t,
      ],
    );
    try {
      await _api.update(task.id, TaskPatch(archived: archived));
      unawaited(refresh());
      return null;
    } on AppException catch (e) {
      DiagnosticLog.warn('tasks', 'archive change failed', error: e);
      if (ref.mounted) state = state.copyWith(tasks: before);
      return e;
    }
  }

  /// `GET /tasks?archived=1`: the archive, read on demand for its dialog.
  Future<List<Task>> archived() => _api.list(archived: true);

  /// `POST /tasks`, then a refresh. Throws [AppException].
  Future<String> create(TaskDraft draft) async {
    final id = await _api.create(draft);
    await refresh();
    return id;
  }

  /// `PATCH /tasks/{id}`, then a refresh. Throws [AppException].
  Future<void> update(String id, TaskPatch patch) async {
    if (!patch.isEmpty) await _api.update(id, patch);
    await refresh();
  }
}

final tasksProvider = NotifierProvider<TasksNotifier, TasksState>(
  TasksNotifier.new,
);

// ---- boards -------------------------------------------------------------------------

/// The personal list — every task without a board. Not a board on the
/// server, so it has no id; the desktop board switcher shows it first.
const personalBoardId = '';

class TaskBoardsState {
  const TaskBoardsState({
    this.boards = const [],
    this.loading = false,
    this.loaded = false,
    this.fromCache = false,
    this.error,
  });

  final List<TaskBoard> boards;
  final bool loading;
  final bool loaded;

  /// Showing the offline copy (the last refresh failed or is pending).
  final bool fromCache;
  final Object? error;

  TaskBoard? byId(String id) =>
      boards.where((b) => b.id == id).firstOrNull;

  TaskBoardsState copyWith({
    List<TaskBoard>? boards,
    bool? loading,
    bool? loaded,
    bool? fromCache,
    Object? error,
    bool clearError = false,
  }) => TaskBoardsState(
    boards: boards ?? this.boards,
    loading: loading ?? this.loading,
    loaded: loaded ?? this.loaded,
    fromCache: fromCache ?? this.fromCache,
    error: clearError ? null : (error ?? this.error),
  );
}

class TaskBoardsNotifier extends Notifier<TaskBoardsState> {
  TasksApi get _api => ref.read(tasksApiProvider);
  TasksCache get _cache => ref.read(tasksCacheProvider);
  String get _selfId => ref.read(currentUserProvider)?.id ?? '';

  @override
  TaskBoardsState build() {
    final signedIn =
        ref.watch(authStateProvider.select((s) => s.status)) ==
        AuthStatus.authenticated;
    if (!signedIn || !ref.watch(tasksEnabledProvider)) {
      return const TaskBoardsState();
    }
    Future.microtask(_start);
    return const TaskBoardsState(loading: true);
  }

  Future<void> _start() async {
    try {
      final cached = await _cache.readBoards(ownerId: _selfId);
      if (ref.mounted && cached != null && !state.loaded) {
        state = state.copyWith(boards: cached, fromCache: true);
      }
    } on Object catch (e) {
      DiagnosticLog.warn('tasks', 'board cache read failed', error: e);
    }
    await refresh();
  }

  /// `GET /tasks/boards`; on failure the cached / current list stays visible.
  Future<void> refresh() async {
    if (!ref.mounted) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final boards = await _api.boards();
      if (!ref.mounted) return;
      state = TaskBoardsState(boards: boards, loaded: true);
      unawaited(
        _cache
            .writeBoards(ownerId: _selfId, boards: boards)
            .catchError(
              (Object e) => DiagnosticLog.warn(
                'tasks',
                'board cache write failed',
                error: e,
              ),
            ),
      );
    } on AppException catch (e) {
      if (!ref.mounted) return;
      DiagnosticLog.warn('tasks', 'board list failed', error: e);
      state = state.copyWith(loading: false, loaded: true, error: e);
    }
  }

  /// `POST /tasks/boards`, then a refresh; the new board's id is returned so
  /// the caller can open it. Throws [AppException].
  Future<String> create(TaskBoardDraft draft) async {
    final id = await _api.createBoard(draft);
    await refresh();
    return id;
  }

  /// `PATCH /tasks/boards/{id}` (owner only), then a refresh. Throws
  /// [AppException].
  Future<void> update(String id, TaskBoardPatch patch) async {
    if (patch.isEmpty) return;
    await _api.updateBoard(id, patch);
    await refresh();
  }

  /// Deletes an own board (optimistic; rolled back and returned on failure).
  /// The tasks that were on it come back on the personal list, so the task
  /// list is refreshed too.
  Future<AppException?> delete(String id) async {
    final before = state.boards;
    state = state.copyWith(
      boards: [
        for (final b in before)
          if (b.id != id) b,
      ],
    );
    try {
      await _api.deleteBoard(id);
      unawaited(refresh());
      unawaited(ref.read(tasksProvider.notifier).refresh());
      return null;
    } on AppException catch (e) {
      DiagnosticLog.warn('tasks', 'board delete failed', error: e);
      if (ref.mounted) state = state.copyWith(boards: before);
      return e;
    }
  }

  /// `PUT /tasks/boards/{id}/members` (owner only): [members] replaces the
  /// whole list, so leaving a colleague out takes their access away. Throws
  /// [AppException].
  Future<void> share(String id, List<TaskBoardMember> members) async {
    await _api.setBoardMembers(id, members);
    await refresh();
  }
}

final taskBoardsProvider =
    NotifierProvider<TaskBoardsNotifier, TaskBoardsState>(
      TaskBoardsNotifier.new,
    );

/// Which board the desktop «Задачи» shows; [personalBoardId] = the personal
/// list. A board that disappears (deleted, or no longer shared with the
/// caller) sends the view back to the personal list.
class SelectedTaskBoardNotifier extends Notifier<String> {
  @override
  String build() {
    final boards = ref.watch(taskBoardsProvider);
    final current = stateOrNull;
    if (current == null || current == personalBoardId) return personalBoardId;
    if (boards.loaded && boards.byId(current) == null) return personalBoardId;
    return current;
  }

  void select(String boardId) => state = boardId;
}

final selectedTaskBoardProvider =
    NotifierProvider<SelectedTaskBoardNotifier, String>(
      SelectedTaskBoardNotifier.new,
    );

/// The tasks of one board (or of the personal list), in server order.
final boardTasksProvider = Provider.family<List<Task>, String>((ref, boardId) {
  final tasks = ref.watch(tasksProvider.select((s) => s.tasks));
  return [
    for (final t in tasks)
      if (t.boardId == boardId) t,
  ];
});

/// Entry badge: own open tasks that are overdue or due today.
final tasksBadgeProvider = Provider<int>((ref) {
  if (!ref.watch(tasksEnabledProvider)) return 0;
  final selfId = ref.watch(currentUserProvider)?.id ?? '';
  final tasks = ref.watch(tasksProvider.select((s) => s.tasks));
  return TaskSections.attentionCount(
    tasks,
    selfId,
    ref.read(tasksClockProvider)(),
  );
});

/// Assignee candidates (members of departments the caller manages).
final taskAssigneesProvider = FutureProvider.autoDispose<List<TaskAssignee>>((
  ref,
) async {
  final selfId = ref.watch(currentUserProvider)?.id ?? '';
  if (selfId.isEmpty || !ref.watch(tasksCanAssignProvider)) return const [];
  return ref.watch(tasksApiProvider).assignableUsers(selfId);
});

/// Sign-out hook (lib/features/sessions/sign_out_wipe.dart).
Future<void> tasksSignOut(ProviderContainer container) async {
  await container.read(tasksCacheProvider).clear();
}
