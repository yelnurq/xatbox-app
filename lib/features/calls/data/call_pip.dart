import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../../shared/utils/diagnostic_log.dart';

/// Android Picture-in-Picture for video calls, behind an interface (a fake in
/// tests). Everything is a no-op on other platforms.
abstract class CallPip {
  Future<bool> isSupported();

  /// Enters PiP now; false when not possible (not supported, not resumed).
  Future<bool> enter();

  /// Lets the system enter PiP by itself when the user leaves the app
  /// (home gesture, recents) — Android 12+ auto-enter, older onUserLeaveHint.
  Future<void> setAutoEnter(bool enabled);

  /// PiP mode changes reported by the activity.
  Stream<bool> get modeChanges;
}

/// `xatbox/pip` MethodChannel of `MainActivity`: `isSupported`, `enter`,
/// `setAutoEnter`; the activity calls `pipChanged(bool)` back.
class MethodChannelCallPip implements CallPip {
  MethodChannelCallPip({MethodChannel channel = const MethodChannel('xatbox/pip'), bool? android})
    : _channel = channel, // ignore: prefer_initializing_formals
      _android = android ?? Platform.isAndroid;

  final MethodChannel _channel;
  final bool _android;
  final _modes = StreamController<bool>.broadcast();
  bool _handlerSet = false;

  void _ensureHandler() {
    if (_handlerSet || !_android) return;
    _handlerSet = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'pipChanged') _modes.add(call.arguments == true);
    });
  }

  Future<T?> _invoke<T>(String method, [Object? args]) async {
    if (!_android) return null;
    _ensureHandler();
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'pip $method failed', error: e);
      return null;
    }
  }

  @override
  Future<bool> isSupported() async => await _invoke<bool>('isSupported') ?? false;

  @override
  Future<bool> enter() async => await _invoke<bool>('enter') ?? false;

  @override
  Future<void> setAutoEnter(bool enabled) async {
    await _invoke<void>('setAutoEnter', {'enabled': enabled});
  }

  @override
  Stream<bool> get modeChanges {
    _ensureHandler();
    return _modes.stream;
  }
}
