import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/localization/localization.dart';
import '../../core/theme/tokens.dart';

/// Loading / empty / error / offline states (ТЗ п.24.22) in the web's
/// `EmptyState` / `ErrorState` shape: an outline icon in a bordered tile, a
/// short title, at most two lines of hint, one primary + one secondary action.
class StateView extends StatelessWidget {
  const StateView._({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.iconColor,
    this.loading = false,
  });

  const StateView.loading({Key? key}) : this._(icon: LucideIcons.loader, title: '', loading: true);

  const StateView.empty({
    required String title,
    String? subtitle,
    IconData icon = LucideIcons.inbox,
    String? actionLabel,
    VoidCallback? onAction,
  }) : this._(icon: icon, title: title, subtitle: subtitle, actionLabel: actionLabel, onAction: onAction);

  const StateView.error({
    required String message,
    VoidCallback? onRetry,
    String? retryLabel,
    IconData icon = LucideIcons.circleAlert,
  }) : this._(icon: icon, title: message, actionLabel: retryLabel, onAction: onRetry);

  const StateView.offline({
    required String message,
    VoidCallback? onRetry,
    String? retryLabel,
  }) : this._(icon: LucideIcons.wifiOff, title: message, actionLabel: retryLabel, onAction: onRetry);

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Color? iconColor;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)));
    }
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: t.surfaceSubtle,
                  borderRadius: BorderRadius.circular(t.radiusMd),
                  border: Border.all(color: t.border, width: t.borderWidth),
                ),
                child: Icon(icon, size: 22, color: iconColor ?? t.textTertiary),
              ),
              const SizedBox(height: Space.md),
              Text(title, textAlign: TextAlign.center, style: text.titleSmall),
              if (subtitle != null) ...[
                const SizedBox(height: Space.xs),
                Text(subtitle!, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodySmall),
              ],
              if (onAction != null || onSecondary != null) ...[
                const SizedBox(height: Space.md),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    if (onAction != null)
                      FilledButton(onPressed: onAction, child: Text(actionLabel ?? context.l10n.retry)),
                    if (onSecondary != null)
                      OutlinedButton(onPressed: onSecondary, child: Text(secondaryLabel ?? context.l10n.cancel)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin banner shown above lists when data comes from cache / the server is
/// unreachable (`warning-soft` with the warning ink, as web notices).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.text, this.onRetry});
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.warningSoft,
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.divider, width: t.borderWidth))),
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
        child: Row(
          children: [
            Icon(LucideIcons.wifiOff, size: 16, color: t.warning),
            const SizedBox(width: Space.sm),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.warning))),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                // Visually compact, but the hit area is padded to 48×48 on
                // every platform (desktop themes default to shrinkWrap).
                style: TextButton.styleFrom(
                  foregroundColor: t.warning,
                  minimumSize: const Size(0, Space.controlSm),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                child: Text(context.l10n.retry),
              ),
          ],
        ),
      ),
    );
  }
}

/// Inline error message: danger ink on the danger-soft surface (forms, banners).
class ErrorMessage extends StatelessWidget {
  const ErrorMessage(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Space.smd, vertical: 10),
      decoration: BoxDecoration(
        color: t.dangerSoft,
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: Border.all(color: t.danger.withValues(alpha: 0.4), width: t.borderWidth),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.triangleAlert, size: 16, color: t.danger),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.danger))),
        ],
      ),
    );
  }
}
