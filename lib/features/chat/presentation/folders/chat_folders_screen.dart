import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../../data/chat_folders.dart';
import '../../data/chat_models.dart';
import '../chat_avatar.dart';
import '../chat_emoji_picker.dart';
import '../chat_providers.dart';
import 'chat_folders_providers.dart';
import '../../../../shared/widgets/app_sheet.dart';

Future<void> openChatFolders(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => const ChatFoldersScreen()));

/// Pops with the saved folder id.
Future<String?> openChatFolderEditor(
  BuildContext context, {
  ChatFolder? folder,
  List<String> initialChatIds = const [],
}) => Navigator.of(context).push<String>(
  MaterialPageRoute<String>(
    builder: (_) =>
        ChatFolderEditorScreen(folder: folder, initialChatIds: initialChatIds),
  ),
);

/// «Добавить в папку» for one chat.
Future<void> showAddToFolderSheet(
  BuildContext context,
  ChatConversation conversation,
) => showAppSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => ChatAddToFolderSheet(conversation: conversation),
);

String chatFolderSummary(AppLocalizations l10n, ChatFolder f) => [
  for (final type in ChatFolder.allTypes)
    if (f.types.contains(type))
      switch (type) {
        'direct' => l10n.chatFolderTypeDirect,
        'group' => l10n.chatFilterGroups,
        _ => l10n.chatFilterChannels,
      },
  if (f.chatIds.isNotEmpty) l10n.chatFolderChatsCount(f.chatIds.length),
  if (f.unreadOnly) l10n.chatFolderUnreadOnly,
].join(', ');

String chatFolderTitle(ChatFolder f) =>
    f.emoji.isEmpty ? f.name : '${f.emoji} ${f.name}';

