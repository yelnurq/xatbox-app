import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/notifications/exact_alarms.dart';
import '../../../core/notifications/local_notification_hub.dart';
import '../../../core/platform/desktop.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../domain/calendar_time.dart';
import 'calendar_reminders.dart';

/// [ReminderScheduler] on top of flutter_local_notifications. Times are
/// absolute (UTC), so a device zone change does not move a reminder.
class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler({
    required this.channelName,
    required this.channelDescription,
    this.onOpen,
  });

  final String channelName;
  final String channelDescription;

  /// Called with [ReminderRequest.payload] when the user taps a reminder.
  final void Function(String payload)? onOpen;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _exact = false;

  /// Linux desktop: the plugin cannot schedule, reminders fire from the
  /// running app instead.
  late final _timers = InProcessReminderTimers(show: _showNow);
  bool _windowsDeduped = false;

  static const channelId = 'calendar_reminders';

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    CalendarZones.ensureInitialized();
    // The plugin has one tap callback for the whole app (push notifications
    // share it), so taps come through the hub; push payloads are not ours.
    LocalNotificationHub.addListener((p) {
      if (p.startsWith(LocalNotificationHub.pushPayloadPrefix)) return false;
      onOpen?.call(p);
      return true;
    });
    await LocalNotificationHub.ensureInitialized();
  }

  @override
  Future<bool> requestPermission() async {
    await _init();
    try {
      if (Platform.isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final granted = await android?.requestNotificationsPermission() ?? true;
        // USE_EXACT_ALARM is declared (calendar app); fall back to inexact
        // delivery when the platform still refuses exact alarms.
        _exact = await android?.canScheduleExactNotifications() ?? false;
        return granted;
      }
      if (Platform.isIOS) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, sound: true, badge: false) ??
            false;
      }
    } on Object catch (e) {
      DiagnosticLog.warn('calendar', 'notification permission failed', error: e);
    }
    return false;
  }

  @override
  Future<void> schedule(ReminderRequest r) async {
    await _init();
    if (isDesktop && Platform.isLinux) {
      _timers.schedule(r);
      return;
    }
    try {
      // Windows adds a scheduled toast per call, it does not replace one
      // with the same id.
      if (isDesktop && Platform.isWindows) {
        await _dedupeWindows();
        await _plugin.cancel(id: r.id);
      }
      // The grant can be revoked while the app runs (Android 12
      // SCHEDULE_EXACT_ALARM): the plugin then throws, retry inexact.
      await scheduleWithExactFallback(
        exact: _exact,
        schedule: (mode) => _scheduleOne(r, mode),
        onFallback: () => _exact = false,
      );
    } on Object catch (e) {
      DiagnosticLog.warn('calendar', 'schedule reminder failed', error: e);
    }
  }

  Future<void> _scheduleOne(ReminderRequest r, AndroidScheduleMode mode) =>
      _plugin.zonedSchedule(
        id: r.id,
        title: r.title,
        body: r.body,
        payload: r.payload,
        scheduledDate: tz.TZDateTime.from(r.fireAt, tz.UTC),
        androidScheduleMode: mode,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
            actions: r.actionLabel == null
                ? null
                : [AndroidNotificationAction(r.actionId ?? 'open', r.actionLabel!, showsUserInterface: true, cancelNotification: true)],
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
          windows: isDesktop ? reminderWindowsDetails(r) : null,
          macOS: isDesktop ? reminderMacDetails(r) : null,
        ),
      );

  /// Builds before this one scheduled a second toast on every re-plan: drop
  /// every id that is scheduled more than once (the plan re-adds it).
  Future<void> _dedupeWindows() async {
    if (_windowsDeduped) return;
    _windowsDeduped = true;
    final counts = <int, int>{};
    for (final p in await _plugin.pendingNotificationRequests()) {
      counts[p.id] = (counts[p.id] ?? 0) + 1;
    }
    for (final MapEntry(key: id, value: n) in counts.entries) {
      for (var i = 1; i < n; i++) {
        await _plugin.cancel(id: id);
      }
    }
  }

  Future<void> _showNow(ReminderRequest r) async {
    try {
      await _plugin.show(
        id: r.id,
        title: r.title,
        body: r.body,
        payload: r.payload,
        notificationDetails: NotificationDetails(linux: reminderLinuxDetails(r)),
      );
    } on Object catch (e) {
      DiagnosticLog.warn('calendar', 'show reminder failed', error: e);
    }
  }

  @override
  Future<void> cancel(int id) async {
    await _init();
    _timers.cancel(id);
    try {
      await _plugin.cancel(id: id);
    } on Object catch (e) {
      DiagnosticLog.warn('calendar', 'cancel reminder failed', error: e);
    }
  }
}

