import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Lightweight composer markup and its conversion to the HTML allow-list of
/// `POST /mail/send` (`p, div, br, b, strong, i, em, u, s, ul, ol, li,
/// a[href http/https/mailto], blockquote, span[style color/background-color],
/// table, thead, tbody, tr, th, td`).
///
/// Syntax (one construct per toolbar button):
/// * `**bold**`, `_italic_`, `__underline__`, `~~strike~~`
/// * `- item` / `* item` (bulleted), `1. item` (numbered); two leading
///   spaces per nesting level
/// * `> quote` (repeat `>` to nest)
/// * `[text](https://…)` — only `http`, `https` and `mailto` become links
/// * `[text]{color=#d93025}`, `[text]{bg=#fff475}`, or both
///   (`{color=#… bg=#…}`) — text colour and highlight; only six-digit hex
///   colours are read, anything else stays literal text
/// * `| a | b |` rows (two or more lines in a row) — a table; a second line
///   of dashes (`|---|---|`) makes the first row a header; `\|` is a literal
///   bar inside a cell
/// * `\*`, `\_`, … — a backslash keeps a marker literal
///
/// Everything that is not markup is HTML-escaped, so user text can never
/// produce tags or attributes.
abstract final class MailMarkup {
  /// Nesting cap for lists and quotes (the server flattens beyond 64).
  static const maxDepth = 8;

  /// Styles written on tables (the server writes the same ones itself).
  static const tableStyle = 'border-collapse:collapse';
  static const cellStyle = 'border:1px solid #ccc;padding:4px 8px';

