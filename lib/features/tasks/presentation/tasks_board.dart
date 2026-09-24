import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/localization/localization.dart';
import '../../../core/platform/desktop.dart';
import '../../../core/platform/desktop_layout.dart';
import '../../../core/preferences/app_preferences.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/skin_backdrop.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/error_text.dart';
import '../../../shared/widgets/state_view.dart';
import '../data/task_models.dart';
import 'task_boards_rail.dart';
import 'task_edit_sheet.dart';
import 'tasks_board_logic.dart';
import 'tasks_archive_dialog.dart';
import 'tasks_format.dart';
import 'tasks_providers.dart';

/// Desktop «Задачи»: a Kanban board per board. The rail on the left holds
/// «Мои задачи» (every task without a board) and the boards the user owns or
/// was given; a card dragged onto a rail row moves to that board. The
/// columns are by due date (Без срока · Сегодня · Завтра · Позже · Готово)
/// or by status (К выполнению · В работе · Готово); editable cards are
/// dragged between them and the due date or status follows. Each column
/// adds a task from one line; a click opens the task, a right click its
/// menu.
class TasksBoardScreen extends ConsumerStatefulWidget {
  const TasksBoardScreen({super.key, this.openTaskId});

  /// Opened once the list is loaded (link, notification).
  final String? openTaskId;

  @override
  ConsumerState<TasksBoardScreen> createState() => _TasksBoardScreenState();
}

class _TasksBoardScreenState extends ConsumerState<TasksBoardScreen> {
  TasksBoardMode _mode = TasksBoardMode.byDue;

  /// «Я поручил(а)»: tasks the user gave to colleagues (read-only cards).
  bool _assigned = false;
  bool _allDone = false;
  bool _openHandled = false;
  String _query = '';
  final _search = TextEditingController();

  static const _doneLimit = 8;

