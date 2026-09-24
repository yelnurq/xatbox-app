import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:xatbox_mobile/features/calendar/domain/calendar_time.dart';
import 'package:xatbox_mobile/features/calendar/domain/recurrence.dart';

/// Time zones, all-day dates and recurrence: the calendar logic most likely
/// to break silently, so every rule is pinned by a test.
void main() {
  setUpAll(CalendarZones.ensureInitialized);

  tz.Location zone(String name) => CalendarZones.location(name);
  DateTime utc(int y, int m, int d, [int h = 0, int mi = 0]) =>
      DateTime.utc(y, m, d, h, mi);

  const zonesAroundTheWorld = [
    'Pacific/Kiritimati', // +14
    'Pacific/Auckland', // +12/+13 DST
    'Asia/Almaty', // +5 (was +6 before 2024-03-01)
    'Europe/Moscow', // +3
    'Europe/Berlin', // +1/+2 DST
    'UTC',
    'America/Sao_Paulo', // -3
    'America/New_York', // -5/-4 DST
    'America/Los_Angeles', // -8/-7 DST
    'Pacific/Pago_Pago', // -11
  ];

  group('API timestamps', () {
    test('both RFC 3339 and PostgreSQL text forms parse to the same instant', () {
      expect(EventTime.parse('2026-09-14T09:00:00Z'), utc(2026, 9, 14, 9));
      expect(EventTime.parse('2026-09-14 09:00:00+00'), utc(2026, 9, 14, 9));
      expect(
        EventTime.parse('2026-09-14 14:00:00.123456+05'),
        DateTime.utc(2026, 9, 14, 9, 0, 0, 123, 456),
      );
    });

    test('encode is RFC 3339 UTC without fractions', () {
      expect(
        EventTime.encode(DateTime.utc(2026, 9, 14, 4, 5, 6, 789)),
        '2026-09-14T04:05:06Z',
      );
    });
  });

  group('timed events', () {
    test('created in Asia/Almaty, shown right after the device zone changes', () {
      // 09:00 in Almaty is stored as an absolute instant.
      final start = EventTime.atWall(
        const CalendarDate(2026, 9, 14),
        9,
        0,
        zone('Asia/Almaty'),
      );
      expect(start, utc(2026, 9, 14, 4));
      // Device in Almaty.
      final inAlmaty = EventTime.inZone(start, zone('Asia/Almaty'));
      expect([inAlmaty.day, inAlmaty.hour], [14, 9]);
      // The traveller switches the phone to Moscow: same moment, 07:00.
      final inMoscow = EventTime.inZone(start, zone('Europe/Moscow'));
      expect([inMoscow.day, inMoscow.hour], [14, 7]);
      // …and to Los Angeles: previous evening.
      final inLa = EventTime.inZone(start, zone('America/Los_Angeles'));
      expect([inLa.day, inLa.hour], [13, 21]);
    });

    test('historical Almaty offset: +6 before 2024-03-01, +5 after', () {
      expect(
        EventTime.inZone(utc(2024, 2, 20, 3), zone('Asia/Almaty')).hour,
        9,
      );
      expect(
        EventTime.inZone(utc(2024, 3, 20, 3), zone('Asia/Almaty')).hour,
        8,
      );
    });
  });

  group('all-day events are dates, not instants', () {
    test('encoded in any zone, read back in that zone → the same day', () {
      for (final name in zonesAroundTheWorld) {
        final z = zone(name);
        for (final day in const [
          CalendarDate(2026, 1, 1),
          CalendarDate(2026, 3, 29), // EU DST switch
          CalendarDate(2026, 11, 1), // US DST end
          CalendarDate(2026, 12, 31),
        ]) {
          final (s, e) = EventTime.encodeAllDay(day, day, z);
          final (first, end) = EventTime.allDayRange(s, e, z);
          expect(first, day, reason: '$name start $day');
          expect(end, day.addDays(1), reason: '$name end $day');
        }
      }
    });

    test('midnight-UTC encoding by another client keeps the UTC date in every zone', () {
      for (final name in zonesAroundTheWorld) {
        final (first, end) = EventTime.allDayRange(
          utc(2026, 9, 14),
          utc(2026, 9, 15),
          zone(name),
        );
        expect(first, const CalendarDate(2026, 9, 14), reason: name);
        expect(end, const CalendarDate(2026, 9, 15), reason: name);
      }
    });

    test('server UTC expansion across DST (local 23:00 / 01:00) stays on the day', () {
      final berlin = zone('Europe/Berlin');
      // Weekly all-day series from Mon 2026-03-23 (midnight CET = 23:00Z).
      final master = EventTime.atWall(const CalendarDate(2026, 3, 23), 0, 0, berlin);
      // The server adds 7×24 h in UTC: after the switch that is 01:00 CEST.
      final next = master.add(const Duration(days: 7));
      expect(EventTime.inZone(next, berlin).hour, 1);
      expect(EventTime.allDayBoundary(next, berlin), const CalendarDate(2026, 3, 30));
      // Back in autumn: 23:00 the previous evening.
      final autumn = EventTime.atWall(const CalendarDate(2026, 10, 19), 0, 0, berlin);
      final after = autumn.add(const Duration(days: 7));
      expect(EventTime.inZone(after, berlin).hour, 23);
      expect(EventTime.allDayBoundary(after, berlin), const CalendarDate(2026, 10, 26));
    });

    test('multi-day range and degenerate end', () {
      final z = zone('Asia/Almaty');
      final (s, e) = EventTime.encodeAllDay(
        const CalendarDate(2026, 9, 14),
        const CalendarDate(2026, 9, 16),
        z,
      );
      final (first, end) = EventTime.allDayRange(s, e, z);
      expect([first, end], const [CalendarDate(2026, 9, 14), CalendarDate(2026, 9, 17)]);
      final (f2, e2) = EventTime.allDayRange(s, s, z);
      expect(e2, f2.addDays(1));
    });
  });

  group('recurring occurrences keep their wall-clock time', () {
    test('Europe/Berlin weekly 09:00 across the March DST switch', () {
      final berlin = zone('Europe/Berlin');
      final master = EventTime.atWall(const CalendarDate(2026, 3, 23), 9, 0, berlin);
      expect(master, utc(2026, 3, 23, 8));
      final serverOccurrence = master.add(const Duration(days: 7)); // 08:00Z = 10:00 CEST
      final display = EventTime.wallClockOccurrence(
        occurrenceUtc: serverOccurrence,
        masterUtc: master,
        zone: berlin,
      );
      expect(display, utc(2026, 3, 30, 7));
      expect(EventTime.inZone(display, berlin).hour, 9);
    });

    test('Asia/Almaty series created before the 2024 offset change does not drift', () {
      final almaty = zone('Asia/Almaty');
      final master = EventTime.atWall(const CalendarDate(2024, 2, 26), 9, 0, almaty);
      expect(master, utc(2024, 2, 26, 3)); // +6 then
      final serverOccurrence = master.add(const Duration(days: 7)); // 03:00Z = 08:00 (+5)
      final display = EventTime.wallClockOccurrence(
        occurrenceUtc: serverOccurrence,
        masterUtc: master,
        zone: almaty,
      );
      expect(EventTime.inZone(display, almaty).hour, 9);
      expect(display, utc(2024, 3, 4, 4));
    });

    test('late-evening series does not jump to the next day', () {
      final ny = zone('America/New_York');
      final master = EventTime.atWall(const CalendarDate(2026, 3, 2), 23, 30, ny);
      final serverOccurrence = master.add(const Duration(days: 7)); // after US DST start
      final display = EventTime.wallClockOccurrence(
        occurrenceUtc: serverOccurrence,
        masterUtc: master,
        zone: ny,
      );
      final w = EventTime.inZone(display, ny);
      expect([w.month, w.day, w.hour, w.minute], [3, 9, 23, 30]);
    });
  });

  group('RRULE', () {
    test('toRRule / parse round trip', () {
      final spec = RecurrenceSpec(
        frequency: RepeatFrequency.weekly,
        interval: 2,
        until: utc(2027, 9, 14, 23, 59),
      );
      expect(spec.toRRule(), 'FREQ=WEEKLY;INTERVAL=2;UNTIL=20270914T235900Z');
      expect(RecurrenceSpec.parse(spec.toRRule()), spec);
      expect(
        RecurrenceSpec.parse('FREQ=DAILY;COUNT=10'),
        const RecurrenceSpec(frequency: RepeatFrequency.daily, count: 10),
      );
      expect(RecurrenceSpec.parse('FREQ=MONTHLY')!.isInfinite, isTrue);
      expect(RecurrenceSpec.parse('RRULE:FREQ=YEARLY')!.frequency, RepeatFrequency.yearly);
    });

    test('unsupported and broken rules', () {
      expect(RecurrenceSpec.parse(''), isNull);
      expect(RecurrenceSpec.parse('garbage'), isNull);
      expect(RecurrenceSpec.parse('FREQ=HOURLY'), isNull);
      expect(RecurrenceSpec.parse('FREQ=WEEKLY;BYDAY=MO,WE')!.hasUnsupportedParts, isTrue);
    });

    test('weekly for a year: 52 occurrences, all at 09:00 local through DST', () {
      final berlin = zone('Europe/Berlin');
      final master = EventTime.atWall(const CalendarDate(2026, 1, 5), 9, 0, berlin);
      const spec = RecurrenceSpec(frequency: RepeatFrequency.weekly, count: 52);
      final all = RecurrenceEngine.expand(
        spec: spec,
        masterUtc: master,
        zone: berlin,
        fromUtc: utc(2025, 1, 1),
        toUtc: utc(2028, 1, 1),
      );
      expect(all, hasLength(52));
      expect(all.every((t) => EventTime.inZone(t, berlin).hour == 9), isTrue);
      expect(
        RecurrenceEngine.lastStart(spec: spec, masterUtc: master, zone: berlin),
        all.last,
      );
      expect(
        RecurrenceEngine.countBefore(
          spec: spec,
          masterUtc: master,
          zone: berlin,
          displayStartUtc: all[10],
        ),
        10,
      );
    });

    test('UNTIL is inclusive and infinite series have no last start', () {
      final z = zone('Asia/Almaty');
      final master = EventTime.atWall(const CalendarDate(2026, 9, 1), 10, 0, z);
      final spec = RecurrenceSpec(
        frequency: RepeatFrequency.daily,
        until: master.add(const Duration(days: 4)),
      );
      final occ = RecurrenceEngine.expand(
        spec: spec,
        masterUtc: master,
        zone: z,
        fromUtc: master,
        toUtc: master.add(const Duration(days: 30)),
      );
      expect(occ, hasLength(5));
      expect(
        RecurrenceEngine.lastStart(
          spec: const RecurrenceSpec(frequency: RepeatFrequency.daily),
          masterUtc: master,
          zone: z,
        ),
        isNull,
      );
    });

    test('expansion window is bounded for infinite series', () {
      final z = zone('UTC');
      final master = utc(2020, 1, 1, 9);
      final occ = RecurrenceEngine.expand(
        spec: const RecurrenceSpec(frequency: RepeatFrequency.daily),
        masterUtc: master,
        zone: z,
        fromUtc: utc(2026, 9, 1),
        toUtc: utc(2026, 10, 1),
      );
      expect(occ, hasLength(30));
      expect(occ.first, utc(2026, 9, 1, 9));
    });
  });

  group('CalendarDate', () {
    test('arithmetic and ordering', () {
      const d = CalendarDate(2026, 1, 31);
      expect(d.addDays(1), const CalendarDate(2026, 2, 1));
      expect(d.addMonths(1), const CalendarDate(2026, 2, 28));
      expect(const CalendarDate(2026, 9, 17).startOfWeek, const CalendarDate(2026, 9, 14));
      expect(d.daysUntil(const CalendarDate(2026, 2, 2)), 2);
      expect(CalendarDate.parse(d.key), d);
    });
  });
}
