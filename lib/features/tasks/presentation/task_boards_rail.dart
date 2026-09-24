import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import '../data/task_models.dart';
import 'task_board_share_dialog.dart';
import 'tasks_format.dart';
import 'tasks_providers.dart';

/// The accents a board can be painted with. The value stored on the server
/// is the key; an unknown one falls back to the theme's primary.
abstract final class TaskBoardColors {
  static const keys = ['', 'blue', 'purple', 'green', 'yellow', 'orange', 'red'];

  static Color of(XatBoxTokens t, String key) => switch (key) {
    'blue' => t.labelBlueText,
    'purple' => t.labelPurpleText,
    'green' => t.labelGreenText,
    'yellow' => t.labelYellowText,
    'orange' => t.warning,
    'red' => t.danger,
    _ => t.primary,
  };
}

/// Desktop «Задачи»: the boards on the left. «Мои задачи» (every task
/// without a board) is always first, then the boards the user owns, then the
/// ones colleagues shared with them. A card dragged onto a row moves the
/// task to that board.
class TaskBoardsRail extends ConsumerWidget {
  const TaskBoardsRail({super.key, required this.selfId, required this.onMove, this.expand = false});

  final String selfId;

  /// Phone: the rail fills the board picker sheet instead of its column.
  final bool expand;

  /// Moves [task] onto the board (empty id = the personal list).
  final void Function(Task task, String boardId) onMove;

  static const width = 240.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final state = ref.watch(taskBoardsProvider);
    final selected = ref.watch(selectedTaskBoardProvider);
    final tasks = ref.watch(tasksProvider.select((s) => s.tasks));
    final personalOpen = tasks
        .where((x) => x.isPersonal && !x.isDone)
        .length;
    final own = [for (final b in state.boards) if (b.isOwner) b];
    final shared = [for (final b in state.boards) if (!b.isOwner) b];

