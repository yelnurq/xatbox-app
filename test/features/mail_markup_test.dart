import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:xatbox_mobile/features/mail/domain/mail_markup.dart';
import 'package:xatbox_mobile/features/mail/presentation/compose_formatting.dart';

/// Tags and attributes that survive `POST /mail/send` sanitizing.
const _allowedTags = {
  'p', 'div', 'br', 'b', 'strong', 'i', 'em', 'u', 's', 'ul', 'ol', 'li', //
  'a', 'blockquote', 'span', 'table', 'thead', 'tbody', 'tr', 'th', 'td',
};

final _spanStyle = RegExp(
  r'^(color:#[0-9a-f]{6}(;background-color:#[0-9a-f]{6})?|background-color:#[0-9a-f]{6})$',
);

/// Every element is allow-listed; only `a[href]` with a safe scheme, a span's
/// `#rrggbb` colours and the fixed table styles are attributes.
void expectAllowListed(String html) {
  final fragment = html_parser.parseFragment(html);
  void walk(dom.Node node) {
    if (node is dom.Element) {
      expect(_allowedTags, contains(node.localName), reason: html);
      if (node.localName == 'a') {
        expect(node.attributes.keys.toList(), ['href'], reason: html);
        expect(MailMarkup.isSafeHref(node.attributes['href']!), isTrue);
      } else if (node.localName == 'span') {
        expect(node.attributes.keys.toList(), ['style'], reason: html);
        expect(node.attributes['style'], matches(_spanStyle), reason: html);
      } else if (node.localName == 'table') {
        expect(node.attributes, {'style': MailMarkup.tableStyle}, reason: html);
      } else if (node.localName == 'td' || node.localName == 'th') {
        expect(node.attributes, {'style': MailMarkup.cellStyle}, reason: html);
      } else {
        expect(node.attributes, isEmpty, reason: html);
      }
    }
    node.nodes.forEach(walk);
  }

  fragment.nodes.forEach(walk);
}

