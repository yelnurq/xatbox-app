import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/localization/localization.dart';
import '../../../core/platform/open_file.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/widgets/desktop_file_gestures.dart';
import '../domain/eml.dart';
import 'mail_html.dart';

/// A saved message (`.eml`) opened with XatBox: read from disk, its files
/// written next to it in the temp folder, shown like a message of the
/// mailbox (the sender's layout, pictures, attachments to open or drag out).
class EmlView extends StatefulWidget {
  const EmlView({super.key, required this.path, required this.onClose});

  final String path;
  final VoidCallback onClose;

  @override
  State<EmlView> createState() => _EmlViewState();
}

class _EmlViewState extends State<EmlView> {
  EmlMessage? _message;
  Map<String, String> _files = const {};
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final message = EmlMessage.parse(await File(widget.path).readAsBytes());
      // Every part on disk: pictures for cid:, files to open or drag out.
      final dir = Directory(p.join((await getTemporaryDirectory()).path, 'eml', '${widget.path.hashCode.abs()}'));
      await dir.create(recursive: true);
      final files = <String, String>{};
      for (var i = 0; i < message.parts.length; i++) {
        final part = message.parts[i];
        final name = part.filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final file = File(p.join(dir.path, '$i-$name'));
        await file.writeAsBytes(part.bytes);
        files['$i'] = file.path;
        if (part.contentId.isNotEmpty) files['cid:${part.contentId.toLowerCase()}'] = file.path;
      }
      if (!mounted) return;
      setState(() {
        _message = message;
        _files = files;
      });
    } on Object catch (e) {
      DiagnosticLog.warn('mail', 'eml not opened', error: e);
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final m = _message;
    if (_error != null) {
      return Center(child: Text(l10n.desktopEmlUnreadable, style: theme.textTheme.bodyMedium));
    }
    if (m == null) return const Center(child: CircularProgressIndicator());
    final html = MailHtml.htmlOf(bodyHtml: m.html, bodyText: m.text);
    final cids = {
      for (final e in _files.entries)
        if (e.key.startsWith('cid:')) e.key.substring(4): e.value,
    };
    final inline = html == null ? const <String>{} : MailHtml.referencedCids(html);
    final meta = theme.textTheme.bodySmall!.copyWith(color: t.textSecondary);
    Widget row(String label, String value) => value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SelectableText('$label: $value', style: meta),
          );
    return ListView(
      padding: const EdgeInsets.all(Space.mlg),
      children: [
        SelectableText(
          m.subject.isEmpty ? l10n.mailNoSubject : m.subject,
          style: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: Space.sm),
        row(l10n.mailFrom, m.from),
        row(l10n.mailTo, m.to),
        row(l10n.mailCc, m.cc),
        if (m.date != null) row(l10n.desktopPrintDate, FormatUtils.fullDate(m.date, Localizations.localeOf(context).toString())),
        const Divider(height: Space.xl),
        if (html != null)
          HtmlWidget(
            MailHtml.prepare(html, cidFiles: cids),
            textStyle: theme.textTheme.bodyLarge!.copyWith(height: 1.6),
            onTapUrl: (url) => false,
          )
        else
          SelectableText(m.text, style: theme.textTheme.bodyLarge!.copyWith(height: 1.6)),
        const SizedBox(height: Space.lg),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (var i = 0; i < m.parts.length; i++)
              if (m.parts[i].contentId.isEmpty || !inline.contains(m.parts[i].contentId.toLowerCase()))
                DesktopFileGestures(
                  resolve: () async => _files['$i'],
                  child: ActionChip(
                    avatar: const Icon(LucideIcons.paperclip, size: 16),
                    label: Text('${m.parts[i].filename} · ${FormatUtils.bytes(m.parts[i].bytes.length)}'),
                    onPressed: () {
                      final path = _files['$i'];
                      if (path != null) openLocalFile(path, mimeType: m.parts[i].contentType);
                    },
                  ),
                ),
          ],
        ),
      ],
    );
  }
}
