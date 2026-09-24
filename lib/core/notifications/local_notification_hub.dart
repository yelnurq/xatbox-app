import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/chat/data/chat_notification_actions.dart';
import '../../shared/utils/diagnostic_log.dart';
import '../platform/desktop.dart';

/// Returns true when the listener handled the tapped notification's payload.
typedef NotificationTapListener = bool Function(String payload);

/// One process-wide initialisation of flutter_local_notifications.
///
/// The plugin is a singleton with a single tap callback, so every feature
/// that shows local notifications (calendar reminders, decrypted pushes)
/// registers a listener here instead of calling `initialize` itself —
/// otherwise the last caller would swallow the others' taps.
class LocalNotificationHub {
  LocalNotificationHub._();

  /// Payload prefix of notifications rendered from push messages.
  static const pushPayloadPrefix = 'push:';

  /// Windows AppUserModelID of the desktop app (toast sender identity).
  static const windowsAppUserModelId = 'Xatbox.XatBox.Desktop';

  /// Windows toast buttons hand back only their `arguments` (as the payload
  /// and the action id alike), so a button carries both:
  /// `xatbox-action:<action id>|<payload>`.
  static const windowsActionPrefix = 'xatbox-action:';

  static String windowsActionArguments(String actionId, String payload) => '$windowsActionPrefix$actionId|$payload';

  /// The response as the other platforms report it: a button press gets its
  /// action id, payload and typed text (input `reply`) back; a tap on the
  /// toast itself has no action (pure, unit-tested).
  static NotificationResponse normalizeWindowsResponse(NotificationResponse r) {
    final raw = r.payload ?? '';
    if (!raw.startsWith(windowsActionPrefix)) {
      if (r.actionId == null || r.actionId != raw) return r;
      return NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        id: r.id,
        payload: r.payload,
        data: r.data,
      );
    }
    final rest = raw.substring(windowsActionPrefix.length);
    final bar = rest.indexOf('|');
    if (bar <= 0) return r;
    final input = r.data['reply'];
    return NotificationResponse(
      notificationResponseType: NotificationResponseType.selectedNotificationAction,
      id: r.id,
      actionId: rest.substring(0, bar),
      payload: rest.substring(bar + 1),
      input: input is String ? input : r.input,
      data: r.data,
    );
  }

  /// «Принять» / «Отклонить» on a desktop incoming-call toast: the action id
  /// ([callAcceptActionId] / [callDeclineActionId]) and the call id.
  static void Function(String actionId, String callId)? onCallAction;

  static const callAcceptActionId = 'call_accept';
  static const callDeclineActionId = 'call_decline';

  /// macOS: the category of incoming-call notifications (payload: call id).
  static const macCallCategoryId = 'XATBOX_CALL';

  /// «Ответить» / «Прочитано» / «Удалить» on a desktop new-mail toast
  /// (payload `mail:<message id>`).
  static void Function(String actionId, String payload)? onMailAction;

  static const mailReplyActionId = 'mail_reply';
  static const mailReadActionId = 'mail_read';
  static const mailDeleteActionId = 'mail_delete';
  static const macMailCategoryId = 'XATBOX_MAIL';

  /// macOS: the category of meeting reminders («Подключиться», action
  /// `join`); the press is routed like a tap (the payload opens the meeting).
  static const macMeetingCategoryId = 'XATBOX_MEETING';

  static final _listeners = <NotificationTapListener>[];
  static Future<void>? _init;

  /// Payload of the notification that launched the app, until handled.
  static String? _launchPayload;

  static Future<void> ensureInitialized() => _init ??= _initialize();

  /// Why the plugin could not start (desktop diagnostics), null when fine.
  static String? initError;

  static Future<void> _initialize() async {
    final plugin = FlutterLocalNotificationsPlugin();
    DiagnosticLog.info('notifications', 'init start');
    try {
      await plugin.initialize(
        settings: InitializationSettings(
          android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Permission is requested in context, not at start.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
            notificationCategories: iosChatNotificationCategories,
          ),
          // Desktop builds: toasts are shown from socket events while the
          // window is hidden or unfocused (desktop_notifications.dart).
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
            // The same buttons as the Windows toasts: reply / «Прочитано»
            // under chat messages, «Принять» / «Отклонить» under calls.
            notificationCategories: [...iosChatNotificationCategories, macCallNotificationCategory, macMailNotificationCategory, macMeetingNotificationCategory],
          ),
          linux: const LinuxInitializationSettings(defaultActionName: 'Открыть'),
          windows: const WindowsInitializationSettings(
            appName: 'XatBox',
            appUserModelId: LocalNotificationHub.windowsAppUserModelId,
            // Fixed for the lifetime of the app: Windows files the toasts
            // of one app under it.
            guid: '3ee9a1f1-27d7-4f10-8cc1-fdd70eeb390b',
          ),
        ),
        onDidReceiveNotificationResponse: (raw) {
          final r = isDesktop && Platform.isWindows ? normalizeWindowsResponse(raw) : raw;
          if (r.actionId == mailReplyActionId || r.actionId == mailReadActionId || r.actionId == mailDeleteActionId) {
            if (r.actionId == mailReplyActionId) unawaited(bringWindowToFront());
            onMailAction?.call(r.actionId!, r.payload ?? '');
            return;
          }
          if (r.actionId == callAcceptActionId || r.actionId == callDeclineActionId) {
            if (r.actionId == callAcceptActionId) unawaited(bringWindowToFront());
            onCallAction?.call(r.actionId!, r.payload ?? '');
            return;
          }
          // «Ответить» / «Прочитано» are answered in place; only a tap on the
          // notification body opens a screen.
          if (isChatNotificationAction(r)) {
            unawaited(handleChatNotificationAction(r));
            return;
          }
          final p = r.payload;
          if (p != null && p.isNotEmpty) {
            // Desktop: the window may be hidden to the tray.
            unawaited(bringWindowToFront());
            _dispatch(p);
          }
        },
        // The same actions when the app is not running: the system starts a
        // background isolate for this top-level entry point.
        onDidReceiveBackgroundNotificationResponse:
            xatboxNotificationBackgroundResponse,
      );
      DiagnosticLog.info('notifications', 'init done');
      final launch = await plugin.getNotificationAppLaunchDetails();
      var launchResponse = launch?.notificationResponse;
      if (launchResponse != null && isDesktop && Platform.isWindows) {
        launchResponse = normalizeWindowsResponse(launchResponse);
        // Windows: a toast button started the app (it had quit).
        if ((launch?.didNotificationLaunchApp ?? false) && isChatNotificationAction(launchResponse)) {
          unawaited(handleChatNotificationAction(launchResponse));
          launchResponse = null;
        }
      }
      final payload = launchResponse?.payload;
      if ((launch?.didNotificationLaunchApp ?? false) &&
          payload != null &&
          payload.isNotEmpty) {
        _launchPayload = payload;
        if (_dispatch(payload)) _launchPayload = null;
      }
    } on Object catch (e) {
      initError = e.toString();
      DiagnosticLog.warn('notifications', 'local notifications init failed', error: e);
    }
  }

  /// Adds [listener]; a not yet handled launch payload is delivered to it.
  static void addListener(NotificationTapListener listener) {
    _listeners.add(listener);
    final p = _launchPayload;
    if (p != null && listener(p)) _launchPayload = null;
  }

  static void removeListener(NotificationTapListener listener) =>
      _listeners.remove(listener);

  static bool _dispatch(String payload) {
    var handled = false;
    for (final l in List.of(_listeners)) {
      if (l(payload)) handled = true;
    }
    return handled;
  }
}

