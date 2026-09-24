import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/localization/localization.dart';
import '../../data/call_media.dart';
import '../../data/call_models.dart';
import '../../data/meetings.dart';
import '../call_controller.dart';
import '../calls_providers.dart';
import 'call_style.dart';

/// Grid columns for [count] tiles on one page.
int callGridColumns(int count) => count <= 1 ? 1 : (count <= 4 ? 2 : (count <= 9 ? 3 : 4));

/// Who the call is with, as the hero / backdrop / mini bar need it. Only
/// changes when the call object changes (not on speaking or timer updates).
typedef CallHero = ({String title, String? colorKey, String email, bool group});

final callHeroProvider = Provider<CallHero>((ref) {
  final call = ref.watch(callControllerProvider.select((s) => s.call));
  final selfId = ref.watch(currentUserProvider)?.id ?? '';
  final group = call?.isGroup ?? false;
  final other = call?.others(selfId).firstOrNull;
  return (title: call?.displayTitle(selfId) ?? '', colorKey: group ? null : other?.userId, email: group ? '' : (other?.email ?? ''), group: group);
});

/// Call participants by user id, memoised per call update.
final callPeopleProvider = Provider<Map<String, CallParticipantInfo>>((ref) {
  final list = ref.watch(callControllerProvider.select((s) => s.call?.participants));
  return {for (final p in list ?? const <CallParticipantInfo>[]) p.userId: p};
});

/// Voice-activity level for the glow, quantised so small audio level jitter
/// does not rebuild anything.
double callVoiceLevel(MediaParticipant? p) {
  if (p == null || !p.speaking || !p.micOn) return 0;
  final l = math.max(0.4, math.min(1.0, p.audioLevel * 1.8));
  return (l * 5).round() / 5;
}

enum CallLayout { grid, spotlight }

class CallLayoutNotifier extends Notifier<CallLayout> {
  @override
  CallLayout build() => CallLayout.grid;

  void toggle() => state = state == CallLayout.grid ? CallLayout.spotlight : CallLayout.grid;
}

/// Group call layout; kept while the call is minimised.
final callLayoutProvider = NotifierProvider<CallLayoutNotifier, CallLayout>(CallLayoutNotifier.new);

/// Status while waiting (`Вызов…`, …) or the running timer.
class CallStatusLine extends ConsumerWidget {
  const CallStatusLine({super.key, this.style, this.textAlign, this.withKeys = true});
  final TextStyle? style;
  final TextAlign? textAlign;

  /// `call_status` / `call_timer` keys (the call screen only).
  final bool withKeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final phase = ref.watch(callControllerProvider.select((s) => s.phase));
    final since = ref.watch(callControllerProvider.select((s) => s.connectedAt));
    final status = switch (phase) {
      CallPhase.outgoing => l10n.callsCalling,
      CallPhase.connecting => l10n.callsConnecting,
      CallPhase.reconnecting => l10n.callsReconnecting,
      _ => null,
    };
    if (status != null) {
      return CallStatusText(status, key: withKeys ? const Key('call_status') : null, style: style, textAlign: textAlign);
    }
    if (since != null) return CallTimerText(key: withKeys ? const Key('call_timer') : null, since: since, style: style);
    return const SizedBox.shrink();
  }
}

/// Stage of a connected call: 1:1 full-screen video with a draggable
/// preview, screen share with a filmstrip, group grid or speaker spotlight.
class CallStage extends ConsumerStatefulWidget {
  const CallStage({super.key, required this.insets});

  /// Space taken by the top bar and the control dock (animated).
  final EdgeInsets insets;

  @override
  ConsumerState<CallStage> createState() => _CallStageState();
}

class _CallStageState extends ConsumerState<CallStage> {
  static const _anim = Duration(milliseconds: 260);
  int _page = 0;
  bool _swapped = false;
  String? _pinned;
  String? _lastSpeaker;

