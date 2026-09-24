import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// The picture behind a glass skin, filling its box. Painted once per size
/// (no assets: a dawn pine forest in fog, or a starry sky with nebulae and
/// a planet).
class SkinBackdropView extends StatelessWidget {
  const SkinBackdropView({super.key, required this.backdrop, this.custom});

  final SkinBackdrop backdrop;

  /// «Свой фон» only: the chosen picture and its dim and blur.
  final CustomBackdrop? custom;

  @override
  Widget build(BuildContext context) {
    if (backdrop == SkinBackdrop.custom) {
      return _CustomBackdrop(config: custom ?? const CustomBackdrop());
    }
    final photo = backdrop.photo;
    if (photo != null) return _PhotoBackdrop(asset: photo);
    return RepaintBoundary(
      child: CustomPaint(
        isComplex: true,
        painter: switch (backdrop) {
          SkinBackdrop.forest => const ForestBackdropPainter(),
          _ => const SpaceBackdropPainter(),
        },
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Desktop: [child] over the glass skin's picture. The tree keeps its shape
/// whatever the skin, so switching skins never remounts the pages; phones
/// ([enabled] false) get [child] alone.
class SkinBackdropScope extends StatelessWidget {
  const SkinBackdropScope({super.key, required this.enabled, required this.child, this.custom});

  final bool enabled;
  final Widget child;

  /// «Свой фон» only; read from `desktopSettingsProvider` by the caller so
  /// that this layer stays free of providers.
  final CustomBackdrop? custom;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final glass = context.tokens.glass;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (glass != null)
          SkinBackdropView(key: ValueKey(glass.backdrop), backdrop: glass.backdrop, custom: custom)
        else
          const SizedBox.shrink(),
        child,
      ],
    );
  }
}

/// Dawn over a pine forest: a warm sky, a low sun, blue ridges, five rows
/// of pines stepping out of the fog, soft light rays and a vignette.
class ForestBackdropPainter extends CustomPainter {
  const ForestBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;
    final full = Offset.zero & size;
    final rnd = math.Random(7);

