import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:xatbox_mobile/core/localization/generated/app_localizations.dart';
import 'package:xatbox_mobile/core/routing/deep_links.dart';
import 'package:xatbox_mobile/core/routing/link_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_models.dart';
import 'package:xatbox_mobile/features/calendar/domain/calendar_time.dart';
import 'package:xatbox_mobile/features/chat/data/chat_models.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/home_widget/app_shortcuts.dart';
import 'package:xatbox_mobile/features/home_widget/home_widget_service.dart';
import 'package:xatbox_mobile/features/home_widget/home_widget_settings.dart';
import 'package:xatbox_mobile/features/home_widget/home_widget_snapshot.dart';

import '../helpers/chat_fixtures.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

class FakeHomeWidgetBridge implements HomeWidgetBridge {
  final List<String> saved = [];

  @override
  Future<void> save(String snapshot) async => saved.add(snapshot);
}

class FakeShortcutsBridge implements LauncherShortcutsBridge {
  final List<List<LauncherShortcut>> published = [];
  void Function(String type)? onAction;

  @override
  Future<void> initialize(void Function(String type) onAction) async =>
      this.onAction = onAction;

  @override
  Future<void> publish(List<LauncherShortcut> items) async =>
      published.add(items);
}

/// In-memory «Текст сообщений в виджете» for widget tests (no database I/O).
class _MemoryPreview extends HomeWidgetPreviewNotifier {
  @override
  bool build() => false;

  @override
  Future<void> set(bool value) async => state = value;
}