/// Folder list: drag to reorder, edit, delete, «Новая папка» (up to 10).
class ChatFoldersScreen extends ConsumerWidget {
  const ChatFoldersScreen({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ChatFolder f,
  ) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.chatFolderDeleteConfirm(f.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('folder_delete_confirm'),
            style: FilledButton.styleFrom(backgroundColor: ctx.tokens.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.chatFolderDelete),
          ),
        ],
      ),
    );
    if (ok == true) unawaited(ref.read(chatFoldersProvider.notifier).remove(f.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final state = ref.watch(chatFoldersProvider);
    ref.listen<ChatFoldersState>(chatFoldersProvider, (prev, next) {
      if (next.error != null && !identical(prev?.error, next.error)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.chatFoldersSaveFailed)),
        );
      }
    });
    final folders = state.folders;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.chatFoldersTitle)),
      body: Column(
        children: [
          if (state.sync == ChatFoldersSync.pending)
            Container(
              key: const Key('folders_pending'),
              width: double.infinity,
              color: t.warningSoft,
              padding: const EdgeInsets.symmetric(
                horizontal: Space.md,
                vertical: Space.sm,
              ),
              child: Text(
                l10n.chatFoldersPending,
                style: theme.textTheme.bodySmall?.copyWith(color: t.textPrimary),
              ),
            ),
          Expanded(
            child: folders.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Space.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.folders, size: 40, color: t.textTertiary),
                          const SizedBox(height: Space.md),
                          Text(
                            l10n.chatFoldersEmpty,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: t.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    key: const Key('folders_list'),
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.symmetric(vertical: Space.sm),
                    itemCount: folders.length,
                    onReorderItem: (from, to) =>
                        ref.read(chatFoldersProvider.notifier).move(from, to),
                    itemBuilder: (context, i) {
                      final f = folders[i];
                      final summary = chatFolderSummary(l10n, f);
                      return ListTile(
                        key: ValueKey('folder_tile_${f.id}'),
                        contentPadding: const EdgeInsets.only(
                          left: Space.xs,
                          right: Space.xs,
                        ),
                        leading: ReorderableDragStartListener(
                          index: i,
                          child: SizedBox.square(
                            dimension: kMinInteractiveDimension,
                            child: Icon(
                              LucideIcons.gripVertical,
                              color: t.textTertiary,
                              semanticLabel: l10n.chatFolderReorder,
                            ),
                          ),
                        ),
                        title: Text(
                          chatFolderTitle(f),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: summary.isEmpty
                            ? null
                            : Text(
                                summary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: t.textMuted),
                              ),
                        trailing: IconButton(
                          key: ValueKey('folder_delete_${f.id}'),
                          tooltip: l10n.chatFolderDelete,
                          icon: Icon(LucideIcons.trash2, color: t.danger),
                          onPressed: () => _delete(context, ref, f),
                        ),
                        onTap: () => openChatFolderEditor(context, folder: f),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                Space.sm,
                Space.md,
                Space.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!state.canAdd)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.sm),
                      child: Text(
                        l10n.chatFolderLimit,
                        key: const Key('folders_limit'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: t.textSecondary,
                        ),
                      ),
                    ),
                  FilledButton.icon(
                    key: const Key('folders_add'),
                    style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                    icon: const Icon(LucideIcons.folderPlus),
                    label: Text(l10n.chatFolderNew),
                    onPressed: state.canAdd
                        ? () => openChatFolderEditor(context)
                        : null,
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

/// Create / edit a folder: name, emoji, types, unread only, exclude muted,
/// chats (search and checkboxes).
class ChatFolderEditorScreen extends ConsumerStatefulWidget {
  const ChatFolderEditorScreen({
    super.key,
    this.folder,
    this.initialChatIds = const [],
  });
  final ChatFolder? folder;
  final List<String> initialChatIds;

  @override
  ConsumerState<ChatFolderEditorScreen> createState() =>
      _ChatFolderEditorScreenState();
}

class _ChatFolderEditorScreenState
    extends ConsumerState<ChatFolderEditorScreen> {
  late final _name = TextEditingController(text: widget.folder?.name ?? '');
  late String _emoji = widget.folder?.emoji ?? '';
  late final Set<String> _types = {...?widget.folder?.types};
  late final List<String> _chatIds = [
    ...?widget.folder?.chatIds,
    for (final id in widget.initialChatIds)
      if (!(widget.folder?.chatIds.contains(id) ?? false)) id,
  ];
  late bool _unreadOnly = widget.folder?.unreadOnly ?? false;
  late bool _excludeMuted = widget.folder?.excludeMuted ?? false;
  String _query = '';
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickEmoji() async {
    final emoji = await ChatEmojiPickerSheet.show(context);
    if (emoji != null && mounted) setState(() => _emoji = emoji);
  }

  void _save() {
    final l10n = context.l10n;
    final notifier = ref.read(chatFoldersProvider.notifier);
    final isNew = widget.folder == null;
    final folder = ChatFolder(
      id: widget.folder?.id ?? ChatFoldersNotifier.newId(),
      name: _name.text.trim(),
      emoji: _emoji,
      chatIds: List.of(_chatIds),
      types: [
        for (final type in ChatFolder.allTypes)
          if (_types.contains(type)) type,
      ],
      unreadOnly: _unreadOnly,
      excludeMuted: _excludeMuted,
    );
    final invalid = folder.validate();
    if (invalid != null) {
      setState(
        () => _error = switch (invalid) {
          'name' => l10n.chatFolderErrorName,
          'chats' => l10n.chatFolderErrorChats,
          _ => l10n.chatFolderErrorEmpty,
        },
      );
      return;
    }
    if (isNew && !ref.read(chatFoldersProvider).canAdd) {
      setState(() => _error = l10n.chatFolderLimit);
      return;
    }
    // Optimistic: the list shows it at once, the server gets it after.
    unawaited(notifier.upsert(folder));
    Navigator.pop(context, folder.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final q = _query.toLowerCase();
    final chats = ref
        .watch(conversationsProvider.select((s) => s.items))
        .where(
          (c) =>
              q.isEmpty ||
              (c.isSaved ? l10n.chatSaved : c.title).toLowerCase().contains(q),
        )
        .toList();
    Widget section(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xs),
      child: Text(
        t.sectionLabel(text),
        // textTertiary is 4.37:1 at 12 px on the page background.
        style: theme.textTheme.labelMedium?.copyWith(
          color: t.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    final header = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              label: l10n.chatFolderEmoji,
              excludeSemantics: true,
              child: InkWell(
                key: const Key('folder_emoji'),
                customBorder: const CircleBorder(),
                onTap: _pickEmoji,
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.surfaceMuted,
                    shape: BoxShape.circle,
                    border: Border.all(color: t.border, width: t.borderWidth),
                  ),
                  child: _emoji.isEmpty
                      ? Icon(LucideIcons.folder, color: t.textSecondary)
                      : Text(_emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: TextField(
                key: const Key('folder_name'),
                controller: _name,
                autofocus: widget.folder == null,
                maxLength: ChatFolder.maxName,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() => _error = null),
                // maxLength enforces the limit; the default 12 px counter
                // is below 4.5:1 on the page background.
                decoration: InputDecoration(
                  labelText: l10n.chatFolderName,
                  counterText: '',
                ),
              ),
            ),
          ],
        ),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          child: Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              key: const Key('folder_error'),
              style: theme.textTheme.bodySmall?.copyWith(color: t.danger),
            ),
          ),
        ),
      section(l10n.chatFolderTypes),
      for (final type in ChatFolder.allTypes)
        CheckboxListTile(
          key: Key('folder_type_$type'),
          value: _types.contains(type),
          title: Text(switch (type) {
            'direct' => l10n.chatFolderTypeDirect,
            'group' => l10n.chatFilterGroups,
            _ => l10n.chatFilterChannels,
          }),
          onChanged: (v) => setState(() {
            _error = null;
            if (v == true) {
              _types.add(type);
            } else {
              _types.remove(type);
            }
          }),
        ),
      SwitchListTile(
        key: const Key('folder_unread_only'),
        title: Text(l10n.chatFolderUnreadOnly),
        value: _unreadOnly,
        onChanged: (v) => setState(() => _unreadOnly = v),
      ),
      SwitchListTile(
        key: const Key('folder_exclude_muted'),
        title: Text(l10n.chatFolderExcludeMuted),
        value: _excludeMuted,
        onChanged: (v) => setState(() => _excludeMuted = v),
      ),
      section(
        '${l10n.chatFolderChats} · ${l10n.chatFolderChatsCount(_chatIds.length)}',
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.xs),
        child: TextField(
          key: const Key('folder_chat_search'),
          onChanged: (v) => setState(() => _query = v.trim()),
          decoration: InputDecoration(
            isDense: true,
            hintText: l10n.chatFolderSearchChats,
            prefixIcon: const Icon(LucideIcons.search, size: 18),
          ),
        ),
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.folder == null ? l10n.chatFolderNew : l10n.chatFolderEditTitle,
        ),
        actions: [
          TextButton(
            key: const Key('folder_save'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _save,
            child: Text(l10n.save),
          ),
        ],
      ),
      body: ListView.builder(
        key: const Key('folder_editor'),
        padding: const EdgeInsets.only(bottom: Space.xl),
        itemCount: header.length + chats.length,
        itemBuilder: (context, i) {
          if (i < header.length) return header[i];
          final c = chats[i - header.length];
          final checked = _chatIds.contains(c.id);
          return CheckboxListTile(
            key: ValueKey('folder_chat_${c.id}'),
            value: checked,
            secondary: ExcludeSemantics(
              child: ChatAvatar(conversation: c, radius: 18),
            ),
            title: Text(
              c.isSaved ? l10n.chatSaved : c.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onChanged: (v) => setState(() {
              _error = null;
              if (v == true) {
                if (!_chatIds.contains(c.id)) _chatIds.add(c.id);
              } else {
                _chatIds.remove(c.id);
              }
            }),
          );
        },
      ),
    );
  }
}

