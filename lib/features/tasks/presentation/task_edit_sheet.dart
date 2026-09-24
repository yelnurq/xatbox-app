import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/localization/localization.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/state_view.dart';
import '../data/task_models.dart';
import 'tasks_format.dart';
import 'tasks_providers.dart';
import '../../../shared/widgets/app_sheet.dart';

/// Opens the create / edit sheet. [task] `null` creates; a task the caller
/// does not own is shown read-only. Resolves to `true` when something was
/// saved.
/// [boardId] is the board a newly created task lands on ('' = the personal
/// list); it is ignored when an existing [task] is opened.
Future<bool> showTaskSheet(
  BuildContext context, {
  Task? task,
  String boardId = '',
}) async {
  final saved = await showAppSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => TaskEditSheet(task: task, boardId: boardId),
  );
  return saved ?? false;
}

class TaskEditSheet extends ConsumerStatefulWidget {
  const TaskEditSheet({super.key, this.task, this.boardId = ''});
  final Task? task;

  /// The board a new task is created on ('' = the personal list).
  final String boardId;

  @override
  ConsumerState<TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends ConsumerState<TaskEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  DateTime? _due;
  DateTime? _reminder;
  late String _priority;
  TaskAssignee? _assignee;
  bool _saving = false;
  String? _titleError;

  Task? get _task => widget.task;
  bool get _creating => _task == null;

  @override
  void initState() {
    super.initState();
    final t = _task;
    _title = TextEditingController(text: t?.title ?? '');
    _description = TextEditingController(text: t?.description ?? '');
    _due = t?.dueAt?.toLocal();
    _reminder = t?.reminderAt?.toLocal();
    _priority = t?.priority ?? TaskPriority.normal;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime? current) async {
    final now = DateTime.now();
    final initial = current ?? DateTime(now.year, now.month, now.day, 18);
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: initial,
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickAssignee() async {
    final picked = await showAppSheet<_AssigneeChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _AssigneePickerSheet(),
    );
    if (picked != null && mounted) {
      setState(() => _assignee = picked.user);
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = l10n.tasksTitleRequired);
      return;
    }
    setState(() {
      _saving = true;
      _titleError = null;
    });
    final notifier = ref.read(tasksProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final t = _task;
      if (t == null) {
        await notifier.create(
          TaskDraft(
            title: title,
            description: _description.text,
            ownerUserId: _assignee?.id,
            dueAt: _due,
            reminderAt: _reminder,
            priority: _priority,
            boardId: widget.boardId,
          ),
        );
        messenger.showSnackBar(SnackBar(content: Text(l10n.tasksCreated)));
      } else {
        final description = _description.text.trim();
        final dueChanged = _due?.toUtc() != t.dueAt?.toUtc();
        await notifier.update(
          t.id,
          TaskPatch(
            title: title != t.title ? title : null,
            description: description != t.description ? description : null,
            dueAt: dueChanged ? _due : null,
            clearDue: dueChanged && _due == null,
            priority: _priority != t.priority ? _priority : null,
          ),
        );
        messenger.showSnackBar(SnackBar(content: Text(l10n.tasksSaved)));
      }
      if (mounted) Navigator.pop(context, true);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            TasksFormat.error(l10n, e, assigning: _assignee != null),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final locale = Localizations.localeOf(context).toString();
    final selfId = ref.watch(currentUserProvider)?.id ?? '';
    final t = _task;
    final readOnly = t != null && !t.editableBy(selfId);
    final canAssign = _creating && ref.watch(tasksCanAssignProvider);
    final messageId = t?.mailMessageId;

    String whenText(DateTime? at, String empty) =>
        at == null ? empty : TasksFormat.when(at, locale);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _creating
                  ? l10n.tasksNew
                  : readOnly
                  ? l10n.tasksDetails
                  : l10n.tasksEdit,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (readOnly) ...[
              const SizedBox(height: Space.xs),
              Text(
                l10n.tasksReadOnly,
                style: TextStyle(color: tokens.textMuted),
              ),
            ],
            const SizedBox(height: Space.md),
            TextField(
              key: const Key('task_title'),
              controller: _title,
              readOnly: readOnly,
              autofocus: _creating,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.tasksFieldTitle,
                errorText: _titleError,
              ),
            ),
            const SizedBox(height: Space.sm),
            TextField(
              key: const Key('task_description'),
              controller: _description,
              readOnly: readOnly,
              minLines: 2,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.tasksFieldDescription,
              ),
            ),
            const SizedBox(height: Space.sm),
            ListTile(
              key: const Key('task_due'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.calendarClock),
              title: Text(l10n.tasksFieldDue),
              subtitle: Text(whenText(_due, l10n.tasksNoDue)),
              trailing: _due != null && !readOnly
                  ? IconButton(
                      tooltip: l10n.tasksClear,
                      icon: const Icon(LucideIcons.x),
                      onPressed: () => setState(() => _due = null),
                    )
                  : null,
              onTap: readOnly
                  ? null
                  : () async {
                      final at = await _pick(_due);
                      if (at != null && mounted) setState(() => _due = at);
                    },
            ),
            ListTile(
              key: const Key('task_reminder'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.alarmClock),
              title: Text(l10n.tasksFieldReminder),
              subtitle: Text(
                _creating
                    ? whenText(_reminder, l10n.tasksNoReminder)
                    : '${whenText(_reminder, l10n.tasksNoReminder)}\n'
                          '${l10n.tasksReminderFixed}',
              ),
              trailing: _creating && _reminder != null
                  ? IconButton(
                      tooltip: l10n.tasksClear,
                      icon: const Icon(LucideIcons.x),
                      onPressed: () => setState(() => _reminder = null),
                    )
                  : null,
              onTap: _creating
                  ? () async {
                      final at = await _pick(_reminder ?? _due);
                      if (at != null && mounted) {
                        setState(() => _reminder = at);
                      }
                    }
                  : null,
            ),
            if (canAssign)
              ListTile(
                key: const Key('task_assignee'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.userCheck),
                title: Text(l10n.tasksFieldAssignee),
                subtitle: Text(_assignee?.label ?? l10n.tasksAssigneeSelf),
                onTap: _pickAssignee,
              ),
            const SizedBox(height: Space.sm),
            Text(
              l10n.tasksFieldPriority,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: Space.xs),
            Wrap(
              spacing: Space.sm,
              children: [
                for (final p in TaskPriority.all)
                  ChoiceChip(
                    key: Key('task_priority_$p'),
                    label: Text(TasksFormat.priority(l10n, p)),
                    selected: _priority == p,
                    onSelected: readOnly
                        ? null
                        : (_) => setState(() => _priority = p),
                  ),
              ],
            ),
            if (messageId != null) ...[
              const SizedBox(height: Space.sm),
              OutlinedButton.icon(
                key: const Key('task_open_message'),
                icon: const Icon(LucideIcons.mail),
                label: Text(l10n.tasksOpenMessage),
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.pop(context, false);
                  router.push(Routes.mailMessagePath(messageId));
                },
              ),
            ],
            const SizedBox(height: Space.md),
            if (!readOnly)
              FilledButton(
                key: const Key('task_save'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_creating ? l10n.tasksCreate : l10n.save),
              )
            else
              OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.close),
              ),
          ],
        ),
      ),
    );
  }
}

