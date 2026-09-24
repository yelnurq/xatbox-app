import 'package:flutter/foundation.dart';
import 'package:rrule/rrule.dart';
import 'package:timezone/timezone.dart' as tz;

import 'calendar_time.dart';

/// Frequencies the calendar server honours (it ignores everything else).
enum RepeatFrequency { daily, weekly, monthly, yearly }

/// A series rule as the app edits it: `FREQ` + `INTERVAL` (what the server
/// expands) plus `UNTIL`/`COUNT`. The server stores the rule verbatim but
/// ignores `UNTIL`/`COUNT`, so the app applies the end itself (and the ICS
/// export carries it to desktop clients).
@immutable
class RecurrenceSpec {
  const RecurrenceSpec({
    required this.frequency,
    this.interval = 1,
    this.until,
    this.count,
    this.hasUnsupportedParts = false,
  }) : assert(until == null || count == null);

  final RepeatFrequency frequency;
  final int interval;

  /// Inclusive end instant (UTC).
  final DateTime? until;
  final int? count;

  /// `BYDAY`, `BYMONTHDAY`… were present (e.g. created elsewhere). The
  /// server ignores them, so such a series is shown as the server expands it.
  final bool hasUnsupportedParts;

  bool get isInfinite => until == null && count == null;

  Frequency get _frequency => switch (frequency) {
    RepeatFrequency.daily => Frequency.daily,
    RepeatFrequency.weekly => Frequency.weekly,
    RepeatFrequency.monthly => Frequency.monthly,
    RepeatFrequency.yearly => Frequency.yearly,
  };

  /// Value for the API `rrule` field (without the `RRULE:` prefix).
  String toRRule() {
    final parts = ['FREQ=${_frequency.toString()}'];
    if (interval > 1) parts.add('INTERVAL=$interval');
    if (until != null) {
      parts.add('UNTIL=${_rruleUtc(until!)}');
    } else if (count != null) {
      parts.add('COUNT=$count');
    }
    return parts.join(';');
  }

  static String _rruleUtc(DateTime t) {
    final u = t.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${u.year.toString().padLeft(4, '0')}${two(u.month)}${two(u.day)}'
        'T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
  }

  /// Parses an API `rrule`; null for empty or unusable rules.
  static RecurrenceSpec? parse(String? rrule) {
    final text = rrule?.trim() ?? '';
    if (text.isEmpty) return null;
    final RecurrenceRule rule;
    try {
      rule = RecurrenceRule.fromString(
        text.toUpperCase().startsWith('RRULE:') ? text : 'RRULE:$text',
      );
    } on Object {
      return null;
    }
    final freq = switch (rule.frequency) {
      Frequency.daily => RepeatFrequency.daily,
      Frequency.weekly => RepeatFrequency.weekly,
      Frequency.monthly => RepeatFrequency.monthly,
      Frequency.yearly => RepeatFrequency.yearly,
      _ => null,
    };
    if (freq == null) return null;
    return RecurrenceSpec(
      frequency: freq,
      interval: rule.actualInterval,
      until: rule.until?.toUtc(),
      count: rule.count,
      hasUnsupportedParts:
          rule.hasByWeekDays ||
          rule.hasByMonthDays ||
          rule.hasByMonths ||
          rule.hasByYearDays ||
          rule.hasByWeeks ||
          rule.hasBySetPositions ||
          rule.hasByHours ||
          rule.hasByMinutes ||
          rule.hasBySeconds,
    );
  }

  RecurrenceSpec copyWith({
    RepeatFrequency? frequency,
    int? interval,
    DateTime? until,
    int? count,
    bool clearEnd = false,
  }) => RecurrenceSpec(
    frequency: frequency ?? this.frequency,
    interval: interval ?? this.interval,
    until: clearEnd ? null : (until ?? (count != null ? null : this.until)),
    count: clearEnd ? null : (count ?? (until != null ? null : this.count)),
  );

  @override
  bool operator ==(Object other) =>
      other is RecurrenceSpec &&
      other.frequency == frequency &&
      other.interval == interval &&
      other.until == until &&
      other.count == count;

  @override
  int get hashCode => Object.hash(frequency, interval, until, count);
}

/// RFC 5545 expansion through package `rrule`, in the wall-clock time of the
/// event zone (so 09:00 stays 09:00 across DST and offset changes).
abstract final class RecurrenceEngine {
  static DateTime _naive(DateTime instant, tz.Location zone) {
    final w = EventTime.inZone(instant, zone);
    return DateTime.utc(w.year, w.month, w.day, w.hour, w.minute, w.second);
  }

  static DateTime _instant(DateTime naive, tz.Location zone) => EventTime.utcOf(
    tz.TZDateTime(
      zone,
      naive.year,
      naive.month,
      naive.day,
      naive.hour,
      naive.minute,
      naive.second,
    ),
  );

  static RecurrenceRule _rule(RecurrenceSpec spec, tz.Location zone) =>
      RecurrenceRule(
        frequency: spec._frequency,
        interval: spec.interval > 1 ? spec.interval : null,
        count: spec.count,
        until: spec.until == null ? null : _naive(spec.until!, zone),
      );

  /// Occurrence starts in `[fromUtc, toUtc)`.
  static List<DateTime> expand({
    required RecurrenceSpec spec,
    required DateTime masterUtc,
    required tz.Location zone,
    required DateTime fromUtc,
    required DateTime toUtc,
    int limit = 500,
  }) {
    final out = <DateTime>[];
    final instances = _rule(
      spec,
      zone,
    ).getInstances(start: _naive(masterUtc, zone));
    for (final naive in instances) {
      final instant = _instant(naive, zone);
      if (!instant.isBefore(toUtc)) break;
      if (!instant.isBefore(fromUtc)) out.add(instant);
      if (out.length >= limit) break;
    }
    return out;
  }

  /// Start of the last occurrence of a finite series; null when infinite.
  static DateTime? lastStart({
    required RecurrenceSpec spec,
    required DateTime masterUtc,
    required tz.Location zone,
  }) {
    if (spec.isInfinite) return null;
    DateTime? last;
    for (final naive in _rule(
      spec,
      zone,
    ).getInstances(start: _naive(masterUtc, zone))) {
      last = naive;
    }
    return last == null ? masterUtc : _instant(last, zone);
  }

  /// Number of occurrences that start before [displayStartUtc].
  static int countBefore({
    required RecurrenceSpec spec,
    required DateTime masterUtc,
    required tz.Location zone,
    required DateTime displayStartUtc,
  }) {
    var n = 0;
    for (final naive in _rule(
      spec,
      zone,
    ).getInstances(start: _naive(masterUtc, zone))) {
      if (!_instant(naive, zone).isBefore(displayStartUtc)) break;
      n++;
    }
    return n;
  }
}
