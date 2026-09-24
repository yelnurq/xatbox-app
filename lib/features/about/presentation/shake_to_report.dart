import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/routes.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../chat/presentation/chat_providers.dart';
import '../data/feedback_api.dart';

/// The app content below the lock / update gates (screenshots for reports).
final screenshotBoundaryKey = GlobalKey(debugLabel: 'screenshot');

/// PNG of the current screen, or null when it cannot be captured.
Future<FeedbackScreenshot?> captureScreen({double pixelRatio = 1.5}) async {
  try {
    final boundary = screenshotBoundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) return null;
    return FeedbackScreenshot(Uint8List.view(data.buffer), filename: 'screen.png');
  } on Object catch (e) {
    DiagnosticLog.warn('feedback', 'screen capture failed', error: e);
    return null;
  }
}

/// «Встряхните, чтобы сообщить о проблеме» (device setting, off by default).
class ShakeToReportSetting extends Notifier<bool> {
  static final _store = stringMapStoreFactory.store('settings');
  static const _key = 'shake_to_report';

  @override
  bool build() {
    unawaited(_load());
    return false;
  }

  Future<void> _load() async {
    try {
      final v = await _store.record(_key).get(ref.read(appDatabaseProvider).db);
      if (ref.mounted && v?['enabled'] == true) state = true;
    } on Object catch (e) {
      DiagnosticLog.warn('feedback', 'shake setting not read', error: e);
    }
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    try {
      await _store.record(_key).put(ref.read(appDatabaseProvider).db, {'enabled': enabled});
    } on Object catch (e) {
      DiagnosticLog.warn('feedback', 'shake setting not saved', error: e);
    }
  }
}

final shakeToReportProvider = NotifierProvider<ShakeToReportSetting, bool>(
  ShakeToReportSetting.new,
);

/// Accelerometer samples; tests override it.
final shakeSamplesProvider = Provider<Stream<List<double>>>((_) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
    return const Stream.empty();
  }
  return userAccelerometerEventStream(samplingPeriod: SensorInterval.uiInterval)
      .map((e) => [e.x, e.y, e.z]);
});

/// Two strong jolts (user acceleration above [threshold] m/s²) within
/// [window]; then quiet for [cooldown].
class ShakeDetector {
  ShakeDetector({
    this.threshold = 13,
    this.window = const Duration(milliseconds: 700),
    this.cooldown = const Duration(seconds: 3),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final double threshold;
  final Duration window;
  final Duration cooldown;
  final DateTime Function() _clock;
  DateTime? _firstJolt;
  DateTime? _lastShake;

  /// True when this sample completes a shake.
  bool add(List<double> xyz) {
    final g = math.sqrt(xyz.fold<double>(0, (s, v) => s + v * v));
    if (g < threshold) return false;
    final now = _clock();
    if (_lastShake != null && now.difference(_lastShake!) < cooldown) return false;
    final first = _firstJolt;
    if (first == null || now.difference(first) > window) {
      _firstJolt = now;
      return false;
    }
    // Ignore samples of the same jolt (< 120 ms apart).
    if (now.difference(first) < const Duration(milliseconds: 120)) return false;
    _firstJolt = null;
    _lastShake = now;
    return true;
  }
}

/// Listens for a shake while enabled and signed in; captures the screen and
/// opens «Сообщить о проблеме» with it attached.
class ShakeToReport extends ConsumerStatefulWidget {
  const ShakeToReport({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ShakeToReport> createState() => _ShakeToReportState();
}

class _ShakeToReportState extends ConsumerState<ShakeToReport> {
  StreamSubscription<List<double>>? _sub;
  final _detector = ShakeDetector();
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<bool>(shakeToReportProvider, (_, enabled) => _listen(enabled), fireImmediately: true);
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  /// sensors_plus throws «No active stream to cancel» from cancel() when the
  /// native sensor stream already stopped (app backgrounded, sensor
  /// unavailable); the future is fire-and-forget, so it must not escape to
  /// the zone as a crash report.
  void _cancel() {
    final sub = _sub;
    _sub = null;
    if (sub == null) return;
    unawaited(
      sub.cancel().catchError((Object e) {
        DiagnosticLog.warn('feedback', 'accelerometer cancel failed', error: e);
      }),
    );
  }

  void _listen(bool enabled) {
    _cancel();
    if (!enabled || !ref.read(chatEnabledProvider)) return;
    _sub = ref.read(shakeSamplesProvider).listen(
      (xyz) {
        if (_detector.add(xyz)) unawaited(_open());
      },
      onError: (Object e) => DiagnosticLog.warn('feedback', 'accelerometer unavailable', error: e),
    );
  }

  Future<void> _open() async {
    if (_opening || !ref.read(authSessionProvider).isAuthenticated) return;
    final router = ref.read(appRouterProvider);
    if (router.routeInformationProvider.value.uri.path == Routes.reportProblem) return;
    _opening = true;
    try {
      unawaited(HapticFeedback.mediumImpact());
      final shot = await captureScreen();
      if (mounted) await router.push(Routes.reportProblem, extra: shot);
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(key: screenshotBoundaryKey, child: widget.child);
  }
}
