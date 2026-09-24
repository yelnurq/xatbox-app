import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:xatbox_mobile/core/api/api_client.dart';
import 'package:xatbox_mobile/core/api/api_exception.dart';
import 'package:xatbox_mobile/core/storage/app_database.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_api.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_cache.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_models.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_ops.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_reminders.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_repository.dart';
import 'package:xatbox_mobile/features/calendar/domain/calendar_time.dart';
import 'package:xatbox_mobile/features/calendar/domain/recurrence.dart';

import '../helpers/calendar_fake_server.dart';
import '../helpers/fake_http.dart';

/// Repository against an in-memory calendar server that follows the
/// documented API behaviour (strict bodies, UTC expansion, exceptions,
/// sequence). Covers idempotent creation, offline reading, recurring edits,
/// conflicts, RSVP and reminders.
void main() {
  setUpAll(CalendarZones.ensureInitialized);

  const alice = FakeCalendarUser(id: 'aaaaaaaa-0000-4000-8000-000000000001', token: 'tok-alice', name: 'Алия', org: 'org-a');
  const bob = FakeCalendarUser(id: 'bbbbbbbb-0000-4000-8000-000000000002', token: 'tok-bob', name: 'Болат', org: 'org-a');
  const eve = FakeCalendarUser(id: 'eeeeeeee-0000-4000-8000-000000000003', token: 'tok-eve', name: 'Ева', org: 'org-b');

  late AppDatabase db;
  late FakeHttpAdapter http;
  late FakeHttpAdapter chatHttp;
  late FakeCalendarServer server;
  late int unauthenticated;
  var ids = 0;
  final clock = DateTime.utc(2026, 9, 14, 6); // Monday, 11:00 in Almaty
  final almaty = CalendarZones.location('Asia/Almaty');

  setUp(() async {
    db = await AppDatabase.inMemory();
    http = FakeHttpAdapter();
    chatHttp = FakeHttpAdapter();
    chatHttp.onPattern('POST', r'^/calendar/events/[^/]+/notify$', (_) => const FakeResponse(204));
    server = FakeCalendarServer(http, const [alice, bob, eve]);
    unauthenticated = 0;
  });
  tearDown(() => db.close());

  CalendarRepository repoFor(FakeCalendarUser user, {AppDatabase? database}) {
    ApiClient client(FakeHttpAdapter a, String base) => ApiClient(
      baseUrl: base,
      userAgent: 'test',
      adapter: a,
      tokenReader: () => user.token,
      onUnauthenticated: () => unauthenticated++,
    );
    return CalendarRepository(
      api: CalendarApi(client(http, 'http://test.local/api/v1')),
      relay: CalendarRelay(client(chatHttp, 'http://chat.local/api/v1')),
      cache: CalendarCache(database ?? db),
      selfId: () => user.id,
      clock: () => clock,
      newId: () => 'id-${ids++}',
    );
  }

  EventDraft single(String title, {CalendarDate day = const CalendarDate(2026, 9, 15), int hour = 9, List<DraftParticipant> guests = const []}) {
    final start = EventTime.atWall(day, hour, 0, almaty);
    return EventDraft(title: title, start: start, end: start.add(const Duration(hours: 1)), timezone: 'Asia/Almaty', participants: guests, reminders: const [10]);
  }

  EventDraft weekly({int count = 52}) {
    final start = EventTime.atWall(const CalendarDate(2026, 9, 14), 9, 0, almaty);
    return EventDraft(
      title: 'Планёрка',
      start: start,
      end: start.add(const Duration(hours: 1)),
      timezone: 'Asia/Almaty',
      recurrence: RecurrenceSpec(frequency: RepeatFrequency.weekly, count: count),
      reminders: const [10],
    );
  }

  EventDraft draftOf(CalendarOccurrence o) => EventDraft(
    title: o.event.title,
    description: o.event.description,
    location: o.event.location,
    start: o.start,
    end: o.end,
    timezone: o.event.timezone,
    allDay: o.event.allDay,
    recurrence: o.event.recurrence,
    reminders: [o.event.reminderMinutes],
  );

  Future<List<CalendarOccurrence>> window(CalendarRepository r, CalendarDate from, CalendarDate to, [tz.Location? device]) =>
      r.occurrences(from: from, to: to, device: device ?? almaty);

  Future<void> settleRelay() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('idempotent creation (API has no client id)', () {
    test('response lost after the server committed → retry finds it, no duplicate', () async {
      final repo = repoFor(alice);
      server.dropNextCreateResponse = true;
      await repo.create(single('Отчёт'));
      await repo.flush();
      expect(server.createCalls, 1);
      final queued = await repo.cache.ops();
      expect(queued.single.payload['maybe_sent'], isTrue);

      var shown = await window(repo, const CalendarDate(2026, 9, 15), const CalendarDate(2026, 9, 16));
      expect(shown, hasLength(1));
      expect(shown.single.pending, isTrue);

      await repo.flush();
      expect(server.createCalls, 1, reason: 'reconciled, no second POST');
      expect(server.events, hasLength(1));
      expect(await repo.cache.ops(), isEmpty);
      shown = await window(repo, const CalendarDate(2026, 9, 15), const CalendarDate(2026, 9, 16));
      expect(shown, hasLength(1));
      expect(shown.single.pending, isFalse);
      expect(shown.single.event.id, server.events.keys.single);
    });

    test('created offline, shown at once, sent once when the network returns', () async {
      final repo = repoFor(alice);
      server.offline = true;
      await repo.create(single('Без сети'));
      await repo.flush();
      expect(server.createCalls, 0);
      expect((await window(repo, const CalendarDate(2026, 9, 15), const CalendarDate(2026, 9, 16))).single.pending, isTrue);

      server.offline = false;
      await repo.flush();
      await repo.flush();
      expect(server.createCalls, 1);
      expect(server.events, hasLength(1));
      // Only documented fields were sent (the fake rejects anything else).
      final body = http.of('POST', '/calendar/events').last.json;
      expect(body.keys.toSet().difference({
        'title', 'description', 'starts_at', 'ends_at', 'all_day', 'location', 'meeting_link',
        'event_type', 'audience_type', 'visibility', 'timezone', 'rrule', 'reminder_minutes',
        'user_ids', 'external_emails',
      }), isEmpty);
    });
  });

  group('offline reading', () {
    test('the synced month opens without network, also after an app restart', () async {
      final repo = repoFor(alice);
      await repo.create(single('Совещание', day: const CalendarDate(2026, 9, 25)));
      await repo.flush();
      await repo.sync(around: const CalendarDate(2026, 9, 14), device: almaty);

      server.offline = true;
      final restarted = repoFor(alice); // same database, new process
      final shown = await window(restarted, const CalendarDate(2026, 9, 1), const CalendarDate(2026, 10, 1));
      expect(shown.map((o) => o.event.title), ['Совещание']);
      await expectLater(
        restarted.sync(around: const CalendarDate(2026, 9, 14), device: almaty),
        throwsA(isA<NetworkException>()),
      );
      expect(await window(restarted, const CalendarDate(2026, 9, 1), const CalendarDate(2026, 10, 1)), hasLength(1));
    });
  });

  group('time zones at repository level', () {
    test('timed event lands on the right day after the device zone changes', () async {
      final repo = repoFor(alice);
      await repo.create(single('Утро', hour: 9)); // 2026-09-15 09:00 Almaty = 04:00Z
      await repo.flush();
      await repo.sync(around: const CalendarDate(2026, 9, 14), device: almaty);

      final inAlmaty = await window(repo, const CalendarDate(2026, 9, 15), const CalendarDate(2026, 9, 16));
      expect(EventTime.inZone(inAlmaty.single.start, almaty).hour, 9);

      final la = CalendarZones.location('America/Los_Angeles');
      expect(await window(repo, const CalendarDate(2026, 9, 15), const CalendarDate(2026, 9, 16), la), isEmpty);
      final inLa = await window(repo, const CalendarDate(2026, 9, 14), const CalendarDate(2026, 9, 15), la);
      expect(EventTime.inZone(inLa.single.start, la).hour, 21);
    });

    test('all-day event stays on its date in every device zone', () async {
      final repo = repoFor(alice);
      const day = CalendarDate(2026, 9, 20);
      final (s, e) = EventTime.encodeAllDay(day, day, almaty);
      await repo.create(EventDraft(title: 'День города', start: s, end: e, allDay: true, timezone: 'Asia/Almaty'));
      await repo.flush();
      await repo.sync(around: day, device: almaty);

      for (final name in const ['Pacific/Kiritimati', 'Asia/Almaty', 'Europe/Berlin', 'UTC', 'America/Los_Angeles', 'Pacific/Pago_Pago']) {
        final device = CalendarZones.location(name);
        final on = await window(repo, day, day.addDays(1), device);
        expect(on.single.allDayStart, day, reason: name);
        expect(await window(repo, day.addDays(-1), day, device), isEmpty, reason: '$name day before');
        expect(await window(repo, day.addDays(1), day.addDays(2), device), isEmpty, reason: '$name day after');
      }
    });
  });

  group('weekly series for a year', () {
    Future<(CalendarRepository, List<CalendarOccurrence>)> seeded() async {
      final repo = repoFor(alice);
      await repo.create(weekly());
      await repo.flush();
      await repo.sync(around: const CalendarDate(2026, 10, 1), device: almaty);
      final occ = await window(repo, const CalendarDate(2026, 9, 1), const CalendarDate(2026, 12, 1));
      return (repo, occ);
    }

    test('expanded at 09:00 local; the server ignores COUNT, the app does not', () async {
      final (repo, occ) = await seeded();
      expect(occ, hasLength(12)); // Sep 14 … Nov 30
      expect(occ.every((o) => EventTime.inZone(o.start, almaty).hour == 9), isTrue);

      // COUNT=3: the server still returns every week, the app shows three.
      final shortOwner = repoFor(alice);
      await shortOwner.create(weekly(count: 3).copyWith(title: 'Три раза'));
      await shortOwner.flush();
      await shortOwner.sync(around: const CalendarDate(2026, 10, 1), device: almaty);
      final three = (await window(shortOwner, const CalendarDate(2026, 9, 1), const CalendarDate(2026, 12, 1)))
          .where((o) => o.event.title == 'Три раза');
      expect(three, hasLength(3));
      expect(repo.selfId, alice.id);
    });

    test('moving one occurrence creates one exception and leaves the others', () async {
      final (repo, before) = await seeded();
      final target = before[3]; // Oct 5
      final moved = target.start.add(const Duration(hours: 2));
      await repo.edit(
        occurrence: target,
        draft: draftOf(target).copyWith(start: moved, end: moved.add(const Duration(hours: 1))),
        scope: EditScope.thisOccurrence,
      );
      await repo.flush();

      expect(server.exceptions, hasLength(1));
      expect(server.patchCalls, 0);
      final after = await window(repo, const CalendarDate(2026, 9, 1), const CalendarDate(2026, 12, 1));
      expect(after, hasLength(12));
      for (var i = 0; i < 12; i++) {
        if (i == 3) continue;
        expect(after[i].start, before[i].start, reason: 'occurrence $i untouched');
        expect(after[i].event.isOverride, isFalse);
      }
      expect(after[3].start, moved);
      expect(after[3].event.isOverride, isTrue);
    });

    test('renaming one occurrence goes through its override event', () async {
      final (repo, before) = await seeded();
      final target = before[1];
      await repo.edit(occurrence: target, draft: draftOf(target).copyWith(title: 'Планёрка (перенос зала)'), scope: EditScope.thisOccurrence);
      await repo.flush();
      final after = await window(repo, const CalendarDate(2026, 9, 1), const CalendarDate(2026, 12, 1));
      expect(after.where((o) => o.event.title == 'Планёрка (перенос зала)'), hasLength(1));
      expect(after.where((o) => o.event.title == 'Планёрка'), hasLength(11));
      expect(await repo.cache.ops(), isEmpty);
    });

    test('"delete this and following" cancels only future occurrences up to the series end', () async {
      final (repo, before) = await seeded();
      final from = before[10]; // Nov 23, 11th occurrence
      await repo.delete(occurrence: from, scope: EditScope.following);
      await repo.flush();

      final cancelled = server.exceptions.where((x) => x['cancelled'] == true).toList();
      expect(cancelled, hasLength(42), reason: 'occurrences #10…#51 of COUNT=52');
      final fromKey = EventTime.parse(from.event.occurrenceStartRaw)!;
      expect(cancelled.every((x) => !(x['occurrence_start'] as DateTime).isBefore(fromKey)), isTrue, reason: 'the past is not touched');
      expect(server.events.values.single['status'], 'confirmed');

      final after = await window(repo, const CalendarDate(2026, 9, 1), const CalendarDate(2026, 12, 1));
      expect(after, hasLength(10));
      for (var i = 0; i < 10; i++) {
        expect(after[i].start, before[i].start);
      }
    });

    test('editing the whole series patches it once', () async {
      final (repo, before) = await seeded();
      await repo.edit(occurrence: before[5], draft: draftOf(before[5]).copyWith(title: 'Планёрка отдела'), scope: EditScope.all);
      await repo.flush();
      expect(server.patchCalls, 1);
      expect(server.exceptions, isEmpty);
      final after = await window(repo, const CalendarDate(2026, 9, 1), const CalendarDate(2026, 12, 1));
      expect(after.every((o) => o.event.title == 'Планёрка отдела'), isTrue);
      expect(after, hasLength(12));
    });

    test('"edit this and following" splits the series', () async {
      final (repo, before) = await seeded();
      final from = before[4];
      final later = from.start.add(const Duration(hours: 1));
      await repo.edit(
        occurrence: from,
        draft: draftOf(from).copyWith(start: later, end: later.add(const Duration(hours: 1))),
        scope: EditScope.following,
      );
      await repo.flush();
      expect(server.events.values.where((e) => e['rrule'] != null), hasLength(2));
      final newSeries = server.events.values.firstWhere((e) => e['sequence'] == 0 && e['id'] != server.events.keys.first);
      expect(newSeries['rrule'], 'FREQ=WEEKLY;COUNT=48');
      final after = await window(repo, const CalendarDate(2026, 9, 1), const CalendarDate(2026, 12, 1));
      expect(after, hasLength(12));
      expect(after.take(4).every((o) => EventTime.inZone(o.start, almaty).hour == 9), isTrue);
      expect(after.skip(4).every((o) => EventTime.inZone(o.start, almaty).hour == 10), isTrue);
    });
  });

  group('conflicts and permissions', () {
    test('changed on another device → conflict, nothing overwritten until the user decides', () async {
      final repo = repoFor(alice);
      await repo.create(single('Бюджет'));
      await repo.flush();
      await repo.sync(around: const CalendarDate(2026, 9, 14), device: almaty);
      final occ = (await window(repo, const CalendarDate(2026, 9, 15), const CalendarDate(2026, 9, 16))).single;
      final id = occ.event.id;

      server.patchDirect(id, {'title': 'Бюджет (ноутбук)'});
      await repo.edit(occurrence: occ, draft: draftOf(occ).copyWith(title: 'Бюджет (телефон)'), scope: EditScope.single);
      await repo.flush();

      final problems = await repo.problems();
      expect(problems.single.status, OpStatus.conflict);
      expect(server.events[id]!['title'], 'Бюджет (ноутбук)');

      await repo.retry(problems.single.id, overwrite: true);
      expect(server.events[id]!['title'], 'Бюджет (телефон)');
      expect(await repo.problems(), isEmpty);
    });

    test('event of another organization is not found (server-side tenant scope)', () async {
      final owner = repoFor(alice);
      await owner.create(single('Внутреннее'));
      await owner.flush();
      final id = server.events.keys.single;
      final stranger = repoFor(eve, database: await AppDatabase.inMemory());
      await expectLater(stranger.detail(id), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'EVENT_NOT_FOUND')));
      await stranger.sync(around: const CalendarDate(2026, 9, 14), device: almaty);
      expect(await window(stranger, const CalendarDate(2026, 9, 1), const CalendarDate(2026, 10, 1)), isEmpty);
    });

    test('401 from the calendar API triggers the global sign-out', () async {
      final ghost = repoFor(const FakeCalendarUser(id: 'x', token: 'dead', name: '', org: 'org-a'));
      await expectLater(
        ghost.sync(around: const CalendarDate(2026, 9, 14), device: almaty),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
      expect(unauthenticated, 1);
    });
  });

  group('invitations', () {
    test('invitee answers, organizer sees the answer; colleagues get a relay signal', () async {
      final organizer = repoFor(alice);
      await organizer.create(single('Защита проекта', guests: [DraftParticipant.internal(userId: bob.id, label: bob.name)]));
      await organizer.flush();
      await settleRelay();
      expect(chatHttp.requests.where((r) => r.path.endsWith('/notify')).single.json, {'kind': 'invited'});

      final invitee = repoFor(bob, database: await AppDatabase.inMemory());
      await invitee.sync(around: const CalendarDate(2026, 9, 14), device: almaty);
      final pending = await invitee.invitations(device: almaty);
      expect(pending.single.event.title, 'Защита проекта');

      await invitee.respond(pending.single.event, RsvpStatus.accepted);
      await invitee.flush();
      await settleRelay();
      expect(await invitee.invitations(device: almaty), isEmpty);
      expect(chatHttp.requests.last.json, {'kind': 'rsvp'});

      final detail = await organizer.detail(pending.single.event.id, refresh: true);
      expect(detail!.participantFor(bob.id)!.responseStatus, RsvpStatus.accepted);
    });
  });

  group('reminders', () {
    test('stable ids: re-planning never duplicates; declined and past are skipped', () async {
      final repo = repoFor(alice);
      await repo.create(single('С напоминанием', hour: 15));
      await repo.create(single('Отклонено', hour: 16));
      await repo.flush();
      await repo.sync(around: const CalendarDate(2026, 9, 14), device: almaty);
      final occ = await window(repo, const CalendarDate(2026, 9, 14), const CalendarDate(2026, 9, 28));
      final declined = occ[1].copyWith(event: occ[1].event.copyWithRaw({'response_status': 'declined'}));
      final all = [occ[0], declined];

      final scheduler = _RecordingScheduler();
      final service = CalendarReminderService(scheduler: scheduler, cache: repo.cache);
      List<ReminderRequest> plan() => ReminderPlanner.plan(
        occurrences: all,
        localReminders: {occ[0].event.id: [10, 60]},
        now: clock,
        device: almaty,
        describe: (_) => '',
      );
      await service.apply(plan());
      await service.apply(plan());
      expect(scheduler.active.length, 2, reason: '10 and 60 minutes for one event');
      expect(scheduler.permissionRequests, 1);
      expect(plan().map((r) => r.fireAt), [
        occ[0].start.subtract(const Duration(minutes: 60)),
        occ[0].start.subtract(const Duration(minutes: 10)),
      ]);

      await service.apply(const []);
      expect(scheduler.active, isEmpty);
    });

    test('all-day reminders fire relative to 09:00 of the day in the device zone', () {
      const day = CalendarDate(2026, 9, 16);
      final (s, e) = EventTime.encodeAllDay(day, day, almaty);
      final event = CalendarEvent.fromJson({
        'id': 'e1', 'title': 'Отпуск', 'all_day': true, 'timezone': 'Asia/Almaty',
        'starts_at': EventTime.encode(s), 'ends_at': EventTime.encode(e), 'reminder_minutes': 0,
      });
      final plan = ReminderPlanner.plan(
        occurrences: [CalendarOccurrence(event: event, start: s, end: e, allDayStart: day, allDayEnd: day.addDays(1))],
        localReminders: const {},
        now: clock,
        device: almaty,
        describe: (_) => '',
      );
      expect(EventTime.inZone(plan.single.fireAt, almaty).hour, 9);
      expect(ReminderPlanner.stableId('a|10'), ReminderPlanner.stableId('a|10'));
      expect(ReminderPlanner.stableId('a|10'), isNot(ReminderPlanner.stableId('a|15')));
    });
  });
}

class _RecordingScheduler implements ReminderScheduler {
  final Map<int, ReminderRequest> active = {};
  int permissionRequests = 0;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<void> schedule(ReminderRequest request) async => active[request.id] = request;

  @override
  Future<void> cancel(int id) async => active.remove(id);
}
