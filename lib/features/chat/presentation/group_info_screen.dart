import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/state_view.dart';
import '../data/chat_models.dart';
import 'channels/channel_widgets.dart';
import 'chat_avatar.dart';
import 'chat_formatters.dart';
import 'chat_providers.dart';
import 'new_chat_screen.dart';
import 'open_direct_chat.dart';
import 'protected/chat_protection.dart';
import 'translation/translation_settings.dart';
import 'status/chat_status_providers.dart';
import '../../../shared/widgets/app_sheet.dart';

/// Conversation details: members with roles, add/remove/leave, rename,
/// per-member settings (mute/pin/archive).
class GroupInfoScreen extends ConsumerWidget {
  const GroupInfoScreen({
    super.key,
    required this.conversationId,
    this.onClose,
    this.onShowMessage,
  });
  final String conversationId;

  /// Desktop: the details panel beside the conversation (the web's ⓘ
  /// aside), closed with ✕ instead of going back.
  final VoidCallback? onClose;

  /// Panel: «Показать в чате» from «Медиа, файлы…» jumps to the message.
  final ValueChanged<String>? onShowMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final state = ref.watch(conversationProvider(conversationId));
    final conv = state.conversation;
    final peer = conv?.peer;
    final peerStatus = peer == null
        ? null
        : watchUserStatus(ref, peer.userId, peer.status);
    final repo = ref.read(chatRepositoryProvider);
    final selfId = repo.selfId;

