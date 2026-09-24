import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/error_text.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/widgets/state_view.dart';
import '../data/mail_message_extras.dart';
import 'mail_providers.dart';
import '../../../shared/widgets/app_sheet.dart';

/// Delivery timeline of a sent message (`GET /mail/messages/{id}/events`).
Future<void> showDeliverySheet(BuildContext context, String messageId) =>
    showAppSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (context, scroll) =>
            _DeliveryBody(messageId: messageId, scroll: scroll),
      ),
    );

final _deliveryProvider = FutureProvider.autoDispose
    .family<MailDeliveryReport, String>(
      (ref, id) => ref.watch(mailApiProvider).messageEvents(id),
    );

class _DeliveryBody extends ConsumerWidget {
  const _DeliveryBody({required this.messageId, required this.scroll});
  final String messageId;
  final ScrollController scroll;

  static String stateText(AppLocalizations l10n, String s) => switch (s) {
    'accepted' => l10n.mailDeliveryStateAccepted,
    'processing' => l10n.mailDeliveryStateProcessing,
    'delivered' => l10n.mailDeliveryStateDelivered,
    'partially_delivered' => l10n.mailDeliveryStatePartiallyDelivered,
    'failed' => l10n.mailDeliveryStateFailed,
    'quarantined' => l10n.mailDeliveryStateQuarantined,
    'pending' => l10n.mailDeliveryStatePending,
    'relayed' => l10n.mailDeliveryStateRelayed,
    'draft' => l10n.mailDeliveryStateDraft,
    _ => s,
  };

  static String eventText(AppLocalizations l10n, String type) =>
      switch (type) {
        'email.accepted' => l10n.mailDeliveryEventAccepted,
        'email.scanned' => l10n.mailDeliveryEventScanned,
        'email.delivered_local' => l10n.mailDeliveryEventDeliveredLocal,
        'email.relayed' => l10n.mailDeliveryEventRelayed,
        'email.failed' => l10n.mailDeliveryEventFailed,
        _ => type,
      };

  static IconData stateIcon(String s) => switch (s) {
    'delivered' || 'relayed' => LucideIcons.circleCheck,
    'failed' => LucideIcons.circleAlert,
    'quarantined' => LucideIcons.shieldAlert,
    'partially_delivered' => LucideIcons.listChecks,
    _ => LucideIcons.clock,
  };

  static Color stateColor(XatBoxTokens t, String s) => switch (s) {
    'delivered' || 'relayed' => t.success,
    'failed' => t.danger,
    'quarantined' || 'partially_delivered' => t.warning,
    _ => t.textMuted,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final async = ref.watch(_deliveryProvider(messageId));

    Widget header() => Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.sm),
      child: Text(l10n.mailDeliveryStatus, style: theme.textTheme.titleMedium),
    );

    return async.when(
      loading: () => ListView(
        controller: scroll,
        children: [
          header(),
          const Padding(
            padding: EdgeInsets.all(Space.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      error: (e, _) => ListView(
        controller: scroll,
        children: [
          header(),
          ErrorText.isOffline(e)
              ? StateView.offline(
                  message: ErrorText.describe(l10n, e),
                  onRetry: () => ref.invalidate(_deliveryProvider(messageId)),
                )
              : StateView.error(
                  message: ErrorText.describe(l10n, e),
                  onRetry: () => ref.invalidate(_deliveryProvider(messageId)),
                ),
        ],
      ),
      data: (report) => ListView(
        key: const Key('delivery_sheet'),
        controller: scroll,
        padding: const EdgeInsets.only(bottom: Space.lg),
        children: [
          header(),
          if (report.isEmpty)
            StateView.empty(
              title: l10n.mailDeliveryEmpty,
              icon: LucideIcons.truck,
            )
          else ...[
            if (report.status.isNotEmpty)
              ListTile(
                leading: Icon(
                  stateIcon(report.status),
                  color: stateColor(tokens, report.status),
                ),
                title: Text(
                  stateText(l10n, report.status),
                  style: theme.textTheme.titleSmall,
                ),
              ),
            if (report.recipients.isNotEmpty) ...[
              _Section(l10n.mailDeliveryRecipients),
              for (final r in report.recipients)
                ListTile(
                  dense: true,
                  leading: Icon(
                    stateIcon(r.status),
                    color: stateColor(tokens, r.status),
                  ),
                  title: Text(r.address),
                  subtitle: Text(
                    [
                      stateText(l10n, r.status),
                      if (r.error != null && r.error!.isNotEmpty) r.error!,
                    ].join(' · '),
                  ),
                ),
            ],
            if (report.events.isNotEmpty) ...[
              _Section(l10n.mailDeliveryHistory),
              for (var i = 0; i < report.events.length; i++)
                ListTile(
                  dense: true,
                  leading: Icon(
                    i == report.events.length - 1
                        ? LucideIcons.circleDot
                        : LucideIcons.circle,
                    size: 18,
                    color: tokens.brand,
                  ),
                  title: Text(eventText(l10n, report.events[i].type)),
                  trailing: Text(
                    FormatUtils.fullDate(report.events[i].createdAt, locale),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.textMuted,
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xs),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: context.tokens.textMuted),
    ),
  );
}