  static final _quoteRe = RegExp(r'^ {0,3}>');
  static final _listRe = RegExp(r'^( *)([-*•]|(\d{1,9})[.)])[ \t]+(.*)$');
  static final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);
  static const _escapable = r'\*_~[]()>-.+#`!';
  static final _colorAttrs = RegExp(
    r'^\{(color|bg)=#([0-9a-fA-F]{6})(?: (color|bg)=#([0-9a-fA-F]{6}))?\}',
  );
  static final _separatorCell = RegExp(r'^\s*:?-+:?\s*$');

  /// Colours, highlight and tables (and `\|`) are read only for the desktop
  /// composer window (`rich: true`); everywhere else, the phone included,
  /// the markup means what it meant before. Set for one synchronous call.
  static bool _rich = false;

  static T _withRich<T>(bool rich, T Function() f) {
    final was = _rich;
    _rich = rich;
    try {
      return f();
    } finally {
      _rich = was;
    }
  }

  // ---- public API -----------------------------------------------------------

  /// Allow-listed HTML for `html`. Empty input gives an empty string.
  static String toHtml(String source, {bool rich = false}) {
    if (source.trim().isEmpty) return '';
    final out = StringBuffer();
    _withRich(rich, () => _renderHtml(_parseBlocks(_lines(source), 0), out));
    return out.toString();
  }

  /// Clean plain text for `text`: markers removed, list bullets rendered,
  /// links as `text (url)`, quotes keep the conventional `> ` prefix.
  static String toPlainText(String source, {bool rich = false}) {
    if (source.trim().isEmpty) return '';
    return _withRich(rich, () => _renderPlain(_parseBlocks(_lines(source), 0)).join('\n').trimRight());
  }

  /// `true` for `http://…`, `https://…` and `mailto:…` without characters
  /// that could break out of an attribute.
  static bool isSafeHref(String url) {
    final u = url.trim();
    if (u.isEmpty || u.length > 2048) return false;
    if (RegExp(r'''[\s<>"'`\\\x00-\x1F\x7F]''').hasMatch(u)) return false;
    final lower = u.toLowerCase();
    if (lower.startsWith('https://')) return u.length > 'https://'.length;
    if (lower.startsWith('http://')) return u.length > 'http://'.length;
    if (lower.startsWith('mailto:')) return u.length > 'mailto:'.length;
    return false;
  }

  /// A colour span `[text]{color=#… bg=#…}` whose `[` is at [i]: the inner
  /// text's bounds, the lowercase colours (either may be null) and the end
  /// of the whole construct. Brackets inside nest (a link may be coloured);
  /// a backslash escapes the next character. Null when [i] starts none.
  static ColorSpanMatch? matchColorSpan(String s, int i) {
    if (i >= s.length || s[i] != '[') return null;
    var depth = 0;
    var k = i + 1;
    while (k < s.length) {
      final c = s[k];
      if (c == r'\') {
        k += 2;
        continue;
      }
      if (c == '\n') return null;
      if (c == '[') depth++;
      if (c == ']') {
        if (depth == 0) break;
        depth--;
      }
      k++;
    }
    if (k >= s.length) return null;
    final m = _colorAttrs.firstMatch(s.substring(k + 1));
    if (m == null) return null;
    String? color;
    String? bg;
    for (final (key, value) in [(m[1], m[2]), (m[3], m[4])]) {
      if (key == null || value == null) continue;
      if (key == 'color') color = '#${value.toLowerCase()}';
      if (key == 'bg') bg = '#${value.toLowerCase()}';
    }
    return ColorSpanMatch(
      innerStart: i + 1,
      innerEnd: k,
      end: k + 1 + m.end,
      color: color,
      background: bg,
    );
  }

  /// The attribute block of a colour span, `{color=#… bg=#…}`; null when
  /// neither colour is set.
  static String? colorAttrs({String? color, String? background}) {
    final parts = [
      if (color != null) 'color=$color',
      if (background != null) 'bg=$background',
    ];
    return parts.isEmpty ? null : '{${parts.join(' ')}}';
  }

  /// `true` for a table row line: `|` first (up to three spaces before it)
  /// and an unescaped `|` last. A table needs two such lines in a row.
  static bool isTableRow(String line) {
    final t = line.trimRight();
    final lead = t.length - t.trimLeft().length;
    if (lead > 3 || t.length - lead < 2) return false;
    if (t[lead] != '|' || !t.endsWith('|')) return false;
    var slashes = 0;
    for (var j = t.length - 2; j >= 0 && t[j] == r'\'; j--) {
      slashes++;
    }
    return slashes.isEven;
  }

  /// The cells of a table row line, as markup (escapes kept).
  static List<String> tableCells(String line) {
    final t = line.trim();
    final body = t.substring(1, t.length - 1);
    final cells = <String>[];
    final buf = StringBuffer();
    for (var j = 0; j < body.length; j++) {
      final c = body[j];
      if (c == r'\' && j + 1 < body.length) {
        buf
          ..write(c)
          ..write(body[j + 1]);
        j++;
        continue;
      }
      if (c == '|') {
        cells.add(buf.toString().trim());
        buf.clear();
        continue;
      }
      buf.write(c);
    }
    cells.add(buf.toString().trim());
    return cells;
  }

  /// `|---|:--:|` — the line under a table's header row.
  static bool isTableSeparator(String line) =>
      isTableRow(line) && tableCells(line).every(_separatorCell.hasMatch);

  /// `#rgb`, `#rrggbb` or `rgb(r, g, b)` as lowercase `#rrggbb`; null for
  /// anything else.
  static String? normalizeColor(String raw) {
    final v = raw.trim().toLowerCase();
    final hex = RegExp(r'^#([0-9a-f]{3}|[0-9a-f]{6})$').firstMatch(v);
    if (hex != null) {
      final h = hex[1]!;
      return h.length == 6 ? '#$h' : '#${h.split('').map((c) => '$c$c').join()}';
    }
    final rgb = RegExp(
      r'^rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(?:,\s*(?:1|1\.0+|0?\.\d+|0)\s*)?\)$',
    ).firstMatch(v);
    if (rgb == null) return null;
    final ch = [rgb[1], rgb[2], rgb[3]].map((s) => int.parse(s!)).toList();
    if (ch.any((n) => n > 255)) return null;
    return '#${ch.map((n) => n.toRadixString(16).padLeft(2, '0')).join()}';
  }

  /// Best-effort reverse conversion for reopening a saved draft.
  static String fromHtml(String html, {bool rich = false}) {
    if (html.trim().isEmpty) return '';
    final fragment = html_parser.parseFragment(html);
    final lines = _withRich(rich, () => (_HtmlWalker()..walk(fragment.nodes)).finish());
    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }
    return lines.join('\n');
  }

  static String escapeHtml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  // ---- block level ----------------------------------------------------------

  static List<String> _lines(String source) => source
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map((l) {
        final m = RegExp(r'^[ \t]+').firstMatch(l);
        if (m == null) return l;
        return '${m.group(0)!.replaceAll('\t', '  ')}${l.substring(m.end)}';
      })
      .toList();

  static List<_Block> _parseBlocks(List<String> lines, int depth) {
    final out = <_Block>[];
    var i = 0;
    while (i < lines.length) {
      if (depth < maxDepth && _quoteRe.hasMatch(lines[i])) {
        final inner = <String>[];
        while (i < lines.length && _quoteRe.hasMatch(lines[i])) {
          inner.add(_stripQuote(lines[i]));
          i++;
        }
        out.add(_QuoteBlock(_parseBlocks(inner, depth + 1)));
        continue;
      }
      if (_rich &&
          isTableRow(lines[i]) &&
          i + 1 < lines.length &&
          isTableRow(lines[i + 1])) {
        final rows = <String>[];
        while (i < lines.length && isTableRow(lines[i])) {
          rows.add(lines[i]);
          i++;
        }
        out.add(_TableBlock.parse(rows));
        continue;
      }
      if (_listRe.hasMatch(lines[i])) {
        final items = <_ListLine>[];
        while (i < lines.length) {
          final m = _listRe.firstMatch(lines[i]);
          if (m == null) break;
          items.add(
            _ListLine(
              level: m.group(1)!.length ~/ 2,
              ordered: m.group(3) != null,
              text: m.group(4)!,
            ),
          );
          i++;
        }
        out.addAll(_buildLists(items, depth));
        continue;
      }
      out.add(_LineBlock(lines[i]));
      i++;
    }
    return out;
  }

  static String _stripQuote(String line) {
    final idx = line.indexOf('>');
    var rest = line.substring(idx + 1);
    if (rest.startsWith(' ')) rest = rest.substring(1);
    return rest;
  }

  static List<_ListBlock> _buildLists(List<_ListLine> lines, int depth) {
    final roots = <_ListBlock>[];
    final stack = <(_ListBlock, int)>[];
    for (final line in lines) {
      while (stack.isNotEmpty && stack.last.$2 > line.level) {
        stack.removeLast();
      }
      if (stack.isEmpty) {
        final list = _ListBlock(line.ordered);
        roots.add(list);
        stack.add((list, line.level));
      } else if (stack.last.$2 == line.level ||
          depth + stack.length >= maxDepth) {
        if (stack.last.$1.ordered != line.ordered) {
          final level = stack.last.$2;
          stack.removeLast();
          final list = _ListBlock(line.ordered);
          if (stack.isEmpty) {
            roots.add(list);
          } else {
            stack.last.$1.items.last.children.add(list);
          }
          stack.add((list, level));
        }
      } else {
        final list = _ListBlock(line.ordered);
        stack.last.$1.items.last.children.add(list);
        stack.add((list, line.level));
      }
      stack.last.$1.items.add(_ListItem(line.text));
    }
    return roots;
  }

  static void _renderHtml(List<_Block> blocks, StringBuffer out) {
    for (final b in blocks) {
      switch (b) {
        case _LineBlock(:final text):
          if (text.trim().isEmpty) {
            out.write('<div><br></div>');
          } else {
            out.write('<div>');
            _inlineHtml(_parseInline(text, allowLinks: true), out);
            out.write('</div>');
          }
        case _QuoteBlock(:final children):
          out.write('<blockquote>');
          _renderHtml(children, out);
          out.write('</blockquote>');
        case _ListBlock():
          _listHtml(b, out);
        case _TableBlock():
          _tableHtml(b, out);
      }
    }
  }

  static void _tableHtml(_TableBlock table, StringBuffer out) {
    void row(List<String> cells, String tag) {
      out.write('<tr>');
      for (var c = 0; c < table.columns; c++) {
        out.write('<$tag style="$cellStyle">');
        if (c < cells.length) {
          _inlineHtml(_parseInline(cells[c], allowLinks: true), out);
        }
        out.write('</$tag>');
      }
      out.write('</tr>');
    }

    out.write('<table style="$tableStyle">');
    if (table.header != null) {
      out.write('<thead>');
      row(table.header!, 'th');
      out.write('</thead>');
    }
    if (table.rows.isNotEmpty) {
      out.write('<tbody>');
      for (final r in table.rows) {
        row(r, 'td');
      }
      out.write('</tbody>');
    }
    out.write('</table>');
  }

  /// Rows as `| a   | b |` with the columns padded to one width, and a
  /// dashed line under a header, so the plain-text part still reads as a
  /// table in a monospace font.
  static void _tablePlain(_TableBlock table, List<String> lines) {
    List<String> plain(List<String> cells) => [
      for (var c = 0; c < table.columns; c++)
        c < cells.length
            ? _inlinePlain(_parseInline(cells[c], allowLinks: true))
            : '',
    ];
    final all = [if (table.header != null) plain(table.header!), ...table.rows.map(plain)];
    final widths = List.filled(table.columns, 1);
    for (final r in all) {
      for (var c = 0; c < table.columns; c++) {
        if (r[c].length > widths[c]) widths[c] = r[c].length;
      }
    }
    String line(List<String> cells) =>
        '| ${[for (var c = 0; c < table.columns; c++) cells[c].padRight(widths[c])].join(' | ')} |';
    for (var i = 0; i < all.length; i++) {
      lines.add(line(all[i]));
      if (i == 0 && table.header != null) {
        lines.add('|${widths.map((w) => '-' * (w + 2)).join('|')}|');
      }
    }
  }

  static void _listHtml(_ListBlock list, StringBuffer out) {
    final tag = list.ordered ? 'ol' : 'ul';
    out.write('<$tag>');
    for (final item in list.items) {
      out.write('<li>');
      _inlineHtml(_parseInline(item.text, allowLinks: true), out);
      for (final child in item.children) {
        _listHtml(child, out);
      }
      out.write('</li>');
    }
    out.write('</$tag>');
  }

  static List<String> _renderPlain(List<_Block> blocks) {
    final lines = <String>[];
    for (final b in blocks) {
      switch (b) {
        case _LineBlock(:final text):
          lines.add(_inlinePlain(_parseInline(text, allowLinks: true)));
        case _QuoteBlock(:final children):
          for (final l in _renderPlain(children)) {
            lines.add(l.isEmpty ? '>' : (l.startsWith('>') ? '>$l' : '> $l'));
          }
        case _ListBlock():
          _listPlain(b, 0, lines);
        case _TableBlock():
          _tablePlain(b, lines);
      }
    }
    return lines;
  }

  static void _listPlain(_ListBlock list, int level, List<String> lines) {
    var n = 0;
    for (final item in list.items) {
      n++;
      final marker = list.ordered ? '$n. ' : '• ';
      lines.add(
        '${'  ' * level}$marker${_inlinePlain(_parseInline(item.text, allowLinks: true))}',
      );
      for (final child in item.children) {
        _listPlain(child, level + 1, lines);
      }
    }
  }

  // ---- inline level ---------------------------------------------------------

  static bool _isWord(String s, int i) =>
      i >= 0 && i < s.length && _wordChar.hasMatch(s[i]);

  static bool _isSpace(String c) => c.trim().isEmpty;

  static const _markers = [('**', 'b'), ('__', 'u'), ('~~', 's'), ('_', 'i')];

  static List<_Inline> _parseInline(String s, {required bool allowLinks}) {
    final out = <_Inline>[];
    final buf = StringBuffer();
    void flush() {
      if (buf.isEmpty) return;
      out.add(_TextInline(buf.toString()));
      buf.clear();
    }

    var i = 0;
    outer:
    while (i < s.length) {
      final c = s[i];
      if (c == r'\' && i + 1 < s.length && (_escapable.contains(s[i + 1]) || (_rich && s[i + 1] == '|'))) {
        buf.write(s[i + 1]);
        i += 2;
        continue;
      }
      if (c == '[' && _rich) {
        final span = matchColorSpan(s, i);
        if (span != null) {
          flush();
          final inner = s.substring(span.innerStart, span.innerEnd);
          if (inner.isNotEmpty) {
            out.add(
              _ColorInline(
                span.color,
                span.background,
                _parseInline(inner, allowLinks: allowLinks),
              ),
            );
          }
          i = span.end;
          continue;
        }
      }
      if (c == '[' && allowLinks) {
        final link = _matchLink(s, i);
        if (link != null) {
          flush();
          out.add(
            _LinkInline(link.$2, _parseInline(link.$1, allowLinks: false)),
          );
          i = link.$3;
          continue;
        }
      }
      if (c == '*' || c == '_' || c == '~') {
        for (final (marker, tag) in _markers) {
          if (!s.startsWith(marker, i)) continue;
          // `__x` is tried only as underline, never re-read as `_`.
          if (marker == '_' && s.startsWith('__', i)) break;
          final close = _findClose(s, i, marker);
          if (close != null) {
            flush();
            out.add(
              _StyledInline(
                tag,
                _parseInline(
                  s.substring(i + marker.length, close),
                  allowLinks: allowLinks,
                ),
              ),
            );
            i = close + marker.length;
            continue outer;
          }
          break;
        }
        // Unmatched: keep the whole run of marker characters literal.
        var j = i;
        while (j < s.length && s[j] == c) {
          j++;
        }
        buf.write(s.substring(i, j));
        i = j;
        continue;
      }
      buf.write(c);
      i++;
    }
    flush();
    return out;
  }

  static int? _findClose(String s, int open, String marker) {
    final start = open + marker.length;
    if (start >= s.length || _isSpace(s[start])) return null;
    if (_isWord(s, open - 1)) return null;
    final ch = marker[0];
    if (open > 0 && s[open - 1] == ch) return null;
    var j = start + 1;
    while (j < s.length) {
      if (s[j] == r'\') {
        j += 2;
        continue;
      }
      if (s.startsWith(marker, j) &&
          !_isSpace(s[j - 1]) &&
          !_isWord(s, j + marker.length) &&
          (j + marker.length >= s.length || s[j + marker.length] != ch)) {
        return j;
      }
      j++;
    }
    return null;
  }

  /// `[text](url)` starting at [i] → (text, url, end) when the URL is safe.
  static (String, String, int)? _matchLink(String s, int i) {
    var k = i + 1;
    while (k < s.length && s[k] != ']') {
      if (s[k] == r'\') k++;
      k++;
    }
    if (k >= s.length - 1 || s[k + 1] != '(') return null;
    final text = s.substring(i + 1, k);
    final urlStart = k + 2;
    final urlEnd = s.indexOf(')', urlStart);
    if (urlEnd < 0) return null;
    final url = s.substring(urlStart, urlEnd).trim();
    if (text.trim().isEmpty || !isSafeHref(url)) return null;
    return (text, url, urlEnd + 1);
  }

  static void _inlineHtml(List<_Inline> nodes, StringBuffer out) {
    for (final n in nodes) {
      switch (n) {
        case _TextInline(:final text):
          out.write(escapeHtml(text));
        case _StyledInline(:final tag, :final children):
          out.write('<$tag>');
          _inlineHtml(children, out);
          out.write('</$tag>');
        case _LinkInline(:final href, :final children):
          out.write('<a href="${escapeHtml(href)}">');
          _inlineHtml(children, out);
          out.write('</a>');
        case _ColorInline(:final color, :final background, :final children):
          // Both values are `#` and six hex digits (matchColorSpan).
          final decl = [
            if (color != null) 'color:$color',
            if (background != null) 'background-color:$background',
          ].join(';');
          out.write('<span style="$decl">');
          _inlineHtml(children, out);
          out.write('</span>');
      }
    }
  }

  static String _inlinePlain(List<_Inline> nodes) {
    final out = StringBuffer();
    for (final n in nodes) {
      switch (n) {
        case _TextInline(:final text):
          out.write(text);
        case _StyledInline(:final children):
          out.write(_inlinePlain(children));
        case _ColorInline(:final children):
          out.write(_inlinePlain(children));
        case _LinkInline(:final href, :final children):
          final text = _inlinePlain(children);
          final bare = href.toLowerCase().startsWith('mailto:')
              ? href.substring(7)
              : href;
          out.write(text == href || text == bare ? text : '$text ($href)');
      }
    }
    return out.toString();
  }
}

