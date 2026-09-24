import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/platform/desktop.dart';
import 'package:xatbox_mobile/core/platform/desktop_layout.dart';
import 'package:xatbox_mobile/core/preferences/app_preferences.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/core/security/app_lock.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_reminders.dart';
import 'package:xatbox_mobile/features/calendar/presentation/calendar_providers.dart';
import 'package:xatbox_mobile/features/calls/presentation/call_screen.dart';
import 'package:xatbox_mobile/features/calls/presentation/calls_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/mail/presentation/message_detail_screen.dart';

import '../helpers/call_fakes.dart';
import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// App lock around other entry points: system screens opened by the app,
/// notification / deep-link taps and incoming calls.
void main() {
  late TestHarness h;
  tearDown(() => h.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 12]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  void russian(WidgetTester tester) {
    tester.platformDispatcher.localeTestValue = const Locale('ru');
    tester.platformDispatcher.localesTestValue = const [Locale('ru')];
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }

  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      await tester.tap(find.byKey(Key('pin_key_$d')));
      await tester.pump();
    }
    await settle(tester);
  }

  test('returning from a system screen the app opened does not lock', () async {
    var now = DateTime.utc(2026, 9, 15, 10);
    h = await TestHarness.create(
      overrides: [
        initialAppPreferencesProvider.overrideWithValue(
          const AppPreferences(lockEnabled: true, lockTimeout: Duration.zero),
        ),
        lockClockProvider.overrideWithValue(() => now),
      ],
    );
    await h.container.read(pinVaultProvider).setPin('1234');
    final lock = h.container.read(appLockProvider.notifier);
    await lock.submit('1234');

    lock.expectExternalActivity();
    lock.onBackground();
    now = now.add(const Duration(seconds: 40));
    lock.onForeground();
    expect(h.container.read(appLockProvider).locked, isFalse);

    // Only once: the next trip to the background locks as usual.
    lock.onBackground();
    now = now.add(const Duration(seconds: 1));
    lock.onForeground();
    expect(h.container.read(appLockProvider).locked, isTrue);
  });

  testWidgets('a notification / link tap while locked opens behind the lock', (tester) async {
    russian(tester);
    h = await TestHarness.create(
      storedToken: Fixtures.token,
      overrides: [
        initialAppPreferencesProvider.overrideWithValue(const AppPreferences(lockEnabled: true)),
      ],
    );
    h.stubSignedIn();
    h.adapter.onJson('GET', '/mail/messages/m1', Fixtures.detail());
    await h.container.read(pinVaultProvider).setPin('1234');
    await tester.pumpWidget(UncontrolledProviderScope(container: h.container, child: const XatBoxApp()));
    await settle(tester);
    expect(find.byKey(const Key('lock_screen')), findsOneWidget);

    h.links.emit(Uri.parse('xatbox://mail/m1'));
    await settle(tester, 20);
    final router = h.container.read(appRouterProvider);
    expect(router.routerDelegate.currentConfiguration.matches.last.matchedLocation, Routes.mailMessagePath('m1'));
    expect(find.byKey(const Key('lock_screen')), findsOneWidget, reason: 'the target waits behind the lock');

    await enterPin(tester, '1234');
    expect(find.byKey(const Key('lock_screen')), findsNothing);
    expect(find.byType(MessageDetailScreen), findsOneWidget);
  });

  testWidgets('an incoming call shows over the lock; the lock returns after it', (tester) async {
    russian(tester);
    final native = FakeCallNative();
    h = await TestHarness.create(
      storedToken: Fixtures.token,
      chatBaseUrl: 'http://chat.local/api/v1',
      callsBaseUrl: 'http://calls.local/api/v1',
      overrides: [
        initialAppPreferencesProvider.overrideWithValue(const AppPreferences(lockEnabled: true)),
        callNativeProvider.overrideWithValue(native),
        callMediaFactoryProvider.overrideWithValue(FakeCallMedia.new),
        reminderSchedulerProvider.overrideWithValue(_NoReminders()),
      ],
    );
    h.stubSignedIn();
    h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats(const []));
    h.chatAdapter.onPattern('POST', r'^/push/devices$', (_) => const FakeResponse(204));
    final server = FakeCallServer(h.callsAdapter, selfId: '11111111-1111-4111-8111-111111111111', selfName: 'Тест Пользователь');
    await h.container.read(pinVaultProvider).setPin('1234');
    await tester.runAsync(() => h.session.restore());
    await tester.pumpWidget(UncontrolledProviderScope(container: h.container, child: const XatBoxApp()));
    await settle(tester);
    expect(find.byKey(const Key('lock_screen')), findsOneWidget);
    expect(find.text('Здравствуйте, Тест Пользователь'), findsOneWidget);

    final id = server.addIncoming(callerId: 'u-bob', callerName: 'Болат Сейтов', type: 'audio');
    h.socketFactory.last.serverSend({'type': 'call.incoming', 'call_id': id, 'call': server.calls[id]});
    await settle(tester, 20);
    expect(find.byType(CallScreen), findsOneWidget);
    expect(find.byKey(const Key('lock_screen')), findsNothing, reason: 'answering must not need the PIN');

    unawaited(h.container.read(callControllerProvider.notifier).hangUp());
    await tester.pump(const Duration(seconds: 1));
    await settle(tester, 20);
    final router = h.container.read(appRouterProvider);
    if (router.routeInformationProvider.value.uri.path != Routes.call) {
      expect(find.byKey(const Key('lock_screen')), findsOneWidget);
    } else {
      router.pop();
      await settle(tester);
      expect(find.byKey(const Key('lock_screen')), findsOneWidget);
    }
    unawaited(h.container.read(chatRepositoryProvider).stop());
    await tester.pump(const Duration(seconds: 10));
  });
  testWidgets('desktop: in a small window the whole PIN card fits, keypad included', (tester) async {
    russian(tester);
    debugDesktopOverride = true;
    addTearDown(() => debugDesktopOverride = null);
    // The window from the report: about 1000×640.
    tester.view.physicalSize = const Size(1000, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await TestHarness.create(
      storedToken: Fixtures.token,
      chatBaseUrl: 'http://chat.local/api/v1',
      overrides: [
        desktopLayoutProvider.overrideWithValue(true),
        initialAppPreferencesProvider.overrideWithValue(const AppPreferences(lockEnabled: true)),
        reminderSchedulerProvider.overrideWithValue(_NoReminders()),
      ],
    );
    h.stubSignedIn();
    h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats(const []));
    h.chatAdapter.onPattern('POST', r'^/push/devices$', (_) => const FakeResponse(204));
    await h.container.read(pinVaultProvider).setPin('1234');
    await tester.runAsync(() => h.session.restore());
    await tester.pumpWidget(UncontrolledProviderScope(container: h.container, child: const XatBoxApp()));
    await settle(tester);
    expect(find.byKey(const Key('lock_screen')), findsOneWidget);

    const screen = Rect.fromLTWH(0, 0, 1000, 640);
    for (final d in ['1', '0', 'delete']) {
      final box = tester.getRect(find.byKey(Key('pin_key_$d')));
      expect(screen.contains(box.topLeft) && screen.contains(box.bottomRight), isTrue, reason: 'pin_key_$d at $box');
    }
    expect(tester.takeException(), isNull);
    // The keys are real buttons at their scaled size.
    for (final d in ['1', '2', '3', '4']) {
      await tester.tap(find.byKey(Key('pin_key_$d')));
      await tester.pump();
    }
    await settle(tester);
    expect(h.container.read(appLockProvider).locked, isFalse);

    unawaited(h.container.read(chatRepositoryProvider).stop());
    await tester.pump(const Duration(seconds: 10));
  });
  testWidgets('desktop: the PIN is typed on the keyboard; closing to the tray locks when asked', (tester) async {
    russian(tester);
    debugDesktopOverride = true;
    addTearDown(() => debugDesktopOverride = null);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await TestHarness.create(
      storedToken: Fixtures.token,
      chatBaseUrl: 'http://chat.local/api/v1',
      overrides: [
        desktopLayoutProvider.overrideWithValue(true),
        initialAppPreferencesProvider.overrideWithValue(const AppPreferences(lockEnabled: true, lockOnClose: true)),
        reminderSchedulerProvider.overrideWithValue(_NoReminders()),
      ],
    );
    h.stubSignedIn();
    h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats(const []));
    h.chatAdapter.onPattern('POST', r'^/push/devices$', (_) => const FakeResponse(204));
    await h.container.read(pinVaultProvider).setPin('1234');
    await tester.runAsync(() => h.session.restore());
    await tester.pumpWidget(UncontrolledProviderScope(container: h.container, child: const XatBoxApp()));
    await settle(tester);
    expect(find.byKey(const Key('lock_screen')), findsOneWidget);

    // Digits from the keyboard, with nothing focused on purpose: the lock
    // listens to the hardware keyboard itself. Each digit lands once.
    for (final key in [LogicalKeyboardKey.digit1, LogicalKeyboardKey.digit2, LogicalKeyboardKey.digit3]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad4);
    await settle(tester);
    expect(h.container.read(appLockProvider).locked, isFalse, reason: '1, 2, 3, ⌫, 3, 4 on the keypad = 1234');
    expect(find.byKey(const Key('lock_screen')), findsNothing);

    // «Запрашивать PIN при закрытии окна»: the «X» locks at once.
    DesktopTray.instance.onClosedToTray?.call();
    await settle(tester);
    expect(h.container.read(appLockProvider).locked, isTrue);
    expect(find.byKey(const Key('lock_screen')), findsOneWidget);

    unawaited(h.container.read(chatRepositoryProvider).stop());
    await tester.pump(const Duration(seconds: 10));
  });
}

class _NoReminders implements ReminderScheduler {
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> schedule(ReminderRequest request) async {}
  @override
  Future<void> cancel(int id) async {}
}
