/// Errors raised by the API layer. Never contains the bearer token or mail
/// content; safe to log.
sealed class AppException implements Exception {
  const AppException();
}

/// The server answered with the JSON error envelope
/// `{"error": {"code", "message", "request_id"}}`.
class ApiException extends AppException {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.serverMessage,
    this.requestId,
  });

  final int statusCode;

  /// Stable code, e.g. `INVALID_CREDENTIALS`. `UNKNOWN` when the body was not
  /// the JSON envelope (e.g. plain-text 404 from avatar endpoints).
  final String code;

  /// English text for logs only; never shown to the user as-is.
  final String serverMessage;
  final String? requestId;

  bool get isUnauthenticated => statusCode == 401 && code == 'UNAUTHENTICATED';

  @override
  String toString() =>
      'ApiException($statusCode $code'
      '${requestId != null ? ', request_id=$requestId' : ''})';
}

/// No usable HTTP response: DNS/socket failure, timeout, TLS problem.
class NetworkException extends AppException {
  const NetworkException({this.isTimeout = false, this.cause});
  final bool isTimeout;
  final Object? cause;

  @override
  String toString() => 'NetworkException(timeout=$isTimeout)';
}

/// The request was cancelled by the app (e.g. screen closed).
class CancelledException extends AppException {
  const CancelledException();
}

/// Any other failure inside the API layer (malformed JSON, unexpected shape).
class UnexpectedApiException extends AppException {
  const UnexpectedApiException(this.detail, {this.statusCode});
  final String detail;
  final int? statusCode;

  @override
  String toString() => 'UnexpectedApiException($detail)';
}