/// Where a colour span sits in a line (see [MailMarkup.matchColorSpan]).
class ColorSpanMatch {
  const ColorSpanMatch({
    required this.innerStart,
    required this.innerEnd,
    required this.end,
    this.color,
    this.background,
  });

  /// The text between `[` and `]`.
  final int innerStart;
  final int innerEnd;

  /// Just after the closing `}`.
  final int end;

  /// `#rrggbb`, lowercase.
  final String? color;
  final String? background;
}

// ---- AST ---------------------------------------------------------------------

sealed class _Block {}

class _TableBlock extends _Block {
  _TableBlock(this.header, this.rows, this.columns);

  /// Rows of markup cells; a separator under the first row makes it a
  /// header, other separator lines are dropped.
  factory _TableBlock.parse(List<String> lines) {
    List<String>? header;
    final rows = <List<String>>[];
    for (var i = 0; i < lines.length; i++) {
      if (MailMarkup.isTableSeparator(lines[i])) {
        if (i == 1 && header == null && rows.length == 1) {
          header = rows.removeAt(0);
        }
        continue;
      }
      rows.add(MailMarkup.tableCells(lines[i]));
    }
    var columns = header?.length ?? 1;
    for (final r in rows) {
      if (r.length > columns) columns = r.length;
    }
    return _TableBlock(header, rows, columns.clamp(1, _maxColumns));
  }

