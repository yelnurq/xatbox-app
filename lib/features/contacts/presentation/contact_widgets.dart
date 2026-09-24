import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import '../../chat/presentation/status/chat_status_providers.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../data/contact_models.dart';

/// Profile photo (initials fallback) with the online dot, or — in [ring]
/// mode — a presence ring for the profile hero. Hidden from screen readers:
/// the surrounding row names the contact and its presence.
class ContactAvatar extends StatelessWidget {
  const ContactAvatar({
    super.key,
    required this.contact,
    this.radius = 20,
    this.ring = false,
  });

  final Contact contact;
  final double radius;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final Widget avatar = contact.email.isEmpty
        ? InitialsAvatar(
            label: contact.label,
            colorKey: contact.id,
            radius: radius,
          )
        : UserAvatar(
            email: contact.email,
            label: contact.label,
            radius: radius,
          );
    final dot = (radius * 0.55).clamp(10.0, 18.0);
    final surface = Theme.of(context).colorScheme.surface;
    final stack = Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        if (contact.online)
          Positioned(
            right: ring ? radius * 0.08 : 0,
            bottom: ring ? radius * 0.08 : 0,
            child: Container(
              key: const Key('contact_online_dot'),
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: t.success,
                shape: BoxShape.circle,
                border: Border.all(color: surface, width: 2),
              ),
            ),
          ),
      ],
    );
    if (!ring) return ExcludeSemantics(child: stack);
    return ExcludeSemantics(
      child: Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: contact.online ? t.success : t.border,
          width: 3,
        ),
      ),
      child: stack,
      ),
    );
  }
}

/// Text with the case-insensitive matches of [query] emphasised.
class HighlightText extends StatelessWidget {
  const HighlightText(
    this.text, {
    super.key,
    this.query = '',
    this.style,
    this.maxLines = 1,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final ranges = matchRanges(text, query);
    if (ranges.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }
    final t = context.tokens;
    final hl = (style ?? const TextStyle()).copyWith(
      color: t.primary,
      fontWeight: FontWeight.w700,
      backgroundColor: t.primarySoft,
    );
    final spans = <TextSpan>[];
    var at = 0;
    for (final (start, end) in ranges) {
      if (start > at) spans.add(TextSpan(text: text.substring(at, start)));
      spans.add(TextSpan(text: text.substring(start, end), style: hl));
      at = end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Directory row: avatar with presence dot, name, status · position ·
/// department (or email), favourite star. Height is set by the list (fixed
/// extents), so the status shares the second line.
class ContactTile extends ConsumerWidget {
  const ContactTile({
    super.key,
    required this.contact,
    this.onTap,
    this.query = '',
    this.favourite = false,
    this.selected = false,
    this.onContextMenu,
  });

  final Contact contact;
  final VoidCallback? onTap;
  final String query;
  final bool favourite;

  /// Desktop split pane: the contact open on the right.
  final bool selected;

  /// Desktop right click, at the pointer (contact_menu.dart).
  final ValueChanged<Offset>? onContextMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final details = [
      contact.position,
      contact.department,
    ].where((s) => s.isNotEmpty).join(' · ');
    final status = watchUserStatus(ref, contact.id, contact.status);
    final subtitle = [
      if (status != null)
        ChatStatusFormat.line(context, status, withUntil: false),
      details.isNotEmpty ? details : contact.email,
    ].where((s) => s.isNotEmpty).join(' · ');
    final l10n = context.l10n;
    // One screen-reader node: name, details, presence, favourite.
    final label = [
      contact.label,
      if (subtitle.isNotEmpty) subtitle,
      if (contact.online) l10n.chatOnline,
      if (favourite) l10n.a11yFavourite,
    ].join(', ');
    final tile = Semantics(
      container: true,
      label: label,
      child: InkWell(
      onTap: onTap,
      child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
        child: Row(
          children: [
            ContactAvatar(contact: contact),
            const SizedBox(width: Space.smd),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HighlightText(
                    contact.label,
                    query: query,
                    style: text.bodyLarge?.copyWith(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: Space.xxs),
                    HighlightText(
                      subtitle,
                      query: query,
                      style: text.bodySmall?.copyWith(color: t.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            if (favourite) ...[
              const SizedBox(width: Space.sm),
              Icon(LucideIcons.star, size: 14, color: t.warning),
            ],
          ],
        ),
      ),
      ),
      ),
    );
    // Desktop split pane: the open contact's row, as the chat list's.
    final row = selected ? Material(color: t.primarySoft, child: tile) : tile;
    final menu = onContextMenu;
    return menu == null ? row : GestureDetector(onSecondaryTapUp: (d) => menu(d.globalPosition), child: row);
  }
}

/// Section title of a profile card list (`sectionLabel` of the skin).
class ContactCardTitle extends StatelessWidget {
  const ContactCardTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.md,
        Space.lg,
        Space.md,
        Space.sm,
      ),
      child: Text(
        t.sectionLabel(text),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: t.textTertiary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Bordered surface card of the profile.
class ContactCard extends StatelessWidget {
  const ContactCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: t.cardRadius,
          border: Border.all(color: t.border, width: t.borderWidth),
          boxShadow: t.shadowSm,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, thickness: t.borderWidth, color: t.divider),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon tile + label/value row of a profile card.
class ContactInfoRow extends StatelessWidget {
  const ContactInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.maxLines = 2,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    // Label and value read as one node; the icon tile is decorative.
    return MergeSemantics(
      child: InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTap: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.smd,
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: t.primarySoft,
                  borderRadius: BorderRadius.circular(t.radiusSm),
                ),
                child: Icon(icon, size: 18, color: t.primary),
              ),
            ),
            const SizedBox(width: Space.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: t.textTertiary),
                  ),
                  const SizedBox(height: Space.xxs),
                  Text(
                    value,
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(color: t.textPrimary),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: Space.sm),
              trailing!,
            ],
          ],
        ),
      ),
      ),
    );
  }
}
