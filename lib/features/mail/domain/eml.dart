import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'cyrillic_charsets.dart';

/// A file of a saved message: an attachment, or a picture the HTML draws
/// with `cid:` ([contentId]).
@immutable
class EmlPart {
  const EmlPart({required this.filename, required this.contentType, required this.bytes, this.contentId = ''});
  final String filename;
  final String contentType;
  final Uint8List bytes;
  final String contentId;
}

/// A saved message (`.eml`, RFC 5322 + MIME) opened with XatBox on the
/// desktop: headers decoded (RFC 2047), the HTML and text bodies in their
/// charsets (UTF-8, the Cyrillic single-byte ones, Latin-1), the files
/// (pure, unit-tested).
@immutable
class EmlMessage {
  const EmlMessage({
    this.subject = '',
    this.from = '',
    this.to = '',
    this.cc = '',
    this.date,
    this.html = '',
    this.text = '',
    this.parts = const [],
  });

  final String subject;
  final String from;
  final String to;
  final String cc;
  final DateTime? date;
  final String html;
  final String text;
  final List<EmlPart> parts;

  static EmlMessage parse(Uint8List bytes) {
    final raw = latin1.decode(bytes, allowInvalid: true);
    final (headers, body) = _split(raw);
    final message = _Builder();
    _walk(headers, body, message);
    String h(String name) => decodeHeader(headers[name] ?? '');
    return EmlMessage(
      subject: h('subject'),
      from: h('from'),
      to: h('to'),
      cc: h('cc'),
      date: parseDate(headers['date'] ?? ''),
      html: message.html,
      text: message.text,
      parts: message.parts,
    );
  }

  /// Header block and body of a message or part; header names lower-cased,
  /// continuation lines unfolded.
  static (Map<String, String>, String) _split(String raw) {
    final text = raw.replaceAll('\r\n', '\n');
    final gap = text.indexOf('\n\n');
    final head = gap < 0 ? text : text.substring(0, gap);
    final body = gap < 0 ? '' : text.substring(gap + 2);
    final headers = <String, String>{};
    for (final line in head.replaceAll(RegExp('\n[ \t]+'), ' ').split('\n')) {
      final colon = line.indexOf(':');
      if (colon <= 0) continue;
      headers.putIfAbsent(line.substring(0, colon).trim().toLowerCase(), () => line.substring(colon + 1).trim());
    }
    return (headers, body);
  }

  static void _walk(Map<String, String> headers, String body, _Builder out) {
    final type = _Header.parse(headers['content-type'] ?? 'text/plain');
    final mime = type.value.toLowerCase();
    if (mime.startsWith('multipart/')) {
      final boundary = type.params['boundary'];
      if (boundary == null || boundary.isEmpty) return;
      for (final part in _parts(body, boundary)) {
        final (h, b) = _split(part);
        _walk(h, b, out);
      }
      return;
    }
    final disposition = _Header.parse(headers['content-disposition'] ?? '');
    final filename = decodeHeader(disposition.params['filename'] ?? type.params['name'] ?? '');
    final bytes = _decodeTransfer(body, headers['content-transfer-encoding'] ?? '');
    final attachment = disposition.value.toLowerCase() == 'attachment' || filename.isNotEmpty;
    if (!attachment && mime == 'text/html' && out.html.isEmpty) {
      out.html = decodeCharset(bytes, type.params['charset']);
    } else if (!attachment && mime == 'text/plain' && out.text.isEmpty) {
      out.text = decodeCharset(bytes, type.params['charset']);
    } else {
      final cid = (headers['content-id'] ?? '').replaceAll(RegExp('[<>]'), '').trim();
      out.parts.add(
        EmlPart(
          filename: filename.isNotEmpty ? filename : (mime == 'message/rfc822' ? 'message.eml' : 'file'),
          contentType: mime,
          bytes: bytes,
          contentId: cid,
        ),
      );
    }
  }

  /// The parts between `--boundary` lines, up to `--boundary--`.
  static List<String> _parts(String body, String boundary) {
    final parts = <String>[];
    final delimiter = '--$boundary';
    StringBuffer? current;
    for (final line in body.split('\n')) {
      if (line.trimRight() == '$delimiter--') break;
      if (line.trimRight() == delimiter) {
        if (current != null) parts.add(current.toString());
        current = StringBuffer();
        continue;
      }
      current?.writeln(line);
    }
    if (current != null && current.isNotEmpty) parts.add(current.toString());
    return parts;
  }

  static Uint8List _decodeTransfer(String body, String encoding) {
    final e = encoding.toLowerCase().trim();
    if (e == 'base64') {
      final clean = body.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');
      try {
        return base64.decode(base64.normalize(clean));
      } on FormatException {
        return Uint8List(0);
      }
    }
    if (e == 'quoted-printable') return _quotedPrintable(body);
    return latin1.encode(body.endsWith('\n') ? body.substring(0, body.length - 1) : body);
  }

