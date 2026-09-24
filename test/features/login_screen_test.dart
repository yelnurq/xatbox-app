import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/auth/auth_session.dart';
import 'package:xatbox_mobile/features/auth/login_screen.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

void main() {
  late TestHarness h;
  tearDown(() => h.dispose());

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWidget(const LoginScreen(), container: h.container),
    );
    await tester.pump();
  }

  Future<void> submit(
    WidgetTester tester, {
    String email = 'user@example.kz',
    String password = 'pw',
  }) async {
    await tester.enterText(find.byKey(const Key('login_email')), email);
    await tester.enterText(find.byKey(const Key('login_password')), password);
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('empty fields show validation messages, no request is made', (
    tester,
  ) async {
    h = await TestHarness.create();
    await pumpLogin(tester);
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();
    expect(find.text('Введите email'), findsOneWidget);
    expect(find.text('Введите пароль'), findsOneWidget);
    expect(h.adapter.requests, isEmpty);
  });

  testWidgets('wrong password shows a human message, not the raw code', (
    tester,
  ) async {
    h = await TestHarness.create();
    h.adapter.onError('POST', '/auth/login', 401, 'INVALID_CREDENTIALS');
    await pumpLogin(tester);
    await submit(tester, password: 'wrong');
    expect(find.text('Неверный email или пароль.'), findsOneWidget);
    expect(find.textContaining('INVALID_CREDENTIALS'), findsNothing);
    expect(h.session.status, isNot(AuthStatus.authenticated));
  });

  testWidgets(
    'TOO_MANY_ATTEMPTS shows a neutral message and the button re-enables',
    (tester) async {
      h = await TestHarness.create();
      h.adapter.onError('POST', '/auth/login', 429, 'TOO_MANY_ATTEMPTS');
      await pumpLogin(tester);
      await submit(tester);
      expect(
        find.text('Слишком много попыток входа. Попробуйте позже.'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('login_submit')),
      );
      expect(button.onPressed, isNotNull);
      expect(h.adapter.of('POST', '/auth/login'), hasLength(1));
    },
  );

  testWidgets('every documented login error code maps to its own text', (
    tester,
  ) async {
    h = await TestHarness.create();
    const cases = {
      'INVALID_CREDENTIALS_FORMAT': 'Введите email и пароль.',
      'USER_DISABLED': 'Учётная запись отключена. Обратитесь к администратору.',
      'ORGANIZATION_SUSPENDED':
          'Подписка организации приостановлена. Обратитесь к администратору.',
      'DIRECTORY_DISABLED': 'Вход через корпоративный каталог отключён. Обратитесь к администратору.',
      'DIRECTORY_UNAVAILABLE':
          'Корпоративный каталог недоступен. Попробуйте позже.',
      'SUBSCRIPTION_LIMIT': 'Достигнут лимит пользователей организации. Обратитесь к администратору.',
      'INTERNAL': 'Ошибка сервера. Попробуйте позже.',
    };
    await pumpLogin(tester);
    for (final entry in cases.entries) {
      h.adapter.onError('POST', '/auth/login', 400, entry.key);
      await submit(tester);
      expect(find.text(entry.value), findsOneWidget, reason: entry.key);
    }
  });

  testWidgets('offline shows the network message', (tester) async {
    h = await TestHarness.create();
    h.adapter.onOffline('POST', '/auth/login');
    await pumpLogin(tester);
    await submit(tester);
    expect(
      find.text(
        'Нет соединения с сервером. Проверьте подключение к интернету.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'successful login stores the token and marks the session authenticated',
    (tester) async {
      h = await TestHarness.create();
      h.adapter.onJson('POST', '/auth/login', Fixtures.loginResponse());
      h.adapter.onJson('GET', '/me', Fixtures.me());
      await pumpLogin(tester);
      await submit(tester);
      expect(h.session.status, AuthStatus.authenticated);
      expect(await h.tokens.read(), Fixtures.token);
    },
  );
}
