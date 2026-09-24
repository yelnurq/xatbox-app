import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/features/tasks/presentation/tasks_board.dart';
import 'package:xatbox_mobile/features/tasks/presentation/tasks_providers.dart';

import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';
import 'tasks_unit_test.dart' show taskJson;

/// «Задачи» on the phone: the desktop's Kanban board laid out for a narrow
/// screen — columns one after another, the boards in a sheet, cards ticked
/// done and created.
void main() {
  late TestHarness h;
  tearDown(() => h.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 12]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('board → tick done → create; the boards open as a sheet', (tester) async {
    phone(tester);
    h = await TestHarness.create(storedToken: Fixtures.token);
    h.adapter.onJson('GET', '/me', Fixtures.me(permissions: ['mail.read', 'tasks.manage.self']));
    final before = [taskJson(id: 't1'), taskJson(id: 't4', status: 'done')];
    h.adapter.onQueue('GET', '/tasks', [
      FakeResponse(200, json: {'tasks': before}),
      FakeResponse(200, json: {'tasks': [taskJson(id: 't1', status: 'done'), before[1]]}),
      FakeResponse(200, json: {'tasks': [taskJson(id: 'new'), taskJson(id: 't1', status: 'done'), before[1]]}),
    ]);
    h.adapter.onJson('GET', '/tasks/boards', {
      'boards': [
        {
          'id': 'b1', 'name': 'Кафедра', 'description': '', 'color': 'blue', 'owner_user_id': '11111111-1111-4111-8111-111111111111',
          'owner_name': 'Тест', 'role': 'owner', 'members': <Object>[], 'open_count': 0,
        },
      ],
    });
    h.adapter.on('PATCH', '/tasks/t1', (_) => const FakeResponse(204));
    h.adapter.onJson('POST', '/tasks', {'id': 'new'}, status: 201);
    await tester.runAsync(() => h.session.restore());

    await tester.pumpWidget(wrapWidget(const TasksBoardScreen(), container: h.container));
    await settle(tester);

    // No rail beside the board on a phone; a column nearly the screen wide.
    expect(find.byKey(const Key('tasks_rail_toggle')), findsNothing);
    expect(find.text('Задача t1'), findsOneWidget);
    final column = tester.getSize(find.byKey(const ValueKey('tasks_column_noDue')));
    expect(column.width, greaterThan(300));

    await tester.tap(find.byKey(const Key('task_check_t1')));
    await settle(tester);
    expect(h.adapter.of('PATCH', '/tasks/t1').single.json, {'status': 'done'});

    await tester.tap(find.byKey(const Key('tasks_new')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('task_title')), 'Позвонить');
    await tester.tap(find.byKey(const Key('task_save')));
    await settle(tester, 20);
    expect(h.adapter.of('POST', '/tasks').single.json['title'], 'Позвонить');
    expect(h.container.read(tasksProvider).tasks, hasLength(3));

    // The board's name opens the boards; picking one closes the sheet.
    await tester.tap(find.byKey(const Key('tasks_board_picker')));
    await settle(tester);
    expect(find.byKey(const Key('tasks_board_sheet')), findsOneWidget);
    await tester.tap(find.text('Кафедра'));
    await settle(tester);
    expect(find.byKey(const Key('tasks_board_sheet')), findsNothing);
    expect(h.container.read(selectedTaskBoardProvider), 'b1');
  });

  testWidgets('without tasks.manage.self: creating is off, nothing fetched', (tester) async {
    phone(tester);
    h = await TestHarness.create(storedToken: Fixtures.token);
    h.adapter.onJson('GET', '/me', Fixtures.me());
    await tester.runAsync(() => h.session.restore());
    await tester.pumpWidget(wrapWidget(const TasksBoardScreen(), container: h.container));
    await settle(tester);
    // (The glass bar has no «Задачи» tab for such a user either.)
    final create = find.byKey(const Key('tasks_new'));
    expect(create.evaluate().isEmpty || tester.widget<IconButton>(create).onPressed == null, isTrue);
    expect(h.adapter.of('GET', '/tasks'), isEmpty);
  });
}
