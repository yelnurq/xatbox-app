import 'dart:convert';

import 'package:dio/dio.dart';

import '../../shared/utils/diagnostic_log.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';
import 'diagnostics_interceptor.dart';

/// Supplies the current bearer token (or null). Implemented by `AuthSession`.
typedef TokenReader = String? Function();

/// Called when any endpoint answers `401 UNAUTHENTICATED`.
typedef UnauthenticatedHandler = void Function();

/// Shared HTTP client for every module (Mail now; Chat/Calls later).
///
/// * Adds `Authorization: Bearer <token>` to every request unless the request
///   sets `extra[ApiClient.noAuthKey] = true`.
/// * Turns `401 UNAUTHENTICATED` from *any* endpoint into a global sign-out
///   (there is no refresh endpoint; the session simply has to be recreated).
/// * Maps transport/HTTP failures to [AppException] via [guard].
class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenReader tokenReader,
    required UnauthenticatedHandler onUnauthenticated,
    required String userAgent,
    HttpClientAdapter? adapter,
    Duration connectTimeout = const Duration(seconds: 15),
    Duration receiveTimeout = const Duration(seconds: 30),
  }) : dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: connectTimeout,
           receiveTimeout: receiveTimeout,
           sendTimeout: const Duration(seconds: 60),
           headers: {'Accept': 'application/json', 'User-Agent': userAgent},
           responseType: ResponseType.json,
           // We inspect the status ourselves; do not throw for non-2xx so the
           // JSON error envelope is always available.
           validateStatus: (_) => true,
         ),
       ) {
    if (adapter != null) dio.httpClientAdapter = adapter;
    dio.interceptors.addAll([
      AuthInterceptor(
        tokenReader: tokenReader,
        onUnauthenticated: onUnauthenticated,
      ),
      DiagnosticsInterceptor(),
    ]);
  }

  static const noAuthKey = 'xatbox.noAuth';

  final Dio dio;

  /// Runs [request] and normalises every failure into an [AppException].
  ///
  /// [expectedStatuses] lists the success codes of the operation (from the
  /// spec); anything else is decoded as the error envelope.
  Future<Response<T>> send<T>(
    Future<Response<T>> Function() request, {
    Set<int> expectedStatuses = const {200},
  }) async {
    final Response<T> response;
    try {
      response = await request();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
    final status = response.statusCode ?? 0;
    if (expectedStatuses.contains(status)) return response;
    throw decodeError(response);
  }

  /// Convenience: JSON object body.
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    final res = await send(
      () => dio.get<dynamic>(
        path,
        queryParameters: query,
        cancelToken: cancelToken,
      ),
    );
    return asJsonObject(res.data, path);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Set<int> expectedStatuses = const {200, 201, 202},
    bool noAuth = false,
  }) async {
    final res = await send(
      () => dio.post<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(extra: noAuth ? {noAuthKey: true} : null),
      ),
      expectedStatuses: expectedStatuses,
    );
    return asJsonObject(res.data, path, allowEmpty: true);
  }

  Future<Map<String, dynamic>> patchJson(String path, {Object? body}) async {
    final res = await send(() => dio.patch<dynamic>(path, data: body));
    return asJsonObject(res.data, path, allowEmpty: true);
  }

  Future<Map<String, dynamic>> putJson(String path, {Object? body}) async {
    final res = await send(() => dio.put<dynamic>(path, data: body));
    return asJsonObject(res.data, path, allowEmpty: true);
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, dynamic>? query,
    Set<int> expectedStatuses = const {200, 204},
  }) async {
    final res = await send(
      () => dio.delete<dynamic>(path, queryParameters: query),
      expectedStatuses: expectedStatuses,
    );
    return asJsonObject(res.data, path, allowEmpty: true);
  }

  static Map<String, dynamic> asJsonObject(
    dynamic data,
    String path, {
    bool allowEmpty = false,
  }) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    if (data is String) {
      if (data.trim().isEmpty) {
        if (allowEmpty) return const {};
      } else {
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map) return decoded.cast<String, dynamic>();
        } on FormatException {
          // fall through
        }
      }
    }
    if (data == null && allowEmpty) return const {};
    throw UnexpectedApiException('Non-object JSON body from $path');
  }

  /// Decodes a non-success response into [ApiException] (or
  /// [UnexpectedApiException] when the body is not the JSON envelope, e.g. the
  /// plain-text 404 of avatar endpoints or HTML from a proxy).
  static AppException decodeError(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    dynamic data = response.data;
    if (data is List<int>) {
      try {
        data = utf8.decode(data);
      } on FormatException {
        data = null;
      }
    }
    if (data is String) {
      try {
        data = jsonDecode(data);
      } on FormatException {
        data = null;
      }
    }
    if (data is Map && data['error'] is Map) {
      final err = (data['error'] as Map).cast<String, dynamic>();
      return ApiException(
        statusCode: status,
        code: (err['code'] as String?) ?? 'UNKNOWN',
        serverMessage: (err['message'] as String?) ?? '',
        requestId: err['request_id'] as String?,
      );
    }
    return UnexpectedApiException(
      'HTTP $status without error envelope',
      statusCode: status,
    );
  }

  static AppException mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.cancel:
        return const CancelledException();
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException(isTimeout: true, cause: e.error);
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return NetworkException(cause: e.error);
      case DioExceptionType.badResponse:
        final res = e.response;
        if (res != null) return decodeError(res);
        return UnexpectedApiException('Bad response without body');
      case DioExceptionType.unknown:
      default:
        final inner = e.error;
        if (inner is AppException) return inner;
        // Socket / TLS errors surface here on some platforms.
        DiagnosticLog.warn('api', 'Unknown transport failure', error: inner);
        return NetworkException(cause: inner);
    }
  }
}
