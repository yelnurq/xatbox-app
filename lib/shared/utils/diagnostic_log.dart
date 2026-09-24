import 'dart:developer' as developer;

/// Diagnostics log (ТЗ п.24.26): technical events only.
///
/// Rules enforced here:
/// * Never log the bearer token, passwords or mail/chat content.
/// * Only the API error *class* (status + code + request_id), never bodies.
///
/// Sinks (crash reporting etc.) can be attached via [addSink]; they receive
/// already-redacted records.
class DiagnosticLog {
  DiagnosticLog._();

  static final List<void Function(DiagnosticRecord record)> _sinks = [];
  static final List<DiagnosticRecord> _recent = [];
  static const _recentLimit = 200;

  static void addSink(void Function(DiagnosticRecord record) sink) =>
      _sinks.add(sink);

  /// In-memory ring buffer for a diagnostics screen; redacted.
  static List<DiagnosticRecord> get recent => List.unmodifiable(_recent);

  static void info(String area, String message) =>
      _emit(DiagnosticLevel.info, area, message);

  static void warn(String area, String message, {Object? error}) =>
      _emit(DiagnosticLevel.warning, area, message, error: error);

  static void error(
    String area,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => _emit(
    DiagnosticLevel.error,
    area,
    message,
    error: error,
    stackTrace: stackTrace,
  );

  static void _emit(
    DiagnosticLevel level,
    String area,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final record = DiagnosticRecord(
      time: DateTime.now(),
      level: level,
      area: area,
      message: redact(message),
      error: error == null ? null : redact(error.toString()),
    );
    _recent.add(record);
    if (_recent.length > _recentLimit) _recent.removeAt(0);
    developer.log(
      record.message,
      name: 'xatbox.$area',
      level: switch (level) {
        DiagnosticLevel.info => 800,
        DiagnosticLevel.warning => 900,
        DiagnosticLevel.error => 1000,
      },
      error: record.error,
      stackTrace: stackTrace,
    );
    for (final sink in _sinks) {
      sink(record);
    }
  }

  static final _bearer = RegExp(
    r'bearer\s+[A-Za-z0-9_\-=]{8,}',
    caseSensitive: false,
  );
  static final _token43 = RegExp(
    r'(?<![A-Za-z0-9_\-])[A-Za-z0-9_\-]{43}(?![A-Za-z0-9_\-])',
  );
  static final _jsonSecret = RegExp(
    r'"(token|password|mp_session)"\s*:\s*"[^"]*"',
    caseSensitive: false,
  );
  static final _cookie = RegExp(r'mp_session=[^;\s]+', caseSensitive: false);

  /// Defensive redaction so that even an accidental token in a message never
  /// reaches logs or crash reports.
  static String redact(String input) {
    var out = input.replaceAll(_bearer, 'Bearer <redacted>');
    out = out.replaceAll(_cookie, 'mp_session=<redacted>');
    out = out.replaceAllMapped(_jsonSecret, (m) => '"${m[1]}":"<redacted>"');
    out = out.replaceAll(_token43, '<redacted>');
    return out;
  }
}

enum DiagnosticLevel { info, warning, error }

class DiagnosticRecord {
  const DiagnosticRecord({
    required this.time,
    required this.level,
    required this.area,
    required this.message,
    this.error,
  });
  final DateTime time;
  final DiagnosticLevel level;
  final String area;
  final String message;
  final String? error;
}