void main() {
  group('MailMarkup.toHtml', () {
    test('inline styles, nesting and line structure', () {
      expect(
        MailMarkup.toHtml('**Привет**, _мир_ и __всё__ ~~старое~~'),
        '<div><b>Привет</b>, <i>мир</i> и <u>всё</u> <s>старое</s></div>',
      );
      expect(
        MailMarkup.toHtml('**жирный _и курсив_**'),
        '<div><b>жирный <i>и курсив</i></b></div>',
      );
      expect(
        MailMarkup.toHtml('раз\n\nдва'),
        '<div>раз</div><div><br></div><div>два</div>',
      );
      expect(MailMarkup.toHtml(''), '');
      expect(MailMarkup.toHtml('  \n '), '');
    });

    test('markers inside words, lone stars and escapes stay literal', () {
      expect(
        MailMarkup.toHtml('snake_case_name и 2 * 3 * 4'),
        '<div>snake_case_name и 2 * 3 * 4</div>',
      );
      expect(MailMarkup.toHtml(r'\*\*не жирный\*\*'), '<div>**не жирный**</div>');
      expect(MailMarkup.toHtml('** пробел **'), '<div>** пробел **</div>');
      expect(MailMarkup.toHtml('**незакрытый'), '<div>**незакрытый</div>');
    });

    test('escapes all HTML in text', () {
      expect(
        MailMarkup.toHtml('<b>не тег</b> & "кавычки" \'апостроф\''),
        '<div>&lt;b&gt;не тег&lt;/b&gt; &amp; &quot;кавычки&quot; &#39;апостроф&#39;</div>',
      );
    });

    test('nested bulleted and numbered lists', () {
      const src =
          '- один\n'
          '  - один.а\n'
          '  - один.б\n'
          '    1. глубоко\n'
          '- два\n'
          '1. первый\n'
          '2. второй';
      expect(
        MailMarkup.toHtml(src),
        '<ul><li>один<ul><li>один.а</li><li>один.б<ol><li>глубоко</li></ol></li></ul></li>'
        '<li>два</li></ul>'
        '<ol><li>первый</li><li>второй</li></ol>',
      );
      expect(
        MailMarkup.toPlainText(src),
        '• один\n  • один.а\n  • один.б\n    1. глубоко\n• два\n1. первый\n2. второй',
      );
    });

    test('a list type change at the same level starts a new list', () {
      expect(
        MailMarkup.toHtml('- а\n1. б'),
        '<ul><li>а</li></ul><ol><li>б</li></ol>',
      );
      expect(
        MailMarkup.toHtml('- **важно**: [ссылка](https://example.kz)'),
        '<ul><li><b>важно</b>: <a href="https://example.kz">ссылка</a></li></ul>',
      );
    });

    test('quotes nest and may contain lists', () {
      expect(
        MailMarkup.toHtml('> а\n> > б\n> - пункт\nпосле'),
        '<blockquote><div>а</div><blockquote><div>б</div></blockquote>'
        '<ul><li>пункт</li></ul></blockquote><div>после</div>',
      );
    });

    test('nesting is capped', () {
      final deep = '${'>' * 30} глубоко';
      final html = MailMarkup.toHtml(deep);
      expect(
        '<blockquote>'.allMatches(html).length,
        MailMarkup.maxDepth,
      );
      expectAllowListed(html);
    });

    test('links: http, https and mailto only; attribute escaped', () {
      expect(
        MailMarkup.toHtml('[сайт](https://example.kz/a?b=1&c=2)'),
        '<div><a href="https://example.kz/a?b=1&amp;c=2">сайт</a></div>',
      );
      expect(
        MailMarkup.toHtml('[почта](mailto:a@b.kz) [http](http://x.kz)'),
        '<div><a href="mailto:a@b.kz">почта</a> <a href="http://x.kz">http</a></div>',
      );
      expect(
        MailMarkup.toHtml('[файл](ftp://x.kz)'),
        '<div>[файл](ftp://x.kz)</div>',
      );
    });

    test('XSS attempts never produce markup', () {
      const attacks = [
        '<script>alert(1)</script>',
        '[клик](javascript:alert(1))',
        '[клик](JaVaScRiPt:alert(1))',
        '[клик]( javascript:alert(1))',
        '[клик](data:text/html;base64,PHNjcmlwdD4=)',
        '[клик](vbscript:msgbox)',
        '[x](https://a.kz/"onmouseover="alert(1))',
        "[x](https://a.kz/'onmouseover='alert(1))",
        '[x](https://a.kz/<img src=x onerror=alert(1)>)',
        '<img src=x onerror=alert(1)>',
        '**<iframe src="https://evil">**',
        '> <svg onload=alert(1)>',
        '- <a href="javascript:alert(1)">x</a>',
        '[**<b onclick=x>**](https://ok.kz)',
        '&lt;script&gt; &#x3C;script&#x3E;',
      ];
      for (final a in attacks) {
        final html = MailMarkup.toHtml(a);
        expectAllowListed(html);
        // Rejected constructs stay as escaped text; only real tags matter.
        final lower = html.toLowerCase();
        expect(lower, isNot(contains('<script')));
        expect(lower, isNot(contains('<img')));
        expect(lower, isNot(contains('<iframe')));
        expect(lower, isNot(contains('<svg')));
        expect(lower, isNot(contains('href="javascript')));
        expect(lower, isNot(contains('href="data')));
      }
      expect(
        MailMarkup.toHtml('[клик](javascript:alert(1))'),
        '<div>[клик](javascript:alert(1))</div>',
      );
      expect(
        MailMarkup.toHtml('&lt;'),
        '<div>&amp;lt;</div>',
        reason: 'entities typed by the user are text, not markup',
      );
    });

    test('isSafeHref', () {
      expect(MailMarkup.isSafeHref('https://example.kz'), isTrue);
      expect(MailMarkup.isSafeHref('HTTP://example.kz'), isTrue);
      expect(MailMarkup.isSafeHref('mailto:a@b.kz'), isTrue);
      expect(MailMarkup.isSafeHref('https://'), isFalse);
      expect(MailMarkup.isSafeHref('javascript:alert(1)'), isFalse);
      expect(MailMarkup.isSafeHref('https://a b'), isFalse);
      expect(MailMarkup.isSafeHref('//example.kz'), isFalse);
    });
  });

  test('phones: colours, tables and \\| stay plain text, as before', () {
    expect(MailMarkup.toHtml('[x]{color=#d93025}'), '<div>[x]{color=#d93025}</div>');
    expect(MailMarkup.toHtml('| a |\n| b |'), contains('| a |'));
    expect(MailMarkup.toHtml('| a |\n| b |'), isNot(contains('<table')));
    expect(MailMarkup.fromHtml('<table><tr><td>a</td></tr></table>'), isNot(contains('|')));
  });

  group('colour spans', () {
    test('text colour, highlight and both', () {
      expect(
        MailMarkup.toHtml('a [красный]{color=#D93025} b', rich: true),
        '<div>a <span style="color:#d93025">красный</span> b</div>',
      );
      expect(
        MailMarkup.toHtml('[фон]{bg=#fff475}', rich: true),
        '<div><span style="background-color:#fff475">фон</span></div>',
      );
      expect(
        MailMarkup.toHtml('[оба]{bg=#fff475 color=#1a73e8}', rich: true),
        '<div><span style="color:#1a73e8;background-color:#fff475">оба</span></div>',
      );
    });

    test('formatting and links nest inside and around', () {
      expect(
        MailMarkup.toHtml('**[жирный]{color=#188038}** [**внутри**]{color=#188038}', rich: true),
        '<div><b><span style="color:#188038">жирный</span></b> '
        '<span style="color:#188038"><b>внутри</b></span></div>',
      );
      expect(
        MailMarkup.toHtml('[[сайт](https://example.kz)]{bg=#aecbfa}', rich: true),
        '<div><span style="background-color:#aecbfa"><a href="https://example.kz">сайт</a></span></div>',
      );
      expect(
        MailMarkup.toHtml('- [пункт]{color=#d93025}', rich: true),
        '<ul><li><span style="color:#d93025">пункт</span></li></ul>',
      );
    });

    test('anything but six hex digits stays literal text', () {
      const literal = [
        '[x]{color=red}',
        '[x]{color=#fff}',
        '[x]{color=#12345g}',
        '[x]{colour=#123456}',
        '[x]{color=#123456;background:url(x)}',
        '[x]{color=#123456" onmouseover="alert(1)}',
        '[x]{color=expression(alert(1))}',
        '[x] {color=#123456}',
        r'\[x]{color=#123456}',
        '[x]{style=color:red}',
      ];
      for (final src in literal) {
        final html = MailMarkup.toHtml(src, rich: true);
        expect(html, isNot(contains('<span')), reason: src);
        expectAllowListed(html);
      }
      expect(MailMarkup.toHtml('[x]{color=red}', rich: true), '<div>[x]{color=red}</div>');
    });

    test('an empty span leaves nothing; plain text drops the colour', () {
      expect(MailMarkup.toHtml('a[]{color=#d93025}b', rich: true), '<div>ab</div>');
      expect(
        MailMarkup.toPlainText('Срок: [завтра]{color=#d93025 bg=#fff475}!', rich: true),
        'Срок: завтра!',
      );
    });

    test('matchColorSpan reports bounds and colours', () {
      final m = MailMarkup.matchColorSpan('a [b [c](https://x.kz)]{color=#ABCDEF} d', 2)!;
      expect(m.innerStart, 3);
      expect(m.innerEnd, 22);
      expect(m.end, 38);
      expect(m.color, '#abcdef');
      expect(m.background, isNull);
      expect(MailMarkup.matchColorSpan('[a](https://x.kz)', 0), isNull);
      expect(MailMarkup.normalizeColor('RGB(26, 115, 232)'), '#1a73e8');
      expect(MailMarkup.normalizeColor('#F00'), '#ff0000');
      expect(MailMarkup.normalizeColor('url(x)'), isNull);
      expect(MailMarkup.normalizeColor('rgb(300,0,0)'), isNull);
    });
  });

  group('tables', () {
    const cell = 'style="${MailMarkup.cellStyle}"';
    const table = '<table style="${MailMarkup.tableStyle}">';

    test('pipe rows with a header line', () {
      expect(
        MailMarkup.toHtml('| Имя | Кабинет |\n|-----|:---:|\n| Асем | **204** |', rich: true),
        '$table<thead><tr><th $cell>Имя</th><th $cell>Кабинет</th></tr></thead>'
        '<tbody><tr><td $cell>Асем</td><td $cell><b>204</b></td></tr></tbody></table>',
      );
    });

    test('without a header; short rows padded; text around stays text', () {
      expect(
        MailMarkup.toHtml('до\n| a | b |\n| c |\nпосле', rich: true),
        '<div>до</div>$table<tbody><tr><td $cell>a</td><td $cell>b</td></tr>'
        '<tr><td $cell>c</td><td $cell></td></tr></tbody></table><div>после</div>',
      );
    });

    test('a single row, or bars inside a sentence, are not a table', () {
      expect(MailMarkup.toHtml('| одна строка |', rich: true), '<div>| одна строка |</div>');
      expect(
        MailMarkup.toHtml('a | b | c\nx | y', rich: true),
        '<div>a | b | c</div><div>x | y</div>',
      );
      expect(
        MailMarkup.toHtml('| a \\|\n| b |', rich: true),
        '<div>| a |</div><div>| b |</div>',
        reason: 'an escaped last bar does not close a row',
      );
    });

    test('escaped bars, links and colours inside cells', () {
      final html = MailMarkup.toHtml(
        '| a \\| b | [сайт](https://example.kz) |\n| [c]{color=#d93025} | <script> |', rich: true
      );
      expect(html, contains('<td $cell>a | b</td>'));
      expect(html, contains('<a href="https://example.kz">сайт</a>'));
      expect(html, contains('<span style="color:#d93025">c</span>'));
      expect(html, contains('&lt;script&gt;'));
      expectAllowListed(html);
    });

    test('tables inside quotes', () {
      expect(
        MailMarkup.toHtml('> | a |\n> | b |', rich: true),
        '<blockquote>$table<tbody><tr><td $cell>a</td></tr><tr><td $cell>b</td></tr></tbody></table></blockquote>',
      );
    });

    test('plain text keeps the table readable', () {
      expect(
        MailMarkup.toPlainText('| Имя | Кабинет |\n|---|---|\n| Асем | **204** |\n| Бауыржан | 3 |', rich: true),
        '| Имя      | Кабинет |\n'
        '|----------|---------|\n'
        '| Асем     | 204     |\n'
        '| Бауыржан | 3       |',
      );
    });
  });


  group('MailMarkup.toPlainText', () {
    test('removes markers, renders links and keeps quotes', () {
      expect(
        MailMarkup.toPlainText(
          '**Жирный** _курсив_ __подчёркнутый__\n'
          '[сайт](https://example.kz) и [a@b.kz](mailto:a@b.kz)\n'
          '> цитата\n'
          r'\*звёздочки\*',
        ),
        'Жирный курсив подчёркнутый\n'
        'сайт (https://example.kz) и a@b.kz\n'
        '> цитата\n'
        '*звёздочки*',
      );
    });

    test('plain text passes through unchanged', () {
      const text = 'Здравствуйте!\n\nОтчёт во вложении, 2 * 3 = 6.\nС уважением';
      expect(MailMarkup.toPlainText(text), text);
      expect(MailMarkup.toPlainText(''), '');
    });
  });

  group('MailMarkup.fromHtml', () {
    test('round-trips the composer markup', () {
      const src =
          '**Привет**, _мир_ и __всё__\n'
          '- один\n'
          '  - два\n'
          '1. первый\n'
          '> цитата\n'
          '\n'
          '[сайт](https://example.kz)';
      final html = MailMarkup.toHtml(src);
      final back = MailMarkup.fromHtml(html);
      expect(back, src);
      expect(MailMarkup.toHtml(back), html);
    });

    test('round-trips colours and tables', () {
      const src =
          'Срок: [завтра]{color=#d93025} и [важно]{color=#1a73e8 bg=#fff475}\n'
          '| Имя | Кабинет |\n'
          '|---|---|\n'
          '| Асем | [204]{bg=#ccff90} |\n'
          '| a \\| b |  |';
      final html = MailMarkup.toHtml(src, rich: true);
      final back = MailMarkup.fromHtml(html, rich: true);
      expect(MailMarkup.toHtml(back, rich: true), html);
      expect(back, contains('[завтра]{color=#d93025}'));
      expect(back, contains('|---|---|'));
    });

    test('colours from other editors are read, other styles are not', () {
      expect(
        MailMarkup.fromHtml(
          '<div><span style="color: rgb(217, 48, 37); font-size: 40px">a</span> '
          '<font color="#00F">b</font> <span style="background-color:url(x)">c</span></div>', rich: true
        ),
        '[a]{color=#d93025} [b]{color=#0000ff} c',
      );
    });


    test('foreign HTML becomes readable markup without active content', () {
      final md = MailMarkup.fromHtml(
        '<p>Hello <strong>there</strong></p><script>alert(1)</script>'
        '<p><a href="javascript:x">bad</a> <a href="https://ok.kz">ok</a></p>'
        '<p>- not a list</p>',
      );
      expect(md, contains('Hello **there**'));
      expect(md, isNot(contains('alert')));
      expect(md, contains('bad [ok](https://ok.kz)'));
      expect(
        MailMarkup.toHtml(md),
        isNot(contains('<ul>')),
        reason: 'a literal dash from HTML must not turn into a list',
      );
    });
  });

  group('MarkupEditing', () {
    TextEditingValue v(String text, int start, [int? end]) => TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: start, extentOffset: end ?? start),
    );

    test('toggleWrap wraps, unwraps and inserts a pair at the caret', () {
      final wrapped = MarkupEditing.toggleWrap(v('Привет мир', 0, 6), '**');
      expect(wrapped.text, '**Привет** мир');
      expect(wrapped.selection, const TextSelection(baseOffset: 2, extentOffset: 8));
      final unwrapped = MarkupEditing.toggleWrap(wrapped, '**');
      expect(unwrapped.text, 'Привет мир');

      final spaced = MarkupEditing.toggleWrap(v('a  слово  b', 1, 9), '_');
      expect(spaced.text, 'a  _слово_  b', reason: 'spaces stay outside');

      final caret = MarkupEditing.toggleWrap(v('ab', 1), '__');
      expect(caret.text, 'a____b');
      expect(caret.selection.baseOffset, 3);
    });

    test('toggleLinePrefix numbers, bullets and quotes selected lines', () {
      const text = 'один\nдва\nтри';
      final numbered = MarkupEditing.toggleLinePrefix(
        v(text, 0, text.length),
        MarkupLineKind.numbered,
      );
      expect(numbered.text, '1. один\n2. два\n3. три');
      final bullets = MarkupEditing.toggleLinePrefix(
        numbered,
        MarkupLineKind.bullet,
      );
      expect(bullets.text, '- один\n- два\n- три');
      final plain = MarkupEditing.toggleLinePrefix(
        bullets,
        MarkupLineKind.bullet,
      );
      expect(plain.text, text);

      final quoted = MarkupEditing.toggleLinePrefix(
        v('до\nцитата\nпосле', 4),
        MarkupLineKind.quote,
      );
      expect(quoted.text, 'до\n> цитата\nпосле');
      expect(
        MarkupEditing.toggleLinePrefix(quoted, MarkupLineKind.quote).text,
        'до\nцитата\nпосле',
      );
    });

    test('applyColor wraps, recolours and removes', () {
      final red = MarkupEditing.applyColor(v('важный срок', 0, 6), hex: '#d93025');
      expect(red.text, '[важный]{color=#d93025} срок');
      expect(red.selection, const TextSelection(baseOffset: 1, extentOffset: 7));

      final both = MarkupEditing.applyColor(red, hex: '#fff475', background: true);
      expect(both.text, '[важный]{color=#d93025 bg=#fff475} срок');

      final blue = MarkupEditing.applyColor(both, hex: '#1a73e8');
      expect(blue.text, '[важный]{color=#1a73e8 bg=#fff475} срок');

      final noBg = MarkupEditing.applyColor(blue, hex: null, background: true);
      expect(noBg.text, '[важный]{color=#1a73e8} срок');
      final plain = MarkupEditing.applyColor(noBg, hex: null);
      expect(plain.text, 'важный срок');
      expect(plain.selection, const TextSelection(baseOffset: 0, extentOffset: 6));

      expect(
        MarkupEditing.applyColor(v('текст', 0, 5), hex: null).text,
        'текст',
        reason: 'clearing uncoloured text changes nothing',
      );
    });

    test('applyColor at a caret: inside a span recolours it, else inserts one', () {
      final inside = MarkupEditing.applyColor(v('a [bcd]{color=#d93025} e', 4), hex: '#188038');
      expect(inside.text, 'a [bcd]{color=#188038} e');
      expect(inside.selection.baseOffset, 4);

      final removed = MarkupEditing.applyColor(v('a [bcd]{color=#d93025} e', 4), hex: null);
      expect(removed.text, 'a bcd e');
      expect(removed.selection.baseOffset, 3);

      final inserted = MarkupEditing.applyColor(v('ab', 1), hex: '#d93025');
      expect(inserted.text, 'a[]{color=#d93025}b');
      expect(inserted.selection.baseOffset, 2);
    });

    test('applyColor keeps lists, quotes and table cells intact', () {
      const text = '- один\n> два\n| a | b |\n| c | d |';
      final out = MarkupEditing.applyColor(v(text, 0, text.length), hex: '#d93025');
      expect(
        out.text,
        '- [один]{color=#d93025}\n> [два]{color=#d93025}\n'
        '| [a]{color=#d93025} | [b]{color=#d93025} |\n| [c]{color=#d93025} | [d]{color=#d93025} |',
      );
      final html = MailMarkup.toHtml(out.text, rich: true);
      expect(html, startsWith('<ul><li><span style="color:#d93025">один</span></li></ul>'));
      expect('<td'.allMatches(html).length, 4);
      expectAllowListed(html);

      final odd = MarkupEditing.applyColor(v('a ] b', 0, 5), hex: '#d93025');
      expect(odd.text, r'[a \] b]{color=#d93025}');
      expect(MailMarkup.toPlainText(odd.text, rich: true), 'a ] b');
    });

    test('insertTable puts a 2x2 skeleton on its own lines', () {
      final empty = MarkupEditing.insertTable(v('', 0));
      expect(empty.text, '|       |       |\n|       |       |');
      expect(empty.selection.baseOffset, 2);
      expect('<td'.allMatches(MailMarkup.toHtml(empty.text, rich: true)).length, 4);

      final mid = MarkupEditing.insertTable(v('до после', 2));
      expect(mid.text, 'до\n|       |       |\n|       |       |\n после');
      expect(mid.selection.baseOffset, 5);
    });


    test('insertLink and URL normalisation', () {
      final linked = MarkupEditing.insertLink(
        v('см. сайт', 4, 8),
        url: 'https://example.kz',
      );
      expect(linked.text, 'см. [сайт](https://example.kz)');
      expect(MarkupEditing.normalizeUrl('example.kz'), 'https://example.kz');
      expect(MarkupEditing.normalizeUrl('a@b.kz'), 'mailto:a@b.kz');
      expect(MarkupEditing.normalizeUrl('javascript:alert(1)'), isNull);
      expect(MarkupEditing.normalizeUrl(''), isNull);
      expect(
        MailMarkup.toHtml(linked.text),
        '<div>см. <a href="https://example.kz">сайт</a></div>',
      );
    });
  });
}
