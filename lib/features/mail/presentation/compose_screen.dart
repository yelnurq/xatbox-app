import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/localization/localization.dart';
import '../../../core/platform/desktop.dart';
import '../../../core/platform/desktop_keys.dart';
import '../../../core/platform/desktop_settings.dart';
import '../../../core/platform/desktop_layout.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../../shared/utils/email_address.dart';
import '../../../shared/utils/error_text.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/utils/html_sanitizer.dart';
import '../../../shared/widgets/desktop_drop_target.dart';
import '../../../shared/widgets/state_view.dart';
import '../data/mail_models.dart';
import '../domain/mail_markup.dart';
import 'compose_formatting.dart';
import 'compose_spell_check.dart';
import 'compose_window.dart';
import 'markup_editing_controller.dart';
import 'mail_providers.dart';
import 'mail_outbox.dart';
import 'mail_undo_send.dart';
import 'mail_ux_settings.dart';
import 'recipient_autocomplete.dart';
import '../../../shared/widgets/app_sheet.dart';

/// A local file handed to the composer (e.g. «Отправить по почте» in chat).
typedef ComposeLocalFile = ({String path, String name});

/// Where composer photos / videos come from.
enum MailMediaSource { cameraPhoto, cameraVideo, gallery }

/// Photos and videos for mail attachments (`image_picker`, as in chat;
/// faked in tests).
final mailMediaPickerProvider =
    Provider<Future<List<ComposeLocalFile>> Function(MailMediaSource source)>(
      (_) => (source) async {
        final picker = ImagePicker();
        switch (source) {
          case MailMediaSource.cameraPhoto:
            final shot = await picker.pickImage(
              source: ImageSource.camera,
              imageQuality: 85,
              maxWidth: 2560,
            );
            return shot == null ? const [] : [(path: shot.path, name: shot.name)];
          case MailMediaSource.cameraVideo:
            final clip = await picker.pickVideo(source: ImageSource.camera);
            return clip == null ? const [] : [(path: clip.path, name: clip.name)];
          case MailMediaSource.gallery:
            final picked = await picker.pickMultipleMedia(
              imageQuality: 85,
              maxWidth: 2560,
            );
            return [for (final x in picked) (path: x.path, name: x.name)];
        }
      },
    );

enum ComposeMode { blank, reply, replyAll, forward, draft }

class ComposeArgs {
  const ComposeArgs({
    required this.mode,
    this.original,
    this.to = const [],
    this.files = const [],
    this.restore,
  });
  const ComposeArgs.blank() : this(mode: ComposeMode.blank);

  /// A new message with [files] attached.
  const ComposeArgs.files(List<ComposeLocalFile> files)
    : this(mode: ComposeMode.blank, files: files);

  /// Reopens a composer from a snapshot («Отменить» after send).
  ComposeArgs.restore(ComposeSnapshot snapshot)
    : this(
        mode: ComposeMode.values
                .where((m) => m.name == snapshot.modeName)
                .firstOrNull ??
            ComposeMode.blank,
        restore: snapshot,
      );

  /// Local files to attach on open.
  final List<ComposeLocalFile> files;

  /// Exact composer state to restore; wins over [original] / [to].
  final ComposeSnapshot? restore;

  /// A new message to [to] (e.g. «Написать письмо» in a contact profile).
  const ComposeArgs.to(List<String> to) : this(mode: ComposeMode.blank, to: to);

  final ComposeMode mode;

  /// Recipients of a blank message.
  final List<String> to;

  /// Message being replied to / forwarded / edited (draft).
  final MailMessageDetail? original;
}

/// Prefilled form values for a compose mode (pure, unit-tested).
class ComposeDraftValues {
  const ComposeDraftValues({
    this.to = const [],
    this.cc = const [],
    this.bcc = const [],
    this.subject = '',
    this.body = '',
    this.inReplyTo,
    this.draftId,
    this.forwardedAttachments = const [],
  });

  final List<String> to;
  final List<String> cc;
  final List<String> bcc;
  final String subject;
  final String body;
  final String? inReplyTo;
  final String? draftId;
  final List<MailAttachment> forwardedAttachments;

  static String _quoteBody(MailMessageDetail m) {
    final text = m.bodyText.isNotEmpty
        ? m.bodyText
        : HtmlSanitizer.toPlainText(m.bodyHtml);
    return text.split('\n').map((l) => '> $l').join('\n');
  }

  static String _prefixed(String prefix, String subject) {
    final s = subject.trim();
    if (s.toLowerCase().startsWith(prefix.toLowerCase())) return s;
    return '$prefix$s';
  }

