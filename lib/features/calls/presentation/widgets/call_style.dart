import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/initials_avatar.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../calls_format.dart';

/// The call stage is always dark and immersive, whatever the skin: its
/// colours are derived here from the skin's primary and semantic tokens, so
/// every skin still gets its own tint.
@immutable
class CallPalette {
  const CallPalette._({required this.bgTop, required this.bgBottom, required this.glow, required this.danger, required this.success, required this.warning});

  factory CallPalette.of(XatBoxTokens t) {
    final hsl = HSLColor.fromColor(t.primary);
    HSLColor tone(double s, double l) => hsl.withSaturation(math.min(hsl.saturation, s)).withLightness(l);
    Color vivid(Color c) {
      final h = HSLColor.fromColor(c);
      return h.withLightness(h.lightness.clamp(0.48, 0.62)).withSaturation(math.max(h.saturation, 0.55)).toColor();
    }

    return CallPalette._(
      bgTop: tone(0.55, 0.17).toColor(),
      bgBottom: tone(0.45, 0.055).toColor(),
      glow: hsl.withSaturation(math.min(1, hsl.saturation + 0.1)).withLightness(0.62).toColor(),
      danger: vivid(t.danger),
      success: vivid(t.success),
      warning: vivid(t.warning),
    );
  }

  final Color bgTop;
  final Color bgBottom;

  /// Voice activity, speaking borders, pulse rings.
  final Color glow;
  final Color danger;
  final Color success;
  final Color warning;

  static const ink = Colors.white;
  Color get inkSecondary => ink.withValues(alpha: 0.74);
  Color get inkTertiary => ink.withValues(alpha: 0.52);

  /// Frosted glass fills and hairlines.
  Color get glass => ink.withValues(alpha: 0.10);
  Color get glassStrong => ink.withValues(alpha: 0.16);
  Color get glassBorder => ink.withValues(alpha: 0.12);

  /// Highlighted (toggled) control: light fill, dark icon.
  Color get activeFill => ink.withValues(alpha: 0.94);
  Color get activeInk => bgBottom;
  Color get tile => ink.withValues(alpha: 0.06);
  Color get scrim => Colors.black.withValues(alpha: 0.45);
}

extension CallPaletteContext on BuildContext {
  CallPalette get callPalette => CallPalette.of(tokens);
}

/// Repeating animations stop when the platform asks for reduced motion or
/// the subtree is not ticking (tests that settle, hidden routes).
bool callAnimationsEnabled(BuildContext context) => !(MediaQuery.maybeDisableAnimationsOf(context) ?? false) && TickerMode.valuesOf(context).enabled;

const _tabular = [FontFeature.tabularFigures()];

/// Deep gradient with a soft glow, plus a huge blurred avatar tint for audio
/// calls. Painted once (RepaintBoundary): timer ticks never repaint it.
class CallBackdrop extends StatelessWidget {
  const CallBackdrop({super.key, this.colorKey});

  /// Avatar tone key for the blurred tint (null: none).
  final String? colorKey;

