import 'dart:async';
import 'dart:io';

import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/utils/diagnostic_log.dart';

/// What the user did in the system call UI (CallKit / Android notification).
enum NativeActionType { accept, decline, end, timeout, mute, unmute, callback }

class NativeCallAction {
  const NativeCallAction(this.type, this.callId);
  final NativeActionType type;
  final String callId;
}

enum MediaPermission { granted, denied, permanentlyDenied }

/// Texts for the system incoming-call UI (localized by the caller).
class NativeCallTexts {
  const NativeCallTexts({
    required this.appName,
    required this.accept,
    required this.decline,
    required this.incomingChannel,
    required this.missedChannel,
  });
  final String appName;
  final String accept;
  final String decline;
  final String incomingChannel;
  final String missedChannel;
}

String _hex(int argb) => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// CallKit (iOS) / full-screen notification (Android) parameters. The call
/// id is the CallKit UUID, so the same call from WS and from push is shown
/// once. Shared by the app and the background push isolate.
CallKitParams incomingCallParams({
  required String callId,
  required String callerName,
  required bool video,
  required Duration ringFor,
  required NativeCallTexts texts,
}) => CallKitParams(
  id: callId,
  nameCaller: callerName,
  appName: texts.appName,
  handle: callerName,
  type: video ? 1 : 0,
  duration: ringFor.inMilliseconds.clamp(5000, 60000),
  extra: {'call_id': callId},
  // The server sends call.missed itself.
  missedCallNotification: const NotificationParams(showNotification: false),
  android: AndroidParams(
    isCustomNotification: true,
    isShowFullLockedScreen: true,
    isShowCallID: false,
    backgroundColor: _hex(XatBoxTokens.brandSeed.toARGB32()),
    actionColor: _hex(XatBoxTokens.light.success.toARGB32()),
    textColor: _hex(XatBoxTokens.light.onBrand.toARGB32()),
    incomingCallNotificationChannelName: texts.incomingChannel,
    missedCallNotificationChannelName: texts.missedChannel,
    textAccept: texts.accept,
    textDecline: texts.decline,
  ),
  ios: IOSParams(
    handleType: 'generic',
    supportsVideo: true,
    maximumCallGroups: 1,
    maximumCallsPerCallGroup: 1,
    supportsDTMF: false,
    supportsHolding: false,
    supportsGrouping: false,
    supportsUngrouping: false,
    includesCallsInRecents: false,
    audioSessionMode: video ? 'videoChat' : 'voiceChat',
  ),
);

/// Platform call integration behind an interface (fake in tests).
abstract class CallNative {
  Stream<NativeCallAction> get actions;

  /// iOS PushKit token updates (empty on Android).
  Stream<void> get voipTokenUpdates;
  Future<String?> voipToken();

  Future<void> showIncoming({
    required String callId,
    required String callerName,
    required bool video,
    required Duration ringFor,
  });
  Future<void> startOutgoing({required String callId, required String title, required bool video});
  Future<void> connected(String callId);

  /// Stops the system incoming-call ringtone and notification (answered in
  /// the app: Android keeps ringing otherwise).
  Future<void> hideIncoming(String callId);
  Future<void> end(String callId);

  /// Calls accepted in the system UI before the app was running.
  Future<List<String>> acceptedCallIds();

  Future<MediaPermission> ensurePermissions({required bool video});
  Future<void> requestIncomingCallPermissions();
  Future<void> openSettings();
  Future<void> keepScreenOn(bool on);
}

class PluginCallNative implements CallNative {
  PluginCallNative(this.texts);
  final NativeCallTexts texts;

