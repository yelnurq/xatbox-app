import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

/// Subtle conversation background derived from the skin: the app ground
/// with a faint diagonal dot pattern in the border tone. Painted once into
/// its own layer (RepaintBoundary) and only repainted when the skin changes.
class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: _DotsPainter(
              ground: t.appBg,
              ink: Color.lerp(t.appBg, t.borderStrong, 0.55)!,
              accent: Color.lerp(t.appBg, t.primary, 0.12)!,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter({
    required this.ground,
    required this.ink,
    required this.accent,
  });
  final Color ground;
  final Color ink;
  final Color accent;

  static const _step = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);
    final dot = Paint()..color = ink;
    final ring = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    var row = 0;
    for (var y = _step / 2; y < size.height + _step; y += _step, row++) {
      final shift = row.isOdd ? _step / 2 : 0.0;
      var col = 0;
      for (var x = shift; x < size.width + _step; x += _step, col++) {
        if ((row + col) % 7 == 0) {
          canvas.drawCircle(Offset(x, y), 3, ring);
        } else {
          canvas.drawCircle(Offset(x, y), 0.9, dot);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) =>
      old.ground != ground || old.ink != ink || old.accent != accent;
}
