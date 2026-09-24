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

/// One official message (`/official/:id`). Marks it read on open; when the
/// sender asked for acknowledgement a prominent «Ознакомлен(а)» button is
/// shown, replaced by a confirmation once the server accepted it. The body
/// is plain text (selectable, never parsed as HTML).
class OfficialDetailScreen extends ConsumerStatefulWidget {
  const OfficialDetailScreen({super.key, required this.messageId});
  final String messageId;

  @override
  ConsumerState<OfficialDetailScreen> createState() =>
      _OfficialDetailScreenState();
}

class _OfficialDetailScreenState extends ConsumerState<OfficialDetailScreen> {
  bool _markRequested = false;
  bool _refreshRequested = false;

  void _ensureRead(OfficialMessage? message, OfficialState state) {
    if (message != null) {
      if (_markRequested || message.isRead) return;
      _markRequested = true;
      Future.microtask(() {
        if (mounted) {
          unawaited(ref.read(officialProvider.notifier).markRead(message.id));
        }
      });
      return;
    }
    // Opened from a push / deep link before the list knew this message.
    if (!_refreshRequested && state.loaded && !state.loading) {
      _refreshRequested = true;
      Future.microtask(() {
        if (mounted) unawaited(ref.read(officialProvider.notifier).refresh());
      });
    }
  }

  Future<void> _acknowledge() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final error = await ref
        .read(officialProvider.notifier)
        .acknowledge(widget.messageId);
    if (error != null && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(officialErrorText(l10n, error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = ref.watch(officialEnabledProvider);
    final state = ref.watch(officialProvider);
    final message = state.byId(widget.messageId);
    final sentIds = {
      for (final s
          in ref.watch(officialSentProvider).value ?? const <SentOfficial>[])
        s.id,
    };
    if (enabled) _ensureRead(message, state);

    final Widget body;
    if (!enabled) {
      body = StateView.empty(
        title: l10n.officialNoAccess,
        icon: LucideIcons.lock,
      );
    } else if (message == null) {
      final pending = !state.loaded || state.loading || !_refreshRequested;
      if (pending) {
        body = const StateView.loading();
      } else if (state.error != null) {
        body = StateView.error(
          message: officialErrorText(l10n, state.error!),
          onRetry: ref.read(officialProvider.notifier).refresh,
        );
      } else {
        body = StateView.empty(
          title: l10n.officialNotFound,
          icon: LucideIcons.searchX,
        );
      }
    } else {
      body = _Body(
        message: message,
        acknowledging: state.acknowledging.contains(message.id),
        onAcknowledge: _acknowledge,
        offline: state.fromCache && ErrorText.isOffline(state.error),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.officialTitle),
        actions: [
          if (sentIds.contains(widget.messageId))
            IconButton(
              key: const Key('official_open_stats'),
              tooltip: l10n.officialStatsTitle,
              icon: const Icon(LucideIcons.chartBar),
              onPressed: () =>
                  context.push(Routes.officialStatsPath(widget.messageId)),
            ),
        ],
      ),
      body: body,
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.message,
    required this.acknowledging,
    required this.onAcknowledge,
    required this.offline,
  });

  final OfficialMessage message;
  final bool acknowledging;
  final VoidCallback onAcknowledge;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final m = message;

    return Column(
      children: [
        if (offline) OfflineBanner(text: l10n.offlineBanner),
        Expanded(
          child: ListView(
            key: const Key('official_detail'),
            padding: const EdgeInsets.all(Space.md),
            children: [
              if (m.requiresAcknowledgement) ...[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OfficialAckChip(message: m),
                ),
                const SizedBox(height: Space.sm),
              ],
              SelectableText(
                m.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  Icon(LucideIcons.userRound, size: 16, color: t.textMuted),
                  const SizedBox(width: Space.xs),
                  Expanded(
                    child: Text(
                      m.senderName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: t.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    FormatUtils.fullDate(m.createdAt, locale),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: t.textMuted,
                    ),
                  ),
                ],
              ),
              const Divider(height: Space.lg * 2),
              // Plain text by contract: no HTML/markdown interpretation.
              SelectableText(
                m.body,
                key: const Key('official_body'),
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        if (m.requiresAcknowledgement)
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: t.divider, width: t.borderWidth),
                ),
              ),
              padding: const EdgeInsets.all(Space.md),
              child: m.isAcknowledged
                  ? _AcknowledgedNote(message: m)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.officialAckHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: t.textSecondary,
                          ),
                        ),
                        const SizedBox(height: Space.sm),
                        FilledButton.icon(
                          key: const Key('official_ack_button'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: acknowledging ? null : onAcknowledge,
                          icon: acknowledging
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(LucideIcons.check),
                          label: Text(l10n.officialAcknowledgeButton),
                        ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }
}

class _AcknowledgedNote extends StatelessWidget {
  const _AcknowledgedNote({required this.message});
  final OfficialMessage message;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final locale = Localizations.localeOf(context).toString();
    return Container(
      key: const Key('official_ack_done'),
      padding: const EdgeInsets.all(Space.smd),
      decoration: BoxDecoration(
        color: t.successSoft,
        borderRadius: BorderRadius.circular(t.radiusMd),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.circleCheck, color: t.success),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              context.l10n.officialAcknowledgedAt(
                FormatUtils.fullDate(message.acknowledgedAt, locale),
              ),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: t.success),
            ),
          ),
        ],
      ),
    );
  }
}
