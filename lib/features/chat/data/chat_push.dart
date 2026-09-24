import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/app_env.dart';
import '../../../core/notifications/local_notification_hub.dart';
import '../../../core/platform/desktop.dart';
import '../../../shared/utils/diagnostic_log.dart';
import 'chat_repository.dart';
import 'push_crypto.dart';
import 'push_notifications.dart';

/// Firebase options from the XATBOX_FIREBASE_* dart-defines (also usable in
/// the background isolate); null when absent or the env is misconfigured.
FirebasePushOptions? firebaseOptionsFromDefines() {
  try {
    return AppEnv.current.firebase;
  } on Object {
    return null;
  }
}

/// Initialises the default FirebaseApp once per isolate; never throws.
///
/// Android first tries the native configuration from google-services.json
/// (android/app/google-services.json at build time), then the dart-define
/// [options]. Returns false when neither is available (push stays off).
Future<bool> ensureFirebaseInitialized(FirebasePushOptions? options) async {
  // FCM has no desktop client: there notifications come from the open
  // socket (lib/features/chat/data/desktop_notifications.dart).
  if (!isMobileOs) return false;
  try {
    if (Firebase.apps.isNotEmpty) return true;
  } on Object {
    // Platform implementation unavailable (tests, desktop).
  }
  if (Platform.isAndroid) {
    try {
      await Firebase.initializeApp();
      return true;
    } on Object {
      // No google-services.json in this build: fall back to options.
    }
  }
  if (options == null) return false;
  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: options.apiKey,
        appId: options.appId,
        messagingSenderId: options.messagingSenderId,
        projectId: options.projectId,
      ),
    );
    return true;
  } on Object catch (e) {
    DiagnosticLog.warn('push', 'firebase init failed', error: e);
    return false;
  }
}

/// Removes the system notification of [conversationId] (call it when the
/// conversation is opened). No-op off Android; never throws.
Future<void> cancelChatNotification(String conversationId) =>
    cancelChatNotificationFor(conversationId);

/// Push registration for chat.message / chat.mention (ТЗ п.12, п.24.19).
///
/// * FCM token is obtained through firebase_messaging and registered as a
///   device of the signed-in user (`POST /push/devices`) together with this
///   install's AES key (`push_key`), re-registered on token rotation and
///   removed on sign-out (the key is rotated then).
/// * FCM messages for such devices are encrypted end to end (`v=1`, see
///   push_crypto.dart): they are decrypted here or in the background handler
///   and rendered as local notifications (push_notifications.dart).
/// * The push is only a signal: on tap the app opens the conversation and
///   loads the actual state from the backend.
/// * While the WebSocket is open the server sends no push, so nothing needs
///   de-duplicating on the client.
///
/// Firebase comes from google-services.json or dart-define options (see
/// env/README.md); when both are absent push stays off and nothing throws.
class ChatPushService {
  ChatPushService({
    required FirebasePushOptions? options,
    required ChatRepository repo,
    required void Function(String conversationId, String? messageId) openConversation,
    void Function(Map<String, dynamic> data)? onData,
    void Function(Map<String, dynamic> data)? onTap,
    BackgroundMessageHandler? backgroundHandler,
    PushKeyStore? keyStore,
    this.onRegistrationChanged,
    this.onMessage,
    this.openThread,
  }) : _options = options, // ignore: prefer_initializing_formals
       _repo = repo, // ignore: prefer_initializing_formals
       _open = openConversation,
       _onData = onData, // ignore: prefer_initializing_formals
       _onTap = onTap, // ignore: prefer_initializing_formals
       _background = backgroundHandler,
       _keys = keyStore ?? SecurePushKeyStore();

  final FirebasePushOptions? _options;
  final ChatRepository _repo;
  /// Opens a chat; [messageId] (reminders, mentions) is scrolled to.
  final void Function(String conversationId, String? messageId) _open;

  /// Data of foreground pushes and taps (e.g. `call.*` for the calls module).
  final void Function(Map<String, dynamic> data)? _onData;

  /// Taps on non-chat pushes (calendar, mail…) for app-level navigation.
  final void Function(Map<String, dynamic> data)? _onTap;

  /// Top-level handler for data messages while in background / killed.
  final BackgroundMessageHandler? _background;
  final PushKeyStore _keys;

  /// `true` after the backend accepted this device's push token, `false`
  /// after sign-out (drives the background-connection grace period).
  final void Function(bool registered)? onRegistrationChanged;

  /// Any push reached the running app (e.g. wake a suspended socket).
  final void Function()? onMessage;

  /// `chat.comment` taps: the post's comment thread.
  final void Function(String conversationId, String postId)? openThread;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  String? _token;
  bool _initialized = false;

  /// Firebase is up and the listeners are attached.
  bool _active = false;

  bool get enabled => _options != null || _active;

