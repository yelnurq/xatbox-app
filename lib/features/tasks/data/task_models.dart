import '../../../shared/utils/api_date.dart';

/// Values of `Task.status`.
abstract final class TaskStatus {
  static const todo = 'todo';
  static const inProgress = 'in_progress';
  static const done = 'done';
}

/// Values of `Task.priority`.
abstract final class TaskPriority {
  static const low = 'low';
  static const normal = 'normal';
  static const high = 'high';
  static const urgent = 'urgent';
  static const all = [low, normal, high, urgent];
}

/// Values of `Task.source_type`.
abstract final class TaskSource {
  static const manual = 'manual';
  static const email = 'email';
  static const chat = 'chat';
  static const official = 'official';
}

/// A to-do item of the Mail API (`Task`). Timestamps arrive as PostgreSQL
/// `timestamptz` text (`2026-09-14 09:00:00+00`) and are parsed by
/// [parseApiDate]; the cache stores them as RFC 3339.
class Task {
  const Task({
    required this.id,
    required this.ownerUserId,
    required this.title,
    this.description = '',
    this.assignedByUserId = '',
    this.assignedByName = '',
    this.dueAt,
    this.priority = TaskPriority.normal,
    this.status = TaskStatus.todo,
    this.sourceType = TaskSource.manual,
    this.sourceId = '',
    this.reminderAt,
    this.createdAt,
    this.boardId = '',
    this.canEdit,
    this.archived = false,
  });

  final String id;

  /// The responsible user. They may always edit or delete the task; on a
  /// shared board its owner and editors may too ([editableBy]).
  final String ownerUserId;
  final String assignedByUserId;
  final String assignedByName;
  final String title;
  final String description;
  final DateTime? dueAt;
  final String priority;
  final String status;
  final String sourceType;
  final String sourceId;

  /// Earliest still-pending reminder; the server drops it once it fired.
  final DateTime? reminderAt;
  final DateTime? createdAt;

  /// The board this task sits on; empty = the personal list.
  final String boardId;

  /// What the service said about the caller's rights (`can_edit`). Null on a
  /// service released before boards, where owning the task was the only way
  /// to edit it.
  final bool? canEdit;

  /// In the archive: out of the board, listed by `GET /tasks?archived=1`.
  final bool archived;

  bool get isDone => status == TaskStatus.done;
  bool isOwnedBy(String userId) => userId.isNotEmpty && ownerUserId == userId;

  /// Whether [userId] may change this task: its owner may, and so may the
  /// owner and the editors of the board it sits on.
  bool editableBy(String userId) => canEdit ?? isOwnedBy(userId);

  /// On the personal list rather than on a board.
  bool get isPersonal => boardId.isEmpty;

  /// Linked mail message (opens the message screen).
  String? get mailMessageId =>
      sourceType == TaskSource.email && sourceId.isNotEmpty ? sourceId : null;

  bool isOverdue(DateTime now) =>
      !isDone && dueAt != null && dueAt!.isBefore(now);

  bool isDueToday(DateTime now) {
    final due = dueAt?.toLocal();
    if (isDone || due == null) return false;
    final local = now.toLocal();
    return due.year == local.year &&
        due.month == local.month &&
        due.day == local.day;
  }

  factory Task.fromJson(Map<String, dynamic> j) => Task(
    id: (j['id'] as String?) ?? '',
    ownerUserId: (j['owner_user_id'] as String?) ?? '',
    assignedByUserId: (j['assigned_by_user_id'] as String?) ?? '',
    assignedByName: (j['assigned_by_name'] as String?) ?? '',
    title: (j['title'] as String?) ?? '',
    description: (j['description'] as String?) ?? '',
    dueAt: parseApiDate(j['due_at'] as String?),
    priority: (j['priority'] as String?) ?? TaskPriority.normal,
    status: (j['status'] as String?) ?? TaskStatus.todo,
    sourceType: (j['source_type'] as String?) ?? TaskSource.manual,
    sourceId: (j['source_id'] as String?) ?? '',
    reminderAt: parseApiDate(j['reminder_at'] as String?),
    createdAt: parseApiDate(j['created_at'] as String?),
    boardId: (j['board_id'] as String?) ?? '',
    canEdit: j['can_edit'] as bool?,
    archived: (j['archived'] as bool?) ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_user_id': ownerUserId,
    if (assignedByUserId.isNotEmpty) 'assigned_by_user_id': assignedByUserId,
    if (assignedByName.isNotEmpty) 'assigned_by_name': assignedByName,
    'title': title,
    'description': description,
    if (dueAt != null) 'due_at': dueAt!.toUtc().toIso8601String(),
    'priority': priority,
    'status': status,
    'source_type': sourceType,
    if (sourceId.isNotEmpty) 'source_id': sourceId,
    if (reminderAt != null)
      'reminder_at': reminderAt!.toUtc().toIso8601String(),
    if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
    if (boardId.isNotEmpty) 'board_id': boardId,
    if (canEdit != null) 'can_edit': canEdit,
    if (archived) 'archived': true,
  };

