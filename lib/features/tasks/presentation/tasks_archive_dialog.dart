import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/state_view.dart';
import '../data/task_models.dart';
import 'tasks_format.dart';
import 'tasks_providers.dart';

/// «Архив»: the tasks sent away from the boards once they were done. They
/// are read on demand (`GET /tasks?archived=1`) — the archive is not part of
/// the live list — and every task can be brought back to the board it came
/// from. [boardId] opens the dialog on that board's tasks ('' = personal
/// list); the other boards' tasks stay a switch away.
Future<void> showTasksArchive(BuildContext context, {required String boardId}) => showDialog<void>(
  context: context,
  builder: (_) => _ArchiveDialog(boardId: boardId),
);

class _ArchiveDialog extends ConsumerStatefulWidget {
  const _ArchiveDialog({required this.boardId});
  final String boardId;

  @override
  ConsumerState<_ArchiveDialog> createState() => _ArchiveDialogState();
}

class _ArchiveDialogState extends ConsumerState<_ArchiveDialog> {
  List<Task>? _tasks;
  AppException? _error;
  bool _all = false;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _tasks = null;
      _error = null;
    });
    try {
      final tasks = await ref.read(tasksProvider.notifier).archived();
      if (mounted) setState(() => _tasks = tasks);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _restore(Task task) async {
    setState(() => _busy.add(task.id));
    final error = await ref.read(tasksProvider.notifier).setArchived(task.copyWith(archived: true), false);
    if (!mounted) return;
    setState(() {
      _busy.remove(task.id);
      if (error == null) _tasks = [for (final t in _tasks ?? const <Task>[]) if (t.id != task.id) t];
    });
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error == null ? l10n.tasksRestored : TasksFormat.error(l10n, error))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final boards = ref.watch(taskBoardsProvider).boards;
    String boardName(String id) => id.isEmpty
        ? l10n.tasksTitle
        : boards.where((b) => b.id == id).map((b) => b.name).firstOrNull ?? l10n.tasksTitle;
    final shown = [
      for (final x in _tasks ?? const <Task>[])
        if (_all || x.boardId == widget.boardId) x,
    ];
    final hasOthers = (_tasks ?? const <Task>[]).any((x) => x.boardId != widget.boardId);

    Widget body;
    if (_error != null) {
      body = StateView.error(message: TasksFormat.error(l10n, _error!), onRetry: _load);
    } else if (_tasks == null) {
      body = const StateView.loading();
    } else if (shown.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.archive, size: 36, color: t.textTertiary),
              const SizedBox(height: Space.md),
              Text(l10n.tasksArchiveEmpty, style: TextStyle(color: t.textSecondary)),
            ],
          ),
        ),
      );
    } else {
      body = ListView.separated(
        key: const Key('tasks_archive_list'),
        itemCount: shown.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: t.border),
        itemBuilder: (context, i) {
          final task = shown[i];
          final busy = _busy.contains(task.id);
          return ListTile(
            key: Key('tasks_archive_${task.id}'),
            leading: Icon(LucideIcons.circleCheck, size: 18, color: t.success),
            title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [
                boardName(task.boardId),
                if (task.dueAt != null) TasksFormat.when(task.dueAt!, Localizations.localeOf(context).languageCode),
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: t.textTertiary),
            ),
            trailing: TextButton.icon(
              key: Key('tasks_archive_restore_${task.id}'),
              onPressed: busy ? null : () => unawaited(_restore(task)),
              icon: busy
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.archiveRestore, size: 16),
              label: Text(l10n.tasksRestore),
            ),
          );
        },
      );
    }

    return AlertDialog(
      key: const Key('tasks_archive_dialog'),
      title: Row(
        children: [
          const Icon(LucideIcons.archive, size: 20),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(l10n.tasksArchiveTitle)),
          if (hasOthers)
            TextButton(
              key: const Key('tasks_archive_toggle_all'),
              onPressed: () => setState(() => _all = !_all),
              child: Text(_all ? l10n.tasksArchiveThisBoard : l10n.tasksArchiveAllBoards),
            ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(0, Space.sm, 0, 0),
      content: SizedBox(width: 560, height: 420, child: body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close)),
      ],
    );
  }
}
