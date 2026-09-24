import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/features/tasks/data/task_models.dart';
import 'package:xatbox_mobile/features/tasks/presentation/tasks_board_logic.dart';

/// The desktop tasks board: which column a card sits in and what a drop
/// changes (due date or status).
void main() {
  // Wednesday 16 September 2026, 10:30 local.
  final now = DateTime(2026, 9, 16, 10, 30);

  Task task({DateTime? due, String status = TaskStatus.todo, String priority = TaskPriority.normal, String id = 't'}) => Task(
    id: id,
    ownerUserId: 'me',
    title: 'Задача',
    dueAt: due,
    status: status,
    priority: priority,
  );

  group('columnOf', () {
    test('by due date: no due, today (overdue too), tomorrow, later, done', () {
      TasksColumn col(Task t) => TasksBoard.columnOf(t, TasksBoardMode.byDue, now);
      expect(col(task()), TasksColumn.noDue);
      expect(col(task(due: DateTime(2026, 9, 16, 18))), TasksColumn.today);
      expect(col(task(due: DateTime(2026, 9, 14, 9))), TasksColumn.today);
      expect(col(task(due: DateTime(2026, 9, 17, 9))), TasksColumn.tomorrow);
      expect(col(task(due: DateTime(2026, 9, 30, 9))), TasksColumn.later);
      expect(col(task(due: DateTime(2026, 9, 17), status: TaskStatus.done)), TasksColumn.done);
    });

    test('by status', () {
      TasksColumn col(Task t) => TasksBoard.columnOf(t, TasksBoardMode.byStatus, now);
      expect(col(task()), TasksColumn.todo);
      expect(col(task(status: TaskStatus.inProgress)), TasksColumn.inProgress);
      expect(col(task(status: TaskStatus.done)), TasksColumn.done);
    });
  });

  group('patchFor', () {
    test('today / tomorrow keep the time of day, else 18:00', () {
      final noDue = TasksBoard.patchFor(task(), TasksColumn.today, now)!;
      expect(noDue.dueAt, DateTime(2026, 9, 16, 18));
      expect(noDue.status, isNull);

      final at9 = TasksBoard.patchFor(task(due: DateTime(2026, 9, 20, 9, 15)), TasksColumn.tomorrow, now)!;
      expect(at9.dueAt, DateTime(2026, 9, 17, 9, 15));
    });

    test('a time already past today becomes 23:59', () {
      final p = TasksBoard.patchFor(task(due: DateTime(2026, 9, 20, 9)), TasksColumn.today, now)!;
      expect(p.dueAt, DateTime(2026, 9, 16, 23, 59));
    });

    test('an overdue card dropped on «Сегодня» moves to today', () {
      final p = TasksBoard.patchFor(task(due: DateTime(2026, 9, 14, 12)), TasksColumn.today, now);
      expect(p?.dueAt, DateTime(2026, 9, 16, 12));
      expect(TasksBoard.patchFor(task(due: DateTime(2026, 9, 16, 18)), TasksColumn.today, now), isNull);
    });

    test('no due clears the date; done marks done; out of done reopens', () {
      expect(TasksBoard.patchFor(task(due: DateTime(2026, 9, 17)), TasksColumn.noDue, now)!.toJson(), {'due_at': ''});
      expect(TasksBoard.patchFor(task(), TasksColumn.noDue, now), isNull);
      expect(TasksBoard.patchFor(task(), TasksColumn.done, now)!.toJson(), {'status': 'done'});
      final reopened = TasksBoard.patchFor(task(status: TaskStatus.done), TasksColumn.tomorrow, now)!;
      expect(reopened.status, TaskStatus.todo);
      expect(reopened.dueAt, DateTime(2026, 9, 17, 18));
    });

    test('later needs a picked day', () {
      expect(TasksBoard.patchFor(task(), TasksColumn.later, now), isNull);
      final p = TasksBoard.patchFor(task(), TasksColumn.later, now, laterDay: DateTime(2026, 9, 25))!;
      expect(p.dueAt, DateTime(2026, 9, 25, 18));
    });

    test('status columns', () {
      expect(TasksBoard.patchFor(task(), TasksColumn.inProgress, now)!.toJson(), {'status': 'in_progress'});
      expect(TasksBoard.patchFor(task(status: TaskStatus.inProgress), TasksColumn.todo, now)!.toJson(), {'status': 'todo'});
      expect(TasksBoard.patchFor(task(), TasksColumn.todo, now), isNull);
    });
  });

  test('sorted: by due time, then priority; no due last', () {
    final list = TasksBoard.sorted([
      task(id: 'a'),
      task(id: 'b', due: DateTime(2026, 9, 16, 18)),
      task(id: 'c', due: DateTime(2026, 9, 16, 9)),
      task(id: 'd', priority: TaskPriority.urgent),
    ], TasksColumn.today);
    expect(list.map((t) => t.id), ['c', 'b', 'd', 'a']);
  });

  test('patched applies a patch for the optimistic move', () {
    final t = task(due: DateTime(2026, 9, 17));
    expect(t.patched(const TaskPatch(clearDue: true)).dueAt, isNull);
    expect(t.patched(const TaskPatch(status: TaskStatus.done)).isDone, isTrue);
    expect(t.patched(TaskPatch(dueAt: DateTime(2026, 9, 20))).dueAt, DateTime(2026, 9, 20));
  });

  test('quick add due: today 18:00, tomorrow 18:00, else none', () {
    expect(TasksBoard.quickAddDue(TasksColumn.today, now), DateTime(2026, 9, 16, 18));
    expect(TasksBoard.quickAddDue(TasksColumn.tomorrow, now), DateTime(2026, 9, 17, 18));
    expect(TasksBoard.quickAddDue(TasksColumn.noDue, now), isNull);
  });
}
