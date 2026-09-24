import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:sembast/sembast.dart';

import '../../shared/utils/diagnostic_log.dart';
import '../auth/auth_providers.dart';
import '../storage/app_database.dart';

/// State of one runtime grant as the UI needs it.
enum GrantState { granted, denied, permanentlyDenied }

/// Android runtime grants the app asks for outside a feature's own flow:
/// POST_NOTIFICATIONS (13+), the full-screen intent for incoming calls (14+)
/// and the battery-optimisation exemption. Microphone and camera stay with
/// the call and voice-message code (asked on first use). Fake in tests.
abstract class DevicePermissions {
  /// False where none of this applies (iOS, desktop, tests): the UI hides it.
  bool get supported;

  Future<GrantState> notifications();

  /// System dialog; on a permanent denial opens the app notification page.
  Future<GrantState> requestNotifications();

  /// Android 14+ «Full screen notifications» special access (true before 14).
  Future<bool> canUseFullScreenIntent();
  Future<void> openFullScreenIntentSettings();

  Future<bool> isIgnoringBatteryOptimizations();

  /// ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS system dialog.
  Future<bool> requestIgnoreBatteryOptimizations();
}

/// Everything granted, nothing shown (non-Android platforms and tests).
class UnsupportedDevicePermissions implements DevicePermissions {
  const UnsupportedDevicePermissions();
  @override
  bool get supported => false;
  @override
  Future<GrantState> notifications() async => GrantState.granted;
  @override
  Future<GrantState> requestNotifications() async => GrantState.granted;
  @override
  Future<bool> canUseFullScreenIntent() async => true;
  @override
  Future<void> openFullScreenIntentSettings() async {}
  @override
  Future<bool> isIgnoringBatteryOptimizations() async => true;
  @override
  Future<bool> requestIgnoreBatteryOptimizations() async => true;
}

class AndroidDevicePermissions implements DevicePermissions {
  const AndroidDevicePermissions();

  @override
  bool get supported => true;

  static GrantState _map(ph.PermissionStatus s) => s.isGranted || s.isLimited || s.isProvisional
      ? GrantState.granted
      : s.isPermanentlyDenied
      ? GrantState.permanentlyDenied
      : GrantState.denied;

  Future<T> _guard<T>(String what, T fallback, Future<T> Function() f) async {
    try {
      return await f();
    } on Object catch (e) {
      DiagnosticLog.warn('permissions', '$what failed', error: e);
      return fallback;
    }
  }

  @override
  Future<GrantState> notifications() =>
      _guard('notification status', GrantState.granted, () async => _map(await ph.Permission.notification.status));

  @override
  Future<GrantState> requestNotifications() => _guard('notification request', GrantState.denied, () async {
    final before = await ph.Permission.notification.status;
    if (before.isPermanentlyDenied) {
      await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.openAppNotificationSettings();
      return _map(await ph.Permission.notification.status);
    }
    return _map(await ph.Permission.notification.request());
  });

  @override
  Future<bool> canUseFullScreenIntent() =>
      _guard('full screen intent status', true, FlutterCallkitIncoming.canUseFullScreenIntent);

  @override
  Future<void> openFullScreenIntentSettings() =>
      _guard<void>('full screen intent settings', null, FlutterCallkitIncoming.requestFullIntentPermission);

  @override
  Future<bool> isIgnoringBatteryOptimizations() =>
      _guard('battery status', true, () => ph.Permission.ignoreBatteryOptimizations.isGranted);

  @override
  Future<bool> requestIgnoreBatteryOptimizations() =>
      _guard('battery request', false, () async => (await ph.Permission.ignoreBatteryOptimizations.request()).isGranted);
}

final devicePermissionsProvider = Provider<DevicePermissions>(
  (_) => !kIsWeb && Platform.isAndroid ? const AndroidDevicePermissions() : const UnsupportedDevicePermissions(),
);

/// Steps of the one-time explainer after sign-in.
enum PermissionPrompt { notifications, fullScreenIntent }

/// Which explainers were already shown on this device (kept on sign-out:
/// the grants belong to the device, not the account).
class PermissionPromptStore {
  PermissionPromptStore(this._db);
  final AppDatabase _db;
  static final _store = stringMapStoreFactory.store('settings');
  static const _key = 'permission_prompts';

  Future<Set<PermissionPrompt>> shown() async {
    try {
      final json = await _store.record(_key).get(_db.db);
      final list = json?['shown'];
      if (list is! List) return {};
      return {
        for (final name in list) ...PermissionPrompt.values.where((p) => p.name == name),
      };
    } on Object {
      return {};
    }
  }

  Future<void> markShown(PermissionPrompt prompt) async {
    try {
      final next = {...await shown(), prompt};
      await _store.record(_key).put(_db.db, {
        'shown': [for (final p in next) p.name],
      });
    } on Object catch (e) {
      DiagnosticLog.warn('permissions', 'prompt flag not saved', error: e);
    }
  }
}

final permissionPromptStoreProvider = Provider<PermissionPromptStore>(
  (ref) => PermissionPromptStore(ref.watch(appDatabaseProvider)),
);

/// The explainers still worth showing: a grant that is missing and was never
/// explained. A permanent denial is not nagged about (Settings has the row).
Future<List<PermissionPrompt>> pendingPermissionPrompts({
  required DevicePermissions permissions,
  required Set<PermissionPrompt> shown,
  required bool callsEnabled,
}) async {
  if (!permissions.supported) return const [];
  final out = <PermissionPrompt>[];
  if (!shown.contains(PermissionPrompt.notifications) &&
      await permissions.notifications() == GrantState.denied) {
    out.add(PermissionPrompt.notifications);
  }
  if (callsEnabled &&
      !shown.contains(PermissionPrompt.fullScreenIntent) &&
      !await permissions.canUseFullScreenIntent()) {
    out.add(PermissionPrompt.fullScreenIntent);
  }
  return out;
}

/// Runs the explainers in order. [explain] shows the sheet and returns
/// whether the user agreed; each prompt is recorded as shown either way, and
/// the system request follows only after consent. Returns the prompts shown.
Future<List<PermissionPrompt>> runPermissionOnboarding({
  required DevicePermissions permissions,
  required PermissionPromptStore store,
  required bool callsEnabled,
  required Future<bool> Function(PermissionPrompt prompt) explain,
  bool Function()? stillWanted,
}) async {
  final pending = await pendingPermissionPrompts(
    permissions: permissions,
    shown: await store.shown(),
    callsEnabled: callsEnabled,
  );
  final done = <PermissionPrompt>[];
  for (final prompt in pending) {
    if (stillWanted != null && !stillWanted()) break;
    final agreed = await explain(prompt);
    await store.markShown(prompt);
    done.add(prompt);
    if (!agreed) continue;
    switch (prompt) {
      case PermissionPrompt.notifications:
        await permissions.requestNotifications();
      case PermissionPrompt.fullScreenIntent:
        await permissions.openFullScreenIntentSettings();
    }
  }
  return done;
}
