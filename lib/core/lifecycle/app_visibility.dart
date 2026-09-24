import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app is visible to the user.
///
/// `resumed` and `inactive` count as foreground (a system dialog, the
/// notification shade, Android picture-in-picture); `hidden`, `paused` and
/// `detached` count as background. Behind an interface so policies can be
/// driven by a fake in tests.
abstract class AppVisibility {
  bool get isForeground;

  /// Emits on every foreground ↔ background transition (never repeats).
  Stream<bool> get changes;

  void dispose();
}

/// Production visibility from the widgets binding.
class BindingAppVisibility implements AppVisibility {
  BindingAppVisibility() {
    try {
      final binding = WidgetsBinding.instance;
      final state = binding.lifecycleState;
      _foreground = state == null || isVisibleState(state);
      _listener = AppLifecycleListener(binding: binding, onStateChange: _onState);
    } on Object {
      // No binding (plain Dart tests): always foreground, never changes.
      _foreground = true;
    }
  }

  static bool isVisibleState(AppLifecycleState s) =>
      s == AppLifecycleState.resumed || s == AppLifecycleState.inactive;

  AppLifecycleListener? _listener;
  bool _foreground = true;
  final _changes = StreamController<bool>.broadcast(sync: true);

  void _onState(AppLifecycleState state) {
    final fg = isVisibleState(state);
    if (fg == _foreground) return;
    _foreground = fg;
    _changes.add(fg);
  }

  @override
  bool get isForeground => _foreground;

  @override
  Stream<bool> get changes => _changes.stream;

  @override
  void dispose() {
    _listener?.dispose();
    unawaited(_changes.close());
  }
}

/// Manually driven visibility for tests.
class FakeAppVisibility implements AppVisibility {
  FakeAppVisibility({bool foreground = true}) : _foreground = foreground; // ignore: prefer_initializing_formals

  bool _foreground;
  final _changes = StreamController<bool>.broadcast(sync: true);

  void set({required bool foreground}) {
    if (foreground == _foreground) return;
    _foreground = foreground;
    _changes.add(foreground);
  }

  @override
  bool get isForeground => _foreground;

  @override
  Stream<bool> get changes => _changes.stream;

  @override
  void dispose() => unawaited(_changes.close());
}

final appVisibilityProvider = Provider<AppVisibility>((ref) {
  final v = BindingAppVisibility();
  ref.onDispose(v.dispose);
  return v;
});

/// A periodic timer that only runs while the app is in the foreground: it is
/// cancelled when the app is hidden (no background wake-ups) and re-armed on
/// return. With [catchUpOnResume] a tick that fell due while hidden fires
/// right away on return instead of waiting a full period.
class ForegroundPeriodic {
  ForegroundPeriodic(
    this._visibility,
    this.every,
    this._tick, {
    this.catchUpOnResume = true,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _last = _now();
    _sub = _visibility.changes.listen(_onChange);
    if (_visibility.isForeground) _arm();
  }

  final AppVisibility _visibility;
  final Duration every;
  final void Function() _tick;
  final bool catchUpOnResume;
  final DateTime Function() _now;

  late DateTime _last;
  Timer? _timer;
  StreamSubscription<bool>? _sub;
  bool _disposed = false;

  /// True while the underlying timer is armed (tests).
  bool get isRunning => _timer != null;

  void _arm() {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => _fire());
  }

  void _fire() {
    if (_disposed) return;
    _last = _now();
    _tick();
  }

  void _onChange(bool foreground) {
    if (_disposed) return;
    if (!foreground) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer != null) return;
    if (catchUpOnResume && _now().difference(_last) >= every) _fire();
    if (!_disposed) _arm();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    unawaited(_sub?.cancel());
  }
}

/// Keeps a background connection (the chat WebSocket) alive for a grace
/// period after the app is hidden, then suspends it until the app returns.
///
/// * [grace] `null` means «always stay connected»;
/// * while [busy] is true (an active or ringing call) the connection is never
///   suspended; call [reevaluate] when it changes, and the grace period
///   restarts from that moment;
/// * return to the foreground resumes at once; [wake] (a push arrived)
///   resumes too and, if still hidden, restarts the grace period.
class BackgroundConnectionPolicy {
  BackgroundConnectionPolicy({
    required AppVisibility visibility,
    required Duration? Function() grace,
    required bool Function() busy,
    required void Function() suspend,
    required void Function() resume,
  }) : _visibility = visibility, // ignore: prefer_initializing_formals
       _grace = grace, // ignore: prefer_initializing_formals
       _busy = busy, // ignore: prefer_initializing_formals
       _suspend = suspend, // ignore: prefer_initializing_formals
       _resume = resume; // ignore: prefer_initializing_formals

  final AppVisibility _visibility;
  final Duration? Function() _grace;
  final bool Function() _busy;
  final void Function() _suspend;
  final void Function() _resume;

  StreamSubscription<bool>? _sub;
  Timer? _timer;
  Duration? _armedGrace;
  bool _suspended = false;
  bool _disposed = false;

  /// The connection is currently suspended by this policy.
  bool get suspended => _suspended;

  /// A grace timer is running (tests).
  bool get graceRunning => _timer != null;

  void start() {
    _sub = _visibility.changes.listen(_onChange);
    if (!_visibility.isForeground) _arm();
  }

  void _onChange(bool foreground) {
    if (_disposed) return;
    if (foreground) {
      _cancelTimer();
      if (_suspended) {
        _suspended = false;
        _resume();
      }
    } else {
      _arm();
    }
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
    _armedGrace = null;
  }

  void _arm() {
    _cancelTimer();
    if (_suspended) return;
    final g = _grace();
    if (g == null) return;
    _armedGrace = g;
    _timer = Timer(g, _expire);
  }

  void _expire() {
    _timer = null;
    _armedGrace = null;
    if (_disposed || _visibility.isForeground || _suspended) return;
    // Busy: stay connected; reevaluate() re-arms once the call is over.
    if (_busy()) return;
    _suspended = true;
    _suspend();
  }

  /// Call when [busy] or [grace] may have changed.
  void reevaluate() {
    if (_disposed || _visibility.isForeground || _suspended) return;
    final g = _grace();
    if (_timer != null && g == _armedGrace) return;
    if (_timer == null && _busy()) return;
    _arm();
  }

  /// Something needs the connection now (e.g. a push arrived).
  void wake() {
    if (_disposed) return;
    if (_suspended) {
      _suspended = false;
      _resume();
    }
    if (!_visibility.isForeground) _arm();
  }

  void dispose() {
    _disposed = true;
    _cancelTimer();
    unawaited(_sub?.cancel());
  }
}
