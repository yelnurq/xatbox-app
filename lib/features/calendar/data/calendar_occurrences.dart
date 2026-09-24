import 'package:timezone/timezone.dart' as tz;

import '../domain/calendar_time.dart';
import '../domain/recurrence.dart';
import 'calendar_models.dart';
import 'calendar_ops.dart';

/// Turns server events (+ series masters + queued operations) into the
/// occurrences shown for a date range in the device zone. Pure; unit-tested.
abstract final class OccurrenceBuilder {
  static List<CalendarOccurrence> build({
    required List<CalendarEvent> events,
    required Map<String, CalendarEvent> masters,
    required List<CalendarOp> ops,
    required CalendarDate from,
    required CalendarDate to,
    required tz.Location device,
    required String selfId,
  }) {
    final fromInstant = EventTime.atWall(from, 0, 0, device);
    final toInstant = EventTime.atWall(to, 0, 0, device);
    final lastStarts = <String, DateTime?>{};

    // 1. De-duplicate: series ids repeat per occurrence, and an override can
    // come twice (standalone copy + replacement with series_id).
    final unique = <String, CalendarEvent>{};
    for (final e in events) {
      if (e.isCancelled) continue;
      final key = e.isOverride ? 'ovr:${e.id}' : e.occurrenceKey;
      final existing = unique[key];
      if (existing == null || (existing.seriesId == null && e.seriesId != null)) {
        unique[key] = e;
      }
    }

    var list = <CalendarOccurrence>[];
    for (final e in unique.values) {
      final occ = _fromServer(e, masters, lastStarts);
      if (occ != null) list.add(occ);
    }

    // 2. Queued changes on top (optimistic UI, offline edits).
    for (final op in ops) {
      list = _apply(op, list, from, to, device, selfId);
    }

    // 3. Range filter in the device zone; dates for all-day events.
    list = list.where((o) {
      if (o.allDay) {
        return o.allDayStart!.isBefore(to) && o.allDayEnd!.isAfter(from);
      }
      return o.start.isBefore(toInstant) && o.end.isAfter(fromInstant);
    }).toList();
    list.sort(compare);
    return list;
  }

  static int compare(CalendarOccurrence a, CalendarOccurrence b) {
    if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
    final byStart = a.start.compareTo(b.start);
    if (byStart != 0) return byStart;
    return a.event.title.compareTo(b.event.title);
  }

  static CalendarOccurrence? _fromServer(
    CalendarEvent e,
    Map<String, CalendarEvent> masters,
    Map<String, DateTime?> lastStarts,
  ) {
    final zone = CalendarZones.location(e.timezone);
    final recurringOccurrence = e.isRecurring && !e.isOverride;
    if (e.allDay) {
      final (first, end) = EventTime.allDayRange(e.startsAt, e.endsAt, zone);
      if (recurringOccurrence && !_withinSeriesEnd(e, masters, lastStarts, zone, e.startsAt)) {
        return null;
      }
      return CalendarOccurrence(
        event: e,
        start: EventTime.atWall(first, 0, 0, zone),
        end: EventTime.atWall(end, 0, 0, zone),
        allDayStart: first,
        allDayEnd: end,
      );
    }
    var start = e.startsAt;
    final duration = e.endsAt.difference(e.startsAt);
    final master = masters[e.id];
    if (recurringOccurrence && master != null && zone != tz.UTC) {
      start = EventTime.wallClockOccurrence(
        occurrenceUtc: e.startsAt,
        masterUtc: master.startsAt,
        zone: zone,
      );
    }
    if (recurringOccurrence && !_withinSeriesEnd(e, masters, lastStarts, zone, start)) {
      return null;
    }
    return CalendarOccurrence(event: e, start: start, end: start.add(duration));
  }

  /// The server ignores UNTIL/COUNT; the app hides occurrences past the end.
  static bool _withinSeriesEnd(
    CalendarEvent e,
    Map<String, CalendarEvent> masters,
    Map<String, DateTime?> lastStarts,
    tz.Location zone,
    DateTime displayStart,
  ) {
    final spec = e.recurrence;
    if (spec == null || spec.isInfinite) return true;
    final master = masters[e.id];
    if (master == null) {
      final until = spec.until;
      return until == null ||
          !displayStart.isAfter(until.add(const Duration(minutes: 1)));
    }
    final last = lastStarts.putIfAbsent(
      e.id,
      () => RecurrenceEngine.lastStart(
        spec: spec,
        masterUtc: master.startsAt,
        zone: zone,
      ),
    );
    return last == null ||
        !displayStart.isAfter(last.add(const Duration(minutes: 1)));
  }

  static bool _sameInstant(String? raw, String? other) {
    final a = EventTime.parse(raw);
    final b = EventTime.parse(other);
    return a != null && b != null && a.isAtSameMomentAs(b);
  }