/// Toggles one chat in the folders' explicit chats; «Новая папка».
class ChatAddToFolderSheet extends ConsumerWidget {
  const ChatAddToFolderSheet({super.key, required this.conversation});
  final ChatConversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final state = ref.watch(chatFoldersProvider);
    final notifier = ref.read(chatFoldersProvider.notifier);
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('add_to_folder_sheet'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.sm),
              child: Text(
                l10n.chatAddToFolder,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final f in state.folders)
              CheckboxListTile(
                key: ValueKey('add_to_folder_${f.id}'),
                value: f.chatIds.contains(conversation.id),
                title: Text(
                  chatFolderTitle(f),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onChanged: (_) =>
                    unawaited(notifier.toggleChat(f.id, conversation.id)),
              ),
            ListTile(
              key: const Key('add_to_folder_new'),
              leading: Icon(LucideIcons.folderPlus, color: t.primary),
              title: Text(l10n.chatFolderNew),
              subtitle: state.canAdd
                  ? null
                  : Text(
                      l10n.chatFolderLimit,
                      style: TextStyle(color: t.textMuted),
                    ),
              enabled: state.canAdd,
              onTap: () {
                Navigator.pop(context);
                unawaited(
                  openChatFolderEditor(
                    context,
                    initialChatIds: [conversation.id],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