  static const _maxColumns = 30;

  final List<String>? header;
  final List<List<String>> rows;
  final int columns;
}

class _LineBlock extends _Block {
  _LineBlock(this.text);
  final String text;
}

class _QuoteBlock extends _Block {
  _QuoteBlock(this.children);
  final List<_Block> children;
}

class _ListBlock extends _Block {
  _ListBlock(this.ordered);
  final bool ordered;
  final List<_ListItem> items = [];
}

class _ListItem {
  _ListItem(this.text);
  final String text;
  final List<_ListBlock> children = [];
}

class _ListLine {
  const _ListLine({
    required this.level,
    required this.ordered,
    required this.text,
  });
  final int level;
  final bool ordered;
  final String text;
}

sealed class _Inline {}

class _TextInline extends _Inline {
  _TextInline(this.text);
  final String text;
}

class _StyledInline extends _Inline {
  _StyledInline(this.tag, this.children);
  final String tag;
  final List<_Inline> children;
}

class _LinkInline extends _Inline {
  _LinkInline(this.href, this.children);
  final String href;
  final List<_Inline> children;
}

class _ColorInline extends _Inline {
  _ColorInline(this.color, this.background, this.children);
  final String? color;
  final String? background;
  final List<_Inline> children;
}

// ---- HTML → markup -------------------------------------------------------------