  Future<void> init() async {
    if (_initialized) {
      // Signed in again after a sign-out: register with a fresh key.
      if (_active && _token == null) unawaited(_registerCurrentToken());
      return;
    }
    _initialized = true;
    if (isDesktop) {
      // No FCM: the toasts shown from socket events (desktop_notifications
      // .dart) carry the same `push:` payload, so taps route the same way.
      LocalNotificationHub.addListener(_handleLocalTap);
      unawaited(LocalNotificationHub.ensureInitialized());
      return;
    }
    try {
      if (!await ensureFirebaseInitialized(_options)) return;
      _active = true;
      if (_background != null) FirebaseMessaging.onBackgroundMessage(_background);
      final fm = FirebaseMessaging.instance;
      _foregroundSub = FirebaseMessaging.onMessage.listen(
        (m) => unawaited(_handleForeground(m)),
      );
      LocalNotificationHub.addListener(_handleLocalTap);
      await ensurePushChannels();
      unawaited(LocalNotificationHub.ensureInitialized());
      // iOS only: Android 13+ POST_NOTIFICATIONS is requested by the
      // permission onboarding sheet (lib/core/permissions), which explains
      // why it is needed before the system dialog appears.
      if (Platform.isIOS) await fm.requestPermission();
      await _registerCurrentToken();
      _tokenSub = fm.onTokenRefresh.listen((t) async {
        final token = Platform.isIOS ? await fm.getAPNSToken() : t;
        if (token == null || token == _token) return;
        _token = token;
        unawaited(_register(token));
      });
      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
      final initial = await fm.getInitialMessage();
      if (initial != null) _handleTap(initial);
      DiagnosticLog.info('push', 'registered');
    } on Object catch (e) {
      // Missing Firebase config on the platform side must never crash chat.
      DiagnosticLog.warn('push', 'push init failed', error: e);
    }
  }

  Future<void> _registerCurrentToken() async {
    try {
      final fm = FirebaseMessaging.instance;
      // The backend talks to APNs directly on iOS, so it needs the APNs
      // device token there (the FCM token is only valid for FCM).
      _token = Platform.isIOS ? await fm.getAPNSToken() : await fm.getToken();
      if (_token != null) await _register(_token!);
    } on Object catch (e) {
      DiagnosticLog.warn('push', 'push token unavailable', error: e);
    }
  }

  Future<void> _register(String token) async {
    String? pushKey;
    try {
      pushKey = await _keys.readOrCreate();
    } on Object catch (e) {
      // Without a key the server still sends generic (content-free) pushes.
      DiagnosticLog.warn('push', 'push key unavailable (${e.runtimeType})');
    }
    try {
      await _repo.api.registerDevice(
        platform: Platform.isIOS ? 'ios' : 'android',
        token: token,
        deviceId: await _repo.deviceId(),
        locale: Platform.localeName.split('_').first,
        pushKey: pushKey,
      );
      onRegistrationChanged?.call(true);
    } on AppException catch (e) {
      DiagnosticLog.warn('push', 'device registration failed', error: e);
    }
  }

  Future<void> _handleForeground(RemoteMessage m) async {
    onMessage?.call();
    final encrypted = isEncryptedPush(m.data);
    final data = await resolvePushData(m.data, keys: _keys);
    if (data == null) return;
    _onData?.call(data);
    if (encrypted) await showPushNotification(data);
  }

  bool _handleLocalTap(String payload) {
    final data = decodePushTapPayload(payload);
    if (data == null) return false;
    _openData(data);
    return true;
  }

  void _handleTap(RemoteMessage m) {
    // Encrypted pushes have no system notification to tap.
    if (isEncryptedPush(m.data)) return;
    _openData(m.data);
  }

  void _openData(Map<String, dynamic> data) {
    final conv = data['conversation_id'];
    final root = data['thread_root_id'];
    if (data['type'] == 'chat.comment' &&
        conv is String &&
        conv.isNotEmpty &&
        root is String &&
        root.isNotEmpty &&
        openThread != null) {
      unawaited(cancelChatNotification(conv));
      openThread!(conv, root);
    } else if (conv is String && conv.isNotEmpty) {
      unawaited(cancelChatNotification(conv));
      _open(conv, pushJumpMessageId(data));
    } else {
      _onData?.call(data);
      _onTap?.call(data);
    }
  }

  /// Sign-out: remove this device's registration and rotate the push key.
  Future<void> unregister() async {
    final t = _token;
    _token = null;
    onRegistrationChanged?.call(false);
    if (t != null) {
      try {
        await _repo.api.unregisterDevice(
          platform: Platform.isIOS ? 'ios' : 'android',
          token: t,
          deviceId: await _repo.deviceId(),
        );
      } on AppException catch (e) {
        DiagnosticLog.warn('push', 'device unregister failed', error: e);
      }
    }
    if (_active) {
      try {
        await _keys.clear();
      } on Object catch (e) {
        DiagnosticLog.warn('push', 'push key removal failed (${e.runtimeType})');
      }
    }
  }

  Future<void> dispose() async {
    LocalNotificationHub.removeListener(_handleLocalTap);
    await _tokenSub?.cancel();
    await _openedSub?.cancel();
    await _foregroundSub?.cancel();
  }
}

/// The message a tapped chat push should scroll to: reminders and mentions
/// point at one message; ordinary new-message pushes open the chat as usual
/// (at the first unread).
String? pushJumpMessageId(Map<String, dynamic> data) {
  final type = data['type'];
  final message = data['message_id'];
  if (message is! String || message.isEmpty) return null;
  return type == 'chat.reminder' || type == 'chat.mention' ? message : null;
}
