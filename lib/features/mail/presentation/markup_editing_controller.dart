import 'package:flutter/material.dart';

import '../../../core/platform/desktop_shell.dart';
import '../domain/mail_markup.dart';

/// Desktop composer body: the text is still [MailMarkup] (what is sent,
/// saved as a draft and previewed does not change), but the field shows it
/// formatted — bold, italic, underline, strike, links, quotes, bullets,
/// text colour and highlight, table rows in a monospace font — with
/// the markers themselves drawn invisible, so it reads like the web's rich
/// text editor. Every character keeps its place, so the caret and selection
/// map one to one onto the markup.
class MailMarkupEditingController extends TextEditingController {
  MailMarkupEditingController({super.text});

  /// Colours for links, quotes and list bullets (set by the composer).
  Color linkColor = const Color(0xFF2879C7);
  Color quoteColor = const Color(0xFF44474C);

  /// Table bars and the dashed header line.
  Color tableRuleColor = const Color(0xFF8A8D91);

  /// Text on a highlight with no colour of its own: recipients see the
  /// default black on it, so the editor shows the same in a dark theme.
  static const highlightTextColor = Color(0xFF202124);

  static const _mono = TextStyle(fontFamily: 'monospace', fontFamilyFallback: ['Consolas', 'Menlo', 'DejaVu Sans Mono', 'Courier New']);

  /// Misspelled words (ComposeSpellChecker), drawn with a red wavy underline.
  List<SpellingIssue> spelling = const [];
  Color spellingColor = const Color(0xFFDC2626);

  static const _hidden = TextStyle(color: Color(0x00000000), fontSize: 0.1, letterSpacing: 0);

