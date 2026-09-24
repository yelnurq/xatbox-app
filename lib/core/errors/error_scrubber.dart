import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Privacy rules of crash reports (mirrored by the Chat Service in
/// `domain/clienterrors.go`): no message texts, tokens, e-mails or file paths
/// carrying a user or file name ever leave the device.
abstract final class ErrorScrubber {
  static const maxMessage = 1000;
  static const maxStack = 16000;
  static const maxContext = 512;
  static const fingerprintFrames = 5;

  static final _bearer = RegExp(
    r'bearer\s+[A-Za-z0-9._~+/=\-]{8,}',
    caseSensitive: false,
  );
  static final _jwt = RegExp(
    r'eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]*',
  );
  static final _secret = RegExp(
    r'''\b(access_token|refresh_token|token|password|passwd|secret|api_key|apikey|authorization|mp_session|session_id|push_key)(["']?\s*[:=]\s*["']?)[^"'\s&;,)]+''',
    caseSensitive: false,
  );
  static final _email = RegExp(
    r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}',
  );
  static final _userDir = RegExp(r'(/home/|/Users/|[A-Za-z]:\\Users\\)[^/\\\s:)]+');
  static final _storage = RegExp(
    r'''(/storage/emulated/\d+/|/sdcard/|content://|/data/user/\d+/[^/\s]+/(?:cache|files|app_flutter)/)[^\n)'"]+''',
  );
  static final _longToken = RegExp(r'[A-Za-z0-9_\-]{32,}');
  // A long quoted fragment is most likely user content (a JSON body, a
  // message, a file name) echoed by an exception.
  static final _longQuoted = RegExp(r'''(["'«])[^"'«»\n]{40,}(["'»])''');

  static String scrub(String input) {
    if (input.isEmpty) return input;
    var s = input.replaceAll(_bearer, 'Bearer <redacted>');
    s = s.replaceAll(_jwt, '<jwt>');
    s = s.replaceAllMapped(_secret, (m) => '${m[1]}${m[2]}<redacted>');
    s = s.replaceAll(_email, '<email>');
    s = s.replaceAllMapped(_userDir, (m) => '${m[1]}<user>');
    s = s.replaceAllMapped(_storage, (m) => '${m[1]}<path>');
    s = s.replaceAllMapped(_longToken, (m) {
      final v = m[0]!;
      final hasDigit = v.contains(RegExp(r'\d'));
      final hasLetter = v.contains(RegExp('[A-Za-z]'));
      return hasDigit && hasLetter ? '<redacted>' : v;
    });
    return s;
  }

  /// Message of an error: scrubbed, long quoted fragments removed, bounded.
  static String message(Object error) {
    final raw = switch (error) {
      // toString() of a FormatException echoes the parsed source (bodies).
      FormatException(:final message) => 'FormatException: $message',
      _ => _safeToString(error),
    };
    return truncate(
      scrub(raw).replaceAllMapped(_longQuoted, (m) => '${m[1]}…${m[2]}'),
      maxMessage,
    );
  }

  static String stack(StackTrace? stack) =>
      stack == null ? '' : truncate(scrub(stack.toString()), maxStack);

  static String context(String? context) => context == null
      ? ''
      : truncate(
          scrub(context).replaceAllMapped(_longQuoted, (m) => '${m[1]}…${m[2]}'),
          maxContext,
        );

  static String _safeToString(Object error) {
    try {
      return error.toString();
    } on Object {
      return error.runtimeType.toString();
    }
  }

  static final _uuidOrId = RegExp(
    r'^([0-9a-fA-F\-]{16,}|\d+|[A-Za-z0-9_\-]{24,})$',
  );

  /// Route path without ids or query (`/chat/c/<uuid>` → `/chat/c/:id`).
  static String route(String? path) {
    if (path == null || path.isEmpty) return '';
    final noQuery = path.split('?').first.split('#').first;
    final segments = [
      for (final s in noQuery.split('/'))
        _uuidOrId.hasMatch(s) || s.contains('@') ? ':id' : s,
    ];
    return truncate(segments.join('/'), 256);
  }

  static final _frameNumber = RegExp(r'^#\d+\s+');
  static final _lineColumn = RegExp(r':\d+(:\d+)?\)?$');
  static final _hex = RegExp('0x[0-9a-fA-F]+');

  /// Same grouping as the server: type + top frames without line numbers.
  static String fingerprint(String errorType, String stack) {
    final b = StringBuffer(errorType);
    var n = 0;
    for (var line in const LineSplitter().convert(stack)) {
      line = line.trim();
      if (line.isEmpty || line == '<asynchronous suspension>') continue;
      line = line
          .replaceFirst(_frameNumber, '')
          .replaceFirst(_lineColumn, '')
          .replaceAll(_hex, '0x');
      b
        ..write('\n')
        ..write(line);
      if (++n == fingerprintFrames) break;
    }
    return sha256.convert(utf8.encode(b.toString())).toString();
  }

  static String truncate(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);
}
