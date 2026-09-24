import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/notifications/local_notification_hub.dart';
import '../../../core/platform/desktop.dart';
import '../../../core/platform/desktop_shell.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../chat/data/push_notifications.dart';
import 'call_native.dart';

/// Texts of the desktop incoming-call toast (localized by the caller).
class DesktopCallTexts {
  const DesktopCallTexts({
    required this.incoming,
    required this.incomingVideo,
    this.accept = '',
    this.decline = '',
  });
  final String incoming;
  final String incomingVideo;

  /// Windows toast buttons (none when empty).
  final String accept;
  final String decline;
}

/// Desktop builds have no CallKit / ConnectionService: an incoming call
/// raises the window (it may be hidden to the tray) and a toast, and the
/// in-app call screen rings and answers. The OS asks for the microphone and
/// camera itself on first use, so there is nothing to request up front.
class DesktopCallNative implements CallNative {
  DesktopCallNative(this.texts) {
    // «Принять» / «Отклонить» pressed on the Windows toast.
    LocalNotificationHub.onCallAction = (action, callId) {
      if (callId.isEmpty) return;
      _actions.add(
        NativeCallAction(
          action == LocalNotificationHub.callAcceptActionId ? NativeActionType.accept : NativeActionType.decline,
          callId,
        ),
      );
    };
  }

  final DesktopCallTexts texts;
  final _actions = StreamController<NativeCallAction>.broadcast();

  static int _toastId(String callId) => stableNotificationId('call:$callId');

  @override
  Stream<NativeCallAction> get actions => _actions.stream;

  @override
  Stream<void> get voipTokenUpdates => const Stream.empty();

  @override
  Future<String?> voipToken() async => null;

  @override
  Future<void> showIncoming({
    required String callId,
    required String callerName,
    required bool video,
    required Duration ringFor,
  }) async {
    unawaited(bringWindowToFront());
    unawaited(DesktopShell.flash());
    try {
      await LocalNotificationHub.ensureInitialized();
      await FlutterLocalNotificationsPlugin().show(
        id: _toastId(callId),
        title: callerName,
        body: video ? texts.incomingVideo : texts.incoming,
        // macOS: «Принять» / «Отклонить» of the call category act on this id.
        payload: Platform.isMacOS ? callId : null,
        notificationDetails: Platform.isMacOS
            ? const NotificationDetails(
                macOS: DarwinNotificationDetails(
                  categoryIdentifier: LocalNotificationHub.macCallCategoryId,
                  interruptionLevel: InterruptionLevel.timeSensitive,
                ),
              )
            : Platform.isWindows && texts.accept.isNotEmpty
            ? NotificationDetails(
                windows: WindowsNotificationDetails(
                  // Stays on screen like a call; the app itself rings.
                  scenario: WindowsNotificationScenario.incomingCall,
                  audio: WindowsNotificationAudio.silent(),
                  actions: [
                    WindowsAction(
                      content: texts.accept,
                      arguments: LocalNotificationHub.windowsActionArguments(LocalNotificationHub.callAcceptActionId, callId),
                    ),
                    WindowsAction(
                      content: texts.decline,
                      arguments: LocalNotificationHub.windowsActionArguments(LocalNotificationHub.callDeclineActionId, callId),
                    ),
                  ],
                ),
              )
            : null,
      );
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'incoming call toast failed', error: e);
    }
  }

  @override
  Future<void> startOutgoing({required String callId, required String title, required bool video}) async {}

  @override
  Future<void> connected(String callId) => hideIncoming(callId);

  @override
  Future<void> hideIncoming(String callId) async {
    try {
      await FlutterLocalNotificationsPlugin().cancel(id: _toastId(callId));
    } on Object {
      // Nothing shown or the plugin is not initialised: nothing to hide.
    }
  }

  @override
  Future<void> end(String callId) => hideIncoming(callId);

  @override
  Future<List<String>> acceptedCallIds() async => const [];

  @override
  Future<MediaPermission> ensurePermissions({required bool video}) async => MediaPermission.granted;

  @override
  Future<void> requestIncomingCallPermissions() async {}

  /// The OS privacy page for the microphone and camera.
  @override
  Future<void> openSettings() async {
    final uri = Platform.isWindows
        ? Uri.parse('ms-settings:privacy-microphone')
        : Platform.isMacOS
        ? Uri.parse('x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone')
        : null;
    if (uri == null) return;
    try {
      await launchUrl(uri);
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'privacy settings unavailable', error: e);
    }
  }

  @override
  Future<void> keepScreenOn(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'wakelock failed', error: e);
    }
  }
}
