import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/features/mail/presentation/message_detail_screen.dart';
import 'package:xatbox_mobile/features/notifications/presentation/notifications_providers.dart';
import 'package:xatbox_mobile/features/notifications/presentation/notifications_screen.dart';

import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/notification_fixtures.dart';
import '../helpers/test_app.dart';

/// Notifications screen: tap marks read and navigates by target_url;
/// «Прочитать все» clears the bell badge.
void main() {
  late TestHarness h;
  tearDown(() => h.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 12]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'tap marks the notification read and opens its target; no target → stays',
    (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('ru');
      tester.platformDispatcher.localesTestValue = const [Locale('ru')];
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      h = await TestHarness.create(storedToken: Fixtures.token);
      h.stubSignedIn();
      h.adapter.onJson('GET', '/mail/messages/m1', Fixtures.detail());
      h.adapter.onJson(
        'GET',
        '/notifications',
        NotificationFixtures.of([
          NotificationFixtures.item(
            id: 'n1',
            kind: 'official',
            title: 'Новое письмо',
            targetUrl: '/mail/message/m1',
          ),
          NotificationFixtures.item(
            id: 'n2',
            kind: 'assigned_task',
            title: 'Задача назначена',
            targetUrl: '/mail/my-list',
          ),
          NotificationFixtures.item(id: 'n3', title: 'Старое', read: true),
        ]),
      );
      h.adapter.onPattern(
        'POST',
        r'^/notifications/[^/]+/read$',
        (_) => const FakeResponse(204),
      );

      await tester.runAsync(() => h.session.restore());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const XatBoxApp(),
        ),
      );
      await settle(tester);
      h.container.read(appRouterProvider).push(Routes.notifications);
      await settle(tester);

      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.text('Новое письмо'), findsOneWidget);
      expect(find.text('Старое'), findsOneWidget);
      expect(find.byKey(const Key('notification_unread_dot')), findsNWidgets(2));

      // Tasks page without tasks.manage.self: marked read, no navigation.
      await tester.tap(find.text('Задача назначена'));
      await settle(tester);
      expect(h.adapter.of('POST', '/notifications/n2/read'), hasLength(1));
      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.byKey(const Key('notification_unread_dot')), findsOneWidget);

      await tester.tap(find.text('Новое письмо'));
      await settle(tester);
      expect(h.adapter.of('POST', '/notifications/n1/read'), hasLength(1));
      expect(find.byType(MessageDetailScreen), findsOneWidget);
      expect(h.container.read(notificationsUnreadBadgeProvider), 0);
    },
  );

  testWidgets('«Прочитать все» clears the bell badge', (tester) async {
    h = await TestHarness.create(storedToken: Fixtures.token);
    h.adapter.onJson('GET', '/me', Fixtures.me());
    h.adapter.onJson(
      'GET',
      '/notifications',
      NotificationFixtures.list(4, unread: 2),
    );
    h.adapter.onJson('POST', '/notifications/read-all', null, status: 204);
    await tester.runAsync(() => h.session.restore());

    await tester.pumpWidget(
      wrapWidget(
        Scaffold(
          appBar: AppBar(actions: const [NotificationsBellButton()]),
          body: const NotificationsScreen(),
        ),
        container: h.container,
      ),
    );
    await settle(tester);
    final bellBadge = find.descendant(
      of: find.byKey(const Key('notifications_bell')),
      matching: find.text('2'),
    );
    expect(bellBadge, findsOneWidget);
    expect(find.text('Уведомление 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('notifications_read_all')));
    await settle(tester);
    expect(h.adapter.of('POST', '/notifications/read-all'), hasLength(1));
    expect(bellBadge, findsNothing);
    expect(h.container.read(notificationsUnreadBadgeProvider), 0);
    expect(find.byKey(const Key('notifications_read_all')), findsNothing);
    expect(find.byKey(const Key('notification_unread_dot')), findsNothing);
  });
}
