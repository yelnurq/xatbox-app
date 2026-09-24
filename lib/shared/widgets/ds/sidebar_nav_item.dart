import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/tokens.dart';

/// A row of the web sidebar (`.sidebar-nav-item`): 30px icon tile, label,
/// optional badge, optional expand toggle. The active state follows the
/// skin's signature ([NavActiveStyle]); colours come from the sidebar tokens,
/// so the kok skin's deep-teal drawer paints itself.
class SidebarNavItem extends StatelessWidget {
  const SidebarNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge,
    this.iconColors,
    this.expanded,
    this.onToggle,
    this.toggleLabel,
    this.semanticKey,
    this.round = false,
    this.iconOnly = false,
    this.onPage = false,
  });

  /// Drawn on a page (the desktop settings sections), not in the sidebar:
  /// the page's colours instead of the sidebar's (the kok skin's sidebar
  /// ink is near-white).
  final bool onPage;

  /// Desktop: the icon sits in a circle (and the active row is a pill).
  final bool round;

  /// Desktop collapsed sidebar: only the icon, centred, with a tooltip and
  /// the badge as a small count on the icon.
  final bool iconOnly;

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Widget? badge;

  /// Folder-coloured icon tile (`data-custom-color`): (background, ink, border).
  final FolderColors? iconColors;

  /// When set the row carries a chevron that expands a nested tree.
  final bool? expanded;
  final VoidCallback? onToggle;
  final String? toggleLabel;
  final Key? semanticKey;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = _NavColors(t, onPage);
    final style = t.navActive;
    final radius = BorderRadius.circular(round ? XatBoxTokens.radiusPill : t.navRadius);
    final iconRadius = BorderRadius.circular(round ? XatBoxTokens.radiusPill : 8);
    final inverse = active && style == NavActiveStyle.inverse;
    final labelColor = inverse ? c.sidebarTextInverse : (active ? c.sidebarText : c.sidebarTextSecondary);
    final background = switch ((active, style)) {
      (false, _) => Colors.transparent,
      (true, NavActiveStyle.rail) => Colors.transparent,
      (true, NavActiveStyle.underline) => Colors.transparent,
      (true, NavActiveStyle.tint) => c.sidebarSelected,
      (true, NavActiveStyle.railTint) => c.sidebarSubtle,
      (true, NavActiveStyle.inverse) => c.sidebarText,
    };
    final showRail = !iconOnly && active && (style == NavActiveStyle.rail || style == NavActiveStyle.railTint);
    final iconInk = iconColors?.foreground ?? (inverse ? c.sidebarTextInverse : (active ? c.sidebarPrimary : c.sidebarTextTertiary));
    final iconBg = iconColors?.background ?? (active && !inverse && style != NavActiveStyle.underline ? c.sidebarSubtle : Colors.transparent);
    final iconBorder = iconColors?.border ?? (active && !inverse && style != NavActiveStyle.underline ? c.sidebarBorder : Colors.transparent);
    final textStyle = Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: labelColor,
      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
      fontFamily: t.fontDisplay,
      decoration: active && style == NavActiveStyle.underline ? TextDecoration.underline : null,
      decorationColor: t.info,
      decorationThickness: 1.5,
    );

    if (iconOnly) {
      final count = badge;
      Widget glyph = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active ? (inverse ? c.sidebarText : c.sidebarSelected) : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: active && !inverse ? c.sidebarBorder : Colors.transparent, width: t.borderWidth),
        ),
        child: Icon(icon, size: 18, color: iconInk),
      );
      if (count != null) glyph = Badge(label: count, backgroundColor: Colors.transparent, padding: EdgeInsets.zero, offset: const Offset(4, -4), child: glyph);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Center(
          child: Tooltip(
            message: label,
            waitDuration: const Duration(milliseconds: 400),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                key: semanticKey,
                onTap: onTap,
                customBorder: const CircleBorder(),
                hoverColor: c.sidebarHover,
                child: Semantics(button: true, selected: active, label: label, excludeSemantics: true, child: glyph),
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 1),
      child: Material(
        color: background,
        borderRadius: radius,
        child: InkWell(
          key: semanticKey,
          onTap: onTap,
          borderRadius: radius,
          hoverColor: c.sidebarHover,
          splashColor: c.sidebarHover,
          child: Stack(
            children: [
              if (showRail)
                Positioned(
                  left: 6,
                  top: 9,
                  bottom: 9,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: c.sidebarPrimary,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
                    ),
                  ),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Space.tapTarget),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(10, 4, onToggle != null ? Space.xxl : 10, 4),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: iconRadius,
                          border: Border.all(color: iconBorder, width: t.borderWidth),
                        ),
                        child: Icon(icon, size: 16, color: iconInk),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: textStyle)),
                      if (badge != null) ...[const SizedBox(width: Space.sm), badge!],
                    ],
                  ),
                ),
              ),
              if (onToggle != null)
                Positioned(
                  right: 6,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      tooltip: toggleLabel,
                      onPressed: onToggle,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                      padding: EdgeInsets.zero,
                      icon: Icon(expanded == true ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 14, color: c.sidebarTextTertiary),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.sidebar-section-label`: 12px/700 uppercase, tracked, tertiary, with the
/// hairline that runs to the right edge. Terminal prefixes it with `> `.
class SidebarSectionLabel extends StatelessWidget {
  const SidebarSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, Space.mlg, 18, Space.sm),
      child: Row(
        children: [
          Text(
            t.sectionLabel(text),
            style: Theme.of(context).textTheme.labelMedium!.copyWith(
              color: t.sidebarTextTertiary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.72,
              fontFamily: t.fontDisplay,
            ),
          ),
          const SizedBox(width: Space.smd),
          Expanded(child: Divider(color: t.sidebarDivider, thickness: t.borderWidth, height: t.borderWidth)),
        ],
      ),
    );
  }
}

/// A row of the nested tree under Inbox / Bookmarks (`FolderTree`): 36px,
/// 24px folder tile, 12px label, folder-coloured unread pill.
class SidebarTreeItem extends StatelessWidget {
  const SidebarTreeItem({
    super.key,
    required this.leading,
    required this.label,
    required this.active,
    required this.onTap,
    this.trailing,
    this.semanticKey,
  });

  final Widget leading;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Widget? trailing;
  final Key? semanticKey;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(8);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: semanticKey,
        onTap: onTap,
        borderRadius: radius,
        hoverColor: t.sidebarHover,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
            child: Row(
              children: [
                leading,
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium!.copyWith(
                      color: active ? t.sidebarText : t.sidebarTextSecondary,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: Space.sm), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The indented tree container: `ml-[26px] border-l pl-2`.
class SidebarTree extends StatelessWidget {
  const SidebarTree({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(left: 34, right: Space.sm, top: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: t.sidebarBorder, width: t.borderWidth))),
        child: Padding(
          padding: const EdgeInsets.only(left: Space.sm),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );
  }
}

/// The sidebar colours of a nav row, or the page's own when it sits on a
/// page ([SidebarNavItem.onPage]).
class _NavColors {
  _NavColors(this.t, this.onPage);
  final XatBoxTokens t;
  final bool onPage;

  Color get sidebarText => onPage ? t.textPrimary : t.sidebarText;
  Color get sidebarTextSecondary => onPage ? t.textSecondary : t.sidebarTextSecondary;
  Color get sidebarTextTertiary => onPage ? t.textTertiary : t.sidebarTextTertiary;
  Color get sidebarTextInverse => onPage ? t.textInverse : t.sidebarTextInverse;
  Color get sidebarPrimary => onPage ? t.primary : t.sidebarPrimary;
  Color get sidebarSubtle => onPage ? t.surfaceSubtle : t.sidebarSubtle;
  Color get sidebarBorder => onPage ? t.border : t.sidebarBorder;
  Color get sidebarSelected => onPage ? t.surfaceSelected : t.sidebarSelected;
  Color get sidebarHover => onPage ? t.surfaceHover : t.sidebarHover;
}
