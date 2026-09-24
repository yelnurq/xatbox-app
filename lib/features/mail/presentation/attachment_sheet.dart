import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/platform/open_file.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../../shared/utils/error_text.dart';
import '../../../shared/utils/format_utils.dart';
import '../data/mail_models.dart';
import 'mail_providers.dart';
import '../../../shared/widgets/app_sheet.dart';

/// Attachment actions. Nothing is downloaded until the user picks one of
/// these (ТЗ п.24.5).
Future<void> showAttachmentActions(
  BuildContext context,
  WidgetRef ref,
  MailAttachment attachment,
) async {
  final l10n = context.l10n;
  final action = await showAppSheet<_AttachmentAction>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(LucideIcons.file),
            title: Text(
              attachment.filename.isEmpty ? attachment.id : attachment.filename,
            ),
            subtitle: Text(
              '${attachment.contentType} · ${FormatUtils.bytes(attachment.sizeBytes)}',
              style: TextStyle(color: ctx.tokens.textMuted),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(LucideIcons.download),
            title: Text(l10n.attachmentOpen),
            onTap: () => Navigator.of(ctx).pop(_AttachmentAction.open),
          ),
          if (attachment.isOfficeDocument)
            ListTile(
              leading: const Icon(LucideIcons.fileText),
              title: Text(l10n.attachmentPreviewPdf),
              onTap: () => Navigator.of(ctx).pop(_AttachmentAction.previewPdf),
            ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  await _run(context, ref, attachment, action);
}

enum _AttachmentAction { open, previewPdf }

Future<void> _run(
  BuildContext context,
  WidgetRef ref,
  MailAttachment attachment,
  _AttachmentAction action,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final downloader = ref.read(attachmentDownloaderProvider);
  final progress = ValueNotifier<double?>(null);

  // Modal progress; the future completes when the download finishes.
  final dialog = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      content: ValueListenableBuilder<double?>(
        valueListenable: progress,
        builder: (_, value, _) => Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(value: value, strokeWidth: 3),
            ),
            const SizedBox(width: Space.md),
            Expanded(child: Text(l10n.attachmentDownloading)),
          ],
        ),
      ),
    ),
  );

  void onProgress(int received, int total) {
    progress.value = total > 0 ? received / total : null;
  }

  String? path;
  String? error;
  try {
    final file = switch (action) {
      _AttachmentAction.open => await downloader.download(
        attachment,
        onProgress: onProgress,
      ),
      _AttachmentAction.previewPdf => await downloader.downloadAsPdf(
        attachment,
        onProgress: onProgress,
      ),
    };
    path = file.path;
  } on AppException catch (e) {
    DiagnosticLog.warn('mail', 'attachment download failed', error: e);
    error = ErrorText.describe(l10n, e);
  } on Object catch (e) {
    DiagnosticLog.error('mail', 'attachment download crashed', error: e);
    error = l10n.errUnexpected;
  }

  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  await dialog;
  progress.dispose();

  if (error != null) {
    messenger.showSnackBar(SnackBar(content: Text(error)));
    return;
  }
  final result = await openLocalFile(
    path!,
    mimeType: action == _AttachmentAction.previewPdf
        ? 'application/pdf'
        : attachment.contentType,
  );
  if (result == OpenFileOutcome.noApp) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.attachmentNoApp)));
  } else if (result != OpenFileOutcome.opened) {
    DiagnosticLog.warn('mail', 'open attachment: ${result.name}');
    messenger.showSnackBar(SnackBar(content: Text(l10n.errUnexpected)));
  }
}
