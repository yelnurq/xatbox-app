import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// `body_html` from `GET /mail/messages/{id}` is NOT sanitized server-side.
/// This strips active content and blocks remote resources before rendering
/// (mirrors what the web client does with DOMPurify).
abstract final class HtmlSanitizer {
  static const _dropWithContent = {
    'script',
    'style',
    'iframe',
    'object',
    'embed',
    'template',
    'svg',
    'math',
    'noscript',
    'textarea',
    'select',
    'title',
    'head',
    'form',
    'input',
    'button',
    'link',
    'meta',
    'base',
    'frame',
    'frameset',
    'applet',
    'audio',
    'video',
    'source',
    'track',
    'canvas',
    'map',
    'area',
  };

  static final _shownImage = RegExp(r'^(https?://|data:image/)', caseSensitive: false);

  static final _unsafeUrl = RegExp(
    r'^\s*(javascript|vbscript|data):',
    caseSensitive: false,
  );

  /// Returns sanitized HTML and whether any remote content was removed.
  ///
  /// [remoteImages]: pictures the sender linked (`http(s):`, inline
  /// `data:image/`) stay, so the letter reads as it was sent (the web
  /// client and the desktop app show them too). Off for text taken into the
  /// composer.
  static SanitizedHtml sanitize(String rawHtml, {bool remoteImages = false}) {
    final doc = html_parser.parse(rawHtml);
    var blockedRemote = false;

    void walk(dom.Element el) {
      for (final child in List<dom.Element>.from(el.children)) {
        final tag = child.localName?.toLowerCase() ?? '';
        if (_dropWithContent.contains(tag)) {
          child.remove();
          continue;
        }
        final attrs = Map<Object, String>.from(child.attributes);
        for (final entry in attrs.entries) {
          final name = entry.key.toString().toLowerCase();
          final value = entry.value;
          if (name.startsWith('on') ||
              name == 'style' ||
              name == 'srcset' ||
              name == 'poster' ||
              name == 'background' ||
              name == 'formaction') {
            child.attributes.remove(entry.key);
          } else if ((name == 'href' ||
                  name == 'src' ||
                  name == 'action' ||
                  name == 'xlink:href') &&
              _unsafeUrl.hasMatch(value)) {
            child.attributes.remove(entry.key);
          }
        }
        if (tag == 'img') {
          final src = attrs.entries
                  .where((e) => e.key.toString().toLowerCase() == 'src')
                  .firstOrNull
                  ?.value
                  .trim() ??
              '';
          if (remoteImages && _shownImage.hasMatch(src)) {
            child.attributes['src'] = src;
          } else {
            // Blocked (or cid:, which the API cannot resolve): keep the alt.
            if (src.isNotEmpty) blockedRemote = true;
            child.attributes.remove('src');
          }
        }
        if (tag == 'a') {
          child.attributes['rel'] = 'noopener noreferrer';
          child.attributes.remove('target');
        }
        walk(child);
      }
    }

    final body = doc.body;
    if (body == null) {
      return const SanitizedHtml('', blockedRemoteContent: false);
    }
    walk(body);
    return SanitizedHtml(body.innerHtml, blockedRemoteContent: blockedRemote);
  }

  /// Plain-text approximation of an HTML body (fallback display / quoting).
  static String toPlainText(String rawHtml) {
    final doc = html_parser.parse(rawHtml);
    for (final tag in _dropWithContent) {
      for (final el in List<dom.Element>.from(doc.getElementsByTagName(tag))) {
        el.remove();
      }
    }
    for (final br in doc.getElementsByTagName('br')) {
      br.replaceWith(dom.Text('\n'));
    }
    for (final tag in const [
      'p',
      'div',
      'li',
      'tr',
      'h1',
      'h2',
      'h3',
      'h4',
      'blockquote',
    ]) {
      for (final el in doc.getElementsByTagName(tag)) {
        el.append(dom.Text('\n'));
      }
    }
    final text = doc.body?.text ?? '';
    return text
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}

class SanitizedHtml {
  const SanitizedHtml(this.html, {required this.blockedRemoteContent});
  final String html;
  final bool blockedRemoteContent;
}
