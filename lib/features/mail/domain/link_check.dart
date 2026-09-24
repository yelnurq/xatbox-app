import 'package:html/parser.dart' as html_parser;

/// The web reading pane's link check (`message-pane.tsx` `onBodyClick`): a
/// link whose visible text names a different host than the one it opens is
/// confirmed first; every other link opens straight away.
abstract final class LinkCheck {
  static final _hostInText = RegExp(r'^(?:https?://)?([a-z0-9-]+(?:\.[a-z0-9-]+)+)(?:[/?#]|$)', caseSensitive: false);

  /// The host a URL opens, without `www.` ('' when it has none).
  static String hostOf(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.host.isEmpty) return '';
    return _noWww(uri.host.toLowerCase());
  }

  /// The host the visible text of a link names — "example.com",
  /// "https://bank.kz/login" — or '' when the text is not an address.
  static String hostInText(String text) {
    final m = _hostInText.firstMatch(text.trim());
    return m == null ? '' : _noWww(m.group(1)!.toLowerCase());
  }

  static String _noWww(String host) => host.startsWith('www.') ? host.substring(4) : host;

  /// The shown and the real host when [text] names a host other than the
  /// one [href] opens (a subdomain of the shown host is fine); null otherwise.
  static ({String shown, String real})? mismatch(String text, String href) {
    final shown = hostInText(text);
    final real = hostOf(href);
    if (shown.isEmpty || real.isEmpty || shown == real || real.endsWith('.$shown')) return null;
    return (shown: shown, real: real);
  }

  /// The visible texts of the links in [html], by `href`.
  static Map<String, List<String>> linkTexts(String html) {
    final texts = <String, List<String>>{};
    for (final a in html_parser.parse(html).querySelectorAll('a[href]')) {
      final href = a.attributes['href']!.trim();
      (texts[href] ??= []).add(a.text);
    }
    return texts;
  }

  /// The first mismatch of a link to [href] in [html] (the same address can
  /// be linked more than once), or null.
  static ({String shown, String real})? mismatchIn(String html, String href) {
    for (final text in linkTexts(html)[href.trim()] ?? const <String>[]) {
      final m = mismatch(text, href);
      if (m != null) return m;
    }
    return null;
  }
}
