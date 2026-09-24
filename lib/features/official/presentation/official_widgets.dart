import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/error_text.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/widgets/ds/sidebar_nav_item.dart';
import '../../../shared/widgets/ds/x_badge.dart';
import '../data/official_models.dart';
import 'official_providers.dart';

/// User-facing text for failures of the official endpoints (their own codes
/// first, then the shared mapping).
String officialErrorText(AppLocalizations l10n, Object error) {
  if (error is UnexpectedApiException && error.statusCode == 200) {
    return l10n.officialErrNotSent;
  }
  if (error is ApiException) {
    switch (error.code) {
      case 'OFFICIAL_NOT_FOUND':
        return l10n.officialErrNotFound;
      case 'INVALID_OFFICIAL':
        return l10n.officialErrInvalid;
      case 'INVALID_RECIPIENTS':
        return l10n.officialErrInvalidRecipients;
      case 'NO_RECIPIENTS':
        return l10n.officialErrNoRecipients;
      case 'FORBIDDEN':
        return l10n.officialErrForbidden;
    }
  }
  return ErrorText.describe(l10n, error);
}

/// «Требует ознакомления» / «Ознакомлен(а)» marker.
class OfficialAckChip extends StatelessWidget {
  const OfficialAckChip({super.key, required this.message});
  final OfficialMessage message;

  @override
  Widget build(BuildContext context) {
    if (!message.requiresAcknowledgement) return const SizedBox.shrink();
    final t = context.tokens;
    final l10n = context.l10n;
    final done = message.isAcknowledged;
    final fg = done ? t.success : t.warning;
    final bg = done ? t.successSoft : t.warningSoft;
    return Container(
      key: Key(done ? 'official_ack_chip_done' : 'official_ack_chip_required'),
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(t.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? LucideIcons.circleCheck : LucideIcons.fileSignature,
            size: 12,
            color: fg,
          ),
          const SizedBox(width: Space.xs),
          Text(
            done ? l10n.officialAcknowledged : l10n.officialRequiresAck,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

/// One row of the received list: megaphone, title, sender · preview, date,
/// unread dot and the acknowledgement marker.
class OfficialTile extends StatelessWidget {
  const OfficialTile({super.key, required this.message, required this.onTap});
  final OfficialMessage message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final t = context.tokens;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final unread = !m.isRead;
    final preview = m.body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: unread ? t.brand : t.textMuted,
        child: const Icon(LucideIcons.megaphone),
      ),
      title: Text(
        m.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [m.senderName, preview].where((s) => s.isNotEmpty).join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (m.requiresAcknowledgement) ...[
            const SizedBox(height: Space.xs),
            OfficialAckChip(message: m),
          ],
        ],
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            FormatUtils.listDate(m.createdAt, locale),
            style: theme.textTheme.bodySmall?.copyWith(color: t.textMuted),
          ),
          const SizedBox(height: Space.xs),
          if (unread)
            Semantics(
              label: context.l10n.officialUnread,
              child: Container(
                key: const Key('official_unread_dot'),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: t.unreadBadge,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Drawer entry («Рабочее пространство»); nothing without `official.read`.
class OfficialNavItem extends ConsumerWidget {
  const OfficialNavItem({super.key, required this.onTap, this.active = false, this.round = false, this.iconOnly = false});
  final VoidCallback onTap;

  /// Desktop sidebar (SidebarNavItem.round / .iconOnly, current page).
  final bool active;
  final bool round;
  final bool iconOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(officialEnabledProvider)) return const SizedBox.shrink();
    final unread = ref.watch(officialUnreadBadgeProvider);
    return SidebarNavItem(
      semanticKey: const Key('sidebar_official'),
      icon: LucideIcons.megaphone,
      label: context.l10n.officialTitle,
      active: active,
      onTap: onTap,
      badge: unread > 0 ? CountPill(unread) : null,
      round: round,
      iconOnly: iconOnly,
    );
  }
}