class _HtmlWalker {
  final List<String> lines = [];
  final StringBuffer _buf = StringBuffer();

  static const _drop = {
    'script',
    'style',
    'head',
    'title',
    'template',
    'svg',
    'math',
    'noscript',
    'iframe',
    'object',
    'embed',
    'textarea',
    'select',
    'form',
    'button',
  };
  static const _blockTags = {
    'div',
    'p',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'tr',
    'table',
    'section',
    'article',
    'header',
    'footer',
    'pre',
  };

  void _flush() {
    if (_buf.isEmpty) return;
    lines.add(_buf.toString());
    _buf.clear();
  }

  List<String> finish() {
    _flush();
    return lines;
  }

  static String _escapeText(String t) {
    var s = t.replaceAll(RegExp(r'\s+'), ' ');
    for (final m in const ['**', '__', '~~']) {
      s = s.replaceAll(m, m.split('').map((c) => '\\$c').join());
    }
    return s;
  }

  static List<String> _sub(List<dom.Node> nodes) =>
      (_HtmlWalker()..walk(nodes)).finish();

  void walk(List<dom.Node> nodes) {
    for (final node in nodes) {
      if (node is dom.Text) {
        final text = _escapeText(node.text);
        if (_buf.isEmpty) {
          final trimmed = text.trimLeft();
          if (trimmed.isEmpty) continue;
          // Keep a text line from being read back as a list or quote.
          if (RegExp(r'^([-*>•]|\d+[.)])(\s|$)').hasMatch(trimmed)) {
            _buf.write('\\');
          }
          _buf.write(trimmed);
        } else {
          _buf.write(text);
        }
        continue;
      }
      if (node is! dom.Element) continue;
      final tag = node.localName?.toLowerCase() ?? '';
      if (_drop.contains(tag)) continue;
      switch (tag) {
        case 'br':
          lines.add(_buf.toString());
          _buf.clear();
        case 'b' || 'strong':
          _wrap(node, '**');
        case 'i' || 'em':
          _wrap(node, '_');
        case 'u':
          _wrap(node, '__');
        case 's' || 'strike' || 'del':
          _wrap(node, '~~');
        case 'a':
          final href = node.attributes['href'] ?? '';
          final inner = _sub(node.nodes).join(' ').trim();
          if (MailMarkup.isSafeHref(href) && inner.isNotEmpty) {
            _buf.write('[$inner](${href.trim()})');
          } else {
            _buf.write(inner);
          }
        case 'blockquote':
          _flush();
          for (final l in _sub(node.nodes)) {
            lines.add(l.isEmpty ? '>' : '> $l');
          }
        case 'ul' || 'ol':
          _flush();
          _list(node, 0);
        case 'li':
          _flush();
          lines.add('- ${_sub(node.nodes).join(' ')}');
        case 'table' when MailMarkup._rich:
          _flush();
          _table(node);
        case 'span' || 'font' when MailMarkup._rich:
          final (color, background) = _colors(node);
          final attrs = MailMarkup.colorAttrs(color: color, background: background);
          if (attrs == null) {
            walk(node.nodes);
          } else {
            _wrapColor(node, attrs);
          }
        default:
          if (_blockTags.contains(tag)) {
            _flush();
            walk(node.nodes);
            _flush();
            if (tag == 'p') lines.add('');
          } else {
            walk(node.nodes);
          }
      }
    }
  }

