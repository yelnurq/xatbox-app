import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/preferences/app_preferences.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/core/security/app_lock.dart';
import 'package:xatbox_mobile/features/auth/login_screen.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_home_screen.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Large system font (ТЗ п.24.22): key screens render at 200 % text scale on
/// a small phone without layout overflow, and tap targets carry labels.
void main() {
  late TestHarness h;
  tearDown(() => h.dispose());

  Future<void> pumpPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.localeTestValue = const Locale('ru');
    tester.platformDispatcher.localesTestValue = const [Locale('ru')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: const XatBoxApp(),
      ),
    );
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('login screen at 200 %', (tester) async {
    h = await TestHarness.create();
    final semantics = tester.ensureSemantics();
    await pumpPhone(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('mail list and settings at 200 %', (tester) async {
    h = await TestHarness.create(storedToken: Fixtures.token);
    h.stubSignedIn();
    await pumpPhone(tester);
    expect(find.byType(MailHomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    h.container.read(appRouterProvider).push(Routes.settings);
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lock screen at 200 % with labelled keys', (tester) async {
    h = await TestHarness.create(
      storedToken: Fixtures.token,
      overrides: [
        initialAppPreferencesProvider.overrideWithValue(
          const AppPreferences(lockEnabled: true, biometricEnabled: true),
        ),
      ],
    );
    h.stubSignedIn();
    h.biometrics.succeed = false;
    await h.container.read(pinVaultProvider).setPin('123456');
    final semantics = tester.ensureSemantics();
    await pumpPhone(tester);
    expect(find.byKey(const Key('lock_screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });
}