  @override
  Widget build(BuildContext context) {
    final p = context.callPalette;
    final tokens = context.tokens;
    final size = MediaQuery.sizeOf(context);
    final blob = math.max(size.width, size.height) * 0.7;
    // Purely decorative: never reaches screen readers.
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [p.bgTop, p.bgBottom]),
              ),
            ),
            if (colorKey != null)
              Positioned(
                top: -blob * 0.25,
                left: (size.width - blob) / 2,
                width: blob,
                height: blob,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 70, sigmaY: 70, tileMode: TileMode.decal),
                  child: DecoratedBox(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: tokens.avatarColorFor(colorKey!).withValues(alpha: 0.35)),
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(center: const Alignment(0, -0.55), radius: 0.9, colors: [p.glow.withValues(alpha: 0.20), p.glow.withValues(alpha: 0)]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Big avatar with pulse rings (ringing / connecting) and a voice-activity
/// glow following [level] (0..1).
class CallAvatar extends StatefulWidget {
  const CallAvatar({super.key, required this.label, this.colorKey, this.email = '', this.radius = 60, this.rings = false, this.level = 0, this.group = false});

  final String label;
  final String? colorKey;
  final String email;
  final double radius;
  final bool rings;
  final double level;
  final bool group;

  @override
  State<CallAvatar> createState() => _CallAvatarState();
}

class _CallAvatarState extends State<CallAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(CallAvatar old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.rings && callAnimationsEnabled(context);
    if (run && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!run && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.callPalette;
    final r = widget.radius;
    final level = widget.level.clamp(0.0, 1.0);
    final Widget face = widget.group
        ? Container(
            width: r * 2,
            height: r * 2,
            decoration: BoxDecoration(shape: BoxShape.circle, color: p.glassStrong),
            child: Icon(LucideIcons.users, size: r * 0.8, color: CallPalette.ink),
          )
        : widget.email.isNotEmpty
        ? UserAvatar(email: widget.email, label: widget.label, radius: r)
        : InitialsAvatar(label: widget.label, colorKey: widget.colorKey, radius: r);
    // Face, rings and glow are decorative: the name is read next to it.
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: r * 2 * 1.7,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.rings)
              Positioned.fill(
                child: RepaintBoundary(child: CustomPaint(painter: _RingsPainter(_pulse, p.glow, r))),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: r * 2 + 8,
              height: r * 2 + 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: level > 0 ? p.glow.withValues(alpha: 0.55 + level * 0.45) : p.glassBorder,
                  width: 2 + level * 2,
                ),
                boxShadow: [
                  if (level > 0)
                    BoxShadow(
                      color: p.glow.withValues(alpha: 0.25 + level * 0.35),
                      blurRadius: 18 + level * 30,
                      spreadRadius: level * r * 0.18,
                    ),
                ],
              ),
              alignment: Alignment.center,
              child: face,
            ),
          ],
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.t, this.color, this.radius) : super(repaint: t);
  final Animation<double> t;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    for (var i = 0; i < 3; i++) {
      final phase = (t.value + i / 3) % 1.0;
      final r = radius + (maxR - radius) * Curves.easeOut.transform(phase);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: 0.45 * (1 - phase));
      canvas.drawCircle(center, r, paint);
      canvas.drawCircle(center, r, Paint()..color = color.withValues(alpha: 0.06 * (1 - phase)));
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.color != color || old.radius != radius;
}

/// Status line; a trailing ellipsis gently breathes while waiting. The plain
/// text stays the localized string (screen readers, tests).
class CallStatusText extends StatefulWidget {
  const CallStatusText(this.text, {super.key, this.style, this.textAlign});
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  State<CallStatusText> createState() => _CallStatusTextState();
}

class _CallStatusTextState extends State<CallStatusText> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  bool get _waiting => widget.text.endsWith('…');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(CallStatusText old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = _waiting && callAnimationsEnabled(context);
    if (run && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!run && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    if (!_waiting) return Text(widget.text, style: style, textAlign: widget.textAlign, maxLines: 2, overflow: TextOverflow.ellipsis);
    final base = widget.text.substring(0, widget.text.length - 1);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Text.rich(
        TextSpan(
          children: [
            TextSpan(text: base),
            TextSpan(
              text: '…',
              style: TextStyle(color: (style.color ?? CallPalette.ink).withValues(alpha: 0.25 + 0.75 * _c.value)),
            ),
          ],
        ),
        style: style,
        textAlign: widget.textAlign,
        maxLines: 2,
      ),
    );
  }
}

/// `mm:ss` since [since] with tabular figures; ticks in its own element so
/// nothing else rebuilds every second.
class CallTimerText extends StatefulWidget {
  const CallTimerText({super.key, required this.since, this.style});
  final DateTime since;
  final TextStyle? style;

  @override
  State<CallTimerText> createState() => _CallTimerTextState();
}

class _CallTimerTextState extends State<CallTimerText> {
  late final Timer _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.since);
    return Text(
      CallsFormat.duration(elapsed.isNegative ? Duration.zero : elapsed),
      style: (widget.style ?? DefaultTextStyle.of(context).style).copyWith(fontFeatures: _tabular),
    );
  }
}

