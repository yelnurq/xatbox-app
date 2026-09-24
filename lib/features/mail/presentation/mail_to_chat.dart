import 'package:flutter/material.dart';

import '../../../core/localization/localization.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/utils/html_sanitizer.dart';
import '../data/mail_models.dart';

/// Text of a mail message forwarded to a chat (pure, unit-tested).
abstract final class MailToChat {
  static const excerptLimit = 1000;

  static String text(
    MailMessageDetail m, {
    required String subjectLabel,
    required String fromLabel,
    required String dateLabel,
    required String noSubject,
    required String date,
  }) {
    final subject = m.subject.trim().isEmpty ? noSubject : m.subject.trim();
    final sender =
        m.senderLabel.trim().isEmpty ||
            m.senderLabel.trim().toLowerCase() == m.from.toLowerCase()
        ? m.from
        : '${m.senderLabel.trim()} <${m.from}>';
    final body = excerpt(
      m.bodyText.trim().isNotEmpty
          ? m.bodyText
          : HtmlSanitizer.toPlainText(m.bodyHtml),
    );
    return [
      '$subjectLabel: $subject',
      '$fromLabel: $sender',
      if (date.isNotEmpty) '$dateLabel: $date',
      if (body.isNotEmpty) '\n$body',
    ].join('\n');
  }

  /// Plain text without quoted history noise, collapsed blank lines, cut at
  /// [excerptLimit] characters on a word boundary with «…».
  static String excerpt(String text, {int limit = excerptLimit}) {
    final collapsed = text
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((l) => l.trimRight())
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    if (collapsed.length <= limit) return collapsed;
    var cut = collapsed.substring(0, limit);
    final space = cut.lastIndexOf(RegExp(r'\s'));
    if (space > limit * 0.6) cut = cut.substring(0, space);
    return '${cut.trimRight()}…';
  }
}

/// Checkbox list of the message attachments; pops the chosen ones (all
/// ticked initially), or null when cancelled.
class MailToChatAttachmentsDialog extends StatefulWidget {
  const MailToChatAttachmentsDialog({super.key, required this.attachments});
  final List<MailAttachment> attachments;

  @override
  State<MailToChatAttachmentsDialog> createState() =>
      _MailToChatAttachmentsDialogState();
}

class _MailToChatAttachmentsDialogState
    extends State<MailToChatAttachmentsDialog> {
  late final Set<MailAttachment> _chosen = {...widget.attachments};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.mailUxForwardToChatAttachments),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final a in widget.attachments)
              CheckboxListTile(
                key: ValueKey('to_chat_attachment_${a.id}'),
                value: _chosen.contains(a),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  a.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(FormatUtils.bytes(a.sizeBytes)),
                onChanged: (v) => setState(
                  () => v == true ? _chosen.add(a) : _chosen.remove(a),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('to_chat_next'),
          onPressed: () => Navigator.pop(
            context,
            widget.attachments.where(_chosen.contains).toList(),
          ),
          child: Text(l10n.mailUxNext),
        ),
      ],
    );
  }
}
