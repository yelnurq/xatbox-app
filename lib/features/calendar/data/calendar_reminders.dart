import 'package:timezone/timezone.dart' as tz;

import '../domain/calendar_time.dart';
import 'calendar_cache.dart';
import 'calendar_models.dart';

/// One local notification to schedule.
class ReminderRequest {
  const ReminderRequest({
    required this.id,
    required this.fireAt,
    required this.title,
    required this.body,
    required this.payload,
    this.actionId,
    this.actionLabel,
  });

  /// Optional notification button (Android), e.g. «Подключиться»; tapping it
  /// delivers [payload] like tapping the notification.
  final String? actionId;
  final String? actionLabel;

  /// Stable per (occurrence, offset): re-scheduling replaces, never duplicates.
  final int id;
  final DateTime fireAt;
  final String title;
  final String body;

  /// `<event id>|<occurrence start>` for opening the event on tap.
  final String payload;
}

/// Platform notifications behind an interface (fake in tests).
abstract class ReminderScheduler {
  Future<bool> requestPermission();
  Future<void> schedule(ReminderRequest request);
  Future<void> cancel(int id);
}

/// Reminders are local notifications scheduled by the OS: they fire with the
/// app closed and without network, and there is exactly one per occurrence
/// and offset (see [ReminderPlanner.stableId]).
abstract final class ReminderPlanner {
  /// iOS keeps at most 64 pending local notifications per app.
  static const maxScheduled = 60;
  static const horizon = Duration(days: 14);

  /// XatBox meeting reminders fire this long before the start.
  static const meetingReminderLead = Duration(minutes: 5);

  /// Payload of a meeting reminder: `meet:<code>`.
  static const meetingPayloadPrefix = 'meet:';

  /// FNV-1a 32-bit (String.hashCode is not stable across runs), 31 bits.
  static int stableId(String key) {
    var h = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      h ^= unit;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h & 0x7fffffff;
  }

  static List<ReminderRequest> plan({
    required List<CalendarOccurrence> occurrences,
    required Map<String, List<int>> localReminders,
    required DateTime now,
    required tz.Location device,
    required String Function(CalendarOccurrence) describe,
    String? Function(CalendarEvent)? meetingCodeOf,
    String? meetingBody,
    String? joinLabel,
  }) {
    final out = <ReminderRequest>[];
    final seen = <int>{};
    for (final o in occurrences) {
      final e = o.event;
      if (e.isCancelled || e.responseStatus == RsvpStatus.declined) continue;
      final meetingCode = o.allDay ? null : meetingCodeOf?.call(e);
      if (meetingCode != null) {
        // A XatBox video meeting: 5 minutes before, «Подключиться» opens the pre-join screen.
        final fireAt = o.start.subtract(meetingReminderLead);
        final id = stableId('${o.key}|meet');
        if (fireAt.isAfter(now) && !fireAt.isAfter(now.add(horizon)) && seen.add(id)) {
          out.add(
            ReminderRequest(
              id: id,
              fireAt: fireAt,
              title: e.title,
              body: meetingBody ?? describe(o),
              payload: '$meetingPayloadPrefix$meetingCode',
              actionId: 'join',
              actionLabel: joinLabel,
            ),
          );
        }
      }
      final minutes = (localReminders[e.seriesKey] ??
              localReminders[e.id] ??
              [e.reminderMinutes])
          .toSet();
      if (meetingCode != null) minutes.remove(meetingReminderLead.inMinutes);
      // All-day events remind relative to 09:00 of their first day.
      final base = o.allDay
          ? EventTime.atWall(o.allDayStart!, 9, 0, device)
          : o.start;
      for (final m in minutes) {
        if (m < 0) continue;
        final fireAt = base.subtract(Duration(minutes: m));
        if (!fireAt.isAfter(now) || fireAt.isAfter(now.add(horizon))) continue;
        final id = stableId('${o.key}|$m');
        if (!seen.add(id)) continue;
        out.add(
          ReminderRequest(
            id: id,
            fireAt: fireAt,
            title: e.title,
            body: describe(o),
            payload: '${e.id}|${e.occurrenceStartRaw ?? ''}',
          ),
        );
      }
    }
    out.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return out.take(maxScheduled).toList();
  }
}

/// Applies a plan: cancels what is no longer wanted, (re)schedules the rest.
class CalendarReminderService {
  CalendarReminderService({required this.scheduler, required this.cache});

  final ReminderScheduler scheduler;
  final CalendarCache cache;
  bool _permissionAsked = false;

  Future<void> apply(List<ReminderRequest> desired) async {
    if (desired.isNotEmpty && !_permissionAsked) {
      _permissionAsked = true;
      await scheduler.requestPermission();
    }
    final previous = await cache.scheduledReminderIds();
    final wanted = desired.map((r) => r.id).toSet();
    for (final id in previous.difference(wanted)) {
      await scheduler.cancel(id);
    }
    for (final r in desired) {
      await scheduler.schedule(r);
    }
    await cache.putScheduledReminderIds(wanted);
  }

  Future<void> clear() async {
    for (final id in await cache.scheduledReminderIds()) {
      await scheduler.cancel(id);
    }
    await cache.putScheduledReminderIds(const {});
  }
}
