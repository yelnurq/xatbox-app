import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/lifecycle/background_connection.dart';
import 'package:xatbox_mobile/core/localization/localization.dart';
import 'package:xatbox_mobile/core/preferences/app_preferences.dart';
import 'package:xatbox_mobile/core/network/network_status.dart';
import 'package:xatbox_mobile/core/theme/app_theme.dart';
import 'package:xatbox_mobile/features/settings/data/notification_preferences.dart';
import 'package:xatbox_mobile/features/settings/notification_settings_screen.dart';

import '../helpers/fake_http.dart';
import '../helpers/test_app.dart';

const _path = NotificationPreferencesApi.path;
const _chatUrl = 'http://chat.local/api/v1';

Map<String, Object?> _server({bool direct = true}) => {
  'direct_messages': direct,
  'group_messages': true,
  'group_mentions_only': false,
  'calls': true,
  'quiet_hours': {
    'enabled': false,
    'start': '22:00',
    'end': '07:00',
    'timezone': 'UTC',
    'allow_calls': true,
  },
};

Future<void> _until(bool Function() cond) async {
  for (var i = 0; i < 200 && !cond(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(cond(), isTrue);
}

void main() {
  test('model: json round trip, defaults for missing or bad values', () {
    const p = NotificationPreferences(
      groupMentionsOnly: true,
      calls: false,
      quietHours: QuietHoursPrefs(
        enabled: true,
        start: '23:30',
        end: '06:45',
        timezone: 'Asia/Almaty',
        allowCalls: false,
      ),
    );
    expect(NotificationPreferences.fromJson(p.toJson()), p);
    final partial = NotificationPreferences.fromJson({
      'quiet_hours': {'start': '7:00', 'timezone': ''},
    });
    expect(partial, const NotificationPreferences());
    expect(QuietHoursPrefs.parseClock('22:00'), 1320);
    expect(QuietHoursPrefs.parseClock('24:00'), isNull);
    expect(QuietHoursPrefs.formatClock(7, 5), '07:05');
  });

  test('offline change stays pending and syncs when the network returns', () async {
    final h = await TestHarness.create(chatBaseUrl: _chatUrl);
    addTearDown(h.dispose);
    h.chatAdapter.onJson('GET', _path, _server());
    final c = h.container;
    final sub = c.listen(notificationPreferencesProvider, (_, _) {});
    addTearDown(sub.close);
    NotificationPreferencesState s() => c.read(notificationPreferencesProvider);

    await _until(() => s().status == NotificationSyncStatus.synced);
    expect(s().prefs.directMessages, isTrue);

    h.chatAdapter.onOffline('PUT', _path);
    await c
        .read(notificationPreferencesProvider.notifier)
        .update((p) => p.copyWith(directMessages: false));
    expect(s().prefs.directMessages, isFalse, reason: 'optimistic');
    expect(s().status, NotificationSyncStatus.pending);
    expect((await c.read(notificationPreferencesStoreProvider).read())!.dirty, isTrue);

    h.chatAdapter.on('PUT', _path, (req) => FakeResponse(200, json: req.json));
    // Go back online only once the provider graph has seen "offline". A fixed
    // real-time pause (it was 10 ms) races the stream → provider propagation
    // under full-suite CPU load: wifi then arrives first, isOnline goes
    // true → true, the listener never fires and nothing re-syncs.
    h.network.set(NetworkKind.none);
    await _until(() => !c.read(isOnlineProvider));
    h.network.set(NetworkKind.wifi);
    await _until(() => s().status == NotificationSyncStatus.synced);

    final sent = h.chatAdapter.of('PUT', _path).last.json;
    expect(sent['direct_messages'], isFalse);
    expect((sent['quiet_hours'] as Map)['timezone'], 'UTC');
    expect((await c.read(notificationPreferencesStoreProvider).read())!.dirty, isFalse);
  });

  test('a pending change from the last run is sent, not overwritten', () async {
    final h = await TestHarness.create(chatBaseUrl: _chatUrl);
    addTearDown(h.dispose);
    await NotificationPreferencesStore(
      h.db,
    ).write(const NotificationPreferences(calls: false), dirty: true);
    h.chatAdapter.onJson('GET', _path, _server());
    h.chatAdapter.on('PUT', _path, (req) => FakeResponse(200, json: req.json));
    final c = h.container;
    final sub = c.listen(notificationPreferencesProvider, (_, _) {});
    addTearDown(sub.close);

    await _until(
      () => c.read(notificationPreferencesProvider).status == NotificationSyncStatus.synced,
    );
    expect(c.read(notificationPreferencesProvider).prefs.calls, isFalse);
    expect(h.chatAdapter.of('GET', _path), isEmpty);
    expect(h.chatAdapter.of('PUT', _path).single.json['calls'], isFalse);
  });

  testWidgets('screen: toggles save optimistically, mentions-only needs groups', (
    tester,
  ) async {
    final h = await TestHarness.create(chatBaseUrl: _chatUrl);
    addTearDown(h.dispose);
    h.chatAdapter.onJson('GET', _path, _server());
    h.chatAdapter.onOffline('PUT', _path);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalization.delegates,
          supportedLocales: AppLocalization.supportedLocales,
          home: const NotificationSettingsScreen(),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Личные сообщения'), findsOneWidget);
    expect(find.byKey(const Key('notif_pending')), findsNothing);

    await tester.tap(find.byKey(const Key('notif_groups')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      tester.widget<SwitchListTile>(find.byKey(const Key('notif_groups'))).value,
      isFalse,
    );
    expect(
      tester.widget<SwitchListTile>(find.byKey(const Key('notif_mentions_only'))).onChanged,
      isNull,
    );
    expect(find.byKey(const Key('notif_pending')), findsOneWidget);
  });

  testWidgets('«Оставаться на связи в фоне»: default 15 min without push, «Всегда» is saved', (
    tester,
  ) async {
    final h = await TestHarness.create(chatBaseUrl: _chatUrl);
    addTearDown(h.dispose);
    h.chatAdapter.onJson('GET', _path, _server());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalization.delegates,
          supportedLocales: AppLocalization.supportedLocales,
          home: const NotificationSettingsScreen(),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final tile = find.byKey(const Key('notif_background'));
    await tester.scrollUntilVisible(tile, 200);
    expect(
      find.descendant(of: tile, matching: find.textContaining('По умолчанию (15 минут)')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile, matching: find.textContaining('Push-уведомления не настроены')),
      findsOneWidget,
    );
    expect(h.container.read(backgroundGraceProvider), const Duration(minutes: 15));

    await tester.tap(tile);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Быстрее расходует заряд батареи'), findsOneWidget);
    await tester.tap(find.byKey(const Key('notif_background_always')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(
      h.container.read(appPreferencesProvider).backgroundConnection,
      BackgroundConnection.always,
    );
    expect(h.container.read(backgroundGraceProvider), isNull);
    final stored = await tester.runAsync(
      () => h.container.read(appPreferencesStoreProvider).read(),
    );
    expect(stored!.backgroundConnection, BackgroundConnection.always);

    // A registered push token makes the default 1 minute.
    await h.container
        .read(appPreferencesProvider.notifier)
        .update((p) => p.copyWith(backgroundConnection: BackgroundConnection.auto));
    h.container.read(pushRegisteredProvider.notifier).set(true);
    await tester.pump();
    expect(h.container.read(backgroundGraceProvider), const Duration(minutes: 1));
    expect(
      find.descendant(of: tile, matching: find.textContaining('По умолчанию (1 минута)')),
      findsOneWidget,
    );
  });
}
