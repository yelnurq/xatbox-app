import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Desktop reading pane: somebody else's HTML mail, prepared the way the web
/// client shows it (`apps/web/src/lib/mail-html.ts`). The web keeps the
/// message's stylesheet inside a shadow root; the Flutter renderer has no
/// stylesheets, so the rules are applied to the elements they select
/// (inlined), which is what mail clients without `<style>` support do. The
/// message's own inline styles stay — dropping them is what turned designed
/// messages into loose fragments. Remote images load, as on the web; `cid:`
/// pictures come from the message's own attachments.
///
/// Everything here is pure (unit-tested).
abstract final class MailHtml {
  /// Elements that never render: active content, forms, embedded documents.
  static const _drop = {
    'script', 'style', 'iframe', 'object', 'embed', 'template', 'noscript',
    'form', 'input', 'button', 'textarea', 'select', 'link', 'meta', 'base',
    'frame', 'frameset', 'applet', 'audio', 'video', 'source', 'track',
    'canvas', 'map', 'area', 'title', 'svg', 'math',
  };

  static final _unsafeUrl = RegExp(r'^\s*(javascript|vbscript|data:(?!image/))', caseSensitive: false);

  /// The body to render: the HTML part, else HTML that arrived as text (some
  /// senders put markup in text/plain) or as a raw MIME part, else null
  /// (plain text).
  static String? htmlOf({required String bodyHtml, required String bodyText}) {
    if (bodyHtml.trim().isNotEmpty) return bodyHtml;
    final text = bodyText.trim();
    if (text.isEmpty) return null;
    final part = rawMimeHtml(text);
    if (part != null) return part;
    if (looksLikeHtml(text)) return decodeEntities(text);
    return null;
  }

  /// The web's `looksLikeHtml`: tags, or escaped markup.
  static bool looksLikeHtml(String value) =>
      RegExp(r'<\/?[a-z][\s\S]*>', caseSensitive: false).hasMatch(value) ||
      RegExp(r'&(lt|gt|amp|quot|#39);', caseSensitive: false).hasMatch(value);

  static String decodeEntities(String value) => value
      .replaceAll(RegExp('&nbsp;', caseSensitive: false), ' ')
      .replaceAll(RegExp('&lt;', caseSensitive: false), '<')
      .replaceAll(RegExp('&gt;', caseSensitive: false), '>')
      .replaceAll(RegExp('&quot;', caseSensitive: false), '"')
      .replaceAll(RegExp('&#39;', caseSensitive: false), "'")
      .replaceAll(RegExp('&amp;', caseSensitive: false), '&');

  /// A text body that is really an undecoded MIME part (`Content-Type:
  /// text/html` headers, then the encoded HTML): the decoded HTML, else null.
  static String? rawMimeHtml(String text) {
    final header = RegExp(r'^content-type:\s*text/html[^\n]*$', caseSensitive: false, multiLine: true).firstMatch(text);
    if (header == null) return null;
    final rest = text.substring(header.start).replaceAll('\r\n', '\n');
    final gap = rest.indexOf('\n\n');
    if (gap < 0) return null;
    final headers = rest.substring(0, gap).toLowerCase();
    var body = rest.substring(gap + 2);
    // The part ends at the next boundary line.
    final boundary = RegExp(r'^--[^\n]+$', multiLine: true).firstMatch(body);
    if (boundary != null) body = body.substring(0, boundary.start);
    try {
      if (headers.contains('content-transfer-encoding: base64')) {
        return utf8.decode(base64.decode(body.replaceAll(RegExp(r'\s'), '')), allowMalformed: true);
      }
      if (headers.contains('content-transfer-encoding: quoted-printable')) return decodeQuotedPrintable(body);
    } on FormatException {
      return null;
    }
    return body;
  }

