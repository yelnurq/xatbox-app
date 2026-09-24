import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/html_sanitizer.dart';
import '../domain/mail_markup.dart';
import 'mail_providers.dart';
import '../../../core/platform/desktop_keys.dart';

enum MarkupLineKind { bullet, numbered, quote }

/// Pure editing operations behind the formatting toolbar (unit-tested).
abstract final class MarkupEditing {
  static final _bulletRe = RegExp(r'^(\s*)[-*•][ \t]+');
  static final _numberRe = RegExp(r'^(\s*)\d{1,9}[.)][ \t]+');
  static final _quoteRe = RegExp(r'^ {0,3}> ?');

  /// Wraps the selection in [marker] (`**`, `_`, `__`), or unwraps it when it
  /// is already wrapped. A collapsed selection inserts a marker pair and puts
  /// the caret between them. Surrounding spaces stay outside the markers.
  static TextEditingValue toggleWrap(TextEditingValue value, String marker) {
    final text = value.text;
    final sel = _validSelection(value);
    var start = sel.start;
    var end = sel.end;
    if (start == end) {
      final inserted = text.replaceRange(start, end, '$marker$marker');
      return TextEditingValue(
        text: inserted,
        selection: TextSelection.collapsed(offset: start + marker.length),
      );
    }
    while (start < end && text[start].trim().isEmpty) {
      start++;
    }
    while (end > start && text[end - 1].trim().isEmpty) {
      end--;
    }
    final m = marker.length;
    final wrappedOutside =
        start >= m &&
        end + m <= text.length &&
        text.substring(start - m, start) == marker &&
        text.substring(end, end + m) == marker;
    if (wrappedOutside) {
      final unwrapped = text
          .replaceRange(end, end + m, '')
          .replaceRange(start - m, start, '');
      return TextEditingValue(
        text: unwrapped,
        selection: TextSelection(baseOffset: start - m, extentOffset: end - m),
      );
    }
    final inner = text.substring(start, end);
    if (inner.length >= 2 * m &&
        inner.startsWith(marker) &&
        inner.endsWith(marker)) {
      final stripped = inner.substring(m, inner.length - m);
      return TextEditingValue(
        text: text.replaceRange(start, end, stripped),
        selection: TextSelection(
          baseOffset: start,
          extentOffset: start + stripped.length,
        ),
      );
    }
    return TextEditingValue(
      text: text.replaceRange(start, end, '$marker$inner$marker'),
      selection: TextSelection(
        baseOffset: start + m,
        extentOffset: end + m,
      ),
    );
  }

