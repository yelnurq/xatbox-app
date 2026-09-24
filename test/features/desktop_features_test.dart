import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/localization/localization.dart';
import 'package:xatbox_mobile/core/platform/desktop.dart';
import 'package:xatbox_mobile/core/platform/desktop_layout.dart';
import 'package:xatbox_mobile/core/preferences/app_preferences.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/core/theme/app_theme.dart';
import 'package:xatbox_mobile/core/theme/skin_backdrop.dart';
import 'package:xatbox_mobile/core/theme/tokens.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_reminders.dart';
import 'package:xatbox_mobile/features/calendar/domain/calendar_time.dart';
import 'package:xatbox_mobile/features/calendar/presentation/calendar_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/contacts/presentation/contacts_desktop.dart';
import 'package:xatbox_mobile/features/contacts/presentation/contacts_providers.dart';
import 'package:xatbox_mobile/features/contacts/presentation/my_contacts_providers.dart';
import 'package:xatbox_mobile/features/tasks/presentation/tasks_board.dart';
import 'package:xatbox_mobile/features/tasks/presentation/tasks_providers.dart';

import '../helpers/calendar_fake_server.dart';
import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
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

const _me = '11111111-1111-4111-8111-111111111111';

Map<String, dynamic> _task(
  String id,
  String title, {
  String? due,
  String status = 'todo',
  String owner = _me,
  String board = '',
  bool canEdit = true,
}) => {
  'id': id,
  'owner_user_id': owner,
  'title': title,
  'description': '',
  'priority': 'normal',
  'status': status,
  'source_type': 'manual',
  'due_at': ?due,
  'created_at': '2026-09-14 09:00:00+00',
  if (board.isNotEmpty) 'board_id': board,
  'can_edit': canEdit,
};

Map<String, dynamic> _board(
  String id,
  String name, {
  String owner = _me,
  String role = 'owner',
  int open = 0,
  List<Map<String, dynamic>> members = const [],
}) => {
  'id': id,
  'name': name,
  'description': '',
  'position': 0,
  'owner_user_id': owner,
  'owner_name': 'Коллега',
  'role': role,
  'members': members,
  'task_count': open,
  'open_count': open,
  'created_at': '2026-09-14 09:00:00+00',
};

