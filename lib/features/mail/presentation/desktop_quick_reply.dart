import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/platform/desktop.dart';
import '../../../core/platform/desktop_keys.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../../shared/utils/error_text.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/widgets/desktop_drop_target.dart';
import '../data/mail_models.dart';
import 'compose_screen.dart';
import 'compose_window.dart';
import 'mail_outbox.dart';
import 'mail_providers.dart';
import 'mail_undo_send.dart';

/// A file chosen for the quick reply: its name, size and contents.
typedef QuickReplyFile = ({String name, Future<int> Function() length, Future<Uint8List> Function() read});

/// «Прикрепить файл» of the quick reply (the system file dialog; faked in
/// tests).
final desktopQuickReplyFilePickerProvider = Provider<Future<List<QuickReplyFile>> Function()>(
  (_) => () async => [
    for (final f in await FilePicker.pickFiles()) (name: f.name, length: () async => await f.length() ?? 0, read: f.readAsBytes),
  ],
);

class _Upload {
  _Upload(this.name, this.size);
  final String name;
  final int size;
  MailComposeAttachment? staged;
  bool failed = false;
}

/// The web reading pane's quick reply (`message-pane.tsx`, desktop): always
/// open at the bottom of the pane under the scrolling letter — whom the
/// reply goes to with a sender / everyone switch, a multi-line field that
/// sends with Ctrl / ⌘ + Enter, attached files (uploaded as the composer
/// does), «Открыть в редакторе» that carries the text and the files over to
/// the floating composer, and after sending «Отправлено: … · HH:MM».
class DesktopQuickReply extends ConsumerStatefulWidget {
  const DesktopQuickReply({super.key, required this.detail, required this.selfAddress});

  final MailMessageDetail detail;
  final String selfAddress;

  @override
  ConsumerState<DesktopQuickReply> createState() => _DesktopQuickReplyState();
}

