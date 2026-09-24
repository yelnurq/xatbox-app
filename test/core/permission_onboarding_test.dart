import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/auth/auth_providers.dart';
import 'package:xatbox_mobile/core/localization/generated/app_localizations_ru.dart';
import 'package:xatbox_mobile/core/localization/localization.dart';
import 'package:xatbox_mobile/core/notifications/exact_alarms.dart';
import 'package:xatbox_mobile/core/permissions/device_permissions.dart';
import 'package:xatbox_mobile/core/permissions/permission_onboarding_host.dart';
import 'package:xatbox_mobile/core/storage/app_database.dart';
import 'package:xatbox_mobile/core/theme/app_theme.dart';
import 'package:xatbox_mobile/features/calls/presentation/calls_providers.dart';
import 'package:xatbox_mobile/features/settings/background_help_screen.dart';
import 'package:xatbox_mobile/features/settings/notification_settings_screen.dart';

class FakeDevicePermissions implements DevicePermissions {
  FakeDevicePermissions({
    this.supported = true,
    this.notificationState = GrantState.denied,
    this.fullScreen = false,
    this.battery = false,
    this.grantOnRequest = true,
  });

  @override
  final bool supported;
  GrantState notificationState;
  bool fullScreen;
  bool battery;
  final bool grantOnRequest;
  final calls = <String>[];

  @override
  Future<GrantState> notifications() async => notificationState;

  @override
  Future<GrantState> requestNotifications() async {
    calls.add('notifications');
    if (grantOnRequest) notificationState = GrantState.granted;
    return notificationState;
  }

  @override
  Future<bool> canUseFullScreenIntent() async => fullScreen;

  @override
  Future<void> openFullScreenIntentSettings() async {
    calls.add('fullScreen');
    if (grantOnRequest) fullScreen = true;
  }

  @override
  Future<bool> isIgnoringBatteryOptimizations() async => battery;

  @override
  Future<bool> requestIgnoreBatteryOptimizations() async {
    calls.add('battery');
    if (grantOnRequest) battery = true;
    return battery;
  }
}

Widget _app(Widget home, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalization.delegates,
    supportedLocales: AppLocalization.supportedLocales,
    home: home,
  ),
);