  Task copyWith({String? status, String? boardId, bool? archived}) => Task(
    id: id,
    ownerUserId: ownerUserId,
    assignedByUserId: assignedByUserId,
    assignedByName: assignedByName,
    title: title,
    description: description,
    dueAt: dueAt,
    priority: priority,
    status: status ?? this.status,
    sourceType: sourceType,
    sourceId: sourceId,
    reminderAt: reminderAt,
    createdAt: createdAt,
    boardId: boardId ?? this.boardId,
    canEdit: canEdit,
    archived: archived ?? this.archived,
  );
}

extension TaskPatching on Task {
  /// This task as it will be once [p] is applied (optimistic board moves).
  Task patched(TaskPatch p) => Task(
    id: id,
    ownerUserId: ownerUserId,
    assignedByUserId: assignedByUserId,
    assignedByName: assignedByName,
    title: p.title ?? title,
    description: p.description ?? description,
    dueAt: p.clearDue ? null : (p.dueAt ?? dueAt),
    priority: p.priority ?? priority,
    status: p.status ?? status,
    sourceType: sourceType,
    sourceId: sourceId,
    reminderAt: reminderAt,
    createdAt: createdAt,
    boardId: p.boardId ?? boardId,
    canEdit: canEdit,
    archived: p.archived ?? archived,
  );
}

/// Body of `POST /tasks` (`TaskCreateRequest`).
class TaskDraft {
  const TaskDraft({
    required this.title,
    this.description = '',
    this.ownerUserId,
    this.dueAt,
    this.reminderAt,
    this.priority,
    this.sourceType,
    this.sourceId,
    this.boardId,
  });

  final String title;
  final String description;

  /// `null` = the caller. Another user needs `tasks.assign.department`.
  final String? ownerUserId;
  final DateTime? dueAt;
  final DateTime? reminderAt;
  final String? priority;
  final String? sourceType;
  final String? sourceId;

  /// `null` / empty = the owner's personal list. A board needs write access
  /// to it (its owner or one of its editors).
  final String? boardId;

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    if (description.trim().isNotEmpty) 'description': description.trim(),
    if (ownerUserId != null && ownerUserId!.isNotEmpty)
      'owner_user_id': ownerUserId,
    if (dueAt != null) 'due_at': dueAt!.toUtc().toIso8601String(),
    if (reminderAt != null)
      'reminder_at': reminderAt!.toUtc().toIso8601String(),
    'priority': ?priority,
    'source_type': ?sourceType,
    if (sourceId != null && sourceId!.isNotEmpty) 'source_id': sourceId,
    if (boardId != null && boardId!.isNotEmpty) 'board_id': boardId,
  };
}

/// Body of `PATCH /tasks/{id}` (`TaskPatchRequest`). Omitted fields stay
/// unchanged; [clearDue] sends `due_at: ""`. Reminders cannot be patched.
class TaskPatch {
  const TaskPatch({
    this.title,
    this.description,
    this.dueAt,
    this.clearDue = false,
    this.priority,
    this.status,
    this.boardId,
    this.archived,
  });

  final String? title;
  final String? description;
  final DateTime? dueAt;
  final bool clearDue;
  final String? priority;
  final String? status;

  /// true sends the task to the archive, false brings it back to its board.
  final bool? archived;

