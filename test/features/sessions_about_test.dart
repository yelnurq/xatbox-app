import 'dart:typed_data';

import 'package:flutter/material.dart' hide DiagnosticLevel;
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/api/app_env.dart';
import 'package:xatbox_mobile/core/auth/auth_session.dart';
import 'package:xatbox_mobile/core/errors/error_reporter.dart';
import 'package:xatbox_mobile/core/preferences/app_preferences.dart';
import 'package:xatbox_mobile/core/security/app_lock.dart';
import 'package:xatbox_mobile/features/about/data/endpoint_status.dart';
import 'package:xatbox_mobile/features/about/data/feedback_api.dart';
import 'package:xatbox_mobile/features/about/presentation/report_problem_screen.dart';
import 'package:xatbox_mobile/features/about/presentation/shake_to_report.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/sessions/sessions_screen.dart';
import 'package:xatbox_mobile/features/sessions/sign_out_wipe.dart';
import 'package:xatbox_mobile/shared/models/profile_session.dart';
import 'package:xatbox_mobile/shared/utils/diagnostic_log.dart';

import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

const _chatUrl = 'http://chat.local/api/v1';

Map<String, dynamic> _session(
  String id, {
  bool current = false,
  String browser = '',
  String os = 'Android',
  String kind = 'mobile',
}) => {
  'id': id,
  'current': current,
  'device': {'browser': browser, 'os': os, 'kind': kind},
  'ip': '10.0.0.5',
  'created_at': '2026-09-10T08:00:00Z',
  'last_seen_at': '2026-09-15T09:00:00Z',
  'expires_at': '2026-09-17T08:00:00Z',
};

class _NoShake extends ShakeToReportSetting {
  @override
  bool build() => false;
}

