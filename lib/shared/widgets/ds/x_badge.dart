import 'package:flutter/material.dart';

import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';

/// Badge tones of the web `Badge` (ui.tsx): soft background + darker ink of
/// the same status; never a saturated fill for a plain label.
enum BadgeTone { neutral, info, success, warning, danger, primary }

/// `DESIGN.MD` §8 "Badges и статусы": 20–24px tall, pill or 5px radius,
/// 11–12px text, status carried by text/icon and not by colour alone.
class XBadge extends StatelessWidget {
  const XBadge(this.text, {super.key, this.tone = BadgeTone.neutral, this.icon, this.pill = true, this.small = false});

  final String text;
  final BadgeTone tone;
  final IconData? icon;
  final bool pill;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (bg, fg, border) = switch (tone) {
      BadgeTone.neutral => (t.surfaceSubtle, t.textSecondary, t.border),
      BadgeTone.info => (t.infoSoft, t.info, t.infoSoft),
      BadgeTone.success => (t.successSoft, t.success, t.successSoft),
      BadgeTone.warning => (t.warningSoft, t.warning, t.warningSoft),
      BadgeTone.danger => (t.dangerSoft, t.danger, t.dangerSoft),
      BadgeTone.primary => (t.primarySoft, t.primary, t.primarySoft),
    };
    final style = Theme.of(context).textTheme.labelMedium!.copyWith(
      color: fg,
      fontSize: small ? 10 * t.display.scale : 11 * t.display.scale,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : Space.sm, vertical: small ? 1 : 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(pill ? XatBoxTokens.radiusPill : 5),
        border: Border.all(color: border, width: t.borderWidth),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(child: Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

/// The sidebar's `CountBadge`: unread counts. `accent` = primary-soft pill,
/// `faint` = plain tertiary number (Drafts total). Caps at 999+.
class CountPill extends StatelessWidget {
  const CountPill(
    this.count, {
    super.key,
    this.accent = true,
    this.active = false,
    this.color,
    this.background,
    this.semanticLabel,
  });

  final int count;
  final bool accent;
  final bool active;

  /// Explicit ink / background (folder-coloured pills in the tree).
  final Color? color;
  final Color? background;

  /// Spoken instead of the bare number. When null, an accent pill (an
  /// unread counter) reads «непрочитанных: N»; a faint pill (a plain total)
  /// keeps the number.
  final String? semanticLabel;

  static String format(int count) => count > 999 ? '999+' : '$count';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = color ?? (active ? t.textPrimary : (accent ? t.primary : t.textTertiary));
    final bg = background ?? (active ? t.surface : (accent ? t.primarySoft : Colors.transparent));
    // Null-safe lookup: the pill is also pumped in bare widget tests.
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    final spoken = semanticLabel ?? (accent ? l10n?.a11yUnreadCount(count) : null);
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(XatBoxTokens.radiusPill)),
      child: Text(
        format(count),
        style: Theme.of(context).textTheme.labelMedium!.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
          height: 20 / 12,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    if (spoken == null) return pill;
    return Semantics(label: spoken, excludeSemantics: true, child: pill);
  }
}

/// The unread marker of the message list (`--unread-pip`, 10px circle).
///
/// Silent by default: the row that shows it states "unread" in its own
/// label (a pip label inside a merged row would be read twice). Pass
/// [semanticLabel] when the pip stands alone.
class UnreadPip extends StatelessWidget {
  const UnreadPip({super.key, this.size = 10, this.semanticLabel});
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final pip = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: context.tokens.unreadPip, shape: BoxShape.circle),
    );
    final spoken = semanticLabel;
    if (spoken == null || spoken.isEmpty) return pip;
    return Semantics(label: spoken, child: pip);
  }
}
