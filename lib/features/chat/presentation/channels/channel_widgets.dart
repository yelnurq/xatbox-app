import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/initials_avatar.dart';
import '../../data/chat_models.dart';
import '../broadcast/broadcast_format.dart';
import '../broadcast/broadcast_providers.dart';
import '../chat_providers.dart';
import '../comments/channel_thread_providers.dart';
import '../status/chat_status_providers.dart';
import 'channel_subscribers_screen.dart';
import '../../../../shared/widgets/app_sheet.dart';

/// Megaphone avatar of a channel without a picture.
class ChannelAvatar extends StatelessWidget {
  const ChannelAvatar({super.key, required this.id, this.radius = 20});
  final String id;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      key: ValueKey('channel_avatar_$id'),
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(color: t.avatarColorFor(id), shape: BoxShape.circle),
      child: Icon(LucideIcons.megaphone, size: radius * 0.95, color: t.avatarTextColorFor(id)),
    );
  }
}

class ChannelEmptyState extends StatelessWidget {
  const ChannelEmptyState({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: t.textTertiary),
            const SizedBox(height: Space.md),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

typedef ChannelDraft = ({String title, String description, bool isPublic});

/// «Создать канал»: name, description, public / private.
class ChannelCreateSheet extends StatefulWidget {
  const ChannelCreateSheet({super.key});

  static Future<ChannelDraft?> show(BuildContext context) => showAppSheet<ChannelDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const ChannelCreateSheet(),
  );

  @override
  State<ChannelCreateSheet> createState() => _ChannelCreateSheetState();
}

class _ChannelCreateSheetState extends State<ChannelCreateSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _public = true;
  bool _error = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = true);
      return;
    }
    Navigator.pop<ChannelDraft>(context, (
      title: title,
      description: _description.text.trim(),
      isPublic: _public,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xs, 0, Space.md, Space.xs),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.cancel,
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      l10n.channelCreate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  FilledButton(
                    key: const Key('channel_create'),
                    onPressed: _submit,
                    child: Text(l10n.pollCreate),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: ChannelAvatar(id: _title.text.isEmpty ? 'new' : _title.text, radius: 32)),
                  const SizedBox(height: Space.md),
                  TextField(
                    key: const Key('channel_title'),
                    controller: _title,
                    autofocus: true,
                    maxLength: 200,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() => _error = false),
                    decoration: InputDecoration(
                      labelText: l10n.channelNameLabel,
                      counterText: '',
                      errorText: _error ? l10n.chatGroupTitle : null,
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  TextField(
                    key: const Key('channel_description'),
                    controller: _description,
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: l10n.channelDescriptionLabel),
                  ),
                  SwitchListTile(
                    key: const Key('channel_public'),
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(_public ? LucideIcons.globe : LucideIcons.lock, color: t.primary),
                    title: Text(l10n.channelPublic),
                    subtitle: Text(_public ? l10n.channelPublicHint : l10n.channelPrivateHint),
                    value: _public,
                    onChanged: (v) => setState(() => _public = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom of a channel for subscribers: who posts, and mute.
class ChannelReadOnlyBar extends ConsumerWidget {
  const ChannelReadOnlyBar({super.key, required this.conversation});
  final ChatConversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final conv = conversation;
    Future<void> toggle() async {
      final messenger = ScaffoldMessenger.of(context);
      final repo = ref.read(chatRepositoryProvider);
      try {
        if (conv.isMuted) {
          await repo.patchChat(conv.id, unmute: true);
        } else {
          await repo.patchChat(conv.id, mutedUntil: DateTime.now().add(const Duration(days: 3650)));
        }
      } on AppException catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(broadcastErrorText(l10n, e))));
      }
    }

    return Material(
      key: const Key('channel_read_only_bar'),
      color: t.surface,
      child: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: t.divider, width: t.borderWidth))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.sm, Space.xs),
            child: Row(
              children: [
                Icon(LucideIcons.megaphone, size: 16, color: t.textTertiary),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    l10n.channelReadOnly,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textTertiary),
                  ),
                ),
                TextButton.icon(
                  key: const Key('channel_mute_toggle'),
                  icon: Icon(conv.isMuted ? LucideIcons.bell : LucideIcons.bellOff, size: 18),
                  label: Text(conv.isMuted ? l10n.chatUnmute : l10n.chatMute),
                  onPressed: toggle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Channel part of the info screen: subscribers, visibility, admins,
/// unsubscribe.
class ChannelInfoSection extends ConsumerStatefulWidget {
  const ChannelInfoSection({super.key, required this.conversation});
  final ChatConversation conversation;

  @override
  ConsumerState<ChannelInfoSection> createState() => _ChannelInfoSectionState();
}

class _ChannelInfoSectionState extends ConsumerState<ChannelInfoSection> {
  bool? _public;
  bool? _comments;
  bool _busy = false;

  /// «Комментарии» (owner / admins): `PATCH /channels/{id}`.
  Future<void> _setComments(bool value) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _comments = value;
      _busy = true;
    });
    try {
      final conv = await ref
          .read(chatCommentsApiProvider)
          .setCommentsEnabled(widget.conversation.id, value);
      await ref.read(chatRepositoryProvider).putConversationLocal(conv);
    } on AppException catch (e) {
      if (mounted) setState(() => _comments = !value);
      messenger.showSnackBar(SnackBar(content: Text(broadcastErrorText(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setPublic(bool value) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _public = value;
      _busy = true;
    });
    try {
      final conv = await ref.read(chatBroadcastApiProvider).setChannelPublic(widget.conversation.id, value);
      await ref.read(chatRepositoryProvider).cache.putConversation(conv);
    } on AppException catch (e) {
      if (mounted) setState(() => _public = !value);
      messenger.showSnackBar(SnackBar(content: Text(broadcastErrorText(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unsubscribe() async {
    final l10n = context.l10n;
    final conv = widget.conversation;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.channelUnsubscribeConfirm(conv.title)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            key: const Key('channel_unsubscribe_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.channelUnsubscribe),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.maybeOf(context);
    try {
      await ref.read(chatBroadcastApiProvider).unsubscribe(conv.id);
      await ref.read(chatRepositoryProvider).cache.removeConversation(conv.id);
      unawaited(ref.read(conversationsProvider.notifier).refresh());
      router?.go(Routes.chat);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(broadcastErrorText(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final conv = widget.conversation;
    final selfId = ref.read(chatRepositoryProvider).selfId;
    final public = _public ?? conv.isPublic;
    String role(String r) => switch (r) {
      'owner' => l10n.chatRoleOwner,
      'admin' => l10n.chatRoleAdmin,
      _ => l10n.chatRoleMember,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        ListTile(
          key: const Key('channel_subscribers'),
          leading: const Icon(LucideIcons.users),
          title: Text(l10n.channelSubscribers),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${conv.memberCount}', style: TextStyle(color: t.textTertiary)),
              if (conv.isAdmin) Icon(LucideIcons.chevronRight, color: t.textMuted),
            ],
          ),
          onTap: conv.isAdmin
              ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => ChannelSubscribersScreen(conversationId: conv.id)),
                )
              : null,
        ),
        if (conv.isAdmin)
          SwitchListTile(
            key: const Key('channel_public_switch'),
            secondary: Icon(public ? LucideIcons.globe : LucideIcons.lock),
            title: Text(l10n.channelPublic),
            subtitle: Text(public ? l10n.channelPublicHint : l10n.channelPrivateHint),
            value: public,
            onChanged: _busy ? null : _setPublic,
          ),
        if (conv.isAdmin)
          SwitchListTile(
            key: const Key('channel_comments_switch'),
            secondary: const Icon(LucideIcons.messageSquare),
            title: Text(l10n.channelComments),
            subtitle: Text(l10n.channelCommentsHint),
            value: _comments ?? conv.commentsEnabled,
            onChanged: _busy ? null : _setComments,
          ),
        const Divider(height: 1),
        ListTile(title: Text(l10n.channelAdmins, style: Theme.of(context).textTheme.titleSmall)),
        for (final m in conv.members)
          ListTile(
            key: ValueKey('channel_admin_${m.userId}'),
            leading: InitialsAvatar(label: m.label, colorKey: m.userId),
            title: Text(
              m.userId == selfId ? '${m.label} (${l10n.chatYou})' : m.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              [
                if (watchUserStatus(ref, m.userId, m.status) case final status?)
                  ChatStatusFormat.line(context, status, withUntil: false),
                role(m.role),
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.textMuted),
            ),
          ),
        if (conv.myRole != 'owner') ...[
          const Divider(height: 1),
          ListTile(
            key: const Key('channel_unsubscribe'),
            leading: Icon(LucideIcons.logOut, color: t.danger),
            title: Text(l10n.channelUnsubscribe, style: TextStyle(color: t.danger)),
            onTap: _unsubscribe,
          ),
        ],
      ],
    );
  }
}