void main() {
  group('pendingPermissionPrompts', () {
    test('nothing on unsupported platforms', () async {
      final p = FakeDevicePermissions(supported: false);
      expect(await pendingPermissionPrompts(permissions: p, shown: {}, callsEnabled: true), isEmpty);
    });

    test('missing grants in order; calls off skips full-screen', () async {
      final p = FakeDevicePermissions();
      expect(
        await pendingPermissionPrompts(permissions: p, shown: {}, callsEnabled: true),
        [PermissionPrompt.notifications, PermissionPrompt.fullScreenIntent],
      );
      expect(
        await pendingPermissionPrompts(permissions: p, shown: {}, callsEnabled: false),
        [PermissionPrompt.notifications],
      );
    });

    test('granted, already explained or permanently denied are not asked', () async {
      final granted = FakeDevicePermissions(notificationState: GrantState.granted, fullScreen: true);
      expect(await pendingPermissionPrompts(permissions: granted, shown: {}, callsEnabled: true), isEmpty);

      final shown = FakeDevicePermissions();
      expect(
        await pendingPermissionPrompts(
          permissions: shown,
          shown: {PermissionPrompt.notifications, PermissionPrompt.fullScreenIntent},
          callsEnabled: true,
        ),
        isEmpty,
      );

      final blocked = FakeDevicePermissions(notificationState: GrantState.permanentlyDenied, fullScreen: true);
      expect(await pendingPermissionPrompts(permissions: blocked, shown: {}, callsEnabled: true), isEmpty);
    });
  });

  group('runPermissionOnboarding', () {
    late AppDatabase db;
    setUp(() async => db = await AppDatabase.inMemory());
    tearDown(() => db.close());

    test('asks the system only after consent and records every explainer', () async {
      final p = FakeDevicePermissions();
      final store = PermissionPromptStore(db);
      final explained = <PermissionPrompt>[];
      final done = await runPermissionOnboarding(
        permissions: p,
        store: store,
        callsEnabled: true,
        explain: (prompt) async {
          explained.add(prompt);
          return prompt == PermissionPrompt.notifications;
        },
      );
      expect(explained, [PermissionPrompt.notifications, PermissionPrompt.fullScreenIntent]);
      expect(done, explained);
      expect(p.calls, ['notifications'], reason: 'declined full-screen: no settings jump');
      expect(await store.shown(), {PermissionPrompt.notifications, PermissionPrompt.fullScreenIntent});

      // Next start: nothing is shown again even though full-screen is still off.
      final again = await runPermissionOnboarding(
        permissions: p,
        store: store,
        callsEnabled: true,
        explain: (_) async => fail('must not explain twice'),
      );
      expect(again, isEmpty);
    });

    test('stops when the host is gone', () async {
      final p = FakeDevicePermissions();
      final done = await runPermissionOnboarding(
        permissions: p,
        store: PermissionPromptStore(db),
        callsEnabled: true,
        stillWanted: () => false,
        explain: (_) async => true,
      );
      expect(done, isEmpty);
      expect(p.calls, isEmpty);
    });
  });

  group('scheduleWithExactFallback', () {
    test('inexact directly when exact is not allowed', () async {
      final modes = <AndroidScheduleMode>[];
      await scheduleWithExactFallback(exact: false, schedule: (m) async => modes.add(m));
      expect(modes, [AndroidScheduleMode.inexactAllowWhileIdle]);
    });

    test('exact refused by the platform falls back to inexact', () async {
      final modes = <AndroidScheduleMode>[];
      var fellBack = false;
      await scheduleWithExactFallback(
        exact: true,
        schedule: (m) async {
          modes.add(m);
          if (m == AndroidScheduleMode.exactAllowWhileIdle) throw Exception('exact_alarms_not_permitted');
        },
        onFallback: () => fellBack = true,
      );
      expect(modes, [AndroidScheduleMode.exactAllowWhileIdle, AndroidScheduleMode.inexactAllowWhileIdle]);
      expect(fellBack, isTrue);
    });
  });

  group('widgets', () {
    testWidgets('explainer sheet returns the choice', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await showPermissionExplainer(context, PermissionPrompt.fullScreenIntent),
              child: const Text('go'),
            ),
          ),
          const [],
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('permission_explainer_fullScreenIntent')), findsOneWidget);
      await tester.tap(find.byKey(const Key('permission_explainer_later')));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('onboarding host shows the explainer once and requests after consent', (tester) async {
      final db = await tester.runAsync(AppDatabase.inMemory);
      final p = FakeDevicePermissions(fullScreen: true);
      await tester.pumpWidget(
        _app(
          const PermissionOnboardingHost(
            callsEnabled: true,
            delay: Duration(milliseconds: 10),
            child: Scaffold(body: Text('shell')),
          ),
          [
            appDatabaseProvider.overrideWithValue(db!),
            devicePermissionsProvider.overrideWithValue(p),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('permission_explainer_notifications')), findsOneWidget);
      await tester.tap(find.byKey(const Key('permission_explainer_allow')));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      expect(p.calls, ['notifications']);
      expect(await tester.runAsync(() => PermissionPromptStore(db).shown()), {PermissionPrompt.notifications});
      await tester.runAsync(db.close);
    });

    testWidgets('onboarding host does nothing where unsupported (no timers)', (tester) async {
      await tester.pumpWidget(
        _app(
          const PermissionOnboardingHost(callsEnabled: true, child: Text('shell')),
          [devicePermissionsProvider.overrideWithValue(FakeDevicePermissions(supported: false))],
        ),
      );
      expect(find.text('shell'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('settings section: statuses, battery request, vendor help', (tester) async {
      final p = FakeDevicePermissions(notificationState: GrantState.granted);
      await tester.pumpWidget(
        _app(
          const Scaffold(body: SingleChildScrollView(child: DevicePermissionsSection(pushReady: false))),
          [
            devicePermissionsProvider.overrideWithValue(p),
            callsEnabledProvider.overrideWithValue(true),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizationsRu();
      expect(find.text(l10n.notifDeviceGranted), findsOneWidget);
      expect(find.text(l10n.notifDeviceFullScreenOff), findsOneWidget);
      expect(find.textContaining(l10n.notifDeviceBatteryNoPush), findsOneWidget);

      await tester.tap(find.byKey(const Key('notif_device_battery')));
      await tester.pumpAndSettle();
      expect(p.calls, ['battery']);
      expect(find.text(l10n.notifDeviceBatteryOn), findsOneWidget);
      expect(find.textContaining(l10n.notifDeviceBatteryNoPush), findsNothing);

      await tester.tap(find.byKey(const Key('notif_device_fullscreen')));
      await tester.pumpAndSettle();
      expect(p.calls, ['battery', 'fullScreen']);

      await tester.tap(find.byKey(const Key('notif_device_help')));
      await tester.pumpAndSettle();
      expect(find.byType(BackgroundHelpScreen), findsOneWidget);
      expect(find.text(l10n.bgHelpXiaomiTitle), findsOneWidget);
    });

    testWidgets('settings section hidden where unsupported', (tester) async {
      await tester.pumpWidget(
        _app(
          const Scaffold(body: DevicePermissionsSection(pushReady: true)),
          [devicePermissionsProvider.overrideWithValue(FakeDevicePermissions(supported: false))],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('notif_device_battery')), findsNothing);
    });
  });
}