ChatConversation _conv(
  String id,
  String title, {
  int unread = 0,
  String body = 'привет',
  bool archived = false,
  bool saved = false,
}) {
  final j = ChatFixtures.conversation(
    id: id,
    title: title,
    unread: unread,
    lastMessage: ChatFixtures.message(id: 'm-$id', seq: 1, body: body, convId: id),
  );
  (j['settings'] as Map)['archived'] = archived;
  if (saved) j['type'] = 'saved';
  return ChatConversation.fromJson(j);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  CalendarZones.ensureInitialized();
  final l10n = lookupAppLocalizations(const Locale('ru'));
  final almaty = CalendarZones.location('Asia/Almaty');

  group('launcher links', () {
    test('shortcut and widget links map to routes', () {
      Uri u(String s) => Uri.parse(s);
      expect(DeepLinks.toRoute(u('xatbox://new/chat')), Routes.chatNew);
      expect(DeepLinks.toRoute(u('xatbox://new/call')), Routes.callsNew);
      expect(DeepLinks.toRoute(u('xatbox://chat/saved')), Routes.chatSaved);
      expect(DeepLinks.toRoute(u('xatbox://search')), Routes.search);
      expect(DeepLinks.toRoute(u('xatbox://today')), Routes.today);
      expect(DeepLinks.toRoute(u('xatbox://new/other')), isNull);
      expect(
        DeepLinks.toRoute(u('xatbox://chat/${ChatFixtures.conv}')),
        Routes.chatConversationPath(ChatFixtures.conv),
      );
    });

    test('every shortcut type opens its screen', () {
      String? route(String type) => DeepLinks.toRoute(shortcutLink(type)!);
      expect(route(ShortcutTypes.newMessage), Routes.chatNew);
      expect(route(ShortcutTypes.newCall), Routes.callsNew);
      expect(route(ShortcutTypes.saved), Routes.chatSaved);
      expect(route(ShortcutTypes.search), Routes.search);
      expect(route(ShortcutTypes.chat('c/1')), Routes.chatConversationPath('c/1'));
      expect(shortcutLink('unknown'), isNull);
      expect(shortcutLink(ShortcutTypes.chatPrefix), isNull);
    });

    test('iOS gets the four fixed actions; Android up to three recent chats', () {
      const labels = (newMessage: 'Н', call: 'П', saved: 'И', search: 'Р');
      expect(
        runtimeShortcuts(ios: true, labels: labels).map((s) => s.type),
        [ShortcutTypes.newMessage, ShortcutTypes.newCall, ShortcutTypes.saved, ShortcutTypes.search],
      );
      final android = runtimeShortcuts(
        ios: false,
        labels: labels,
        recentChats: const [
          (id: 'a', title: 'Алия'),
          (id: 'b', title: '  '),
          (id: 'c', title: 'Бахыт'),
          (id: 'd', title: 'Группа'),
          (id: 'e', title: 'Лишний'),
        ],
      );
      expect(android.map((s) => s.type), ['chat:a', 'chat:c', 'chat:d']);
      expect(android.every((s) => s.icon == chatShortcutIcon), isTrue);
    });
  });

  group('home widget snapshot', () {
    final now = DateTime.utc(2026, 9, 15, 6); // 11:00 in Almaty
    final convs = [
      _conv('a', 'Алия', unread: 2, body: 'Секретный текст\nвторая строка'),
      _conv('b', 'Прочитанный'),
      _conv('c', 'Архив', unread: 1, archived: true),
      _conv('d', 'Избранное', unread: 1, saved: true),
      _conv('e', 'Бухгалтерия', unread: 5),
      _conv('f', 'Четвёртый', unread: 1),
      _conv('g', 'Пятый', unread: 1),
    ];

    CalendarOccurrence occ(String id, String title, DateTime s, DateTime e, {String status = 'confirmed', bool allDay = false}) {
      final event = CalendarEvent.fromJson({
        'id': id, 'title': title, 'all_day': allDay, 'timezone': 'Asia/Almaty', 'status': status,
        'starts_at': EventTime.encode(s), 'ends_at': EventTime.encode(e), 'reminder_minutes': 0,
      });
      const day = CalendarDate(2026, 9, 15);
      return allDay
          ? CalendarOccurrence(event: event, start: s, end: e, allDayStart: day, allDayEnd: day.addDays(1))
          : CalendarOccurrence(event: event, start: s, end: e);
    }

    final today = [
      occ('e2', 'Ревью', DateTime.utc(2026, 9, 15, 8), DateTime.utc(2026, 9, 15, 9)),
      occ('e1', 'Планёрка', DateTime.utc(2026, 9, 15, 5), DateTime.utc(2026, 9, 15, 5, 30)),
      occ('e3', 'Созвон', DateTime.utc(2026, 9, 15, 6, 30), DateTime.utc(2026, 9, 15, 7)),
      occ('e4', 'Отменено', DateTime.utc(2026, 9, 15, 7), DateTime.utc(2026, 9, 15, 8), status: 'cancelled'),
      occ('e5', 'Отпуск', DateTime.utc(2026, 9, 14, 19), DateTime.utc(2026, 9, 15, 19), allDay: true),
    ];

    String build({bool preview = false, bool hide = false}) => buildHomeWidgetSnapshot(
      conversations: convs,
      unreadTotal: 9,
      today: today,
      location: almaty,
      now: now,
      l10n: l10n,
      showPreview: preview,
      hideContent: hide,
      accent: const Color(0xFF0B1F3D),
      accentDark: const Color(0xFF5B95E5),
      avatarColor: (_) => const Color(0xFF123456),
    );

    test('titles only by default; archived, saved and read chats are skipped', () {
      final raw = build();
      final s = jsonDecode(raw) as Map<String, dynamic>;
      expect(s['signedIn'], isTrue);
      expect(s['hidden'], isFalse);
      expect(s['unread'], 9);
      expect(s['headline'], '9 непрочитанных');
      expect(s['accent'], '#0B1F3D');
      expect(s['accentDark'], '#5B95E5');
      final chats = (s['chats'] as List).cast<Map<String, dynamic>>();
      expect(chats.map((c) => c['title']), ['Алия', 'Бухгалтерия', 'Четвёртый']);
      expect(chats.first['initial'], 'А');
      expect(chats.first['unread'], 2);
      expect(chats.first['color'], '#123456');
      expect(chats.any((c) => c.containsKey('preview')), isFalse);
      expect(raw.contains('Секретный'), isFalse, reason: 'no message text without opt-in');
    });

    test('preview only after opt-in: first line of the last message', () {
      final chats = (jsonDecode(build(preview: true))['chats'] as List).cast<Map<String, dynamic>>();
      expect(chats.first['preview'], 'Секретный текст');
    });

    test('hidden content keeps only the count', () {
      final raw = build(preview: true, hide: true);
      final s = jsonDecode(raw) as Map<String, dynamic>;
      expect(s['hidden'], isTrue);
      expect(s['chats'], isEmpty);
      expect(s['events'], isEmpty);
      for (final secret in ['Алия', 'Секретный', 'Ревью', 'Созвон']) {
        expect(raw.contains(secret), isFalse, reason: secret);
      }
      expect(s['unread'], 9);
    });

    test('events: timed, not cancelled, not over, sorted, local time', () {
      final s = jsonDecode(build()) as Map<String, dynamic>;
      final events = (s['events'] as List).cast<Map<String, dynamic>>();
      expect(events.map((e) => e['title']), ['Созвон', 'Ревью']);
      expect(events.map((e) => e['time']), ['11:30–12:00', '13:00–14:00']);
      expect(events.first['end'], DateTime.utc(2026, 9, 15, 7).millisecondsSinceEpoch);
      expect(s['dayEnd'], tz.TZDateTime(almaty, 2026, 9, 16).millisecondsSinceEpoch);
      expect((s['labels'] as Map)['noEvents'], l10n.homeWidgetNoEvents);
    });

    test('signed-out snapshot carries no data; previews skip deleted and trim long text', () {
      final out = jsonDecode(signedOutHomeWidgetSnapshot(l10n)) as Map<String, dynamic>;
      expect(out.keys.toSet(), {'v', 'signedIn', 'labels'});
      expect(out['signedIn'], isFalse);
      final deleted = ChatMessage.fromJson({
        ...ChatFixtures.message(id: 'x', seq: 2, body: 'удалено'),
        'deleted_at': '2026-09-15T10:00:00Z',
      });
      expect(messagePreview(deleted), '');
      final long = messagePreview(
        ChatMessage.fromJson(ChatFixtures.message(id: 'y', seq: 3, body: 'я' * 200)),
      );
      expect(long.length, 80);
      expect(long.endsWith('…'), isTrue);
    });
  });

  group('LauncherIntegration', () {
    late TestHarness h;
    tearDown(() => h.dispose());

    test('recent-chat shortcuts and widget follow the chat list; sign-out wipes them; taps wait for sign-in', () async {
      final widget = FakeHomeWidgetBridge();
      final shortcuts = FakeShortcutsBridge();
      h = await TestHarness.create(
        storedToken: Fixtures.token,
        chatBaseUrl: 'http://chat.local/api/v1',
        overrides: [
          launcherIntegrationEnabledProvider.overrideWithValue(true),
          homeWidgetSupportedProvider.overrideWithValue(true),
          launcherIsIosProvider.overrideWithValue(false),
          homeWidgetBridgeProvider.overrideWithValue(widget),
          launcherShortcutsBridgeProvider.overrideWithValue(shortcuts),
        ],
      );
      h.adapter.onJson('GET', '/me', Fixtures.me());
      h.chatAdapter.onJson(
        'GET',
        '/chats',
        ChatFixtures.chats([
          ChatFixtures.conversation(id: 'c1', title: 'Алия', unread: 3),
          ChatFixtures.conversation(id: 'c2', title: 'Бахыт'),
        ]),
      );
      await h.session.restore();
      // Listened like XatBoxApp does (an unlistened provider is paused).
      final sub = h.container.listen(launcherIntegrationProvider, (_, _) {});
      addTearDown(sub.close);
      final integration = sub.read()!;
      h.container.read(conversationsProvider);
      for (var i = 0; i < 20 && h.container.read(conversationsProvider).items.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      await integration.flush();
      expect(shortcuts.published.last.map((s) => s.type), ['chat:c1', 'chat:c2']);
      expect(shortcuts.published.last.map((s) => s.title), ['Алия', 'Бахыт']);
      final snap = jsonDecode(widget.saved.last) as Map<String, dynamic>;
      expect(snap['signedIn'], isTrue);
      expect(snap['unread'], 3);
      expect((snap['chats'] as List).single['title'], 'Алия');

      // Unchanged state is not written again.
      final writes = widget.saved.length;
      await integration.flush();
      expect(widget.saved.length, writes);

      // A shortcut tap becomes a pending location (opened after sign-in/lock).
      shortcuts.onAction!(ShortcutTypes.newCall);
      expect(h.container.read(pendingNavigationProvider), Routes.callsNew);

      // Session ends: no chat data remains in the widget or the shortcuts.
      h.session.expire();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final after = widget.saved.last;
      expect(jsonDecode(after)['signedIn'], isFalse);
      expect(after.contains('Алия'), isFalse);
      expect(shortcuts.published.last, isEmpty);
    });
  });

  group('settings section', () {
    late TestHarness h;
    tearDown(() => h.dispose());

    testWidgets('widget message text switch (Android only), off by default', (tester) async {
      h = await TestHarness.create(
        overrides: [
          homeWidgetSupportedProvider.overrideWithValue(true),
          // Persistence is covered below; no database I/O under fake time.
          homeWidgetPreviewProvider.overrideWith(_MemoryPreview.new),
        ],
      );
      await tester.pumpWidget(
        wrapWidget(const Scaffold(body: HomeWidgetSettingsSection()), container: h.container),
      );
      await tester.pump();
      final tile = find.byKey(const Key('settings_widget_preview'));
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
      await tester.tap(tile);
      await tester.pump();
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);
      expect(h.container.read(homeWidgetPreviewProvider), isTrue);
    });

    testWidgets('hidden where the widget is not supported', (tester) async {
      h = await TestHarness.create(
        overrides: [
          homeWidgetSupportedProvider.overrideWithValue(false),
          homeWidgetPreviewProvider.overrideWith(_MemoryPreview.new),
        ],
      );
      await tester.pumpWidget(
        wrapWidget(const Scaffold(body: HomeWidgetSettingsSection()), container: h.container),
      );
      await tester.pump();
      expect(find.byKey(const Key('settings_widget_preview')), findsNothing);
    });
  });

  test('widget message text setting is stored in the app database', () async {
    final h = await TestHarness.create();
    addTearDown(h.dispose);
    expect(h.container.read(homeWidgetPreviewProvider), isFalse);
    await h.container.read(homeWidgetPreviewProvider.notifier).set(true);
    h.container.invalidate(homeWidgetPreviewProvider);
    expect(h.container.read(homeWidgetPreviewProvider), isFalse, reason: 'loads asynchronously');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(h.container.read(homeWidgetPreviewProvider), isTrue);
  });
}