  static List<CalendarOccurrence> _apply(
    CalendarOp op,
    List<CalendarOccurrence> list,
    CalendarDate from,
    CalendarDate to,
    tz.Location device,
    String selfId,
  ) {
    final p = op.payload;
    switch (op.kind) {
      case CalendarOp.create:
        return [
          ...list,
          ..._synthetic(op, p, p['client_event_id'] as String, from, to, device, selfId),
        ];

      case CalendarOp.recreate:
        final old = p['event_id'] as String;
        return [
          ...list.where((o) => o.event.seriesKey != old),
          ..._synthetic(op, p, p['client_event_id'] as String, from, to, device, selfId),
        ];

      case CalendarOp.patch:
        final id = p['event_id'] as String;
        final body = Map<String, dynamic>.from(p['body'] as Map);
        if (body['status'] == 'cancelled') {
          return list
              .where((o) => o.event.id != id && o.event.seriesKey != id)
              .toList();
        }
        final shiftMs = (p['shift_ms'] as num?)?.toInt();
        final durationMs = (p['duration_ms'] as num?)?.toInt();
        return [
          for (final o in list)
            if (o.event.id == id || (o.event.seriesKey == id && !o.event.isOverride))
              _patched(o, body, shiftMs, durationMs)
            else
              o,
        ];

      case CalendarOp.exception:
      case CalendarOp.overridePatch:
        final series = p['series_id'] as String;
        final key = p['occurrence_start'] as String?;
        bool match(CalendarOccurrence o) =>
            o.event.id == series &&
            !o.event.isOverride &&
            _sameInstant(o.event.occurrenceStartRaw, key);
        if (p['cancelled'] == true) {
          return list.where((o) => !match(o)).toList();
        }
        final start = EventTime.parse(p['starts_at'] as String?);
        final end = EventTime.parse(p['ends_at'] as String?);
        final body = p['body'] is Map
            ? Map<String, dynamic>.from(p['body'] as Map)
            : const <String, dynamic>{};
        return [
          for (final o in list)
            if (match(o))
              o.copyWith(
                event: body.isEmpty ? o.event : o.event.copyWithRaw(body),
                start: start ?? o.start,
                end: end ?? o.end,
                pending: true,
              )
            else
              o,
        ];

      case CalendarOp.cancelFollowing:
        final series = p['series_id'] as String;
        final fromKey = EventTime.parse(p['from'] as String?);
        if (fromKey == null) return list;
        return list.where((o) {
          final e = o.event;
          final inSeries = e.id == series || e.seriesId == series;
          final key = e.occurrenceStart;
          return !(inSeries && key != null && !key.isBefore(fromKey));
        }).toList();

      case CalendarOp.rsvp:
        final id = p['event_id'] as String;
        return [
          for (final o in list)
            if (o.event.seriesKey == id)
              o.copyWith(
                event: o.event.copyWithRaw({'response_status': p['status']}),
                pending: true,
              )
            else
              o,
        ];
    }
    return list;
  }

  static CalendarOccurrence _patched(
    CalendarOccurrence o,
    Map<String, dynamic> body,
    int? shiftMs,
    int? durationMs,
  ) {
    final text = {
      for (final k in const ['title', 'description', 'location', 'meeting_link'])
        if (body.containsKey(k)) k: body[k],
    };
    var start = o.start;
    var end = o.end;
    if (!o.event.isRecurring || o.event.isOverride) {
      start = EventTime.parse(body['starts_at'] as String?) ?? start;
      end = EventTime.parse(body['ends_at'] as String?) ?? end;
    } else if (shiftMs != null) {
      start = start.add(Duration(milliseconds: shiftMs));
      end = durationMs == null
          ? end.add(Duration(milliseconds: shiftMs))
          : start.add(Duration(milliseconds: durationMs));
    }
    return o.copyWith(
      event: text.isEmpty ? o.event : o.event.copyWithRaw(text),
      start: start,
      end: end,
      pending: true,
    );
  }

  /// Local occurrences of a queued create (expanded with the RFC engine when
  /// it is a series, so an offline-created weekly meeting shows every week).
  static List<CalendarOccurrence> _synthetic(
    CalendarOp op,
    Map<String, dynamic> p,
    String clientId,
    CalendarDate from,
    CalendarDate to,
    tz.Location device,
    String selfId,
  ) {
    final body = Map<String, dynamic>.from(p['body'] as Map);
    final event = CalendarEvent.fromJson({
      ...body,
      'id': 'local:$clientId',
      'uid': '',
      'sequence': 0,
      'organization_id': '',
      'organizer_id': selfId,
      'organizer_name': '',
      'status': 'confirmed',
      'managed': false,
      'visibility': body['visibility'] ?? 'default',
      'attendance': 'invitation',
    });
    final zone = CalendarZones.location(event.timezone);
    final duration = event.endsAt.difference(event.startsAt);
    final spec = event.recurrence;
    final starts = spec == null
        ? [event.startsAt]
        : RecurrenceEngine.expand(
            spec: spec,
            masterUtc: event.startsAt,
            zone: zone,
            fromUtc: EventTime.atWall(from.addDays(-1), 0, 0, device)
                .subtract(duration),
            toUtc: EventTime.atWall(to.addDays(1), 0, 0, device),
          );
    return [
      for (final s in starts)
        if (event.allDay)
          () {
            final (first, end) = EventTime.allDayRange(s, s.add(duration), zone);
            return CalendarOccurrence(
              event: event,
              start: s,
              end: s.add(duration),
              allDayStart: first,
              allDayEnd: end,
              pending: op.status != OpStatus.failed,
              localId: '$clientId|${s.millisecondsSinceEpoch}',
            );
          }()
        else
          CalendarOccurrence(
            event: event,
            start: s,
            end: s.add(duration),
            pending: op.status != OpStatus.failed,
            localId: '$clientId|${s.millisecondsSinceEpoch}',
          ),
    ];
  }
}
