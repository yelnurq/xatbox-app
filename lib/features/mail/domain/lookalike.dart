/// Sender-domain checks against the user's own domain, the same as the web
/// reading pane (`message-pane.tsx`): homoglyphs are folded (Cyrillic
/// а/е/о/р/с/у/х, digit-for-letter tricks) before comparing, and a
/// one-character edit distance counts as a lookalike — "smart-osi.kz" vs
/// "smart-0si.kz" is exactly the trick phishing relies on.
abstract final class Lookalike {
  static const _homoglyphs = <String, String>{
    'а': 'a', 'е': 'e', 'о': 'o', 'р': 'p', 'с': 'c', 'у': 'y', 'х': 'x', 'і': 'i', 'ј': 'j',
    'ԁ': 'd', 'ѕ': 's', 'һ': 'h', 'ӏ': 'l', 'ԛ': 'q', 'ԝ': 'w',
    '0': 'o', '1': 'l', '3': 'e', '5': 's', '7': 't', '@': 'a', r'$': 's',
  };

  static String domainOf(String address) {
    final at = address.lastIndexOf('@');
    return at > 0 ? address.substring(at + 1).toLowerCase() : '';
  }

  static String fold(String domain) {
    final base = domain.toLowerCase().replaceAll('rn', 'm').replaceAll('vv', 'w');
    final out = StringBuffer();
    for (final ch in base.split('')) {
      out.write(_homoglyphs[ch] ?? ch);
    }
    return out.toString();
  }

  static int editDistance(String a, String b) {
    final prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      var diag = prev[0];
      prev[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final tmp = prev[j];
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        prev[j] = [prev[j] + 1, prev[j - 1] + 1, diag + cost].reduce((x, y) => x < y ? x : y);
        diag = tmp;
      }
    }
    return prev[b.length];
  }

  static String _stripTld(String d) => d.replaceFirst(RegExp(r'\.[a-z]{2,}(\.[a-z]{2})?$'), '');

  /// True when [senderDomain] imitates [ownDomain].
  static bool isLookalike(String senderDomain, String ownDomain) {
    if (senderDomain.isEmpty || ownDomain.isEmpty || senderDomain == ownDomain || ownDomain.length < 5) return false;
    final a = fold(senderDomain);
    final b = fold(ownDomain);
    if (a == b) return true;
    return editDistance(_stripTld(a), _stripTld(b)) <= 1;
  }

  /// `hostInText`: visible link text that names a host ("example.com",
  /// "https://bank.kz/login").
  static String hostInText(String text) {
    final m = RegExp(r'^(?:https?://)?([a-z0-9-]+(?:\.[a-z0-9-]+)+)(?:[/?#]|$)', caseSensitive: false).firstMatch(text.trim());
    return m == null ? '' : m.group(1)!.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  }

  static String hostOf(String url) {
    final uri = Uri.tryParse(url);
    return uri == null ? '' : uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  }
}