/// Frosted translucent surface (BackdropFilter) for docks, chips and cards.
class CallGlass extends StatelessWidget {
  const CallGlass({super.key, required this.child, this.radius = 28, this.padding = EdgeInsets.zero, this.blur = 24, this.strong = false});
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double blur;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final p = context.callPalette;
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: strong ? p.bgBottom.withValues(alpha: 0.55) : p.glass,
            borderRadius: shape,
            border: Border.all(color: p.glassBorder),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

enum CallButtonTone { normal, danger, success }

/// Round (or pill when [width] is set) call control with a label below and
/// a press-down scale. [active] highlights a toggled state.
class CallRoundButton extends StatefulWidget {
  const CallRoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    this.tone = CallButtonTone.normal,
    this.size = 56,
    this.width,
    this.showLabel = true,
    this.onLongPress,
    this.iconSize,
    this.labelWidth,
    this.toggled,
    this.semanticValue,
    this.onLongPressHint,
    this.tooltip,
  });

  /// Desktop: hover text over the circle (the label with its keys).
  final String? tooltip;

  /// On / off state for screen readers (null: not a toggle). Independent of
  /// [active], which is only the visual highlight.
  final bool? toggled;

  /// Extra state read after the label (e.g. an unread count).
  final String? semanticValue;

  /// What a long press does, for screen readers.
  final String? onLongPressHint;

  /// Width of the label box (defaults to a bit wider than the button).
  final double? labelWidth;

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool active;
  final CallButtonTone tone;
  final double size;
  final double? width;
  final bool showLabel;
  final double? iconSize;

  @override
  State<CallRoundButton> createState() => _CallRoundButtonState();
}

class _CallRoundButtonState extends State<CallRoundButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = context.callPalette;
    final (bg, fg) = switch (widget.tone) {
      CallButtonTone.danger => (p.danger, CallPalette.ink),
      CallButtonTone.success => (p.success, CallPalette.ink),
      CallButtonTone.normal => widget.active ? (p.activeFill, p.activeInk) : (p.glassStrong, CallPalette.ink),
    };
    final w = widget.width ?? widget.size;
    final button = AnimatedScale(
      scale: _down ? 0.9 : 1,
      duration: const Duration(milliseconds: 110),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: w,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.onPressed == null ? bg.withValues(alpha: 0.4) : bg,
          borderRadius: BorderRadius.circular(widget.size / 2),
          boxShadow: widget.tone == CallButtonTone.normal ? null : [BoxShadow(color: bg.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: widget.onPressed,
            onLongPress: widget.onLongPress,
            onSecondaryTap: widget.onLongPress,
            onHighlightChanged: (v) => setState(() => _down = v),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Icon(widget.icon, key: ValueKey(widget.icon), color: fg, size: widget.iconSize ?? widget.size * 0.42),
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      toggled: widget.toggled,
      label: widget.label,
      value: widget.semanticValue,
      onTap: widget.onPressed,
      onLongPress: widget.onLongPress,
      onLongPressHint: widget.onLongPress == null ? null : widget.onLongPressHint,
      excludeSemantics: true,
      // The whole button + caption is the hit area (the circle may be smaller
      // than 48 dp in a crowded dock); taps on the circle itself still go to
      // its InkWell, which wins the gesture arena.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: widget.onPressed,
        onLongPress: widget.onLongPress,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.tooltip case final tip?) Tooltip(message: tip, excludeFromSemantics: true, child: button) else button,
            if (widget.showLabel) ...[
              const SizedBox(height: Space.xs + 2),
              SizedBox(
                width: widget.labelWidth ?? math.max(w + 16, 64),
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.inkSecondary, fontSize: 11.5, fontWeight: FontWeight.w500, height: 1.2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small frosted chip (names, quality, hands).
class CallChip extends StatelessWidget {
  const CallChip({super.key, this.icon, this.iconColor, required this.label, this.dense = false});
  final IconData? icon;
  final Color? iconColor;
  final String label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final p = context.callPalette;
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.38), borderRadius: BorderRadius.circular(XatBoxTokens.radiusPill)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: dense ? 6 : Space.sm, vertical: dense ? 2 : 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: dense ? 12 : 14, color: iconColor ?? CallPalette.ink), if (label.isNotEmpty) const SizedBox(width: 4)],
            if (label.isNotEmpty)
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.inkSecondary.withValues(alpha: 0.95), fontSize: dense ? 11 : 12, fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
