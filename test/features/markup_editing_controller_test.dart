import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/features/mail/presentation/markup_editing_controller.dart';

void main() {
  const samples = [
    'Привет, **коллеги**!',
    '_курсив_ и __подчёркнутый__ и ~~зачёркнутый~~',
    '- первый\n- **второй**\n  * вложенный',
    '> цитата с [ссылкой](https://kaztbu.edu.kz)\n>> вложенная',
    'snake_case_name и a_b не курсив',
    '**жирный с _курсивом_ внутри**',
    '1. номер\n2. ещё',
    'незакрытый **жирный',
    'a [красный]{color=#d93025} и [фон]{bg=#fff475} и [оба **жирно**]{color=#1a73e8 bg=#fff475}',
    '[[ссылка](https://kaztbu.edu.kz)]{color=#188038} [x]{color=red}',
    '| Имя | Кабинет |\n|---|---|\n| [Асем]{bg=#ccff90} | a \\| b |\n> | в | цитате |\n> | ещё | ряд |',
    '| одна строка |',
    '',
  ];

  testWidgets('the formatted field keeps every character in place', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) { context = c; return const SizedBox(); })));
    for (final s in samples) {
      final c = MailMarkupEditingController(text: s);
      final span = c.buildTextSpan(context: context, style: const TextStyle(), withComposing: false);
      expect(span.toPlainText().length, s.length, reason: s);
      // Only «-»/«*» bullets change glyph (to «•»); everything else is equal.
      expect(span.toPlainText().replaceAll('•', '-'), s.replaceAllMapped(RegExp(r'^( *)\*(?= )', multiLine: true), (m) => '${m[1]}-').replaceAll('•', '-'), reason: s);
    }
  });

  testWidgets('markers are hidden, the text inside is styled', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) { context = c; return const SizedBox(); })));
    final span = MailMarkupEditingController(text: 'a **b** c').buildTextSpan(
      context: context,
      style: const TextStyle(),
      withComposing: false,
    );
    final leaves = <TextSpan>[];
    span.visitChildren((s) {
      if (s is TextSpan && s.text != null) leaves.add(s);
      return true;
    });
    final bold = leaves.firstWhere((s) => s.text == 'b');
    expect(bold.style?.fontWeight, FontWeight.w700);
    final marker = leaves.firstWhere((s) => s.text == '**');
    expect(marker.style?.color?.a, 0);
  });

  List<TextSpan> leavesOf(TextSpan span) {
    final leaves = <TextSpan>[];
    span.visitChildren((s) {
      if (s is TextSpan && s.text != null) leaves.add(s);
      return true;
    });
    return leaves;
  }

  testWidgets('colour spans show their colours, the markup around is hidden', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) { context = c; return const SizedBox(); })));
    final leaves = leavesOf(
      MailMarkupEditingController(text: 'a [red]{color=#d93025} [hi]{bg=#fff475} [x]{color=red}').buildTextSpan(
        context: context,
        style: const TextStyle(),
        withComposing: false,
      ),
    );
    final red = leaves.firstWhere((s) => s.text == 'red');
    expect(red.style?.color, const Color(0xFFD93025));
    final hi = leaves.firstWhere((s) => s.text == 'hi');
    expect(hi.style?.backgroundColor, const Color(0xFFFFF475));
    expect(hi.style?.color, MailMarkupEditingController.highlightTextColor);
    for (final hidden in ['[', ']{color=#d93025}', ']{bg=#fff475}']) {
      expect(leaves.firstWhere((s) => s.text == hidden).style?.color?.a, 0, reason: hidden);
    }
    expect(
      leaves.map((s) => s.text).join(),
      contains('[x]{color=red}'),
      reason: 'a colour that is not #rrggbb is shown as typed',
    );
  });

  testWidgets('table rows use a monospace font; a single row does not', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) { context = c; return const SizedBox(); })));
    TextSpan build(String text) =>
        MailMarkupEditingController(text: text).buildTextSpan(context: context, style: const TextStyle(), withComposing: false);

    final table = leavesOf(build('| a | b |\n|---|---|\n| c | d |'));
    final cell = table.firstWhere((s) => s.text == ' c ');
    expect(cell.style?.fontFamily, 'monospace');
    final bar = table.firstWhere((s) => s.text == '|');
    expect(bar.style?.fontFamily, 'monospace');
    expect(table.firstWhere((s) => s.text == '|---|---|').style?.fontFamily, 'monospace');

    final single = leavesOf(build('| a | b |'));
    expect(single.every((s) => s.style?.fontFamily != 'monospace'), isTrue);
  });
}