  /// RFC 2045 quoted-printable, UTF-8 text.
  static String decodeQuotedPrintable(String input) {
    final bytes = <int>[];
    final s = input.replaceAll(RegExp(r'=\r?\n'), '');
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '=' && i + 2 < s.length) {
        final v = int.tryParse(s.substring(i + 1, i + 3), radix: 16);
        if (v != null) {
          bytes.add(v);
          i += 2;
          continue;
        }
      }
      bytes.addAll(utf8.encode(c));
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// The prepared body: styles inlined, markup cleaned, images resolved.
  /// [cidFiles] maps a Content-ID to a local file (downloaded inline
  /// pictures); unresolved `cid:` pictures are left out.
  static String prepare(String rawHtml, {Map<String, String> cidFiles = const {}}) {
    final doc = html_parser.parse(rawHtml);
    final sheets = [for (final s in doc.querySelectorAll('style')) cleanCss(s.text)];
    _inline(doc, sheets.join('\n'));
    final body = doc.body;
    if (body == null) return '';
    _clean(body, cidFiles);
    return body.innerHtml;
  }

  /// Content-IDs the HTML draws (`src="cid:…"`), so those attachments are
  /// pictures in the text, not files to list.
  static Set<String> referencedCids(String rawHtml) => {
    for (final m in RegExp(r'''src\s*=\s*["']?cid:([^"'\s>]+)''', caseSensitive: false).allMatches(rawHtml))
      _cid(m.group(1)!),
  };

  static String _cid(String value) {
    var v = value.trim();
    try {
      v = Uri.decodeComponent(v);
    } on ArgumentError {
      // Not %-encoded after all.
    }
    return v.replaceAll(RegExp('^<|>\$'), '').toLowerCase();
  }

