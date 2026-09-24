import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/platform/desktop.dart';
import '../../../core/platform/desktop_keys.dart';
import '../../../core/platform/desktop_layout.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/localization/localization.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../chat/presentation/chat_providers.dart';
import '../data/call_media.dart';
import '../data/call_models.dart';
import 'call_controller.dart';
import 'calls_format.dart';
import 'calls_providers.dart';
import 'widgets/call_chat.dart';
import 'widgets/call_lobby.dart';
import 'widgets/call_quality.dart';
import 'widgets/call_recording.dart';
import 'widgets/call_sheets.dart';
import 'widgets/call_stage.dart';
import 'widgets/call_style.dart';

export 'widgets/call_stage.dart' show callGridColumns;

/// Below this width the dock drops «flip camera» (it moves to «Ещё»).
const callDockNarrowWidth = 400.0;

/// Desktop tooltip of a call button: its label and keys, «Микрофон (M, Ctrl+D)».
String _withKeys(String label, List<String> keys) => '$label (${keys.join(', ')})';

/// Desktop keys of the call screen, as written in the tooltips.
abstract final class _CallKeys {
  static List<String> get mic => ['M', '$commandKeyLabel+D'];
  static List<String> get camera => ['V', '$commandKeyLabel+E'];
  static List<String> get hangUp => ['$commandKeyLabel+Shift+H'];
  static List<String> get chat => ['$commandKeyLabel+Shift+C'];
  static List<String> get participants => ['$commandKeyLabel+Shift+P'];
}

/// Camera on / off; a snack bar when it cannot start.
Future<void> _toggleCamera(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final cameraOn = ref.read(callControllerProvider).cameraOn;
  if (!await ref.read(callControllerProvider.notifier).setCamera(!cameraOn) && !cameraOn) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.callsCameraUnavailable)));
  }
}

/// Incoming / outgoing / active call (ТЗ п.24.10–24.13): an always-dark
/// immersive stage tinted by the skin. Back (gesture or the chevron)
/// minimises the call into the floating mini bar ([CallOverlayHost]).
///
/// Only small widgets watch narrow slices of the call state: the timer ticks
/// in its own element, speaking updates rebuild tiles, not the controls.
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  bool _closing = false;
  late final CallScreenPresence _presence;

  @override
  void initState() {
    super.initState();
    // Providers must not change while the tree builds: defer.
    _presence = ref.read(callScreenPresenceProvider.notifier);
    Future.microtask(_presence.enter);
  }

  @override
  void dispose() {
    final presence = _presence;
    Future.microtask(presence.leave);
    super.dispose();
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.canPop()) context.pop();
    });
  }

  void _minimise() {
    if (!mounted || _closing) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.calls);
    }
  }

  /// «Написать» from the ended summary: the chat replaces the call screen.
  Future<void> _openChat(String userId) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final controller = ref.read(callControllerProvider.notifier)..keepEnded();
    try {
      final conv = await ref.read(chatRepositoryProvider).createDirect(userId);
      if (!mounted) return;
      _closing = true;
      unawaited(router.pushReplacement(Routes.chatConversationPath(conv.id)));
      controller.dismiss();
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(CallsFormat.error(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final phase = ref.watch(callControllerProvider.select((s) => s.phase));
    if (phase == CallPhase.idle) {
      _close();
      return const Scaffold(body: SizedBox.shrink());
    }
    final palette = context.callPalette;
    // Android PiP window: remote video only, no controls.
    if (ref.watch(callPipModeProvider) && phase != CallPhase.ended) {
      return Scaffold(
        backgroundColor: palette.bgBottom,
        body: const Stack(
          fit: StackFit.expand,
          children: [
            CallPipStage(),
            Positioned(top: 6, left: 6, child: CallRecIndicator(compact: true)),
          ],
        ),
      );
    }
    final Widget view = switch (phase) {
      CallPhase.incoming => _IncomingView(key: const ValueKey('incoming'), onMinimise: _minimise),
      CallPhase.ended => _EndedView(key: const ValueKey('ended'), onMessage: _openChat),
      _ => _InCallView(key: const ValueKey('in_call'), onMinimise: _minimise),
    };
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: palette.bgBottom,
        body: DefaultTextStyle.merge(
          style: const TextStyle(color: CallPalette.ink),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOut,
            layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
            child: view,
          ),
        ),
      ),
    );
  }
}

