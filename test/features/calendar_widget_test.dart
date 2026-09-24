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
import 'package:xatbox_mobile/features/calendar/presentation/calendar_screen.dart';
import 'package:xatbox_mobile/features/calendar/presentation/event_detail_screen.dart';
import 'package:xatbox_mobile/features/calendar/presentation/event_edit_screen.dart';

import '../helpers/calendar_fake_server.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Calendar screens through the real router against the fake calendar
/// server: month grid and day list, view switching, offline month, event
/// detail with RSVP, organizer view, create form, recurring edit scope.
void main() {
  setUpAll(CalendarZones.ensureInitialized);

  late TestHarness h;
  late FakeCalendarServer server;
  late _RecordingScheduler scheduler;
  final clock = DateTime.utc(2026, 9, 14, 6); // Monday 11:00 in Almaty
  final almaty = CalendarZones.location('Asia/Almaty');
  const me = FakeCalendarUser(
    id: '11111111-1111-4111-8111-111111111111',
    token: Fixtures.token,
    name: 'Тест Пользователь',
    org: '33333333-3333-4333-8333-333333333333',
  );
  const bob = FakeCalendarUser(
    id: 'bbbbbbbb-0000-4000-8000-000000000002',
    token: 'tok-bob',
    name: 'Болат Сейтов',
    org: '33333333-3333-4333-8333-333333333333',
  );
  const permissions = [
    'mail.read',
    'mail.send',
    'calendar.events.read',
    'calendar.events.create',
    'calendar.events.manage_own',
  ];

  DateTime at(int d, int hour) =>
      EventTime.atWall(CalendarDate(2026, 9, d), hour, 0, almaty);

  tearDown(() => h.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 12]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> prepare() async {
    scheduler = _RecordingScheduler();
    h = await TestHarness.create(
      storedToken: Fixtures.token,
      overrides: [
        initialDeviceZoneProvider.overrideWithValue('Asia/Almaty'),
        calendarClockProvider.overrideWithValue(() => clock),
        reminderSchedulerProvider.overrideWithValue(scheduler),
      ],
    );
    h.stubSignedIn();
    h.adapter.onJson('GET', '/me', Fixtures.me(permissions: permissions));
    server = FakeCalendarServer(h.adapter, const [me, bob]);
  }

  Future<void> launch(WidgetTester tester) async {
    tester.platformDispatcher.localeTestValue = const Locale('ru');
    tester.platformDispatcher.localesTestValue = const [Locale('ru')];
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.runAsync(() => h.session.restore());
    await tester.pumpWidget(
      UncontrolledProviderScope(container: h.container, child: const XatBoxApp()),
    );
    await settle(tester);
    unawaited(h.container.read(appRouterProvider).push(Routes.calendar));
    await settle(tester, 20);
  }

  /// Lets debounce timers (reminders, sync) fire before the test ends.
  Future<void> finish(WidgetTester tester) => tester.pump(const Duration(seconds: 5));

  Future<void> chooseView(WidgetTester tester, String mode) async {
    await tester.tap(find.byKey(const Key('calendar_view_menu')));
    await settle(tester);
    await tester.tap(find.byKey(Key('view_$mode')));
    await settle(tester);
  }

  testWidgets(
    'month grid and day list; view switch keeps the date; offline keeps the month',
    (tester) async {
      await prepare();
      server.seedEvent(organizer: me, title: 'Планёрка', start: at(14, 9), end: at(14, 10), rrule: 'FREQ=WEEKLY');
      final (s, e) = EventTime.encodeAllDay(
        const CalendarDate(2026, 9, 16),
        const CalendarDate(2026, 9, 16),
        almaty,
      );
      server.seedEvent(organizer: me, title: 'Отпуск', start: s, end: e, allDay: true);
      server.seedEvent(organizer: bob, title: 'Защита проекта', start: at(18, 14), end: at(18, 15), guests: [me]);
      await launch(tester);

      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('day_2026-09-14')), findsOneWidget);
      // Month cells show titles too: look in the selected day's list.
      Finder inDay(String text) => find.descendant(of: find.byType(DayAgenda), matching: find.text(text));
      expect(inDay('Планёрка'), findsOneWidget, reason: "today's list");
      expect(h.container.read(calendarBadgeProvider), 1, reason: 'one invitation');

      await tester.tap(find.byKey(const ValueKey('day_2026-09-16')));
      await settle(tester);
      expect(inDay('Отпуск'), findsOneWidget);
      expect(inDay('Весь день'), findsOneWidget);

      await chooseView(tester, 'week');
      expect(
        h.container.read(calendarViewProvider).selected,
        const CalendarDate(2026, 9, 16),
        reason: 'switching the view keeps the selected date',
      );
      expect(find.byKey(const ValueKey('timeline_day_2026-09-14')), findsOneWidget);
      expect(find.text('Планёрка'), findsOneWidget);
      expect(find.text('Защита проекта'), findsOneWidget);
      expect(find.text('Отпуск'), findsOneWidget, reason: 'all-day strip');

      await chooseView(tester, 'agenda');
      expect(find.byKey(const Key('agenda_list')), findsOneWidget);
      expect(find.text('Защита проекта'), findsOneWidget);

      await chooseView(tester, 'month');
      server.offline = true;
      unawaited(h.container.read(calendarSyncProvider.notifier).sync());
      await settle(tester, 20);
      expect(find.text('Нет сети — показан сохранённый календарь'), findsOneWidget);
      expect(inDay('Отпуск'), findsOneWidget, reason: 'cached month still readable');
      await finish(tester);
    },
  );

  testWidgets('invitation: detail shows the organizer; RSVP reaches the server', (tester) async {
    await prepare();
    final id = server.seedEvent(organizer: bob, title: 'Защита проекта', start: at(18, 14), end: at(18, 15), guests: [me]);
    await launch(tester);

    unawaited(h.container.read(appRouterProvider).push(Routes.calendarEventPath(id)));
    await settle(tester, 20);
    expect(find.byType(EventDetailScreen), findsOneWidget);
    expect(find.text('Защита проекта'), findsOneWidget);
    expect(find.text('Организатор: Болат Сейтов'), findsOneWidget);
    expect(find.byKey(const Key('event_edit')), findsNothing, reason: 'only the organizer edits');

    await tester.tap(find.text('Приду'));
    await settle(tester, 20);
    final mine = server.participants[id]!.firstWhere((p) => p['user_id'] == me.id);
    expect(mine['response_status'], 'accepted');
    expect(h.container.read(calendarBadgeProvider), 0);
    await finish(tester);
  });

  testWidgets(
    'organizer sees answers and the reserved call button; the form creates an event in the event zone',
    (tester) async {
      await prepare();
      final id = server.seedEvent(organizer: me, title: 'Совет', start: at(15, 11), end: at(15, 12), guests: [bob]);
      server.participants[id]![1]['response_status'] = 'declined';
      await launch(tester);

      unawaited(h.container.read(appRouterProvider).push(Routes.calendarEventPath(id)));
      await settle(tester, 20);
      expect(find.byKey(const Key('event_edit')), findsOneWidget);
      expect(find.textContaining('Отказались: 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('participant_${'bbbbbbbb-0000-4000-8000-000000000002'}')), findsOneWidget);
      final join = tester.widget<ButtonStyleButton>(find.byKey(const Key('event_join_call')));
      expect(join.onPressed, isNull, reason: 'calls are not configured in this build');

      unawaited(
        h.container.read(appRouterProvider).push(
          Routes.calendarNew,
          extra: const EventEditArgs.create(date: CalendarDate(2026, 9, 17), hour: 10),
        ),
      );
      await settle(tester);
      expect(find.byType(EventEditScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('event_save')));
      await settle(tester);
      expect(find.text('Введите название'), findsOneWidget);
      expect(server.createCalls, 0);

      await tester.enterText(find.byKey(const Key('event_title')), 'Ревью кода');
      await tester.tap(find.byKey(const Key('event_save')));
      await settle(tester, 30);
      expect(server.createCalls, 1);
      final created = server.events.values.firstWhere((e) => e['title'] == 'Ревью кода');
      expect(created['timezone'], 'Asia/Almaty');
      expect(FakeCalendarServer.parse(created['starts_at'] as String), at(17, 10));
      expect(find.byType(EventEditScreen), findsNothing);
      await finish(tester);
    },
  );

  testWidgets('editing a recurring event asks for the scope; one occurrence locks the rule', (tester) async {
    await prepare();
    server.seedEvent(organizer: me, title: 'Планёрка', start: at(14, 9), end: at(14, 10), rrule: 'FREQ=WEEKLY');
    await launch(tester);

    await tester.tap(find.descendant(of: find.byType(DayAgenda), matching: find.text('Планёрка')));
    await settle(tester, 20);
    expect(find.byType(EventDetailScreen), findsOneWidget);
    expect(find.text('Каждую неделю'), findsOneWidget);

    await tester.tap(find.byKey(const Key('event_edit')));
    await settle(tester);
    expect(find.text('Только это событие'), findsOneWidget);
    expect(find.text('Это и последующие'), findsOneWidget);
    expect(find.text('Все события серии'), findsOneWidget);

    await tester.tap(find.byKey(const Key('scope_this')));
    await settle(tester);
    expect(find.byType(EventEditScreen), findsOneWidget);
    // One occurrence: the repeat rule is shown but cannot be changed.
    expect(find.byKey(const Key('event_repeat')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('event_repeat')),
        matching: find.byWidgetPredicate((w) => w is InkWell && w.onTap != null),
      ),
      findsNothing,
    );
    expect(find.byKey(const Key('event_add_participant')), findsNothing);
    await finish(tester);
  });
}

class _RecordingScheduler implements ReminderScheduler {
  final Map<int, ReminderRequest> active = {};

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> schedule(ReminderRequest request) async => active[request.id] = request;

  @override
  Future<void> cancel(int id) async => active.remove(id);
}