    Future<void> run(Future<void> Function() action) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await action();
      } on AppException catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(ChatFormat.error(l10n, e))),
        );
      }
    }

    final panel = onClose != null;
    final close = panel
        ? IconButton(
            key: const Key('chat_info_panel_close'),
            tooltip: l10n.close,
            icon: const Icon(LucideIcons.x),
            onPressed: onClose,
          )
        : null;
    if (conv == null) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !panel,
          title: Text(panel ? l10n.desktopChatDetails : l10n.chatInfo),
          actions: [?close],
        ),
        body: const StateView.loading(),
      );
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !panel,
        title: Text(panel ? l10n.desktopChatDetails : l10n.chatInfo),
        actions: [
          if ((conv.isGroup || conv.isChannel) && conv.isAdmin)
            IconButton(
              icon: const Icon(LucideIcons.pencil),
              tooltip: l10n.chatRename,
              onPressed: () async {
                final ctrl = TextEditingController(text: conv.title);
                final title = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.chatRename),
                    content: TextField(
                      controller: ctrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: l10n.chatGroupTitle,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                        child: Text(l10n.save),
                      ),
                    ],
                  ),
                );
                if (title != null && title.isNotEmpty) {
                  await run(() => repo.patchChat(conversationId, title: title));
                }
              },
            ),
          ?close,
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              children: [
                _GroupAvatarEditor(conversation: conv),
                const SizedBox(height: Space.md),
                Text(
                  conv.isSaved ? l10n.chatSaved : conv.title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                if (conv.isChannel)
                  Text(
                    l10n.channelSubscribersCount(conv.memberCount),
                    key: const Key('channel_info_count'),
                    style: TextStyle(color: tokens.textMuted),
                  ),
                if (conv.isSaved)
                  Text(
                    l10n.chatSavedHint,
                    style: TextStyle(color: tokens.textMuted),
                    textAlign: TextAlign.center,
                  ),
                if (!conv.isGroup && conv.peer != null) ...[
                  Text(
                    conv.peer!.email,
                    style: TextStyle(color: tokens.textMuted),
                  ),
                  Text(
                    ChatFormat.presence(context, conv.peer),
                    style: TextStyle(
                      color: conv.peer!.online
                          ? tokens.success
                          : tokens.textMuted,
                    ),
                  ),
                  if (peerStatus != null)
                    Text(
                      ChatStatusFormat.line(context, peerStatus),
                      key: const Key('chat_info_status'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: tokens.textSecondary),
                    ),
                ],
              ],
            ),
          ),
          if ((conv.isGroup || conv.isChannel) &&
              (conv.description.isNotEmpty || conv.isAdmin)) ...[
            const Divider(height: 1),
            ListTile(
              key: const Key('group_description'),
              leading: const Icon(LucideIcons.info),
              title: Text(
                conv.description.isEmpty
                    ? l10n.chatDescriptionAdd
                    : conv.description,
                style: conv.description.isEmpty
                    ? TextStyle(color: tokens.primary)
                    : null,
              ),
              subtitle: conv.description.isEmpty
                  ? null
                  : Text(
                      l10n.chatDescription,
                      style: TextStyle(color: tokens.textMuted),
                    ),
              trailing: conv.isAdmin
                  ? Icon(LucideIcons.pencil, size: 18, color: tokens.textMuted)
                  : null,
              onTap: !conv.isAdmin
                  ? null
                  : () async {
                      final ctrl = TextEditingController(
                        text: conv.description,
                      );
                      final text = await showDialog<String>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(
                            conv.description.isEmpty
                                ? l10n.chatDescriptionAdd
                                : l10n.chatDescriptionEdit,
                          ),
                          content: TextField(
                            key: const Key('group_description_field'),
                            controller: ctrl,
                            autofocus: true,
                            minLines: 1,
                            maxLines: 6,
                            maxLength: 500,
                            decoration: InputDecoration(
                              labelText: l10n.chatDescription,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(l10n.cancel),
                            ),
                            FilledButton(
                              key: const Key('group_description_save'),
                              onPressed: () =>
                                  Navigator.pop(ctx, ctrl.text.trim()),
                              child: Text(l10n.save),
                            ),
                          ],
                        ),
                      );
                      if (text == null || text == conv.description) return;
                      if (text.characters.length > 500) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.chatDescriptionTooLong),
                            ),
                          );
                        }
                        return;
                      }
                      await run(
                        () => repo.setDescription(conversationId, text),
                      );
                    },
            ),
          ],
          const Divider(height: 1),
          ListTile(
            key: const Key('chat_info_media'),
            leading: const Icon(LucideIcons.images),
            title: Text(l10n.chatMediaFilesLinks),
            trailing: Icon(LucideIcons.chevronRight, color: tokens.textMuted),
            onTap: () async {
              final target = await context.push<String>(
                Routes.chatMediaPath(conversationId),
              );
              // «Показать в чате»: back to the conversation, which jumps.
              if (target == null || !context.mounted) return;
              if (onShowMessage != null) {
                onShowMessage!(target);
              } else {
                context.pop(target);
              }
            },
          ),
          if (!conv.isSaved) ...[
            const Divider(height: 1),
            ListTile(
              key: const Key('chat_info_protection'),
              leading: Icon(
                conv.protection.active
                    ? LucideIcons.shieldCheck
                    : LucideIcons.shield,
                color: conv.protection.active ? tokens.success : null,
              ),
              title: Text(l10n.chatProtection),
              subtitle: Text(
                conv.protection.active
                    ? l10n.chatProtectionActive
                    : l10n.chatProtectionNone,
                style: TextStyle(color: tokens.textMuted),
              ),
              trailing: Icon(LucideIcons.chevronRight, color: tokens.textMuted),
              onTap: () => ChatProtectionSheet.show(context, conversationId),
            ),
          ],
          if (!conv.isSaved) ...[
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(LucideIcons.volumeX),
              title: Text(l10n.chatMute),
              value: conv.isMuted,
              onChanged: (v) => run(
                () => v
                    ? repo.patchChat(
                        conversationId,
                        mutedUntil: DateTime.now().add(
                          const Duration(days: 3650),
                        ),
                      )
                    : repo.patchChat(conversationId, unmute: true),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(LucideIcons.pin),
              title: Text(l10n.chatPin),
              value: conv.settings.pinned,
              onChanged: (v) =>
                  run(() => repo.patchChat(conversationId, pinned: v)),
            ),
            SwitchListTile(
              secondary: const Icon(LucideIcons.archive),
              title: Text(l10n.chatArchive),
              value: conv.settings.archived,
              onChanged: (v) =>
                  run(() => repo.patchChat(conversationId, archived: v)),
            ),
            ChatAutoTranslateTile(conversationId: conversationId),
          ],
          if (conv.isChannel) ChannelInfoSection(conversation: conv),
          if (conv.isGroup) ...[
            const Divider(height: 1),
            if (panel)
              // Desktop panel: one line — the count never wraps under the
              // button, which becomes an icon.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.md,
                  Space.sm,
                  Space.xs,
                  Space.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${l10n.chatMembers} · ${conv.memberCount}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (conv.isAdmin)
                      IconButton(
                        key: const Key('chat_info_add_member'),
                        tooltip: l10n.chatAddMember,
                        icon: const Icon(LucideIcons.userPlus, size: 18),
                        onPressed: () => openNewChat(
                          context,
                          addToConversationId: conversationId,
                        ),
                      ),
                  ],
                ),
              )
            else
              ListTile(
                title: Text(
                  '${l10n.chatMembers} · ${conv.memberCount}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                trailing: conv.isAdmin
                    ? TextButton.icon(
                        icon: const Icon(LucideIcons.userPlus),
                        label: Text(l10n.chatAddMember),
                        onPressed: () => openNewChat(
                          context,
                          addToConversationId: conversationId,
                        ),
                      )
                    : null,
              ),
            for (final m in conv.members)
              _MemberTile(member: m, conv: conv, selfId: selfId, onAction: run),
            const Divider(height: 1),
            ListTile(
              leading: Icon(LucideIcons.logOut, color: tokens.danger),
              title: Text(
                l10n.chatLeave,
                style: TextStyle(color: tokens.danger),
              ),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.chatLeave),
                    content: Text(l10n.chatLeaveConfirm),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l10n.chatLeave),
                      ),
                    ],
                  ),
                );
                if (ok != true || !context.mounted) return;
                await run(() => repo.removeMember(conversationId, selfId));
                // Panel: the pane of the chat left closes with it.
                if (panel) {
                  ref
                      .read(chatSelectedConversationProvider.notifier)
                      .select(null);
                }
                if (context.mounted) context.go(Routes.chat);
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Conversation picture; group admins can replace it (pick an image →
/// upload as an attachment → `POST /chats/{id}/avatar`).
class _GroupAvatarEditor extends ConsumerStatefulWidget {
  const _GroupAvatarEditor({required this.conversation});
  final ChatConversation conversation;

  @override
  ConsumerState<_GroupAvatarEditor> createState() => _GroupAvatarEditorState();
}

class _GroupAvatarEditorState extends ConsumerState<_GroupAvatarEditor> {
  bool _busy = false;

  Future<void> _change() async {
    if (_busy) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final picked = await ref.read(chatImagePickerProvider)();
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .setGroupAvatar(
            widget.conversation.id,
            filePath: picked.path,
            filename: picked.name,
          );
      messenger.showSnackBar(SnackBar(content: Text(l10n.chatAvatarUpdated)));
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
    final tokens = context.tokens;
    final conv = widget.conversation;
    final canEdit = (conv.isGroup || conv.isChannel) && conv.isAdmin;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ChatAvatar(conversation: conv, radius: 36),
        if (_busy)
          const Positioned.fill(
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        if (canEdit)
          Positioned(
            right: -Space.sm,
            bottom: -Space.sm,
            child: IconButton.filled(
              key: const Key('group_avatar_change'),
              tooltip: context.l10n.chatAvatarChange,
              style: IconButton.styleFrom(
                backgroundColor: tokens.brand,
                foregroundColor: tokens.onBrand,
              ),
              iconSize: 18,
              onPressed: _busy ? null : _change,
              icon: const Icon(LucideIcons.camera),
            ),
          ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.conv,
    required this.selfId,
    required this.onAction,
  });
  final ChatMember member;
  final ChatConversation conv;
  final String selfId;
  final Future<void> Function(Future<void> Function()) onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final role = switch (member.role) {
      'owner' => l10n.chatRoleOwner,
      'admin' => l10n.chatRoleAdmin,
      _ => l10n.chatRoleMember,
    };
    return Consumer(
      builder: (context, ref, _) {
        final repo = ref.read(chatRepositoryProvider);
        // Any colleague in the list can be written to privately;
        // administrators also get their member actions.
        final self = member.userId == selfId;
        final canManage = conv.isAdmin && member.role != 'owner' && !self;
        return ListTile(
          leading: InitialsAvatar(label: member.label, colorKey: member.userId),
          title: Text(
            member.userId == selfId
                ? '${member.label} (${l10n.chatYou})'
                : member.label,
          ),
          subtitle: Text(
            [
              if (watchUserStatus(ref, member.userId, member.status)
                  case final status?)
                ChatStatusFormat.line(context, status, withUntil: false),
              member.email,
              role,
            ].where((s) => s.isNotEmpty).join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.textMuted),
          ),
          trailing: !self
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (member.online)
                      Icon(LucideIcons.circle, size: 10, color: tokens.success),
                    IconButton(
                      key: Key('member_write_${member.userId}'),
                      tooltip: l10n.chatWritePersonally,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(LucideIcons.messageCircle, size: 18),
                      onPressed: () =>
                          openDirectChat(context, ref, member.userId),
                    ),
                  ],
                )
              : member.online
              ? Icon(LucideIcons.circle, size: 10, color: tokens.success)
              : null,
          onTap: self
              ? null
              : () async {
                  final action = await showAppSheet<String>(
                    context: context,
                    showDragHandle: true,
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            key: const Key('member_write'),
                            leading: const Icon(LucideIcons.messageCircle),
                            title: Text(l10n.chatWritePersonally),
                            onTap: () => Navigator.pop(ctx, 'write'),
                          ),
                          if (canManage &&
                              conv.myRole == 'owner' &&
                              member.role != 'admin')
                            ListTile(
                              key: const Key('member_make_admin'),
                              leading: const Icon(LucideIcons.shieldCheck),
                              title: Text(l10n.chatMakeAdmin),
                              onTap: () => Navigator.pop(ctx, 'admin'),
                            ),
                          if (canManage &&
                              conv.myRole == 'owner' &&
                              member.role == 'admin')
                            ListTile(
                              key: const Key('member_remove_admin'),
                              leading: const Icon(LucideIcons.shieldOff),
                              title: Text(l10n.chatRemoveAdmin),
                              onTap: () => Navigator.pop(ctx, 'member'),
                            ),
                          if (canManage)
                            ListTile(
                              leading: Icon(
                                LucideIcons.userMinus,
                                color: ctx.tokens.danger,
                              ),
                              title: Text(l10n.chatRemoveMember),
                              onTap: () => Navigator.pop(ctx, 'remove'),
                            ),
                        ],
                      ),
                    ),
                  );
                  if (!context.mounted) return;
                  switch (action) {
                    case 'write':
                      await openDirectChat(context, ref, member.userId);
                    case 'admin':
                      await onAction(
                        () => repo.setRole(conv.id, member.userId, 'admin'),
                      );
                    case 'member':
                      await onAction(
                        () => repo.setRole(conv.id, member.userId, 'member'),
                      );
                    case 'remove':
                      await onAction(
                        () => repo.removeMember(conv.id, member.userId),
                      );
                  }
                },
        );
      },
    );
  }
}