/// The desktop additions: the simple event form, the tasks board, «Мои
/// контакты» and the glass skins (desktop only).
void main() {
  setUpAll(CalendarZones.ensureInitialized);

  final clock = DateTime.utc(2026, 9, 16, 5, 30); // Wednesday 10:30 in Almaty
  const org = '33333333-3333-4333-8333-333333333333';
  const me = FakeCalendarUser(id: _me, token: Fixtures.token, name: 'Тест Пользователь', org: org);
  const bob = FakeCalendarUser(id: 'bbbbbbbb-0000-4000-8000-000000000002', token: 'tok-bob', name: 'Болат Сейтов', org: org);

  Future<void> settle(WidgetTester tester, [int steps = 12]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<(TestHarness, FakeCalendarServer)> launch(
    WidgetTester tester, {
    List<Map<String, dynamic>> tasks = const [],
    List<Map<String, dynamic>> boards = const [],
    FakeHandler? users,
  }) async {
    debugDesktopOverride = true;
    addTearDown(() => debugDesktopOverride = null);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localeTestValue = const Locale('ru');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final h = await TestHarness.create(
      storedToken: Fixtures.token,
      chatBaseUrl: 'http://chat.local/api/v1',
      overrides: [
        desktopLayoutProvider.overrideWithValue(true),
        initialDeviceZoneProvider.overrideWithValue('Asia/Almaty'),
        calendarClockProvider.overrideWithValue(() => clock),
        tasksClockProvider.overrideWithValue(() => clock),
        reminderSchedulerProvider.overrideWithValue(_NoReminders()),
      ],
    );
    addTearDown(h.dispose);
    h.stubSignedIn();
    h.adapter.onJson('GET', '/me', Fixtures.me(permissions: const [
      'mail.read', 'mail.send', 'calendar.events.read', 'calendar.events.create', 'calendar.events.manage_own',
      'tasks.manage.self',
    ]));
    h.adapter.onJson('GET', '/tasks', {'tasks': tasks});
    h.adapter.onJson('GET', '/tasks/boards', {'boards': boards});
    h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats(const []));
    h.chatAdapter.onPattern('POST', r'^/push/devices$', (_) => const FakeResponse(204));
    if (users != null) {
      h.chatAdapter.on('GET', '/users', users);
    } else {
      h.chatAdapter.onJson('GET', '/users', {
        'users': [
          {...ChatFixtures.user(id: bob.id, name: 'Болат Сейтов'), 'position': 'Доцент'},
        ],
      });
    }
    h.chatAdapter.onJson('GET', '/departments', {'departments': <Object>[]});
    final server = FakeCalendarServer(h.adapter, const [me, bob]);
    await tester.pumpWidget(UncontrolledProviderScope(container: h.container, child: const XatBoxApp()));
    await settle(tester);
    return (h, server);
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(TasksBoardScreen)));

  Future<void> finish(WidgetTester tester, TestHarness h) async {
    unawaited(h.container.read(chatRepositoryProvider).stop());
    await tester.pump(const Duration(seconds: 10));
  }

  testWidgets('event form: a title, one hour, a colleague found by name → saved', (tester) async {
    final (h, server) = await launch(tester);
    h.container.read(appRouterProvider).go(Routes.calendar);
    await settle(tester, 20);
    await tester.tap(find.byKey(const Key('calendar_new_button')));
    await settle(tester);

    // Next half hour for 30 minutes, as the web; the chips change the end.
    expect(find.descendant(of: find.byKey(const Key('event_start_time')), matching: find.text('11:00')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('event_end_time')), matching: find.text('11:30')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('event_title')), 'Заседание кафедры');
    await tester.tap(find.byKey(const Key('event_duration_60')));
    await settle(tester);
    expect(find.descendant(of: find.byKey(const Key('event_end_time')), matching: find.text('12:00')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('event_participant_search')), 'Бол');
    await settle(tester, 20);
    await tester.tap(find.byKey(ValueKey('pick_${bob.id}')));
    await settle(tester);
    expect(find.byKey(ValueKey('draft_participant_${bob.id}')), findsOneWidget);

    await tester.tap(find.byKey(const Key('event_save')));
    await settle(tester, 30);
    final created = server.events.values.singleWhere((e) => e['title'] == 'Заседание кафедры');
    final almaty = CalendarZones.location('Asia/Almaty');
    expect(created['starts_at'], FakeCalendarServer.pgText(EventTime.atWall(const CalendarDate(2026, 9, 16), 11, 0, almaty)));
    expect(created['ends_at'], FakeCalendarServer.pgText(EventTime.atWall(const CalendarDate(2026, 9, 16), 12, 0, almaty)));
    await finish(tester, h);
  });

  testWidgets('tasks board: in the rail; a card dragged to «Завтра» gets tomorrow as its due date', (tester) async {
    final (h, _) = await launch(tester, tasks: [_task('t1', 'Купить картриджи'), _task('t2', 'Отчёт', due: '2026-09-16 13:00:00+00')]);
    h.adapter.on('PATCH', '/tasks/t1', (_) {
      // The server now has it due tomorrow at 18:00 local (12:00 UTC).
      h.adapter.onJson('GET', '/tasks', {
        'tasks': [_task('t1', 'Купить картриджи', due: '2026-09-17 13:00:00+00'), _task('t2', 'Отчёт', due: '2026-09-16 13:00:00+00')],
      });
      return const FakeResponse(204);
    });
    expect(find.byKey(const Key('desktop_rail_tasks')), findsOneWidget);
    await tester.tap(find.byKey(const Key('desktop_rail_tasks')));
    await settle(tester, 20);
    expect(find.byType(TasksBoardScreen), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('tasks_column_noDue')), matching: find.text('Купить картриджи')), findsOneWidget);

    final card = find.byKey(const ValueKey('task_card_t1'));
    final target = find.byKey(const ValueKey('tasks_column_tomorrow'));
    final mouse = await tester.startGesture(tester.getCenter(card), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 1; i <= 10; i++) {
      await mouse.moveTo(Offset.lerp(tester.getCenter(card), tester.getCenter(target), i / 10)!);
      await tester.pump(const Duration(milliseconds: 20));
    }
    await mouse.up();
    await settle(tester);
    final body = h.adapter.of('PATCH', '/tasks/t1').single.json as Map;
    final due = DateTime.parse(body['due_at'] as String).toLocal();
    expect((due.year, due.month, due.day, due.hour), (2026, 9, 17, 18));
    expect(find.descendant(of: target, matching: find.text('Купить картриджи')), findsOneWidget);
    await finish(tester, h);
  });

  testWidgets('tasks board: boards hold their own tasks; a new one is created and opened', (tester) async {
    final (h, _) = await launch(
      tester,
      tasks: [
        _task('t1', 'Купить картриджи'),
        _task('t2', 'Проверить списки', board: 'b1'),
        _task('t3', 'Читаю только', board: 'b2', owner: bob.id, canEdit: false),
      ],
      boards: [
        _board('b1', 'Приёмная кампания', open: 1),
        _board('b2', 'Расписание', owner: bob.id, role: 'viewer', open: 1, members: [
          {'user_id': _me, 'display_name': 'Тест Пользователь', 'role': 'viewer'},
        ]),
      ],
    );
    await tester.tap(find.byKey(const Key('desktop_rail_tasks')));
    await settle(tester, 20);

    // «Мои задачи» is open first: only the task without a board.
    expect(find.text('Купить картриджи'), findsOneWidget);
    expect(find.text('Проверить списки'), findsNothing);

    await tester.tap(find.byKey(const Key('task_board_b1')));
    await settle(tester, 12);
    expect(find.text('Проверить списки'), findsOneWidget);
    expect(find.text('Купить картриджи'), findsNothing);
    expect(find.text('Приёмная кампания'), findsWidgets, reason: 'the open board names the page');

    // A board shared for reading only: no «Новая задача», and the hint says so.
    await tester.tap(find.byKey(const Key('task_board_b2')));
    await settle(tester, 12);
    expect(find.text('Читаю только'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('tasks_new'))).onPressed,
      isNull,
      reason: 'a viewer cannot add tasks to somebody else\'s board',
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(TasksBoardScreen)));
    expect(find.text(l10n.taskBoardReadOnly), findsOneWidget);

    // «Новая доска» → the dialog → POST /tasks/boards, and it opens.
    h.adapter.onJson('POST', '/tasks/boards', {'id': 'b3'}, status: 201);
    h.adapter.onJson('GET', '/tasks/boards', {
      'boards': [
        _board('b1', 'Приёмная кампания', open: 1),
        _board('b3', 'Аккредитация'),
        _board('b2', 'Расписание', owner: bob.id, role: 'viewer', open: 1),
      ],
    });
    await tester.tap(find.byKey(const Key('task_board_new')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('task_board_name')), 'Аккредитация');
    await tester.tap(find.byKey(const Key('task_board_color_purple')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('task_board_submit')));
    await settle(tester, 20);

    expect(h.adapter.of('POST', '/tasks/boards').single.json, {
      'name': 'Аккредитация',
      'color': 'purple',
    });
    expect(find.byKey(const Key('task_board_b3')), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('tasks_new'))).onPressed,
      isNotNull,
      reason: 'the new board is open and writable',
    );
    await finish(tester, h);
  });

  testWidgets('tasks board: a board is shared with a colleague, with a role', (tester) async {
    final (h, _) = await launch(
      tester,
      tasks: [_task('t2', 'Проверить списки', board: 'b1')],
      boards: [
        _board('b1', 'Приёмная кампания', open: 1, members: [
          {'user_id': 'old-member', 'display_name': 'Прошлый Участник', 'role': 'editor'},
        ]),
      ],
    );
    // The colleague picker walks the organization's directory 50 at a time.
    h.adapter.on('GET', '/directory/users', (r) {
      final q = (r.query['q'] as String?) ?? '';
      final users = [
        {'id': bob.id, 'display_name': 'Болат Сейтов', 'email': 'bolat@x.kz'},
        {'id': 'u-other', 'display_name': 'Другой Сотрудник', 'email': 'other@x.kz'},
      ].where((u) => q.isEmpty || u['display_name']!.contains(q)).toList();
      return FakeResponse(200, json: {
        'users': users,
        'limit': int.parse(r.query['limit'] as String),
        'offset': 0,
        'has_more': false,
      });
    });
    h.adapter.on('PUT', '/tasks/boards/b1/members', (_) => const FakeResponse(204));

    await tester.tap(find.byKey(const Key('desktop_rail_tasks')));
    await settle(tester, 20);
    await tester.tap(find.byKey(const Key('task_board_menu_button_Приёмная кампания')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('task_board_menu_share')));
    await settle(tester, 20);

    // The board's current member is shown and can be dropped.
    expect(find.byKey(const Key('task_board_member_old-member')), findsOneWidget);
    await tester.tap(find.byKey(const Key('task_board_member_remove_old-member')));
    await settle(tester);
    expect(find.byKey(const Key('task_board_member_old-member')), findsNothing);

    await tester.enterText(find.byKey(const Key('task_board_share_search')), 'Болат');
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester, 20);
    expect(find.byKey(Key('task_board_candidate_u-other')), findsNothing);
    await tester.tap(find.byKey(Key('task_board_candidate_${bob.id}')));
    await settle(tester);

    // Invited colleagues may edit by default; this one only reads.
    await tester.tap(find.byKey(Key('task_board_role_${bob.id}')));
    await settle(tester);
    await tester.tap(find.text(l10nOf(tester).taskBoardRoleViewer).last);
    await settle(tester);

    await tester.tap(find.byKey(const Key('task_board_share_save')));
    await settle(tester, 20);
    expect(h.adapter.of('PUT', '/tasks/boards/b1/members').single.json, {
      'members': [
        {'user_id': bob.id, 'role': 'viewer'},
      ],
    });
    await finish(tester, h);
  });

  testWidgets('tasks board: a task added from one line in «Сегодня»', (tester) async {
    final (h, _) = await launch(tester);
    h.adapter.onJson('POST', '/tasks', {'id': 'new'}, status: 201);
    h.container.read(appRouterProvider).go(Routes.tasks);
    await settle(tester, 20);
    await tester.tap(find.byKey(const Key('tasks_add_today')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('tasks_quick_today')), 'Распечатать приказ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    final body = h.adapter.of('POST', '/tasks').single.json as Map;
    expect(body['title'], 'Распечатать приказ');
    final due = DateTime.parse(body['due_at'] as String).toLocal();
    expect((due.month, due.day, due.hour), (9, 16, 18));
    await finish(tester, h);
  });

  testWidgets('contacts: the directory arrives 50 at a time and grows as the list is scrolled', (tester) async {
    final many = [
      for (var i = 0; i < 130; i++)
        ChatFixtures.user(id: 'u-${i.toString().padLeft(3, '0')}', name: 'Сотрудник $i'),
    ];
    final (h, _) = await launch(tester, users: (r) {
      final limit = int.parse(r.query['limit'] as String);
      final offset = int.parse((r.query['offset'] as String?) ?? '0');
      final slice = many.skip(offset).take(limit).toList();
      return FakeResponse(200, json: {
        'users': slice,
        'limit': limit,
        'offset': offset,
        'has_more': offset + slice.length < many.length,
      });
    });
    h.container.read(appRouterProvider).go(Routes.contacts);
    await settle(tester, 30);
    expect(find.byType(DesktopContactsScreen), findsOneWidget);

    // The whole organization is not pulled at once: 50 rows, and the count
    // says more are waiting.
    expect(h.chatAdapter.of('GET', '/users').last.query, {'limit': '50'});
    expect(h.container.read(contactsProvider).contacts, hasLength(50));
    expect(find.text('50+'), findsOneWidget);

    final list = find
        .ancestor(
          of: find.byKey(const ValueKey('contact_row_u-000')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(list, const Offset(0, -2400));
    await settle(tester, 20);
    expect(h.chatAdapter.of('GET', '/users').last.query, {'limit': '50', 'offset': '50'});
    expect(h.container.read(contactsProvider).contacts, hasLength(100));
    await finish(tester, h);
  });

  testWidgets('contacts: the star pins a colleague to «Мои контакты»; a personal contact is added', (tester) async {
    final (h, _) = await launch(tester);
    h.container.read(appRouterProvider).go(Routes.contacts);
    await settle(tester, 20);
    expect(find.byType(DesktopContactsScreen), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('contact_pin_${bob.id}')));
    await settle(tester);
    expect(h.container.read(contactsFavouriteIdsProvider), contains(bob.id));

    await tester.tap(find.byKey(const Key('contacts_new')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('personal_save')));
    await settle(tester);
    // The name is required.
    expect(find.text('Enter a name'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('personal_name')), 'Мария Иванова');
    await tester.enterText(find.byKey(const Key('personal_email')), 'maria@partner.kz');
    await tester.tap(find.byKey(const Key('personal_save')));
    await settle(tester);
    expect(h.container.read(personalContactsProvider).single.email, 'maria@partner.kz');

    // «Мои контакты» lists both, and the new contact is open on the right.
    expect(find.byKey(ValueKey('contact_row_${bob.id}')), findsOneWidget);
    expect(find.byKey(const Key('personal_write_email')), findsOneWidget);
    await finish(tester, h);
  });

  test('glass skins are offered on every platform; others keep an opaque overlay', () {
    for (final desktop in [false, true]) {
      expect(
        AppSkin.offered(desktop: desktop),
        containsAll([
          AppSkin.glassForest,
          AppSkin.glassSpace,
          AppSkin.glassAstana,
          AppSkin.glassSemey,
          AppSkin.glassCustom,
        ]),
      );
      expect(AppSkin.offered(desktop: desktop).length, AppSkin.values.length);
    }
    const kok = XatBoxTokens(SkinPalettes.kok);
    expect(kok.overlaySurface, kok.surface);
    final glass = XatBoxTokens(AppSkin.glassSpace.palette(ThemeMode.dark, Brightness.dark));
    expect(glass.overlaySurface.a, 1);
    expect(AppTheme.build(glass).dialogTheme.backgroundColor, glass.overlaySurface);
  });

  testWidgets('a glass skin paints its picture behind the desktop shell', (tester) async {
    final (h, _) = await launch(tester);
    expect(find.byType(SkinBackdropView), findsNothing);
    await tester.runAsync(() => h.container.read(appPreferencesProvider.notifier).update((p) => p.copyWith(skin: AppSkin.glassForest)));
    await settle(tester);
    expect(find.byType(SkinBackdropView), findsOneWidget);
    await finish(tester, h);
  });
}
