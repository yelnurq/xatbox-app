import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Route name marking a full-window viewer (photos, videos): the desktop
/// shell goes dark around it as if the viewer covered the whole window.
const desktopFullscreenRouteName = 'desktop:fullscreen';

/// The desktop shell (module rail, folder sidebar, top bar) sits above the
/// router's navigator, so a dialog's barrier or a full-window viewer used to
/// stop at the page and leave the shell bright. This observer of the root
/// navigator tells the shell which open route shades it, with that route's
/// own animation, so both fade together.
class DesktopModalObserver extends NavigatorObserver with ChangeNotifier {
  DesktopModalObserver._();

  static final instance = DesktopModalObserver._();

  final _routes = <Route<dynamic>>[];

  /// The route shading the shell now: the topmost dialog / sheet with a
  /// barrier, or a full-window viewer; null when a page is on top.
  ModalRoute<dynamic>? get shade {
    for (final r in _routes.reversed) {
      if (r is! ModalRoute || !r.isActive) continue;
      if (r.settings.name == desktopFullscreenRouteName) return r;
      if (r is PopupRoute) {
        final c = r.barrierColor;
        if (c != null && c.a > 0) return r;
        continue; // menus: no barrier, look underneath
      }
      if (r.opaque) return null;
    }
    return null;
  }

  /// The colour to paint over the shell for [route] at full animation.
  static Color colorFor(ModalRoute<dynamic> route) => route.settings.name == desktopFullscreenRouteName
      ? const Color(0xFF0B0F14)
      : (route is PopupRoute ? route.barrierColor ?? Colors.transparent : Colors.transparent);

  void _changed() {
    // Navigator callbacks arrive mid-build: repaint the shell afterwards.
    SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (i >= 0 && newRoute != null) {
      _routes[i] = newRoute;
    } else if (newRoute != null) {
      _routes.add(newRoute);
    }
    if (i < 0 && oldRoute != null) _routes.remove(oldRoute);
    _changed();
  }
}

/// Paints the shading route's barrier over [child] (a part of the desktop
/// shell), fading with the route; a click dismisses it when the route
/// allows that (the same rule as its own barrier).
class DesktopShellShade extends StatelessWidget {
  const DesktopShellShade({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: DesktopModalObserver.instance,
    builder: (context, _) {
      final route = DesktopModalObserver.instance.shade;
      final animation = route?.animation;
      return Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          if (route != null && animation != null)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final color = DesktopModalObserver.colorFor(route);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: route.barrierDismissible ? () => route.navigator?.maybePop() : null,
                    child: ColoredBox(color: color.withValues(alpha: color.a * animation.value)),
                  );
                },
              ),
            ),
        ],
      );
    },
  );
}
