import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/network/network_status.dart';
import 'package:xatbox_mobile/core/preferences/app_preferences.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/core/security/app_lock.dart';
import 'package:xatbox_mobile/core/security/lock_screen.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_home_screen.dart';
import 'package:xatbox_mobile/features/mail/presentation/message_detail_screen.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// App-level features around the router: offline banner, PIN lock,
/// privacy cover, theme/language preferences, deep links.
void main() {
  late TestHarness h;
  tearDown(() => h.dispose());

  Future<void> pumpApp(WidgetTester tester) async {
    tester.platformDispatcher.localeTestValue = const Locale('ru');
    tester.platformDispatcher.localesTestValue = const [Locale('ru')];
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: const XatBoxApp(),
      ),
    );
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester, [int steps = 10]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<TestHarness> signedIn({List<Override> overrides = const []}) async {
    final harness = await TestHarness.create(
      storedToken: Fixtures.token,
      overrides: overrides,
    );
    harness.stubSignedIn();
    return harness;
  }

  testWidgets('offline banner follows connectivity without rebuilding routes', (
    tester,
  ) async {
    h = await signedIn();
    await pumpApp(tester);
    await settle(tester);
    expect(find.byType(MailHomeScreen), findsOneWidget);
    expect(find.byKey(const Key('offline_banner')), findsNothing);
    final listCalls = h.adapter.of('GET', '/mail/messages').length;

    h.network.set(NetworkKind.none);
    await settle(tester);
    expect(find.text('Нет подключения к сети'), findsOneWidget);

    h.network.set(NetworkKind.mobile);
    await settle(tester);
    expect(find.byKey(const Key('offline_banner')), findsNothing);
    expect(find.byType(MailHomeScreen), findsOneWidget);
    expect(h.adapter.of('GET', '/mail/messages').length, listCalls);
  });

  testWidgets('cold start with PIN lock: wrong PIN, then unlock', (
    tester,
  ) async {
    h = await signedIn(
      overrides: [
        initialAppPreferencesProvider.overrideWithValue(
          const AppPreferences(lockEnabled: true),
        ),
      ],
    );
    await h.container.read(pinVaultProvider).setPin('1234');
    await pumpApp(tester);
    await settle(tester);

    expect(find.byKey(const Key('lock_screen')), findsOneWidget);
    for (final d in ['1', '1', '1', '1']) {
      await tester.tap(find.byKey(Key('pin_key_$d')));
      await tester.pump();
    }
    await settle(tester);
    expect(find.text('Неверный PIN-код. Осталось 9 попыток'), findsOneWidget);

    for (final d in ['1', '2', '3', '4']) {
      await tester.tap(find.byKey(Key('pin_key_$d')));
      await tester.pump();
    }
    await settle(tester);
    expect(find.byKey(const Key('lock_screen')), findsNothing);
    expect(find.byType(MailHomeScreen), findsOneWidget);
  });

  testWidgets('background longer than the timeout locks again; cover hides content', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 9, 15, 10);
    h = await signedIn(
      overrides: [
        initialAppPreferencesProvider.overrideWithValue(
          const AppPreferences(lockEnabled: true, hideInSwitcher: true),
        ),
        lockClockProvider.overrideWithValue(() => now),
      ],
    );
    await h.container.read(pinVaultProvider).setPin('1234');
    await h.container.read(appLockProvider.notifier).submit('1234');
    await pumpApp(tester);
    await settle(tester);
    expect(find.byKey(const Key('lock_screen')), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byKey(const Key('privacy_cover')), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 5));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(find.byKey(const Key('privacy_cover')), findsNothing);
    expect(find.byKey(const Key('lock_screen')), findsOneWidget);
  });

  testWidgets('biometric unlock is offered automatically when enabled', (
    tester,
  ) async {
    h = await signedIn(
      overrides: [
        initialAppPreferencesProvider.overrideWithValue(
          const AppPreferences(lockEnabled: true, biometricEnabled: true),
        ),
      ],
    );
    await h.container.read(pinVaultProvider).setPin('1234');
    await pumpApp(tester);
    await settle(tester);
    expect(h.biometrics.prompts, 1);
    expect(find.byKey(const Key('lock_screen')), findsNothing);
  });

  testWidgets('settings: theme choice applies and persists; PIN setup enables the lock', (
    tester,
  ) async {
    h = await signedIn();
    await pumpApp(tester);
    await settle(tester);
    h.container.read(appRouterProvider).push(Routes.settings);
    await settle(tester);

    await tester.tap(find.byKey(const Key('settings_theme')));
    await settle(tester);
    await tester.tap(find.text('Тёмная'));
    await settle(tester);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    // sembast works on real timers.
    final stored = await tester.runAsync(
      () => h.container.read(appPreferencesStoreProvider).read(),
    );
    expect(stored!.theme, AppThemePreference.dark);

    await tester.tap(find.byKey(const Key('settings_language')));
    await settle(tester);
    await tester.tap(find.text('English'));
    await settle(tester);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings_pin')));
    await settle(tester);
    expect(find.byType(PinSetupScreen), findsOneWidget);
    for (final d in ['2', '5', '8', '0']) {
      await tester.tap(find.byKey(Key('pin_key_$d')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('pin_setup_next')));
    await settle(tester);
    for (final d in ['2', '5', '8', '0']) {
      await tester.tap(find.byKey(Key('pin_key_$d')));
      await tester.pump();
    }
    // Saving the preference goes through sembast, which needs real async.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await settle(tester);
    expect(find.byType(PinSetupScreen), findsNothing);
    expect(h.container.read(appPreferencesProvider).lockEnabled, isTrue);
    expect(await h.container.read(pinVaultProvider).hasPin(), isTrue);
    expect(find.byKey(const Key('lock_screen')), findsNothing);

    // Storage used on the device (fake inspector: 1 MB + 512 KB).
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings_storage_used')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Used on this device: 1.5 MB'), findsOneWidget);
  });

  testWidgets('deep link received before sign-in opens after the main screen', (
    tester,
  ) async {
    h = await signedIn();
    h.adapter.onJson('GET', '/mail/messages/m1', Fixtures.detail());
    h.links.initialLink = Uri.parse('xatbox://mail/m1');
    await pumpApp(tester);
    await settle(tester, 20);
    expect(find.byType(MessageDetailScreen), findsOneWidget);
    expect(h.adapter.of('GET', '/mail/messages/m1'), hasLength(1));

    // Unsupported links are ignored; supported ones open while running.
    h.links.emit(Uri.parse('https://evil.example/mail/m1'));
    await settle(tester);
    expect(h.adapter.of('GET', '/mail/messages/m1'), hasLength(1));
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.byType(MailHomeScreen), findsOneWidget);
    h.links.emit(Uri.parse('xatbox://mail/m1'));
    await settle(tester);
    expect(find.byType(MessageDetailScreen), findsOneWidget);
  });
}
