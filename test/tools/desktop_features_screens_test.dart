// Screenshots of the desktop calendar form, tasks board, «Мои контакты»
// and the glass skins, for design review (not a check).
// Run: SCREENS=1 flutter test test/tools/desktop_features_screens_test.dart
// PNGs land in build/desktop_screens/features/.
@Tags(['screens'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/platform/desktop.dart';
import 'package:xatbox_mobile/core/platform/desktop_layout.dart';
import 'package:xatbox_mobile/core/preferences/app_preferences.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/core/theme/skins.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_reminders.dart';
import 'package:xatbox_mobile/features/calendar/domain/calendar_time.dart';
import 'package:xatbox_mobile/features/calendar/presentation/calendar_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
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

Future<void> _loadFonts() async {
  final families = <String, List<String>>{
    'Golos Text': [for (final w in [400, 500, 600, 700]) 'assets/fonts/GolosText-$w.ttf'],
    'JetBrains Mono': [for (final w in [400, 500, 600]) 'assets/fonts/JetBrainsMono-$w.ttf'],
    'Roboto': [for (final w in [400, 500, 600, 700]) 'assets/fonts/GolosText-$w.ttf'],
    'packages/lucide_icons_flutter/Lucide': ['packages/lucide_icons_flutter/assets/lucide.ttf'],
    'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
  };
  for (final e in families.entries) {
    final loader = FontLoader(e.key);
    for (final asset in e.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}

const _me = '11111111-1111-4111-8111-111111111111';

Map<String, dynamic> _task(
  String id,
  String title, {
  String? due,
  String status = 'todo',
  String priority = 'normal',
  String description = '',
  String owner = _me,
  String sourceType = 'manual',
  String? sourceId,
}) => {
  'id': id,
  'owner_user_id': owner,
  'title': title,
  'description': description,
  'priority': priority,
  'status': status,
  'source_type': sourceType,
  'source_id': ?sourceId,
  'due_at': ?due,
  'created_at': '2026-09-14 09:00:00+00',
};

void main() {
  final enabled = Platform.environment['SCREENS'] == '1';
  final out = Directory('build/desktop_screens/features')..createSync(recursive: true);
  final clock = DateTime.utc(2026, 9, 16, 5, 30); // Wednesday 10:30 in Almaty
  const org = '33333333-3333-4333-8333-333333333333';
  const me = FakeCalendarUser(id: _me, token: Fixtures.token, name: 'Тест Пользователь', org: org);
  const bob = FakeCalendarUser(id: 'bbbbbbbb-0000-4000-8000-000000000002', token: 'tok-bob', name: 'Болат Сейтов', org: org);

  testWidgets('desktop feature screens', (tester) async {
    if (!enabled) return;
    CalendarZones.ensureInitialized();
    await tester.runAsync(_loadFonts);
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
    h.stubSignedIn(messages: Fixtures.messages(12), total: 12);
    h.adapter.onJson('GET', '/me', Fixtures.me(permissions: const [
      'mail.read', 'mail.send', 'calendar.events.read', 'calendar.events.create', 'calendar.events.manage_own',
      'tasks.manage.self',
    ]));
    h.adapter.onJson('GET', '/tasks', {
      'tasks': [
        _task('t1', 'Подготовить отчёт кафедры за сентябрь', due: '2026-09-16 13:00:00+00', priority: 'high',
            description: 'Сводка по нагрузке и публикациям'),
        _task('t2', 'Проверить курсовые 3 курса', due: '2026-09-15 12:00:00+00', priority: 'urgent'),
        _task('t3', 'Ответить деканату по расписанию', due: '2026-09-16 09:00:00+00', sourceType: 'email', sourceId: 'm1'),
        _task('t4', 'Заявка на командировку', due: '2026-09-17 06:00:00+00'),
        _task('t5', 'Созвон с партнёрами из KazNU', due: '2026-09-17 10:00:00+00', status: 'in_progress'),
        _task('t6', 'Обновить силлабус «Базы данных»', due: '2026-09-22 13:00:00+00', priority: 'low'),
        _task('t7', 'Подать статью в журнал', due: '2026-09-25 13:00:00+00', priority: 'high'),
        _task('t8', 'Купить картриджи для принтера'),
        _task('t9', 'Идеи для открытой лекции', description: 'ИИ в образовании, примеры из практики'),
        _task('t10', 'Сдать ведомость', status: 'done', due: '2026-09-14 12:00:00+00'),
        _task('t11', 'Согласовать план НИР', status: 'done'),
      ],
    });
    h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats(const []));
    h.chatAdapter.onPattern('POST', r'^/push/devices$', (_) => const FakeResponse(204));
    final people = [
      {...ChatFixtures.user(id: bob.id, name: 'Болат Сейтов', online: true), 'position': 'Доцент', 'department_name': 'Кафедра ИС'},
      {...ChatFixtures.user(id: 'u-aigerim', name: 'Айгерим Нурланова'), 'position': 'Методист', 'department_name': 'Деканат'},
      {...ChatFixtures.user(id: 'u-daniyar', name: 'Данияр Ахметов', online: true), 'position': 'Профессор', 'department_name': 'Кафедра ИС'},
      {...ChatFixtures.user(id: 'u-saule', name: 'Сауле Жумабаева'), 'position': 'Бухгалтер', 'department_name': 'Бухгалтерия'},
      {...ChatFixtures.user(id: 'u-yerlan', name: 'Ерлан Касымов'), 'position': 'Ст. преподаватель', 'department_name': 'Кафедра ИС'},
    ];
    h.chatAdapter.onJson('GET', '/users', {'users': people});
    h.chatAdapter.onJson('GET', '/departments', {
      'departments': [
        {'id': 'd1', 'name': 'Кафедра ИС'},
        {'id': 'd2', 'name': 'Деканат'},
        {'id': 'd3', 'name': 'Бухгалтерия'},
      ],
    });
    final server = FakeCalendarServer(h.adapter, const [me, bob]);
    final almaty = CalendarZones.location('Asia/Almaty');
    DateTime at(int d, int hour, [int minute = 0]) => EventTime.atWall(CalendarDate(2026, 9, d), hour, minute, almaty);
    server.seedEvent(organizer: me, title: 'Планёрка кафедры', start: at(16, 9), end: at(16, 10), location: 'Ауд. 214');
    server.seedEvent(organizer: bob, title: 'Учёный совет', start: at(17, 14), end: at(17, 16), guests: const [me]);

    await tester.runAsync(() => h.session.restore());
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: UncontrolledProviderScope(container: h.container, child: const XatBoxApp()),
      ),
    );
    Future<void> settle([int steps = 20]) async {
      for (var i = 0; i < steps; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    Future<void> shot(String name) async {
      await settle();
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    Future<void> tapIf(Finder f) async {
      if (f.evaluate().isEmpty) {
        debugPrint('SCREENS: missing $f');
        return;
      }
      await tester.tap(f.first);
    }

    Future<void> skin(AppSkin s) => tester.runAsync(
      () => h.container.read(appPreferencesProvider.notifier).update((p) => p.copyWith(languageCode: 'ru', skin: s)),
    );

    await skin(AppSkin.steppe);
    await settle(30);
    final router = h.container.read(appRouterProvider);

    // Calendar: the new event form, empty, then filled.
    router.go(Routes.calendar);
    await settle();
    await tapIf(find.text('Новое событие').first);
    await shot('c1_event_new');
    await tester.enterText(find.byKey(const Key('event_title')), 'Заседание кафедры');
    await tapIf(find.byKey(const Key('event_duration_60')));
    await tester.enterText(find.byKey(const Key('event_participant_search')), 'Бол');
    await settle(20);
    await shot('c2_event_people');
    final pick = find.byKey(ValueKey('pick_${bob.id}'));
    if (pick.evaluate().isNotEmpty) await tapIf(pick);
    await settle();
    await tapIf(find.byKey(const Key('event_start_time')));
    await shot('c3_event_time_menu');
    await tapIf(find.text('11:30'));
    await settle();
    await tapIf(find.byKey(const Key('event_more')));
    await shot('c4_event_more');
    await tapIf(find.byKey(const Key('event_edit_close')));
    await settle();

    // Tasks board.
    router.go(Routes.tasks);
    await shot('t1_tasks_board');
    final card = find.byKey(const ValueKey('task_card_t8'));
    final target = find.byKey(const ValueKey('tasks_column_tomorrow'));
    if (card.evaluate().isNotEmpty && target.evaluate().isNotEmpty) {
      final gesture = await tester.startGesture(tester.getCenter(card), kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 50));
      for (var i = 1; i <= 8; i++) {
        await gesture.moveTo(Offset.lerp(tester.getCenter(card), tester.getCenter(target), i / 8)!);
        await tester.pump(const Duration(milliseconds: 30));
      }
      await shot('t2_tasks_dragging');
      await gesture.up();
      await gesture.removePointer();
      await settle();
    }
    await tapIf(find.byKey(const Key('tasks_add_today')));
    await settle();
    await tester.enterText(find.byKey(const Key('tasks_quick_today')), 'Распечатать приказ');
    await shot('t3_tasks_quick_add');
    await tapIf(find.byKey(const Key('tasks_mode_byStatus')));
    await shot('t4_tasks_by_status');
    await tapIf(find.byKey(const Key('tasks_mode_byDue')));
    await settle();

    // Contacts: empty «Мои контакты» → pin a colleague, add a personal one.
    router.go(Routes.contacts);
    await shot('k1_contacts_start');
    await tapIf(find.byKey(const Key('contacts_view_all')));
    await settle();
    final row = find.byKey(ValueKey('contact_row_${bob.id}'));
    if (row.evaluate().isNotEmpty) {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(row));
      await mouse.moveTo(tester.getCenter(row));
      await shot('k2_contacts_all_hover');
      await tapIf(find.byKey(ValueKey('contact_pin_${bob.id}')));
      await mouse.removePointer();
    }
    await tapIf(find.byKey(const Key('contacts_new')));
    await settle();
    await tester.enterText(find.byKey(const Key('personal_name')), 'Мария Иванова');
    await tester.enterText(find.byKey(const Key('personal_email')), 'maria@partner.kz');
    await tester.enterText(find.byKey(const Key('personal_phone')), '+7 701 555 12 34');
    await shot('k4_contacts_new_dialog');
    await tapIf(find.byKey(const Key('personal_save')));
    await settle();
    await tapIf(find.byKey(const Key('contacts_view_mine')));
    await settle();
    await tapIf(find.text('Мария Иванова'));
    await shot('k3_contacts_mine');

    // Glass skins.
    await skin(AppSkin.glassForest);
    router.go(Routes.tasks);
    await shot('g1_forest_tasks');
    router.go(Routes.contacts);
    await shot('g2_forest_contacts');
    await skin(AppSkin.glassSpace);
    router.go(Routes.calendar);
    await settle();
    await tapIf(find.text('Новое событие').first);
    await shot('g3_space_event');
    await tapIf(find.byKey(const Key('event_edit_close')));
    await settle();
    router.go(Routes.tasks);
    await shot('g4_space_tasks');
    await tapIf(find.byKey(const Key('topbar_theme')));
    await shot('g5_space_theme_panel');
    await tapIf(find.byKey(const Key('topbar_theme')));
    await settle();
    await skin(AppSkin.glassAstana);
    router.go(Routes.mail);
    await shot('g6_astana_mail');
    router.go(Routes.contacts);
    await shot('g7_astana_contacts');
    await skin(AppSkin.glassSemey);
    router.go(Routes.tasks);
    await shot('g8_semey_tasks');
    router.go(Routes.calendar);
    await shot('g9_semey_calendar');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle();

    await tester.runAsync(() => h.container.read(chatRepositoryProvider).stop());
    await tester.pump(const Duration(seconds: 10));
  }, timeout: const Timeout(Duration(minutes: 4)));
}