  /// Moves the task: a board id puts it on that board, `''` sends it back to
  /// the owner's personal list. Null leaves it where it is.
  final String? boardId;

  bool get isEmpty =>
      title == null &&
      description == null &&
      dueAt == null &&
      !clearDue &&
      priority == null &&
      status == null &&
      boardId == null &&
      archived == null;

  Map<String, dynamic> toJson() => {
    'title': ?title,
    'description': ?description,
    if (clearDue)
      'due_at': ''
    else if (dueAt != null)
      'due_at': dueAt!.toUtc().toIso8601String(),
    'priority': ?priority,
    'status': ?status,
    'board_id': ?boardId,
    'archived': ?archived,
  };
}

/// Roles on a task board. The owner is not a member: owning the board is
/// what allows renaming, sharing and deleting it.
abstract final class TaskBoardRole {
  static const owner = 'owner';

  /// Works on the board's tasks as if they were their own.
  static const editor = 'editor';

  /// Reads the board's tasks and nothing else.
  static const viewer = 'viewer';
}

/// A colleague a board is shared with (`TaskBoardMember`).
class TaskBoardMember {
  const TaskBoardMember({
    required this.userId,
    this.displayName = '',
    this.email = '',
    this.role = TaskBoardRole.editor,
  });

  final String userId;
  final String displayName;
  final String email;
  final String role;

  String get label => displayName.trim().isNotEmpty ? displayName.trim() : email;
  bool get canWrite => role == TaskBoardRole.editor;

  TaskBoardMember withRole(String role) => TaskBoardMember(
    userId: userId,
    displayName: displayName,
    email: email,
    role: role,
  );

  factory TaskBoardMember.fromJson(Map<String, dynamic> j) => TaskBoardMember(
    userId: (j['user_id'] as String?) ?? '',
    displayName: (j['display_name'] as String?) ?? '',
    email: (j['email'] as String?) ?? '',
    role: (j['role'] as String?) ?? TaskBoardRole.editor,
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    if (displayName.isNotEmpty) 'display_name': displayName,
    if (email.isNotEmpty) 'email': email,
    'role': role,
  };

  /// What `PUT /tasks/boards/{id}/members` expects.
  Map<String, dynamic> toMemberRequest() => {'user_id': userId, 'role': role};
}

/// A board of the tasks module (`TaskBoard`): a named group of tasks its
/// owner may hand to colleagues. The personal list is not a board — it is
/// every task without a `board_id`.
class TaskBoard {
  const TaskBoard({
    required this.id,
    required this.name,
    this.description = '',
    this.color = '',
    this.position = 0,
    this.ownerUserId = '',
    this.ownerName = '',
    this.role = TaskBoardRole.owner,
    this.members = const [],
    this.taskCount = 0,
    this.openCount = 0,
    this.createdAt,
  });

  final String id;
  final String name;
  final String description;

  /// Accent chosen in the app; empty = the default one.
  final String color;
  final int position;
  final String ownerUserId;
  final String ownerName;

  /// What the caller may do here: owner, editor or viewer.
  final String role;
  final List<TaskBoardMember> members;
  final int taskCount;
  final int openCount;
  final DateTime? createdAt;

  bool get isOwner => role == TaskBoardRole.owner;

  /// The caller may add, edit and move this board's tasks.
  bool get canWrite => role == TaskBoardRole.owner || role == TaskBoardRole.editor;

  /// Someone else's board, shared with the caller.
  bool get isShared => members.isNotEmpty || !isOwner;

  factory TaskBoard.fromJson(Map<String, dynamic> j) => TaskBoard(
    id: (j['id'] as String?) ?? '',
    name: (j['name'] as String?) ?? '',
    description: (j['description'] as String?) ?? '',
    color: (j['color'] as String?) ?? '',
    position: (j['position'] as num?)?.toInt() ?? 0,
    ownerUserId: (j['owner_user_id'] as String?) ?? '',
    ownerName: (j['owner_name'] as String?) ?? '',
    role: (j['role'] as String?) ?? TaskBoardRole.owner,
    members: ((j['members'] as List?) ?? const [])
        .map((e) => TaskBoardMember.fromJson((e as Map).cast<String, dynamic>()))
        .where((m) => m.userId.isNotEmpty)
        .toList(),
    taskCount: (j['task_count'] as num?)?.toInt() ?? 0,
    openCount: (j['open_count'] as num?)?.toInt() ?? 0,
    createdAt: parseApiDate(j['created_at'] as String?),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (description.isNotEmpty) 'description': description,
    if (color.isNotEmpty) 'color': color,
    'position': position,
    'owner_user_id': ownerUserId,
    if (ownerName.isNotEmpty) 'owner_name': ownerName,
    'role': role,
    'members': [for (final m in members) m.toJson()],
    'task_count': taskCount,
    'open_count': openCount,
    if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
  };