  @override
  Stream<NativeCallAction> get actions => FlutterCallkitIncoming.onEvent
      .map<NativeCallAction?>((e) => switch (e) {
        CallEventActionCallAccept(:final callKitParams) => NativeCallAction(NativeActionType.accept, callKitParams.id),
        CallEventActionCallDecline(:final callKitParams) => NativeCallAction(NativeActionType.decline, callKitParams.id),
        CallEventActionCallEnded(:final callKitParams) => NativeCallAction(NativeActionType.end, callKitParams.id),
        CallEventActionCallTimeout(:final id) => NativeCallAction(NativeActionType.timeout, id),
        CallEventActionCallCallback(:final id) => NativeCallAction(NativeActionType.callback, id),
        CallEventActionCallToggleMute(:final id, :final isMuted) =>
          NativeCallAction(isMuted ? NativeActionType.mute : NativeActionType.unmute, id),
        _ => null,
      })
      .where((a) => a != null)
      .cast<NativeCallAction>();

  @override
  Stream<void> get voipTokenUpdates =>
      FlutterCallkitIncoming.onEvent.where((e) => e is CallEventActionDidUpdateDevicePushTokenVoip);

  @override
  Future<String?> voipToken() async {
    if (!Platform.isIOS) return null;
    final t = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
    return (t == null || t.isEmpty) ? null : t;
  }

  Future<void> _safe(String what, Future<void> Function() f) async {
    try {
      await f();
    } on Object catch (e) {
      DiagnosticLog.warn('calls', '$what failed', error: e);
    }
  }

  @override
  Future<void> showIncoming({
    required String callId,
    required String callerName,
    required bool video,
    required Duration ringFor,
  }) => _safe(
    'show incoming',
    () => FlutterCallkitIncoming.showCallkitIncoming(
      incomingCallParams(callId: callId, callerName: callerName, video: video, ringFor: ringFor, texts: texts),
    ),
  );

  @override
  Future<void> startOutgoing({required String callId, required String title, required bool video}) => _safe(
    'start outgoing',
    () => FlutterCallkitIncoming.startCall(
      CallKitParams(id: callId, nameCaller: title, handle: title, type: video ? 1 : 0, appName: texts.appName),
    ),
  );

  @override
  Future<void> connected(String callId) =>
      _safe('connected', () => FlutterCallkitIncoming.setCallConnected(callId));

  // Android only: on iOS the CallKit screen cannot be hidden without ending
  // the call, and answering there already dismisses it.
  @override
  Future<void> hideIncoming(String callId) async {
    if (!Platform.isAndroid) return;
    await _safe('hide incoming', () => FlutterCallkitIncoming.hideCallkitIncoming(CallKitParams(id: callId)));
  }

  @override
  Future<void> end(String callId) => _safe('end', () => FlutterCallkitIncoming.endCall(callId));

  @override
  Future<List<String>> acceptedCallIds() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      return [for (final c in calls) if (c.isAccepted) c.id];
    } on Object {
      return const [];
    }
  }

  @override
  Future<MediaPermission> ensurePermissions({required bool video}) async {
    final wanted = [Permission.microphone, if (video) Permission.camera];
    var permanently = false;
    for (final p in wanted) {
      final s = await p.request();
      if (s.isGranted || s.isLimited) continue;
      permanently = permanently || s.isPermanentlyDenied;
      return permanently ? MediaPermission.permanentlyDenied : MediaPermission.denied;
    }
    // Bluetooth headsets on Android 12+; not required for the call itself.
    if (Platform.isAndroid) await Permission.bluetoothConnect.request();
    return MediaPermission.granted;
  }

  // Only POST_NOTIFICATIONS here (a no-op once decided). The full-screen
  // intent grant (Android 14+) used to open system settings every time the
  // Calls tab was opened; it is now offered once with an explanation after
  // sign-in and kept in Settings → Уведомления (lib/core/permissions).
  @override
  Future<void> requestIncomingCallPermissions() => _safe('incoming permissions', () async {
    if (!Platform.isAndroid) return;
    await FlutterCallkitIncoming.requestNotificationPermission({
      'title': texts.appName,
      'rationaleMessagePermission': texts.incomingChannel,
    });
  });

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }

  @override
  Future<void> keepScreenOn(bool on) => _safe('wakelock', () => WakelockPlus.toggle(enable: on));
}
