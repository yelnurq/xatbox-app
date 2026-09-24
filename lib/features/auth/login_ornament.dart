import 'dart:typed_data';

import 'package:flutter/material.dart';

/// The ornament of the web login field, drawn with the same two Kazakh
/// motifs and the same 320 dp tile: the four-way curl with a centre point
/// (the "spider") and қошқар мүйіз — a stem with two ram's horns curling
/// inward. Thin ink lines on the coloured field, drifting diagonally like
/// the CSS `login-drift` animation (90 s per tile).
///
/// The path data is the web's, so both logins carry the exact same figure;
/// see `apps/web/src/app/login/page.tsx` in the mail server.
class LoginOrnament extends StatefulWidget {
  const LoginOrnament({super.key, required this.color});

  /// The field's ink (`--login-ink`); the lines are drawn translucently.
  final Color color;

  @override
  State<LoginOrnament> createState() => _LoginOrnamentState();
}

class _LoginOrnamentState extends State<LoginOrnament>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 90),
  )..repeat();

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // "Reduce motion": the ornament is still drawn, it just stands still.
    final still = MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _drift,
            builder: (_, _) => CustomPaint(
              painter: _OrnamentPainter(
                color: widget.color,
                shift: still ? 0 : _drift.value * _OrnamentPainter.tile,
              ),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrnamentPainter extends CustomPainter {
  _OrnamentPainter({required this.color, required this.shift});

  final Color color;

  /// Diagonal offset inside one tile, 0 … [tile].
  final double shift;

  /// Side of the repeating square, as on the web (`background-size: 320px`).
  static const tile = 320.0;

  /// The two halves of a cell: full-strength strokes and the faint mirrored
  /// ones, each built once for the whole 320 dp tile.
  static final Path _strong = _buildTile(faint: false);
  static final Path _faint = _buildTile(faint: true);

  // The web's `CURL` and `RAM`, in a 160 dp cell.
  static Path _curl() => Path()
    ..moveTo(30, 118)
    ..cubicTo(30, 84, 48, 66, 70, 66)
    ..cubicTo(92, 66, 104, 80, 104, 96)
    ..cubicTo(104, 110, 94, 120, 82, 120)
    ..cubicTo(70, 120, 64, 112, 64, 102)
    ..cubicTo(64, 94, 70, 89, 76, 91);

  static Path _ram() => Path()
    ..moveTo(80, 124)
    ..lineTo(80, 78)
    ..cubicTo(80, 58, 66, 44, 50, 44)
    ..cubicTo(36, 44, 27, 54, 27, 66)
    ..cubicTo(27, 77, 35, 85, 45, 85)
    ..cubicTo(53, 85, 58, 79, 58, 72)
    ..cubicTo(58, 66, 53, 62, 48, 62);

  /// `translate(tx, ty) scale(sx, sy)` of the SVG, as a matrix.
  static Float64List _m(double tx, double ty, double sx, double sy) =>
      (Matrix4.identity()
            ..translateByDouble(tx, ty, 0, 1)
            ..scaleByDouble(sx, sy, 1, 1))
          .storage;

  /// One cell of the "spider": the curl in four mirrored copies, the lower
  /// two fainter (`stroke-opacity 0.09` on the web).
  static void _spider(Path into, {required bool faint, required double dx,
      required double dy}) {
    final move = _m(dx, dy, 1, 1);
    if (!faint) {
      into.addPath(_curl(), Offset.zero, matrix4: move);
      into.addPath(_curl(), Offset.zero, matrix4: _m(dx + 160, dy, -1, 1));
    } else {
      into.addPath(_curl(), Offset.zero, matrix4: _m(dx, dy + 160, 1, -1));
      into.addPath(
        _curl(),
        Offset.zero,
        matrix4: _m(dx + 160, dy + 160, -1, -1),
      );
    }
  }

  /// One cell of қошқар мүйіз: the stem with both horns, plus the small
  /// diamond at its foot (the faint part).
  static void _horns(Path into, {required bool faint, required double dx,
      required double dy}) {
    if (!faint) {
      into.addPath(_ram(), Offset.zero, matrix4: _m(dx, dy, 1, 1));
      into.addPath(_ram(), Offset.zero, matrix4: _m(dx + 160, dy, -1, 1));
      return;
    }
    into.addPath(
      Path()
        ..moveTo(80, 124)
        ..relativeLineTo(-7, 9)
        ..relativeLineTo(7, 9)
        ..relativeLineTo(7, -9)
        ..close(),
      Offset.zero,
      matrix4: _m(dx, dy, 1, 1),
    );
  }

  /// Spider / horns in a checkerboard, exactly as the web tile.
  static Path _buildTile({required bool faint}) {
    final path = Path();
    _spider(path, faint: faint, dx: 0, dy: 0);
    _horns(path, faint: faint, dx: 160, dy: 0);
    _horns(path, faint: faint, dx: 0, dy: 160);
    _spider(path, faint: faint, dx: 160, dy: 160);
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: 0.16);
    final faint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: 0.09);
    final dot = Paint()..color = color.withValues(alpha: 0.18);

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // One tile of slack on each side keeps the drift seamless.
    canvas.translate(shift - tile, shift - tile);
    for (var y = 0.0; y < size.height + tile * 2; y += tile) {
      for (var x = 0.0; x < size.width + tile * 2; x += tile) {
        canvas.save();
        canvas.translate(x, y);
        canvas.drawPath(_strong, stroke);
        canvas.drawPath(_faint, faint);
        // Centre point of both spider cells.
        canvas.drawCircle(const Offset(80, 80), 3, dot);
        canvas.drawCircle(const Offset(240, 240), 3, dot);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OrnamentPainter old) =>
      old.shift != shift || old.color != color;
}