  static Uint8List _quotedPrintable(String input) {
    final s = input.replaceAll(RegExp(r'=\n'), '');
    final out = BytesBuilder();
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c == 0x3D && i + 2 < s.length) {
        final v = int.tryParse(s.substring(i + 1, i + 3), radix: 16);
        if (v != null) {
          out.addByte(v);
          i += 2;
          continue;
        }
      }
      out.addByte(c & 0xFF);
    }
    return out.takeBytes();
  }

  /// Bytes in [charset] (UTF-8 when unknown).
  static String decodeCharset(List<int> bytes, String? charset) {
    final name = (charset ?? 'utf-8').toLowerCase().replaceAll('_', '-').trim();
    final table = cyrillicCharsets[switch (name) {
      'cp1251' || 'win-1251' || 'windows1251' => 'windows-1251',
      'cp866' || '866' => 'ibm866',
      'koi8r' => 'koi8-r',
      _ => name,
    }];
    if (table != null) {
      return String.fromCharCodes([for (final b in bytes) b < 0x80 ? b : table[b - 0x80]]);
    }
    if (name == 'iso-8859-1' || name == 'latin1' || name == 'us-ascii' || name == 'ascii' || name == 'windows-1252') {
      return latin1.decode(bytes, allowInvalid: true);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// RFC 2047 encoded words (`=?utf-8?B?…?=`, `=?windows-1251?Q?…?=`); the
  /// whitespace between two of them goes.
  static String decodeHeader(String raw) {
    // Raw 8-bit headers (read as Latin-1 here) are UTF-8 in practice.
    final raw8bit = raw.codeUnits.any((c) => c > 0x7F) && raw.codeUnits.every((c) => c <= 0xFF);
    final value = raw8bit ? utf8.decode(latin1.encode(raw), allowMalformed: true) : raw;
    final word = RegExp(r'=\?([^?]+)\?([bBqQ])\?([^?]*)\?=');
    final joined = value.replaceAllMapped(RegExp(r'(\?=)\s+(=\?)'), (m) => '${m[1]}${m[2]}');
    return joined.replaceAllMapped(word, (m) {
      final charset = m[1]!.split('*').first;
      final encoded = m[3]!;
      List<int> bytes;
      if (m[2]!.toLowerCase() == 'b') {
        try {
          bytes = base64.decode(base64.normalize(encoded));
        } on FormatException {
          return m[0]!;
        }
      } else {
        bytes = _quotedPrintable(encoded.replaceAll('_', ' '));
      }
      return decodeCharset(bytes, charset);
    });
  }

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  /// RFC 5322 date (`Thu, 18 Sep 2026 14:03:05 +0500`) in UTC.
  static DateTime? parseDate(String value) {
    final m = RegExp(r'(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4}|[A-Z]{1,5})?').firstMatch(value);
    if (m == null) return null;
    final month = _months[m[2]!.toLowerCase()];
    if (month == null) return null;
    final utc = DateTime.utc(int.parse(m[3]!), month, int.parse(m[1]!), int.parse(m[4]!), int.parse(m[5]!), int.parse(m[6] ?? '0'));
    final zone = m[7] ?? '';
    if (zone.length == 5 && (zone[0] == '+' || zone[0] == '-')) {
      final offset = Duration(hours: int.parse(zone.substring(1, 3)), minutes: int.parse(zone.substring(3, 5)));
      return zone[0] == '+' ? utc.subtract(offset) : utc.add(offset);
    }
    return utc;
  }
}

class _Builder {
  String html = '';
  String text = '';
  final parts = <EmlPart>[];
}

/// `value; name=param; name*=utf-8''%D0%...` of Content-Type and
/// Content-Disposition (RFC 2231 values decoded).
class _Header {
  _Header(this.value, this.params);
  final String value;
  final Map<String, String> params;

  static _Header parse(String raw) {
    final pieces = <String>[];
    var quoted = false;
    var start = 0;
    for (var i = 0; i < raw.length; i++) {
      if (raw[i] == '"') quoted = !quoted;
      if (raw[i] == ';' && !quoted) {
        pieces.add(raw.substring(start, i));
        start = i + 1;
      }
    }
    pieces.add(raw.substring(start));
    final params = <String, String>{};
    final continued = <String, Map<int, String>>{};
    for (final piece in pieces.skip(1)) {
      final eq = piece.indexOf('=');
      if (eq <= 0) continue;
      var key = piece.substring(0, eq).trim().toLowerCase();
      var value = piece.substring(eq + 1).trim();
      if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) value = value.substring(1, value.length - 1);
      final extended = key.endsWith('*');
      if (extended) {
        key = key.substring(0, key.length - 1);
        value = _rfc2231(value);
      }
      final section = RegExp(r'^(.+)\*(\d+)$').firstMatch(key);
      if (section != null) {
        (continued[section[1]!] ??= {})[int.parse(section[2]!)] = value;
      } else {
        params[key] = value;
      }
    }
    for (final e in continued.entries) {
      final keys = e.value.keys.toList()..sort();
      params[e.key] = keys.map((k) => e.value[k]).join();
    }
    return _Header(pieces.first.trim(), params);
  }

  /// `utf-8''%D0%9E%D1%82%D1%87%D1%91%D1%82.pdf`.
  static String _rfc2231(String value) {
    final m = RegExp(r"^([^']*)'[^']*'(.*)$").firstMatch(value);
    if (m == null) return value;
    final bytes = <int>[];
    final s = m[2]!;
    for (var i = 0; i < s.length; i++) {
      if (s[i] == '%' && i + 2 < s.length) {
        final v = int.tryParse(s.substring(i + 1, i + 3), radix: 16);
        if (v != null) {
          bytes.add(v);
          i += 2;
          continue;
        }
      }
      bytes.addAll(utf8.encode(s[i]));
    }
    return EmlMessage.decodeCharset(bytes, m[1]!.isEmpty ? 'utf-8' : m[1]);
  }
}