  TaskBoard copyWith({
    String? name,
    String? description,
    String? color,
    List<TaskBoardMember>? members,
  }) => TaskBoard(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    color: color ?? this.color,
    position: position,
    ownerUserId: ownerUserId,
    ownerName: ownerName,
    role: role,
    members: members ?? this.members,
    taskCount: taskCount,
    openCount: openCount,
    createdAt: createdAt,
  );
}

/// Body of `POST /tasks/boards` (`TaskBoardCreateRequest`).
class TaskBoardDraft {
  const TaskBoardDraft({
    required this.name,
    this.description = '',
    this.color = '',
    this.position,
  });

  final String name;
  final String description;
  final String color;
  final int? position;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    if (description.trim().isNotEmpty) 'description': description.trim(),
    if (color.isNotEmpty) 'color': color,
    'position': ?position,
  };
}

/// Body of `PATCH /tasks/boards/{id}` (`TaskBoardPatchRequest`). Omitted
/// fields stay unchanged.
class TaskBoardPatch {
  const TaskBoardPatch({this.name, this.description, this.color, this.position});

  final String? name;
  final String? description;
  final String? color;
  final int? position;

  bool get isEmpty =>
      name == null && description == null && color == null && position == null;

  Map<String, dynamic> toJson() => {
    'name': ?name?.trim(),
    'description': ?description,
    'color': ?color,
    'position': ?position,
  };
}

/// A colleague the caller may assign a task to (`DirectoryUser`).
class TaskAssignee {
  const TaskAssignee({
    required this.id,
    required this.name,
    this.email = '',
    this.departmentName = '',
  });

  final String id;
  final String name;
  final String email;
  final String departmentName;

  String get label => name.trim().isNotEmpty ? name.trim() : email;

  factory TaskAssignee.fromJson(Map<String, dynamic> j) => TaskAssignee(
    id: (j['id'] as String?) ?? '',
    name: (j['display_name'] as String?) ?? '',
    email: (j['email'] as String?) ?? '',
    departmentName: (j['department_name'] as String?) ?? '',
  );
}

/// The «Мои задачи» grouping (the phone screen). Server order (open first,
/// due ascending, no due last, newest first) is kept inside each section.
class TaskSections {
  const TaskSections({
    required this.mine,
    required this.assigned,
    required this.done,
  });

  /// Open tasks the caller owns.
  final List<Task> mine;

  /// Open tasks the caller assigned to someone else (read-only).
  final List<Task> assigned;

  /// Completed tasks of both kinds (collapsed in the UI).
  final List<Task> done;

  /// Only what the user is part of: their own tasks and the ones they
  /// assigned to somebody else. A colleague's task seen through a shared
  /// board belongs to that board (the desktop «Задачи»), not to this list.
  factory TaskSections.of(List<Task> tasks, String selfId) {
    final mine = <Task>[];
    final assigned = <Task>[];
    final done = <Task>[];
    for (final t in tasks) {
      final own = t.isOwnedBy(selfId);
      if (!own && !t.isPersonal && t.assignedByUserId != selfId) continue;
      if (t.isDone) {
        done.add(t);
      } else if (own) {
        mine.add(t);
      } else {
        assigned.add(t);
      }
    }
    return TaskSections(mine: mine, assigned: assigned, done: done);
  }

  /// Badge: open own tasks that are overdue or due today.
  static int attentionCount(List<Task> tasks, String selfId, DateTime now) =>
      tasks
          .where(
            (t) =>
                t.isOwnedBy(selfId) && (t.isOverdue(now) || t.isDueToday(now)),
          )
          .length;
}
