import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/localization/localization.dart';
import '../../../core/platform/desktop.dart';
import '../../../core/platform/desktop_settings.dart';
import '../../../shared/utils/diagnostic_log.dart';
import 'calls_providers.dart';
import 'widgets/call_stage.dart';
import 'widgets/call_style.dart';

/// Where the mini window goes: the bottom right of [screen] (the work area)
/// with a margin (pure, unit-tested).
Rect miniCallBounds(Rect screen, {Size size = DesktopMiniCall.size, double margin = 16}) => Rect.fromLTWH(
  screen.right - size.width - margin,
  screen.bottom - size.height - margin,
  size.width,
  size.height,
);

/// The desktop call in a small always-on-top window: when XatBox loses the
/// focus during a call (the person went to another program), the window
/// shrinks to the call's video with «Микрофон», «Завершить» and «Развернуть»
/// in the bottom right corner of the screen; «Развернуть» or the end of the
/// call bring the window back as it was.
class DesktopMiniCall extends Notifier<bool> with WindowListener {
  static const size = Size(360, 220);

  Rect? _restore;
  bool _wasMaximized = false;
  bool _busy = false;

  @override
  bool build() {
    if (!isDesktop) return false;
    windowManager.addListener(this);
    ref.onDispose(() => windowManager.removeListener(this));
    ref.listen(callControllerProvider.select((s) => s.inCall), (_, inCall) {
      if (!inCall && state) unawaited(expand());
    });
    return false;
  }

  @override
  void onWindowBlur() {
    if (state || _busy) return;
    if (!ref.read(desktopSettingsProvider).miniCallWindow) return;
    if (!ref.read(callControllerProvider).inCall) return;
    unawaited(_shrink());
  }

  Future<void> _shrink() async {
    _busy = true;
    try {
      // A short blur (a file dialog, the tray menu) is not leaving the app.
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!ref.mounted || !ref.read(callControllerProvider).inCall || await windowManager.isFocused()) return;
      // Hidden to the tray: nothing to shrink.
      if (!await windowManager.isVisible() || await windowManager.isMinimized()) return;
      _wasMaximized = await windowManager.isMaximized();
      _restore = await windowManager.getBounds();
      final screen = await _screenOf(_restore!);
      state = true;
      if (_wasMaximized) await windowManager.unmaximize();
      await windowManager.setMinimumSize(size);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setBounds(miniCallBounds(screen));
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'mini call window failed', error: e);
    } finally {
      _busy = false;
    }
  }

  /// The window was maximized while small («□» in its title bar): the full
  /// app at that size, not the small call stretched over the screen.
  @override
  void onWindowMaximize() {
    if (!state || _busy) return;
    unawaited(_leave());
  }

  Future<void> _leave() async {
    _busy = true;
    try {
      state = false;
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setMinimumSize(desktopMinWindowSize);
      await windowManager.focus();
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'mini call window not left', error: e);
    } finally {
      _busy = false;
    }
  }

  /// Back to the full window, as it was.
  Future<void> expand() async {
    if (!state || _busy) return;
    _busy = true;
    try {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setMinimumSize(desktopMinWindowSize);
      final restore = _restore;
      if (restore != null) await windowManager.setBounds(restore);
      if (_wasMaximized) await windowManager.maximize();
      state = false;
      await windowManager.focus();
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'mini call window not restored', error: e);
      state = false;
    } finally {
      _busy = false;
    }
  }

  static Future<Rect> _screenOf(Rect window) async {
    final displays = await screenRetriever.getAllDisplays();
    Rect area(Display d) => (d.visiblePosition ?? Offset.zero) & (d.visibleSize ?? d.size);
    for (final d in displays) {
      if (area(d).contains(window.center)) return area(d);
    }
    return displays.isEmpty ? window : area(displays.first);
  }
}

final desktopMiniCallProvider = NotifierProvider<DesktopMiniCall, bool>(DesktopMiniCall.new);

/// Shows the mini call instead of the app while the window is small; the
/// app stays mounted (at its normal size, offstage) so nothing is lost.
class DesktopMiniCallHost extends ConsumerWidget {
  const DesktopMiniCallHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isDesktop) return child;
    final mini = ref.watch(desktopMiniCallProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: mini,
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: mini ? desktopMinWindowSize.width : null,
            maxWidth: mini ? desktopMinWindowSize.width : null,
            minHeight: mini ? desktopMinWindowSize.height : null,
            maxHeight: mini ? desktopMinWindowSize.height : null,
            child: child,
          ),
        ),
        // The app's overlays live under its navigator, offstage now: the
        // small call brings its own (the buttons' tooltips need one).
        if (mini) Overlay.wrap(child: const _MiniCallView()),
      ],
    );
  }
}

class _MiniCallView extends ConsumerWidget {
  const _MiniCallView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.callPalette;
    final micOn = ref.watch(callControllerProvider.select((s) => s.micOn));
    final call = ref.read(callControllerProvider.notifier);
    Widget button(IconData icon, String tip, VoidCallback onTap, {Color? color}) => Tooltip(
      message: tip,
      child: Material(
        color: color ?? Colors.black54,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(9), child: Icon(icon, size: 18, color: Colors.white)),
        ),
      ),
    );
    return Material(
      color: palette.bgBottom,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Drag anywhere on the video to move the window; a double click
          // brings the full window back (DragToMoveArea would maximize the
          // small call instead).
          GestureDetector(
            key: const Key('mini_call_video'),
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => unawaited(windowManager.startDragging()),
            onDoubleTap: () => unawaited(ref.read(desktopMiniCallProvider.notifier).expand()),
            child: const CallPipStage(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                button(
                  micOn ? LucideIcons.mic : LucideIcons.micOff,
                  micOn ? l10n.desktopMiniCallMute : l10n.desktopMiniCallUnmute,
                  () => unawaited(call.setMic(!micOn)),
                ),
                const SizedBox(width: 10),
                button(LucideIcons.phoneOff, l10n.desktopMiniCallEnd, () => unawaited(call.hangUp()), color: const Color(0xFFDC2626)),
                const SizedBox(width: 10),
                button(LucideIcons.maximize2, l10n.desktopMiniCallExpand, () => unawaited(ref.read(desktopMiniCallProvider.notifier).expand())),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