    // Sky.
    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D2433), Color(0xFF24505F), Color(0xFF8C9A86), Color(0xFFE8BE82), Color(0xFFF4D7A1)],
          stops: [0, 0.3, 0.5, 0.62, 0.72],
        ).createShader(full),
    );
    final sun = Offset(w * 0.7, h * 0.56);
    canvas.drawCircle(
      sun,
      w * 0.5,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0xE6FFF1C9), Color(0x66FFD99A), Color(0x00FFD99A)],
          stops: const [0, 0.25, 1],
        ).createShader(Rect.fromCircle(center: sun, radius: w * 0.5)),
    );
    canvas.drawCircle(sun, h * 0.035, Paint()..color = const Color(0xFFFFF6DE));

    // Distant ridges.
    _ridge(canvas, size, rnd, base: 0.58, amp: 0.07, color: const Color(0xFF7D938F));
    _ridge(canvas, size, rnd, base: 0.62, amp: 0.06, color: const Color(0xFF5A7775));
    _fog(canvas, size, top: 0.55, bottom: 0.7, color: const Color(0x80EBDDBF));

    // Pines, far to near, each row darker, taller and sharper.
    const rows = [
      (0.66, 0.10, Color(0xFF3E625E), Color(0x66E3DCC4)),
      (0.72, 0.15, Color(0xFF2A4B45), Color(0x4DD7D8C6)),
      (0.8, 0.21, Color(0xFF17332C), Color(0x40C9D1C3)),
      (0.9, 0.3, Color(0xFF0B1F19), Color(0x26B7C4B8)),
      (1.02, 0.44, Color(0xFF040F0B), null),
    ];
    for (final (base, height, color, fog) in rows) {
      pines(canvas, size, rnd, base: base, height: height, color: color);
      if (fog != null) _fog(canvas, size, top: base - height * 0.25, bottom: base + 0.03, color: fog);
    }

    // Soft light shafts falling from the sun through the trees.
    final rays = Paint()..blendMode = BlendMode.plus;
    for (var i = 0; i < 5; i++) {
      final angle = math.pi * (0.5 + i * 0.07 + rnd.nextDouble() * 0.03);
      final spread = 0.02 + rnd.nextDouble() * 0.025;
      final len = h * 0.7;
      final path = Path()
        ..moveTo(sun.dx, sun.dy)
        ..lineTo(sun.dx + math.cos(angle - spread) * len, sun.dy + math.sin(angle - spread) * len)
        ..lineTo(sun.dx + math.cos(angle + spread) * len, sun.dy + math.sin(angle + spread) * len)
        ..close();
      rays.shader = RadialGradient(
        colors: const [Color(0x24FFF0CC), Color(0x0AFFF0CC), Color(0x00FFF0CC)],
        stops: const [0, 0.5, 1],
      ).createShader(Rect.fromCircle(center: sun, radius: len));
      canvas.drawPath(path, rays);
    }
    _vignette(canvas, size);
  }

  static void _ridge(Canvas canvas, Size size, math.Random rnd, {required double base, required double amp, required Color color}) {
    final w = size.width;
    final h = size.height;
    final phases = [for (var i = 0; i < 3; i++) rnd.nextDouble() * math.pi * 2];
    final path = Path()..moveTo(0, h);
    for (var x = 0.0; x <= w + 8; x += 8) {
      final t = x / w;
      final y = base -
          amp *
              (0.55 * math.sin(t * 5.1 + phases[0]) +
                      0.3 * math.sin(t * 11.3 + phases[1]) +
                      0.15 * math.sin(t * 23.7 + phases[2]))
                  .abs();
      path.lineTo(x, y * h);
    }
    path
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  /// A row of spruces standing on [base] (a fraction of the height); the
  /// Semey bank borrows it for its far shore.
  static void pines(Canvas canvas, Size size, math.Random rnd, {required double base, required double height, required Color color}) {
    final w = size.width;
    final h = size.height;
    final baseY = base * h;
    final paint = Paint()..color = color;
    final path = Path();
    var x = -rnd.nextDouble() * 40;
    final tallest = height * h;
    while (x < w + 60) {
      final th = tallest * (0.55 + rnd.nextDouble() * 0.45);
      final width = th * (0.28 + rnd.nextDouble() * 0.1);
      _pine(path, rnd, x, baseY + rnd.nextDouble() * tallest * 0.08, th, width);
      x += width * (0.35 + rnd.nextDouble() * 0.5);
    }
    path.addRect(Rect.fromLTRB(0, baseY, w, h));
    canvas.drawPath(path, paint);
  }

  /// A spruce: a thin tip, then tiers that widen downward with drooping,
  /// ragged ends.
  static void _pine(Path path, math.Random rnd, double cx, double baseY, double height, double width) {
    final top = baseY - height;
    final tiers = 7 + rnd.nextInt(4);
    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 1; i <= tiers; i++) {
      final t = i / tiers;
      final y = top + height * (0.08 + 0.92 * t);
      final half = width * 0.5 * (0.18 + 0.82 * t) * (0.85 + rnd.nextDouble() * 0.3);
      final droop = height * 0.018;
      final inner = half * (0.45 + rnd.nextDouble() * 0.15);
      right
        ..add(Offset(cx + half, y + droop))
        ..add(Offset(cx + inner, y - height * 0.02));
      left
        ..add(Offset(cx - half * (0.9 + rnd.nextDouble() * 0.2), y + droop))
        ..add(Offset(cx - inner, y - height * 0.02));
    }
    path.moveTo(cx, top);
    for (final p in right) {
      path.lineTo(p.dx, p.dy);
    }
    path
      ..lineTo(cx + width * 0.05, baseY)
      ..lineTo(cx - width * 0.05, baseY);
    for (final p in left.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
  }

  static void _fog(Canvas canvas, Size size, {required double top, required double bottom, required Color color}) {
    final rect = Rect.fromLTRB(0, top * size.height, size.width, bottom * size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0), color, color.withValues(alpha: 0)],
          stops: const [0, 0.6, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(ForestBackdropPainter oldDelegate) => false;
}

/// Deep space: a violet-blue sky, a tilted Milky Way, glowing nebulae,
/// a few thousand stars (some with rays) and a planet rising at the corner.
class SpaceBackdropPainter extends CustomPainter {
  const SpaceBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;
    final full = Offset.zero & size;
    final rnd = math.Random(42);

    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF03040D), Color(0xFF0A1030), Color(0xFF150B2E), Color(0xFF05060F)],
          stops: [0, 0.4, 0.7, 1],
        ).createShader(full),
    );

    // Nebulae: overlapping soft glows, added on top of each other.
    final glow = Paint()..blendMode = BlendMode.plus;
    void cloud(double x, double y, double r, Color c) {
      final center = Offset(x * w, y * h);
      final radius = r * math.max(w, h);
      glow.shader = RadialGradient(
        colors: [c, c.withValues(alpha: c.a * 0.35), c.withValues(alpha: 0)],
        stops: const [0, 0.45, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, glow);
    }

    cloud(0.22, 0.3, 0.32, const Color(0x59B0368E));
    cloud(0.34, 0.2, 0.22, const Color(0x4D6A3BD6));
    cloud(0.44, 0.38, 0.26, const Color(0x4D2F57D9));
    cloud(0.3, 0.46, 0.16, const Color(0x40E0628A));
    cloud(0.62, 0.3, 0.2, const Color(0x331FA3C4));
    cloud(0.12, 0.62, 0.18, const Color(0x333E2FA8));
    cloud(0.5, 0.33, 0.07, const Color(0x40FFC7E6));

    // The Milky Way: a tilted band with its own denser stars.
    canvas.save();
    canvas.translate(w * 0.5, h * 0.45);
    canvas.rotate(-0.42);
    final band = Rect.fromCenter(center: Offset.zero, width: w * 1.8, height: h * 0.34);
    canvas.save();
    canvas.scale(1, 0.22);
    canvas.drawCircle(
      Offset.zero,
      w * 0.9,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = const RadialGradient(
          colors: [Color(0x40B8C4FF), Color(0x1A7D8BE0), Color(0x00000000)],
          stops: [0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: w * 0.9)),
    );
    canvas.restore();
    final dust = Paint();
    for (var i = 0; i < (w * h / 900).clamp(400, 2600).toInt(); i++) {
      final gx = (rnd.nextDouble() - 0.5) * band.width;
      final gy = _gauss(rnd) * band.height * 0.22;
      dust.color = Colors.white.withValues(alpha: 0.15 + rnd.nextDouble() * 0.45);
      canvas.drawCircle(Offset(gx, gy), 0.3 + rnd.nextDouble() * 0.6, dust);
    }
    canvas.restore();

    // Stars.
    final star = Paint();
    const tints = [Color(0xFFFFFFFF), Color(0xFFCAD8FF), Color(0xFFFFE9C7), Color(0xFFE7D6FF)];
    final count = (w * h / 1100).clamp(500, 3000).toInt();
    for (var i = 0; i < count; i++) {
      final p = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h);
      final r = 0.3 + math.pow(rnd.nextDouble(), 3) * 1.4;
      star.color = tints[rnd.nextInt(tints.length)].withValues(alpha: 0.35 + rnd.nextDouble() * 0.65);
      canvas.drawCircle(p, r, star);
    }
    // Bright stars with a halo and four rays.
    for (var i = 0; i < 26; i++) {
      final p = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * 0.85);
      final r = 1.2 + rnd.nextDouble() * 1.6;
      final tint = tints[rnd.nextInt(tints.length)];
      canvas.drawCircle(
        p,
        r * 7,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: [tint.withValues(alpha: 0.35), tint.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: p, radius: r * 7)),
      );
      final ray = Paint()
        ..blendMode = BlendMode.plus
        ..strokeWidth = 0.8
        ..color = tint.withValues(alpha: 0.55);
      canvas
        ..drawLine(p.translate(-r * 6, 0), p.translate(r * 6, 0), ray)
        ..drawLine(p.translate(0, -r * 6), p.translate(0, r * 6), ray)
        ..drawCircle(p, r, Paint()..color = Colors.white);
    }

    _planet(canvas, size);
    _vignette(canvas, size);
  }

  static void _planet(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = math.min(w, h) * 0.42;
    final c = Offset(w * 0.9, h * 1.08);
    final disc = Rect.fromCircle(center: c, radius: r);
    // Atmosphere.
    canvas.drawCircle(
      c,
      r * 1.18,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: const [Color(0x00000000), Color(0x00000000), Color(0x807FA8FF), Color(0x00000000)],
          stops: const [0, 0.8, 0.85, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.18)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.55, -0.6),
          radius: 1.1,
          colors: [Color(0xFF6E83D8), Color(0xFF2B3478), Color(0xFF0E1033), Color(0xFF05060F)],
          stops: [0, 0.3, 0.7, 1],
        ).createShader(disc),
    );
    // Cloud bands.
    canvas.save();
    canvas.clipPath(Path()..addOval(disc));
    final bands = Paint()..blendMode = BlendMode.plus;
    for (var i = 0; i < 6; i++) {
      final y = c.dy - r + r * 0.25 + i * r * 0.22;
      bands.color = const Color(0xFF9FB4FF).withValues(alpha: 0.05 + (i % 2) * 0.04);
      canvas.drawOval(Rect.fromCenter(center: Offset(c.dx - r * 0.1, y), width: r * 2.6, height: r * 0.08), bands);
    }
    canvas.restore();
    // Rim light.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xCCBFD0FF), Color(0x00BFD0FF)],
          stops: [0, 0.5],
        ).createShader(disc),
    );
    // A small moon.
    final moon = Offset(w * 0.68, h * 0.7);
    final mr = r * 0.07;
    canvas.drawCircle(
      moon,
      mr,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.5, -0.5),
          colors: [Color(0xFFE6E2F0), Color(0xFF6F6A86), Color(0xFF1A1830)],
          stops: [0, 0.6, 1],
        ).createShader(Rect.fromCircle(center: moon, radius: mr)),
    );
  }

  static double _gauss(math.Random rnd) {
    final u = rnd.nextDouble().clamp(1e-9, 1.0);
    final v = rnd.nextDouble();
    return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v);
  }

  @override
  bool shouldRepaint(SpaceBackdropPainter oldDelegate) => false;
}

