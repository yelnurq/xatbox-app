import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/localization/localization.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/error_text.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/widgets/state_view.dart';
import '../data/official_models.dart';
import 'official_providers.dart';
import 'official_widgets.dart';

/// «Официальные сообщения» (`/official`): messages addressed to the user,
/// newest first, pull to refresh, cached for offline reading. Senders also
/// get «Отправленные» (sent from this device, with statistics) and a create
/// button.
class OfficialListScreen extends ConsumerStatefulWidget {
  const OfficialListScreen({super.key});

  @override
  ConsumerState<OfficialListScreen> createState() => _OfficialListScreenState();
}

class _OfficialListScreenState extends ConsumerState<OfficialListScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the screen always shows fresh data (the badge may be stale).
    Future.microtask(() {
      if (!mounted) return;
      final s = ref.read(officialProvider);
      if (s.loaded && !s.loading) {
        unawaited(ref.read(officialProvider.notifier).refresh());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = ref.watch(officialEnabledProvider);
    final rights = ref.watch(officialSendRightsProvider);

    if (!enabled) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.officialTitle)),
        body: StateView.empty(
          title: l10n.officialNoAccess,
          icon: LucideIcons.lock,
        ),
      );
    }

    final fab = rights.any
        ? FloatingActionButton.extended(
            key: const Key('official_create'),
            onPressed: () => context.push(Routes.officialNew),
            icon: const Icon(LucideIcons.pencil),
            label: Text(l10n.officialNew),
          )
        : null;

    if (!rights.any) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.officialTitle)),
        body: const _ReceivedList(),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.officialTitle),
          bottom: TabBar(
            tabs: [
              Tab(
                key: const Key('official_tab_received'),
                text: l10n.officialReceivedTab,
              ),
              Tab(
                key: const Key('official_tab_sent'),
                text: l10n.officialSentTab,
              ),
            ],
          ),
        ),
        floatingActionButton: fab,
        body: const TabBarView(children: [_ReceivedList(), _SentList()]),
      ),
    );
  }
}

class _ReceivedList extends ConsumerWidget {
  const _ReceivedList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(officialProvider);
    final notifier = ref.read(officialProvider.notifier);

    if (!state.loaded && state.messages.isEmpty) {
      return const StateView.loading();
    }
    if (state.messages.isEmpty && state.error != null) {
      final text = officialErrorText(l10n, state.error!);
      return ErrorText.isOffline(state.error)
          ? StateView.offline(message: text, onRetry: notifier.refresh)
          : StateView.error(message: text, onRetry: notifier.refresh);
    }
    final messages = state.messages;
    return Column(
      children: [
        if (state.error != null)
          OfflineBanner(
            text: ErrorText.isOffline(state.error)
                ? l10n.offlineBanner
                : officialErrorText(l10n, state.error!),
            onRetry: notifier.refresh,
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: notifier.refresh,
            child: messages.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: 320,
                        child: StateView.empty(
                          title: l10n.officialEmpty,
                          icon: LucideIcons.megaphone,
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    key: const Key('official_list'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: messages.length + 1,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      if (i == messages.length) {
                        return messages.length >= OfficialMessage.maxItems
                            ? Padding(
                                padding: const EdgeInsets.all(Space.md),
                                child: Text(
                                  l10n.officialLimitNote(
                                    OfficialMessage.maxItems,
                                  ),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: context.tokens.textMuted,
                                      ),
                                ),
                              )
                            : const SizedBox(height: Space.lg);
                      }
                      final m = messages[i];
                      return OfficialTile(
                        key: ValueKey('official_${m.id}'),
                        message: m,
                        onTap: () =>
                            context.push(Routes.officialMessagePath(m.id)),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _SentList extends ConsumerWidget {
  const _SentList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sent = ref.watch(officialSentProvider);
    final locale = Localizations.localeOf(context).toString();
    final items = sent.value ?? const <SentOfficial>[];
    if (sent.isLoading && items.isEmpty) return const StateView.loading();
    if (items.isEmpty) {
      return StateView.empty(
        title: l10n.officialSentEmpty,
        icon: LucideIcons.send,
      );
    }
    return ListView.separated(
      key: const Key('official_sent_list'),
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final s = items[i];
        return ListTile(
          key: ValueKey('official_sent_${s.id}'),
          leading: const CircleAvatar(child: Icon(LucideIcons.chartBar)),
          title: Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [
              l10n.officialRecipientCount(s.recipientCount),
              if (s.requiresAcknowledgement) l10n.officialRequiresAck,
            ].join(' · '),
          ),
          trailing: Text(
            FormatUtils.listDate(s.sentAt, locale),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.tokens.textMuted),
          ),
          onTap: () => context.push(Routes.officialStatsPath(s.id), extra: s),
        );
      },
    );
  }
}
