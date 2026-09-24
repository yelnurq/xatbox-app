import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_reminders.dart';
import 'package:xatbox_mobile/features/calendar/domain/calendar_time.dart';
import 'package:xatbox_mobile/features/calendar/presentation/calendar_providers.dart';
import 'package:xatbox_mobile/features/calendar/presentation/event_detail_screen.dart';
import 'package:xatbox_mobile/features/calendar/presentation/event_edit_screen.dart';
import 'package:xatbox_mobile/features/calls/presentation/call_screen.dart';
import 'package:xatbox_mobile/features/calls/presentation/calls_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';

import '../helpers/calendar_fake_server.dart';
import '../helpers/call_fakes.dart';
import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Event form scheduling (free-busy, find-time chips, rooms) and joining a
/// call from the event, through the real app and router.
void main() {
  setUpAll(CalendarZones.ensureInitialized);

  late TestHarness h;
  late FakeCalendarServer server;
  final clock = DateTime.utc(2026, 9, 14, 6); // Monday 11:00 in Almaty
  final almaty = CalendarZones.location('Asia/Almaty');
  const org = '33333333-3333-4333-8333-333333333333';
  const me = FakeCalendarUser(
    id: '11111111-1111-4111-8111-111111111111',
    token: Fixtures.token,
    name: 'Тест Пользователь',
    org: org,
  );
  const bob = FakeCalendarUser(
    id: 'bbbbbbbb-0000-4000-8000-000000000002',
    token: 'tok-bob',
    name: 'Болат Сейтов',
    org: org,
  );
  const carol = FakeCalendarUser(
    id: 'cccccccc-0000-4000-8000-000000000003',
    token: 'tok-carol',
    name: 'Карина Ахметова',
    org: org,
  );
  const permissions = [
    'mail.read',
    'mail.send',
    'calendar.events.read',
    'calendar.events.create',
    'calendar.events.manage_own',
  ];
  const documented = {
    'user_ids',
    'start',
    'end',
    'duration_minutes',
    'timezone',
    'resource_id',
  };

  DateTime at(int d, int hour) =>
      EventTime.atWall(CalendarDate(2026, 9, d), hour, 0, almaty);

  tearDown(() => h.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 12]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> prepare({bool calls = false}) async {
    h = await TestHarness.create(
      storedToken: Fixtures.token,
      chatBaseUrl: 'http://chat.local/api/v1',
      callsBaseUrl: calls ? 'http://calls.local/api/v1' : '',
      overrides: [
        initialDeviceZoneProvider.overrideWithValue('Asia/Almaty'),
        calendarClockProvider.overrideWithValue(() => clock),
        reminderSchedulerProvider.overrideWithValue(_NoReminders()),
        if (calls) ...[
          callNativeProvider.overrideWithValue(FakeCallNative()),
          callMediaFactoryProvider.overrideWithValue(FakeCallMedia.new),
        ],
      ],
    );
    h.stubSignedIn();
    h.adapter.onJson('GET', '/me', Fixtures.me(permissions: permissions));
    h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats(const []));
    h.chatAdapter.onPattern(
      'POST',
      r'^/push/devices$',
      (_) => const FakeResponse(204),
    );
    h.chatAdapter.onJson('GET', '/users', {
      'users': [
        ChatFixtures.user(id: bob.id, name: bob.name),
        ChatFixtures.user(id: carol.id, name: carol.name),
      ],
    });
    server = FakeCalendarServer(h.adapter, const [me, bob, carol]);
  }

  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localeTestValue = const Locale('ru');
    tester.platformDispatcher.localesTestValue = const [Locale('ru')];
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.runAsync(() => h.session.restore());
    await tester.pumpWidget(
      UncontrolledProviderScope(container: h.container, child: const XatBoxApp()),
    );
    await settle(tester);
  }

  /// Stops the chat socket (ping timer) and lets debounce timers expire.
  Future<void> finish(WidgetTester tester) async {
    unawaited(h.container.read(chatRepositoryProvider).stop());
    await tester.pump(const Duration(seconds: 10));
  }

  Map<String, dynamic> lastFreeBusy() =>
      h.adapter.of('POST', '/calendar/free-busy').last.json;

  Finder inside(Key key, String text) => find.descendant(
    of: find.byKey(key),
    matching: find.text(text),
    matchRoot: true,
  );

  testWidgets(
    'event form: busy intervals, room bookings, find-time chips set the time, room booked on create',
    (tester) async {
      await prepare();
      server.seedEvent(organizer: bob, title: 'Занят', start: at(17, 10), end: at(17, 11));
      server.resources.addAll([
        {
          'id': 'room-a',
          'name': 'Алатау',
          'location': '3 этаж',
          'capacity': 8,
          'equipment': 'ТВ',
          'status': 'active',
          'created_at': '2026-09-01 09:00:00.123456+00',
        },
        {
          'id': 'room-old',
          'name': 'Старая',
          'location': '',
          'capacity': 4,
          'equipment': '',
          'status': 'disabled',
          'created_at': '2026-09-01 09:00:00+00',
        },
      ]);
      server.roomBookings['room-a'] = [(at(17, 14), at(17, 15))];
      server.suggestions = [(at(17, 14), at(17, 15)), (at(17, 16), at(17, 17))];
      await launch(tester);

      final router = h.container.read(appRouterProvider);
      unawaited(router.push(Routes.calendar));
      await settle(tester, 20);
      unawaited(
        router.push(
          Routes.calendarNew,
          extra: const EventEditArgs.create(date: CalendarDate(2026, 9, 17), hour: 9),
        ),
      );
      await settle(tester, 20);
      expect(find.byType(EventEditScreen), findsOneWidget);
      // Scheduling (busy times, room, find a time) waits under «Ещё».
      await tester.ensureVisible(find.byKey(const Key('event_more')));
      await tester.tap(find.byKey(const Key('event_more')));
      await settle(tester, 20);

      // Initially only the caller, whom the API does not add by itself.
      var fb = lastFreeBusy();
      expect(documented.containsAll(fb.keys), isTrue);
      expect(fb['user_ids'], [me.id]);
      expect(fb['start'], EventTime.encode(at(17, 0)));
      expect(fb['end'], EventTime.encode(at(18, 0)));
      expect(inside(ValueKey('busy_${me.id}'), 'свободен'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('event_title')), 'Планирование');
      // People are found as you type.
      await tester.ensureVisible(find.byKey(const Key('event_participant_search')));
      await tester.enterText(find.byKey(const Key('event_participant_search')), 'Бол');
      await settle(tester, 20);
      await tester.tap(find.byKey(ValueKey('pick_${bob.id}')));
      await settle(tester, 20);
      fb = lastFreeBusy();
      expect(fb['user_ids'], [me.id, bob.id]);
      expect(inside(ValueKey('busy_${bob.id}'), '10:00–11:00'), findsOneWidget);

      // Room picker lists active rooms only; the room's bookings appear.
      await tester.ensureVisible(find.byKey(const Key('event_room')));
      await tester.tap(find.byKey(const Key('event_room')));
      await settle(tester);
      expect(find.byKey(const ValueKey('room_room-a')), findsOneWidget);
      expect(find.text('Старая'), findsNothing, reason: 'disabled rooms are hidden');
      await tester.tap(find.byKey(const ValueKey('room_room-a')));
      await settle(tester, 20);
      fb = lastFreeBusy();
      expect(fb['resource_id'], 'room-a');
      expect(inside(const Key('room_busy'), '14:00–15:00'), findsOneWidget);
      expect(find.byKey(const Key('room_busy_warning')), findsNothing);

      // «Подобрать время»: chips set start and end.
      await tester.ensureVisible(find.byKey(const Key('calendar_find_time')));
      await tester.tap(find.byKey(const Key('calendar_find_time')));
      await settle(tester);
      final ft = h.adapter.of('POST', '/calendar/find-time').single.json;
      expect(ft.keys.toSet(), {'user_ids', 'start', 'end', 'duration_minutes'});
      expect(ft['user_ids'], [me.id, bob.id]);
      expect(ft['duration_minutes'], 60);
      expect(find.byKey(const ValueKey('time_suggestion_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('time_suggestion_1')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('time_suggestion_0')));
      await tester.tap(find.byKey(const ValueKey('time_suggestion_0')));
      await settle(tester);
      expect(inside(const Key('event_start_time'), '14:00'), findsOneWidget);
      expect(inside(const Key('event_end_time'), '15:00'), findsOneWidget);
      expect(
        find.byKey(const Key('room_busy_warning')),
        findsOneWidget,
        reason: 'the room is booked at 14:00',
      );

      await tester.ensureVisible(find.byKey(const ValueKey('time_suggestion_1')));
      await tester.tap(find.byKey(const ValueKey('time_suggestion_1')));
      await settle(tester);
      expect(inside(const Key('event_start_time'), '16:00'), findsOneWidget);
      expect(inside(const Key('event_end_time'), '17:00'), findsOneWidget);
      expect(find.byKey(const Key('room_busy_warning')), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('event_save')));
      await tester.tap(find.byKey(const Key('event_save')));
      await settle(tester, 30);
      expect(server.createCalls, 1);
      final body = h.adapter.of('POST', '/calendar/events').single.json;
      expect(body['resource_id'], 'room-a');
      expect(body['user_ids'], [bob.id]);
      final created = server.events.values.firstWhere((e) => e['title'] == 'Планирование');
      expect(FakeCalendarServer.parse(created['starts_at'] as String), at(17, 16));
      expect(server.roomBookings['room-a'], hasLength(2));
      await finish(tester);
    },
  );

  testWidgets(
    '«Присоединиться к звонку» starts a video conference with the internal participants',
    (tester) async {
      await prepare(calls: true);
      final calls = FakeCallServer(h.callsAdapter, selfId: me.id, selfName: me.name);
      final id = server.seedEvent(
        organizer: me,
        title: 'Совет',
        start: at(15, 11),
        end: at(15, 12),
        guests: [bob, carol],
      );
      await launch(tester);
      expect(h.container.read(callsEnabledProvider), isTrue);

      unawaited(h.container.read(appRouterProvider).push(Routes.calendarEventPath(id)));
      await settle(tester, 20);
      expect(find.byType(EventDetailScreen), findsOneWidget);
      final join = tester.widget<ButtonStyleButton>(find.byKey(const Key('event_join_call')));
      expect(join.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('event_join_call')));
      await settle(tester, 20);
      expect(calls.createPosts, 1);
      final body = h.callsAdapter.of('POST', '/calls').single.json;
      expect(body['callee_ids'], [bob.id, carol.id], reason: 'internal participants except self');
      expect(body['type'], 'video');
      expect(body['mode'], 'conference');
      expect(body['title'], 'Совет');
      expect(find.byType(CallScreen), findsOneWidget);

      unawaited(h.container.read(callControllerProvider.notifier).hangUp());
      await tester.pump(const Duration(seconds: 1));
      await finish(tester);
    },
  );
}

class _NoReminders implements ReminderScheduler {
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> schedule(ReminderRequest request) async {}
  @override
  Future<void> cancel(int id) async {}
}