  static ComposeDraftValues from(
    ComposeArgs args, {
    required String selfEmail,
    required String Function(MailMessageDetail m) quoteHeader,
    required String forwardHeader,
    bool keepColors = false,
  }) {
    final m = args.original;
    final self = selfEmail.toLowerCase();
    switch (args.mode) {
      case ComposeMode.blank:
        return ComposeDraftValues(to: args.to);
      case ComposeMode.reply:
        if (m == null) return const ComposeDraftValues();
        return ComposeDraftValues(
          to: [m.from.toLowerCase()],
          subject: _prefixed('Re: ', m.subject),
          body: '\n\n${quoteHeader(m)}\n${_quoteBody(m)}',
          inReplyTo: m.messageId.isNotEmpty ? m.messageId : m.id,
        );
      case ComposeMode.replyAll:
        if (m == null) return const ComposeDraftValues();
        final to = EmailAddress.dedupe([m.from, ...m.to])
            .where((a) => a != self)
            .toList();
        final cc = EmailAddress.dedupe(m.cc)
            .where((a) => a != self && !to.contains(a))
            .toList();
        return ComposeDraftValues(
          to: to.isEmpty ? [m.from.toLowerCase()] : to,
          cc: cc,
          subject: _prefixed('Re: ', m.subject),
          body: '\n\n${quoteHeader(m)}\n${_quoteBody(m)}',
          inReplyTo: m.messageId.isNotEmpty ? m.messageId : m.id,
        );
      case ComposeMode.forward:
        if (m == null) return const ComposeDraftValues();
        final text = m.bodyText.isNotEmpty
            ? m.bodyText
            : HtmlSanitizer.toPlainText(m.bodyHtml);
        return ComposeDraftValues(
          subject: _prefixed('Fwd: ', m.subject),
          body:
              '\n\n$forwardHeader\nFrom: ${m.from}\nTo: ${m.to.join(', ')}\n'
              'Subject: ${m.subject}\n\n$text',
          forwardedAttachments: m.attachments,
        );
      case ComposeMode.draft:
        if (m == null) return const ComposeDraftValues();
        return ComposeDraftValues(
          to: m.to,
          cc: m.cc,
          bcc: m.bcc,
          subject: m.subject,
          // Keep the formatting of a saved draft editable as markup. The
          // desktop window also keeps colours: MailMarkup.fromHtml only reads
          // text and a fixed set of tags, the general sanitizer would drop
          // every style attribute first.
          body: m.bodyHtml.isNotEmpty
              ? MailMarkup.fromHtml(keepColors ? m.bodyHtml : HtmlSanitizer.sanitize(m.bodyHtml).html, rich: keepColors)
              : m.bodyText,
          draftId: m.id,
        );
    }
  }
}

/// Validation mirroring `POST /mail/send` rules, run before any request.
class ComposeValidation {
  const ComposeValidation._(this.error, {this.invalidAddress});
  final ComposeError? error;
  final String? invalidAddress;

  static ComposeValidation check({
    required List<String> to,
    required List<String> cc,
    required List<String> bcc,
    required String subject,
    required int attachmentCount,
  }) {
    if (to.isEmpty) {
      return const ComposeValidation._(ComposeError.recipientsRequired);
    }
    final bad = EmailAddress.firstInvalid([...to, ...cc, ...bcc]);
    if (bad != null) {
      return ComposeValidation._(
        ComposeError.invalidAddress,
        invalidAddress: bad,
      );
    }
    if (to.length + cc.length + bcc.length > MailSendRequest.maxRecipients) {
      return const ComposeValidation._(ComposeError.tooManyRecipients);
    }
    if (utf8Length(subject) > MailSendRequest.maxSubjectBytes) {
      return const ComposeValidation._(ComposeError.subjectTooLong);
    }
    if (attachmentCount > MailSendRequest.maxAttachments) {
      return const ComposeValidation._(ComposeError.tooManyAttachments);
    }
    return const ComposeValidation._(null);
  }

  /// UTF-8 byte length (the API limits the subject in bytes).
  static int utf8Length(String s) {
    var n = 0;
    for (final r in s.runes) {
      n += r < 0x80 ? 1 : (r < 0x800 ? 2 : (r < 0x10000 ? 3 : 4));
    }
    return n;
  }
}

enum ComposeError {
  recipientsRequired,
  invalidAddress,
  tooManyRecipients,
  subjectTooLong,
  tooManyAttachments,
}

class _PendingAttachment {
  _PendingAttachment.local({
    required this.name,
    required this.size,
    required this.bytes,
  }) : blob = null;
  _PendingAttachment.blob(MailAttachment attachment)
    : name = attachment.filename,
      size = attachment.sizeBytes,
      blob = attachment,
      bytes = null;
  _PendingAttachment.snapshot(ComposeAttachmentSnapshot s)
    : name = s.name,
      size = s.size,
      blob = s.blob,
      bytes = null,
      staged = s.staged;

  final String name;
  final int size;
  final MailAttachment? blob;

  /// Local file contents until staged; released after upload.
  Uint8List? bytes;
  MailComposeAttachment? staged;
  bool uploading = false;
  String? error;
}

/// Window controls of the desktop composer (compose_window.dart): the
/// composer then draws the web's floating compose window instead of a page.
class ComposeWindowChrome {
  const ComposeWindowChrome({
    required this.onClose,
    required this.onMinimize,
    required this.onToggleExpanded,
    required this.expanded,
    this.closeRequest = 0,
  });
  final VoidCallback onClose;
  final VoidCallback onMinimize;
  final VoidCallback onToggleExpanded;
  final bool expanded;

  /// Changes when the window is to save and close (the minimised bar's ✕).
  final int closeRequest;
}