  /// Adds (or, when every selected line already has it, removes) a list or
  /// quote prefix on each line touched by the selection.
  static TextEditingValue toggleLinePrefix(
    TextEditingValue value,
    MarkupLineKind kind,
  ) {
    final text = value.text;
    final sel = _validSelection(value);
    final blockStart = sel.start == 0
        ? 0
        : text.lastIndexOf('\n', sel.start - 1) + 1;
    var blockEnd = text.indexOf('\n', sel.end);
    if (blockEnd < 0) blockEnd = text.length;
    final lines = text.substring(blockStart, blockEnd).split('\n');
    final re = switch (kind) {
      MarkupLineKind.bullet => _bulletRe,
      MarkupLineKind.numbered => _numberRe,
      MarkupLineKind.quote => _quoteRe,
    };
    final allHave = lines.every(re.hasMatch);
    final out = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (allHave) {
        out.add(
          line.replaceFirstMapped(
            re,
            (m) => kind == MarkupLineKind.quote ? '' : m.group(1)!,
          ),
        );
        continue;
      }
      if (kind == MarkupLineKind.quote) {
        out.add(_quoteRe.hasMatch(line) ? line : '> $line');
        continue;
      }
      final indent = RegExp(r'^\s*').firstMatch(line)!.group(0)!;
      final body = line
          .replaceFirst(_bulletRe, indent)
          .replaceFirst(_numberRe, indent)
          .substring(indent.length);
      final prefix = kind == MarkupLineKind.bullet ? '- ' : '${i + 1}. ';
      out.add('$indent$prefix$body');
    }
    final replaced = out.join('\n');
    return TextEditingValue(
      text: text.replaceRange(blockStart, blockEnd, replaced),
      selection: TextSelection(
        baseOffset: blockStart,
        extentOffset: blockStart + replaced.length,
      ),
    );
  }

  /// Replaces the selection with `[text](url)`.
  static TextEditingValue insertLink(
    TextEditingValue value, {
    required String url,
    String? text,
  }) {
    final sel = _validSelection(value);
    final selected = value.text.substring(sel.start, sel.end);
    final label = (text != null && text.trim().isNotEmpty)
        ? text.trim()
        : (selected.trim().isNotEmpty ? selected.trim() : url);
    final escaped = label.replaceAll('[', r'\[').replaceAll(']', r'\]');
    final link = '[$escaped]($url)';
    return TextEditingValue(
      text: value.text.replaceRange(sel.start, sel.end, link),
      selection: TextSelection.collapsed(offset: sel.start + link.length),
    );
  }

  static final _linePrefix = RegExp(r'^ {0,3}(>+ ?)*( *([-*•]|\d{1,9}[.)])[ \t]+)?');

  /// Sets ([hex] `#rrggbb`) or clears (null) the text colour (`color`) or
  /// the highlight (`bg`, when [background]) of the selection:
  /// * a selection that is exactly a colour span's text, or a caret inside
  ///   one, changes that span (clearing its last colour removes it);
  /// * other text is wrapped in `[…]{color=…}`, line by line and, in table
  ///   rows, cell by cell, so lists, quotes and tables keep their shape;
  /// * a caret outside any span inserts an empty span to type into.
  static TextEditingValue applyColor(
    TextEditingValue value, {
    required String? hex,
    bool background = false,
  }) {
    final text = value.text;
    final sel = _validSelection(value);
    var start = sel.start;
    var end = sel.end;
    while (start < end && text[start].trim().isEmpty) {
      start++;
    }
    while (end > start && text[end - 1].trim().isEmpty) {
      end--;
    }

    String? attrs(ColorSpanMatch? m) => MailMarkup.colorAttrs(
      color: background ? m?.color : hex,
      background: background ? hex : m?.background,
    );

    final span = _enclosingSpan(text, start, end, exact: start != end);
    if (span != null) {
      final (open, m) = span;
      final inner = text.substring(m.innerStart, m.innerEnd);
      final next = attrs(m);
      final replaced = next == null ? inner : '[$inner]$next';
      final innerAt = next == null ? open : open + 1;
      return TextEditingValue(
        text: text.replaceRange(open, m.end, replaced),
        selection: start == end
            ? TextSelection.collapsed(offset: (sel.start - (m.innerStart - innerAt)).clamp(innerAt, innerAt + inner.length))
            : TextSelection(baseOffset: innerAt, extentOffset: innerAt + inner.length),
      );
    }
    final block = attrs(null);
    if (hex == null || block == null) return value;
    if (start == end) {
      final at = sel.start;
      return TextEditingValue(
        text: text.replaceRange(at, at, '[]$block'),
        selection: TextSelection.collapsed(offset: at + 1),
      );
    }

    // Wrap each piece: per line, after a list or quote marker, and per
    // table cell.
    final out = StringBuffer();
    var pos = start;
    while (pos < end) {
      final lineStart = pos == 0 ? 0 : text.lastIndexOf('\n', pos - 1) + 1;
      var lineEnd = text.indexOf('\n', pos);
      if (lineEnd < 0) lineEnd = text.length;
      final line = text.substring(lineStart, lineEnd);
      final to = end < lineEnd ? end : lineEnd;
      var from = lineStart + _linePrefix.firstMatch(line)!.end;
      if (from < pos) from = pos;
      if (from > to) from = to;
      out.write(text.substring(pos, from));
      if (from < to) {
        final segment = text.substring(from, to);
        final pieces = MailMarkup.isTableRow(line) ? _splitCells(segment) : [segment];
        for (var p = 0; p < pieces.length; p++) {
          if (p > 0) out.write('|');
          out.write(_wrapPiece(pieces[p], block));
        }
      }
      if (to >= end) break;
      out.write('\n');
      pos = to + 1;
    }
    final replaced = out.toString();
    // One span: select its text, as bold does; several: select them all.
    final single = MailMarkup.matchColorSpan(replaced, 0);
    return TextEditingValue(
      text: text.replaceRange(start, end, replaced),
      selection: single != null && single.end == replaced.length
          ? TextSelection(baseOffset: start + 1, extentOffset: start + single.innerEnd)
          : TextSelection(baseOffset: start, extentOffset: start + replaced.length),
    );
  }

  /// `[piece]{…}` with the piece's outer spaces kept outside; brackets that
  /// do not pair up are escaped so the span still closes where it should.
  static String _wrapPiece(String piece, String block) {
    final t = piece.trim();
    if (t.isEmpty) return piece;
    final lead = piece.substring(0, piece.indexOf(t));
    final trail = piece.substring(lead.length + t.length);
    var depth = 0;
    var balanced = true;
    for (var i = 0; i < t.length; i++) {
      if (t[i] == r'\') {
        i++;
      } else if (t[i] == '[') {
        depth++;
      } else if (t[i] == ']' && --depth < 0) {
        balanced = false;
      }
    }
    final inner = balanced && depth == 0
        ? t
        : t.replaceAllMapped(RegExp(r'(?<!\\)[\[\]]'), (m) => '\\${m[0]}');
    return '$lead[$inner]$block$trail';
  }

  static List<String> _splitCells(String segment) {
    final pieces = <String>[];
    var from = 0;
    for (var i = 0; i < segment.length; i++) {
      if (segment[i] == r'\') {
        i++;
      } else if (segment[i] == '|') {
        pieces.add(segment.substring(from, i));
        from = i + 1;
      }
    }
    pieces.add(segment.substring(from));
    return pieces;
  }

  /// The innermost colour span whose text is exactly [start]..[end]
  /// ([exact]) or contains the caret; its `[` offset and match.
  static (int, ColorSpanMatch)? _enclosingSpan(
    String text,
    int start,
    int end, {
    required bool exact,
  }) {
    final lineStart = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
    var lineEnd = text.indexOf('\n', start);
    if (lineEnd < 0) lineEnd = text.length;
    if (end > lineEnd) return null;
    (int, ColorSpanMatch)? found;
    for (var j = text.indexOf('[', lineStart); j >= 0 && j < lineEnd; j = text.indexOf('[', j + 1)) {
      if (j > 0 && text[j - 1] == r'\') continue;
      final m = MailMarkup.matchColorSpan(text, j);
      if (m == null) continue;
      final hit = exact
          ? (m.innerStart == start && m.innerEnd == end) || (j == start && m.end == end)
          : m.innerStart <= start && start <= m.innerEnd;
      if (hit) found = (j, m);
    }
    return found;
  }

  /// A 2×2 table skeleton on lines of its own, the caret in the first cell.
  static TextEditingValue insertTable(TextEditingValue value) {
    const row = '|       |       |';
    const skeleton = '$row\n$row';
    final text = value.text;
    final sel = _validSelection(value);
    final at = sel.end;
    final lineStart = at == 0 ? 0 : text.lastIndexOf('\n', at - 1) + 1;
    var lineEnd = text.indexOf('\n', at);
    if (lineEnd < 0) lineEnd = text.length;
    final before = text.substring(lineStart, at).trim().isEmpty ? '' : '\n';
    final after = text.substring(at, lineEnd).trim().isEmpty ? '' : '\n';
    final insertAt = before.isEmpty ? lineStart : at;
    final removeTo = after.isEmpty ? lineEnd : at;
    final inserted = '$before$skeleton$after';
    return TextEditingValue(
      text: text.replaceRange(insertAt, removeTo, inserted),
      selection: TextSelection.collapsed(offset: insertAt + before.length + 2),
    );
  }

  /// `example.com` → `https://example.com`, `a@b.kz` → `mailto:a@b.kz`.
  /// Returns null when the result is not an allowed link.
  static String? normalizeUrl(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return null;
    var url = raw;
    final lower = raw.toLowerCase();
    final hasScheme = RegExp(r'^[a-z][a-z0-9+.-]*:').hasMatch(lower);
    if (!hasScheme) {
      url = raw.contains('@') && !raw.contains('/')
          ? 'mailto:$raw'
          : 'https://$raw';
    }
    return MailMarkup.isSafeHref(url) ? url : null;
  }

  static TextSelection _validSelection(TextEditingValue value) {
    final len = value.text.length;
    final sel = value.selection;
    if (!sel.isValid) return TextSelection.collapsed(offset: len);
    return TextSelection(
      baseOffset: sel.start.clamp(0, len),
      extentOffset: sel.end.clamp(0, len),
    );
  }
}

