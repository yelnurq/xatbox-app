import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/initials_avatar.dart';
import '../../../../shared/widgets/state_view.dart';
import '../../data/chat_models.dart';
import '../broadcast/broadcast_format.dart';
import '../broadcast/broadcast_providers.dart';
import '../chat_providers.dart';
import '../new_chat_screen.dart';
import '../status/chat_status_providers.dart';

/// Subscribers of a channel (owner/admins): search, make admin, remove, add.
class ChannelSubscribersScreen extends ConsumerStatefulWidget {
  const ChannelSubscribersScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<ChannelSubscribersScreen> createState() => _ChannelSubscribersScreenState();
}

class _ChannelSubscribersScreenState extends ConsumerState<ChannelSubscribersScreen> {
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _act(ChatMember m, String action) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(chatRepositoryProvider);
    final id = widget.conversationId;
    try {
      switch (action) {
        case 'admin':
          await repo.setRole(id, m.userId, 'admin');
        case 'member':
          await repo.setRole(id, m.userId, 'member');
        case 'remove':
          await repo.removeMember(id, m.userId);
      }
      ref.invalidate(channelSubscribersProvider);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(broadcastErrorText(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final id = widget.conversationId;
    final myRole = ref.watch(conversationProvider(id).select((s) => s.conversation?.myRole ?? 'member'));
    final selfId = ref.read(chatRepositoryProvider).selfId;
    final state = ref.watch(channelSubscribersProvider((id: id, q: _query)));
    String role(String r) => switch (r) {
      'owner' => l10n.chatRoleOwner,
      'admin' => l10n.chatRoleAdmin,
      _ => l10n.chatRoleMember,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.channelSubscribers)),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_channel_add_subscriber',
        key: const Key('channel_add_subscriber'),
        tooltip: l10n.channelAddSubscriber,
        onPressed: () async {
          await openNewChat(context, addToConversationId: id);
          ref.invalidate(channelSubscribersProvider);
        },
        child: const Icon(LucideIcons.userPlus),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.xs),
            child: TextField(
              key: const Key('channel_subscriber_search'),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  if (mounted) setState(() => _query = v.trim());
                });
              },
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.chatSearchUsers,
                prefixIcon: const Icon(LucideIcons.search, size: 18),
              ),
            ),
          ),
          Expanded(
            child: state.when(
              loading: () => const StateView.loading(),
              error: (e, _) => Center(child: Text(broadcastErrorText(l10n, e))),
              data: (res) => ListView.builder(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: res.subscribers.length,
                itemBuilder: (context, i) {
                  final m = res.subscribers[i];
                  final canManage = m.userId != selfId &&
                      m.role != 'owner' &&
                      (myRole == 'owner' || (myRole == 'admin' && m.role == 'member'));
                  return ListTile(
                    key: ValueKey('subscriber_${m.userId}'),
                    leading: InitialsAvatar(label: m.label, colorKey: m.userId),
                    title: Text(
                      m.userId == selfId ? '${m.label} (${l10n.chatYou})' : m.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Own consumer: rows are built lazily, outside build().
                    subtitle: Consumer(
                      builder: (context, ref, _) {
                        final status = watchUserStatus(ref, m.userId, m.status);
                        return Text(
                          [
                            if (status != null)
                              ChatStatusFormat.line(context, status, withUntil: false),
                            if (m.email.isNotEmpty) m.email,
                            role(m.role),
                          ].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: t.textMuted),
                        );
                      },
                    ),
                    trailing: !canManage
                        ? null
                        : PopupMenuButton<String>(
                            key: ValueKey('subscriber_menu_${m.userId}'),
                            icon: Icon(LucideIcons.ellipsisVertical, color: t.textTertiary),
                            onSelected: (a) => _act(m, a),
                            itemBuilder: (_) => [
                              if (myRole == 'owner' && m.role != 'admin')
                                PopupMenuItem(value: 'admin', child: Text(l10n.chatMakeAdmin)),
                              if (myRole == 'owner' && m.role == 'admin')
                                PopupMenuItem(value: 'member', child: Text(l10n.chatRemoveAdmin)),
                              PopupMenuItem(
                                value: 'remove',
                                child: Text(l10n.chatRemoveMember, style: TextStyle(color: t.danger)),
                              ),
                            ],
                          ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
