import 'package:flutter/widgets.dart';

/// A piece of message text: plain, or a link with the [uri] to open.
class TextLinkSegment {
  const TextLinkSegment(this.text, {this.uri});
  final String text;
  final Uri? uri;
  bool get isLink => uri != null;
}

/// Pure text helpers for message bodies: link detection and emoji-only
/// messages (rendered large).
abstract final class ChatText {
  static final _link = RegExp(
    r'''(?:https?://|www\.)[^\s<>"]+|[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}''',
    caseSensitive: false,
  );

  static const _trailing = '.,;:!?\'"»…';

  /// Splits [text] into plain and link segments (http/https, `www.`, e-mail).
  /// Trailing punctuation and an unbalanced closing bracket stay outside.
  static List<TextLinkSegment> links(String text) {
    final out = <TextLinkSegment>[];
    var pos = 0;
    for (final match in _link.allMatches(text)) {
      var raw = match.group(0)!;
      while (raw.isNotEmpty) {
        final last = raw[raw.length - 1];
        if (_trailing.contains(last)) {
          raw = raw.substring(0, raw.length - 1);
        } else if (last == ')' &&
            '('.allMatches(raw).length < ')'.allMatches(raw).length) {
          raw = raw.substring(0, raw.length - 1);
        } else {
          break;
        }
      }
      final uri = _uriFor(raw);
      if (uri == null) continue;
      if (match.start > pos) {
        out.add(TextLinkSegment(text.substring(pos, match.start)));
      }
      out.add(TextLinkSegment(raw, uri: uri));
      pos = match.start + raw.length;
    }
    if (pos < text.length) out.add(TextLinkSegment(text.substring(pos)));
    return out;
  }

  static bool hasLinks(String text) => _link.hasMatch(text);

  static Uri? _uriFor(String raw) {
    final lower = raw.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final uri = Uri.tryParse(raw);
      return uri != null && uri.host.isNotEmpty ? uri : null;
    }
    if (lower.startsWith('www.')) {
      return raw.length > 4 ? Uri.tryParse('https://$raw') : null;
    }
    if (raw.contains('@')) return Uri(scheme: 'mailto', path: raw);
    return null;
  }

  /// Pictographic start of a grapheme, or a regional-indicator flag. Kept
  /// in a constant: the analyzer's regexp lint does not know `\p{…}`.
  static const _pictographicPattern =
      r'^(?:\p{Extended_Pictographic}|[\u{1F1E6}-\u{1F1FF}])';
  static final _pictographic = RegExp(_pictographicPattern, unicode: true);

  /// True for 1…[max] emoji and nothing else (whitespace ignored).
  static bool isEmojiOnly(String text, {int max = 3}) {
    final graphemes = text.characters.where((g) => g.trim().isNotEmpty);
    var count = 0;
    for (final g in graphemes) {
      if (!_pictographic.hasMatch(g)) return false;
      if (++count > max) return false;
    }
    return count > 0;
  }
}