/// Toolbar over the body field; the preview toggle is the last button.
class ComposeFormattingToolbar extends StatelessWidget {
  const ComposeFormattingToolbar({
    super.key,
    required this.controller,
    required this.enabled,
    required this.preview,
    required this.onTogglePreview,
    this.richExtras = false,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool preview;
  final VoidCallback onTogglePreview;

  /// Desktop window composer only: text colour, highlight and table. The
  /// phone composer leaves it off, so its toolbar stays as it was.
  final bool richExtras;

  /// Web-like palettes (text colours dark enough to read on white,
  /// highlights light enough to read black text on).
  static const textColors = ['#202124', '#5f6368', '#d93025', '#e8710a', '#188038', '#1a73e8', '#9334e6', '#d01884'];
  static const highlightColors = ['#fff475', '#fbbc04', '#ccff90', '#a7ffeb', '#aecbfa', '#d7aefb', '#fdcfe8', '#e8eaed'];

  void _apply(TextEditingValue Function(TextEditingValue) op) {
    controller.value = op(controller.value);
  }

  Future<void> _link(BuildContext context) async {
    final sel = controller.selection;
    final selected = sel.isValid && !sel.isCollapsed
        ? controller.text.substring(sel.start, sel.end)
        : '';
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _LinkDialog(initialText: selected),
    );
    if (result == null) return;
    controller.value = MarkupEditing.insertLink(
      controller.value.copyWith(selection: sel),
      url: result.$1,
      text: result.$2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final editable = enabled && !preview;
    Widget button(
      String key,
      IconData icon,
      String tooltip,
      VoidCallback onPressed,
    ) => IconButton(
      key: Key('fmt_$key'),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon),
      onPressed: editable ? onPressed : null,
    );

    return Semantics(
      container: true,
      label: l10n.mailFormatToolbar,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            button(
              'bold',
              LucideIcons.bold,
              l10n.mailFormatBold,
              () => _apply((v) => MarkupEditing.toggleWrap(v, '**')),
            ),
            button(
              'italic',
              LucideIcons.italic,
              l10n.mailFormatItalic,
              () => _apply((v) => MarkupEditing.toggleWrap(v, '_')),
            ),
            button(
              'underline',
              LucideIcons.underline,
              l10n.mailFormatUnderline,
              () => _apply((v) => MarkupEditing.toggleWrap(v, '__')),
            ),
            button(
              'bullets',
              LucideIcons.list,
              l10n.mailFormatBulletList,
              () => _apply(
                (v) => MarkupEditing.toggleLinePrefix(v, MarkupLineKind.bullet),
              ),
            ),
            button(
              'numbers',
              LucideIcons.listOrdered,
              l10n.mailFormatNumberedList,
              () => _apply(
                (v) =>
                    MarkupEditing.toggleLinePrefix(v, MarkupLineKind.numbered),
              ),
            ),
            button(
              'quote',
              LucideIcons.quote,
              l10n.mailFormatQuote,
              () => _apply(
                (v) => MarkupEditing.toggleLinePrefix(v, MarkupLineKind.quote),
              ),
            ),
            button('link', LucideIcons.link, l10n.mailFormatLink, () => _link(context)),
            if (richExtras) ...[
              _ColorMenu(
                key: const Key('fmt_color'),
                icon: LucideIcons.baseline,
                tooltip: l10n.mailFormatTextColor,
                colors: textColors,
                keyPrefix: 'fmt_color',
                enabled: editable,
                onPick: (hex) => _apply((v) => MarkupEditing.applyColor(v, hex: hex)),
              ),
              _ColorMenu(
                key: const Key('fmt_highlight'),
                icon: LucideIcons.highlighter,
                tooltip: l10n.mailFormatHighlight,
                colors: highlightColors,
                keyPrefix: 'fmt_bg',
                enabled: editable,
                onPick: (hex) => _apply((v) => MarkupEditing.applyColor(v, hex: hex, background: true)),
              ),
              button('table', LucideIcons.table, l10n.mailFormatTable, () => _apply(MarkupEditing.insertTable)),
            ],
            const SizedBox(width: Space.sm),
            IconButton(
              key: const Key('fmt_preview'),
              tooltip: preview ? l10n.mailFormatEdit : l10n.mailFormatPreview,
              isSelected: preview,
              visualDensity: VisualDensity.compact,
              icon: const Icon(LucideIcons.eye),
              selectedIcon: const Icon(LucideIcons.pencil),
              onPressed: enabled ? onTogglePreview : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// A toolbar button opening a small palette: one swatch per colour and
/// «Без цвета» to clear it.
class _ColorMenu extends StatelessWidget {
  const _ColorMenu({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.colors,
    required this.keyPrefix,
    required this.enabled,
    required this.onPick,
  });

  final IconData icon;
  final String tooltip;
  final List<String> colors;
  final String keyPrefix;
  final bool enabled;
  final ValueChanged<String?> onPick;

  static Color _color(String hex) => Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MenuAnchor(
      menuChildren: [
        Padding(
          padding: const EdgeInsets.all(Space.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 4 * 30,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final hex in colors)
                      Builder(
                        builder: (context) => Tooltip(
                          message: hex,
                          child: InkWell(
                            key: Key('${keyPrefix}_$hex'),
                            borderRadius: BorderRadius.circular(4),
                            onTap: () {
                              MenuController.maybeOf(context)?.close();
                              onPick(hex);
                            },
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: _color(hex),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: theme.colorScheme.outlineVariant),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        MenuItemButton(
          key: Key('${keyPrefix}_none'),
          leadingIcon: const Icon(LucideIcons.ban, size: 16),
          onPressed: () => onPick(null),
          child: Text(context.l10n.mailFormatColorNone),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon),
        onPressed: enabled
            ? () => controller.isOpen ? controller.close() : controller.open()
            : null,
      ),
    );
  }
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({required this.initialText});
  final String initialText;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  final _url = TextEditingController();
  late final _text = TextEditingController(text: widget.initialText);
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final url = MarkupEditing.normalizeUrl(_url.text);
    if (url == null) {
      setState(() => _error = context.l10n.mailLinkInvalid);
      return;
    }
    Navigator.pop(context, (url, _text.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.mailLinkDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('link_url'),
            controller: _url,
            autofocus: true,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.mailLinkUrl,
              hintText: l10n.mailLinkUrlHint,
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: Space.sm),
          TextField(
            key: const Key('link_text'),
            controller: _text,
            decoration: InputDecoration(labelText: l10n.mailLinkText),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('link_insert'),
          onPressed: _submit,
          child: Text(l10n.mailLinkInsert),
        ),
      ],
    );
  }
}

/// Rendered preview of the HTML that will be sent.
class ComposePreview extends StatelessWidget {
  const ComposePreview({super.key, required this.markup, this.keepStyles = false});
  final String markup;

  /// Desktop window: show colours and table borders. The HTML is then used
  /// as MailMarkup.toHtml wrote it — every text escaped, only fixed tags and
  /// the `#rrggbb` colour and table styles it writes itself. Off (phone), it
  /// passes the general sanitizer, which drops all styles, as before.
  final bool keepStyles;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final html = MailMarkup.toHtml(markup, rich: keepStyles);
    return Container(
      key: const Key('compose_preview'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 160),
      padding: const EdgeInsets.all(Space.sm + Space.xs),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(Space.sm),
      ),
      child: html.isEmpty
          ? Text(l10n.mailPreviewEmpty, style: TextStyle(color: tokens.textMuted))
          : HtmlWidget(
              // Our own output, sanitized again as defence in depth.
              keepStyles ? html : HtmlSanitizer.sanitize(html).html,
              textStyle: theme.textTheme.bodyMedium,
              onTapUrl: (_) => true,
            ),
    );
  }
}

/// What the server will append on send (`GET /mail/signature-preview`).
/// Failures are silent: the generic note is shown instead.
class ComposeSignaturePreview extends ConsumerWidget {
  const ComposeSignaturePreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: tokens.textMuted);
    final preview = ref.watch(mailSignaturePreviewProvider);
    final value = preview.value;
    if (preview.isLoading && value == null) return const SizedBox.shrink();
    if (value == null) {
      return Text(l10n.composeSignatureNote, style: muted);
    }
    final parts = value.appendedParts;
    if (!value.applied || parts.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const Key('compose_signature_preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(Space.sm + Space.xs),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(Space.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.mailSignaturePreviewTitle, style: muted),
          const SizedBox(height: Space.xs),
          for (final part in parts) ...[
            Text('-- \n$part', style: theme.textTheme.bodySmall),
            const SizedBox(height: Space.xs),
          ],
          Text(l10n.mailSignaturePreviewNote, style: muted),
        ],
      ),
    );
  }
}

/// Keyboard shortcuts for hardware keyboards (Ctrl+B / Ctrl+I / Ctrl+U).
class ComposeFormattingShortcuts extends StatelessWidget {
  const ComposeFormattingShortcuts({
    super.key,
    required this.controller,
    required this.child,
  });

  final TextEditingController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    void wrap(String marker) =>
        controller.value = MarkupEditing.toggleWrap(controller.value, marker);
    return CallbackShortcuts(
      bindings: {
        commandShortcut(LogicalKeyboardKey.keyB): () =>
            wrap('**'),
        commandShortcut(LogicalKeyboardKey.keyI): () =>
            wrap('_'),
        commandShortcut(LogicalKeyboardKey.keyU): () =>
            wrap('__'),
      },
      child: child,
    );
  }
}