/// Windows: «Подключиться» on a meeting reminder. The button hands back its
/// arguments only, so they carry the payload (LocalNotificationHub routes it
/// like a tap on the toast).
WindowsNotificationDetails? reminderWindowsDetails(ReminderRequest r) {
  final label = r.actionLabel;
  if (label == null) return null;
  return WindowsNotificationDetails(
    actions: [
      WindowsAction(
        content: label,
        arguments: LocalNotificationHub.windowsActionArguments(r.actionId ?? 'open', r.payload),
      ),
    ],
  );
}

/// macOS: meeting reminders use the category with «Подключиться»; shown
/// even while the app is in front, like on the phone.
DarwinNotificationDetails reminderMacDetails(ReminderRequest r) => DarwinNotificationDetails(
  presentAlert: true,
  presentBanner: true,
  presentList: true,
  presentSound: true,
  categoryIdentifier: r.actionLabel == null ? null : LocalNotificationHub.macMeetingCategoryId,
);

/// Linux: the same button through the notification server's actions.
LinuxNotificationDetails reminderLinuxDetails(ReminderRequest r) => LinuxNotificationDetails(
  actions: [
    if (r.actionLabel case final label?) LinuxNotificationAction(key: r.actionId ?? 'open', label: label),
  ],
);

/// Reminders kept by the running app (Linux desktop, where
/// flutter_local_notifications has no scheduling). A periodic check rather
/// than one long timer per reminder: timers do not count the time the
/// computer sleeps, the wall clock does. A reminder missed by more than
/// [maxLate] (the app was not running, a long sleep) is dropped.
class InProcessReminderTimers {
  InProcessReminderTimers({
    required this.show,
    DateTime Function()? now,
    this.tick = const Duration(seconds: 15),
  }) : _now = now ?? DateTime.now;

  final Future<void> Function(ReminderRequest r) show;
  final DateTime Function() _now;
  final Duration tick;

  static const maxLate = Duration(minutes: 15);

  final _pending = <int, ReminderRequest>{};
  Timer? _ticker;

  /// Ids waiting to fire.
  Iterable<int> get pendingIds => _pending.keys;

  /// Replaces the reminder with the same id.
  void schedule(ReminderRequest r) {
    if (!r.fireAt.isAfter(_now().subtract(maxLate))) {
      _pending.remove(r.id);
      return;
    }
    _pending[r.id] = r;
    _ticker ??= Timer.periodic(tick, (_) => _fireDue());
    _fireDue();
  }

  void cancel(int id) {
    _pending.remove(id);
    _stopWhenIdle();
  }

  void dispose() {
    _pending.clear();
    _stopWhenIdle();
  }

  void _fireDue() {
    final now = _now();
    final due = _pending.values.where((r) => !r.fireAt.isAfter(now)).toList();
    for (final r in due) {
      _pending.remove(r.id);
      if (now.difference(r.fireAt) <= maxLate) unawaited(show(r));
    }
    _stopWhenIdle();
  }

  void _stopWhenIdle() {
    if (_pending.isNotEmpty) return;
    _ticker?.cancel();
    _ticker = null;
  }
}