class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key, required this.args, this.window});
  final ComposeArgs args;

  /// Desktop: shown in the floating compose window (null = a page).
  final ComposeWindowChrome? window;

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  late final TextEditingController _to;
  late final TextEditingController _cc;
  late final TextEditingController _bcc;
  late final TextEditingController _subject;
  late final TextEditingController _body;
  final List<_PendingAttachment> _attachments = [];
  String? _inReplyTo;
  String? _draftId;
  bool _showCcBcc = false;
  bool _sending = false;
  bool _savingDraft = false;
  bool _dirty = false;
  String? _error;
  bool _initialized = false;
  bool _preview = false;

  @override
  void initState() {
    super.initState();
    _to = TextEditingController();
    _cc = TextEditingController();
    _bcc = TextEditingController();
    _subject = TextEditingController();
    // The body is shown formatted as it is typed (the web's rich text
    // editor); the text itself stays the markup the letter is built from.
    _body = MailMarkupEditingController();
    // Desktop window: misspelled words underlined, suggestions on right click.
    final body = _body;
    if (isDesktop && body is MailMarkupEditingController) {
      _spell = ComposeSpellChecker(body, enabled: ref.read(desktopSettingsProvider).spellCheck);
    }
    if (widget.window != null) {
      // Deferred: the subject is also filled while the composer is being
      // set up (a restored or prefilled letter), when providers must not
      // change.
      void publishSubject() => Future.microtask(() {
        if (mounted) ref.read(composeWindowSubjectProvider.notifier).set(_subject.text);
      });
      _subject.addListener(publishSubject);
      publishSubject();
    }
    for (final c in [_to, _cc, _bcc, _subject, _body]) {
      c.addListener(() => _dirty = true);
      // Desktop: drafts save themselves a moment after typing stops.
      if (widget.window != null) c.addListener(_scheduleAutosave);
    }
  }

  @override
  void didUpdateWidget(covariant ComposeScreen old) {
    super.didUpdateWidget(old);
    final window = widget.window;
    if (window != null && window.closeRequest != (old.window?.closeRequest ?? 0)) {
      unawaited(_closeFromBar());
    }
  }

  /// The minimised bar's ✕: save and close; if the draft could not be
  /// saved, the window opens again to show why.
  Future<void> _closeFromBar() async {
    await _saveAndClose();
    if (mounted && _dirty) ref.read(composeWindowProvider.notifier).setMinimized(false);
  }

  // ---- desktop autosave (web «Draft saved HH:MM») -------------------------
  static const _autosaveDelay = Duration(seconds: 3);
  Timer? _autosave;
  String? _savedSnapshot;
  DateTime? _savedAt;

  String _snapshot() => [_to.text, _cc.text, _bcc.text, _subject.text, _body.text].join('\u0000');

  void _scheduleAutosave() {
    // Selection moves notify too: only real edits count.
    if (_snapshot() == (_savedSnapshot ?? _initialSnapshot)) return;
    _autosave?.cancel();
    _autosave = Timer(_autosaveDelay, () => unawaited(_autoSaveNow()));
  }

  String? _initialSnapshot;

  Future<void> _autoSaveNow() async {
    if (!mounted || _sending || _savingDraft) return;
    final snap = _snapshot();
    if (snap == (_savedSnapshot ?? _initialSnapshot)) return;
    final empty = [_to.text, _cc.text, _bcc.text, _subject.text, _body.text].every((v) => v.trim().isEmpty);
    if (empty) return;
    await _saveDraft(quiet: true);
    if (mounted) setState(() {}); // «Черновик сохранён HH:MM»
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final restore = widget.args.restore;
    if (restore != null) {
      _to.text = restore.to;
      _cc.text = restore.cc;
      _bcc.text = restore.bcc;
      _subject.text = restore.subject;
      _body.text = restore.body;
      _inReplyTo = restore.inReplyTo;
      _draftId = restore.draftId;
      _showCcBcc = restore.cc.isNotEmpty || restore.bcc.isNotEmpty;
      _attachments.addAll(restore.attachments.map(_PendingAttachment.snapshot));
      // Not sent: leaving asks before discarding.
      _dirty = true;
      _initialSnapshot = _snapshot();
      return;
    }
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final self = ref.read(currentUserProvider)?.email ?? '';
    final values = ComposeDraftValues.from(
      widget.args,
      selfEmail: self,
      quoteHeader: (m) => l10n.composeQuoteHeader(
        FormatUtils.fullDate(m.date, locale),
        m.senderLabel,
      ),
      forwardHeader: l10n.composeForwardHeader,
      keepColors: widget.window != null,
    );
    _to.text = values.to.join(', ');
    _cc.text = values.cc.join(', ');
    _bcc.text = values.bcc.join(', ');
    _subject.text = values.subject;
    _body.text = values.body;
    _inReplyTo = values.inReplyTo;
    _draftId = values.draftId;
    _showCcBcc = values.cc.isNotEmpty || values.bcc.isNotEmpty;
    _attachments.addAll(
      values.forwardedAttachments.map(_PendingAttachment.blob),
    );
    _dirty = false;
    _initialSnapshot = _snapshot();
    if (widget.args.files.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _attachLocalFiles(widget.args.files),
      );
    }
  }

  /// Desktop window only (null elsewhere).
  ComposeSpellChecker? _spell;

  @override
  void dispose() {
    _spell?.dispose();
    _autosave?.cancel();
    for (final c in [_to, _cc, _bcc, _subject, _body]) {
      c.dispose();
    }
    super.dispose();
  }

  String _composeErrorText(AppLocalizations l10n, ComposeValidation v) =>
      switch (v.error!) {
        ComposeError.recipientsRequired => l10n.composeRecipientsRequired,
        ComposeError.invalidAddress => l10n.composeInvalidAddress(
          v.invalidAddress ?? '',
        ),
        ComposeError.tooManyRecipients => l10n.composeTooManyRecipients,
        ComposeError.subjectTooLong => l10n.composeSubjectTooLong,
        ComposeError.tooManyAttachments => l10n.composeTooManyAttachments,
      };

  Future<void> _pickFiles() async {
    final files = await FilePicker.pickFiles();
    if (!mounted) return;
    await _attachAll([
      for (final f in files)
        (
          name: f.name,
          length: () async => await f.length() ?? 0,
          read: f.readAsBytes,
        ),
    ]);
  }

  /// Local paths (camera, gallery, chat files) through the same checks and
  /// upload as picked files.
  Future<void> _attachLocalFiles(List<ComposeLocalFile> files) => _attachAll([
    for (final f in files)
      (
        name: f.name,
        length: () => File(f.path).length(),
        read: () => File(f.path).readAsBytes(),
      ),
  ]);

  Future<void> _pickMedia(MailMediaSource source) async {
    final l10n = context.l10n;
    try {
      final files = await ref.read(mailMediaPickerProvider)(source);
      if (!mounted || files.isEmpty) return;
      await _attachLocalFiles(files);
    } on Object catch (e) {
      DiagnosticLog.warn('mail', 'media pick failed', error: e);
      if (mounted) setState(() => _error = l10n.errUnexpected);
    }
  }

  Future<void> _attachAll(List<_LocalSource> files) async {
    final l10n = context.l10n;
    final limit = (await ref.read(mailClientConfigProvider.future))
        .attachmentLimitBytes;
    if (!mounted) return;
    for (final f in files) {
      if (_attachments.length >= MailSendRequest.maxAttachments) {
        setState(() => _error = l10n.composeTooManyAttachments);
        break;
      }
      final int size;
      final Uint8List bytes;
      try {
        size = await f.length();
        if (size > limit) {
          if (!mounted) return;
          setState(
            () => _error = l10n.composeAttachmentTooLarge(
              f.name,
              FormatUtils.bytes(limit),
            ),
          );
          continue;
        }
        bytes = await f.read();
      } on FileSystemException catch (e) {
        DiagnosticLog.warn('mail', 'attachment unreadable', error: e);
        if (!mounted) return;
        setState(() => _error = l10n.errUnexpected);
        continue;
      }
      if (!mounted) return;
      final pending = _PendingAttachment.local(
        name: f.name,
        size: size,
        bytes: bytes,
      );
      setState(() {
        _attachments.add(pending);
        _dirty = true;
      });
      _upload(pending);
    }
  }

  Future<void> _attachMenu() async {
    final l10n = context.l10n;
    final choice = await showAppSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('compose_attach_file'),
              leading: const Icon(LucideIcons.file),
              title: Text(l10n.mailUxAttachFile),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
            ListTile(
              key: const Key('compose_attach_gallery'),
              leading: const Icon(LucideIcons.images),
              title: Text(l10n.mailUxAttachGallery),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            // image_picker has no camera on desktop.
            if (!isDesktop) ...[
              ListTile(
                key: const Key('compose_attach_photo'),
                leading: const Icon(LucideIcons.camera),
                title: Text(l10n.mailUxAttachCameraPhoto),
                onTap: () => Navigator.pop(ctx, 'photo'),
              ),
              ListTile(
                key: const Key('compose_attach_video'),
                leading: const Icon(LucideIcons.video),
                title: Text(l10n.mailUxAttachCameraVideo),
                onTap: () => Navigator.pop(ctx, 'video'),
              ),
            ],
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'file':
        await _pickFiles();
      case 'gallery':
        await _pickMedia(MailMediaSource.gallery);
      case 'photo':
        await _pickMedia(MailMediaSource.cameraPhoto);
      case 'video':
        await _pickMedia(MailMediaSource.cameraVideo);
    }
  }

  Future<void> _upload(_PendingAttachment a) async {
    if (a.staged != null || a.uploading) return;
    setState(() {
      a.uploading = true;
      a.error = null;
    });
    final api = ref.read(mailApiProvider);
    try {
      final bytes = a.bytes ?? await api.fetchBlobBytes(a.blob!);
      a.bytes = null; // do not hold file bytes longer than needed
      final staged = await api.uploadAttachment(filename: a.name, bytes: bytes);
      if (!mounted) return;
      setState(() => a.staged = staged);
    } on AppException catch (e) {
      DiagnosticLog.warn('mail', 'attachment upload failed', error: e);
      if (!mounted) return;
      setState(() => a.error = ErrorText.describe(context.l10n, e));
    } finally {
      if (mounted) setState(() => a.uploading = false);
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    final l10n = context.l10n;
    final to = EmailAddress.dedupe(EmailAddress.split(_to.text));
    final cc = EmailAddress.dedupe(EmailAddress.split(_cc.text));
    final bcc = EmailAddress.dedupe(EmailAddress.split(_bcc.text));
    final validation = ComposeValidation.check(
      to: to,
      cc: cc,
      bcc: bcc,
      subject: _subject.text,
      attachmentCount: _attachments.length,
    );
    if (validation.error != null) {
      setState(() => _error = _composeErrorText(l10n, validation));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Stage anything not yet uploaded (forwarded blobs, retried failures).
      for (final a in _attachments) {
        if (a.staged == null) await _upload(a);
        if (a.staged == null) {
          setState(() => _error = a.error ?? l10n.errUnexpected);
          return;
        }
      }
      final request = MailSendRequest(
        to: to,
        cc: cc,
        bcc: bcc,
        subject: _subject.text.trim(),
        // Both bodies: clean plain text and allow-listed HTML.
        text: MailMarkup.toPlainText(_body.text, rich: widget.window != null),
        html: MailMarkup.toHtml(_body.text, rich: widget.window != null),
        inReplyTo: _inReplyTo,
        attachmentIds: _attachments.map((a) => a.staged!.id).toList(),
      );
      unawaited(
        ref
            .read(mailRecentRecipientsProvider.notifier)
            .remember([...to, ...cc, ...bcc]),
      );
      final delay = ref.read(mailUxSettingsProvider).undoSendSeconds;
      if (delay > 0) {
        await _sendLater(request, Duration(seconds: delay), messenger);
        return;
      }
      try {
        await ref
            .read(mailRepositoryProvider)
            .send(request, draftIdToDelete: _draftId);
      } on NetworkException catch (e) {
        // Without network: the letter waits in «Исходящие».
        DiagnosticLog.warn('mail', 'send failed offline, queued', error: e);
        await ref.read(mailOutboxProvider.notifier).enqueue(request, draftId: _draftId);
        _dirty = false;
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(key: const Key('mail_outbox_queued_snackbar'), content: Text(l10n.mailOutboxQueued)));
        _close();
        return;
      }
      _dirty = false;
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.composeSent)));
      _close();
    } on AppException catch (e) {
      DiagnosticLog.warn('mail', 'send failed', error: e);
      if (!mounted) return;
      setState(() => _error = ErrorText.describe(l10n, e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// «Отменить отправку»: saves the form as a draft (so a killed app loses
  /// nothing), closes the composer and leaves the send to
  /// [mailUndoSendProvider]; «Отменить» reopens this exact composer.
  Future<void> _sendLater(
    MailSendRequest request,
    Duration delay,
    ScaffoldMessengerState messenger,
  ) async {
    final l10n = context.l10n;
    var draftId = _draftId;
    try {
      draftId = await ref
          .read(mailRepositoryProvider)
          .saveDraft(
            MailDraftRequest(
              to: request.to,
              cc: request.cc,
              bcc: request.bcc,
              subject: request.subject,
              text: request.text,
              html: request.html,
            ),
            existingId: _draftId,
          );
      _draftId = draftId;
    } on AppException catch (e) {
      // Still sendable; only the kill-safety copy is missing.
      DiagnosticLog.warn('mail', 'safety draft not saved', error: e);
    }
    if (!mounted) return;
    final snapshot = ComposeSnapshot(
      modeName: widget.args.mode.name,
      to: _to.text,
      cc: _cc.text,
      bcc: _bcc.text,
      subject: _subject.text,
      body: _body.text,
      inReplyTo: _inReplyTo,
      draftId: draftId,
      attachments: [
        for (final a in _attachments)
          ComposeAttachmentSnapshot(
            name: a.name,
            size: a.size,
            staged: a.staged,
            blob: a.blob,
          ),
      ],
    );
    final router = ref.read(appRouterProvider);
    final notifier = ref.read(mailUndoSendProvider.notifier);
    // Captured now: «Отменить» fires after this composer is gone.
    final desktop = ref.read(desktopLayoutProvider);
    final windows = ref.read(composeWindowProvider.notifier);
    void reopen(ComposeSnapshot s) => desktop
        ? windows.open(ComposeArgs.restore(s))
        : unawaited(router.push(Routes.mailCompose, extra: ComposeArgs.restore(s)));
    final pending = notifier.schedule(
      request: request,
      snapshot: snapshot,
      delay: delay,
      onSent: () => messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.composeSent))),
      onQueued: () => messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(key: const Key('mail_outbox_queued_snackbar'), content: Text(l10n.mailOutboxQueued))),
      onFailed: (e) => messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.mailUxSendFailed(ErrorText.describe(l10n, e))),
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: l10n.mailUxEdit,
              onPressed: () => reopen(snapshot),
            ),
          ),
        ),
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('undo_send_snackbar'),
          content: Text(l10n.mailUxSending),
          duration: delay,
          action: SnackBarAction(
            label: l10n.mailUndo,
            onPressed: () {
              final restored = notifier.cancel(pending.id);
              if (restored != null) reopen(restored);
            },
          ),
        ),
      );
    _dirty = false;
    _close();
  }

  /// Leaves the composer: the page pops, the desktop window closes.
  void _close() {
    final window = widget.window;
    if (window != null) {
      window.onClose();
    } else {
      context.pop();
    }
  }

  /// The window's ✕ (web «Сохранить и закрыть»): a started message is kept
  /// as a draft instead of asking.
  Future<void> _saveAndClose() async {
    if (_dirty && !_sending) await _saveDraft();
    if (mounted && !_dirty) _close();
  }

  Future<void> _saveDraft({bool quiet = false}) async {
    if (_savingDraft || _discarded) return;
    final l10n = context.l10n;
    setState(() {
      _savingDraft = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final request = MailDraftRequest(
        to: EmailAddress.dedupe(EmailAddress.split(_to.text)),
        cc: EmailAddress.dedupe(EmailAddress.split(_cc.text)),
        bcc: EmailAddress.dedupe(EmailAddress.split(_bcc.text)),
        subject: _subject.text.trim(),
        text: MailMarkup.toPlainText(_body.text, rich: widget.window != null),
        html: MailMarkup.toHtml(_body.text, rich: widget.window != null),
      );
      _draftId = await ref
          .read(mailRepositoryProvider)
          .saveDraft(request, existingId: _draftId);
      _dirty = false;
      if (!quiet) messenger.showSnackBar(SnackBar(content: Text(l10n.composeDraftSaved)));
      if (widget.window != null) {
        _savedSnapshot = _snapshot();
        _savedAt = DateTime.now();
      }
    } on AppException catch (e) {
      DiagnosticLog.warn('mail', 'save draft failed', error: e);
      if (!mounted) return;
      setState(() => _error = ErrorText.describe(l10n, e));
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  /// The window's 🗑 (web «Удалить черновик»): asks whenever something was
  /// written or saved, then deletes the saved draft too — an autosave must
  /// not leave it behind in «Черновики».
  Future<void> _discardWindow() async {
    final written = _dirty || _draftId != null || _snapshot() != _initialSnapshot;
    if (written && !await _askDiscard()) return;
    if (!mounted) return;
    _discarded = true;
    _autosave?.cancel();
    final id = _draftId;
    if (id != null) {
      try {
        await ref.read(mailRepositoryProvider).delete(id, permanent: true);
      } on AppException catch (e) {
        DiagnosticLog.warn('mail', 'discarded draft not deleted', error: e);
      }
    }
    if (mounted) widget.window?.onClose();
  }

  /// Set once the window's draft is thrown away: nothing may save it again.
  bool _discarded = false;

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return _askDiscard();
  }

  Future<bool> _askDiscard() async {
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.composeDiscardTitle),
        content: Text(l10n.composeDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('compose_discard_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.composeDiscard),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final canSend = ref.watch(hasPermissionProvider(Permissions.mailSend));
    final title = switch (widget.args.mode) {
      ComposeMode.blank => l10n.composeTitleNew,
      ComposeMode.reply || ComposeMode.replyAll => l10n.composeTitleReply,
      ComposeMode.forward => l10n.composeTitleForward,
      ComposeMode.draft => l10n.composeTitleDraft,
    };
    final busy = _sending || _savingDraft;
    final body = _body;
    if (body is MailMarkupEditingController) {
      body
        ..linkColor = tokens.info
        ..quoteColor = tokens.textSecondary;
    }
    final window = widget.window;
    if (window != null) {
      // Desktop: Ctrl+Enter sends; files dropped on the window or pasted
      // (Ctrl+V: copied in Explorer, a screenshot) are attached.
      return CallbackShortcuts(
        bindings: {
          commandShortcut(LogicalKeyboardKey.enter): () {
            if (!busy && canSend) unawaited(_send());
          },
        },
        child: DesktopDropTarget(
          enabled: canSend && !_sending,
          onFiles: (paths) => _attachLocalFiles([for (final f in paths) (path: f, name: p.basename(f))]),
          child: _buildWindow(context, window, canSend: canSend, busy: busy),
        ),
      );
    }

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            IconButton(
              tooltip: l10n.composeAddAttachment,
              icon: const Icon(LucideIcons.paperclip),
              key: const Key('compose_attach'),
              onPressed: busy || !canSend ? null : _attachMenu,
            ),
            IconButton(
              tooltip: l10n.composeSaveDraft,
              icon: _savingDraft
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.save),
              onPressed: busy || !canSend ? null : _saveDraft,
            ),
            IconButton(
              key: const Key('compose_send'),
              tooltip: l10n.send,
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.send),
              onPressed: busy || !canSend ? null : _send,
            ),
          ],
        ),
        body: !canSend
            ? StateView.error(
                message: l10n.composeNoSendPermission,
                icon: LucideIcons.lock,
              )
            : ListView(
                padding: const EdgeInsets.all(Space.md),
                children: [
                  if (_error != null) ...[
                    ErrorMessage(_error!),
                    const SizedBox(height: Space.md),
                  ],
                  RecipientField(
                    controller: _to,
                    label: l10n.mailTo,
                    hint: l10n.composeRecipientHint,
                    enabled: !busy,
                    fieldKey: const Key('compose_to'),
                    trailing: IconButton(
                      icon: Icon(
                        _showCcBcc ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                      ),
                      onPressed: () => setState(() => _showCcBcc = !_showCcBcc),
                    ),
                  ),
                  if (_showCcBcc) ...[
                    const SizedBox(height: Space.sm),
                    RecipientField(
                      controller: _cc,
                      label: l10n.mailCc,
                      enabled: !busy,
                    ),
                    const SizedBox(height: Space.sm),
                    RecipientField(
                      controller: _bcc,
                      label: l10n.mailBcc,
                      enabled: !busy,
                    ),
                  ],
                  const SizedBox(height: Space.sm),
                  TextField(
                    controller: _subject,
                    key: const Key('compose_subject'),
                    enabled: !busy,
                    decoration: InputDecoration(labelText: l10n.mailSubject),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: Space.sm),
                  ComposeFormattingToolbar(
                    controller: _body,
                    enabled: !busy,
                    preview: _preview,
                    onTogglePreview: () =>
                        setState(() => _preview = !_preview),
                  ),
                  if (_preview)
                    ComposePreview(markup: _body.text)
                  else
                    ComposeFormattingShortcuts(
                      controller: _body,
                      child: TextField(
                        controller: _body,
                        key: const Key('compose_body'),
                        enabled: !busy,
                        decoration: InputDecoration(
                          labelText: l10n.mailBody,
                          alignLabelWithHint: true,
                        ),
                        minLines: 8,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                      ),
                    ),
                  const SizedBox(height: Space.xs),
                  Text(
                    l10n.mailFormatHelp,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: tokens.textMuted),
                  ),
                  const SizedBox(height: Space.sm),
                  const ComposeSignaturePreview(),
                  if (_attachments.isNotEmpty) ...[
                    const SizedBox(height: Space.md),
                    Text(
                      widget.args.mode == ComposeMode.forward
                          ? l10n.composeForwardedAttachments
                          : l10n.mailAttachments,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    for (final a in _attachments)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: a.uploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                a.error != null
                                    ? LucideIcons.circleAlert
                                    : (a.staged != null
                                          ? LucideIcons.circleCheck
                                          : LucideIcons.paperclip),
                                color: a.error != null
                                    ? tokens.danger
                                    : (a.staged != null
                                          ? tokens.success
                                          : null),
                              ),
                        title: Text(
                          a.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(a.error ?? FormatUtils.bytes(a.size)),
                        trailing: IconButton(
                          icon: const Icon(LucideIcons.x),
                          onPressed: busy
                              ? null
                              : () => setState(() => _attachments.remove(a)),
                        ),
                        onTap: a.error != null ? () => _upload(a) : null,
                      ),
                  ],
                ],
              ),
      ),
    );
  }

  /// The web's floating compose window (`.compose-window`): a 48px title bar
  /// with minimise / expand / close, borderless To · Cc/Bcc · Subject rows
  /// on hairlines, the body filling the rest, attachments and signature
  /// under it, and the footer «Отправить ➤» · attach · draft.
  Widget _buildWindow(BuildContext context, ComposeWindowChrome window, {required bool canSend, required bool busy}) {
    final l10n = context.l10n;
    final t = context.tokens;
    final body = _body;
    if (body is MailMarkupEditingController) {
      body
        ..linkColor = t.info
        ..quoteColor = t.textSecondary;
    }
    final theme = Theme.of(context);
    final hairline = BorderSide(color: t.border, width: t.borderWidth);
    final subject = _subject.text.trim();
    final bare = const InputDecoration(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      filled: false,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(vertical: 12),
    );
    Widget row({required String label, required Widget field, Widget? trailing}) => Container(
      decoration: BoxDecoration(border: Border(bottom: hairline)),
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, right: Space.sm),
            child: Text(label, style: TextStyle(fontSize: 14, color: t.textSecondary)),
          ),
          Expanded(child: field),
          ?trailing,
        ],
      ),
    );
    Widget headerButton(IconData icon, String tooltip, VoidCallback onPressed, {Key? key}) => IconButton(
      key: key,
      tooltip: tooltip,
      iconSize: 16,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        foregroundColor: t.textSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusSm)),
      ),
      icon: Icon(icon),
      onPressed: onPressed,
    );

    return Theme(
      data: theme.copyWith(inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
      )),
      child: Material(
        color: t.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title bar.
            Container(
              height: 48,
              padding: const EdgeInsets.only(left: Space.md, right: 10),
              decoration: BoxDecoration(color: t.surfaceSubtle, border: Border(bottom: hairline)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      subject.isEmpty ? l10n.composeTitleNew : subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: t.fontDisplay, fontSize: 14, fontWeight: FontWeight.w500, color: t.textPrimary),
                    ),
                  ),
                  if (_savedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(right: Space.xs),
                      child: Text(
                        l10n.composeDraftSavedAt(TimeOfDay.fromDateTime(_savedAt!).format(context)),
                        key: const Key('compose_draft_saved'),
                        style: TextStyle(fontSize: 12, color: t.textTertiary),
                      ),
                    ),
                  headerButton(LucideIcons.minus, l10n.composeMinimize, window.onMinimize, key: const Key('compose_window_minimize')),
                  headerButton(
                    window.expanded ? LucideIcons.minimize2 : LucideIcons.maximize2,
                    window.expanded ? l10n.composeRestoreSize : l10n.composeExpand,
                    window.onToggleExpanded,
                  ),
                  headerButton(LucideIcons.x, l10n.composeSaveAndClose, () => unawaited(_saveAndClose()), key: const Key('compose_window_close')),
                ],
              ),
            ),
            if (!canSend)
              Expanded(child: StateView.error(message: l10n.composeNoSendPermission, icon: LucideIcons.lock))
            else ...[
              if (_error != null)
                Padding(padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0), child: ErrorMessage(_error!)),
              row(
                label: l10n.mailTo,
                field: RecipientChipsField(controller: _to, hint: l10n.composeRecipientHint, enabled: !busy, fieldKey: const Key('compose_to')),
                trailing: _showCcBcc
                    ? null
                    : TextButton(
                        onPressed: () => setState(() => _showCcBcc = true),
                        style: TextButton.styleFrom(foregroundColor: t.textSecondary, textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        child: Text(l10n.composeAddCcBcc),
                      ),
              ),
              if (_showCcBcc) ...[
                row(label: l10n.mailCc, field: RecipientChipsField(controller: _cc, enabled: !busy)),
                row(label: l10n.mailBcc, field: RecipientChipsField(controller: _bcc, enabled: !busy)),
              ],
              Container(
                decoration: BoxDecoration(border: Border(bottom: hairline)),
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                child: TextField(
                  controller: _subject,
                  key: const Key('compose_subject'),
                  enabled: !busy,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: bare.copyWith(hintText: l10n.mailSubject),
                  textInputAction: TextInputAction.next,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.md),
                  children: [
                    ComposeFormattingToolbar(
                      controller: _body,
                      enabled: !busy,
                      preview: _preview,
                      onTogglePreview: () => setState(() => _preview = !_preview),
                      richExtras: true,
                    ),
                    if (_preview)
                      ComposePreview(markup: _body.text, keepStyles: true)
                    else
                      ComposeFormattingShortcuts(
                        controller: _body,
                        // Repaints the spelling underline when a check lands.
                        child: ListenableBuilder(
                          listenable: _spell ?? _body,
                          builder: (context, _) => TextField(
                            controller: _body,
                            key: const Key('compose_body'),
                            enabled: !busy,
                            autofocus: widget.args.mode != ComposeMode.blank,
                            decoration: bare,
                            minLines: 10,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            contextMenuBuilder: (context, state) => AdaptiveTextSelectionToolbar.buttonItems(
                              anchors: state.contextMenuAnchors,
                              buttonItems: [...?_spell?.suggestionItems(state), ...state.contextMenuButtonItems],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: Space.sm),
                    const ComposeSignaturePreview(),
                    if (_attachments.isNotEmpty) ...[
                      const SizedBox(height: Space.sm),
                      for (final a in _attachments)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(horizontal: Space.smd, vertical: Space.sm),
                          decoration: BoxDecoration(
                            border: Border.all(color: t.border),
                            borderRadius: BorderRadius.circular(t.radiusMd),
                            color: t.surfaceSubtle,
                          ),
                          child: Row(
                            children: [
                              a.uploading
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Icon(
                                      a.error != null ? LucideIcons.circleAlert : LucideIcons.paperclip,
                                      size: 16,
                                      color: a.error != null ? t.danger : t.textTertiary,
                                    ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              ),
                              Text(
                                a.error ?? FormatUtils.bytes(a.size),
                                style: TextStyle(fontSize: 12, color: a.error != null ? t.danger : t.textTertiary),
                              ),
                              IconButton(
                                iconSize: 14,
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(LucideIcons.x),
                                onPressed: busy ? null : () => setState(() => _attachments.remove(a)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              // Footer.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: Space.smd),
                decoration: BoxDecoration(border: Border(top: hairline)),
                child: Row(
                  children: [
                    FilledButton.icon(
                      key: const Key('compose_send'),
                      onPressed: busy ? null : _send,
                      iconAlignment: IconAlignment.end,
                      icon: _sending
                          ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: t.textInverse))
                          : const Icon(LucideIcons.send, size: 16),
                      label: Text(l10n.send),
                    ),
                    const SizedBox(width: Space.xs),
                    IconButton(
                      key: const Key('compose_attach'),
                      tooltip: l10n.composeAddAttachment,
                      iconSize: 18,
                      icon: const Icon(LucideIcons.paperclip),
                      onPressed: busy ? null : _attachMenu,
                    ),
                    IconButton(
                      tooltip: l10n.composeSaveDraft,
                      iconSize: 18,
                      icon: _savingDraft
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(LucideIcons.save),
                      onPressed: busy ? null : _saveDraft,
                    ),
                    const Spacer(),
                    IconButton(
                      key: const Key('compose_discard'),
                      tooltip: l10n.composeDiscard,
                      iconSize: 18,
                      style: IconButton.styleFrom(foregroundColor: t.textTertiary),
                      icon: const Icon(LucideIcons.trash2),
                      onPressed: busy
                          ? null
                          : _discardWindow,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

typedef _LocalSource = ({
  String name,
  Future<int> Function() length,
  Future<Uint8List> Function() read,
});
