import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/state_view.dart';
import '../../data/chat_broadcast.dart';
import '../broadcast/broadcast_format.dart';
import '../broadcast/broadcast_providers.dart';
import '../chat_providers.dart';
import 'channel_widgets.dart';

Future<void> openChannelDiscover(BuildContext context) => Navigator.of(context).push(
  MaterialPageRoute<void>(builder: (_) => const ChannelDiscoverScreen()),
);

/// «Каналы организации»: public channels of the tenant with search,
/// subscribe / open, and «Создать канал».
class ChannelDiscoverScreen extends ConsumerStatefulWidget {
  const ChannelDiscoverScreen({super.key});

  @override
  ConsumerState<ChannelDiscoverScreen> createState() => _ChannelDiscoverScreenState();
}

class _ChannelDiscoverScreenState extends ConsumerState<ChannelDiscoverScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  final Map<String, ChatChannelSummary> _overrides = {};
  final Set<String> _busy = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  Future<void> _subscribe(ChatChannelSummary ch) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(ch.id));
    try {
      await ref.read(chatBroadcastApiProvider).subscribe(ch.id);
      if (!mounted) return;
      setState(() => _overrides[ch.id] = ch.copyWith(subscribed: true, subscriberCount: ch.subscriberCount + 1));
      unawaited(ref.read(conversationsProvider.notifier).refresh());
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(broadcastErrorText(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy.remove(ch.id));
    }
  }

  void _openChat(String id) {
    final router = GoRouter.maybeOf(context);
    if (router != null) unawaited(router.push(Routes.chatConversationPath(id)));
  }

  Future<void> _create() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final draft = await ChannelCreateSheet.show(context);
    if (draft == null || !mounted) return;
    try {
      final conv = await ref
          .read(chatBroadcastApiProvider)
          .createChannel(title: draft.title, description: draft.description, isPublic: draft.isPublic);
      if (!mounted) return;
      unawaited(ref.read(conversationsProvider.notifier).refresh());
      ref.invalidate(channelDiscoverProvider);
      _openChat(conv.id);
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.statusCode == 403 ? l10n.channelNoPermission : broadcastErrorText(l10n, e))),
      );
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(broadcastErrorText(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final state = ref.watch(channelDiscoverProvider(_query));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.channelsDiscoverTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.sm),
            child: TextField(
              key: const Key('channel_search'),
              controller: _search,
              onChanged: _onSearch,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.channelsSearchHint,
                prefixIcon: const Icon(LucideIcons.search, size: 18),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_channel_create',
        key: const Key('channel_create_fab'),
        onPressed: _create,
        icon: const Icon(LucideIcons.megaphone),
        label: Text(l10n.channelCreate),
      ),
      body: state.when(
        loading: () => const StateView.loading(),
        error: (e, _) => ChannelEmptyState(icon: LucideIcons.cloudOff, text: broadcastErrorText(l10n, e)),
        data: (res) {
          final list = [for (final c in res.channels) _overrides[c.id] ?? c];
          if (list.isEmpty) {
            return ChannelEmptyState(
              icon: LucideIcons.megaphone,
              text: _query.isEmpty ? l10n.channelsEmpty : l10n.channelsNothingFound,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(channelDiscoverProvider(_query)),
            child: ListView.separated(
              key: const Key('channel_list'),
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: list.length,
              separatorBuilder: (_, _) => Divider(height: 1, indent: 76, color: t.divider),
              itemBuilder: (context, i) => _ChannelTile(
                channel: list[i],
                busy: _busy.contains(list[i].id),
                onSubscribe: () => _subscribe(list[i]),
                onOpen: () => _openChat(list[i].id),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.busy,
    required this.onSubscribe,
    required this.onOpen,
  });
  final ChatChannelSummary channel;
  final bool busy;
  final VoidCallback onSubscribe;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final ch = channel;
    final details = ch.description.isEmpty
        ? l10n.channelSubscribersCount(ch.subscriberCount)
        : '${l10n.channelSubscribersCount(ch.subscriberCount)} · ${ch.description}';
    return InkWell(
      key: ValueKey('channel_${ch.id}'),
      onTap: ch.subscribed ? onOpen : null,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: Space.md, vertical: t.display.rowPaddingY),
        child: Row(
          children: [
            ChannelAvatar(id: ch.id, radius: 24),
            const SizedBox(width: Space.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ch.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: t.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: t.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            if (ch.subscribed)
              OutlinedButton(
                key: ValueKey('channel_open_${ch.id}'),
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: onOpen,
                child: Text(l10n.channelSubscribed),
              )
            else
              FilledButton.tonal(
                key: ValueKey('channel_subscribe_${ch.id}'),
                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: busy ? null : onSubscribe,
                child: Text(l10n.channelSubscribe),
              ),
          ],
        ),
      ),
    );
  }
}