/// A photographed backdrop: the picture fills the window, a dark scrim over
/// it keeps the white text and the glass panels readable, and the corners
/// darken so the shell's edges do not glare.
class _PhotoBackdrop extends StatelessWidget {
  const _PhotoBackdrop({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(asset, fit: BoxFit.cover, alignment: Alignment.center, filterQuality: FilterQuality.medium),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x8C000000), Color(0x4D000000), Color(0x66000000), Color(0xA6000000)],
                stops: [0, 0.35, 0.7, 1],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.95,
                colors: [Color(0x00000000), Color(0x00000000), Color(0x66000000)],
                stops: [0, 0.55, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «Свой фон»: the picture the user chose, under the same scrim as the
/// photographed skins but with the dim and the blur they set. Until a
/// picture is chosen — or if the file went missing — the skin falls back to
/// its plain dark surface, so the app never shows a broken image.
class _CustomBackdrop extends StatelessWidget {
  const _CustomBackdrop({required this.config});

  final CustomBackdrop config;

  @override
  Widget build(BuildContext context) {
    final path = config.path;
    final empty = path == null || path.isEmpty || !File(path).existsSync();
    final dim = config.dim.clamp(0.0, 1.0);
    final blur = config.blur.clamp(0.0, 30.0);
    Widget picture = Image.file(
      empty ? File('') : File(path),
      key: ValueKey(path),
      fit: BoxFit.cover,
      alignment: Alignment.center,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => const _EmptyBackdrop(),
    );
    if (blur > 0) {
      // The blur is clipped to the window: without it the softened edges
      // let the dark shell show through along the sides.
      picture = ClipRect(
        child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: picture),
      );
    }
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (empty) const _EmptyBackdrop() else picture,
          DecoratedBox(decoration: BoxDecoration(color: Colors.black.withValues(alpha: dim))),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.95,
                colors: [Color(0x00000000), Color(0x00000000), Color(0x66000000)],
                stops: [0, 0.55, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «Свой фон» with no picture yet: a quiet slate gradient.
class _EmptyBackdrop extends StatelessWidget {
  const _EmptyBackdrop();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1B1E24), Color(0xFF101216)],
      ),
    ),
    child: SizedBox.expand(),
  );
}

void _vignette(Canvas canvas, Size size) {
  final full = Offset.zero & size;
  canvas.drawRect(
    full,
    Paint()
      ..shader = RadialGradient(
        radius: 0.95,
        colors: const [Color(0x00000000), Color(0x00000000), Color(0x73000000)],
        stops: const [0, 0.55, 1],
      ).createShader(full),
  );
}

/// Glass skins: frosts the picture behind [child] (the rail, the top bar,
/// page cards). Desktop only; the widget tree is the same for every skin
/// (the filter is just off), so a skin change never remounts [child].
class GlassBlur extends StatelessWidget {
  const GlassBlur({super.key, required this.child, this.borderRadius});

  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final glass = context.tokens.glass;
    final sigma = glass?.blur ?? 0;
    final filter = BackdropFilter(
      enabled: glass != null,
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    );
    return borderRadius == null ? ClipRect(child: filter) : ClipRRect(borderRadius: borderRadius!, child: filter);
  }
}