/// macOS incoming call: «Принять» brings the app forward, «Отклонить» does
/// not. Registered once at start, so the texts are fixed (like the chat
/// buttons of iosChatNotificationCategories).
final macCallNotificationCategory = DarwinNotificationCategory(
  LocalNotificationHub.macCallCategoryId,
  actions: [
    DarwinNotificationAction.plain(
      LocalNotificationHub.callAcceptActionId,
      'Принять',
      options: {DarwinNotificationActionOption.foreground},
    ),
    DarwinNotificationAction.plain(
      LocalNotificationHub.callDeclineActionId,
      'Отклонить',
      options: {DarwinNotificationActionOption.destructive},
    ),
  ],
);

/// macOS new mail: «Ответить» brings the app forward with the composer.
final macMailNotificationCategory = DarwinNotificationCategory(
  LocalNotificationHub.macMailCategoryId,
  actions: [
    DarwinNotificationAction.plain(
      LocalNotificationHub.mailReplyActionId,
      'Ответить',
      options: {DarwinNotificationActionOption.foreground},
    ),
    DarwinNotificationAction.plain(LocalNotificationHub.mailReadActionId, 'Прочитано'),
    DarwinNotificationAction.plain(
      LocalNotificationHub.mailDeleteActionId,
      'Удалить',
      options: {DarwinNotificationActionOption.destructive},
    ),
  ],
);

/// macOS meeting reminder: «Подключиться» brings the app forward.
final macMeetingNotificationCategory = DarwinNotificationCategory(
  LocalNotificationHub.macMeetingCategoryId,
  actions: [
    DarwinNotificationAction.plain('join', 'Подключиться', options: {DarwinNotificationActionOption.foreground}),
  ],
);
