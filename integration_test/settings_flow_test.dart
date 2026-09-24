import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/preferences/app_preferences.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/core/theme/skins.dart';
import 'package:xatbox_mobile/features/settings/appearance_screen.dart';
import 'package:xatbox_mobile/features/settings/settings_screen.dart';

import '../test/helpers/fixtures.dart';
import 'support/e2e_app.dart';

/// E2E: settings → appearance → pick another skin; the app theme changes and
/// the choice is persisted.
void main() {
  ensureE2EBinding();

  testWidgets('settings: appearance skin change applies and persists', (tester) async {
    useRussian(tester);
    final e2e = await E2E.create(storedToken: Fixtures.token, chat: false, withCalls: false);
    addTearDown(e2e.h.dispose);
    final h = e2e.h;
    h.stubSignedIn();
    await tester.runAsync(() => h.session.restore());
    await pumpE2EApp(tester, e2e);

    h.container.read(appRouterProvider).push(Routes.settings);
    await settle(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);

    final before = h.container.read(appPreferencesProvider).skin;
    const target = AppSkin.steppe;
    expect(before, isNot(target));
    final primaryBefore = Theme.of(tester.element(find.byType(SettingsScreen))).colorScheme.primary;

    await tester.tap(find.byKey(const Key('settings_style')));
    await settle(tester);
    expect(find.byType(AppearanceScreen), findsOneWidget);

    final tile = find.byKey(Key('skin_${target.name}'));
    await tester.scrollUntilVisible(tile, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(tile);
    await settle(tester);

    expect(h.container.read(appPreferencesProvider).skin, target);
    expect(find.text('Стиль применён'), findsOneWidget);
    final primaryAfter = Theme.of(tester.element(find.byType(AppearanceScreen))).colorScheme.primary;
    expect(primaryAfter, isNot(primaryBefore), reason: 'the app theme follows the skin');

    final stored = await tester.runAsync(() => h.container.read(appPreferencesStoreProvider).read());
    expect(stored!.skin, target);
    expect(tester.takeException(), isNull);

    await finishE2E(tester, e2e);
  });
}
