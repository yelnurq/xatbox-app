import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Recorded request for assertions.
class RecordedRequest {
  RecordedRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.headers,
    required this.body,
  });
  final String method;
  final String path;
  final Map<String, dynamic> query;
  final Map<String, dynamic> headers;

  /// Raw request body (JSON text or multipart text).
  final String body;

  Map<String, dynamic> get json => jsonDecode(body) as Map<String, dynamic>;
}

/// Canned response.
class FakeResponse {
  const FakeResponse(this.status, {this.json, this.text, this.contentType});

  factory FakeResponse.error(
    int status,
    String code, {
    String message = 'x',
    String? requestId,
  }) => FakeResponse(
    status,
    json: {
      'error': {'code': code, 'message': message, 'request_id': ?requestId},
    },
  );

  final int status;
  final Object? json;
  final String? text;
  final String? contentType;
}

typedef FakeHandler = FakeResponse Function(RecordedRequest request);

/// In-memory `HttpClientAdapter` that routes by `METHOD /path` and records
/// every request. Throw a [SocketException] from a handler to simulate
/// "no network".
class FakeHttpAdapter implements HttpClientAdapter {
  final Map<String, List<FakeHandler>> _routes = {};
  final List<(String, RegExp, FakeHandler)> _patterns = [];
  final List<RecordedRequest> requests = [];

  /// Fallback route for paths with ids, e.g. `^/calendar/events/[^/]+$`.
  void onPattern(String method, String pattern, FakeHandler handler) =>
      _patterns.add((method.toUpperCase(), RegExp(pattern), handler));

  /// Registers (or replaces) the handler for `METHOD /path`.
  void on(String method, String path, FakeHandler handler) {
    _routes['${method.toUpperCase()} $path'] = [handler];
  }

  /// Registers an ordered sequence of responses; each is consumed once and
  /// the last one sticks.
  void onQueue(String method, String path, List<FakeResponse> responses) {
    _routes['${method.toUpperCase()} $path'] = [
      for (final r in responses) (_) => r,
    ];
  }

  void onJson(String method, String path, Object? body, {int status = 200}) =>
      on(method, path, (_) => FakeResponse(status, json: body));

  void onError(
    String method,
    String path,
    int status,
    String code, {
    String? requestId,
  }) => on(
    method,
    path,
    (_) => FakeResponse.error(status, code, requestId: requestId),
  );

  void onOffline(String method, String path) =>
      on(method, path, (_) => throw const SocketException('offline'));

  List<RecordedRequest> of(String method, String path) => requests
      .where((r) => r.method == method.toUpperCase() && r.path == path)
      .toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    final path = options.uri.path.replaceFirst(RegExp(r'^.*?/api/v1'), '');
    final recorded = RecordedRequest(
      method: options.method.toUpperCase(),
      path: path,
      query: options.uri.queryParametersAll.map(
        (k, v) => MapEntry(k, v.length == 1 ? v.first : v),
      ),
      headers: options.headers,
      body: utf8.decode(bytes, allowMalformed: true),
    );
    requests.add(recorded);

    var handlers = _routes['${recorded.method} $path'];
    if (handlers == null || handlers.isEmpty) {
      final match = _patterns
          .where((p) => p.$1 == recorded.method && p.$2.hasMatch(path))
          .firstOrNull;
      if (match != null) handlers = [match.$3];
    }
    if (handlers == null || handlers.isEmpty) {
      return ResponseBody.fromString(
        '{"error":{"code":"NOT_FOUND","message":"no fake route for ${recorded.method} $path"}}',
        404,
        headers: {
          'content-type': ['application/json'],
        },
      );
    }
    final handler = handlers.length > 1 ? handlers.removeAt(0) : handlers.first;
    final res = handler(recorded);
    final contentType =
        res.contentType ??
        (res.json != null ? 'application/json' : 'text/plain');
    final text = res.json != null ? jsonEncode(res.json) : (res.text ?? '');
    return ResponseBody.fromString(
      text,
      res.status,
      headers: {
        'content-type': [contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
