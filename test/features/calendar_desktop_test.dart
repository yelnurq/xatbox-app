import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/platform/desktop.dart';
import 'package:xatbox_mobile/core/platform/desktop_layout.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_reminders.dart';
import 'package:xatbox_mobile/features/calendar/domain/calendar_time.dart';
import 'package:xatbox_mobile/features/calendar/presentation/calendar_desktop_timeline.dart';
import 'package:xatbox_mobile/features/calendar/presentation/calendar_providers.dart';
import 'package:xatbox_mobile/features/calendar/presentation/event_edit_screen.dart';
import 'package:xatbox_mobile/features/mail/presentation/compose_screen.dart';

import '../helpers/calendar_fake_server.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

class _NoReminders implements ReminderScheduler {
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> schedule(ReminderRequest request) async {}
  @override
  Future<void> cancel(int id) async {}
}

/// The desktop calendar: the week grid (click / drag to create, drag to
/// move), the event panel beside the grid, the editor dialog and the keys.
void main() {
  setUpAll(CalendarZones.ensureInitialized);

  final clock = DateTime.utc(2026, 9, 16, 5, 30); // Wednesday 10:30 in Almaty
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
  DateTime at(int d, int hour, [int minute = 0]) => EventTime.atWall(CalendarDate(2026, 9, d), hour, minute, almaty);

  Future<void> settle(WidgetTester tester, [int steps = 12]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<(TestHarness, FakeCalendarServer)> launch(WidgetTester tester, [void Function(FakeCalendarServer)? seed]) async {
    debugDesktopOverride = true;
    addTearDown(() => debugDesktopOverride = null);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localeTestValue = const Locale('ru');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final h = await TestHarness.create(
      storedToken: Fixtures.token,
      overrides: [
        desktopLayoutProvider.overrideWithValue(true),
        initialDeviceZoneProvider.overrideWithValue('Asia/Almaty'),
        calendarClockProvider.overrideWithValue(() => clock),
        reminderSchedulerProvider.overrideWithValue(_NoReminders()),
      ],
    );
    addTearDown(h.dispose);
    h.stubSignedIn();
    h.adapter.onJson(
      'GET',
      '/me',
      Fixtures.me(permissions: const ['mail.read', 'mail.send', 'calendar.events.read', 'calendar.events.create', 'calendar.events.manage_own']),
    );
    final server = FakeCalendarServer(h.adapter, const [me, bob]);
    seed?.call(server);
    await tester.pumpWidget(UncontrolledProviderScope(container: h.container, child: const XatBoxApp()));
    await settle(tester);
    h.container.read(appRouterProvider).go(Routes.calendar);
    await settle(tester, 20);
    return (h, server);
  }

  testWidgets('week grid: W switches, a click opens the event beside the grid, Esc closes it', (tester) async {
    await launch(tester, (s) => s.seedEvent(organizer: me, title: 'Планёрка', start: at(16, 9), end: at(16, 10)));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await settle(tester, 20);
    expect(find.byType(DesktopTimeline), findsOneWidget);
    expect(find.byKey(const Key('timeline_now')), findsOneWidget);

    await tester.tap(find.text('Планёрка'));
    await settle(tester);
    expect(find.byKey(const Key('calendar_event_panel')), findsOneWidget);
    // The grid stays in view.
    expect(find.byType(DesktopTimeline), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byKey(const Key('calendar_event_panel')), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('week grid: dragging an event moves it; a click on a free slot opens the editor there', (tester) async {
    late String id;
    final (_, server) = await launch(tester, (s) => id = s.seedEvent(organizer: me, title: 'Планёрка', start: at(16, 9), end: at(16, 10)));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await settle(tester, 20);

    // Two hours down, one day right.
    final column = tester.getSize(find.byKey(const ValueKey('timeline_column_2026-09-16'))).width;
    final mouse = await tester.startGesture(tester.getCenter(find.text('Планёрка')), kind: PointerDeviceKind.mouse);
    for (var i = 0; i < 10; i++) {
      await mouse.moveBy(Offset(column / 10, 2 * desktopHourHeight / 10));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await mouse.up();
    await settle(tester, 20);
    expect(server.events[id]!['starts_at'], FakeCalendarServer.pgText(at(17, 11)));
    expect(server.events[id]!['ends_at'], FakeCalendarServer.pgText(at(17, 12)));

    // Friday 15:00: the editor opens as a dialog with 15:00–15:30.
    final friday = tester.getTopLeft(find.byKey(const ValueKey('timeline_column_2026-09-18')));
    await tester.tapAt(friday + const Offset(20, 15 * desktopHourHeight + 10));
    await settle(tester);
    expect(find.byType(EventEditScreen), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const Key('event_start_time')), matching: find.text('15:00')),
      findsOneWidget,
    );
    expect(find.descendant(of: find.byKey(const Key('event_end_time')), matching: find.text('15:30')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byType(EventEditScreen), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('keys: T today, arrows move, C / N open a new event instead of a new letter', (tester) async {
    final (h, _) = await launch(tester);
    final view = h.container.read(calendarViewProvider);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(h.container.read(calendarViewProvider).selected.month, view.selected.month + 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await settle(tester);
    expect(h.container.read(calendarViewProvider).selected, view.selected);

    for (final key in [LogicalKeyboardKey.keyC, LogicalKeyboardKey.keyN]) {
      await tester.sendKeyEvent(key);
      await settle(tester);
      expect(find.byType(EventEditScreen), findsOneWidget);
      expect(find.byType(ComposeScreen), findsNothing);
      await tester.tap(find.byKey(const Key('event_edit_close')));
      await settle(tester);
      expect(find.byType(EventEditScreen), findsNothing);
    }
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('month: a chip dragged to another day moves the event there, same time', (tester) async {
    late String id;
    final (_, server) = await launch(tester, (s) => id = s.seedEvent(organizer: me, title: 'Планёрка', start: at(16, 9), end: at(16, 10)));
    final chip = find.text('Планёрка').first;
    final target = tester.getCenter(find.byKey(const ValueKey('day_2026-09-24')));
    final mouse = await tester.startGesture(tester.getCenter(chip), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 1; i <= 10; i++) {
      await mouse.moveTo(Offset.lerp(tester.getCenter(chip), target, i / 10)!);
      await tester.pump(const Duration(milliseconds: 20));
    }
    await mouse.up();
    await settle(tester, 20);
    expect(server.events[id]!['starts_at'], FakeCalendarServer.pgText(at(24, 9)));
    expect(server.events[id]!['ends_at'], FakeCalendarServer.pgText(at(24, 10)));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('day view has a mini month; the event panel writes to the participants', (tester) async {
    await launch(tester, (s) => s.seedEvent(organizer: me, title: 'Совет', start: at(16, 14), end: at(16, 15), guests: const [bob]));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await settle(tester, 20);
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    await tester.tap(find.text('Совет').first);
    await settle(tester, 20);
    await tester.tap(find.byKey(const Key('event_email_participants')));
    await settle(tester);
    expect(find.byType(ComposeScreen), findsOneWidget);
    expect(find.descendant(of: find.byType(ComposeScreen), matching: find.text('Совет')), findsWidgets);
    await tester.pump(const Duration(seconds: 5));
  });
}