  @override
  Widget build(BuildContext context) {
    final participants = ref.watch(callControllerProvider.select((s) => s.participants));
    final group = ref.watch(callControllerProvider.select((s) => s.call?.isGroup ?? false));
    final hands = ref.watch(callControllerProvider.select((s) => s.raisedHands));
    final myHand = ref.watch(callControllerProvider.select((s) => s.handRaised));
    final people = ref.watch(callPeopleProvider);
    final layout = ref.watch(callLayoutProvider);
    // Tiles rendered with video at once (server `max_video_tiles`); the
    // rest get no renderer, so LiveKit adaptive stream pauses their video.
    final tilesPerPage = ref.watch(callsConfigProvider.select((c) => c.maxVideoTiles));
    final media = ref.read(callControllerProvider.notifier).media;

    final local = participants.where((p) => p.isLocal).firstOrNull;
    final remote = [
      for (final p in participants)
        if (!p.isLocal) p,
    ];
    final sharer = participants.where((p) => p.screenSharing).firstOrNull;
    final speaker = remote.where((p) => p.speaking).firstOrNull;
    if (speaker != null) _lastSpeaker = speaker.identity;

    Widget tile(MediaParticipant p, {bool video = true, bool large = false, double radius = 18, bool compact = false, VoidCallback? onTap}) => CallTile(
      participant: p,
      media: video ? media : null,
      info: people[p.userId],
      handRaised: p.isLocal ? myHand : hands.contains(p.identity),
      large: large,
      radius: radius,
      compact: compact,
      onTap: onTap,
    );

    final String kind;
    final Widget child;
    if (sharer != null && media != null) {
      kind = 'share';
      final everyone = [?local, ...remote];
      child = AnimatedPadding(
        duration: _anim,
        padding: widget.insets.add(const EdgeInsets.symmetric(horizontal: 6)),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: ColoredBox(
                  key: const Key('screen_share_view'),
                  color: Colors.black,
                  child: RepaintBoundary(child: media.videoView(sharer, screenShare: true)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            _Filmstrip(
              count: everyone.length,
              builder: (i) => tile(everyone[i], video: i < tilesPerPage, compact: true, radius: 14),
            ),
          ],
        ),
      );
    } else if (!group && remote.length <= 1) {
      kind = 'direct';
      final other = remote.firstOrNull;
      if (local?.cameraOn != true || other == null) _swapped = false;
      final main = _swapped ? local : other;
      final small = _swapped ? other : (local?.cameraOn == true ? local : null);
      child = Stack(
        fit: StackFit.expand,
        children: [
          if (main != null) tile(main, large: true, radius: 0),
          if (small != null && other != null)
            CallDraggablePreview(insets: widget.insets, onTap: () => setState(() => _swapped = !_swapped), child: tile(small, compact: true, radius: 18)),
        ],
      );
    } else if (layout == CallLayout.spotlight) {
      kind = 'spotlight';
      final everyone = [?local, ...remote];
      final focus =
          everyone.where((p) => p.identity == _pinned).firstOrNull ??
          remote.where((p) => p.identity == _lastSpeaker).firstOrNull ??
          remote.where((p) => p.cameraOn).firstOrNull ??
          remote.firstOrNull ??
          local;
      final strip = [
        for (final p in everyone)
          if (p.identity != focus?.identity) p,
      ];
      child = AnimatedPadding(
        duration: _anim,
        padding: widget.insets.add(const EdgeInsets.symmetric(horizontal: 6)),
        child: Column(
          children: [
            Expanded(
              child: focus == null
                  ? const SizedBox.shrink()
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: KeyedSubtree(
                        key: ValueKey('focus_${focus.identity}'),
                        child: tile(focus, radius: 20, onTap: () => setState(() => _pinned = _pinned == focus.identity ? null : focus.identity)),
                      ),
                    ),
            ),
            if (strip.isNotEmpty) ...[
              const SizedBox(height: 6),
              _Filmstrip(
                count: strip.length,
                builder: (i) =>
                    tile(strip[i], video: i < tilesPerPage - 1, compact: true, radius: 14, onTap: () => setState(() => _pinned = strip[i].identity)),
              ),
            ],
          ],
        ),
      );
    } else {
      kind = 'grid';
      final everyone = [?local, ...remote];
      final pages = math.max(1, (everyone.length / tilesPerPage).ceil());
      final page = _page.clamp(0, pages - 1);
      child = AnimatedPadding(
        duration: _anim,
        padding: widget.insets.add(const EdgeInsets.symmetric(horizontal: 6)),
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                key: const Key('call_grid_pages'),
                itemCount: pages,
                onPageChanged: (p) => setState(() => _page = p),
                itemBuilder: (_, p) {
                  final tiles = everyone.skip(p * tilesPerPage).take(tilesPerPage).toList();
                  return LayoutBuilder(
                    builder: (_, box) {
                      const gap = 6.0;
                      final columns = callGridColumns(tiles.length);
                      final rows = math.max(1, (tiles.length / columns).ceil());
                      final w = (box.maxWidth - gap * (columns - 1)) / columns;
                      final h = (box.maxHeight - gap * (rows - 1)) / rows;
                      final ratio = h <= 0 ? 1.0 : (w / h).clamp(0.45, 2.4);
                      return GridView.count(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        crossAxisCount: columns,
                        mainAxisSpacing: gap,
                        crossAxisSpacing: gap,
                        childAspectRatio: ratio,
                        children: [
                          // Only the visible page builds video renderers.
                          for (final t in tiles) tile(t, video: p == page),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            if (pages > 1) _PageDots(page: page, pages: pages),
          ],
        ),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
      child: KeyedSubtree(key: ValueKey(kind), child: child),
    );
  }
}

class _Filmstrip extends StatelessWidget {
  const _Filmstrip({required this.count, required this.builder});
  final int count;
  final Widget Function(int i) builder;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 112,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(width: 6),
      itemBuilder: (_, i) => SizedBox(width: 84, child: builder(i)),
    ),
  );
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.page, required this.pages});
  final int page;
  final int pages;

  @override
  Widget build(BuildContext context) {
    final p = context.callPalette;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < math.min(pages, 8); i++)
            ExcludeSemantics(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(color: i == page ? CallPalette.ink : p.inkTertiary, borderRadius: BorderRadius.circular(3)),
              ),
            ),
          const SizedBox(width: 8),
          Text(
            '${page + 1} / $pages',
            key: const Key('call_grid_page'),
            style: TextStyle(color: p.inkSecondary, fontSize: 12, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

/// One person on the stage: camera (or avatar with voice glow), name and
/// microphone chip, raised hand, weak-link badge.
class CallTile extends StatelessWidget {
  CallTile({required this.participant, this.media, this.info, this.handRaised = false, this.large = false, this.radius = 18, this.compact = false, this.onTap})
    : super(key: ValueKey('tile_${participant.identity}'));

  final MediaParticipant participant;

  /// Null: no video renderer (hidden page, over the tile limit).
  final CallMediaSession? media;
  final CallParticipantInfo? info;
  final bool handRaised;
  final bool large;
  final double radius;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.callPalette;
    final l10n = context.l10n;
    final p = participant;
    final infoLabel = info?.label ?? '';
    final baseLabel = p.isLocal ? l10n.callsYou : (infoLabel.isNotEmpty ? infoLabel : (p.name.isNotEmpty ? p.name : p.userId));
    // People without an account are marked for everyone.
    final label = !p.isLocal && isGuestIdentity(p.identity) ? '$baseLabel · ${l10n.callsGuest}' : baseLabel;
    final level = callVoiceLevel(p);
    final video = p.cameraOn && media != null;
    final weak = !p.isLocal && (p.quality == LinkQuality.poor || p.quality == LinkQuality.lost);
    final framed = radius > 0;
    final guest = !p.isLocal && isGuestIdentity(p.identity);
    // One node per person: name, guest, muted mic, raised hand, weak link.
    final semanticLabel = [
      baseLabel,
      if (guest) l10n.a11yGuest,
      if (!p.micOn) l10n.a11yMicOff,
      if (handRaised) l10n.callsHandRaised,
      if (weak) p.quality == LinkQuality.poor ? l10n.callsQualityPoor : l10n.callsQualityLost,
    ].join(', ');
    final Widget hand = CallChip(
      key: ValueKey('tile_hand_${p.identity}'),
      icon: LucideIcons.hand,
      iconColor: pal.warning,
      label: compact ? '' : l10n.callsHandRaised,
      dense: compact,
    );
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: framed ? pal.tile : Colors.transparent,
            borderRadius: BorderRadius.circular(radius),
            border: framed ? Border.all(color: level > 0 ? pal.glow : pal.glassBorder, width: level > 0 ? 2.5 : 1) : null,
            boxShadow: framed && level > 0 ? [BoxShadow(color: pal.glow.withValues(alpha: 0.35), blurRadius: 16)] : null,
          ),
          clipBehavior: framed ? Clip.antiAlias : Clip.none,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (video)
                RepaintBoundary(child: media!.videoView(p))
              else
                LayoutBuilder(
                  builder: (_, box) {
                    final r = (box.biggest.shortestSide * (large ? 0.2 : 0.24)).clamp(16.0, 76.0);
                    return Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CallAvatar(label: label, colorKey: p.userId, email: info?.email ?? '', radius: r, level: level),
                            if (large)
                              Text(
                                label,
                                style: const TextStyle(color: CallPalette.ink, fontSize: 22, fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              if (video && !large)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0x73000000), Color(0x00000000)]),
                    ),
                  ),
                ),
              if (handRaised)
                Positioned(
                  top: 8,
                  left: 8,
                  child: callAnimationsEnabled(context)
                      ? TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.6, end: 1),
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeOutBack,
                          builder: (_, s, child) => Transform.scale(scale: s, child: child),
                          child: hand,
                        )
                      : hand,
                ),
              if (weak)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Tooltip(
                    message: p.quality == LinkQuality.poor ? l10n.callsQualityPoor : l10n.callsQualityLost,
                    child: CallChip(
                      key: ValueKey('tile_quality_${p.quality.name}_${p.identity}'),
                      icon: p.quality == LinkQuality.poor ? LucideIcons.activity : LucideIcons.wifiOff,
                      iconColor: p.quality == LinkQuality.poor ? pal.warning : pal.danger,
                      label: '',
                      dense: true,
                    ),
                  ),
                ),
              if (!(large && !video))
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: CallChip(
                      icon: !p.micOn ? LucideIcons.micOff : (level > 0 ? LucideIcons.audioLines : null),
                      iconColor: !p.micOn ? pal.danger : pal.glow,
                      label: label,
                      dense: compact,
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

/// Picture-in-picture of the other video in a 1:1 call: drag it anywhere,
/// it snaps to the nearest corner (following the fling); tap swaps views.
class CallDraggablePreview extends StatefulWidget {
  const CallDraggablePreview({super.key, required this.child, required this.insets, this.onTap});
  final Widget child;
  final EdgeInsets insets;
  final VoidCallback? onTap;

  @override
  State<CallDraggablePreview> createState() => _CallDraggablePreviewState();
}

class _CallDraggablePreviewState extends State<CallDraggablePreview> {
  bool _left = false;
  bool _top = false;
  Offset? _drag;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth < 500 ? 104.0 : 148.0;
        final h = w * 1.42;
        const m = 12.0;
        Offset corner(bool left, bool top) => Offset(
          left ? widget.insets.left + m : box.maxWidth - w - widget.insets.right - m,
          top ? widget.insets.top + m : math.max(0, box.maxHeight - h - widget.insets.bottom - m),
        );
        final rest = corner(_left, _top);
        final pos = _drag ?? rest;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: _drag != null ? Duration.zero : const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              left: pos.dx,
              top: pos.dy,
              width: w,
              height: h,
              child: Semantics(
                button: true,
                label: context.l10n.callsSwapVideo,
                child: GestureDetector(
                  key: const Key('call_local_preview'),
                  onTap: widget.onTap,
                  onPanStart: (_) => setState(() => _drag = rest),
                  onPanUpdate: (d) => setState(() => _drag = (_drag ?? rest) + d.delta),
                  onPanEnd: (d) {
                    final at = (_drag ?? rest) + Offset(w / 2, h / 2) + d.velocity.pixelsPerSecond * 0.12;
                    setState(() {
                      _left = at.dx < box.maxWidth / 2;
                      _top = at.dy < box.maxHeight / 2;
                      _drag = null;
                    });
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 20, offset: Offset(0, 8))],
                    ),
                    child: widget.child,
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

/// This device's camera full screen (behind the ringing hero of a video call).
class CallLocalCamera extends ConsumerWidget {
  const CallLocalCamera({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(callControllerProvider.select((s) => s.participants.where((p) => p.isLocal && p.cameraOn).firstOrNull?.identity));
    final media = ref.read(callControllerProvider.notifier).media;
    if (identity == null || media == null) return const SizedBox.shrink();
    return RepaintBoundary(
      child: media.videoView(MediaParticipant(identity: identity, name: '', isLocal: true, cameraOn: true)),
    );
  }
}

/// Compact stage for the PiP window: a remote screen share, else the active
/// speaker's (or any) remote camera, else the remote avatar.
class CallPipStage extends ConsumerWidget {
  const CallPipStage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participants = ref.watch(callControllerProvider.select((s) => s.participants));
    final hero = ref.watch(callHeroProvider);
    final people = ref.watch(callPeopleProvider);
    final media = ref.read(callControllerProvider.notifier).media;
    final remote = participants.where((p) => !p.isLocal).toList();
    final sharer = remote.where((p) => p.screenSharing).firstOrNull;
    final shown = remote.where((p) => p.speaking && p.cameraOn).firstOrNull ?? remote.where((p) => p.cameraOn).firstOrNull ?? remote.firstOrNull;
    final Widget child;
    if (media != null && sharer != null) {
      child = media.videoView(sharer, screenShare: true);
    } else if (media != null && shown != null && shown.cameraOn) {
      child = media.videoView(shown);
    } else {
      final label = shown == null ? hero.title : (people[shown.userId]?.label ?? shown.name);
      child = Stack(
        fit: StackFit.expand,
        children: [
          CallBackdrop(colorKey: shown?.userId ?? hero.colorKey),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: CallAvatar(label: label, colorKey: shown?.userId, radius: 32, level: callVoiceLevel(shown), group: shown == null && hero.group),
            ),
          ),
        ],
      );
    }
    return SizedBox.expand(key: const Key('call_pip_stage'), child: child);
  }
}
