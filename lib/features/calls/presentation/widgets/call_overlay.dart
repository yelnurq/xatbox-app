import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/platform/desktop.dart';
import '../../../../core/localization/localization.dart';
import '../call_controller.dart';
import '../calls_providers.dart';
import 'call_chat.dart';
import 'call_recording.dart';
import 'call_stage.dart';
import 'call_style.dart';

/// App-wide host of the minimised call: while a call runs and the call
/// screen is not shown, a draggable mini bar floats over every page; a tap
/// returns to the call.
class CallOverlayHost extends ConsumerWidget {
  const CallOverlayHost({super.key, required this.child, required this.onOpen});
  final Widget child;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show =
        ref.watch(callsEnabledProvider) &&
        ref.watch(callControllerProvider.select((s) => s.inCall)) &&
        ref.watch(callScreenPresenceProvider) == 0 &&
        !ref.watch(callPipModeProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (show) _MiniCall(onOpen: onOpen),
      ],
    );
  }
}

class _MiniCall extends StatefulWidget {
  const _MiniCall({required this.onOpen});
  final VoidCallback onOpen;

  @override
  State<_MiniCall> createState() => _MiniCallState();
}

class _MiniCallState extends State<_MiniCall> {
  bool _left = false;
  double? _y;
  Offset? _drag;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final pad = MediaQuery.paddingOf(context);
        final w = (box.maxWidth - 24).clamp(160.0, 280.0);
        // Minimum height; the card grows with large text.
        const h = 64.0;
        final minY = pad.top + 8;
        // Above the bottom navigation bar by default (the desktop has none).
        final maxY = (box.maxHeight - pad.bottom - h - (isDesktop ? 16 : 92)).clamp(minY, double.infinity);
        final rest = Offset(_left ? 12 : box.maxWidth - w - 12, (_y ?? maxY).clamp(minY, maxY));
        final pos = _drag ?? rest;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: _drag != null ? Duration.zero : const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              left: pos.dx,
              top: pos.dy,
              width: w,
              child: GestureDetector(
                key: const Key('call_mini_bar'),
                onTap: widget.onOpen,
                onPanStart: (_) => setState(() => _drag = rest),
                onPanUpdate: (d) => setState(() => _drag = (_drag ?? rest) + d.delta),
                onPanEnd: (d) {
                  final at = _drag ?? rest;
                  setState(() {
                    _left = at.dx + w / 2 + d.velocity.pixelsPerSecond.dx * 0.1 < box.maxWidth / 2;
                    _y = at.dy;
                    _drag = null;
                  });
                },
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.8, end: 1),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutBack,
                  builder: (_, s, child) => Transform.scale(scale: s, child: child),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: h),
                    child: const _MiniCallCard(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MiniCallCard extends ConsumerWidget {
  const _MiniCallCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final pal = context.callPalette;
    final hero = ref.watch(callHeroProvider);
    final phase = ref.watch(callControllerProvider.select((s) => s.phase));
    final micOn = ref.watch(callControllerProvider.select((s) => s.micOn));
    final level = ref.watch(callControllerProvider.select((s) => callVoiceLevel(s.participants.where((p) => !p.isLocal && p.speaking).firstOrNull)));
    final unread = ref.watch(callControllerProvider.select((s) => s.chatUnread));
    final controller = ref.read(callControllerProvider.notifier);
    final incoming = phase == CallPhase.incoming;
    return Semantics(
      button: true,
      label: l10n.callsReturnToCall,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [pal.bgTop, pal.bgBottom]),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: pal.glassBorder),
          boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 24, offset: Offset(0, 10))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox.square(
                      dimension: 52,
                      child: FittedBox(
                        child: CallAvatar(
                          label: hero.title,
                          colorKey: hero.colorKey,
                          email: hero.email,
                          group: hero.group,
                          radius: 26,
                          level: level,
                          rings: incoming || phase == CallPhase.outgoing,
                        ),
                      ),
                    ),
                    if (unread > 0 && !incoming)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: CallCountBadge(key: const Key('call_mini_chat_badge'), count: unread),
                      ),
                  ],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              hero.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: CallPalette.ink, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const CallRecIndicator(key: Key('call_mini_rec'), compact: true),
                        ],
                      ),
                      const SizedBox(height: 2),
                      incoming
                          ? Text(l10n.callsIncoming, maxLines: 1, style: TextStyle(color: pal.inkSecondary, fontSize: 12))
                          : CallStatusLine(withKeys: false, style: TextStyle(color: pal.inkSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                if (!incoming)
                  _MiniButton(
                    key: const Key('call_mini_mic'),
                    icon: micOn ? LucideIcons.mic : LucideIcons.micOff,
                    label: l10n.callsMic,
                    active: !micOn,
                    toggled: micOn,
                    onTap: () => controller.setMic(!micOn),
                  ),
                const SizedBox(width: 2),
                _MiniButton(
                  key: const Key('call_mini_hangup'),
                  icon: LucideIcons.phoneOff,
                  label: incoming ? l10n.callsDecline : l10n.callsHangUp,
                  danger: true,
                  onTap: () => incoming ? controller.decline() : controller.hangUp(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({super.key, required this.icon, required this.label, required this.onTap, this.active = false, this.danger = false, this.toggled});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool danger;

  /// On / off for screen readers (the mic: highlighted when muted, on when live).
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    final pal = context.callPalette;
    final bg = danger ? pal.danger : (active ? pal.activeFill : pal.glassStrong);
    final fg = danger ? CallPalette.ink : (active ? pal.activeInk : CallPalette.ink);
    // 40 dp circle inside a 48 dp hit area (fits the 64 dp card).
    return Semantics(
      button: true,
      toggled: toggled,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: Material(
              color: bg,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox.square(dimension: 40, child: Icon(icon, size: 18, color: fg)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
