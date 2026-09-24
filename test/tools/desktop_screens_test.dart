// Screenshots of the desktop app's pages for design review (not a check).
// Run: SCREENS=1 flutter test test/tools/desktop_screens_test.dart
// PNGs land in build/desktop_screens/.
@Tags(['screens'])
library;

import 'dart:async';
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
  final out = Directory('build/desktop_screens')..createSync(recursive: true);
  final clock = DateTime.utc(2026, 9, 16, 5, 30); // Wednesday 10:30 in Almaty
  const org = '33333333-3333-4333-8333-333333333333';
  const me = FakeCalendarUser(id: '11111111-1111-4111-8111-111111111111', token: Fixtures.token, name: 'Тест Пользователь', org: org);
  const bob = FakeCalendarUser(id: 'bbbbbbbb-0000-4000-8000-000000000002', token: 'tok-bob', name: 'Болат Сейтов', org: org);

  testWidgets('desktop screens', (tester) async {
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
        reminderSchedulerProvider.overrideWithValue(_NoReminders()),
      ],
    );
    addTearDown(h.dispose);
    h.stubSignedIn(messages: Fixtures.messages(12), total: 12);
    h.adapter.onJson('GET', '/me', Fixtures.me(permissions: const [
      'mail.read', 'mail.send', 'calendar.events.read', 'calendar.events.create', 'calendar.events.manage_own',
    ]));
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
    h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats([conv]));
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
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${out.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    await tester.runAsync(
      () => h.container.read(appPreferencesProvider.notifier).update(// Google Sans has no Cyrillic and the test engine has no font
      // fallback: the Golos Text skin shows the layout readably.
      (p) => p.copyWith(
        languageCode: 'ru',
        skin: AppSkin.values.where((s) => s.name == Platform.environment['SKIN']).firstOrNull ?? AppSkin.steppe,
      )),
    );
    await settle(30);
    final router = h.container.read(appRouterProvider);
    await shot('01_mail');
    await tester.tap(find.text('Тема письма 1').first);
    await shot('02_mail_open');
    router.go(Routes.calendar);
    await shot('03_calendar');
    await tester.tap(find.text('Неделя').first);
    await shot('03b_calendar_week');
    await tester.tap(find.text('Планёрка кафедры').first);
    await shot('03c_calendar_event');
    await tester.tap(find.byKey(const Key('event_panel_close')));
    await settle();
    await tester.tap(find.text('Новое событие').first);
    await shot('03d_calendar_new');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle();
    if (find.byKey(const Key('event_edit_close')).evaluate().isNotEmpty) {
      debugPrint('SCREENS: Esc left the event dialog open');
      await tester.tap(find.byKey(const Key('event_edit_close')));
      await settle();
    }
    await tester.tap(find.text('День').first);
    await shot('03e_calendar_day');
    await tester.tap(find.text('Планёрка кафедры').first);
    await shot('03f_calendar_day_event');
    await tester.tap(find.byKey(const Key('event_panel_close')));
    router.go(Routes.calendar);
    for (final route in [Routes.chat, Routes.contacts, Routes.calls, Routes.settings]) {
      router.go(route);
      await shot('04_${route.substring(1)}');
    }
    // A chat opened from elsewhere lands in the messenger's pane.
    unawaited(router.push(Routes.chatConversationPath(ChatFixtures.conv)));
    await shot('05_chat_open');
    router.go(Routes.contacts);
    await settle();
    final contact = find.text('Болат Сейтов');
    if (contact.evaluate().isNotEmpty) {
      await tester.tap(contact.first, buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
      await shot('05b_contact_menu');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    }
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await shot('05c_palette');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    router.go(Routes.profile);
    await shot('06_profile');
    router.go(Routes.settingsSecurity);
    await shot('06b_security');
    unawaited(h.container.read(chatRepositoryProvider).stop());
    await tester.pump(const Duration(seconds: 10));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
