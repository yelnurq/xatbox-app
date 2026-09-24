import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../shared/utils/api_date.dart';

/// A calendar day with no time and no zone. All-day events and grid cells
/// are dates, not instants: storing them as `00:00 UTC` is the classic
/// "the day moved" bug, so they never go through a device-zone conversion.
@immutable
class CalendarDate implements Comparable<CalendarDate> {
  const CalendarDate(this.year, this.month, this.day);

  /// Normalises overflowing values (e.g. day 32).
  factory CalendarDate.normalized(int year, int month, int day) {
    final d = DateTime.utc(year, month, day);
    return CalendarDate(d.year, d.month, d.day);
  }

  /// The date part of [dt] as it is (no zone conversion).
  factory CalendarDate.of(DateTime dt) => CalendarDate(dt.year, dt.month, dt.day);

  /// Parses `YYYY-MM-DD`.
  factory CalendarDate.parse(String key) {
    final p = key.split('-').map(int.parse).toList();
    return CalendarDate(p[0], p[1], p[2]);
  }

  final int year;
  final int month;
  final int day;

  DateTime get _utc => DateTime.utc(year, month, day);

  /// ISO weekday, Monday = 1.
  int get weekday => _utc.weekday;

  CalendarDate addDays(int days) =>
      CalendarDate.normalized(year, month, day + days);

  /// Same day-of-month [months] later, clamped to the month length.
  CalendarDate addMonths(int months) {
    final first = DateTime.utc(year, month + months, 1);
    final last = DateTime.utc(first.year, first.month + 1, 0).day;
    return CalendarDate(first.year, first.month, day > last ? last : day);
  }

  CalendarDate get firstOfMonth => CalendarDate(year, month, 1);

  /// Monday of this date's week.
  CalendarDate get startOfWeek => addDays(-(weekday - 1));

  int daysUntil(CalendarDate other) => other._utc.difference(_utc).inDays;

  bool isBefore(CalendarDate other) => compareTo(other) < 0;
  bool isAfter(CalendarDate other) => compareTo(other) > 0;

  String get key =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  /// Local-noon [DateTime] for `intl` formatting (never shifts a day).
  DateTime get forFormatting => DateTime(year, month, day, 12);

  @override
  int compareTo(CalendarDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => key;
}

/// IANA zone database access. The app keeps its own tzdata (package
/// `timezone`) instead of trusting `DateTime.toLocal()`, so a device zone
/// change is picked up without a restart and historical offsets (e.g. the
/// Kazakhstan change of 2024-03-01) are known.
abstract final class CalendarZones {
  static bool _ready = false;

  static void ensureInitialized() {
    if (_ready) return;
    tzdata.initializeTimeZones();
    _ready = true;
  }

  static bool isKnown(String? name) {
    if (name == null || name.isEmpty) return false;
    ensureInitialized();
    return tz.timeZoneDatabase.locations.containsKey(name);
  }

  /// The zone [name], or [fallback] (UTC by default) when unknown.
  static tz.Location location(String? name, {tz.Location? fallback}) {
    ensureInitialized();
    if (isKnown(name)) return tz.getLocation(name!);
    return fallback ?? tz.UTC;
  }
}

/// Conversions between API instants, event zones and the device zone.
abstract final class EventTime {
  /// Parses both timestamp forms the calendar API emits (RFC 3339 and
  /// PostgreSQL `timestamptz` text) into a UTC instant.
  static DateTime? parse(String? raw) => parseApiDate(raw)?.toUtc();

  /// RFC 3339 without fractional seconds, e.g. `2026-09-14T09:00:00Z`.
  static String encode(DateTime instant) {
    final u = instant.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}'
        'T${two(u.hour)}:${two(u.minute)}:${two(u.second)}Z';
  }

  /// Plain UTC [DateTime] of a zoned value.
  static DateTime utcOf(DateTime t) =>
      DateTime.fromMillisecondsSinceEpoch(t.millisecondsSinceEpoch, isUtc: true);

  /// Wall-clock view of [instant] in [zone].
  static tz.TZDateTime inZone(DateTime instant, tz.Location zone) =>
      tz.TZDateTime.from(instant.toUtc(), zone);

  /// The instant of wall time [date] [hour]:[minute] in [zone].
  static DateTime atWall(
    CalendarDate date,
    int hour,
    int minute,
    tz.Location zone,
  ) => utcOf(tz.TZDateTime(zone, date.year, date.month, date.day, hour, minute));

  /// Date of [instant] as seen in [zone].
  static CalendarDate dateIn(DateTime instant, tz.Location zone) =>
      CalendarDate.of(inZone(instant, zone));

  /// Day of an all-day boundary stored as an instant.
  ///
  /// The API keeps all-day events as full instants. Clients encode them
  /// differently (midnight in the event zone, midnight UTC), and the server
  /// expands series in UTC, which moves local midnight by an hour across
  /// DST. So: a value within ±3 h of local midnight in the event zone is
  /// that midnight; otherwise an exact UTC midnight is a UTC date; otherwise
  /// the local date. The device zone never takes part.
  static CalendarDate allDayBoundary(DateTime instant, tz.Location eventZone) {
    final local = inZone(instant, eventZone);
    final minutes = local.hour * 60 + local.minute;
    final date = CalendarDate.of(local);
    if (minutes <= 180) return date;
    if (minutes >= 21 * 60) return date.addDays(1);
    final utc = instant.toUtc();
    if (utc.hour == 0 && utc.minute == 0 && utc.second == 0) {
      return CalendarDate.of(utc);
    }
    return date;
  }

  /// `[first, endExclusive)` of an all-day event.
  static (CalendarDate, CalendarDate) allDayRange(
    DateTime start,
    DateTime end,
    tz.Location eventZone,
  ) {
    final first = allDayBoundary(start, eventZone);
    var last = allDayBoundary(end, eventZone);
    if (!last.isAfter(first)) last = first.addDays(1);
    return (first, last);
  }

  /// Encodes all-day dates `[first, lastInclusive]` as midnight instants in
  /// [eventZone] (end exclusive), the form [allDayBoundary] reads back.
  static (DateTime, DateTime) encodeAllDay(
    CalendarDate first,
    CalendarDate lastInclusive,
    tz.Location eventZone,
  ) => (
    atWall(first, 0, 0, eventZone),
    atWall(lastInclusive.addDays(1), 0, 0, eventZone),
  );

  /// Display start of a server-expanded occurrence.
  ///
  /// The server expands series by adding whole periods in UTC, so a weekly
  /// 09:00 meeting in a DST zone drifts to 10:00, and a series created in
  /// Almaty before the 2024-03-01 offset change drifts to 08:00. RFC 5545
  /// keeps the wall-clock time of DTSTART in its TZID: the occurrence's date
  /// is taken in the master's offset frame and the master's wall time is
  /// re-applied with the current zone rules. The occurrence's server key
  /// (`occurrence_start`) is not changed.
  static DateTime wallClockOccurrence({
    required DateTime occurrenceUtc,
    required DateTime masterUtc,
    required tz.Location zone,
  }) {
    final master = inZone(masterUtc, zone);
    final shifted = occurrenceUtc.toUtc().add(master.timeZoneOffset);
    return utcOf(
      tz.TZDateTime(
        zone,
        shifted.year,
        shifted.month,
        shifted.day,
        master.hour,
        master.minute,
        master.second,
      ),
    );
  }
}
