import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:xatbox_mobile/core/localization/localization.dart';
import 'package:xatbox_mobile/core/theme/app_theme.dart';
import 'package:xatbox_mobile/features/mail/presentation/compose_formatting.dart';
import 'package:xatbox_mobile/features/mail/presentation/markup_editing_controller.dart';

/// The desktop window composer's colour, highlight and table buttons, and
/// the phone toolbar without them.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('ru'),
      supportedLocales: AppLocalization.supportedLocales,
      localizationsDelegates: AppLocalization.delegates,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  Widget toolbar(TextEditingController c, {required bool rich}) => ComposeFormattingToolbar(
    controller: c,
    enabled: true,
    preview: false,
    onTogglePreview: () {},
    richExtras: rich,
  );

  testWidgets('the phone toolbar has no colour or table buttons', (tester) async {
    await pump(tester, toolbar(TextEditingController(), rich: false));
    expect(find.byKey(const Key('fmt_bold')), findsOneWidget);
    expect(find.byKey(const Key('fmt_color')), findsNothing);
    expect(find.byKey(const Key('fmt_highlight')), findsNothing);
    expect(find.byKey(const Key('fmt_table')), findsNothing);
  });

  testWidgets('text colour and highlight from the palettes, then cleared', (tester) async {
    final c = MailMarkupEditingController(text: 'важный срок')
      ..selection = const TextSelection(baseOffset: 0, extentOffset: 6);
    await pump(tester, toolbar(c, rich: true));

    await tester.tap(find.byTooltip('Цвет текста'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fmt_color_#d93025')));
    await tester.pumpAndSettle();
    expect(c.text, '[важный]{color=#d93025} срок');
    expect(find.byKey(const Key('fmt_color_#d93025')), findsNothing, reason: 'the palette closes');

    await tester.tap(find.byTooltip('Цвет выделения'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fmt_bg_#fff475')));
    await tester.pumpAndSettle();
    expect(c.text, '[важный]{color=#d93025 bg=#fff475} срок');

    await tester.tap(find.byTooltip('Цвет текста'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fmt_color_none')));
    await tester.pumpAndSettle();
    expect(c.text, '[важный]{bg=#fff475} срок');
  });

  testWidgets('«Таблица» inserts a 2x2 skeleton', (tester) async {
    final c = MailMarkupEditingController(text: 'Итоги:')..selection = const TextSelection.collapsed(offset: 6);
    await pump(tester, toolbar(c, rich: true));
    await tester.tap(find.byKey(const Key('fmt_table')));
    await tester.pump();
    expect(c.text, 'Итоги:\n|       |       |\n|       |       |');
    expect(c.selection, const TextSelection.collapsed(offset: 9));
  });

  testWidgets('the desktop preview keeps colours and the table; the phone one does not', (tester) async {
    const markup = '[красный]{color=#d93025}\n| a | b |\n| c | d |';
    await pump(tester, const ComposePreview(markup: markup, keepStyles: true));
    final desktop = tester.widget<HtmlWidget>(find.byType(HtmlWidget)).html;
    expect(desktop, contains('<span style="color:#d93025">'));
    expect(desktop, contains('<table style="border-collapse:collapse">'));

    await pump(tester, const ComposePreview(markup: markup));
    final phone = tester.widget<HtmlWidget>(find.byType(HtmlWidget)).html;
    expect(phone, isNot(contains('style=')));
  });
}