Future<void> _settle(WidgetTester tester, [int steps = 10]) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('Мои устройства и сеансы', () {
    test('how sessions are labelled', () {
      final app = ProfileSession.fromJson(_session('a'));
      expect(app.isXatBoxApp, isTrue);
      final web = ProfileSession.fromJson(_session('b', browser: 'Chrome', os: 'Windows', kind: 'desktop'));
      expect(web.isXatBoxApp, isFalse);
      expect(web.platformLabel(), 'Windows');
      final unknown = ProfileSession.fromJson(_session('c', os: '', kind: 'other'));
      expect(unknown.platformLabel(), isNull);
    });

    testWidgets('current device highlighted; end one and all other sessions', (tester) async {
      final h = await TestHarness.create(storedToken: Fixtures.token);
      addTearDown(h.dispose);
      h.stubSignedIn();
      h.adapter.onJson('GET', '/me/sessions', {
        'sessions': [
          _session('s-cur', current: true),
          _session('s-web', browser: 'Chrome', os: 'Windows', kind: 'desktop'),
        ],
      });
      h.adapter.on('DELETE', '/me/sessions/s-web', (_) => const FakeResponse(204));
      h.adapter.onJson('POST', '/me/sessions/end-others', {'ended': 1});
      await tester.pumpWidget(wrapWidget(const SessionsScreen(), container: h.container));
      await _settle(tester);

      expect(find.byKey(const Key('session_s-cur')), findsOneWidget);
      expect(find.text('Приложение XatBox'), findsOneWidget);
      expect(find.text('Chrome'), findsOneWidget);
      expect(find.text('Активно сейчас'), findsOneWidget);
      expect(find.byKey(const Key('session_end_s-cur')), findsNothing, reason: 'the current session ends with «Выйти»');

      await tester.tap(find.byKey(const Key('session_end_s-web')));
      await _settle(tester);
      expect(find.text('Завершить сеанс?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('sessions_confirm')));
      await _settle(tester);
      expect(h.adapter.of('DELETE', '/me/sessions/s-web'), hasLength(1));
      expect(h.adapter.of('GET', '/me/sessions'), hasLength(2));

      await tester.tap(find.byKey(const Key('sessions_end_others')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('sessions_confirm')));
      await _settle(tester);
      expect(h.adapter.of('POST', '/me/sessions/end-others'), hasLength(1));
      expect(find.text('Завершено сессий: 1'), findsOneWidget);
    });

    test('a session ended on another device wipes this one at the next 401', () async {
      final h = await TestHarness.create(
        storedToken: Fixtures.token,
        chatBaseUrl: _chatUrl,
        overrides: [
          initialAppPreferencesProvider.overrideWithValue(const AppPreferences(lockEnabled: true)),
        ],
      );
      addTearDown(h.dispose);
      h.stubSignedIn();
      registerSignOutWipes(h.container);
      await h.session.restore();
      expect(h.session.status, AuthStatus.authenticated);
      await h.container.read(pinVaultProvider).setPin('1234');
      final cache = h.container.read(chatCacheProvider);
      await cache.setDraft('c1', 'черновик');
      expect(await cache.draft('c1'), 'черновик');

      // Revoked elsewhere: the chat service now rejects the token.
      h.chatAdapter.onError('GET', '/chats', 401, 'UNAUTHENTICATED');
      await expectLater(h.container.read(chatApiClientProvider).getJson('/chats'), throwsA(anything));
      for (var i = 0; i < 100 && h.session.status != AuthStatus.unauthenticated; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(h.session.status, AuthStatus.unauthenticated);
      expect(h.session.signOutReason, SignOutReason.sessionExpired);
      expect(await h.tokens.read(), isNull);
      expect(await cache.draft('c1'), '');
      expect(await h.container.read(pinVaultProvider).hasPin(), isFalse);
      expect(h.container.read(appPreferencesProvider).lockEnabled, isFalse);
    });
  });

  group('О приложении', () {
    test('health URLs and server probes', () async {
      expect(EndpointProber.healthUrl('https://h.kz/chat/api/v1'), 'https://h.kz/chat/health');
      expect(EndpointProber.healthUrl('http://chat.local:8090/api/v1/'), 'http://chat.local:8090/health');
      expect(EndpointProber.hostOf('http://chat.local:8090/api/v1'), 'chat.local:8090');

      final adapter = FakeHttpAdapter()
        ..on('GET', '/health', (_) => const FakeResponse(200, text: '{"status":"ok"}'))
        ..onError('GET', '/me', 401, 'UNAUTHENTICATED');
      final prober = EndpointProber(adapter: adapter);
      final env = AppEnv.fromValues(
        flavorName: 'stage',
        apiBaseUrl: 'http://mail.local/api/v1',
        chatBaseUrl: _chatUrl,
      );
      final list = await prober.probeAll(env);
      final mail = list.firstWhere((s) => s.kind == ServiceKind.mail);
      final chat = list.firstWhere((s) => s.kind == ServiceKind.chat);
      final calls = list.firstWhere((s) => s.kind == ServiceKind.calls);
      expect(mail.reachable, isTrue);
      expect(mail.statusCode, 401);
      expect(mail.latency, isNotNull);
      expect(adapter.of('GET', '/me').single.headers['Authorization'], isNull);
      expect(chat.reachable, isTrue);
      expect(chat.degraded, isFalse);
      expect(calls.configured, isFalse);

      adapter.onOffline('GET', '/health');
      expect((await prober.probe(ServiceKind.chat, _chatUrl)).reachable, isFalse);
      adapter.on('GET', '/health', (_) => const FakeResponse(503, text: 'down'));
      expect((await prober.probe(ServiceKind.chat, _chatUrl)).degraded, isTrue);
    });

    test('shake detector needs two jolts close together, then cools down', () {
      var t = DateTime(2026, 9, 15, 10);
      final d = ShakeDetector(clock: () => t);
      void at(int ms) => t = DateTime(2026, 9, 15, 10).add(Duration(milliseconds: ms));
      at(0);
      expect(d.add([2, 1, 0]), isFalse);
      expect(d.add([15, 3, 1]), isFalse);
      at(50);
      expect(d.add([16, 0, 0]), isFalse, reason: 'same jolt');
      at(300);
      expect(d.add([0, 18, 2]), isTrue);
      at(600);
      expect(d.add([20, 0, 0]), isFalse);
      at(900);
      expect(d.add([20, 0, 0]), isFalse, reason: 'cooldown');
      at(5000);
      expect(d.add([20, 0, 0]), isFalse);
      at(6000);
      expect(d.add([20, 0, 0]), isFalse, reason: 'too far apart');
      at(6300);
      expect(d.add([20, 0, 0]), isTrue);
    });

    test('diagnostics log tail is bounded and scrubbed', () {
      final records = [
        for (var i = 0; i < 500; i++)
          DiagnosticRecord(
            time: DateTime.utc(2026, 9, 15, 10, 0, i % 60),
            level: DiagnosticLevel.info,
            area: 'chat',
            message: 'event $i for user$i@kaztbu.edu.kz',
          ),
      ];
      final tail = FeedbackDiagnostics.tail(records);
      expect(tail.length, lessThanOrEqualTo(FeedbackDiagnostics.maxLogBytes));
      expect(tail, contains('event 499'));
      expect(tail, isNot(contains('event 0 ')));
      expect(tail, isNot(contains('@kaztbu.edu.kz')));
    });

    test('feedback is posted as multipart with payload and screenshot', () async {
      final h = await TestHarness.create(storedToken: Fixtures.token, chatBaseUrl: _chatUrl);
      addTearDown(h.dispose);
      await h.session.restore().catchError((Object _) {});
      h.chatAdapter.onJson('POST', '/feedback', {'id': 'f-1', 'created_at': '2026-09-15T10:00:00Z'}, status: 201);
      final id = await h.container.read(feedbackApiProvider).send(
        category: FeedbackCategory.idea,
        description: '  Добавьте тёмную тему  ',
        diagnostics: const FeedbackDiagnostics(
          device: DeviceSnapshot(appVersion: '0.1.0', appBuild: '5', platform: 'android', deviceModel: 'Pixel 8'),
          route: '/settings',
          errorReportIds: ['1-0:abc'],
          log: 'start',
        ),
        screenshot: FeedbackScreenshot(Uint8List.fromList([137, 80, 78, 71]), filename: 'screen.png'),
      );
      expect(id, 'f-1');
      final body = h.chatAdapter.of('POST', '/feedback').single.body;
      expect(body, contains('name="payload"'));
      expect(body, contains('"category":"idea"'));
      expect(body, contains('"description":"Добавьте тёмную тему"'));
      expect(body, contains('"device_model":"Pixel 8"'));
      expect(body, contains('"error_report_ids":["1-0:abc"]'));
      expect(body, contains('name="screenshot"; filename="screen.png"'));
      expect(body, contains('image/png'));
    });

    Future<TestHarness> reportHarness() async {
      final h = await TestHarness.create(
        storedToken: Fixtures.token,
        chatBaseUrl: _chatUrl,
        overrides: [
          feedbackDiagnosticsProvider.overrideWith(
            (ref) async => const FeedbackDiagnostics(device: DeviceSnapshot(appVersion: '0.1.0')),
          ),
          shakeToReportProvider.overrideWith(_NoShake.new),
        ],
      );
      addTearDown(h.dispose);
      return h;
    }

    testWidgets('report a problem: category, description, sent confirmation', (tester) async {
      final h = await reportHarness();
      h.chatAdapter.onJson('POST', '/feedback', {'id': 'f-2'}, status: 201);
      await tester.pumpWidget(wrapWidget(const ReportProblemScreen(), container: h.container));
      await _settle(tester);

      final send = find.byKey(const Key('report_send'));
      await tester.tap(find.byKey(const Key('report_category_question')));
      await tester.enterText(find.byKey(const Key('report_description')), 'Не приходят уведомления');
      await tester.pump();
      await tester.scrollUntilVisible(send, 200, scrollable: find.byType(Scrollable).first);
      expect(tester.widget<ButtonStyleButton>(send).onPressed, isNotNull);
      await tester.tap(send);
      await _settle(tester);

      expect(find.byKey(const Key('report_sent')), findsOneWidget);
      final body = h.chatAdapter.of('POST', '/feedback').single.body;
      expect(body, contains('"category":"question"'));
      expect(body, contains('"app_version":"0.1.0"'));
    });

    testWidgets('report a problem: rate limit is explained', (tester) async {
      final h = await reportHarness();
      h.chatAdapter.onError('POST', '/feedback', 429, 'RATE_LIMITED');
      await tester.pumpWidget(wrapWidget(const ReportProblemScreen(), container: h.container));
      await _settle(tester);
      await tester.enterText(find.byKey(const Key('report_description')), 'Ошибка');
      await tester.pump();
      final send = find.byKey(const Key('report_send'));
      await tester.scrollUntilVisible(send, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(send);
      await _settle(tester);
      expect(find.byKey(const Key('report_error')), findsOneWidget);
      expect(find.text('Слишком много сообщений подряд. Попробуйте через час.'), findsOneWidget);
    });
  });
}