  /// Below this the page header stacks: title, then toolbar.
  static const _toolbarBreakpoint = 1040.0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final s = ref.read(tasksProvider);
      if (s.loaded && !s.loading) unawaited(ref.read(tasksProvider.notifier).refresh());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _maybeOpenRequested(TasksState state) {
    final id = widget.openTaskId;
    if (id == null || _openHandled || !state.loaded || state.loading) return;
    _openHandled = true;
    final task = state.tasks.where((t) => t.id == id).firstOrNull;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (task == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.tasksNotFound)));
      } else {
        unawaited(showTaskSheet(context, task: task));
      }
    });
  }

  DateTime get _now => ref.read(tasksClockProvider)();

  void _report(AppException? error) {
    if (error == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TasksFormat.error(context.l10n, error))));
  }

  /// A card dropped on [column].
  Future<void> _drop(Task task, TasksColumn column) async {
    DateTime? later;
    if (column == TasksColumn.later) {
      final now = _now;
      final first = DateTime(now.year, now.month, now.day + 2);
      final current = task.dueAt?.toLocal();
      later = await showDatePicker(
        context: context,
        helpText: context.l10n.tasksPickDay,
        initialDate: current != null && current.isAfter(first) ? current : first,
        firstDate: first,
        lastDate: DateTime(now.year + 5),
      );
      if (later == null || !mounted) return;
    }
    final patch = TasksBoard.patchFor(task, column, _now, laterDay: later);
    if (patch == null) return;
    _report(await ref.read(tasksProvider.notifier).move(task, patch));
  }

  Future<void> _quickAdd(TasksColumn column, String title) async {
    final notifier = ref.read(tasksProvider.notifier);
    try {
      final id = await notifier.create(
        TaskDraft(
          title: title,
          dueAt: TasksBoard.quickAddDue(column, _now),
          boardId: ref.read(selectedTaskBoardProvider),
        ),
      );
      if (column == TasksColumn.inProgress) {
        await notifier.update(id, const TaskPatch(status: TaskStatus.inProgress));
      }
    } on AppException catch (e) {
      _report(e);
    }
  }

  /// A card dropped on a rail row: the task changes board. The personal
  /// list is the empty board id.
  Future<void> _moveToBoard(Task task, String boardId) async {
    if (task.boardId == boardId) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final name = boardId == personalBoardId
        ? l10n.taskBoardPersonal
        : ref.read(taskBoardsProvider).byId(boardId)?.name ?? '';
    final error = await ref
        .read(tasksProvider.notifier)
        .move(task, TaskPatch(boardId: boardId));
    if (!mounted) return;
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(TasksFormat.error(l10n, error))),
      );
      return;
    }
    unawaited(ref.read(taskBoardsProvider.notifier).refresh());
    messenger.showSnackBar(SnackBar(content: Text(l10n.taskBoardMoved(name))));
  }

  Future<void> _delete(Task task) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tasksDelete),
        content: Text(l10n.tasksDeleteConfirm(task.title)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(key: const Key('task_delete_confirm'), onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref.read(tasksProvider.notifier).delete(task);
    messenger.showSnackBar(SnackBar(content: Text(error == null ? l10n.tasksDeleted : TasksFormat.error(l10n, error))));
  }

  /// Phone: the boards (the desktop's rail) as a sheet; picking one closes it.
  Future<void> _pickBoard(BuildContext context) {
    final selfId = ref.read(currentUserProvider)?.id ?? '';
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheet) => FractionallySizedBox(
        heightFactor: 0.75,
        child: Consumer(
          builder: (context, ref, _) {
            ref.listen(selectedTaskBoardProvider, (prev, next) {
              if (prev != next && Navigator.of(sheet).canPop()) Navigator.of(sheet).pop();
            });
            return TaskBoardsRail(
              key: const Key('tasks_board_sheet'),
              selfId: selfId,
              expand: true,
              onMove: (task, to) => unawaited(_moveToBoard(task, to)),
            );
          },
        ),
      ),
    );
  }

  Future<void> _menu(Task task, Offset at, bool own) async {
    final l10n = context.l10n;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    PopupMenuItem<String> item(String value, IconData icon, String label, {Color? color}) => PopupMenuItem(
      key: Key('task_menu_$value'),
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: Space.smd),
          Text(label, style: color == null ? null : TextStyle(color: color)),
        ],
      ),
    );
    final picked = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(at & const Size(1, 1), Offset.zero & overlay.size),
      items: [
        item('open', LucideIcons.pencil, own ? l10n.tasksEdit : l10n.tasksOpen),
        if (own && !task.isDone && task.status != TaskStatus.inProgress)
          item('progress', LucideIcons.play, l10n.tasksMarkInProgress),
        if (own) item('done', task.isDone ? LucideIcons.rotateCcw : LucideIcons.check, task.isDone ? l10n.tasksMarkUndone : l10n.tasksMarkDone),
        if (task.mailMessageId != null) item('mail', LucideIcons.mail, l10n.tasksOpenMessage),
        if (own && task.isDone) item('archive', LucideIcons.archive, l10n.tasksArchive),
        if (own) item('delete', LucideIcons.trash2, l10n.tasksDelete, color: context.tokens.danger),
      ],
    );
    if (!mounted) return;
    switch (picked) {
      case 'open':
        unawaited(showTaskSheet(context, task: task));
      case 'progress':
        _report(await ref.read(tasksProvider.notifier).move(task, const TaskPatch(status: TaskStatus.inProgress)));
      case 'done':
        _report(await ref.read(tasksProvider.notifier).setDone(task, !task.isDone));
      case 'mail':
        unawaited(context.push(Routes.mailMessagePath(task.mailMessageId!)));
      case 'archive':
        final error = await ref.read(tasksProvider.notifier).setArchived(task, true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error == null ? l10n.tasksArchived : TasksFormat.error(l10n, error))),
        );
      case 'delete':
        await _delete(task);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final enabled = ref.watch(tasksEnabledProvider);
    final railHidden = ref.watch(appPreferencesProvider.select((p) => p.tasksRailHidden));
    final state = ref.watch(tasksProvider);
    final notifier = ref.read(tasksProvider.notifier);
    final selfId = ref.watch(currentUserProvider)?.id ?? '';
    final boardId = ref.watch(selectedTaskBoardProvider);
    final board = boardId == personalBoardId
        ? null
        : ref.watch(taskBoardsProvider).byId(boardId);
    final onPersonal = board == null;
    // A board shared for reading only: its cards open but never move.
    final canWrite = onPersonal || board.canWrite;
    _maybeOpenRequested(state);

    final Widget body;
    if (!enabled) {
      body = StateView.empty(title: l10n.tasksUnavailable, icon: LucideIcons.lock);
    } else if (state.tasks.isEmpty && !state.loaded) {
      body = const StateView.loading();
    } else if (state.tasks.isEmpty && state.error != null) {
      body = ErrorText.isOffline(state.error)
          ? StateView.offline(message: ErrorText.describe(l10n, state.error!), onRetry: notifier.refresh)
          : StateView.error(message: TasksFormat.error(l10n, state.error!), onRetry: notifier.refresh);
    } else {
      body = _board(context, state, selfId, boardId, canWrite);
    }

    final now = _now;
    // The figures at the top are about the user's own work, wherever it sits.
    final mine = [for (final x in state.tasks) if (x.isOwnedBy(selfId)) x];
    final overdue = mine.where((x) => x.isOverdue(now)).length;
    final today = mine.where((x) => x.isDueToday(now) && !x.isOverdue(now)).length;
    final done = mine.where((x) => x.isDone).length;
    final hasAssigned = onPersonal &&
        state.tasks.any((x) => x.isPersonal && !x.isOwnedBy(selfId));

    final content = _content(
      context,
      l10n: l10n,
      t: t,
      state: state,
      notifier: notifier,
      enabled: enabled,
      board: board,
      canWrite: canWrite,
      railHidden: railHidden,
      hasAssigned: hasAssigned,
      today: today,
      overdue: overdue,
      done: done,
      body: body,
    );
    // Phone: no rail beside the board — the board's name opens the boards
    // as a sheet — and the page keeps clear of the status bar.
    if (!ref.watch(desktopLayoutProvider)) {
      return Scaffold(body: SafeArea(bottom: false, child: content));
    }
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (enabled && !railHidden)
            TaskBoardsRail(selfId: selfId, onMove: (task, to) => unawaited(_moveToBoard(task, to))),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _content(
    BuildContext context, {
    required AppLocalizations l10n,
    required XatBoxTokens t,
    required TasksState state,
    required TasksNotifier notifier,
    required bool enabled,
    required TaskBoard? board,
    required bool canWrite,
    required bool railHidden,
    required bool hasAssigned,
    required int today,
    required int overdue,
    required int done,
    required Widget body,
  }) {
    final onPersonal = board == null;
    final phone = !ref.watch(desktopLayoutProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(phone ? Space.md : Space.lg, phone ? Space.md : Space.lg, phone ? Space.md : Space.lg, Space.sm),
          child: LayoutBuilder(
            builder: (context, box) {
              final heading = Text(
                t.pageTitle(board?.name ?? l10n.tasksTitle),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: t.fontDisplay, fontSize: phone ? 24 : 26, fontWeight: FontWeight.w700, color: t.textPrimary),
              );
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (phone && enabled)
                    InkWell(
                      key: const Key('tasks_board_picker'),
                      borderRadius: BorderRadius.circular(t.radiusSm),
                      onTap: () => unawaited(_pickBoard(context)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: heading),
                          const SizedBox(width: Space.xs),
                          Icon(LucideIcons.chevronDown, size: 20, color: t.textSecondary),
                        ],
                      ),
                    )
                  else
                    heading,
                  const SizedBox(height: Space.xs),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.xs,
                    children: [
                      if (board != null) ...[
                        _Stat(
                          icon: board.canWrite ? LucideIcons.users : LucideIcons.eye,
                          text: board.isOwner
                              ? l10n.taskBoardShareMembers(board.members.length)
                              : l10n.taskBoardOwnedBy(board.ownerName),
                          color: TaskBoardColors.of(t, board.color),
                        ),
                        _Stat(
                          icon: LucideIcons.listChecks,
                          text: l10n.taskBoardOpenCount(board.openCount),
                          color: t.info,
                        ),
                      ],
                      _Stat(icon: LucideIcons.sun, text: l10n.tasksStatToday(today), color: t.warning),
                      if (overdue > 0) _Stat(icon: LucideIcons.flame, text: l10n.tasksStatOverdue(overdue), color: t.danger),
                      _Stat(icon: LucideIcons.circleCheck, text: l10n.tasksStatDone(done), color: t.success),
                    ],
                  ),
                ],
              );
              final search = SizedBox(
                width: phone ? null : 240,
                height: 38,
                child: TextField(
                  key: const Key('tasks_search'),
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: l10n.tasksSearchHint,
                    prefixIcon: const Icon(LucideIcons.search, size: 16),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    filled: true,
                    fillColor: t.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.border)),
                  ),
                ),
              );
              final modes = _Segmented<TasksBoardMode>(
                value: _mode,
                items: {
                  TasksBoardMode.byDue: (LucideIcons.calendarDays, l10n.tasksBoardByDue),
                  TasksBoardMode.byStatus: (LucideIcons.columns3, l10n.tasksBoardByStatus),
                },
                keyPrefix: 'tasks_mode',
                onChanged: (m) => setState(() => _mode = m),
              );
              final scope = onPersonal && (hasAssigned || ref.watch(tasksCanAssignProvider))
                  ? _Segmented<bool>(
                      value: _assigned,
                      items: {
                        false: (LucideIcons.user, l10n.tasksSectionMine),
                        true: (LucideIcons.send, l10n.tasksSectionAssigned),
                      },
                      keyPrefix: 'tasks_scope',
                      onChanged: (v) => setState(() => _assigned = v),
                    )
                  : null;
              final archive = IconButton(
                key: const Key('tasks_archive'),
                tooltip: l10n.tasksArchiveTitle,
                onPressed: enabled ? () => unawaited(showTasksArchive(context, boardId: board?.id ?? '')) : null,
                icon: const Icon(LucideIcons.archive),
              );
              final create = enabled && canWrite
                  ? () => unawaited(showTaskSheet(context, boardId: board?.id ?? personalBoardId))
                  : null;
              // Phone: search across, the new-task button round beside it,
              // the switches on a line of their own.
              if (phone) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    const SizedBox(height: Space.smd),
                    Row(
                      children: [
                        Expanded(child: search),
                        archive,
                        IconButton.filled(
                          key: const Key('tasks_new'),
                          tooltip: l10n.tasksNew,
                          style: IconButton.styleFrom(backgroundColor: t.primary, foregroundColor: t.textInverse),
                          onPressed: create,
                          icon: const Icon(LucideIcons.plus),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.sm),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          modes,
                          if (scope != null) ...[const SizedBox(width: Space.sm), scope],
                        ],
                      ),
                    ),
                  ],
                );
              }
              final toolbar = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('tasks_rail_toggle'),
                    tooltip: railHidden ? l10n.taskBoardsRailShow : l10n.taskBoardsRailHide,
                    onPressed: () => unawaited(
                      ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(tasksRailHidden: !railHidden)),
                    ),
                    icon: Icon(railHidden ? LucideIcons.panelLeftOpen : LucideIcons.panelLeftClose),
                  ),
                  const SizedBox(width: Space.xs),
                  search,
                  const SizedBox(width: Space.sm),
                  modes,
                  if (scope != null) ...[const SizedBox(width: Space.sm), scope],
                  const SizedBox(width: Space.sm),
                  archive,
                  IconButton(
                    key: const Key('tasks_refresh'),
                    tooltip: l10n.desktopRefresh,
                    onPressed: () {
                      unawaited(notifier.refresh());
                      unawaited(ref.read(taskBoardsProvider.notifier).refresh());
                    },
                    icon: state.loading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(LucideIcons.refreshCw),
                  ),
                  const SizedBox(width: Space.xs),
                  FilledButton.icon(
                    key: const Key('tasks_new'),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: create,
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: Text(l10n.tasksNew),
                  ),
                ],
              );
              // With the boards rail beside it the toolbar no longer
              // fits next to the title on a narrow window; it then
              // takes a line of its own rather than squeezing the
              // board's name away.
              if (box.maxWidth < _toolbarBreakpoint) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    const SizedBox(height: Space.smd),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: toolbar,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [Expanded(child: title), toolbar],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
          child: Row(
            children: [
              Icon(LucideIcons.grip, size: 14, color: t.textTertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  !canWrite
                      ? l10n.taskBoardReadOnly
                      : (onPersonal && _assigned)
                      ? l10n.tasksReadOnly
                      : (board != null && board.description.isNotEmpty)
                      ? board.description
                      : (_mode == TasksBoardMode.byDue ? l10n.tasksBoardHintDue : l10n.tasksBoardHintStatus),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: t.textTertiary),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  Widget _board(
    BuildContext context,
    TasksState state,
    String selfId,
    String boardId,
    bool canWrite,
  ) {
    final now = _now;
    final onPersonal = boardId == personalBoardId;
    final columns = TasksBoard.columns(_mode);
    final visible = [
      for (final x in state.tasks)
        if (x.boardId == boardId &&
            // «Я поручил(а)» splits the personal list only; a board shows
            // everything on it, whoever is responsible.
            (!onPersonal || x.isOwnedBy(selfId) != _assigned) &&
            (_query.isEmpty || x.title.toLowerCase().contains(_query) || x.description.toLowerCase().contains(_query)))
          x,
    ];
    final byColumn = {for (final c in columns) c: <Task>[]};
    for (final x in visible) {
      byColumn[TasksBoard.columnOf(x, _mode, now)]?.add(x);
    }
    final names = (!onPersonal || _assigned) && ref.watch(tasksCanAssignProvider)
        ? {for (final u in ref.watch(taskAssigneesProvider).value ?? const <TaskAssignee>[]) u.id: u.label}
        : const <String, String>{};
    final editable = canWrite && !(onPersonal && _assigned);
    return LayoutBuilder(
      builder: (context, box) {
        final phone = !ref.watch(desktopLayoutProvider);
        const gap = Space.md;
        final pad = phone ? Space.md : Space.lg;
        // Phone: a column nearly as wide as the screen, the next one
        // peeking in; swipe from one to the next.
        final width = phone
            ? box.maxWidth - pad - 48
            : math.max(250.0, (box.maxWidth - pad * 2 - gap * (columns.length - 1)) / columns.length);
        // The glass tab bar floats over the bottom of the page.
        final bottom = Space.lg + MediaQuery.paddingOf(context).bottom;
        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.fromLTRB(pad, Space.xs, pad, bottom),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, c) in columns.indexed) ...[
                  if (i > 0) const SizedBox(width: gap),
                  SizedBox(
                    width: width,
                    height: box.maxHeight - Space.xs - bottom,
                    child: _Column(
                      key: ValueKey('tasks_column_${c.name}'),
                      column: c,
                      tasks: TasksBoard.sorted(byColumn[c]!, c),
                      doneLimit: c == TasksColumn.done ? _doneLimit : null,
                      onShowAll: () => setState(() => _allDone = !_allDone),
                      showingAll: _allDone,
                      editable: editable,
                      now: now,
                      width: width,
                      selfId: selfId,
                      names: names,
                      onDrop: (task) => unawaited(_drop(task, c)),
                      accepts: (task) =>
                          editable &&
                          task.editableBy(selfId) &&
                          (c == TasksColumn.later
                              ? TasksBoard.columnOf(task, _mode, now) != TasksColumn.later
                              : TasksBoard.patchFor(task, c, now) != null),
                      onQuickAdd: editable && TasksBoard.canQuickAdd(c) ? (title) => _quickAdd(c, title) : null,
                      onOpen: (task) => unawaited(showTaskSheet(context, task: task)),
                      onToggle: (task) async => _report(await ref.read(tasksProvider.notifier).setDone(task, !task.isDone)),
                      onMenu: (task, at) => unawaited(_menu(task, at, canWrite && task.editableBy(selfId))),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        // The title column can get narrow next to the toolbar: a figure is
        // cut short rather than pushed out of its row.
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: t.textSecondary, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

/// A two- or three-way toggle with icons (the web's `.segmented`).
class _Segmented<T> extends StatelessWidget {
  const _Segmented({required this.value, required this.items, required this.onChanged, required this.keyPrefix});

  final T value;
  final Map<T, (IconData, String)> items;
  final ValueChanged<T> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in items.entries)
            InkWell(
              key: Key('${keyPrefix}_${e.key is Enum ? (e.key as Enum).name : e.key}'),
              borderRadius: BorderRadius.circular(7),
              onTap: () => onChanged(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: e.key == value ? t.primarySoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  children: [
                    Icon(e.value.$1, size: 14, color: e.key == value ? t.primary : t.textTertiary),
                    const SizedBox(width: 6),
                    Text(
                      e.value.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: e.key == value ? FontWeight.w600 : FontWeight.w500,
                        color: e.key == value ? t.textPrimary : t.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One column: a header with its colour, count and «+», the cards, and a
/// drop zone that lights up while a card is dragged over it.
class _Column extends StatefulWidget {
  const _Column({
    super.key,
    required this.column,
    required this.tasks,
    required this.editable,
    required this.now,
    required this.width,
    required this.selfId,
    required this.names,
    required this.onDrop,
    required this.accepts,
    required this.onOpen,
    required this.onToggle,
    required this.onMenu,
    required this.onShowAll,
    required this.showingAll,
    this.doneLimit,
    this.onQuickAdd,
  });

  final TasksColumn column;
  final List<Task> tasks;
  final bool editable;
  final DateTime now;
  final double width;
  final String selfId;
  final Map<String, String> names;
  final ValueChanged<Task> onDrop;
  final bool Function(Task) accepts;
  final ValueChanged<Task> onOpen;
  final ValueChanged<Task> onToggle;
  final void Function(Task, Offset) onMenu;
  final VoidCallback onShowAll;
  final bool showingAll;
  final int? doneLimit;
  final Future<void> Function(String title)? onQuickAdd;

  @override
  State<_Column> createState() => _ColumnState();
}

class _ColumnState extends State<_Column> {
  bool _adding = false;
  final _field = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  (IconData, String, Color) _look(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return switch (widget.column) {
      TasksColumn.noDue => (LucideIcons.inbox, l10n.tasksNoDue, t.textTertiary),
      TasksColumn.today => (LucideIcons.sun, l10n.tasksDueToday, t.warning),
      TasksColumn.tomorrow => (LucideIcons.sunrise, l10n.tasksColumnTomorrow, t.info),
      TasksColumn.later => (LucideIcons.calendarRange, l10n.tasksColumnLater, t.labelPurpleText),
      TasksColumn.todo => (LucideIcons.circle, l10n.tasksColumnTodo, t.info),
      TasksColumn.inProgress => (LucideIcons.loader, l10n.tasksColumnInProgress, t.warning),
      TasksColumn.done => (LucideIcons.circleCheck, l10n.tasksColumnDone, t.success),
    };
  }

  Future<void> _submit() async {
    final title = _field.text.trim();
    if (title.isEmpty) {
      setState(() => _adding = false);
      return;
    }
    _field.clear();
    _focus.requestFocus();
    await widget.onQuickAdd?.call(title);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final (icon, title, accent) = _look(context);
    final limit = widget.doneLimit;
    final collapsible = limit != null && widget.tasks.length > limit;
    final shown = collapsible && !widget.showingAll ? widget.tasks.take(limit).toList() : widget.tasks;
    final radius = BorderRadius.circular(t.radiusLg);
    return DragTarget<Task>(
      onWillAcceptWithDetails: (d) => widget.editable && widget.accepts(d.data),
      onAcceptWithDetails: (d) => widget.onDrop(d.data),
      builder: (context, candidates, rejected) {
        final hovering = candidates.isNotEmpty;
        return GlassBlur(
          borderRadius: radius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            decoration: BoxDecoration(
              color: hovering ? Color.alphaBlend(accent.withValues(alpha: 0.10), t.surfaceMuted) : t.surfaceMuted,
              borderRadius: radius,
              border: Border.all(color: hovering ? accent : t.border, width: hovering ? 2 : t.borderWidth),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header: colour bar, icon, title, count, «+».
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusLg)),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.smd, 0, Space.xs, 0),
                    child: Row(
                      children: [
                        Icon(icon, size: 16, color: accent),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontFamily: t.fontDisplay, fontSize: 14, fontWeight: FontWeight.w700, color: t.textPrimary),
                                ),
                              ),
                              const SizedBox(width: Space.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                                decoration: BoxDecoration(color: accent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
                                child: Text(
                                  '${widget.tasks.length}',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.onQuickAdd != null)
                          IconButton(
                            key: Key('tasks_add_${widget.column.name}'),
                            tooltip: l10n.tasksQuickAdd,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(LucideIcons.plus, size: 18),
                            onPressed: () {
                              setState(() => _adding = true);
                              _focus.requestFocus();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(Space.sm, 0, Space.sm, Space.sm),
                    children: [
                      if (_adding)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.sm),
                          child: CallbackShortcuts(
                            bindings: {
                              const SingleActivator(LogicalKeyboardKey.escape): () => setState(() {
                                _adding = false;
                                _field.clear();
                              }),
                            },
                            child: TextField(
                              key: Key('tasks_quick_${widget.column.name}'),
                              controller: _field,
                              focusNode: _focus,
                              autofocus: true,
                              onSubmitted: (_) => unawaited(_submit()),
                              decoration: InputDecoration(
                                hintText: l10n.tasksQuickAddHint,
                                filled: true,
                                fillColor: t.surface,
                                contentPadding: const EdgeInsets.symmetric(horizontal: Space.smd, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(t.radiusMd), borderSide: BorderSide(color: accent)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(t.radiusMd),
                                  borderSide: BorderSide(color: accent.withValues(alpha: 0.6)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(t.radiusMd),
                                  borderSide: BorderSide(color: accent, width: 2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      for (final task in shown)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.sm),
                          child: _DraggableCard(
                            task: task,
                            width: widget.width - Space.sm * 2,
                            draggable: widget.editable && task.editableBy(widget.selfId),
                            now: widget.now,
                            selfId: widget.selfId,
                            ownerName: widget.names[task.ownerUserId],
                            showProgress: widget.column != TasksColumn.inProgress,
                            onOpen: () => widget.onOpen(task),
                            onToggle: () => widget.onToggle(task),
                            onMenu: (at) => widget.onMenu(task, at),
                          ),
                        ),
                      if (collapsible)
                        TextButton(
                          key: const Key('tasks_done_all'),
                          onPressed: widget.onShowAll,
                          child: Text(widget.showingAll ? l10n.tasksShowLess : l10n.tasksShowAll(widget.tasks.length)),
                        ),
                      if (widget.tasks.isEmpty && !_adding)
                        _EmptyDrop(
                          text: widget.editable ? l10n.tasksDropHere : l10n.tasksEmpty,
                          highlight: hovering,
                          accent: accent,
                        ),
                      if (widget.onQuickAdd != null && !_adding)
                        TextButton.icon(
                          key: Key('tasks_add_bottom_${widget.column.name}'),
                          style: TextButton.styleFrom(alignment: Alignment.centerLeft, foregroundColor: t.textTertiary),
                          onPressed: () {
                            setState(() => _adding = true);
                            _focus.requestFocus();
                          },
                          icon: Icon(LucideIcons.plus, size: 15, color: t.textTertiary),
                          label: Text(l10n.tasksQuickAdd, style: TextStyle(color: t.textTertiary)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyDrop extends StatelessWidget {
  const _EmptyDrop({required this.text, required this.highlight, required this.accent});

  final String text;
  final bool highlight;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      height: 88,
      margin: const EdgeInsets.only(bottom: Space.sm),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: Border.all(color: highlight ? accent : t.border, width: 1.5),
        color: highlight ? accent.withValues(alpha: 0.08) : Colors.transparent,
      ),
      child: Text(text, style: TextStyle(fontSize: 12.5, color: highlight ? accent : t.textTertiary)),
    );
  }
}

/// A card that can be picked up with the mouse (own tasks only).
class _DraggableCard extends StatelessWidget {
  const _DraggableCard({
    required this.task,
    required this.width,
    required this.draggable,
    required this.now,
    required this.selfId,
    required this.onOpen,
    required this.onToggle,
    required this.onMenu,
    this.ownerName,
    this.showProgress = true,
  });

  final Task task;
  final double width;
  final bool draggable;
  final bool showProgress;
  final DateTime now;
  final String selfId;
  final String? ownerName;
  final VoidCallback onOpen;
  final VoidCallback onToggle;
  final ValueChanged<Offset> onMenu;

  @override
  Widget build(BuildContext context) {
    final card = _TaskCard(
      task: task,
      now: now,
      selfId: selfId,
      ownerName: ownerName,
      showProgress: showProgress,
      onOpen: onOpen,
      onToggle: draggable ? onToggle : null,
      onMenu: onMenu,
    );
    if (!draggable) return card;
    // Touch: a long press lifts the card, so a swipe still scrolls the
    // columns (the mouse drags at once).
    if (!isDesktop) {
      return LongPressDraggable<Task>(
        key: ValueKey('task_card_${task.id}'),
        data: task,
        hapticFeedbackOnStart: true,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Transform.translate(
          offset: Offset(-width / 2, -24),
          child: Transform.rotate(
            angle: -0.03,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(width: width, child: _TaskCard(task: task, now: now, selfId: selfId, lifted: true)),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: card),
        child: card,
      );
    }
    return Draggable<Task>(
      key: ValueKey('task_card_${task.id}'),
      data: task,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Transform.translate(
        offset: Offset(-width / 2, -24),
        child: Transform.rotate(
          angle: -0.03,
          child: Material(
            color: Colors.transparent,
            child: SizedBox(width: width, child: _TaskCard(task: task, now: now, selfId: selfId, lifted: true)),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: MouseRegion(cursor: SystemMouseCursors.grab, child: card),
    );
  }
}

class _TaskCard extends StatefulWidget {
  const _TaskCard({
    required this.task,
    required this.now,
    required this.selfId,
    this.ownerName,
    this.onOpen,
    this.onToggle,
    this.onMenu,
    this.lifted = false,
    this.showProgress = true,
  });

  final Task task;
  final DateTime now;
  final String selfId;
  final String? ownerName;

  /// The «В работе» chip (not in the «В работе» column itself).
  final bool showProgress;
  final VoidCallback? onOpen;
  final VoidCallback? onToggle;
  final ValueChanged<Offset>? onMenu;
  final bool lifted;

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final task = widget.task;
    final locale = Localizations.localeOf(context).toString();
    final overdue = task.isOverdue(widget.now);
    final today = !overdue && task.isDueToday(widget.now);
    final priorityColor = switch (task.priority) {
      TaskPriority.urgent => t.danger,
      TaskPriority.high => t.warning,
      TaskPriority.low => t.textTertiary,
      _ => null,
    };
    final radius = BorderRadius.circular(t.radiusMd);
    final done = task.isDone;

    final meta = <Widget>[
      if (task.dueAt != null)
        _Chip(
          icon: overdue ? LucideIcons.flame : LucideIcons.clock,
          text: overdue
              ? '${l10n.tasksOverdue} · ${TasksFormat.when(task.dueAt!, locale, now: widget.now)}'
              : today
              ? '${l10n.tasksDueToday}, ${TasksFormat.time(task.dueAt!, locale)}'
              : TasksFormat.when(task.dueAt!, locale, now: widget.now),
          color: done ? t.textTertiary : (overdue ? t.danger : (today ? t.warning : t.textSecondary)),
          background: done ? null : (overdue ? t.dangerSoft : (today ? t.warningSoft : null)),
        ),
      if (priorityColor != null && task.priority != TaskPriority.low && !done)
        _Chip(icon: LucideIcons.flag, text: TasksFormat.priority(l10n, task.priority), color: priorityColor, background: priorityColor.withValues(alpha: 0.14)),
      if (task.status == TaskStatus.inProgress && !done && widget.showProgress)
        _Chip(icon: LucideIcons.loader, text: l10n.tasksColumnInProgress, color: t.info, background: t.infoSoft),
      if (task.mailMessageId != null) _Chip(icon: LucideIcons.mail, text: l10n.tasksFromMail, color: t.textTertiary),
      if (task.reminderAt != null && !done) Icon(LucideIcons.alarmClock, size: 13, color: t.textTertiary),
    ];
    final owner = task.isOwnedBy(widget.selfId);
    final by = owner && task.assignedByName.isNotEmpty && task.assignedByUserId.isNotEmpty && task.assignedByUserId != widget.selfId
        ? l10n.tasksAssignedBy(task.assignedByName)
        : (!owner ? (widget.ownerName != null ? l10n.tasksAssignedTo(widget.ownerName!) : l10n.tasksAssignedToColleague) : null);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onSecondaryTapUp: widget.onMenu == null ? null : (d) => widget.onMenu!(d.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: widget.lifted ? t.overlaySurface : t.surface,
            borderRadius: radius,
            border: Border.all(color: _hover || widget.lifted ? t.borderStrong : t.border),
            boxShadow: widget.lifted
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 24, offset: const Offset(0, 10))]
                : (_hover ? t.shadowSm : const []),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onOpen,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (priorityColor != null && task.priority != TaskPriority.low && !done) Container(width: 3, color: priorityColor),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(Space.sm, Space.smd, Space.xs, Space.smd),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _CheckCircle(
                                  key: Key('task_check_${task.id}'),
                                  done: done,
                                  onTap: widget.onToggle,
                                  tooltip: done ? l10n.tasksMarkUndone : l10n.tasksMarkDone,
                                ),
                                const SizedBox(width: Space.sm),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 1),
                                    child: Text(
                                      task.title,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.35,
                                        fontWeight: FontWeight.w600,
                                        color: done ? t.textTertiary : t.textPrimary,
                                        decoration: done ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ),
                                ),
                                if (widget.onMenu != null)
                                  Opacity(
                                    // Touch has no hover: the ⋯ is always there.
                                    opacity: _hover || !isDesktop ? 1 : 0,
                                    child: Builder(
                                      builder: (button) => InkWell(
                                        key: Key('task_more_${task.id}'),
                                        borderRadius: BorderRadius.circular(6),
                                        onTap: () {
                                          final box = button.findRenderObject()! as RenderBox;
                                          widget.onMenu!(box.localToGlobal(box.size.bottomLeft(Offset.zero)));
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(LucideIcons.ellipsis, size: 16, color: t.textTertiary),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (task.description.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.only(left: 28),
                                child: Text(
                                  task.description.trim(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12.5, height: 1.35, color: t.textTertiary),
                                ),
                              ),
                            ],
                            if (meta.isNotEmpty) ...[
                              const SizedBox(height: Space.sm),
                              Padding(
                                padding: const EdgeInsets.only(left: 28),
                                child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: meta),
                              ),
                            ],
                            if (by != null) ...[
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.only(left: 28),
                                child: Text(by, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: t.textTertiary)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The round tick of a card.
class _CheckCircle extends StatelessWidget {
  const _CheckCircle({super.key, required this.done, required this.onTap, required this.tooltip});

  final bool done;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final circle = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? t.success : Colors.transparent,
        border: Border.all(color: done ? t.success : t.borderStrong, width: 1.6),
      ),
      child: done ? Icon(LucideIcons.check, size: 13, color: t.textInverse) : null,
    );
    if (onTap == null) return circle;
    return Tooltip(
      message: tooltip,
      child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: circle),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, required this.color, this.background});

  final IconData icon;
  final String text;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background ?? context.tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
