import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Circle with initials in one of the five web avatar tones (`Avatar` in
/// ui.tsx): primary-soft or a label colour, chosen by the same hash of
/// [colorKey], so a person gets the same tone in both clients.
///
/// The initials are decorative for screen readers (TalkBack would spell
/// "ИП"); rows carry the name in their own label. Pass [semanticLabel] when
/// the avatar stands alone and should be announced as an image.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.label,
    this.colorKey,
    this.radius = 20,
    this.semanticLabel,
  });

  /// Display name or email.
  final String label;
  final String? colorKey;
  final double radius;

  /// Optional spoken label (image semantics); none by default.
  final String? semanticLabel;

  /// Web sizes: sm 28px / md 32px / lg 40px.
  static const radiusSm = 14.0;
  static const radiusMd = 16.0;
  static const radiusLg = 20.0;

  /// Same split as the web: whitespace, `@`, `.`, `_`, `-`; first two parts.
  static String initialsOf(String label) {
    final parts = label.split(RegExp(r'[\s@._-]+')).where((p) => p.isNotEmpty).take(2).toList();
    if (parts.isEmpty) return '?';
    return parts.map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final key = colorKey ?? label;
    final circle = Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tokens.avatarColorFor(key), shape: BoxShape.circle),
      child: ExcludeSemantics(
        child: Text(
          initialsOf(label),
          style: TextStyle(
            fontFamily: tokens.fontDisplay,
            fontSize: (radius * 0.66).clamp(10, 18),
            fontWeight: FontWeight.w600,
            color: tokens.avatarTextColorFor(key),
            height: 1,
          ),
        ),
      ),
    );
    final spoken = semanticLabel;
    if (spoken == null || spoken.isEmpty) return circle;
    return Semantics(label: spoken, image: true, child: circle);
  }
}
