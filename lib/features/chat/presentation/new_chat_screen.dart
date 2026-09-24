import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/platform/desktop_layout.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/state_view.dart';
import '../data/chat_models.dart';
import 'chat_formatters.dart';
import 'chat_providers.dart';

/// «Новый чат» (or «Добавить участника» with [addToConversationId]).
/// Desktop: the web's modal (max-w-lg) over the messenger; the chat created
/// opens in the right pane. Phones push the page as before.
Future<void> openNewChat(BuildContext context, {String? addToConversationId}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  if (!container.read(desktopLayoutProvider)) {
    await context.push(
      addToConversationId == null ? Routes.chatNew : Routes.chatAddMembersPath(addToConversationId),
    );
    return;
  }
  final opened = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final height = MediaQuery.sizeOf(ctx).height;
      return Dialog(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: NewChatScreen.dialogWidth,
          height: (height - Space.xxxl * 2).clamp(360.0, 640.0),
          child: NewChatScreen(addToConversationId: addToConversationId, dialog: true),
        ),
      );
    },
  );
  if (opened != null && addToConversationId == null) {
    container.read(chatSelectedConversationProvider.notifier).select(opened);
  }
}

/// Pick a colleague (direct chat) or several (group) from the organization
/// directory. Also used to add members to an existing group.
class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({
    super.key,
    this.addToConversationId,
    this.excludeUserIds = const {},
    this.dialog = false,
  });

  /// When set, selected users are added to this group instead of creating a chat.
  final String? addToConversationId;
  final Set<String> excludeUserIds;

  /// Desktop modal ([openNewChat]): ✕ in the header, «Отмена» / «Создать»
  /// in the footer instead of the floating button; pops with the id of the
  /// chat opened.
  final bool dialog;

  static const dialogWidth = 560.0;

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _search = TextEditingController();
  final _title = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _groupMode = false;
  final Set<String> _selected = {};
  final Map<String, ChatUser> _users = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _groupMode = widget.addToConversationId != null;
  }

  @override
  void dispose() {
    _search.dispose();
    _title.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = q.trim());
    });
  }

  Future<void> _openDirect(ChatUser u) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final conv = await ref
          .read(chatRepositoryProvider)
          .createDirect(u.userId);
      if (!mounted) return;
      _opened(conv.id);
    } on AppException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ChatFormat.error(l10n, e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _opened(String conversationId) {
    if (widget.dialog) {
      Navigator.pop(context, conversationId);
    } else {
      context.pushReplacement(Routes.chatConversationPath(conversationId));
    }
  }

  Future<void> _submitGroup() async {
    if (_busy || _selected.isEmpty) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final repo = ref.read(chatRepositoryProvider);
      if (widget.addToConversationId != null) {
        for (final id in _selected) {
          await repo.addMember(widget.addToConversationId!, id);
        }
        if (mounted) widget.dialog ? Navigator.pop(context) : context.pop();
        return;
      }
      final title = _title.text.trim();
      if (title.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.chatGroupTitle)));
        return;
      }
      final conv = await repo.createGroup(title, _selected.toList());
      if (!mounted) return;
      _opened(conv.id);
    } on AppException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ChatFormat.error(l10n, e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final selfId = ref.read(chatRepositoryProvider).selfId;
    final results = ref.watch(chatUserSearchProvider(_query));
    final adding = widget.addToConversationId != null;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.dialog,
        title: Text(
          adding
              ? l10n.chatAddMember
              : (_groupMode ? l10n.chatNewGroup : l10n.chatNew),
        ),
        actions: [
          if (!adding)
            TextButton(
              onPressed: () => setState(() => _groupMode = !_groupMode),
              child: Text(_groupMode ? l10n.chatNew : l10n.chatNewGroup),
            ),
          if (widget.dialog)
            IconButton(
              key: const Key('new_chat_close'),
              tooltip: l10n.close,
              icon: const Icon(LucideIcons.x),
              onPressed: () => Navigator.pop(context),
            ),
        ],
      ),
      bottomNavigationBar: widget.dialog && _groupMode ? _dialogFooter(context, adding) : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
            child: TextField(
              key: const Key('chat_user_search'),
              controller: _search,
              autofocus: true,
              onChanged: _onQuery,
              decoration: InputDecoration(
                hintText: l10n.chatSearchUsers,
                prefixIcon: const Icon(LucideIcons.search),
              ),
            ),
          ),
          if (_groupMode && !adding)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                Space.sm,
                Space.md,
                0,
              ),
              child: TextField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: l10n.chatGroupTitle,
                  prefixIcon: const Icon(LucideIcons.users),
                ),
              ),
            ),
          if (_groupMode)
            Padding(
              padding: const EdgeInsets.all(Space.sm),
              child: Text(
                l10n.chatSelectedMembers(_selected.length),
                style: TextStyle(color: tokens.textMuted),
              ),
            ),
          Expanded(
            child: results.when(
              loading: () => const StateView.loading(),
              error: (e, _) => StateView.error(
                message: ChatFormat.error(l10n, e),
                onRetry: () => ref.invalidate(chatUserSearchProvider(_query)),
              ),
              data: (users) {
                final visible = users
                    .where(
                      (u) =>
                          u.userId != selfId &&
                          !widget.excludeUserIds.contains(u.userId),
                    )
                    .toList();
                for (final u in visible) {
                  _users[u.userId] = u;
                }
                if (visible.isEmpty) {
                  return StateView.empty(
                    title: l10n.chatNoUsers,
                    icon: LucideIcons.userSearch,
                  );
                }
                return ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (_, i) {
                    final u = visible[i];
                    final selected = _selected.contains(u.userId);
                    return ListTile(
                      key: ValueKey('user_${u.userId}'),
                      leading: Stack(
                        children: [
                          InitialsAvatar(label: u.label, colorKey: u.userId),
                          if (u.online)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: tokens.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(u.label),
                      subtitle: Text(u.email),
                      trailing: _groupMode
                          ? Checkbox(
                              value: selected,
                              onChanged: (_) => _toggle(u.userId),
                            )
                          : null,
                      onTap: () =>
                          _groupMode ? _toggle(u.userId) : _openDirect(u),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: !widget.dialog && _groupMode && _selected.isNotEmpty
          ? FloatingActionButton.extended(
              heroTag: 'fab_new_group_submit',
              onPressed: _busy ? null : _submitGroup,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.check),
              label: Text(adding ? l10n.chatAddMember : l10n.chatCreateGroup),
            )
          : null,
    );
  }

  /// The web modal's footer: «Отмена» and «Создать» (or «Добавить»).
  Widget _dialogFooter(BuildContext context, bool adding) {
    final l10n = context.l10n;
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.divider, width: t.borderWidth)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.smd),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
            const SizedBox(width: Space.sm),
            FilledButton(
              key: const Key('new_chat_submit'),
              onPressed: _busy || _selected.isEmpty ? null : _submitGroup,
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(adding ? l10n.chatAddMember : l10n.desktopChatCreate),
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });
}
