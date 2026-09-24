import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/utils/diagnostic_log.dart';
import '../../../../shared/utils/error_text.dart';
import '../../../../shared/utils/format_utils.dart';
import '../../../../shared/widgets/state_view.dart';
import '../../data/mail_settings_models.dart';
import '../mail_error_text.dart';
import '../mail_providers.dart';
import 'mail_settings_widgets.dart';

/// One archive chosen on disk, as little of it as the upload needs.
typedef MailImportPickedFile = ({String name, String path, int size});

/// The archive picker, behind a provider so a test can offer a file without
/// opening a system dialog.
final mailImportFilePickerProvider =
    Provider<Future<MailImportPickedFile?> Function()>(
      (ref) => () async {
        final files = await FilePicker.pickFiles(
          type: FileType.custom,
          // ".tar.gz" reaches the dialog as "gz"; both are offered, and the
          // name check below is what actually decides.
          allowedExtensions: const ['tgz', 'gz'],
        );
        if (files.isEmpty) return null;
        final file = files.first;
        final path = file.path;
        if (path == null) return null;
        return (name: file.name, path: path, size: await file.length() ?? 0);
      },
    );

/// `/settings/mail/import` — importing one's own mail, the web's
/// «Импорт почты» section of Mail → Settings.
///
/// The archive the previous mail system exported is uploaded and read into
/// this mailbox in the background: nothing is replaced, and a message the
/// mailbox already holds is recognised and counted instead of doubled.
class MailImportScreen extends ConsumerStatefulWidget {
  const MailImportScreen({super.key});

  @override
  ConsumerState<MailImportScreen> createState() => _MailImportScreenState();
}

class _MailImportScreenState extends ConsumerState<MailImportScreen> {
  /// The web polls every 4 s while an import is queued or running.
  static const _pollInterval = Duration(seconds: 4);

  MailImportList? _list;
  Object? _loadError;
  bool _loading = true;

