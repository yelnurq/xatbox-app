import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import '../../shared/utils/diagnostic_log.dart';
import '../auth/auth_providers.dart';
import 'desktop_keys.dart';

/// Desktop zoom: the whole interface scaled like a browser page
/// (Ctrl+= / Ctrl+- / Ctrl+0, Настройки → Оформление → «Масштаб»).
/// Kept in its own record so the phone's preferences stay untouched.
abstract final class DesktopZoom {
  static const steps = [0.8, 0.9, 1.0, 1.1, 1.25, 1.5];
  static const normal = 1.0;

  /// The step after [current] in [direction] (+1 / -1), clamped (pure).
  static double step(double current, int direction) {
    var i = steps.indexWhere((s) => (s - current).abs() < 0.001);
    if (i < 0) i = steps.indexOf(normal);
    return steps[(i + direction).clamp(0, steps.length - 1)];
  }

  static String label(double zoom) => '${(zoom * 100).round()}%';
}

class DesktopZoomNotifier extends Notifier<double> {
  static final _store = stringMapStoreFactory.store('settings');
  static const _key = 'desktop';

  @override
  double build() {
    _load();
    return DesktopZoom.normal;
  }

  Future<void> _load() async {
    try {
      final raw = await _store.record(_key).get(ref.read(appDatabaseProvider).db);
      final z = raw?['zoom'];
      if (z is num && DesktopZoom.steps.contains(z.toDouble())) state = z.toDouble();
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'zoom not read', error: e);
    }
  }

  Future<void> set(double zoom) async {
    if (zoom == state) return;
    state = zoom;
    try {
      await _store.record(_key).put(ref.read(appDatabaseProvider).db, {'zoom': zoom}, merge: true);
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'zoom not saved', error: e);
    }
  }

  void zoomIn() => set(DesktopZoom.step(state, 1));
  void zoomOut() => set(DesktopZoom.step(state, -1));
  void reset() => set(DesktopZoom.normal);
}

final desktopZoomProvider = NotifierProvider<DesktopZoomNotifier, double>(DesktopZoomNotifier.new);

/// Lays the app out at `size / zoom` and paints it scaled by [zoom], so
/// every widget, dialog and overlay grows together (text stays vector-sharp).
class DesktopZoomBox extends StatelessWidget {
  const DesktopZoomBox({super.key, required this.zoom, required this.child});

  final double zoom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if ((zoom - 1).abs() < 0.001) return child;
    final mq = MediaQuery.of(context);
    final size = mq.size / zoom;
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: size.width,
        maxWidth: size.width,
        minHeight: size.height,
        maxHeight: size.height,
        child: Transform.scale(
          scale: zoom,
          alignment: Alignment.topLeft,
          child: MediaQuery(
            data: mq.copyWith(
              size: size,
              padding: mq.padding / zoom,
              viewPadding: mq.viewPadding / zoom,
              viewInsets: mq.viewInsets / zoom,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Desktop: Ctrl+= / Ctrl+- / Ctrl+0 anywhere (the sign-in screen too) and
/// the zoom itself around the whole app. Phones get [child] unchanged.
class DesktopZoomScope extends ConsumerWidget {
  const DesktopZoomScope({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled) return child;
    final zoom = ref.watch(desktopZoomProvider);
    final notifier = ref.read(desktopZoomProvider.notifier);
    return CallbackShortcuts(
      bindings: {
        commandShortcut(LogicalKeyboardKey.equal): notifier.zoomIn,
        commandShortcut(LogicalKeyboardKey.equal, shift: true): notifier.zoomIn,
        commandShortcut(LogicalKeyboardKey.numpadAdd): notifier.zoomIn,
        commandShortcut(LogicalKeyboardKey.minus): notifier.zoomOut,
        commandShortcut(LogicalKeyboardKey.numpadSubtract): notifier.zoomOut,
        commandShortcut(LogicalKeyboardKey.digit0): notifier.reset,
        commandShortcut(LogicalKeyboardKey.numpad0): notifier.reset,
      },
      // Keys reach the bindings even when no field has focus.
      child: Focus(
        autofocus: true,
        child: DesktopZoomBox(zoom: zoom, child: child),
      ),
    );
  }
}