  static final _inline = <(RegExp, TextStyle Function(TextStyle), int)>[
    // (pattern, style of the inner text, marker length on each side)
    (RegExp(r'\*\*(?=\S)(.+?)(?<=\S)\*\*'), (s) => s.copyWith(fontWeight: FontWeight.w700), 2),
    (RegExp(r'__(?=\S)(.+?)(?<=\S)__'), (s) => s.copyWith(decoration: TextDecoration.underline), 2),
    (RegExp(r'~~(?=\S)(.+?)(?<=\S)~~'), (s) => s.copyWith(decoration: TextDecoration.lineThrough), 2),
    (RegExp(r'(?<![\p{L}\p{N}_\\])_(?![_\s])(.+?)(?<![_\s\\])_(?![\p{L}\p{N}_])', unicode: true), (s) => s.copyWith(fontStyle: FontStyle.italic), 1),
  ];
  static final _link = RegExp(r'\[([^\]\n]+)\]\(([^)\s]+)\)');
  static final _list = RegExp(r'^( *)([-*])( )');
  static final _quote = RegExp(r'^( {0,3}>+ ?)');

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final base = style ?? const TextStyle();
    // IME composition (e.g. a keyboard layout that composes) keeps the plain
    // rendering, so the composing underline stays where the platform puts it.
    if (withComposing && value.isComposingRangeValid) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    final children = <InlineSpan>[];
    final lines = text.split('\n');
    // Table rows count only in runs of two or more, as MailMarkup reads them.
    final rows = [for (final l in lines) MailMarkup.isTableRow(_withoutQuote(l))];
    for (var i = 0; i < lines.length; i++) {
      final table = rows[i] && ((i > 0 && rows[i - 1]) || (i + 1 < lines.length && rows[i + 1]));
      _line(lines[i], base, children, table: table);
      if (i < lines.length - 1) children.add(TextSpan(text: '\n', style: base));
    }
    return TextSpan(style: base, children: spelling.isEmpty ? children : _underline(children));
  }

  /// The flat spans again, split where a misspelled word starts or ends; the
  /// word's pieces keep their formatting and get the wavy underline.
  List<InlineSpan> _underline(List<InlineSpan> spans) {
    final out = <InlineSpan>[];
    var offset = 0;
    for (final span in spans) {
      if (span is! TextSpan || span.text == null || span.style == _hidden) {
        out.add(span);
        offset += span is TextSpan ? (span.text?.length ?? 0) : 1;
        continue;
      }
      final text = span.text!;
      final end = offset + text.length;
      var cut = offset;
      for (final issue in spelling) {
        if (issue.end <= cut || issue.start >= end) continue;
        final from = issue.start.clamp(cut, end);
        final to = issue.end.clamp(cut, end);
        if (from > cut) out.add(TextSpan(text: text.substring(cut - offset, from - offset), style: span.style));
        final style = span.style ?? const TextStyle();
        out.add(
          TextSpan(
            text: text.substring(from - offset, to - offset),
            style: style.copyWith(
              decoration: TextDecoration.combine([
                if (style.decoration != null && style.decoration != TextDecoration.none) style.decoration!,
                TextDecoration.underline,
              ]),
              decorationStyle: TextDecorationStyle.wavy,
              decorationColor: spellingColor,
            ),
          ),
        );
        cut = to;
      }
      if (cut < end) out.add(TextSpan(text: text.substring(cut - offset), style: span.style));
      offset = end;
    }
    return out;
  }

  String _withoutQuote(String line) {
    final quote = _quote.firstMatch(line);
    return quote == null ? line : line.substring(quote.end);
  }

  void _line(String line, TextStyle base, List<InlineSpan> out, {bool table = false}) {
    var rest = line;
    var style = base;
    final quote = _quote.firstMatch(rest);
    if (quote != null) {
      out.add(TextSpan(text: quote.group(1), style: _hidden));
      rest = rest.substring(quote.end);
      style = base.copyWith(color: quoteColor, fontStyle: FontStyle.italic);
    }
    if (table) {
      _tableRow(rest, style.merge(_mono), out);
      return;
    }
    final list = _list.firstMatch(rest);
    if (list != null) {
      // «- » → «• »: one character for one, so offsets stay the same.
      out.add(TextSpan(text: list.group(1), style: style));
      out.add(TextSpan(text: '•', style: style.copyWith(fontWeight: FontWeight.w700, color: linkColor)));
      out.add(TextSpan(text: list.group(3), style: style));
      rest = rest.substring(list.end);
    }
    _inlineSpans(rest, style, out);
  }

  /// A table row in the monospace font: bars and a dashed header line drawn
  /// muted, the cells formatted as usual. Every character stays.
  void _tableRow(String row, TextStyle style, List<InlineSpan> out) {
    final rule = style.copyWith(color: tableRuleColor);
    if (MailMarkup.isTableSeparator(row)) {
      out.add(TextSpan(text: row, style: rule));
      return;
    }
    var cell = 0;
    for (var j = 0; j < row.length; j++) {
      if (row[j] == r'\') {
        j++;
        continue;
      }
      if (row[j] == '|') {
        if (j > cell) _inlineSpans(row.substring(cell, j), style, out);
        out.add(TextSpan(text: '|', style: rule));
        cell = j + 1;
      }
    }
    if (cell < row.length) _inlineSpans(row.substring(cell), style, out);
  }

  /// The first colour span at or after [from] whose `[` is not escaped.
  static (int, ColorSpanMatch)? _colorSpan(String s, int from) {
    for (var j = s.indexOf('[', from); j >= 0; j = s.indexOf('[', j + 1)) {
      var slashes = 0;
      for (var k = j - 1; k >= 0 && s[k] == r'\'; k--) {
        slashes++;
      }
      if (slashes.isOdd) continue;
      final m = MailMarkup.matchColorSpan(s, j);
      if (m != null) return (j, m);
    }
    return null;
  }

  static Color _color(String hex) => Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));

  void _inlineSpans(String s, TextStyle style, List<InlineSpan> out) {
    var pos = 0;
    while (pos < s.length) {
      final colored = _colorSpan(s, pos);
      // The earliest construct from here.
      RegExpMatch? best;
      TextStyle Function(TextStyle)? bestStyle;
      var bestMarker = 0;
      var isLink = false;
      for (final (re, st, marker) in _inline) {
        final m = re.firstMatch(s.substring(pos));
        if (m != null && (best == null || m.start < best.start)) {
          best = m;
          bestStyle = st;
          bestMarker = marker;
          isLink = false;
        }
      }
      final link = _link.firstMatch(s.substring(pos));
      if (link != null && (best == null || link.start < best.start)) {
        best = link;
        isLink = true;
      }
      if (colored != null && (best == null || colored.$1 - pos <= best.start)) {
        final (at, m) = colored;
        if (at > pos) out.add(TextSpan(text: s.substring(pos, at), style: style));
        out.add(const TextSpan(text: '[', style: _hidden));
        final inner = style.copyWith(
          color: m.color != null ? _color(m.color!) : (m.background != null ? highlightTextColor : null),
          backgroundColor: m.background != null ? _color(m.background!) : null,
        );
        _inlineSpans(s.substring(m.innerStart, m.innerEnd), inner, out);
        out.add(TextSpan(text: s.substring(m.innerEnd, m.end), style: _hidden));
        pos = m.end;
        continue;
      }
      if (best == null) {
        out.add(TextSpan(text: s.substring(pos), style: style));
        return;
      }
      if (best.start > 0) out.add(TextSpan(text: s.substring(pos, pos + best.start), style: style));
      if (isLink) {
        final label = best.group(1)!;
        out.add(const TextSpan(text: '[', style: _hidden));
        _inlineSpans(label, style.copyWith(color: linkColor, decoration: TextDecoration.underline, decorationColor: linkColor), out);
        out.add(TextSpan(text: '](${best.group(2)})', style: _hidden));
      } else {
        final marker = best.group(0)!.substring(0, bestMarker);
        out.add(TextSpan(text: marker, style: _hidden));
        _inlineSpans(best.group(1)!, bestStyle!(style), out);
        out.add(TextSpan(text: marker, style: _hidden));
      }
      pos += best.end;
    }
  }
}
