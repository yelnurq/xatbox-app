/// Build-time environment / flavor configuration.
///
/// Values come from `--dart-define` (or `--dart-define-from-file=env/<flavor>.json`),
/// never from source code. See `env/README.md`.
library;

import 'package:flutter/foundation.dart';

enum AppFlavor { dev, stage, prod }

class AppEnv {
  const AppEnv._({
    required this.flavor,
    required this.apiBaseUrl,
    required this.chatBaseUrl,
    required this.firebase,
    this.callsBaseUrl = '',
  });

  final AppFlavor flavor;

  /// Base URL including the `/api/v1` prefix, e.g. `https://host/backend/api/v1`.
  final String apiBaseUrl;

  /// Chat Service base URL including `/api/v1`, e.g. `https://chat.host/api/v1`.
  /// Empty = chat module disabled (tab shows a notice).
  final String chatBaseUrl;

  /// Call Service base URL including `/api/v1`. Empty = calls disabled.
  final String callsBaseUrl;

  /// Firebase options for push (all four required, otherwise push is off).
  final FirebasePushOptions? firebase;

  static const _flavorName = String.fromEnvironment(
    'XATBOX_FLAVOR',
    defaultValue: 'dev',
  );
  static const _apiBaseUrl = String.fromEnvironment('XATBOX_API_BASE_URL');
  static const _chatBaseUrl = String.fromEnvironment('XATBOX_CHAT_BASE_URL');
  static const _callsBaseUrl = String.fromEnvironment('XATBOX_CALLS_BASE_URL');
  static const _devDefaultCallsUrl = 'http://localhost:8095/api/v1';
  static const _fbApiKey = String.fromEnvironment('XATBOX_FIREBASE_API_KEY');
  static const _fbAppId = String.fromEnvironment('XATBOX_FIREBASE_APP_ID');
  static const _fbIosAppId = String.fromEnvironment(
    'XATBOX_FIREBASE_IOS_APP_ID',
  );
  static const _fbSenderId = String.fromEnvironment(
    'XATBOX_FIREBASE_SENDER_ID',
  );
  static const _fbProjectId = String.fromEnvironment(
    'XATBOX_FIREBASE_PROJECT_ID',
  );
  static const _devDefaultChatUrl = 'http://localhost:8090/api/v1';

  /// Local development server documented in the API spec; the only URL that is
  /// allowed to be a code default (it is not a secret).
  static const _devDefaultBaseUrl = 'http://localhost:8080/api/v1';

  static AppEnv? _current;

  /// The active environment. Throws [AppEnvError] on misconfiguration so the
  /// problem is visible at startup instead of as a confusing network error.
  static AppEnv get current => _current ??= fromDefines();

  /// Replace the environment (tests / manual wiring).
  static void override(AppEnv env) => _current = env;

  static AppEnv fromDefines() => fromValues(
    flavorName: _flavorName,
    apiBaseUrl: _apiBaseUrl,
    chatBaseUrl: _chatBaseUrl,
    callsBaseUrl: _callsBaseUrl,
    firebase: FirebasePushOptions.fromValues(
      apiKey: _fbApiKey,
      appId: _fbAppId,
      iosAppId: _fbIosAppId,
      messagingSenderId: _fbSenderId,
      projectId: _fbProjectId,
    ),
  );

  /// Pure builder, unit-testable.
  static AppEnv fromValues({
    required String flavorName,
    required String apiBaseUrl,
    String chatBaseUrl = '',
    String callsBaseUrl = '',
    FirebasePushOptions? firebase,
  }) {
    final flavor = AppFlavor.values.cast<AppFlavor?>().firstWhere(
      (f) => f!.name == flavorName,
      orElse: () => null,
    );
    if (flavor == null) {
      throw AppEnvError('Unknown XATBOX_FLAVOR "$flavorName"');
    }
    var baseUrl = apiBaseUrl.trim();
    if (baseUrl.isEmpty) {
      if (flavor == AppFlavor.dev) {
        baseUrl = _devDefaultBaseUrl;
      } else {
        throw AppEnvError(
          'XATBOX_API_BASE_URL is required for flavor "${flavor.name}". '
          'Pass it with --dart-define-from-file=env/${flavor.name}.json',
        );
      }
    }
    if (flavor == AppFlavor.prod && !baseUrl.startsWith('https://')) {
      throw AppEnvError('Production API base URL must use https');
    }
    var chatUrl = chatBaseUrl.trim();
    if (chatUrl.isEmpty && flavor == AppFlavor.dev) {
      chatUrl = _devDefaultChatUrl;
    }
    if (flavor == AppFlavor.prod &&
        chatUrl.isNotEmpty &&
        !chatUrl.startsWith('https://')) {
      throw AppEnvError('Production chat base URL must use https');
    }
    var callsUrl = callsBaseUrl.trim();
    if (callsUrl.isEmpty && flavor == AppFlavor.dev) {
      callsUrl = _devDefaultCallsUrl;
    }
    if (flavor == AppFlavor.prod &&
        callsUrl.isNotEmpty &&
        !callsUrl.startsWith('https://')) {
      throw AppEnvError('Production calls base URL must use https');
    }
    return AppEnv._(
      flavor: flavor,
      apiBaseUrl: baseUrl,
      chatBaseUrl: chatUrl,
      callsBaseUrl: callsUrl,
      firebase: firebase,
    );
  }

  bool get chatEnabled => chatBaseUrl.isNotEmpty;
  bool get callsEnabled => callsBaseUrl.isNotEmpty;

  bool get isProd => flavor == AppFlavor.prod;
}

class AppEnvError implements Exception {
  AppEnvError(this.message);
  final String message;
  @override
  String toString() => 'AppEnvError: $message';
}

/// Firebase project values needed to initialise FCM without a
/// google-services.json (manual `FirebaseOptions`).
class FirebasePushOptions {
  const FirebasePushOptions({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
  });

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;

  /// A Firebase app id belongs to one platform app (`1:…:android:…` vs
  /// `1:…:ios:…`), so iOS builds take [iosAppId]
  /// (`XATBOX_FIREBASE_IOS_APP_ID`) when it is set; [appId]
  /// (`XATBOX_FIREBASE_APP_ID`) stays the Android one. [ios] selects the
  /// platform (defaults to the running one).
  static FirebasePushOptions? fromValues({
    required String apiKey,
    required String appId,
    required String messagingSenderId,
    required String projectId,
    String iosAppId = '',
    bool? ios,
  }) {
    final onIos = ios ?? defaultTargetPlatform == TargetPlatform.iOS;
    final effectiveAppId = onIos && iosAppId.trim().isNotEmpty
        ? iosAppId
        : appId;
    if ([
      apiKey,
      effectiveAppId,
      messagingSenderId,
      projectId,
    ].any((v) => v.trim().isEmpty)) {
      return null;
    }
    return FirebasePushOptions(
      apiKey: apiKey.trim(),
      appId: effectiveAppId.trim(),
      messagingSenderId: messagingSenderId.trim(),
      projectId: projectId.trim(),
    );
  }
}
