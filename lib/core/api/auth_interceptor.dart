import 'package:dio/dio.dart';

import 'api_client.dart';

/// Adds the bearer token and detects `401 UNAUTHENTICATED` on *any* endpoint.
///
/// The API has no refresh flow: a 401 means the 7-day session is gone, so the
/// only correct reaction is to drop local state and show the login screen.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.tokenReader, required this.onUnauthenticated});

  final TokenReader tokenReader;
  final UnauthenticatedHandler onUnauthenticated;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra[ApiClient.noAuthKey] != true) {
      final token = tokenReader();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _checkUnauthenticated(response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final res = err.response;
    if (res != null) _checkUnauthenticated(res);
    handler.next(err);
  }

  void _checkUnauthenticated(Response<dynamic> response) {
    if (response.statusCode != 401) return;
    // The login endpoint itself answers 401 INVALID_CREDENTIALS; only the
    // UNAUTHENTICATED code means "session is gone".
    if (response.requestOptions.extra[ApiClient.noAuthKey] == true) return;
    final data = response.data;
    if (data is Map && data['error'] is Map) {
      final code = (data['error'] as Map)['code'];
      if (code == 'UNAUTHENTICATED') onUnauthenticated();
    }
  }
}
