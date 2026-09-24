import '../data/task_models.dart';

/// How the desktop board groups cards.
enum TasksBoardMode { byDue, byStatus }

/// The board's columns. [byDue] mode: no due · today (overdue included) ·
/// tomorrow · later · done. [byStatus] mode: to do · in progress · done.
enum TasksColumn { noDue, today, tomorrow, later, todo, inProgress, done }

abstract final class TasksBoard {
  static const dueColumns = [TasksColumn.noDue, TasksColumn.today, TasksColumn.tomorrow, TasksColumn.later, TasksColumn.done];
  static const statusColumns = [TasksColumn.todo, TasksColumn.inProgress, TasksColumn.done];

  static List<TasksColumn> columns(TasksBoardMode mode) => mode == TasksBoardMode.byDue ? dueColumns : statusColumns;

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Where [task] sits on the board in [mode] at [now] (local time).
  static TasksColumn columnOf(Task task, TasksBoardMode mode, DateTime now) {
    if (task.isDone) return TasksColumn.done;
    if (mode == TasksBoardMode.byStatus) {
      return task.status == TaskStatus.inProgress ? TasksColumn.inProgress : TasksColumn.todo;
    }
    final due = task.dueAt?.toLocal();
    if (due == null) return TasksColumn.noDue;
    final today = _day(now.toLocal());
    final day = _day(due);
    if (!day.isAfter(today)) return TasksColumn.today;
    if (day == today.add(const Duration(days: 1))) return TasksColumn.tomorrow;
    return TasksColumn.later;
  }

  /// Cards in a column: overdue and urgent first, then by due time, then
  /// newest; done cards keep the server order.
  static List<Task> sorted(List<Task> tasks, TasksColumn column) {
    if (column == TasksColumn.done) return tasks;
    int rank(String p) => switch (p) {
      TaskPriority.urgent => 0,
      TaskPriority.high => 1,
      TaskPriority.normal => 2,
      _ => 3,
    };
    final list = [...tasks];
    list.sort((a, b) {
      final ad = a.dueAt;
      final bd = b.dueAt;
      if (ad != null && bd != null && ad != bd) return ad.compareTo(bd);
      if (ad != null && bd == null) return -1;
      if (ad == null && bd != null) return 1;
      final pr = rank(a.priority).compareTo(rank(b.priority));
      if (pr != 0) return pr;
      final ac = a.createdAt;
      final bc = b.createdAt;
      if (ac != null && bc != null) return bc.compareTo(ac);
      return 0;
    });
    return list;
  }

  /// The due time a card gets on [day]: the time it already had (unless it
  /// was midnight), else 18:00; a time already past today becomes 23:59.
  static DateTime dueOn(DateTime day, Task? task, DateTime now) {
    final keep = task?.dueAt?.toLocal();
    final hasTime = keep != null && (keep.hour != 0 || keep.minute != 0);
    var at = DateTime(day.year, day.month, day.day, hasTime ? keep.hour : 18, hasTime ? keep.minute : 0);
    if (!at.isAfter(now)) at = DateTime(day.year, day.month, day.day, 23, 59);
    return at;
  }

  /// The change that puts [task] into [column]; [laterDay] is the day
  /// picked for «Позже». Null when nothing changes (or no day was picked).
  static TaskPatch? patchFor(Task task, TasksColumn column, DateTime now, {DateTime? laterDay}) {
    final local = now.toLocal();
    final today = _day(local);
    // Out of «Готово»: back to work.
    final reopen = task.isDone && column != TasksColumn.done ? TaskStatus.todo : null;
    switch (column) {
      case TasksColumn.done:
        return task.isDone ? null : const TaskPatch(status: TaskStatus.done);
      case TasksColumn.todo:
        return task.status == TaskStatus.todo ? null : const TaskPatch(status: TaskStatus.todo);
      case TasksColumn.inProgress:
        return task.status == TaskStatus.inProgress ? null : const TaskPatch(status: TaskStatus.inProgress);
      case TasksColumn.noDue:
        if (task.dueAt == null && reopen == null) return null;
        return TaskPatch(clearDue: task.dueAt != null, status: reopen);
      case TasksColumn.today:
      case TasksColumn.tomorrow:
        final day = column == TasksColumn.today ? today : today.add(const Duration(days: 1));
        final current = task.dueAt?.toLocal();
        // Already due that day (or overdue into «Сегодня»): only reopen.
        if (current != null && reopen == null && _day(current) == day) return null;
        return TaskPatch(dueAt: dueOn(day, task, local), status: reopen);
      case TasksColumn.later:
        if (laterDay == null) return null;
        return TaskPatch(dueAt: dueOn(_day(laterDay), task, local), status: reopen);
    }
  }

  /// The due time of a task quick-added to [column] (null: no due).
  static DateTime? quickAddDue(TasksColumn column, DateTime now) {
    final today = _day(now.toLocal());
    return switch (column) {
      TasksColumn.today => dueOn(today, null, now.toLocal()),
      TasksColumn.tomorrow => dueOn(today.add(const Duration(days: 1)), null, now.toLocal()),
      _ => null,
    };
  }

  /// Columns that take a quick-added card.
  static bool canQuickAdd(TasksColumn column) =>
      column == TasksColumn.noDue ||
      column == TasksColumn.today ||
      column == TasksColumn.tomorrow ||
      column == TasksColumn.todo ||
      column == TasksColumn.inProgress;
}
