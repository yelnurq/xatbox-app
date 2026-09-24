import 'package:dio/dio.dart';

import '../../shared/utils/diagnostic_log.dart';

/// Logs the *class* of each API call: method, path, status, error code,
/// request_id and duration. Never headers, never bodies (ТЗ п.24.26).
class DiagnosticsInterceptor extends Interceptor {
  static const _startedAtKey = 'xatbox.startedAt';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedAtKey] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final status = response.statusCode ?? 0;
    final code = _errorCode(response.data);
    final requestId = _requestId(response.data);
    final line =
        '${response.requestOptions.method} ${_path(response.requestOptions)} '
        '-> $status${code != null ? ' $code' : ''}'
        '${requestId != null ? ' request_id=$requestId' : ''} '
        '${_elapsed(response.requestOptions)}ms';
    if (status >= 500) {
      DiagnosticLog.error('api', line);
    } else if (status >= 400) {
      DiagnosticLog.warn('api', line);
    } else {
      DiagnosticLog.info('api', line);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    DiagnosticLog.warn(
      'api',
      '${err.requestOptions.method} ${_path(err.requestOptions)} '
          '-> ${err.type.name} ${_elapsed(err.requestOptions)}ms',
    );
    handler.next(err);
  }

  /// Path only, without query (search terms may be personal).
  static String _path(RequestOptions o) => Uri.parse(o.path).path;

  static int _elapsed(RequestOptions o) {
    final started = o.extra[_startedAtKey];
    if (started is DateTime) {
      return DateTime.now().difference(started).inMilliseconds;
    }
    return 0;
  }

  static String? _errorCode(dynamic data) {
    if (data is Map && data['error'] is Map) {
      final code = (data['error'] as Map)['code'];
      return code is String ? code : null;
    }
    return null;
  }

  static String? _requestId(dynamic data) {
    if (data is Map && data['error'] is Map) {
      final id = (data['error'] as Map)['request_id'];
      return id is String ? id : null;
    }
    return null;
  }
}
