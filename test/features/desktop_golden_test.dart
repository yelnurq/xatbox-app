import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/platform/desktop.dart';
import 'package:xatbox_mobile/core/platform/desktop_layout.dart';
import 'package:xatbox_mobile/core/preferences/app_preferences.dart';
import 'package:xatbox_mobile/core/theme/skins.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/mail/presentation/compose_screen.dart';

import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// What the desktop window looks like.
///
/// The functional desktop tests say that the pieces work; these say that
/// they are still where the web client puts them — the sidebar and its
/// width, the header and the order of its buttons, the list beside the
/// reading pane, the floating composer. A layout that slips sideways breaks
/// no assertion and fails no click, which is exactly why it needs a picture.
///
/// Re-bless with `flutter test --update-goldens test/features/desktop_golden_test.dart`
/// after a deliberate change, and look at the diff in
/// `test/features/goldens/` before committing it.
///
/// The fixtures are dated 2024 on purpose: a message from an earlier year
/// is written as a full date, so these pictures do not change when the year
/// does.
void main() {
  Future<void> settle(WidgetTester tester, [int steps = 14]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  List<Map<String, dynamic>> messages() => [
    for (var i = 1; i <= 6; i++)
      {...Fixtures.message(i, read: i > 2), 'date': '2024-03-0${i}T08:00:00Z'},
  ];

  Future<TestHarness> launch(
    WidgetTester tester, {
    AppSkin skin = AppSkin.defaultSkin,
    AppThemePreference theme = AppThemePreference.light,
  }) async {
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
        // Skin and theme are both chosen outright. One skin is one theme:
        // only «Стандартная» follows the light/dark preference, every other
        // skin commits to its own brightness, so a picture meant to be dark
        // has to say which skin it is asking.
        initialAppPreferencesProvider.overrideWithValue(
          AppPreferences(skin: skin, theme: theme),
        ),
      ],
    );
    addTearDown(h.dispose);
    h.stubSignedIn(messages: messages(), total: 6);
    h.adapter.onPattern(
      'GET',
      r'^/mail/messages/m\d+$',
      (req) => FakeResponse(
        200,
        json: {
          ...Fixtures.detail(id: req.path.split('/').last),
          'date': '2024-03-01T08:00:00Z',
        },
      ),
    );
    h.adapter.onJson('GET', '/me/sessions', {'sessions': <Object>[]});
    h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats([]));
    h.chatAdapter.onPattern(
      'POST',
      r'^/push/devices$',
      (_) => const FakeResponse(204),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: const XatBoxApp(),
      ),
    );
    await settle(tester);
    return h;
  }

  /// Stops the messenger's socket (its ping timer) before the test ends.
  Future<void> finish(WidgetTester tester, TestHarness h) async {
    unawaited(h.container.read(chatRepositoryProvider).stop());
    await tester.pump(const Duration(seconds: 10));
  }

  testWidgets('mail: sidebar, header, list and reading pane', (tester) async {
    final h = await launch(tester);
    await tester.tap(find.text('Тема письма 1'));
    await settle(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/desktop_mail_kok.png'),
    );
    await finish(tester, h);
  });

  testWidgets('mail in the standard skin, light', (tester) async {
    final h = await launch(tester, skin: AppSkin.standard);
    await tester.tap(find.text('Тема письма 1'));
    await settle(tester);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/desktop_mail_light.png'),
    );
    await finish(tester, h);
  });

  testWidgets('mail in the standard skin, dark', (tester) async {
    final h = await launch(
      tester,
      skin: AppSkin.standard,
      theme: AppThemePreference.dark,
    );
    await tester.tap(find.text('Тема письма 1'));
    await settle(tester);
    // Without this the dark picture could quietly be a copy of the light
    // one, and a golden that never differs guards nothing.
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/desktop_mail_dark.png'),
    );
    await finish(tester, h);
  });

  testWidgets('the composer floats over the mail window', (tester) async {
    final h = await launch(tester);
    await tester.tap(find.byKey(const Key('compose_button')));
    await settle(tester);
    expect(find.byType(ComposeScreen), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/desktop_compose.png'),
    );
    await finish(tester, h);
  });
}
