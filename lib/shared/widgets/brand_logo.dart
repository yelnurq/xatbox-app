import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/tokens.dart';

/// The Xatbox mark (the web's `BrandLogo`): the silhouette of
/// `assets/brand/icon.svg` painted in one colour — the skin's `--color-mark`
/// (the sidebar's near-white ink on a dark drawer, the brand blue on light).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? context.tokens.mark;
    return SvgPicture.asset(
      'assets/brand/icon.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
      semanticsLabel: 'Xatbox',
    );
  }
}

/// The wordmark (`BrandName`): one colour, the ink of the surface it sits on.
class BrandName extends StatelessWidget {
  const BrandName({super.key, this.color, this.size = 18});

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(
      'Xatbox',
      style: TextStyle(
        fontFamily: t.fontDisplay,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1,
        color: color ?? t.textPrimary,
      ),
    );
  }
}

/// Mark + wordmark side by side (sidebar brand row, login).
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.markColor, this.nameColor, this.markSize = 32, this.nameSize = 18});

  final Color? markColor;
  final Color? nameColor;
  final double markSize;
  final double nameSize;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      BrandMark(size: markSize, color: markColor),
      const SizedBox(width: 10),
      BrandName(color: nameColor, size: nameSize),
    ],
  );
}
