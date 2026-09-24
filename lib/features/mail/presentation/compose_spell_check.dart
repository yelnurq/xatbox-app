import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/platform/desktop_shell.dart';
import 'markup_editing_controller.dart';

/// Misspellings worth showing in composer markup (pure, unit-tested): not
/// in link targets `[…](url)`, colour blocks `[…]{color=#…}`, bare URLs or
/// e-mail addresses.
List<SpellingIssue> filterSpelling(String text, List<SpellingIssue> issues) {
  final skip = [
    for (final re in [
      RegExp(r'\]\([^)\s]*\)'),
      RegExp(r'\]\{(?:color|bg)=#[0-9a-fA-F]{6}(?: (?:color|bg)=#[0-9a-fA-F]{6})?\}'),
      RegExp(r'https?://\S+|www\.\S+'),
      RegExp(r'\S+@\S+\.\S+'),
    ])
      for (final m in re.allMatches(text)) (m.start, m.end),
  ];
  return [
    for (final i in issues)
      if (i.end <= text.length && !skip.any((r) => i.start < r.$2 && i.end > r.$1)) i,
  ];
}

/// Desktop composer spelling: the body is checked by the system dictionaries
/// (DesktopShell.spellCheck) a moment after typing stops; misspelled words
/// get a red wavy underline over the formatted text, and the right-click
/// menu offers the suggestions. Listen to it to repaint the field.
class ComposeSpellChecker extends ChangeNotifier {
  ComposeSpellChecker(this.controller, {this.enabled = true}) {
    controller.addListener(_changed);
    _schedule();
  }

  static const _delay = Duration(milliseconds: 700);

  final MailMarkupEditingController controller;
  final bool enabled;
  String _checked = '';
  Timer? _debounce;

  void _changed() {
    if (controller.text == _checked) return; // a caret move
    if (controller.spelling.isNotEmpty) {
      // Offsets no longer match the text: drop them until the next check.
      controller.spelling = const [];
      notifyListeners();
    }
    _schedule();
  }

  void _schedule() {
    if (!enabled) return;
    _debounce?.cancel();
    _debounce = Timer(_delay, () => unawaited(_check()));
  }

  Future<void> _check() async {
    final text = controller.text;
    final issues = await DesktopShell.spellCheck(text);
    if (controller.text != text) return;
    _checked = text;
    controller.spelling = filterSpelling(text, issues);
    notifyListeners();
  }

  /// The suggestions for the misspelled word at the caret, as menu items.
  List<ContextMenuButtonItem> suggestionItems(EditableTextState state) {
    final offset = state.textEditingValue.selection.baseOffset;
    final issue = controller.spelling.where((i) => offset >= i.start && offset <= i.end).firstOrNull;
    if (issue == null) return const [];
    return [
      for (final s in issue.suggestions)
        ContextMenuButtonItem(
          label: s,
          onPressed: () {
            final text = controller.text;
            if (issue.end > text.length) return;
            controller.value = TextEditingValue(
              text: text.replaceRange(issue.start, issue.end, s),
              selection: TextSelection.collapsed(offset: issue.start + s.length),
            );
            ContextMenuController.removeAny();
          },
        ),
    ];
  }

  @override
  void dispose() {
    _debounce?.cancel();
    controller.removeListener(_changed);
    super.dispose();
  }
}