    return Container(
      width: expand ? null : width,
      decoration: BoxDecoration(
        color: t.surfaceSubtle,
        border: Border(right: BorderSide(color: t.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.sm, Space.sm),
            child: Row(
              children: [
                Text(
                  l10n.taskBoardsTitle,
                  style: TextStyle(
                    fontFamily: t.fontDisplay,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: t.textSecondary,
                  ),
                ),
                const Spacer(),
                if (state.loading)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: Space.sm),
              children: [
                _BoardRow(
                  key: const Key('task_board_personal'),
                  icon: LucideIcons.user,
                  label: l10n.taskBoardPersonal,
                  count: personalOpen,
                  accent: t.primary,
                  selected: selected == personalBoardId,
                  onTap: () => ref
                      .read(selectedTaskBoardProvider.notifier)
                      .select(personalBoardId),
                  onAccept: (task) => onMove(task, personalBoardId),
                  accepts: (task) => !task.isPersonal && task.editableBy(selfId),
                ),
                for (final b in own)
                  _BoardRow(
                    key: Key('task_board_${b.id}'),
                    icon: b.members.isEmpty ? LucideIcons.layoutGrid : LucideIcons.users,
                    label: b.name,
                    count: b.openCount,
                    accent: TaskBoardColors.of(t, b.color),
                    selected: selected == b.id,
                    subtitle: b.members.isEmpty
                        ? null
                        : l10n.taskBoardShareMembers(b.members.length),
                    onTap: () =>
                        ref.read(selectedTaskBoardProvider.notifier).select(b.id),
                    onMenu: (at) => unawaited(_menu(context, ref, b, at)),
                    onAccept: (task) => onMove(task, b.id),
                    accepts: (task) => b.canWrite && task.editableBy(selfId),
                  ),
                if (shared.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.md, Space.smd, Space.md, Space.xs),
                    child: Text(
                      l10n.taskBoardShare,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: t.textTertiary),
                    ),
                  ),
                  for (final b in shared)
                    _BoardRow(
                      key: Key('task_board_${b.id}'),
                      icon: b.canWrite ? LucideIcons.users : LucideIcons.eye,
                      label: b.name,
                      count: b.openCount,
                      accent: TaskBoardColors.of(t, b.color),
                      selected: selected == b.id,
                      subtitle: b.ownerName.isEmpty
                          ? null
                          : l10n.taskBoardOwnedBy(b.ownerName),
                      onTap: () =>
                          ref.read(selectedTaskBoardProvider.notifier).select(b.id),
                      onAccept: (task) => onMove(task, b.id),
                      accepts: (task) => b.canWrite && task.editableBy(selfId),
                    ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: t.divider),
          Padding(
            padding: const EdgeInsets.all(Space.sm),
            child: TextButton.icon(
              key: const Key('task_board_new'),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                minimumSize: const Size.fromHeight(38),
                foregroundColor: t.textSecondary,
              ),
              onPressed: () => unawaited(_create(context, ref)),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: Text(l10n.taskBoardNew),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final draft = await showTaskBoardDialog(context);
    if (draft == null || !context.mounted) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = await ref.read(taskBoardsProvider.notifier).create(draft);
      ref.read(selectedTaskBoardProvider.notifier).select(id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.taskBoardCreated)));
    } on AppException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(TasksFormat.error(l10n, e))),
      );
    }
  }

  Future<void> _menu(
    BuildContext context,
    WidgetRef ref,
    TaskBoard board,
    Offset at,
  ) async {
    final l10n = context.l10n;
    final t = context.tokens;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    PopupMenuItem<String> item(String value, IconData icon, String label, {Color? color}) =>
        PopupMenuItem(
          key: Key('task_board_menu_$value'),
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
        item('rename', LucideIcons.pencil, l10n.taskBoardRename),
        item('share', LucideIcons.userPlus, l10n.taskBoardShare),
        item('delete', LucideIcons.trash2, l10n.taskBoardDelete, color: t.danger),
      ],
    );
    if (!context.mounted) return;
    switch (picked) {
      case 'rename':
        await _rename(context, ref, board);
      case 'share':
        await showTaskBoardShareDialog(context, board);
      case 'delete':
        await _delete(context, ref, board);
    }
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    TaskBoard board,
  ) async {
    final draft = await showTaskBoardDialog(context, board: board);
    if (draft == null || !context.mounted) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(taskBoardsProvider.notifier).update(
            board.id,
            TaskBoardPatch(
              name: draft.name,
              description: draft.description,
              color: draft.color,
            ),
          );
      messenger.showSnackBar(SnackBar(content: Text(l10n.taskBoardSaved)));
    } on AppException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(TasksFormat.error(l10n, e))),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TaskBoard board,
  ) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.taskBoardDelete),
        content: Text(l10n.taskBoardDeleteConfirm(board.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            key: const Key('task_board_delete_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref.read(taskBoardsProvider.notifier).delete(board.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error == null ? l10n.taskBoardDeleted : TasksFormat.error(l10n, error),
        ),
      ),
    );
  }
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.accent,
    required this.selected,
    required this.onTap,
    required this.onAccept,
    required this.accepts,
    this.subtitle,
    this.onMenu,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color accent;
  final bool selected;
  final String? subtitle;
  final VoidCallback onTap;
  final void Function(Offset at)? onMenu;
  final ValueChanged<Task> onAccept;
  final bool Function(Task) accepts;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DragTarget<Task>(
      onWillAcceptWithDetails: (d) => !selected && accepts(d.data),
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (context, candidate, _) {
        final hovering = candidate.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 1),
          child: Material(
            color: selected
                ? t.surfaceSelected
                : (hovering ? t.surfaceHover : Colors.transparent),
            borderRadius: BorderRadius.circular(t.radiusMd),
            child: InkWell(
              borderRadius: BorderRadius.circular(t.radiusMd),
              onTap: onTap,
              onSecondaryTapUp: onMenu == null
                  ? null
                  : (d) => onMenu!(d.globalPosition),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.sm),
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: accent),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: t.textPrimary,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: t.textTertiary),
                            ),
                        ],
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: Space.xs),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: t.textTertiary,
                        ),
                      ),
                    ],
                    if (onMenu != null)
                      IconButton(
                        key: Key('task_board_menu_button_$label'),
                        tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                        visualDensity: VisualDensity.compact,
                        iconSize: 15,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        icon: Icon(LucideIcons.ellipsis, color: t.textTertiary),
                        onPressed: () {
                          final box = context.findRenderObject() as RenderBox?;
                          onMenu!(
                            box == null
                                ? Offset.zero
                                : box.localToGlobal(box.size.centerRight(Offset.zero)),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Create («Новая доска») or rename a board. Returns the draft the user
/// confirmed, or null when they cancelled.
Future<TaskBoardDraft?> showTaskBoardDialog(
  BuildContext context, {
  TaskBoard? board,
}) => showDialog<TaskBoardDraft>(
  context: context,
  builder: (_) => _BoardDialog(board: board),
);

class _BoardDialog extends StatefulWidget {
  const _BoardDialog({this.board});
  final TaskBoard? board;

  @override
  State<_BoardDialog> createState() => _BoardDialogState();
}

class _BoardDialogState extends State<_BoardDialog> {
  late final _name = TextEditingController(text: widget.board?.name ?? '');
  late final _description =
      TextEditingController(text: widget.board?.description ?? '');
  late String _color = widget.board?.color ?? '';
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = context.l10n.taskBoardNameRequired);
      return;
    }
    Navigator.pop(
      context,
      TaskBoardDraft(
        name: name,
        description: _description.text.trim(),
        color: _color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return AlertDialog(
      title: Text(widget.board == null ? l10n.taskBoardCreate : l10n.taskBoardRename),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('task_board_name'),
              controller: _name,
              autofocus: true,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.taskBoardName,
                hintText: l10n.taskBoardNameHint,
                errorText: _error,
              ),
            ),
            const SizedBox(height: Space.smd),
            TextField(
              key: const Key('task_board_description'),
              controller: _description,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(labelText: l10n.taskBoardDescription),
            ),
            const SizedBox(height: Space.md),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.taskBoardColor,
                style: TextStyle(fontSize: 12, color: t.textTertiary),
              ),
            ),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              children: [
                for (final key in TaskBoardColors.keys)
                  _ColorDot(
                    key: Key('task_board_color_${key.isEmpty ? 'default' : key}'),
                    color: TaskBoardColors.of(t, key),
                    selected: _color == key,
                    onTap: () => setState(() => _color = key),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          key: const Key('task_board_submit'),
          onPressed: _submit,
          child: Text(widget.board == null ? l10n.tasksCreate : l10n.save),
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({super.key, required this.color, required this.selected, required this.onTap});

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.18),
          border: Border.all(color: selected ? color : t.border, width: selected ? 2 : 1),
        ),
        child: Center(
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ),
      ),
    );
  }
}
