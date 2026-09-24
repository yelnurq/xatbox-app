/// Pure helpers for `@mentions` in group chats (composer and bubbles).
///
/// The server stores mentions as a list of user ids next to the body; the
/// body itself keeps the human readable `@Name`. Everything here works on
/// UTF-16 offsets of Dart strings.
abstract final class ChatMentions {
  /// Longest query the picker still reacts to.
  static const maxQueryLength = 40;

  /// The mention being typed at [cursor]: the offset of its `@` and the text
  /// typed after it. `@` must start the text or follow whitespace; the query
  /// cannot contain whitespace.
  static ({int start, String query})? activeQuery(String text, int cursor) {
    if (cursor < 0 || cursor > text.length) return null;
    for (var i = cursor - 1; i >= 0 && cursor - i <= maxQueryLength + 1; i--) {
      final ch = text[i];
      if (ch == '@') {
        if (i > 0 && !_isSpace(text[i - 1])) return null;
        return (start: i, query: text.substring(i + 1, cursor));
      }
      if (_isSpace(ch)) return null;
    }
    return null;
  }

  /// Replaces the typed `@query` (from [start] to [cursor]) with `@label `
  /// and returns the new text and cursor position.
  static ({String text, int cursor}) insert(
    String text, {
    required int start,
    required int cursor,
    required String label,
  }) {
    final token = '@$label ';
    final rest = text.substring(cursor);
    // Do not double the space when the user already typed one.
    final tail = rest.startsWith(' ') ? rest.substring(1) : rest;
    final out = '${text.substring(0, start)}$token$tail';
    return (text: out, cursor: start + token.length);
  }

  /// Candidates whose label or e-mail matches [query] (case-insensitive).
  static List<T> filter<T>(
    Iterable<T> candidates,
    String query, {
    required String Function(T) label,
    String Function(T)? email,
    int limit = 6,
  }) {
    final q = query.toLowerCase();
    final out = <T>[];
    for (final c in candidates) {
      final l = label(c).toLowerCase();
      final matches =
          q.isEmpty ||
          l.startsWith(q) ||
          l.split(RegExp(r'\s+')).any((w) => w.startsWith(q)) ||
          (email?.call(c).toLowerCase().startsWith(q) ?? false);
      if (matches) out.add(c);
      if (out.length >= limit) break;
    }
    return out;
  }

  /// User ids from [picked] (id → label) whose `@label` is still in [text],
  /// in the order of first appearance.
  static List<String> resolve(String text, Map<String, String> picked) {
    final hits = <(int, String)>[];
    for (final e in picked.entries) {
      final at = _find(text, e.value, 0);
      if (at >= 0) hits.add((at, e.key));
    }
    hits.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final h in hits) h.$2];
  }

  /// Splits [body] into plain and mention segments. Only ids listed in the
  /// message and known in [names] are highlighted; longer names win when
  /// they overlap.
  static List<MentionSegment> segments(
    String body,
    Iterable<String> mentionIds,
    Map<String, String> names,
  ) {
    final ranges = <(int, int, String)>[];
    final ids = mentionIds.where((id) => (names[id] ?? '').isNotEmpty).toList()
      ..sort((a, b) => names[b]!.length.compareTo(names[a]!.length));
    for (final id in ids) {
      final label = names[id]!;
      var from = 0;
      while (true) {
        final at = _find(body, label, from);
        if (at < 0) break;
        final end = at + label.length + 1;
        if (!ranges.any((r) => at < r.$2 && end > r.$1)) {
          ranges.add((at, end, id));
        }
        from = end;
      }
    }
    if (ranges.isEmpty) return [MentionSegment(body)];
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    final out = <MentionSegment>[];
    var pos = 0;
    for (final r in ranges) {
      if (r.$1 > pos) out.add(MentionSegment(body.substring(pos, r.$1)));
      out.add(MentionSegment(body.substring(r.$1, r.$2), userId: r.$3));
      pos = r.$2;
    }
    if (pos < body.length) out.add(MentionSegment(body.substring(pos)));
    return out;
  }

  /// Offset of `@label` in [text] at a word boundary, or -1.
  static int _find(String text, String label, int from) {
    final needle = '@$label';
    var at = text.indexOf(needle, from);
    while (at >= 0) {
      final beforeOk = at == 0 || _isSpace(text[at - 1]);
      final after = at + needle.length;
      final afterOk = after >= text.length || !_isWordChar(text[after]);
      if (beforeOk && afterOk) return at;
      at = text.indexOf(needle, at + 1);
    }
    return -1;
  }

  static bool _isSpace(String ch) => ch.trim().isEmpty;

  static bool _isWordChar(String ch) =>
      RegExp(r'[\p{L}\p{N}_]', unicode: true).hasMatch(ch);
}

class MentionSegment {
  const MentionSegment(this.text, {this.userId});
  final String text;

  /// Set for a highlighted `@Name`.
  final String? userId;
  bool get isMention => userId != null;
}