  void _wrap(dom.Element el, String marker) {
    final parts = _sub(el.nodes);
    for (var i = 0; i < parts.length; i++) {
      final raw = parts[i];
      final t = raw.trim();
      if (t.isNotEmpty) {
        final lead = raw.startsWith(' ') && _buf.isNotEmpty ? ' ' : '';
        final trail = raw.endsWith(' ') ? ' ' : '';
        _buf.write('$lead$marker$t$marker$trail');
      }
      if (i < parts.length - 1) {
        lines.add(_buf.toString());
        _buf.clear();
      }
    }
  }

  /// The colour and highlight a span (or `<font color>`) sets, as `#rrggbb`.
  static (String?, String?) _colors(dom.Element el) {
    String? color;
    String? background;
    for (final decl in (el.attributes['style'] ?? '').split(';')) {
      final colon = decl.indexOf(':');
      if (colon < 0) continue;
      final prop = decl.substring(0, colon).trim().toLowerCase();
      final value = MailMarkup.normalizeColor(decl.substring(colon + 1));
      if (value == null) continue;
      if (prop == 'color') color = value;
      if (prop == 'background-color') background = value;
    }
    if (color == null && el.localName?.toLowerCase() == 'font') {
      color = MailMarkup.normalizeColor(el.attributes['color'] ?? '');
    }
    return (color, background);
  }