  /// The web's `cleanEmailCss`, plus what the Flutter renderer cannot take.
  static String cleanCss(String css) => css
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'@(import|charset|font-face)[^;{}]*(;|\{[^}]*\})?', caseSensitive: false), '')
      .replaceAll(RegExp(r'expression\s*\(', caseSensitive: false), 'none(')
      .replaceAll(RegExp(r'behaviou?r\s*:', caseSensitive: false), '--was-behavior:')
      .replaceAll(RegExp(r'position\s*:\s*(fixed|absolute|sticky)', caseSensitive: false), 'position: static')
      .replaceAll(RegExp(r'''url\(\s*(['"]?)\s*(?:javascript|vbscript|data:text/html)''', caseSensitive: false), r'url($1about:blank#');

  /// `selector, selector { declarations }` rules of [css], outside `@media`
  /// blocks (those are for phones and print) (pure, unit-tested).
  static List<({String selectors, String declarations})> rules(String input) {
    final css = input.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
    final out = <({String selectors, String declarations})>[];
    var i = 0;
    while (i < css.length) {
      final open = css.indexOf('{', i);
      if (open < 0) break;
      final head = css.substring(i, open).trim();
      // The matching brace, counting nested blocks.
      var depth = 1;
      var j = open + 1;
      while (j < css.length && depth > 0) {
        if (css[j] == '{') depth++;
        if (css[j] == '}') depth--;
        j++;
      }
      final inner = css.substring(open + 1, (j - 1).clamp(open + 1, css.length));
      if (head.startsWith('@')) {
        // @media screen / all without a width limit applies to a desktop.
        final media = head.toLowerCase();
        if (media.startsWith('@media') && !media.contains('max-width') && !media.contains('print') && !media.contains('max-device')) {
          out.addAll(rules(inner));
        }
      } else if (head.isNotEmpty) {
        out.add((selectors: head, declarations: inner.trim()));
      }
      i = j;
    }
    return out;
  }

  /// Specificity of one selector: (ids, classes/attributes/pseudo-classes,
  /// elements) folded into one number.
  static int specificity(String selector) {
    final ids = RegExp('#[\\w-]+').allMatches(selector).length;
    final classes = RegExp(r'\.[\w-]+|\[[^\]]*\]|:(?!:)[\w-]+').allMatches(selector).length;
    final tags = RegExp(r'(?:^|[\s>+~])([a-zA-Z][\w-]*)').allMatches(selector).length;
    return ids * 10000 + classes * 100 + tags;
  }

  static void _inline(dom.Document doc, String css) {
    if (css.trim().isEmpty) return;
    final normal = <dom.Element, List<(int, int, String)>>{};
    final important = <dom.Element, List<(int, int, String)>>{};
    var order = 0;
    for (final rule in rules(css)) {
      final decls = rule.declarations.split(';').map((d) => d.trim()).where((d) => d.contains(':')).toList();
      if (decls.isEmpty) continue;
      final plain = [for (final d in decls) if (!d.toLowerCase().contains('!important')) d].join('; ');
      final strong = [
        for (final d in decls)
          if (d.toLowerCase().contains('!important')) d.replaceAll(RegExp(r'\s*!important', caseSensitive: false), ''),
      ].join('; ');
      for (final raw in rule.selectors.split(',')) {
        final selector = raw.trim();
        // Pseudo-elements and dynamic states have nothing to select here.
        if (selector.isEmpty || selector.contains('::') || RegExp(r':(hover|active|focus|visited|link|before|after)').hasMatch(selector)) {
          continue;
        }
        List<dom.Element> hits;
        try {
          hits = doc.querySelectorAll(selector);
        } on Object {
          continue; // a selector the parser does not know
        }
        final spec = specificity(selector);
        order++;
        for (final el in hits) {
          if (plain.isNotEmpty) (normal[el] ??= []).add((spec, order, plain));
          if (strong.isNotEmpty) (important[el] ??= []).add((spec, order, strong));
        }
      }
    }
    int byRank((int, int, String) a, (int, int, String) b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2);
    for (final el in {...normal.keys, ...important.keys}) {
      final before = (normal[el] ?? [])..sort(byRank);
      final after = (important[el] ?? [])..sort(byRank);
      final own = el.attributes['style']?.trim() ?? '';
      // Later declarations win: rules, then the element's own, then !important.
      el.attributes['style'] = [
        ...before.map((r) => r.$3),
        if (own.isNotEmpty) own,
        ...after.map((r) => r.$3),
      ].join('; ');
    }
  }

  static void _clean(dom.Element root, Map<String, String> cidFiles) {
    final cids = {for (final e in cidFiles.entries) e.key.toLowerCase(): e.value};
    for (final child in List<dom.Element>.from(root.children)) {
      final tag = child.localName?.toLowerCase() ?? '';
      if (_drop.contains(tag)) {
        child.remove();
        continue;
      }
      for (final entry in Map<Object, String>.from(child.attributes).entries) {
        final name = entry.key.toString().toLowerCase();
        final value = entry.value;
        if (name.startsWith('on') || name == 'srcset' || name == 'formaction') {
          child.attributes.remove(entry.key);
        } else if (name == 'style') {
          child.attributes[entry.key] = cleanCss(value);
        } else if ((name == 'href' || name == 'src' || name == 'xlink:href' || name == 'background') &&
            _unsafeUrl.hasMatch(value)) {
          child.attributes.remove(entry.key);
        }
      }
      if (tag == 'img') {
        final src = child.attributes['src']?.trim() ?? '';
        if (src.toLowerCase().startsWith('cid:')) {
          final file = cids[_cid(src.substring(4))];
          if (file == null) {
            child.remove();
            continue;
          }
          child.attributes['src'] = Uri.file(file).toString();
        } else if (!RegExp(r'^(https?:|data:image/|file:)', caseSensitive: false).hasMatch(src)) {
          child.remove();
          continue;
        }
        // Pictures never push the text wider than the pane.
        final style = child.attributes['style'] ?? '';
        if (!style.contains('max-width')) child.attributes['style'] = '${style.isEmpty ? '' : '$style; '}max-width: 100%; height: auto';
      }
      if (tag == 'a') {
        child.attributes['rel'] = 'noopener noreferrer';
        child.attributes.remove('target');
      }
      _clean(child, cidFiles);
    }
  }
}
