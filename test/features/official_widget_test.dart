import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/features/official/presentation/official_detail_screen.dart';
import 'package:xatbox_mobile/features/official/presentation/official_list_screen.dart';
import 'package:xatbox_mobile/features/official/presentation/official_providers.dart';

import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

Map<String, dynamic> _message(
  String id,
  String title, {
  bool ack = false,
  bool read = false,
}) => {
  'id': id,
  'sender_name': 'Директор',
  'sender_role': 'org_admin',
  'title': title,
  'body': 'Текст $title',
  'requires_acknowledgement': ack,
  'created_at': '2026-09-14 09:00:00+00',
  if (read) 'read_at': '2026-09-14 10:00:00+00',
};

/// Official messages: list → detail (marks read) → «Ознакомлен(а)»; the
/// create button follows the send permissions.
void main() {
  late TestHarness h;
  tearDown(() => h.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 12]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> start(WidgetTester tester, List<String> permissions) async {
    tester.platformDispatcher.localeTestValue = const Locale('ru');
    tester.platformDispatcher.localesTestValue = const [Locale('ru')];
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    h = await TestHarness.create(storedToken: Fixtures.token);
    h.stubSignedIn();
    h.adapter.onJson('GET', '/me', Fixtures.me(permissions: permissions));
    h.adapter.onJson('GET', '/notifications', {
      'notifications': <Object>[],
      'unread': 0,
    });
    h.adapter.onJson('GET', '/official', {
      'messages': [
        _message('o1', 'Приказ о дежурстве', ack: true),
        _message('o2', 'Старое объявление', read: true),
      ],
    });
    h.adapter.onPattern(
      'POST',
      r'^/official/[^/]+/(read|acknowledge)$',
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
    h.container.read(appRouterProvider).push(Routes.official);
    await settle(tester);
  }

  testWidgets('list → detail marks read → acknowledge shows confirmation', (
    tester,
  ) async {
    await start(tester, ['mail.read', 'official.read']);

    expect(find.byType(OfficialListScreen), findsOneWidget);
    expect(find.text('Приказ о дежурстве'), findsOneWidget);
    expect(find.text('Старое объявление'), findsOneWidget);
    expect(find.byKey(const Key('official_unread_dot')), findsOneWidget);
    expect(find.byKey(const Key('official_ack_chip_required')), findsOneWidget);
    expect(h.container.read(officialUnreadBadgeProvider), 1);
    // No send permission: no create button, no «Отправленные» tab.
    expect(find.byKey(const Key('official_create')), findsNothing);
    expect(find.byKey(const Key('official_tab_sent')), findsNothing);

    await tester.tap(find.text('Приказ о дежурстве'));
    await settle(tester);
    expect(find.byType(OfficialDetailScreen), findsOneWidget);
    expect(find.text('Текст Приказ о дежурстве'), findsOneWidget);
    expect(h.adapter.of('POST', '/official/o1/read'), hasLength(1));
    expect(h.container.read(officialUnreadBadgeProvider), 0);

    await tester.tap(find.byKey(const Key('official_ack_button')));
    await settle(tester);
    expect(h.adapter.of('POST', '/official/o1/acknowledge'), hasLength(1));
    expect(find.byKey(const Key('official_ack_button')), findsNothing);
    expect(find.byKey(const Key('official_ack_done')), findsOneWidget);
    expect(
      h.container.read(officialProvider).byId('o1')!.isAcknowledged,
      isTrue,
    );
  });

  testWidgets('create button only with a send permission', (tester) async {
    await start(tester, [
      'mail.read',
      'official.read',
      'official.send.department',
    ]);
    expect(find.byKey(const Key('official_create')), findsOneWidget);
    expect(find.byKey(const Key('official_tab_sent')), findsOneWidget);
  });

  testWidgets('without official.read nothing is loaded', (tester) async {
    await start(tester, ['mail.read']);
    expect(find.byKey(const Key('official_list')), findsNothing);
    expect(find.byKey(const Key('official_create')), findsNothing);
    expect(h.adapter.of('GET', '/official'), isEmpty);
    expect(h.container.read(officialUnreadBadgeProvider), 0);
  });
}