/// Round frosted icon button of the top bar.
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed, this.badge});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final pal = context.callPalette;
    final l10n = context.l10n;
    // 44 dp glass circle inside a 48 dp hit area (taps on the margin count).
    return Semantics(
      button: true,
      label: tooltip,
      value: badge == null ? null : l10n.a11yHandsRaised(badge!),
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 48,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                CallGlass(
                  radius: 22,
                  blur: 16,
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: onPressed,
                      child: SizedBox.square(dimension: 44, child: Icon(icon, color: CallPalette.ink, size: 22)),
                    ),
                  ),
                ),
                if (badge != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(color: pal.warning, borderRadius: BorderRadius.circular(9)),
                      alignment: Alignment.center,
                      child: Text(
                        '$badge',
                        style: TextStyle(color: pal.bgBottom, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Incoming
// ---------------------------------------------------------------------------

class _IncomingView extends ConsumerWidget {
  const _IncomingView({super.key, required this.onMinimise});
  final VoidCallback onMinimise;

  Future<void> _declineWithMessage(BuildContext context, WidgetRef ref, String callerId) async {
    final text = await showCallQuickReplySheet(context);
    if (text == null || !context.mounted) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(chatRepositoryProvider);
    unawaited(ref.read(callControllerProvider.notifier).decline());
    try {
      final conv = await repo.createDirect(callerId);
      await repo.sendText(conv.id, text);
      messenger.showSnackBar(SnackBar(content: Text(l10n.callsQuickReplySent)));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(CallsFormat.error(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final pal = context.callPalette;
    final tokens = context.tokens;
    final hero = ref.watch(callHeroProvider);
    final video = ref.watch(callControllerProvider.select((s) => s.video));
    final callerId = ref.watch(callControllerProvider.select((s) => s.call?.callerId));
    final controller = ref.read(callControllerProvider.notifier);
    final size = MediaQuery.sizeOf(context);
    final radius = (size.shortestSide * 0.19).clamp(40.0, 84.0);
    final buttons = size.width < 360 ? 64.0 : 72.0;
    final desktop = ref.watch(desktopLayoutProvider);
    final view = Stack(
      fit: StackFit.expand,
      children: [
        CallBackdrop(colorKey: hero.group ? null : (hero.colorKey ?? hero.title)),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    _GlassIconButton(key: const Key('call_minimize'), icon: LucideIcons.chevronDown, tooltip: l10n.callsMinimize, onPressed: onMinimise),
                    const Spacer(),
                    CallChip(
                      icon: video ? LucideIcons.video : (hero.group ? LucideIcons.users : LucideIcons.phone),
                      label: video ? l10n.callsVideo : (hero.group ? l10n.callsGroupCall : l10n.callsAudio),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CallAvatar(label: hero.title, colorKey: hero.colorKey, email: hero.email, group: hero.group, radius: radius, rings: true),
                        const SizedBox(height: Space.smd),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                          child: Text(
                            hero.title,
                            key: const Key('call_title'),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: CallPalette.ink,
                              fontFamily: tokens.fontDisplay,
                              fontSize: 30,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: Space.xs + 2),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            video ? l10n.callsIncomingVideo : l10n.callsIncoming,
                            key: const Key('call_status'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: pal.inkSecondary, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!hero.group && callerId != null && callerId.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
                  child: CallGlass(
                    radius: 22,
                    blur: 16,
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        key: const Key('call_decline_message'),
                        onTap: () => _declineWithMessage(context, ref, callerId),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.smd - 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const ExcludeSemantics(child: Icon(LucideIcons.messageSquareText, size: 18, color: CallPalette.ink)),
                                const SizedBox(width: Space.sm),
                                Flexible(
                                  child: Text(
                                    l10n.callsDeclineWithMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: CallPalette.ink, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    CallRoundButton(
                      key: const Key('call_decline'),
                      icon: LucideIcons.phoneOff,
                      label: l10n.callsDecline,
                      tone: CallButtonTone.danger,
                      size: buttons,
                      tooltip: desktop ? _withKeys(l10n.callsDecline, const ['Esc']) : null,
                      onPressed: () => controller.decline(),
                    ),
                    _Bounce(
                      child: CallRoundButton(
                        key: const Key('call_accept'),
                        icon: video ? LucideIcons.video : LucideIcons.phone,
                        label: l10n.callsAccept,
                        tone: CallButtonTone.success,
                        size: buttons,
                        tooltip: desktop ? _withKeys(l10n.callsAccept, const ['Enter']) : null,
                        onPressed: () => controller.accept(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
    if (!desktop) return view;
    // Desktop: Enter answers, Esc declines.
    return DesktopKeyBindings(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): () => controller.accept(),
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () => controller.accept(),
        const SingleActivator(LogicalKeyboardKey.escape): () => controller.decline(),
      },
      child: view,
    );
  }
}

/// Gentle hop of the accept button while ringing.
class _Bounce extends StatefulWidget {
  const _Bounce({required this.child});
  final Widget child;

  @override
  State<_Bounce> createState() => _BounceState();
}

class _BounceState extends State<_Bounce> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (callAnimationsEnabled(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (_, child) {
      // Two quick hops, then rest.
      final t = _c.value;
      final hop = t < 0.4 ? math.sin(t / 0.4 * math.pi * 2).abs() * (1 - t / 0.4) : 0.0;
      return Transform.translate(offset: Offset(0, -8 * hop), child: child);
    },
  );
}

// ---------------------------------------------------------------------------
// Outgoing / connecting / active
// ---------------------------------------------------------------------------

class _InCallView extends ConsumerStatefulWidget {
  const _InCallView({super.key, required this.onMinimise});
  final VoidCallback onMinimise;

  @override
  ConsumerState<_InCallView> createState() => _InCallViewState();
}

class _InCallViewState extends ConsumerState<_InCallView> {
  static const _topBar = 64.0;
  static const _dock = 112.0;
  bool _chrome = true;
  bool _autoHide = false;

  /// A screen reader is on: the controls never hide (they must stay reachable).
  bool _a11y = false;
  Timer? _hide;

  static bool _videoStage(CallSessionState s) => s.cameraOn || s.participants.any((p) => !p.isLocal && (p.cameraOn || p.screenSharing));

  @override
  void initState() {
    super.initState();
    // Controls hide after a few seconds on an active video call.
    ref.listenManual<bool>(callControllerProvider.select((s) => s.phase == CallPhase.active && _videoStage(s)), (_, next) {
      _autoHide = next;
      if (next) {
        _arm();
      } else {
        _hide?.cancel();
        if (!_chrome && mounted) setState(() => _chrome = true);
      }
    }, fireImmediately: true);
    // Desktop: a new call starts without the last call's participants panel.
    if (ref.read(desktopLayoutProvider)) {
      final panel = ref.read(callParticipantsPanelOpenProvider.notifier);
      Future.microtask(() => panel.set(false));
    }
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  /// Desktop keys of a call (as desktop meeting apps): microphone, camera,
  /// hang up, the chat and participants panels.
  Map<ShortcutActivator, VoidCallback> _keys(bool group) {
    final controller = ref.read(callControllerProvider.notifier);
    void mic() => controller.setMic(!ref.read(callControllerProvider).micOn);
    void camera() => unawaited(_toggleCamera(context, ref));
    return {
      const SingleActivator(LogicalKeyboardKey.keyM): mic,
      commandShortcut(LogicalKeyboardKey.keyD): mic,
      const SingleActivator(LogicalKeyboardKey.keyV): camera,
      commandShortcut(LogicalKeyboardKey.keyE): camera,
      commandShortcut(LogicalKeyboardKey.keyH, shift: true): () => controller.hangUp(),
      commandShortcut(LogicalKeyboardKey.keyC, shift: true): () => unawaited(openCallChat(context)),
      if (group) commandShortcut(LogicalKeyboardKey.keyP, shift: true): () => toggleCallParticipantsPanel(context),
    };
  }

  void _arm() {
    _hide?.cancel();
    if (!_autoHide || _a11y) return;
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted && _autoHide && !_a11y) setState(() => _chrome = false);
    });
  }

  /// Desktop: moving the mouse brings the controls back (and re-arms the
  /// auto-hide), as in desktop meeting apps.
  void _onPointerMove() {
    if (!_autoHide || _a11y) return;
    if (!_chrome) setState(() => _chrome = true);
    _arm();
  }

  void _onStageTap() {
    if (!_autoHide || _a11y) return;
    if (_chrome) {
      _hide?.cancel();
      setState(() => _chrome = false);
    } else {
      setState(() => _chrome = true);
      _arm();
    }
  }

  @override
  Widget build(BuildContext context) {
    final showStage = ref.watch(callControllerProvider.select((s) => s.phase == CallPhase.active || s.participants.any((p) => !p.isLocal)));
    final group = ref.watch(callControllerProvider.select((s) => s.call?.isGroup ?? false));
    final videoStage = ref.watch(callControllerProvider.select(_videoStage));
    final hero = ref.watch(callHeroProvider);
    final heroMode = !showStage || (!group && !videoStage);
    final pad = MediaQuery.paddingOf(context);
    _a11y = MediaQuery.accessibleNavigationOf(context);
    if (_a11y) _hide?.cancel();
    final chrome = _chrome || !_autoHide || _a11y;
    final desktop = ref.watch(desktopLayoutProvider);
    // Desktop: the participants list takes the chat's place on the right.
    final participantsPanel = desktop && group && ref.watch(callParticipantsPanelOpenProvider);
    // Wide layouts: the chat is a panel on the right and the stage shrinks.
    final sidePanel = participantsPanel || (callChatAsSidePanel(context) && ref.watch(callChatPanelOpenProvider));
    final panelSpace = sidePanel ? callChatSidePanelWidth + Space.smd * 2 : 0.0;
    final insets = EdgeInsets.only(
      left: pad.left,
      right: pad.right + panelSpace,
      top: pad.top + (chrome ? _topBar : 8),
      bottom: pad.bottom + (chrome ? _dock : 8),
    );
    const anim = Duration(milliseconds: 280);

    final view = MouseRegion(
      onHover: isDesktop ? (_) => _onPointerMove() : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CallBackdrop(colorKey: videoStage || hero.group ? null : (hero.colorKey ?? hero.title)),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _onStageTap,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
              child: heroMode
                  ? _HeroView(key: const ValueKey('hero'), ringing: !showStage, insets: insets)
                  : CallStage(key: const ValueKey('stage'), insets: insets),
            ),
          ),
          const IgnorePointer(child: _ReactionsLayer()),
          if (sidePanel)
            Positioned(
              top: pad.top + _topBar,
              bottom: pad.bottom + _dock,
              right: pad.right + Space.smd,
              width: callChatSidePanelWidth,
              child: participantsPanel ? const CallParticipantsSidePanel() : const CallChatSidePanel(),
            ),
          // «REC • 00:12» stays visible for everyone, even with hidden controls.
          AnimatedPositioned(
            duration: anim,
            curve: Curves.easeOutCubic,
            top: pad.top + (chrome ? _topBar : Space.sm),
            left: pad.left,
            right: pad.right + panelSpace,
            child: const IgnorePointer(child: Center(child: CallRecIndicator())),
          ),
          Positioned(
            top: pad.top + _topBar + 32,
            left: pad.left + Space.md,
            right: pad.right + Space.md + panelSpace,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CallRecordingBanner(),
                  CallLobbyBanner(onOpen: () => showCallParticipantsSheet(context)),
                  const CallQualityPromptBanner(),
                ],
              ),
            ),
          ),
          AnimatedPositioned(
            duration: anim,
            curve: Curves.easeOutCubic,
            left: pad.left + Space.md,
            right: pad.right + Space.md + panelSpace,
            bottom: pad.bottom + (chrome ? _dock : 8) + Space.sm,
            child: const Align(alignment: Alignment.bottomLeft, child: CallChatToasts()),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _Chrome(
              visible: chrome,
              fromTop: true,
              child: _TopBar(onMinimise: widget.onMinimise, headline: !heroMode),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _Chrome(
              visible: chrome,
              fromTop: false,
              child: Listener(onPointerDown: (_) => _arm(), child: const _ControlDock()),
            ),
          ),
        ],
      ),
    );
    if (!desktop) return view;
    return DesktopKeyBindings(bindings: _keys(group), child: view);
  }
}

/// Slides the top bar / dock away when the controls auto-hide.
class _Chrome extends StatelessWidget {
  const _Chrome({required this.visible, required this.fromTop, required this.child});
  final bool visible;
  final bool fromTop;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSlide(
    offset: visible ? Offset.zero : Offset(0, fromTop ? -1.2 : 1.2),
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOutCubic,
    child: AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 220),
      child: IgnorePointer(ignoring: !visible, child: child),
    ),
  );
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.onMinimise, required this.headline});
  final VoidCallback onMinimise;

  /// Title and status / timer (the hero shows them otherwise).
  final bool headline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final pal = context.callPalette;
    final group = ref.watch(callControllerProvider.select((s) => s.call?.isGroup ?? false));
    final quality = ref.watch(callControllerProvider.select((s) => s.quality));
    final hands = ref.watch(callControllerProvider.select((s) => s.raisedHands.length));
    final layout = ref.watch(callLayoutProvider);
    final title = ref.watch(callHeroProvider.select((h) => h.title));
    final desktop = ref.watch(desktopLayoutProvider);
    final wide = MediaQuery.sizeOf(context).width > 420;
    final weak = switch (quality) {
      LinkQuality.poor => (LucideIcons.activity, pal.warning, l10n.callsQualityPoor),
      LinkQuality.lost => (LucideIcons.wifiOff, pal.danger, l10n.callsQualityLost),
      _ => null,
    };
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        // Grows with large text instead of overflowing.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              _GlassIconButton(key: const Key('call_minimize'), icon: LucideIcons.chevronDown, tooltip: l10n.callsMinimize, onPressed: onMinimise),
              const SizedBox(width: Space.smd),
              Expanded(
                child: AnimatedOpacity(
                  opacity: headline ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: headline
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: CallPalette.ink, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            CallStatusLine(style: TextStyle(color: pal.inkSecondary, fontSize: 13)),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              if (weak != null)
                Padding(
                  padding: const EdgeInsets.only(left: Space.sm),
                  child: Tooltip(
                    message: weak.$3,
                    child: CallChip(key: const Key('call_quality'), icon: weak.$1, iconColor: weak.$2, label: wide ? weak.$3 : ''),
                  ),
                ),
              if (group && headline) ...[
                const SizedBox(width: Space.sm),
                _GlassIconButton(
                  key: const Key('call_layout'),
                  icon: layout == CallLayout.grid ? LucideIcons.layoutPanelTop : LucideIcons.layoutGrid,
                  tooltip: layout == CallLayout.grid ? l10n.callsLayoutSpotlight : l10n.callsLayoutGrid,
                  onPressed: ref.read(callLayoutProvider.notifier).toggle,
                ),
              ],
              if (group) ...[
                const SizedBox(width: Space.sm),
                _GlassIconButton(
                  key: const Key('call_participants'),
                  icon: LucideIcons.users,
                  tooltip: desktop ? _withKeys(l10n.callsParticipants, _CallKeys.participants) : l10n.callsParticipants,
                  badge: hands > 0 ? hands : null,
                  onPressed: desktop ? () => toggleCallParticipantsPanel(context) : () => showCallParticipantsSheet(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar, name and status (ringing, with pulse rings) or the voice glow of
/// a 1:1 audio call. For a video call, the local camera fills the back.
class _HeroView extends ConsumerWidget {
  const _HeroView({super.key, required this.ringing, required this.insets});
  final bool ringing;
  final EdgeInsets insets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.callPalette;
    final tokens = context.tokens;
    final hero = ref.watch(callHeroProvider);
    final cameraBehind = ringing && ref.watch(callControllerProvider.select((s) => s.cameraOn));
    final level = ringing ? 0.0 : ref.watch(callControllerProvider.select((s) => callVoiceLevel(s.participants.where((p) => !p.isLocal).firstOrNull)));
    final size = MediaQuery.sizeOf(context);
    final radius = size.height < 560 ? 40.0 : (size.shortestSide * 0.17).clamp(44.0, 76.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (cameraBehind) ...[
          const CallLocalCamera(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [pal.scrim, pal.bgBottom.withValues(alpha: 0.15), pal.scrim],
              ),
            ),
          ),
        ],
        AnimatedPadding(
          duration: const Duration(milliseconds: 260),
          padding: insets,
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CallAvatar(label: hero.title, colorKey: hero.colorKey, email: hero.email, group: hero.group, radius: radius, rings: ringing, level: level),
                  const SizedBox(height: Space.smd),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    child: Text(
                      hero.title,
                      key: const Key('call_title'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: CallPalette.ink,
                        fontFamily: tokens.fontDisplay,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.xs + 2),
                  CallStatusLine(
                    style: TextStyle(color: pal.inkSecondary, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  if (hero.group && ringing) const _InviteesRow(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Overlapping avatars of the people being rung in a group call.
class _InviteesRow extends ConsumerWidget {
  const _InviteesRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.callPalette;
    final selfId = ref.watch(currentUserProvider)?.id ?? '';
    final others = ref.watch(callPeopleProvider).values.where((p) => p.userId != selfId).toList();
    if (others.isEmpty) return const SizedBox.shrink();
    const shown = 5;
    final visible = others.take(shown).toList();
    return Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: SizedBox(
              height: 36,
              width: 26.0 * visible.length + 10,
              child: Stack(
                children: [
                  for (final (i, p) in visible.indexed)
                    Positioned(
                      left: 26.0 * i,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: pal.bgTop, shape: BoxShape.circle),
                        child: InitialsAvatar(label: p.label, colorKey: p.userId, radius: 16),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (others.length > shown)
            Padding(
              padding: const EdgeInsets.only(left: Space.xs),
              child: Text(
                '+${others.length - shown}',
                style: TextStyle(color: pal.inkSecondary, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

/// Frosted control dock: microphone, camera, flip, sound, more, hang up.
class _ControlDock extends ConsumerWidget {
  const _ControlDock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(callControllerProvider.notifier);
    final micOn = ref.watch(callControllerProvider.select((s) => s.micOn));
    final cameraOn = ref.watch(callControllerProvider.select((s) => s.cameraOn));
    final speakerOn = ref.watch(callControllerProvider.select((s) => s.speakerOn));
    final group = ref.watch(callControllerProvider.select((s) => s.call?.isGroup ?? false));
    final moderator = ref.watch(callControllerProvider.select((s) => s.call?.isModerator ?? false));
    final unread = ref.watch(callControllerProvider.select((s) => s.chatUnread));
    final chatPanel = callChatAsSidePanel(context) && ref.watch(callChatPanelOpenProvider);
    // Phones: flipping the camera lives in «Ещё» so the dock keeps usable buttons.
    final narrow = MediaQuery.sizeOf(context).width < callDockNarrowWidth;
    // Desktop: the buttons' keys in their tooltips.
    final keys = ref.watch(desktopLayoutProvider)
        ? <Key, String>{
            const Key('call_mic'): _withKeys(l10n.callsMic, _CallKeys.mic),
            const Key('call_camera'): _withKeys(l10n.callsCamera, _CallKeys.camera),
            const Key('call_chat'): _withKeys(l10n.callsChat, _CallKeys.chat),
            const Key('call_hangup'): _withKeys(group ? l10n.callsLeave : l10n.callsHangUp, _CallKeys.hangUp),
          }
        : const <Key, String>{};

    final specs = <({Key key, IconData icon, String label, bool active, bool? toggled, int badge, VoidCallback onTap})>[
      (
        key: const Key('call_mic'),
        icon: micOn ? LucideIcons.mic : LucideIcons.micOff,
        label: l10n.callsMic,
        active: !micOn,
        // Highlighted when muted, but for screen readers «on» means the mic is on.
        toggled: micOn,
        badge: 0,
        onTap: () => controller.setMic(!micOn),
      ),
      (
        key: const Key('call_camera'),
        icon: cameraOn ? LucideIcons.video : LucideIcons.videoOff,
        label: l10n.callsCamera,
        active: cameraOn,
        toggled: cameraOn,
        badge: 0,
        onTap: () async {
          final messenger = ScaffoldMessenger.of(context);
          if (!await controller.setCamera(!cameraOn) && !cameraOn) {
            messenger.showSnackBar(SnackBar(content: Text(l10n.callsCameraUnavailable)));
          }
        },
      ),
      if (cameraOn && !narrow)
        (
          key: const Key('call_switch_camera'),
          icon: LucideIcons.switchCamera,
          label: l10n.callsSwitchCamera,
          active: false,
          toggled: null,
          badge: 0,
          onTap: () => controller.switchCamera(),
        ),
      (
        key: const Key('call_chat'),
        icon: LucideIcons.messageCircle,
        label: l10n.callsChat,
        active: chatPanel,
        toggled: null,
        badge: unread,
        onTap: () => openCallChat(context),
      ),
      (
        key: const Key('call_audio_route'),
        // Desktop: output devices, no speaker / earpiece.
        icon: isDesktop ? LucideIcons.headphones : (speakerOn ? LucideIcons.volume2 : LucideIcons.ear),
        label: isDesktop ? l10n.callsAudioSettings : l10n.callsSpeaker,
        active: speakerOn,
        // Opens the sound sheet: not a toggle.
        toggled: null,
        badge: 0,
        onTap: () => showCallAudioSheet(context),
      ),
      (
        key: const Key('call_more'),
        icon: LucideIcons.ellipsis,
        label: l10n.callsMore,
        active: false,
        toggled: null,
        badge: 0,
        onTap: () => showCallMoreSheet(context),
      ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.smd, 0, Space.smd, Space.sm),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: CallGlass(
              radius: 32,
              strong: true,
              padding: const EdgeInsets.fromLTRB(Space.xs, Space.smd, Space.xs, Space.sm),
              child: LayoutBuilder(
                builder: (context, box) {
                  const hangFactor = 1.4;
                  final slot = math.min(84.0, box.maxWidth / (specs.length + hangFactor));
                  final size = math.min(56.0, slot - 8);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final s in specs)
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CallRoundButton(
                              key: s.key,
                              icon: s.icon,
                              label: s.label,
                              active: s.active,
                              toggled: s.toggled,
                              semanticValue: s.badge > 0 ? l10n.a11yUnreadCount(s.badge) : null,
                              size: size,
                              labelWidth: slot - 1,
                              tooltip: keys[s.key],
                              onPressed: s.onTap,
                            ),
                            if (s.badge > 0)
                              Positioned(
                                top: -4,
                                right: math.max(0, (slot - 1 - size) / 2 - 6),
                                // Read as the button's value instead.
                                child: IgnorePointer(
                                  child: ExcludeSemantics(
                                    child: CallCountBadge(key: const Key('call_chat_badge'), count: s.badge),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      CallRoundButton(
                        key: const Key('call_hangup'),
                        icon: LucideIcons.phoneOff,
                        label: group ? l10n.callsLeave : l10n.callsHangUp,
                        tone: CallButtonTone.danger,
                        size: size,
                        width: size * 1.35,
                        labelWidth: slot * hangFactor - 1,
                        tooltip: keys[const Key('call_hangup')],
                        onPressed: () => controller.hangUp(),
                        onLongPress: group && moderator ? () => controller.hangUp(forAll: true) : null,
                        onLongPressHint: l10n.callsEndForAll,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Emoji reactions floating up over the stage.
class _ReactionsLayer extends ConsumerStatefulWidget {
  const _ReactionsLayer();

  @override
  ConsumerState<_ReactionsLayer> createState() => _ReactionsLayerState();
}

class _Floating {
  _Floating(this.reaction, this.dx, this.controller);
  final CallReaction reaction;
  final double dx;
  final AnimationController controller;

  /// Reduced motion: removes the static emoji.
  Timer? timer;
}

class _ReactionsLayerState extends ConsumerState<_ReactionsLayer> with TickerProviderStateMixin {
  final _items = <_Floating>[];
  final _rng = math.Random();
  StreamSubscription<CallReaction>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(callControllerProvider.notifier).reactions.listen(_add);
  }

  void _add(CallReaction r) {
    if (!mounted || _items.length >= 14) return;
    final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
    final item = _Floating(r, 0.58 + _rng.nextDouble() * 0.3, c);
    setState(() => _items.add(item));
    void done() {
      if (!mounted) return;
      setState(() => _items.remove(item));
      c.dispose();
    }

    if (!callAnimationsEnabled(context)) {
      // Reduced motion: a brief static emoji mid-way, no float.
      c.value = 0.5;
      item.timer = Timer(const Duration(milliseconds: 2800), done);
      return;
    }
    c.forward().whenComplete(done);
  }

  @override
  void dispose() {
    _sub?.cancel();
    for (final i in _items) {
      i.timer?.cancel();
      i.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final people = ref.watch(callPeopleProvider);
    // Decorative (the sender is not announced either).
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (_, box) => Stack(
          children: [
            for (final item in _items)
              AnimatedBuilder(
                animation: item.controller,
                builder: (_, child) {
                  final t = item.controller.value;
                  final opacity = t < 0.08 ? t / 0.08 : (t > 0.7 ? (1 - t) / 0.3 : 1.0);
                  final scale = t < 0.18 ? Curves.easeOutBack.transform(t / 0.18) : 1.0;
                  return Positioned(
                    left: box.maxWidth * item.dx + math.sin(t * math.pi * 3) * 10,
                    bottom: box.maxHeight * (0.2 + 0.5 * Curves.easeOut.transform(t)),
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Transform.scale(scale: scale, child: child),
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item.reaction.emoji, style: const TextStyle(fontSize: 40)),
                    if (!item.reaction.local) CallChip(label: people[item.reaction.identity.split('#').first]?.label ?? '', dense: true),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ended
// ---------------------------------------------------------------------------

class _EndedView extends ConsumerStatefulWidget {
  const _EndedView({super.key, required this.onMessage});
  final Future<void> Function(String userId) onMessage;

  @override
  ConsumerState<_EndedView> createState() => _EndedViewState();
}

class _EndedViewState extends ConsumerState<_EndedView> {
  Duration? _duration;
  bool _kept = false;

  static const _failures = {
    CallEndReasons.declined,
    CallEndReasons.busy,
    CallEndReasons.missed,
    CallEndReasons.failed,
    CallEndReasons.network,
    CallEndReasons.removed,
    CallEndReasons.permission,
  };

  @override
  void initState() {
    super.initState();
    final s = ref.read(callControllerProvider);
    final seconds = s.call?.durationSec ?? 0;
    if (s.connectedAt != null) {
      _duration = seconds > 0 ? Duration(seconds: seconds) : DateTime.now().difference(s.connectedAt!);
    }
  }

  /// Any touch keeps the summary open (no auto-close).
  void _keep() {
    if (_kept) return;
    ref.read(callControllerProvider.notifier).keepEnded();
    setState(() => _kept = true);
  }

  void _redial(CallInfo call, List<CallParticipantInfo> others, bool video) {
    final controller = ref.read(callControllerProvider.notifier)..keepEnded();
    unawaited(
      controller.startCall(
        calleeIds: others.map((p) => p.userId).toList(),
        video: video,
        conversationId: call.conversationId,
        mode: call.mode,
        title: call.title.isEmpty ? null : call.title,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A screen reader user needs time to hear the summary: no auto-close.
    if (!_kept && MediaQuery.accessibleNavigationOf(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _keep();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pal = context.callPalette;
    final tokens = context.tokens;
    final animate = callAnimationsEnabled(context);
    final reason = ref.watch(callControllerProvider.select((s) => s.endReason));
    final video = ref.watch(callControllerProvider.select((s) => s.video));
    final call = ref.watch(callControllerProvider.select((s) => s.call));
    final hero = ref.watch(callHeroProvider);
    final selfId = ref.watch(currentUserProvider)?.id ?? '';
    final enabled = ref.watch(callsEnabledProvider);
    final others = call?.others(selfId) ?? const <CallParticipantInfo>[];
    final direct = call != null && !call.isGroup && others.length == 1;
    final failure = _failures.contains(reason);
    final controller = ref.read(callControllerProvider.notifier);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _keep(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CallBackdrop(colorKey: hero.group || call == null ? null : (hero.colorKey ?? hero.title)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Space.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (call != null) ...[
                        CallAvatar(label: hero.title, colorKey: hero.colorKey, email: hero.email, group: hero.group, radius: 44),
                        const SizedBox(height: Space.xs),
                        Text(
                          hero.title,
                          key: const Key('call_title'),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: CallPalette.ink, fontFamily: tokens.fontDisplay, fontSize: 24, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: Space.mlg),
                      ],
                      CallGlass(
                        radius: 24,
                        padding: const EdgeInsets.all(Space.mlg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                ExcludeSemantics(
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: failure ? pal.danger.withValues(alpha: 0.22) : pal.glassStrong),
                                    child: Icon(
                                      reason == CallEndReasons.permission ? LucideIcons.micOff : (failure ? LucideIcons.phoneMissed : LucideIcons.phoneOff),
                                      color: failure ? pal.danger : CallPalette.ink,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: Space.smd),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        CallsFormat.endReason(l10n, reason),
                                        key: const Key('call_status'),
                                        style: const TextStyle(color: CallPalette.ink, fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                                      if (_duration != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: Space.xxs),
                                          child: Row(
                                            children: [
                                              Icon(LucideIcons.timer, size: 14, color: pal.inkTertiary),
                                              const SizedBox(width: Space.xs),
                                              Text(
                                                CallsFormat.duration(_duration!),
                                                key: const Key('call_ended_duration'),
                                                style: TextStyle(color: pal.inkSecondary, fontSize: 14, fontFeatures: const [FontFeature.tabularFigures()]),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              child: _kept || reason == CallEndReasons.permission
                                  ? const SizedBox(width: double.infinity)
                                  : Padding(
                                      padding: const EdgeInsets.only(top: Space.md),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: TweenAnimationBuilder<double>(
                                          // Reduced motion: a static bar.
                                          tween: animate ? Tween(begin: 1, end: 0) : Tween(begin: 1, end: 1),
                                          duration: animate ? const Duration(seconds: 3) : Duration.zero,
                                          builder: (_, v, _) =>
                                              LinearProgressIndicator(value: v, minHeight: 3, backgroundColor: pal.glass, color: pal.inkTertiary),
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      if (reason == CallEndReasons.permission)
                        Padding(
                          padding: const EdgeInsets.only(top: Space.md),
                          child: FilledButton.icon(
                            key: const Key('call_open_settings'),
                            onPressed: () => ref.read(callNativeProvider).openSettings(),
                            icon: const Icon(LucideIcons.settings, size: 18),
                            label: Text(l10n.chatOpenSettings),
                          ),
                        ),
                      const SizedBox(height: Space.lg),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: Space.lg,
                        runSpacing: Space.smd,
                        children: [
                          if (call != null && enabled && others.isNotEmpty && reason != CallEndReasons.removed)
                            CallRoundButton(
                              key: const Key('call_redial'),
                              icon: video ? LucideIcons.video : LucideIcons.phone,
                              label: l10n.callsRedial,
                              tone: CallButtonTone.success,
                              onPressed: () => _redial(call, others, video),
                            ),
                          if (direct && enabled)
                            CallRoundButton(
                              key: const Key('call_message'),
                              icon: LucideIcons.messageCircle,
                              label: l10n.callsDetailsMessage,
                              onPressed: () => widget.onMessage(others.single.userId),
                            ),
                          CallRoundButton(key: const Key('call_close'), icon: LucideIcons.x, label: l10n.callsClose, onPressed: controller.dismiss),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
