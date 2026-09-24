import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/shared/widgets/avatar_cache.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <Uri>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options.uri);
    if (options.uri.queryParameters['domain'] == 'zoom.us') {
      return ResponseBody.fromBytes([1, 2, 3], 200, headers: {Headers.contentTypeHeader: ['image/png']});
    }
    return ResponseBody.fromString('', 404);
  }

  @override
  void close({bool force = false}) {}
}

/// Desktop sender marks come from the web's /api/sender-icon on our own
/// server (the origin of the API address), one request per domain.
void main() {
  test('domains worth asking about', () {
    expect(DomainLogoCache.domainOf('Billing@Zoom.US'), 'zoom.us');
    expect(DomainLogoCache.domainOf('no-at-sign'), isNull);
    expect(DomainLogoCache.domainOf('a@localhost'), isNull);
  });

  test('asks our server once per domain; none is remembered', () async {
    final adapter = _Adapter();
    final cache = DomainLogoCache(apiBaseUrl: 'https://mail.example.kz/backend/api/v1', dio: Dio()..httpClientAdapter = adapter);
    expect(await cache.logo('billing@zoom.us'), [1, 2, 3]);
    expect(await cache.logo('noreply@zoom.us'), [1, 2, 3]);
    expect(await cache.logo('x@unknown.kz'), isNull);
    expect(await cache.logo('y@unknown.kz'), isNull);
    expect(adapter.requests.map((u) => u.toString()), [
      'https://mail.example.kz/api/sender-icon?domain=zoom.us',
      'https://mail.example.kz/api/sender-icon?domain=unknown.kz',
    ]);
  });
}
