import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/api/app_env.dart';
import 'package:xatbox_mobile/core/auth/auth_session.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/deep_links.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/shared/utils/api_date.dart';
import 'package:xatbox_mobile/shared/utils/diagnostic_log.dart';
import 'package:xatbox_mobile/shared/utils/email_address.dart';
import 'package:xatbox_mobile/shared/utils/html_sanitizer.dart';

void main() {
  group('DiagnosticLog.redact', () {
    const token = 'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789_-AbCdE';
    test('strips bearer tokens, cookies and 43-char opaque tokens', () {
      expect(
        DiagnosticLog.redact('Authorization: Bearer $token'),
        isNot(contains(token)),
      );
      expect(
        DiagnosticLog.redact('mp_session=$token; Path=/'),
        isNot(contains(token)),
      );
      expect(
        DiagnosticLog.redact('{"token":"$token","user":{}}'),
        isNot(contains(token)),
      );
      expect(
        DiagnosticLog.redact('{"password":"hunter2"}'),
        isNot(contains('hunter2')),
      );
      expect(DiagnosticLog.redact('got $token back'), isNot(contains(token)));
    });
    test('keeps ordinary text', () {
      expect(
        DiagnosticLog.redact('GET /mail/messages -> 200 12ms'),
        'GET /mail/messages -> 200 12ms',
      );
    });
  });

  group('AppEnv', () {
    test('dev falls back to localhost', () {
      final env = AppEnv.fromValues(flavorName: 'dev', apiBaseUrl: '');
      expect(env.apiBaseUrl, 'http://localhost:8080/api/v1');
    });
    test('prod requires an https URL', () {
      expect(
        () => AppEnv.fromValues(flavorName: 'prod', apiBaseUrl: ''),
        throwsA(isA<AppEnvError>()),
      );
      expect(
        () => AppEnv.fromValues(
          flavorName: 'prod',
          apiBaseUrl: 'http://x/api/v1',
        ),
        throwsA(isA<AppEnvError>()),
      );
      expect(
        AppEnv.fromValues(
          flavorName: 'prod',
          apiBaseUrl: 'https://x/api/v1',
        ).isProd,
        isTrue,
      );
    });
    test('unknown flavor is rejected', () {
      expect(
        () => AppEnv.fromValues(flavorName: 'qa', apiBaseUrl: ''),
        throwsA(isA<AppEnvError>()),
      );
    });
  });

  group('authRedirect', () {
    test('unknown/unreachable → splash', () {
      expect(authRedirect(AuthStatus.unknown, Routes.mail), Routes.splash);
      expect(authRedirect(AuthStatus.unreachable, Routes.login), Routes.splash);
      expect(authRedirect(AuthStatus.unknown, Routes.splash), isNull);
    });
    test('unauthenticated → login from anywhere', () {
      expect(
        authRedirect(AuthStatus.unauthenticated, Routes.mail),
        Routes.login,
      );
      expect(
        authRedirect(AuthStatus.unauthenticated, '/mail/message/abc'),
        Routes.login,
      );
      expect(authRedirect(AuthStatus.unauthenticated, Routes.login), isNull);
    });
    test('authenticated leaves splash/login, keeps deep routes', () {
      expect(
        authRedirect(AuthStatus.authenticated, Routes.splash),
        Routes.mail,
      );
      expect(authRedirect(AuthStatus.authenticated, Routes.login), Routes.mail);
      expect(
        authRedirect(AuthStatus.authenticated, '/mail/message/abc'),
        isNull,
      );
      expect(authRedirect(AuthStatus.authenticated, Routes.chat), isNull);
    });
  });

  group('DeepLinks', () {
    test('maps the ТЗ scheme to routes', () {
      expect(
        DeepLinks.toRoute(Uri.parse('xatbox://mail/abc%20d')),
        '/mail/message/abc%20d',
      );
      expect(
        DeepLinks.toRoute(Uri.parse('xatbox://chat/c1/message/m1')),
        '/chat/c/c1',
      );
      expect(
        DeepLinks.toRoute(Uri.parse('xatbox://call/x')),
        Routes.callDetailsPath('x'),
      );
      expect(DeepLinks.toRoute(Uri.parse('xatbox://call')), Routes.calls);
      expect(DeepLinks.toRoute(Uri.parse('https://evil/mail/1')), isNull);
    });
  });

  group('parseApiDate', () {
    test('RFC 3339', () {
      expect(
        parseApiDate('2026-08-20T08:49:50Z')!.toUtc(),
        DateTime.utc(2026, 8, 20, 8, 49, 50),
      );
    });
    test('PostgreSQL text form', () {
      final d = parseApiDate('2026-08-20 08:49:50.801968+00')!.toUtc();
      expect(d, DateTime.utc(2026, 8, 20, 8, 49, 50, 801, 968));
      expect(
        parseApiDate('2026-09-14 10:21:33.123456+05')!.toUtc(),
        DateTime.utc(2026, 9, 14, 5, 21, 33, 123, 456),
      );
    });
    test('garbage → null', () {
      expect(parseApiDate(''), isNull);
      expect(parseApiDate('yesterday'), isNull);
    });
  });

  group('EmailAddress', () {
    test('accepts bare addresses only', () {
      expect(EmailAddress.isBare('a.b@example.kz'), isTrue);
      expect(EmailAddress.isBare('Name <a@b.kz>'), isFalse);
      expect(EmailAddress.isBare('a@b'), isFalse);
    });
    test('split/dedupe normalise', () {
      expect(EmailAddress.split('A@b.kz, c@d.kz; e@f.kz\n'), [
        'a@b.kz',
        'c@d.kz',
        'e@f.kz',
      ]);
      expect(EmailAddress.dedupe(['A@b.kz', 'a@B.kz', 'c@d.kz']), [
        'a@b.kz',
        'c@d.kz',
      ]);
      expect(EmailAddress.firstInvalid(['a@b.kz', 'bad']), 'bad');
    });
  });

  group('HtmlSanitizer', () {
    test('drops scripts, event handlers, remote images and js: links', () {
      const html =
          '<div onclick="x()"><script>alert(1)</script><p>Hi <b>there</b></p>'
          '<img src="https://t.example/pixel.gif" alt="pix"><a href="javascript:evil()">l</a>'
          '<a href="https://ok.example/">ok</a><style>p{}</style><iframe src="https://x"></iframe></div>';
      final out = HtmlSanitizer.sanitize(html);
      expect(out.html, isNot(contains('<script')));
      expect(out.html, isNot(contains('onclick')));
      expect(out.html, isNot(contains('pixel.gif')));
      expect(out.html, isNot(contains('javascript:')));
      expect(out.html, isNot(contains('<iframe')));
      expect(out.html, contains('<b>there</b>'));
      expect(out.html, contains('href="https://ok.example/"'));
      expect(out.blockedRemoteContent, isTrue);
    });
    test('the letter view keeps the pictures the sender linked', () {
      const html = '<p>Hi</p><img src="https://cdn.example/logo.png" alt="logo">'
          '<img src="data:image/png;base64,AAAA"><img src="cid:part1"><img src="javascript:x()">'
          '<img src="https://t.example/p.gif" onerror="x()">';
      final out = HtmlSanitizer.sanitize(html, remoteImages: true);
      expect(out.html, contains('src="https://cdn.example/logo.png"'));
      expect(out.html, contains('src="data:image/png;base64,AAAA"'));
      expect(out.html, isNot(contains('cid:')));
      expect(out.html, isNot(contains('javascript:')));
      expect(out.html, isNot(contains('onerror')));
      // Only the unresolvable ones count as blocked.
      expect(out.blockedRemoteContent, isTrue);
      expect(HtmlSanitizer.sanitize('<img src="https://a.example/x.png">', remoteImages: true).blockedRemoteContent, isFalse);
    });
    test('plain text keeps line structure', () {
      expect(HtmlSanitizer.toPlainText('<p>a</p><p>b<br>c</p>'), 'a\nb\nc');
    });
  });
}