class _DesktopQuickReplyState extends ConsumerState<DesktopQuickReply> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final List<_Upload> _uploads = [];
  bool _all = false;
  bool _sending = false;

  /// Recipients and time of the reply just sent (the receipt).
  ({List<String> recipients, DateTime at})? _sent;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  ComposeMode get _mode => _all ? ComposeMode.replyAll : ComposeMode.reply;

  ComposeDraftValues _values({String Function(MailMessageDetail m)? quoteHeader}) => ComposeDraftValues.from(
    ComposeArgs(mode: _mode, original: widget.detail),
    selfEmail: widget.selfAddress,
    quoteHeader: quoteHeader ?? (_) => '',
    forwardHeader: '',
  );

  bool get _canReplyAll {
    final d = widget.detail;
    final self = widget.selfAddress.toLowerCase();
    final others = {d.from.toLowerCase(), ...d.to.map((a) => a.toLowerCase()), ...d.cc.map((a) => a.toLowerCase())}..remove(self);
    return others.length > 1;
  }

  bool get _uploading => _uploads.any((u) => u.staged == null && !u.failed);

  Future<void> _pick() async {
    final List<QuickReplyFile> files;
    try {
      files = await ref.read(desktopQuickReplyFilePickerProvider)();
    } on Object catch (e) {
      DiagnosticLog.warn('mail', 'quick reply: file dialog failed', error: e);
      return;
    }
    if (mounted && files.isNotEmpty) await _attach(files);
  }

  /// Files dropped on the reply or pasted into it.
  Future<void> _attachPaths(List<String> paths) => _attach([
    for (final path in paths)
      (name: p.basename(path), length: () => File(path).length(), read: () => File(path).readAsBytes()),
  ]);

  /// The composer's checks (count, the organisation's size limit), then the
  /// upload to `POST /mail/attachments`.
  Future<void> _attach(List<QuickReplyFile> files) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(mailApiProvider);
    final limit = (await ref.read(mailClientConfigProvider.future)).attachmentLimitBytes;
    for (final f in files) {
      if (!mounted) return;
      if (_uploads.length >= MailSendRequest.maxAttachments) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.composeTooManyAttachments)));
        break;
      }
      final _Upload upload;
      final Uint8List bytes;
      try {
        final size = await f.length();
        if (size > limit) {
          messenger.showSnackBar(SnackBar(content: Text(l10n.composeAttachmentTooLarge(f.name, FormatUtils.bytes(limit)))));
          continue;
        }
        upload = _Upload(f.name, size);
        bytes = await f.read();
      } on FileSystemException catch (e) {
        DiagnosticLog.warn('mail', 'quick reply: file unreadable', error: e);
        messenger.showSnackBar(SnackBar(content: Text(l10n.errUnexpected)));
        continue;
      }
      if (!mounted) return;
      setState(() => _uploads.add(upload));
      try {
        final staged = await api.uploadAttachment(filename: f.name, bytes: bytes);
        if (mounted) setState(() => upload.staged = staged);
      } on AppException catch (e) {
        DiagnosticLog.warn('mail', 'quick reply: upload failed', error: e);
        if (mounted) setState(() => upload.failed = true);
      }
    }
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending || _uploading) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final v = _values();
    setState(() => _sending = true);
    final request = MailSendRequest(
      to: v.to,
      cc: v.cc,
      subject: v.subject,
      text: text,
      inReplyTo: v.inReplyTo,
      attachmentIds: [for (final u in _uploads) ?u.staged?.id],
    );
    try {
      await ref.read(mailRepositoryProvider).send(request);
      if (!mounted) return;
      setState(() {
        _sent = (recipients: [...v.to, ...v.cc], at: DateTime.now());
        _text.clear();
        _uploads.clear();
      });
    } on NetworkException catch (e) {
      // No network: the reply waits in «Исходящие».
      DiagnosticLog.warn('mail', 'quick reply offline, queued', error: e);
      await ref.read(mailOutboxProvider.notifier).enqueue(request);
      if (!mounted) return;
      setState(() {
        _text.clear();
        _uploads.clear();
      });
      messenger.showSnackBar(SnackBar(key: const Key('mail_outbox_queued_snackbar'), content: Text(l10n.mailOutboxQueued)));
    } on AppException catch (e) {
      DiagnosticLog.warn('mail', 'quick reply failed', error: e);
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.describe(l10n, e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// «Открыть в редакторе»: the floating composer with the reply's
  /// recipients and subject, the typed text above the quote and the files
  /// already uploaded here.
  void _openComposer() {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final d = widget.detail;
    final text = _text.text.trimRight();
    final files = [for (final u in _uploads) if (u.staged != null) u];
    if (text.isEmpty && files.isEmpty) {
      openCompose(ref, ComposeArgs(mode: _mode, original: d));
      return;
    }
    final v = _values(quoteHeader: (m) => l10n.composeQuoteHeader(FormatUtils.fullDate(m.date, locale), m.senderLabel));
    openCompose(
      ref,
      ComposeArgs.restore(
        ComposeSnapshot(
          modeName: _mode.name,
          to: v.to.join(', '),
          cc: v.cc.join(', '),
          subject: v.subject,
          body: '$text${v.body}',
          inReplyTo: v.inReplyTo,
          attachments: [for (final u in files) ComposeAttachmentSnapshot(name: u.name, size: u.size, staged: u.staged)],
        ),
      ),
    );
    setState(() {
      _text.clear();
      _uploads.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final d = widget.detail;
    final sent = _sent;

    if (sent != null) {
      final time = DateFormat.Hm(Localizations.localeOf(context).toString()).format(sent.at);
      return Container(
        key: const Key('quick_reply_receipt'),
        margin: const EdgeInsets.fromLTRB(Space.mlg, Space.smd, Space.mlg, Space.smd),
        padding: const EdgeInsets.all(Space.smd),
        decoration: BoxDecoration(
          color: t.successSoft,
          borderRadius: BorderRadius.circular(t.radiusMd),
          border: Border.all(color: t.borderStrong, width: t.borderWidth),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.circleCheck, color: t.success, size: 20),
            const SizedBox(width: Space.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.mailQuickReplySent, style: theme.textTheme.titleSmall?.copyWith(color: t.success)),
                  Text(
                    l10n.desktopMailQuickReplySentTo(sent.recipients.join(', '), time),
                    key: const Key('quick_reply_sent_to'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => ref.read(selectedFolderProvider.notifier).select(MailFolderType.sent),
              icon: const Icon(LucideIcons.send, size: 14),
              label: Text(l10n.mailQuickReplyViewSent),
            ),
            TextButton.icon(
              key: const Key('quick_reply_another'),
              onPressed: () {
                setState(() => _sent = null);
                _focus.requestFocus();
              },
              icon: const Icon(LucideIcons.reply, size: 14),
              label: Text(l10n.mailQuickReplyAnother),
            ),
          ],
        ),
      );
    }

    final v = _values();
    final title = _all ? l10n.mailQuickReplyAll(v.to.length + v.cc.length) : l10n.mailQuickReplyTo(d.senderLabel);
    final canSend = _text.text.trim().isNotEmpty && !_sending && !_uploading;
    final small = theme.textTheme.labelSmall?.copyWith(color: t.textTertiary);

    return DesktopDropTarget(
      onFiles: _attachPaths,
      child: Padding(
        key: const Key('quick_reply'),
        padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: t.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: t.border, width: t.borderWidth),
                  ),
                  child: Icon(_all ? LucideIcons.replyAll : LucideIcons.reply, size: 16, color: t.textPrimary),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
                ),
                if (_canReplyAll)
                  OutlinedButton(
                    key: const Key('quick_reply_switch'),
                    onPressed: () => setState(() => _all = !_all),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: Space.smd),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(_all ? l10n.mailQuickReplySwitchOne : l10n.mailQuickReplySwitchAll),
                  ),
              ],
            ),
            const SizedBox(height: Space.sm),
            CallbackShortcuts(
              bindings: {
                commandShortcut(LogicalKeyboardKey.enter): _send,
                commandShortcut(LogicalKeyboardKey.numpadEnter): _send,
              },
              child: TextField(
                key: const Key('quick_reply_text'),
                controller: _text,
                focusNode: _focus,
                minLines: 2,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: isDesktop ? l10n.desktopMailQuickReplyHint('$commandKeyLabel+Enter') : l10n.mailQuickReplyHint,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (_uploads.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Space.sm),
                child: Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.xs,
                  children: [for (final u in _uploads) _chip(context, u)],
                ),
              ),
            const SizedBox(height: Space.xs),
            Row(
              children: [
                IconButton(
                  key: const Key('quick_reply_attach'),
                  tooltip: l10n.desktopMailQuickReplyAttach,
                  icon: const Icon(LucideIcons.paperclip, size: 18),
                  onPressed: _sending ? null : _pick,
                ),
                // Phone: no keyboard shortcut to show, and «Открыть в
                // редакторе» becomes an icon so the row fits a narrow screen.
                if (isDesktop) Text('$commandKeyLabel+Enter', style: small),
                const Spacer(),
                if (isDesktop)
                  TextButton(
                    key: const Key('quick_reply_open_composer'),
                    onPressed: _openComposer,
                    child: Text(l10n.mailQuickReplyOpenComposer),
                  )
                else
                  IconButton(
                    key: const Key('quick_reply_open_composer'),
                    tooltip: l10n.mailQuickReplyOpenComposer,
                    icon: const Icon(LucideIcons.maximize2, size: 18),
                    onPressed: _openComposer,
                  ),
                const SizedBox(width: Space.sm),
                FilledButton.icon(
                  key: const Key('quick_reply_send'),
                  onPressed: canSend ? _send : null,
                  icon: _sending
                      ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: t.textInverse))
                      : const Icon(LucideIcons.send, size: 14),
                  label: Text(l10n.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, _Upload u) {
    final l10n = context.l10n;
    final t = context.tokens;
    final color = u.failed ? t.danger : t.textPrimary;
    final status = u.failed
        ? l10n.desktopMailQuickReplyUploadFailed
        : u.staged == null
        ? l10n.desktopMailQuickReplyUploading
        : FormatUtils.bytes(u.size);
    return Container(
      key: ValueKey('quick_reply_file_${u.name}'),
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: u.failed ? t.dangerSoft : t.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: u.failed ? t.danger.withValues(alpha: 0.4) : t.border, width: t.borderWidth),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.paperclip, size: 14, color: color),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: color)),
          ),
          const SizedBox(width: 6),
          Text(status, style: TextStyle(fontSize: 12, color: t.textTertiary)),
          IconButton(
            tooltip: l10n.desktopMailQuickReplyRemoveFile,
            iconSize: 12,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            padding: EdgeInsets.zero,
            icon: const Icon(LucideIcons.x),
            onPressed: () => setState(() => _uploads.remove(u)),
          ),
        ],
      ),
    );
  }
}
