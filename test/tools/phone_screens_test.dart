// Screenshots of the phone app's pages for design review (not a check):
// an iPhone-sized screen (390×844 pt, notch and home indicator), light and
// dark. Run: SCREENS=1 flutter test test/tools/phone_screens_test.dart
// PNGs land in build/phone_screens/.
@Tags(['screens'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/security/app_lock.dart';
import 'package:xatbox_mobile/core/preferences/app_preferences.dart';
import 'package:xatbox_mobile/core/theme/skins.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_reminders.dart';
import 'package:xatbox_mobile/features/calendar/domain/calendar_time.dart';
import 'package:xatbox_mobile/features/calendar/presentation/calendar_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';

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

void main() {
  final enabled = Platform.environment['SCREENS'] == '1';
  final out = Directory('build/phone_screens')..createSync(recursive: true);
  final clock = DateTime.utc(2026, 9, 16, 5, 30); // Wednesday 10:30 in Almaty
  const org = '33333333-3333-4333-8333-333333333333';
  const me = FakeCalendarUser(id: '11111111-1111-4111-8111-111111111111', token: Fixtures.token, name: 'Тест Пользователь', org: org);
  const bob = FakeCalendarUser(id: 'bbbbbbbb-0000-4000-8000-000000000002', token: 'tok-bob', name: 'Болат Сейтов', org: org);

  testWidgets('phone screens', (tester) async {
    if (!enabled) return;
    CalendarZones.ensureInitialized();
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 141, bottom: 102);
    tester.view.viewPadding = const FakeViewPadding(top: 141, bottom: 102);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localeTestValue = const Locale('ru');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    final h = await TestHarness.create(
      storedToken: Fixtures.token,
      chatBaseUrl: 'http://chat.local/api/v1',
      overrides: [
        initialDeviceZoneProvider.overrideWithValue('Asia/Almaty'),
        calendarClockProvider.overrideWithValue(() => clock),
        reminderSchedulerProvider.overrideWithValue(_NoReminders()),
      ],
    );
    addTearDown(h.dispose);
    h.stubSignedIn(messages: Fixtures.messages(12), total: 12);
    h.adapter.onJson('GET', '/me', Fixtures.me(permissions: const [
      'mail.read', 'mail.send', 'calendar.events.read', 'calendar.events.create', 'calendar.events.manage_own',
      'tasks.manage.self',
    ]));
    Map<String, dynamic> task(String id, String title, {String status = 'todo', String? due, String priority = 'normal'}) => {
      'id': id, 'owner_user_id': me.id, 'title': title, 'description': '', 'status': status, 'priority': priority,
      'due_at': ?due, 'source_type': 'manual', 'created_at': '2026-09-15T08:00:00Z', 'updated_at': '2026-09-15T08:00:00Z',
    };
    h.adapter.onJson('GET', '/tasks', {'tasks': [
      task('t1', 'Подготовить отчёт кафедры', due: '2026-09-16T12:00:00Z', priority: 'high'),
      task('t2', 'Согласовать расписание', due: '2026-09-17T09:00:00Z'),
      task('t3', 'Проверить курсовые работы'),
      task('t4', 'Заказать проектор', status: 'done'),
    ]});
    h.adapter.onJson('GET', '/tasks/boards', {'boards': [
      {'id': 'b1', 'name': 'Кафедра ИТ', 'description': '', 'color': 'blue', 'owner_user_id': me.id,
       'owner_name': 'Тест Пользователь', 'role': 'owner', 'members': <Object>[], 'open_count': 3},
    ]});
    h.adapter.onPattern('GET', r'^/mail/messages/m\d+$', (req) {
      final id = req.path.split('/').last;
      return FakeResponse(200, json: {
        ...Fixtures.detail(
          id: id,
          bodyHtml: '<html><head><style>.card{border:1px solid #dde;border-radius:8px;padding:16px}'
              '.btn{background:#2868B4;color:#fff;padding:8px 16px;border-radius:6px;text-decoration:none}</style></head>'
              '<body><div class="card"><h2>Заседание учёного совета</h2><p>Уважаемые коллеги! Приглашаем вас на заседание '
              'учёного совета в четверг в 14:00, ауд. 301.</p><p><a class="btn" href="https://kaztbu.edu.kz">Подтвердить участие</a></p>'
              '<table width="100%"><tr><td><b>Повестка</b></td><td>1. Отчёт кафедр<br>2. Разное</td></tr></table></div></body></html>',
        ),
      });
    });
    final conv = ChatFixtures.conversation(title: 'Болат Сейтов', lastSeq: 4);
    const requestsConv = 'c0000000-0000-4000-8000-0000000000aa';
    Map<String, dynamic> request(String status, String updatedAt) => {
      'id': 'r1', 'number': 42, 'what': 'Не работает проектор в аудитории', 'room': '305', 'date': '2026-09-16',
      'status': status, 'comment': '', 'updated_at': updatedAt,
    };
    final requests = {
      ...ChatFixtures.conversation(id: requestsConv, title: 'Заявки', lastSeq: 3),
      'type': 'requests', 'member_count': 1, 'peer': null,
    };
    h.chatAdapter.onPattern('GET', r'^/chats$', (req) => FakeResponse(200,
        json: ChatFixtures.chats([if (req.query['with_requests'] == '1') requests, conv])));
    h.chatAdapter.onJson('GET', '/chats/$requestsConv', requests);
    h.chatAdapter.onJson('GET', '/chats/$requestsConv/messages', ChatFixtures.messages([
      {...ChatFixtures.message(id: 'q1', seq: 1, type: 'request', sender: ChatFixtures.me, convId: requestsConv, status: 'read',
          body: 'Заявка №42'), 'request': request('new', '2026-09-16T04:00:00Z')},
      {...ChatFixtures.message(id: 'q2', seq: 2, type: 'request_update', convId: requestsConv,
          body: 'Заявка №42\nЗаявка принята и передана в работу. Ответ придёт в этот чат.'), 'request': request('new', '2026-09-16T04:00:00Z')},
      {...ChatFixtures.message(id: 'q3', seq: 3, type: 'request_update', convId: requestsConv,
          body: 'Заявка №42: В работе\nМастер придёт сегодня до 15:00.'), 'request': request('in_progress', '2026-09-16T05:00:00Z')},
    ]));
    h.chatAdapter.onPattern('POST', r'^/messages/[^/]+/read$', (_) => const FakeResponse(204));
    h.chatAdapter.onJson('GET', '/chats/${ChatFixtures.conv}', conv);
    h.chatAdapter.onJson(
      'GET',
      '/chats/${ChatFixtures.conv}/messages',
      ChatFixtures.messages([
        ChatFixtures.message(id: 'm1', seq: 1, body: 'Добрый день! Отчёт по кафедре готов?'),
        ChatFixtures.message(id: 'm2', seq: 2, body: 'Да, отправлю до обеда.', sender: ChatFixtures.me, status: 'read'),
        ChatFixtures.message(id: 'm3', seq: 3, body: 'Отлично, спасибо. Заседание в четверг в 14:00, ауд. 301.'),
        ChatFixtures.message(id: 'm4', seq: 4, body: 'Буду.', sender: ChatFixtures.me, status: 'read'),
      ]),
    );
    h.chatAdapter.onPattern('POST', r'^/push/devices$', (_) => const FakeResponse(204));
    h.chatAdapter.onJson('GET', '/users', {'users': [ChatFixtures.user(name: 'Болат Сейтов')]});
    final server = FakeCalendarServer(h.adapter, const [me, bob]);
    final almaty = CalendarZones.location('Asia/Almaty');
    DateTime at(int d, int hour, [int minute = 0]) => EventTime.atWall(CalendarDate(2026, 9, d), hour, minute, almaty);
    server.seedEvent(organizer: me, title: 'Планёрка кафедры', start: at(16, 9), end: at(16, 10), location: 'Ауд. 214');
    server.seedEvent(organizer: bob, title: 'Учёный совет', start: at(17, 14), end: at(17, 16), guests: const [me]);
    server.seedEvent(organizer: me, title: 'Лекция: Базы данных', start: at(15, 11), end: at(15, 12, 30), rrule: 'FREQ=WEEKLY');
    server.seedEvent(organizer: me, title: 'Приём студентов', start: at(18, 15), end: at(18, 17));
    server.seedEvent(organizer: me, title: 'День открытых дверей', start: at(19, 0), end: at(20, 0), allDay: true);
    server.seedEvent(organizer: me, title: 'Созвон с деканатом', start: at(16, 13), end: at(16, 13, 30));

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
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    Future<void> prefs(AppThemePreference theme) => tester.runAsync(
      () => h.container.read(appPreferencesProvider.notifier).update(
        // Google Sans has no Cyrillic and the test engine has no font
        // fallback: the Golos Text skin shows the layout readably.
        (p) => p.copyWith(
          languageCode: 'ru',
          theme: theme,
          skin: theme == AppThemePreference.dark
              ? AppSkin.standard
              : AppSkin.values.where((s) => s.name == Platform.environment['SKIN']).firstOrNull ?? AppSkin.steppe,
        ),
      ),
    );

    final router = h.container.read(appRouterProvider);
    for (final theme in [AppThemePreference.light, AppThemePreference.dark]) {
      final p = theme.name;
      await prefs(theme);
      await settle(30);
      router.go(Routes.mail);
      await shot('${p}_01_mail');
      await tester.tap(find.text('Тема письма 1').first);
      await settle();
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -3000));
      await shot('${p}_01b_mail_open');
      router.pop();
      await settle();
      router.go(Routes.chat);
      await shot('${p}_02_chat');
      router.go(Routes.calendar);
      await shot('${p}_03_calendar');
      await tester.tap(find.text('Планёрка кафедры').last);
      await shot('${p}_03b_event');
      router.pop();
      await settle();
      await tester.tap(find.byType(FloatingActionButton).last);
      await shot('${p}_03c_event_new');
      router.pop();
      await settle();
      router.go(Routes.tasks);
      await shot('${p}_04_tasks');
      router.go(Routes.mail);
      await settle();
      await tester.tap(find.byKey(const Key('tab_more')));
      await shot('${p}_05_more');
      await tester.tap(find.byKey(const Key('more_contacts')));
      await shot('${p}_06_contacts');
      unawaited(router.push(Routes.chatConversationPath(requestsConv)));
      await shot('${p}_07_requests');
      router.pop();
      await settle();
    }
    // The lock screen (PIN set, lock right away on return).
    await tester.runAsync(() async {
      await h.container.read(pinVaultProvider).setPin('1234');
      await h.container.read(appPreferencesProvider.notifier).update(
        (p) => p.copyWith(lockEnabled: true, lockTimeout: Duration.zero),
      );
    });
    for (final theme in [AppThemePreference.light, AppThemePreference.dark]) {
      await prefs(theme);
      final lock = h.container.read(appLockProvider.notifier);
      lock.onBackground();
      lock.onForeground();
      await shot('${theme.name}_08_lock');
      await tester.runAsync(() => lock.submit('1234'));
      await settle();
    }
    unawaited(h.container.read(chatRepositoryProvider).stop());
    await tester.pump(const Duration(seconds: 10));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
