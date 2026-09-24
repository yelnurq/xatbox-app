import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../shared/utils/diagnostic_log.dart';

/// Whether exact alarms may be used for reminders. Android 13+ grants the
/// declared USE_EXACT_ALARM at install; Android 12/12L use
/// SCHEDULE_EXACT_ALARM (granted by default, revocable). Never throws.
Future<bool> canScheduleExactReminders(FlutterLocalNotificationsPlugin plugin) async {
  if (!Platform.isAndroid) return false;
  try {
    return await plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.canScheduleExactNotifications() ??
        false;
  } on Object {
    return false;
  }
}

/// Schedules with an exact alarm when [exact], falling back to an inexact
/// one when the platform refuses (`exact_alarms_not_permitted`) — a reminder
/// that comes late is better than none. Other errors are rethrown.
Future<void> scheduleWithExactFallback({
  required bool exact,
  required Future<void> Function(AndroidScheduleMode mode) schedule,
  void Function()? onFallback,
}) async {
  if (!exact) {
    await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    return;
  }
  try {
    await schedule(AndroidScheduleMode.exactAllowWhileIdle);
  } on Object catch (e) {
    DiagnosticLog.warn('notifications', 'exact alarm refused, using inexact', error: e);
    onFallback?.call();
    await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
  }
}
