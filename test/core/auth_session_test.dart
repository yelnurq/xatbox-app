import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/api/api_exception.dart';
import 'package:xatbox_mobile/core/auth/auth_providers.dart';
import 'package:xatbox_mobile/core/auth/auth_session.dart';
import 'package:xatbox_mobile/features/mail/data/mail_models.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_providers.dart';
import 'package:xatbox_mobile/shared/models/auth_user.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

void main() {
  late TestHarness h;

  tearDown(() => h.dispose());

  group('login', () {
    test(
      'stores the token in secure storage and exposes permissions',
      () async {
        h = await TestHarness.create();
        h.adapter.onJson('POST', '/auth/login', Fixtures.loginResponse());
        h.adapter.onJson('GET', '/me', Fixtures.me());

        await h.session.login(email: '  User@Example.kz ', password: 'secret');

        expect(h.session.status, AuthStatus.authenticated);
        expect(await h.tokens.read(), Fixtures.token);
        expect(h.session.hasPermission('mail.send'), isTrue);
        final body = h.adapter.of('POST', '/auth/login').single.json;
        expect(body.keys.toSet(), {
          'email',
          'password',
        }, reason: 'only documented fields');
        expect(body['email'], 'User@Example.kz');
      },
    );

    test(
      'INVALID_CREDENTIALS surfaces as ApiException and stores nothing',
      () async {
        h = await TestHarness.create();
        h.adapter.onError('POST', '/auth/login', 401, 'INVALID_CREDENTIALS');
        await expectLater(
          h.session.login(email: 'a@b.c', password: 'bad'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              'INVALID_CREDENTIALS',
            ),
          ),
        );
        expect(h.session.status, AuthStatus.unknown);
        expect(await h.tokens.read(), isNull);
      },
    );

    test(
      'TOO_MANY_ATTEMPTS (429, no Retry-After) does not crash or loop',
      () async {
        h = await TestHarness.create();
        h.adapter.onError('POST', '/auth/login', 429, 'TOO_MANY_ATTEMPTS');
        await expectLater(
          h.session.login(email: 'a@b.c', password: 'x'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              'TOO_MANY_ATTEMPTS',
            ),
          ),
        );
        expect(
          h.adapter.of('POST', '/auth/login').length,
          1,
          reason: 'no automatic retry',
        );
      },
    );

    test('network failure surfaces as NetworkException', () async {
      h = await TestHarness.create();
      h.adapter.onOffline('POST', '/auth/login');
      await expectLater(
        h.session.login(email: 'a@b.c', password: 'x'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('restore (splash)', () {
    test('no token → unauthenticated without any request', () async {
      h = await TestHarness.create();
      await h.session.restore();
      expect(h.session.status, AuthStatus.unauthenticated);
      expect(h.adapter.requests, isEmpty);
    });

    test('token + GET /me 200 → authenticated (survives restart)', () async {
      h = await TestHarness.create(storedToken: Fixtures.token);
      h.adapter.onJson('GET', '/me', Fixtures.me());
      await h.session.restore();
      expect(h.session.status, AuthStatus.authenticated);
      expect(h.session.user?.departmentName, 'IT');
      expect(
        h.adapter.of('GET', '/me').single.headers['Authorization'],
        'Bearer ${Fixtures.token}',
      );
    });

    test('token + GET /me 401 → unauthenticated and token wiped', () async {
      h = await TestHarness.create(storedToken: Fixtures.token);
      h.adapter.onError('GET', '/me', 401, 'UNAUTHENTICATED');
      await h.session.restore();
      expect(h.session.status, AuthStatus.unauthenticated);
      expect(h.session.signOutReason, SignOutReason.sessionExpired);
      expect(await h.tokens.read(), isNull);
    });

    test(
      'token + offline + no cached profile → unreachable (retryable)',
      () async {
        h = await TestHarness.create(storedToken: Fixtures.token);
        h.adapter.onOffline('GET', '/me');
        await h.session.restore();
        expect(h.session.status, AuthStatus.unreachable);
        expect(
          await h.tokens.read(),
          Fixtures.token,
          reason: 'token kept for retry',
        );

        h.adapter.onJson('GET', '/me', Fixtures.me());
        await h.session.retryRestore();
        expect(h.session.status, AuthStatus.authenticated);
      },
    );

    test('token + offline + cached profile → authenticated offline', () async {
      h = await TestHarness.create(storedToken: Fixtures.token);
      // A previous run stored the profile snapshot (no secrets) in the DB.
      await h.container
          .read(profileCacheProvider)
          .write(AuthUser.fromJson(Fixtures.me()));
      h.adapter.onOffline('GET', '/me');
      await h.session.restore();
      expect(h.session.status, AuthStatus.authenticated);
      expect(h.session.offlineProfile, isTrue);
    });
  });

  group('logout', () {
    test(
      'calls POST /auth/logout, clears token and runs sign-out hooks',
      () async {
        h = await TestHarness.create(storedToken: Fixtures.token);
        h.adapter.onJson('GET', '/me', Fixtures.me());
        h.adapter.onJson('POST', '/auth/logout', {'status': 'ok'});
        await h.session.restore();
        var hookCalls = 0;
        h.session.addSignOutHook(() async => hookCalls++);

        await h.session.logout();

        expect(
          h.adapter.of('POST', '/auth/logout').single.headers['Authorization'],
          'Bearer ${Fixtures.token}',
        );
        expect(await h.tokens.read(), isNull);
        expect(h.session.status, AuthStatus.unauthenticated);
        expect(h.session.currentToken(), isNull);
        expect(hookCalls, 1);
      },
    );

    test('still clears local state when the server is unreachable', () async {
      h = await TestHarness.create(storedToken: Fixtures.token);
      h.adapter.onJson('GET', '/me', Fixtures.me());
      h.adapter.onOffline('POST', '/auth/logout');
      await h.session.restore();
      await h.session.logout();
      expect(await h.tokens.read(), isNull);
      expect(h.session.status, AuthStatus.unauthenticated);
    });
  });

  group('expiry from any endpoint', () {
    test('401 UNAUTHENTICATED on a mail endpoint signs the user out', () async {
      h = await TestHarness.create(storedToken: Fixtures.token);
      h.adapter.onJson('GET', '/me', Fixtures.me());
      h.adapter.onError('GET', '/mail/summary', 401, 'UNAUTHENTICATED');
      await h.session.restore();
      expect(h.session.status, AuthStatus.authenticated);

      await expectLater(
        h.container.read(mailApiProvider).summary(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.isUnauthenticated,
            'isUnauthenticated',
            true,
          ),
        ),
      );
      // expire() clears asynchronously.
      await Future<void>.delayed(Duration.zero);
      expect(h.session.status, AuthStatus.unauthenticated);
      expect(h.session.signOutReason, SignOutReason.sessionExpired);
      expect(await h.tokens.read(), isNull);
      expect(
        h.adapter.of('POST', '/auth/logout'),
        isEmpty,
        reason: 'no refresh/logout dance',
      );
    });

    test('concurrent 401s cause a single sign-out', () async {
      h = await TestHarness.create(storedToken: Fixtures.token);
      h.adapter.onJson('GET', '/me', Fixtures.me());
      h.adapter.onError('GET', '/mail/summary', 401, 'UNAUTHENTICATED');
      h.adapter.onError('GET', '/mail/messages', 401, 'UNAUTHENTICATED');
      await h.session.restore();
      var changes = 0;
      h.session.addListener(() => changes++);
      final api = h.container.read(mailApiProvider);
      await Future.wait([
        api.summary().then<Object?>((_) => null, onError: (e) => e),
        api
            .listMessages(const MailListQuery())
            .then<Object?>((_) => null, onError: (e) => e),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(h.session.status, AuthStatus.unauthenticated);
      expect(changes, 1);
    });
  });
}
