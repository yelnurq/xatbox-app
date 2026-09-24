import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/api/api_exception.dart';
import 'package:xatbox_mobile/core/auth/auth_providers.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_api.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_models.dart';
import 'package:xatbox_mobile/features/calendar/domain/calendar_time.dart';
import 'package:xatbox_mobile/features/calendar/presentation/calendar_providers.dart';

import '../helpers/calendar_fake_server.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Request bodies of free-busy / find-time use only fields documented in
/// `CalendarFreeBusyRequest` (the API rejects unknown ones), and responses in
/// both timestamp formats are parsed.
void main() {
  setUpAll(CalendarZones.ensureInitialized);

  const documented = {'user_ids', 'start', 'end', 'duration_minutes', 'timezone', 'resource_id'};
  const createDocumented = {
    'organization_id', 'title', 'description', 'starts_at', 'ends_at', 'all_day', 'location',
    'meeting_link', 'event_type', 'audience_type', 'visibility', 'attendance', 'timezone', 'rrule',
    'reminder_minutes', 'user_ids', 'department_ids', 'external_emails', 'resource_id',
  };
  final start = DateTime.utc(2026, 9, 16, 19);
  final end = DateTime.utc(2026, 9, 17, 19);

  group('request bodies', () {
    test('free-busy: documented keys only, distinct users, room optional', () {
      final body = CalendarApi.freeBusyBody(userIds: ['me', 'bob', 'me'], start: start, end: end);
      expect(body.keys.toSet(), {'user_ids', 'start', 'end'});
      expect(documented.containsAll(body.keys), isTrue);
      expect(body['user_ids'], ['me', 'bob']);
      expect(body['start'], '2026-09-16T19:00:00Z');
      expect(body['end'], '2026-09-17T19:00:00Z');

      final withRoom = CalendarApi.freeBusyBody(userIds: ['me'], start: start, end: end, resourceId: 'room-1');
      expect(withRoom.keys.toSet(), {'user_ids', 'start', 'end', 'resource_id'});
      expect(CalendarApi.freeBusyBody(userIds: ['me'], start: start, end: end, resourceId: '').containsKey('resource_id'), isFalse);
    });

    test('find-time: no room or timezone (ignored by the API), duration only when positive', () {
      final body = CalendarApi.findTimeBody(userIds: ['me', 'bob'], start: start, end: end, durationMinutes: 45);
      expect(body.keys.toSet(), {'user_ids', 'start', 'end', 'duration_minutes'});
      expect(body['duration_minutes'], 45);
      expect(CalendarApi.findTimeBody(userIds: ['me'], start: start, end: end, durationMinutes: 0).keys.toSet(), {'user_ids', 'start', 'end'});
    });

    test('the window is clamped to 62 days', () {
      final body = CalendarApi.findTimeBody(userIds: ['me'], start: start, end: start.add(const Duration(days: 90)));
      expect(DateTime.parse(body['end'] as String).difference(start), const Duration(days: 62));
    });

    test('create sends resource_id only when a room is chosen', () {
      final draft = EventDraft(title: 'Совет', start: start, end: end, timezone: 'Asia/Almaty');
      expect(draft.toCreateBody().containsKey('resource_id'), isFalse);
      final booked = draft.copyWith(resourceId: 'room-1').toCreateBody();
      expect(booked['resource_id'], 'room-1');
      expect(createDocumented.containsAll(booked.keys), isTrue);
    });
  });

  group('against the strict fake server', () {
    late TestHarness h;
    late FakeCalendarServer server;
    const me = FakeCalendarUser(id: '11111111-1111-4111-8111-111111111111', token: Fixtures.token, name: 'Тест', org: 'org-1');
    const bob = FakeCalendarUser(id: 'bbbbbbbb-0000-4000-8000-000000000002', token: 'tok-bob', name: 'Болат', org: 'org-1');
    tearDown(() => h.dispose());

    Future<CalendarApi> setUp() async {
      h = await TestHarness.create(storedToken: Fixtures.token);
      h.adapter.onJson('GET', '/me', Fixtures.me());
      await h.session.restore();
      server = FakeCalendarServer(h.adapter, const [me, bob]);
      return h.container.read(calendarApiProvider);
    }

    test('free-busy parses RFC 3339 busy and PostgreSQL room bookings', () async {
      final api = await setUp();
      server.seedEvent(organizer: bob, title: 'x', start: DateTime.utc(2026, 9, 17, 4), end: DateTime.utc(2026, 9, 17, 5));
      server.resources.add({'id': 'room-1', 'name': 'Алатау', 'location': '3 этаж', 'capacity': 8, 'equipment': '', 'status': 'active', 'created_at': '2026-09-01 09:00:00.1+00'});
      server.roomBookings['room-1'] = [(DateTime.utc(2026, 9, 17, 9), DateTime.utc(2026, 9, 17, 10))];

      final fb = await api.freeBusy(userIds: [me.id, bob.id], start: start, end: end, resourceId: 'room-1');
      expect(fb.busy[me.id], isEmpty);
      expect(fb.busy[bob.id]!.single.start, DateTime.utc(2026, 9, 17, 4));
      expect(fb.resourceBusy.single.start, DateTime.utc(2026, 9, 17, 9));
      expect(fb.resourceBusy.single.overlaps(DateTime.utc(2026, 9, 17, 9, 30), DateTime.utc(2026, 9, 17, 11)), isTrue);
      final sent = h.adapter.of('POST', '/calendar/free-busy').single.json;
      expect(documented.containsAll(sent.keys), isTrue);
      expect(sent['user_ids'], contains(me.id), reason: 'the caller is included explicitly');
    });

    test('find-time returns at most five suggestions; resources filter active in the provider', () async {
      final api = await setUp();
      server.suggestions = [
        for (var i = 0; i < 7; i++) (DateTime.utc(2026, 9, 17, 4 + i), DateTime.utc(2026, 9, 17, 5 + i)),
      ];
      final slots = await api.findTime(userIds: [me.id, bob.id], start: start, end: end, durationMinutes: 60);
      expect(slots, hasLength(5));
      expect(slots.first.start, DateTime.utc(2026, 9, 17, 4));

      server.resources.addAll([
        {'id': 'r1', 'name': 'Алатау', 'location': '', 'capacity': 8, 'equipment': '', 'status': 'active', 'created_at': ''},
        {'id': 'r2', 'name': 'Старая', 'location': '', 'capacity': 4, 'equipment': '', 'status': 'disabled', 'created_at': ''},
      ]);
      expect((await api.resources()).map((r) => r.id), ['r1', 'r2']);
      final active = await h.container.read(calendarResourcesProvider.future);
      expect(active.map((r) => r.id), ['r1']);
    });

    test('unknown fields are rejected by the fake exactly like the API', () async {
      final api = await setUp();
      final res = await api.freeBusy(userIds: [me.id], start: start, end: end);
      expect(res.busy.keys, [me.id]);
      await expectLater(
        h.container.read(apiClientProvider).postJson('/calendar/free-busy', body: {
          'user_ids': [me.id],
          'start': EventTime.encode(start),
          'end': EventTime.encode(end),
          'include_self': true,
        }),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_BODY')),
      );
      await expectLater(
        api.freeBusy(userIds: [me.id, me.id, 'stranger'], start: start, end: end),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'FORBIDDEN')),
        reason: 'duplicates are dropped client-side, the unknown user is still refused',
      );
    });
  });
}
