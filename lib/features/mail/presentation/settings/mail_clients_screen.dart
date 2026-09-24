import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/utils/error_text.dart';
import '../../../../shared/widgets/ds/x_badge.dart';
import '../../../../shared/widgets/state_view.dart';
import '../mail_providers.dart';

/// The web settings "Clients" section: IMAP/SMTP host, port and encryption
/// from `GET /mail/client-config`, plus the username (mailbox address).
class MailClientsScreen extends ConsumerWidget {
  const MailClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final config = ref.watch(mailClientConfigProvider);
    final mailbox = ref.watch(mailSummaryProvider).summary?.mailboxAddress ?? ref.watch(currentUserProvider)?.email ?? '';

    Widget row(String label, String value, {String? extra}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.smd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SelectableText(value, style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontFamily: 'JetBrains Mono')),
              ),
              if (extra != null) ...[
                const SizedBox(width: Space.sm),
                Text(extra, style: Theme.of(context).textTheme.labelSmall),
              ],
              IconButton(
                tooltip: l10n.mailCopyAddress,
                icon: const Icon(LucideIcons.copy, size: 16),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: value));
                  messenger.showSnackBar(SnackBar(content: Text(l10n.mailActionDone)));
                },
              ),
            ],
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mailSettingsClients)),
      body: config.when(
        loading: () => const StateView.loading(),
        error: (e, _) => StateView.error(message: ErrorText.describe(l10n, e), onRetry: () => ref.invalidate(mailClientConfigProvider)),
        data: (c) => ListView(
          padding: const EdgeInsets.all(Space.md),
          children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(t.radiusLg),
                border: Border.all(color: t.border, width: t.borderWidth),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: Space.mlg, vertical: Space.smd),
                    decoration: BoxDecoration(color: t.surfaceSubtle, border: Border(bottom: BorderSide(color: t.border, width: t.borderWidth))),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.mailSettingsClients, style: Theme.of(context).textTheme.titleSmall),
                              Text(l10n.mailClientsHint, style: Theme.of(context).textTheme.labelSmall),
                            ],
                          ),
                        ),
                        XBadge(c.enabled ? l10n.mailClientsEnabled : l10n.mailClientsDisabledBadge, tone: c.enabled ? BadgeTone.success : BadgeTone.warning),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.mlg, vertical: Space.sm),
                    child: !c.enabled || c.imap == null || c.smtp == null
                        ? Padding(padding: const EdgeInsets.symmetric(vertical: Space.smd), child: Text(l10n.mailClientsDisabled, style: Theme.of(context).textTheme.bodySmall))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              row(l10n.mailClientsIncoming, '${c.imap!.host}:${c.imap!.port}', extra: c.imap!.encryption),
                              Divider(color: t.divider),
                              row(l10n.mailClientsOutgoing, '${c.smtp!.host}:${c.smtp!.port}', extra: c.smtp!.encryption),
                              Divider(color: t.divider),
                              row(l10n.mailClientsUsername, mailbox),
                              if (c.loginHint.isNotEmpty)
                                Padding(padding: const EdgeInsets.only(top: Space.xs), child: Text(c.loginHint, style: Theme.of(context).textTheme.labelSmall)),
                            ],
                          ),
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
