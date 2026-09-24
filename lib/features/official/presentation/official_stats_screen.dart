import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/error_text.dart';
import '../../../shared/widgets/state_view.dart';
import '../data/official_models.dart';
import 'official_providers.dart';
import 'official_widgets.dart';

/// Statistics of a sent message (`/official/:id/stats`): recipients, read and
/// acknowledged counts. The API returns aggregates only — no per-recipient
/// list — and answers all zeros for a message of another sender.
class OfficialStatsScreen extends ConsumerWidget {
  const OfficialStatsScreen({super.key, required this.messageId, this.sent});
  final String messageId;

  /// Local record (title, acknowledgement flag) when opened from «Отправленные».
  final SentOfficial? sent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(officialStatsProvider(messageId));
    Future<void> reload() async {
      ref.invalidate(officialStatsProvider(messageId));
      await ref
          .read(officialStatsProvider(messageId).future)
          .catchError(
            (_) => const OfficialStats(
              sent: 0,
              delivered: 0,
              read: 0,
              acknowledged: 0,
            ),
          );
    }

    final Widget body;
    if (async.hasValue) {
      body = RefreshIndicator(
        onRefresh: reload,
        child: _StatsView(stats: async.value!, sent: sent),
      );
    } else if (async.hasError) {
      final e = async.error!;
      final text = officialErrorText(l10n, e);
      body = ErrorText.isOffline(e)
          ? StateView.offline(message: text, onRetry: reload)
          : StateView.error(message: text, onRetry: reload);
    } else {
      body = const StateView.loading();
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.officialStatsTitle)),
      body: body,
    );
  }
}

class _StatsView extends StatelessWidget {
  const _StatsView({required this.stats, this.sent});
  final OfficialStats stats;
  final SentOfficial? sent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final showAck = sent?.requiresAcknowledgement ?? true;

    Widget row(Key key, IconData icon, String label, int value) {
      final ratio = stats.sent == 0
          ? 0.0
          : (value / stats.sent).clamp(0.0, 1.0);
      return Padding(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: t.textSecondary),
                const SizedBox(width: Space.sm),
                Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
                Text(
                  '$value / ${stats.sent}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Space.md),
      children: [
        if (sent != null) ...[
          Text(sent!.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.md),
        ],
        if (stats.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Text(
              l10n.officialStatsNoData,
              key: const Key('official_stats_empty'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: t.textSecondary,
              ),
            ),
          ),
        ListTile(
          key: const Key('official_stats_recipients'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.users),
          title: Text(l10n.officialStatsRecipients),
          trailing: Text(
            '${stats.sent}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        row(
          const Key('official_stats_read'),
          LucideIcons.eye,
          l10n.officialStatsRead,
          stats.read,
        ),
        if (showAck)
          row(
            const Key('official_stats_ack'),
            LucideIcons.circleCheck,
            l10n.officialStatsAcknowledged,
            stats.acknowledged,
          ),
        const SizedBox(height: Space.md),
        Text(
          l10n.officialStatsAggregateNote,
          style: theme.textTheme.bodySmall?.copyWith(color: t.textMuted),
        ),
      ],
    );
  }
}