/// `user == null` means «Я».
class _AssigneeChoice {
  const _AssigneeChoice(this.user);
  final TaskAssignee? user;
}

class _AssigneePickerSheet extends ConsumerStatefulWidget {
  const _AssigneePickerSheet();

  @override
  ConsumerState<_AssigneePickerSheet> createState() =>
      _AssigneePickerSheetState();
}

class _AssigneePickerSheetState extends ConsumerState<_AssigneePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final users = ref.watch(taskAssigneesProvider);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.tasksAssigneePick,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: Space.sm),
                TextField(
                  key: const Key('task_assignee_search'),
                  decoration: InputDecoration(
                    hintText: l10n.tasksAssigneeSearch,
                    prefixIcon: const Icon(LucideIcons.search),
                  ),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
              ],
            ),
          ),
          ListTile(
            key: const Key('task_assignee_self'),
            leading: const Icon(LucideIcons.user),
            title: Text(l10n.tasksAssigneeSelf),
            onTap: () => Navigator.pop(context, const _AssigneeChoice(null)),
          ),
          const Divider(height: 1),
          Expanded(
            child: users.when(
              loading: () => const StateView.loading(),
              error: (e, _) => StateView.error(
                message: TasksFormat.error(l10n, e),
                onRetry: () => ref.invalidate(taskAssigneesProvider),
              ),
              data: (all) {
                final visible = _query.isEmpty
                    ? all
                    : all
                          .where(
                            (u) =>
                                u.label.toLowerCase().contains(_query) ||
                                u.email.toLowerCase().contains(_query),
                          )
                          .toList();
                if (visible.isEmpty) {
                  return StateView.empty(
                    title: l10n.tasksAssigneeEmpty,
                    icon: LucideIcons.userSearch,
                  );
                }
                return ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (_, i) {
                    final u = visible[i];
                    return ListTile(
                      key: ValueKey('task_assignee_${u.id}'),
                      leading: InitialsAvatar(label: u.label, colorKey: u.id),
                      title: Text(u.label),
                      subtitle: Text(
                        [
                          u.email,
                          u.departmentName,
                        ].where((s) => s.isNotEmpty).join(' · '),
                        style: TextStyle(color: tokens.textMuted),
                      ),
                      onTap: () => Navigator.pop(context, _AssigneeChoice(u)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
