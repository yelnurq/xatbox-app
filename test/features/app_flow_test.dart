import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/shared/widgets/glass_tab_bar.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/auth/auth_session.dart';
import 'package:xatbox_mobile/features/auth/login_screen.dart';
import 'package:xatbox_mobile/features/auth/splash_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_list_screen.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_home_screen.dart';
import 'package:xatbox_mobile/features/mail/presentation/message_detail_screen.dart';
import 'package:xatbox_mobile/features/mail/presentation/message_tile.dart';

import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// End-to-end widget flow through the real router: splash → mail list →
/// pagination → detail → tabs → badge → 401 → login.
void main() {
  late TestHarness h;
  tearDown(() => h.dispose());

  Future<void> pumpApp(WidgetTester tester) async {
    // Deterministic Russian UI regardless of the host machine locale.
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

  /// Advances time in small steps (spinners never "settle").
  Future<void> settle(WidgetTester tester, [int steps = 10]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('no stored token → login screen', (tester) async {
    h = await TestHarness.create();
    await pumpApp(tester);
    await settle(tester);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets(
    'stored token → splash verifies /me → mail list with badge; tabs keep state; 401 → login',
    (tester) async {
      h = await TestHarness.create(storedToken: Fixtures.token);
      h.adapter.onJson('GET', '/me', Fixtures.me());
      h.adapter.onJson(
        'GET',
        '/mail/summary',
        Fixtures.summary(inboxUnread: 3, smartUnread: 2),
      );
      h.adapter.on('GET', '/mail/messages', (r) {
        final offset = int.parse(r.query['offset'] as String);
        return FakeResponse(
          200,
          json: offset == 0
              ? Fixtures.page(Fixtures.messages(50), total: 60, offset: 0)
              : Fixtures.page(
                  Fixtures.messages(10, from: 51),
                  total: 60,
                  offset: 50,
                ),
        );
      });
      h.adapter.onJson(
        'GET',
        '/mail/messages/m1',
        Fixtures.detail(attachments: [Fixtures.attachment()]),
      );

      await pumpApp(tester);
      await settle(tester);

      // Mail list visible with rows from page 1.
      expect(find.byType(MailHomeScreen), findsOneWidget);
      expect(find.text('Тема письма 1'), findsOneWidget);
      expect(h.adapter.of('GET', '/mail/messages'), hasLength(1));

      // Badge on the Mail tab = inbox unread + smart folder unread.
      expect(
        find.descendant(
          of: find.byType(GlassTabBar),
          matching: find.text('5'),
        ),
        findsOneWidget,
      );

      // Pagination: scroll to the end loads page 2.
      await tester.drag(find.byType(ListView).first, const Offset(0, -20000));
      await settle(tester);
      expect(
        h.adapter.of('GET', '/mail/messages').length,
        greaterThanOrEqualTo(2),
      );
      expect(h.adapter.of('GET', '/mail/messages')[1].query['offset'], '50');

      // Open a message: detail loads, attachment is listed but NOT downloaded.
      await tester.drag(find.byType(ListView).first, const Offset(0, 20000));
      await settle(tester);
      await tester.tap(find.widgetWithText(MessageTile, 'Тема письма 1'));
      await settle(tester);
      expect(find.byType(MessageDetailScreen), findsOneWidget);
      expect(find.text('Привет!\nЭто тестовое письмо.'), findsOneWidget);
      expect(find.text('report.docx'), findsOneWidget);
      expect(
        h.adapter.of('GET', '/mail/blob/blob1'),
        isEmpty,
        reason: 'no automatic download',
      );
      expect(h.adapter.of('GET', '/mail/blob/blob1/pdf'), isEmpty);

      // Back to the list.
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.byType(MailHomeScreen), findsOneWidget);

      // Switch to Chat and back: list state is preserved (no reload).
      final listCallsBefore = h.adapter.of('GET', '/mail/messages').length;
      await tester.tap(
        find.descendant(
          of: find.byType(GlassTabBar),
          matching: find.text('Чат'),
        ),
      );
      await settle(tester);
      expect(find.byType(ChatListScreen), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(GlassTabBar),
          matching: find.text('Почта'),
        ),
      );
      await settle(tester);
      expect(find.byType(MailHomeScreen), findsOneWidget);
      expect(find.text('Тема письма 1'), findsOneWidget);
      expect(h.adapter.of('GET', '/mail/messages').length, listCallsBefore);

      // Session dies: any mail endpoint answers 401 UNAUTHENTICATED → login.
      h.adapter.onError('GET', '/mail/messages', 401, 'UNAUTHENTICATED');
      await tester.drag(find.byType(ListView).first, const Offset(0, 400));
      await settle(tester, 20);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Сессия истекла. Войдите снова.'), findsOneWidget);
      expect(await h.tokens.read(), isNull);
      expect(h.session.status, AuthStatus.unauthenticated);
    },
  );

  testWidgets(
    'user without mail.read sees a permission notice and no compose button',
    (tester) async {
      h = await TestHarness.create(storedToken: Fixtures.token);
      h.adapter.onJson(
        'GET',
        '/me',
        Fixtures.me(permissions: const ['messages.send']),
      );
      await pumpApp(tester);
      await settle(tester);
      expect(find.text('У вас нет доступа к почте.'), findsOneWidget);
      expect(find.byKey(const Key('compose_fab')), findsNothing);
      expect(h.adapter.of('GET', '/mail/messages'), isEmpty);
    },
  );

  testWidgets('empty folder and error states render', (tester) async {
    h = await TestHarness.create(storedToken: Fixtures.token);
    h.adapter.onJson('GET', '/me', Fixtures.me());
    h.adapter.onJson('GET', '/mail/summary', Fixtures.summary());
    h.adapter.onQueue('GET', '/mail/messages', [
      FakeResponse.error(503, 'MAIL_SERVICE_UNAVAILABLE'),
      FakeResponse(200, json: Fixtures.page(const [], total: 0)),
    ]);
    await pumpApp(tester);
    await settle(tester);
    expect(find.text('Почтовый сервис временно недоступен.'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await settle(tester);
    expect(find.text('В этой папке нет писем'), findsOneWidget);
  });
}
