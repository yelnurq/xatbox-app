import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_html.dart';

void main() {
  group('which body renders', () {
    test('the HTML part; else markup that came as text; else plain text', () {
      expect(MailHtml.htmlOf(bodyHtml: '<p>a</p>', bodyText: 'a'), '<p>a</p>');
      expect(MailHtml.htmlOf(bodyHtml: '', bodyText: '<div><b>Привет</b></div>'), '<div><b>Привет</b></div>');
      expect(MailHtml.htmlOf(bodyHtml: '', bodyText: '&lt;p&gt;Текст&lt;/p&gt;'), '<p>Текст</p>');
      expect(MailHtml.htmlOf(bodyHtml: '', bodyText: 'Добрый день, коллеги'), isNull);
      expect(MailHtml.htmlOf(bodyHtml: '  ', bodyText: ''), isNull);
    });

    test('a raw MIME part in the text is decoded (quoted-printable, base64)', () {
      const qp =
          'This is a multi-part message\n--b1\nContent-Type: text/html; charset=utf-8\n'
          'Content-Transfer-Encoding: quoted-printable\n\n<p>=D0=9F=D1=80=D0=B8=\n=D0=B2=D0=B5=D1=82</p>\n--b1--';
      expect(MailHtml.htmlOf(bodyHtml: '', bodyText: qp)!.trim(), '<p>Привет</p>');
      final b64 =
          'Content-Type: text/html; charset=utf-8\nContent-Transfer-Encoding: base64\n\n'
          '${base64.encode(utf8.encode('<h1>Отчёт</h1>'))}\n';
      expect(MailHtml.htmlOf(bodyHtml: '', bodyText: b64), '<h1>Отчёт</h1>');
    });
  });

  group('stylesheet', () {
    test('rules outside phone and print media queries', () {
      final rules = MailHtml.rules('''
        /* comment */ .a, p { color: red }
        @media screen { .b { margin: 0 } }
        @media only screen and (max-width: 600px) { .a { display: none } }
        @media print { p { color: black } }
      ''');
      expect(rules.map((r) => r.selectors), ['.a, p', '.b']);
    });

    test('inlined by specificity and order; own style and !important win', () {
      final out = MailHtml.prepare('''
        <html><head><style>
          p { color: red; font-size: 12px }
          .lead { color: blue }
          #x { color: green }
          .hidden { display: none !important }
          a:hover { color: pink }
        </style></head>
        <body><p class="lead" id="x" style="font-size: 16px">t</p><span class="hidden" style="display: block">h</span></body></html>''');
      final p = RegExp(r'<p[^>]*style="([^"]*)"').firstMatch(out)!.group(1)!;
      // Later wins in the renderer: red → blue → green, then the element's own.
      expect(p.indexOf('red') < p.indexOf('blue') && p.indexOf('blue') < p.indexOf('green'), isTrue);
      expect(p.endsWith('font-size: 16px'), isTrue);
      final span = RegExp(r'<span[^>]*style="([^"]*)"').firstMatch(out)!.group(1)!;
      expect(span.endsWith('display: none'), isTrue, reason: '!important beats the inline style');
      expect(out, isNot(contains('<style')));
      expect(out, isNot(contains('pink')));
    });

    test('dangerous CSS is neutralised', () {
      final css = MailHtml.cleanCss('@import url(x.css); div { position: fixed; width: expression(alert(1)); background: url(javascript:x) }');
      expect(css, isNot(contains('@import')));
      expect(css, isNot(contains('fixed')));
      expect(css, isNot(contains('expression(')));
      expect(css, isNot(contains('javascript')));
    });
  });

  group('markup', () {
    test('scripts, handlers and forms go; remote and data pictures stay, capped to the pane', () {
      final out = MailHtml.prepare(
        '<div onclick="x()">a<script>alert(1)</script><form><input></form>'
        '<img src="https://cdn.example/logo.png" width="600"><img src="data:image/png;base64,AA==">'
        '<img src="data:text/html,<b>"><img src="ftp://x/y.png"><a href="javascript:alert(1)" target="_blank">l</a></div>',
      );
      expect(out, isNot(contains('script')));
      expect(out, isNot(contains('onclick')));
      expect(out, isNot(contains('<form')));
      expect(out, contains('src="https://cdn.example/logo.png"'));
      expect(out, contains('max-width: 100%'));
      expect(out, contains('data:image/png'));
      expect(out, isNot(contains('text/html')));
      expect(out, isNot(contains('ftp:')));
      expect(out, isNot(contains('javascript')));
      expect(out, contains('rel="noopener noreferrer"'));
      expect(out, isNot(contains('target=')));
    });

    test('cid: pictures come from the downloaded attachments', () {
      const html = '<p><img src="cid:logo@x.kz"><img src="CID:%3Cmissing%3E"></p>';
      expect(MailHtml.referencedCids(html), {'logo@x.kz', 'missing'});
      final out = MailHtml.prepare(html, cidFiles: {'LOGO@x.kz': '/tmp/att/logo.png'});
      expect(out, contains('src="file:///tmp/att/logo.png"'));
      expect('<img'.allMatches(out).length, 1, reason: 'an unresolved cid: picture is left out');
    });

    test('specificity counts ids, classes and elements', () {
      expect(MailHtml.specificity('#a .b p'), greaterThan(MailHtml.specificity('.b .c p')));
      expect(MailHtml.specificity('.b'), greaterThan(MailHtml.specificity('div p span')));
    });
  });
}