  static bool _balanced(String s) {
    var depth = 0;
    for (var i = 0; i < s.length; i++) {
      if (s[i] == r'\') {
        i++;
      } else if (s[i] == '[') {
        depth++;
      } else if (s[i] == ']' && --depth < 0) {
        return false;
      }
    }
    return depth == 0;
  }

  /// `[text]{color=…}` around each line of the span's text; text whose
  /// brackets do not pair up keeps no colour rather than break the markup.
  void _wrapColor(dom.Element el, String attrs) {
    final parts = _sub(el.nodes);
    for (var i = 0; i < parts.length; i++) {
      final raw = parts[i];
      final t = raw.trim();
      if (t.isNotEmpty) {
        final lead = raw.startsWith(' ') && _buf.isNotEmpty ? ' ' : '';
        final trail = raw.endsWith(' ') ? ' ' : '';
        _buf.write(_balanced(t) ? '$lead[$t]$attrs$trail' : '$lead$t$trail');
      }
      if (i < parts.length - 1) {
        lines.add(_buf.toString());
        _buf.clear();
      }
    }
  }

  /// Pipe rows; a first row of header cells gets the dashed line under it.
  void _table(dom.Element table) {
    final rows = <dom.Element>[];
    void collect(dom.Element el) {
      for (final child in el.children) {
        final tag = child.localName?.toLowerCase();
        if (tag == 'tr') {
          rows.add(child);
        } else if (tag == 'thead' || tag == 'tbody' || tag == 'tfoot') {
          collect(child);
        }
      }
    }

    collect(table);
    for (var r = 0; r < rows.length; r++) {
      final cells = rows[r].children
          .where((c) => c.localName == 'td' || c.localName == 'th')
          .toList();
      if (cells.isEmpty) continue;
      final texts = [
        for (final c in cells)
          _sub(c.nodes)
              .where((l) => l.trim().isNotEmpty)
              .join(' ')
              .trim()
              .replaceAllMapped(RegExp(r'(?<!\\)\|'), (_) => r'\|'),
      ];
      lines.add('| ${texts.join(' | ')} |');
      if (r == 0 && cells.every((c) => c.localName == 'th')) {
        lines.add('|${List.filled(cells.length, '---').join('|')}|');
      }
    }
  }

  void _list(dom.Element list, int level) {
    final ordered = list.localName?.toLowerCase() == 'ol';
    var n = 0;
    for (final child in list.children) {
      final tag = child.localName?.toLowerCase();
      if (tag == 'ul' || tag == 'ol') {
        _list(child, level + 1);
        continue;
      }
      if (tag != 'li') continue;
      n++;
      final nested = <dom.Element>[];
      final inline = <dom.Node>[];
      for (final node in child.nodes) {
        if (node is dom.Element &&
            (node.localName == 'ul' || node.localName == 'ol')) {
          nested.add(node);
        } else {
          inline.add(node);
        }
      }
      final text = _sub(inline).where((l) => l.trim().isNotEmpty).join(' ');
      lines.add('${'  ' * level}${ordered ? '$n.' : '-'} $text');
      for (final sub in nested) {
        _list(sub, level + 1);
      }
    }
  }
}
