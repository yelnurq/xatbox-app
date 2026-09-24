import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../data/task_models.dart';
import 'tasks_format.dart';
import 'tasks_providers.dart';

/// «Поделиться»: who may see the board and who may work on it. The list the
/// dialog saves replaces the board's current one, so removing a colleague is
/// leaving them out.
Future<void> showTaskBoardShareDialog(BuildContext context, TaskBoard board) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ShareDialog(board: board),
    );

class _ShareDialog extends ConsumerStatefulWidget {
  const _ShareDialog({required this.board});
  final TaskBoard board;

  @override
  ConsumerState<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends ConsumerState<_ShareDialog> {
  static const _debounce = Duration(milliseconds: 350);
  static const _pageSize = 50;

  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _timer;
  String _query = '';

  /// The list being edited, keyed by user id so a colleague appears once.
  late final Map<String, TaskBoardMember> _members = {
    for (final m in widget.board.members) m.userId: m,
  };

  final List<TaskAssignee> _found = [];
  bool _loading = false;
  bool _hasMore = true;
  bool _saving = false;
  Object? _error;

  /// Guards against an answer of an older query landing last.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loading || !_hasMore) return;
    final p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent - 200) unawaited(_load());
  }

  void _onQuery(String value) {
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      if (!mounted) return;
      setState(() => _query = value.trim());
      unawaited(_load(reset: true));
    });
  }

  /// One page of the directory; [reset] starts again from the top (a new
  /// search term).
  Future<void> _load({bool reset = false}) async {
    final gen = reset ? ++_generation : _generation;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _found.clear();
        _hasMore = true;
      }
    });
    try {
      final page = await ref.read(tasksApiProvider).directory(
            _query,
            limit: _pageSize,
            offset: reset ? 0 : _found.length,
          );
      if (!mounted || gen != _generation) return;
      final selfId = ref.read(currentUserProvider)?.id ?? '';
      final seen = {for (final u in _found) u.id};
      final added = [
        for (final u in page.users)
          if (u.id != selfId && seen.add(u.id)) u,
      ];
      setState(() {
        _found.addAll(added);
        _loading = false;
        // A service that ignores `offset` repeats the first page: stop
        // rather than page for ever over the same colleagues.
        _hasMore = page.hasMore && (reset || added.isNotEmpty);
      });
    } on AppException catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _loading = false;
        _hasMore = false;
        _error = e;
      });
    }
  }

  void _toggle(TaskAssignee user) => setState(() {
    if (_members.remove(user.id) == null) {
      _members[user.id] = TaskBoardMember(
        userId: user.id,
        displayName: user.name,
        email: user.email,
      );
    }
  });

  void _setRole(String userId, String role) => setState(() {
    final current = _members[userId];
    if (current != null) _members[userId] = current.withRole(role);
  });

  Future<void> _save() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(taskBoardsProvider.notifier)
          .share(widget.board.id, _members.values.toList());
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.taskBoardShared)));
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final chosen = _members.values.toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

    return AlertDialog(
      title: Text(l10n.taskBoardShareTitle(widget.board.name)),
      content: SizedBox(
        width: 460,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.taskBoardShareHint,
              style: TextStyle(fontSize: 12, color: t.textTertiary),
            ),
            const SizedBox(height: Space.smd),
            if (chosen.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                child: Text(
                  l10n.taskBoardShareEmpty,
                  style: TextStyle(fontSize: 12, color: t.textTertiary),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 170),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final m in chosen)
                      _MemberRow(
                        key: Key('task_board_member_${m.userId}'),
                        member: m,
                        onRole: (role) => _setRole(m.userId, role),
                        onRemove: () => setState(() => _members.remove(m.userId)),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: Space.smd),
            TextField(
              key: const Key('task_board_share_search'),
              controller: _search,
              onChanged: _onQuery,
              decoration: InputDecoration(
                hintText: l10n.taskBoardShareSearch,
                prefixIcon: const Icon(LucideIcons.search, size: 16),
                isDense: true,
              ),
            ),
            const SizedBox(height: Space.sm),
            Expanded(
              child: _error != null && _found.isEmpty
                  ? Center(
                      child: Text(
                        TasksFormat.error(l10n, _error!),
                        style: TextStyle(fontSize: 12, color: t.danger),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      itemCount: _found.length + (_loading ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= _found.length) {
                          return const Padding(
                            key: Key('task_board_share_loading'),
                            padding: EdgeInsets.symmetric(vertical: Space.smd),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        final user = _found[i];
                        return CheckboxListTile(
                          key: Key('task_board_candidate_${user.id}'),
                          dense: true,
                          value: _members.containsKey(user.id),
                          onChanged: (_) => _toggle(user),
                          controlAffinity: ListTileControlAffinity.leading,
                          secondary: InitialsAvatar(label: user.label, radius: 15),
                          title: Text(
                            user.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            user.departmentName.isNotEmpty
                                ? '${user.email} · ${user.departmentName}'
                                : user.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: t.textTertiary),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        if (_error != null && _found.isNotEmpty)
          Expanded(
            child: Text(
              TasksFormat.error(l10n, _error!),
              style: TextStyle(fontSize: 12, color: t.danger),
            ),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('task_board_share_save'),
          onPressed: _saving ? null : () => unawaited(_save()),
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.save),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    super.key,
    required this.member,
    required this.onRole,
    required this.onRemove,
  });

  final TaskBoardMember member;
  final ValueChanged<String> onRole;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xxs),
      child: Row(
        children: [
          InitialsAvatar(label: member.label, radius: 14),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              member.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          DropdownButton<String>(
            key: Key('task_board_role_${member.userId}'),
            value: member.role,
            underline: const SizedBox.shrink(),
            isDense: true,
            style: TextStyle(fontSize: 12, color: t.textSecondary),
            items: [
              DropdownMenuItem(
                value: TaskBoardRole.editor,
                child: Text(l10n.taskBoardRoleEditor),
              ),
              DropdownMenuItem(
                value: TaskBoardRole.viewer,
                child: Text(l10n.taskBoardRoleViewer),
              ),
            ],
            onChanged: (role) {
              if (role != null) onRole(role);
            },
          ),
          IconButton(
            key: Key('task_board_member_remove_${member.userId}'),
            tooltip: l10n.taskBoardRemoveMember,
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            icon: Icon(LucideIcons.x, color: t.textTertiary),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
