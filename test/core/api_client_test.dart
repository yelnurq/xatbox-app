import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/api/api_client.dart';
import 'package:xatbox_mobile/core/api/api_exception.dart';

import '../helpers/fake_http.dart';

void main() {
  late FakeHttpAdapter adapter;
  late ApiClient client;
  String? token;
  var unauthenticatedCalls = 0;

  setUp(() {
    adapter = FakeHttpAdapter();
    token = null;
    unauthenticatedCalls = 0;
    client = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      userAgent: 'XatBoxMobile/test',
      adapter: adapter,
      tokenReader: () => token,
      onUnauthenticated: () => unauthenticatedCalls++,
    );
  });

  test(
    'adds bearer header when a token exists and never with noAuth',
    () async {
      token = 'tok';
      adapter.onJson('GET', '/me', {'ok': true});
      adapter.onJson('POST', '/auth/login', {'ok': true});
      await client.getJson('/me');
      await client.postJson(
        '/auth/login',
        body: {'email': 'a@b.c', 'password': 'p'},
        noAuth: true,
      );
      expect(
        adapter.of('GET', '/me').single.headers['Authorization'],
        'Bearer tok',
      );
      expect(
        adapter
            .of('POST', '/auth/login')
            .single
            .headers
            .containsKey('Authorization'),
        isFalse,
      );
      expect(
        adapter.of('GET', '/me').single.headers['User-Agent'],
        'XatBoxMobile/test',
      );
    },
  );

  test('decodes the JSON error envelope into ApiException', () async {
    adapter.onError(
      'GET',
      '/mail/summary',
      404,
      'NO_MAILBOX',
      requestId: 'req-1',
    );
    final err = await client
        .getJson('/mail/summary')
        .then<Object?>((_) => null, onError: (e) => e);
    expect(err, isA<ApiException>());
    final api = err! as ApiException;
    expect(api.statusCode, 404);
    expect(api.code, 'NO_MAILBOX');
    expect(api.requestId, 'req-1');
  });

  test('401 UNAUTHENTICATED on any endpoint triggers the global handler once per call', () async {
    token = 'expired';
    adapter.onError('GET', '/mail/summary', 401, 'UNAUTHENTICATED');
    await expectLater(
      client.getJson('/mail/summary'),
      throwsA(isA<ApiException>()),
    );
    expect(unauthenticatedCalls, 1);
  });

  test(
    '401 INVALID_CREDENTIALS from login does not trigger the global handler',
    () async {
      adapter.onError('POST', '/auth/login', 401, 'INVALID_CREDENTIALS');
      await expectLater(
        client.postJson(
          '/auth/login',
          body: {'email': 'a@b.c', 'password': 'x'},
          noAuth: true,
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'INVALID_CREDENTIALS',
          ),
        ),
      );
      expect(unauthenticatedCalls, 0);
    },
  );

  test('socket failure becomes NetworkException', () async {
    adapter.onOffline('GET', '/me');
    await expectLater(client.getJson('/me'), throwsA(isA<NetworkException>()));
  });

  test(
    'non-envelope error body (plain text 404) becomes UnexpectedApiException',
    () async {
      adapter.on(
        'GET',
        '/avatars/by-email',
        (_) => const FakeResponse(404, text: '404 page not found'),
      );
      await expectLater(
        client.getJson('/avatars/by-email'),
        throwsA(
          isA<UnexpectedApiException>().having(
            (e) => e.statusCode,
            'status',
            404,
          ),
        ),
      );
    },
  );

  test('unexpected success status is treated as an error', () async {
    adapter.onJson('POST', '/mail/send', {'message_id': 'msg_x'}, status: 200);
    await expectLater(
      client.postJson(
        '/mail/send',
        body: {
          'to': ['a@b.c'],
        },
        expectedStatuses: const {202},
      ),
      throwsA(isA<UnexpectedApiException>()),
    );
  });
}