  MailImportPickedFile? _picked;
  double? _uploadProgress;
  CancelToken? _uploadCancel;
  final Set<String> _busy = {};
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    // Leaving the page stops the upload; nothing is queued server-side until
    // the whole archive has arrived.
    _uploadCancel?.cancel();
    super.dispose();
  }

  /// Polls only while something is moving, and never stacks two timers.
  void _schedulePoll() {
    _poll?.cancel();
    if (_list?.hasActive != true) return;
    _poll = Timer(_pollInterval, () => _load(quiet: true));
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final list = await ref.read(mailApiProvider).mailImports();
      if (!mounted) return;
      final wasActive = _list?.hasActive ?? false;
      setState(() {
        _list = list;
        _loading = false;
        _loadError = null;
      });
      // The folder counters in the sidebar move as the mail lands.
      if (wasActive && !list.hasActive) {
        unawaited(ref.read(mailSummaryProvider.notifier).refresh());
      }
      _schedulePoll();
    } on AppException catch (e) {
      DiagnosticLog.warn('mail', 'import list failed', error: e);
      if (!mounted) return;
      // A failed poll must not wipe the list that is already on screen.
      setState(() {
        _loading = false;
        if (_list == null) _loadError = e;
      });
      _schedulePoll();
    }
  }

  Future<void> _pick() async {
    final picked = await ref.read(mailImportFilePickerProvider)();
    if (!mounted || picked == null) return;
    setState(() => _picked = picked);
  }

  Future<void> _upload() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final picked = _picked;
    if (picked == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.mailImportPickFile)));
      return;
    }
    final mailbox = _list?.mailbox ?? '';
    // Refused here before a byte leaves the machine; the server refuses it
    // too, on the same rule.
    if (mailbox.isNotEmpty &&
        !MailArchiveImport.namedFor(picked.name, mailbox)) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.mailImportWrongName(mailbox))),
      );
      return;
    }
    final cancel = CancelToken();
    setState(() {
      _uploadProgress = 0;
      _uploadCancel = cancel;
    });
    try {
      await ref
          .read(mailApiProvider)
          .uploadMailImport(
            path: picked.path,
            filename: picked.name,
            cancelToken: cancel,
            onProgress: (sent, total) {
              if (!mounted || total <= 0) return;
              setState(() => _uploadProgress = (sent / total).clamp(0, 1));
            },
          );
      if (!mounted) return;
      setState(() {
        _picked = null;
        _uploadProgress = null;
        _uploadCancel = null;
      });
      messenger.showSnackBar(SnackBar(content: Text(l10n.mailImportQueued)));
      await _load(quiet: true);
    } on AppException catch (e) {
      DiagnosticLog.warn('mail', 'import upload failed', error: e);
      if (!mounted) return;
      setState(() {
        _uploadProgress = null;
        _uploadCancel = null;
      });
      if (cancel.isCancelled) return;
      messenger.showSnackBar(
        SnackBar(content: Text(MailErrorText.describe(l10n, e))),
      );
    }
  }

  void _cancelUpload() {
    _uploadCancel?.cancel();
    setState(() {
      _uploadProgress = null;
      _uploadCancel = null;
    });
  }

  Future<void> _retry(MailArchiveImport item) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(item.id));
    try {
      await ref.read(mailApiProvider).retryMailImport(item.id);
      if (!mounted) return;
      await _load(quiet: true);
    } on AppException catch (e) {
      DiagnosticLog.warn('mail', 'import retry failed', error: e);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(MailErrorText.describe(l10n, e))),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(item.id));
    }
  }

  Future<void> _remove(MailArchiveImport item) async {
    final l10n = context.l10n;
    final ok = await confirmMailAction(
      context,
      title: l10n.mailImportDeleteTitle,
      body: l10n.mailImportDeleteBody,
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(item.id));
    try {
      await ref.read(mailApiProvider).deleteMailImport(item.id);
      if (!mounted) return;
      await _load(quiet: true);
    } on AppException catch (e) {
      DiagnosticLog.warn('mail', 'import delete failed', error: e);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(MailErrorText.describe(l10n, e))),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final list = _list;

    if (_loading && list == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.mailSettingsImport)),
        body: const StateView.loading(),
      );
    }
    if (list == null) {
      final err = _loadError!;
      return Scaffold(
        appBar: AppBar(title: Text(l10n.mailSettingsImport)),
        body: ErrorText.isOffline(err)
            ? StateView.offline(
                message: ErrorText.describe(l10n, err),
                onRetry: _load,
              )
            : StateView.error(
                message: ErrorText.describe(l10n, err),
                onRetry: _load,
              ),
      );
    }

    final picked = _picked;
    final uploading = _uploadProgress != null;
    final muted = theme.textTheme.bodySmall?.copyWith(color: tokens.textMuted);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mailSettingsImport)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 96),
          children: [
            Text(l10n.mailImportHint, style: muted),
            const SizedBox(height: Space.md),
            Text(l10n.mailImportFile, style: theme.textTheme.titleSmall),
            const SizedBox(height: Space.xs),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('mail_import_pick'),
                    onPressed: uploading ? null : _pick,
                    icon: const Icon(LucideIcons.paperclip, size: 16),
                    label: Text(
                      picked == null
                          ? l10n.mailImportChoose
                          : '${picked.name} · ${FormatUtils.bytes(picked.size)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: Space.sm),
                FilledButton.icon(
                  key: const Key('mail_import_start'),
                  onPressed: picked == null || uploading ? null : _upload,
                  icon: const Icon(LucideIcons.upload, size: 16),
                  label: Text(
                    uploading
                        ? l10n.mailImportUploading(
                            ((_uploadProgress ?? 0) * 100).round(),
                          )
                        : l10n.mailImportStart,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            Text(l10n.mailImportFileHint, style: muted),
            if (uploading) ...[
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(value: _uploadProgress),
                  ),
                  const SizedBox(width: Space.sm),
                  TextButton(
                    key: const Key('mail_import_cancel'),
                    onPressed: _cancelUpload,
                    child: Text(l10n.mailImportCancelUpload),
                  ),
                ],
              ),
            ],
            if (list.imports.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              const Divider(height: 1),
              for (final item in list.imports)
                _ImportTile(
                  key: ValueKey('mail_import_${item.id}'),
                  item: item,
                  busy: _busy.contains(item.id),
                  onRetry: () => _retry(item),
                  onRemove: () => _remove(item),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One uploaded archive: its state, its counters and, while it runs, the
/// folder being read, so a long import is visibly moving.
class _ImportTile extends StatelessWidget {
  const _ImportTile({
    super.key,
    required this.item,
    required this.busy,
    required this.onRetry,
    required this.onRemove,
  });

  final MailArchiveImport item;
  final bool busy;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final muted = theme.textTheme.bodySmall?.copyWith(color: tokens.textMuted);

    final status = switch (item.status) {
      'running' => l10n.mailImportStatusRunning,
      'done' => l10n.mailImportStatusDone,
      'failed' => l10n.mailImportStatusFailed,
      _ => l10n.mailImportStatusQueued,
    };
    final counts = [
      l10n.mailImportImported(item.messagesImported, item.messagesTotal),
      if (item.messagesSkipped > 0)
        l10n.mailImportAlready(item.messagesSkipped),
      if (item.messagesFailed > 0)
        l10n.mailImportFailedCount(item.messagesFailed),
      if (item.itemsNotMail > 0) l10n.mailImportNotMail(item.itemsNotMail),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.filename,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.isFailed && item.fileAvailable)
                busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        key: ValueKey('mail_import_retry_${item.id}'),
                        tooltip: l10n.retry,
                        icon: const Icon(LucideIcons.rotateCw, size: 16),
                        onPressed: onRetry,
                      ),
              // A running import owns the file on the server; it may go once
              // it has stopped.
              if (item.status != 'running')
                IconButton(
                  key: ValueKey('mail_import_delete_${item.id}'),
                  tooltip: l10n.delete,
                  icon: const Icon(LucideIcons.trash2, size: 16),
                  onPressed: busy ? null : onRemove,
                ),
            ],
          ),
          Text(
            [
              status,
              FormatUtils.bytes(item.sizeBytes),
              FormatUtils.listDate(item.createdAt, locale),
            ].where((s) => s.isNotEmpty).join(' · '),
            style: muted,
          ),
          if (item.isActive) ...[
            const SizedBox(height: Space.xs),
            LinearProgressIndicator(
              value: item.messagesTotal > 0 ? item.progress : null,
            ),
          ],
          const SizedBox(height: Space.xs),
          Text(counts, style: muted),
          if (item.status == 'running' && item.currentFolder.isNotEmpty)
            Text(
              item.currentFolder,
              style: muted,
              overflow: TextOverflow.ellipsis,
            ),
          if (item.error.isNotEmpty)
            Text(
              item.error,
              style: theme.textTheme.bodySmall?.copyWith(color: tokens.danger),
            ),
        ],
      ),
    );
  }
}
