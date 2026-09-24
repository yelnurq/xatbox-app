import 'dart:async';

import '../../calendar/presentation/event_edit_screen.dart' show EventEditArgs;
import '../../calendar/presentation/calendar_widgets.dart' show openEventEditor;
import '../../calendar/presentation/calendar_providers.dart' show calendarEnabledProvider, calendarCanCreateProvider;
import '../../calendar/data/calendar_models.dart' show DraftParticipant;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/localization/localization.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/platform/desktop.dart';
import '../../../core/platform/desktop_keys.dart';
import '../../../core/platform/desktop_layout.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../../shared/utils/error_text.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/utils/html_sanitizer.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/desktop_file_gestures.dart';
import '../../../shared/widgets/ds/x_badge.dart';
import '../../../shared/widgets/state_view.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../chat/presentation/chat_share.dart';
import '../../chat/presentation/translation/translation_providers.dart';
import '../data/mail_models.dart';
import '../data/mail_repository.dart';
import '../domain/link_check.dart';
import '../domain/lookalike.dart';
import 'attachment_sheet.dart';
import 'compose_screen.dart';
import 'delivery_sheet.dart';
import 'folder_names.dart';
import 'invitation_card.dart';
import '../../tasks/presentation/tasks_providers.dart';
import 'desktop_mail_body.dart';
import 'desktop_quick_reply.dart';
import 'mail_html.dart';
import 'mail_print.dart';
import 'mail_providers.dart';
import 'mail_selection.dart';
import 'message_window.dart';
import 'mail_to_chat.dart';
import 'mail_translation.dart';
import '../../../shared/widgets/app_sheet.dart';
import 'compose_window.dart';

/// `GET /mail/messages/{id}` viewer laid out like the web reading pane
/// (`message-pane.tsx`): the 48px toolbar (reply / reply all / forward,
/// bookmark, save to collection, not spam, remind me, delete, more), subject
/// with folder badge and conversation line, the opened message block (avatar,
/// sender, external-sender and recipients badges, date), the lookalike-domain
/// warning, body, attachment chips and the conversation cards.
///
/// [embedded] renders it as the right pane of the wide layout: no AppBar, the
/// toolbar's close button hands control back through [onClose].
class MessageDetailScreen extends ConsumerStatefulWidget {
  const MessageDetailScreen({
    super.key,
    required this.messageId,
    this.embedded = false,
    this.onClose,
    this.onOpenMessage,
    this.keyboard = true,
    this.listHidden = false,
    this.onToggleList,
  });

  final String messageId;
  final bool embedded;
  final VoidCallback? onClose;

  /// Desktop: the web's shortcuts (R, A, F, U, S, Delete, Esc, Ctrl+P) act
  /// on this message. Off in the separate message windows, so a key never
  /// acts on two messages.
  final bool keyboard;

  /// Opens another message of the conversation in place (wide layout);
  /// pushes the detail route when null.
  final ValueChanged<String>? onOpenMessage;

  /// Desktop reading pane: «Скрыть список / Показать список» (web eye-off
  /// button) — the list is hidden and the letter takes the full width.
  final bool listHidden;
  final VoidCallback? onToggleList;

  @override
  ConsumerState<MessageDetailScreen> createState() => _MessageDetailScreenState();
}

class _MessageDetailScreenState extends ConsumerState<MessageDetailScreen> {
  MailMessageDetail? _detail;
  Object? _error;
  bool _loading = true;
  bool _fromCache = false;
  bool _showHtml = true;
  bool _busy = false;

  /// «Перевести письмо» is on for this message id.
  String? _translatedId;
  CancelToken? _cancel;
  StreamSubscription<MailEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(mailRepositoryProvider).events.listen(_onEvent);
    _load();
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(MailEvent event) {
    final d = _detail;
    if (d == null) return;
    if (event is MailFlagsChanged && event.id == d.id) {
      setState(() => _detail = d.copyWith(isRead: event.isRead, isStarred: event.isStarred));
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    _cancel = CancelToken();
    try {
      final result = await ref.read(mailRepositoryProvider).getMessage(widget.messageId, cancelToken: _cancel);
      if (!mounted) return;
      setState(() {
        _detail = result.detail;
        _fromCache = result.fromCache;
        _loading = false;
      });
    } on CancelledException {
      // closed
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Leaves the message: pops the route, or clears the pane.
  void _leave() {
    if (widget.embedded) {
      widget.onClose?.call();
    } else if (mounted && context.canPop()) {
      context.pop();
    }
  }

  Future<void> _guard(Future<void> Function() action, {String? successText, SnackBarAction? successAction}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await action();
      if (successText != null) messenger.showSnackBar(SnackBar(content: Text(successText), action: successAction));
    } on AppException catch (e) {
      DiagnosticLog.warn('mail', 'message action failed', error: e);
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.describe(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm({required String title, required String body, required String action, IconData? icon}) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: icon == null ? null : Icon(icon, color: ctx.tokens.danger),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(key: const Key('phishing_cancel'), onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            key: const Key('phishing_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: ctx.tokens.danger),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true && mounted;
  }

  Future<void> _delete(MailMessageDetail d) async {
    final l10n = context.l10n;
    final permanent = d.deleteIsPermanent;
    if (permanent && !await _confirm(title: l10n.mailDeleteForever, body: l10n.mailDeleteForeverConfirm, action: l10n.delete)) return;
    await _guard(
      () async {
        await ref.read(mailRepositoryProvider).delete(d.id, permanent: permanent);
        _leave();
      },
      successText: permanent ? l10n.mailDeleted : l10n.mailMovedToTrash,
      successAction: permanent ? null : _undoMove(d),
    );
  }

  /// «Отменить» after the letter left its folder (web `message-pane.tsx`
  /// `moveTo` / `toTrash`): it goes back where it was. The page may be gone
  /// by then, so nothing here needs it.
  SnackBarAction? _undoMove(MailMessageDetail d) {
    final repo = ref.read(mailRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    return SnackBarAction(
      label: l10n.mailUndo,
      onPressed: () async {
        try {
          await repo.moveTo(d.id, d.folder);
          showMailRestored(messenger, l10n);
        } on AppException catch (e) {
          DiagnosticLog.warn('mail', 'undo move failed', error: e);
          messenger.showSnackBar(SnackBar(content: Text(ErrorText.describe(l10n, e))));
        }
      },
    );
  }

  Future<void> _report(MailMessageDetail d, MailReportKind kind) async {
    final l10n = context.l10n;
    await _guard(
      () async {
        await ref.read(mailRepositoryProvider).report(d.id, kind);
        _leave();
      },
      successText: switch (kind) {
        MailReportKind.ham => l10n.mailReportedHam,
        MailReportKind.phishing => l10n.mailReportedPhishing,
        MailReportKind.spam => l10n.mailReportedSpam,
      },
    );
  }

  /// Phishing moves the message to Spam, so it is confirmed first.
  Future<void> _reportPhishing(MailMessageDetail d) async {
    final l10n = context.l10n;
    if (!await _confirm(
      title: l10n.mailReportPhishingTitle,
      body: l10n.mailReportPhishingBody,
      action: l10n.mailReportPhishingConfirm,
      icon: LucideIcons.triangleAlert,
    )) {
      return;
    }
    await _report(d, MailReportKind.phishing);
  }

  Future<void> _moveTo(MailMessageDetail d) async {
    final l10n = context.l10n;
    final target = await pickMoveFolder(context, d.folder);
    if (target == null || !mounted) return;
    await _guard(() async {
      await ref.read(mailRepositoryProvider).moveTo(d.id, target);
      _leave();
    }, successText: l10n.mailActionDone, successAction: _undoMove(d));
  }

  Future<void> _saveToFolder(MailMessageDetail d) async {
    final l10n = context.l10n;
    final folders = (ref.read(mailSummaryProvider).summary?.folders ?? const <MailFolder>[]).where((f) => f.isBookmarkFolder).toList();
    final chosen = await showAppSheet<MailFolder>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(dense: true, title: Text(l10n.mailSaveToBookmarkFolder, style: Theme.of(ctx).textTheme.titleSmall)),
            if (folders.isEmpty)
              ListTile(enabled: false, leading: const Icon(LucideIcons.folderPlus), title: Text(l10n.mailCreateBookmarkFolderFirst)),
            for (final f in folders)
              ListTile(
                leading: Icon(LucideIcons.bookmark, color: ctx.tokens.folderColors(f.color).foreground),
                title: Text(f.name),
                onTap: () => Navigator.pop(ctx, f),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    await _guard(() async {
      await ref.read(mailApiProvider).addMessageToBookmarkFolder(chosen.id, d.id);
      await ref.read(mailRepositoryProvider).setStarred(d.id, true);
      ref.read(mailSummaryProvider.notifier).refresh();
    }, successText: l10n.mailSavedToFolder(chosen.name));
  }

  /// "Sort sender": put the sender into one of the smart folders, optionally
  /// with the mail already received (web `senders` menu).
  Future<void> _sortSender(MailMessageDetail d) async {
    final l10n = context.l10n;
    final folders = (ref.read(mailSummaryProvider).summary?.folders ?? const <MailFolder>[]).where((f) => f.isSmart).toList();
    var includeExisting = true;
    final chosen = await showAppSheet<MailFolder>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                dense: true,
                title: Text(l10n.mailSortSender, style: Theme.of(ctx).textTheme.titleSmall),
                subtitle: Text(l10n.mailSortSenderHint(d.from)),
              ),
              if (folders.isEmpty)
                ListTile(enabled: false, leading: const Icon(LucideIcons.folderPlus), title: Text(l10n.mailSortSenderNoFolders))
              else
                SwitchListTile(
                  dense: true,
                  value: includeExisting,
                  title: Text(l10n.mailSortSenderIncludeExisting),
                  onChanged: (v) => setSheet(() => includeExisting = v),
                ),
              for (final f in folders)
                ListTile(
                  key: Key('sort_sender_${f.id}'),
                  leading: Icon(LucideIcons.folder, color: ctx.tokens.folderColors(f.color).foreground),
                  title: Text(f.name),
                  onTap: () => Navigator.pop(ctx, f),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    await _guard(() async {
      await ref.read(mailApiProvider).addSenderToSmartFolder(chosen.id, d.from, includeExisting: includeExisting);
      ref.read(mailSummaryProvider.notifier).refresh();
    }, successText: l10n.mailSenderSorted(chosen.name));
  }

  /// "Remind me": later today (18:00, or +3h), tomorrow 09:00, next Monday 09:00.
  Future<void> _remind(MailMessageDetail d, String kind) async {
    final l10n = context.l10n;
    final now = DateTime.now();
    final at = switch (kind) {
      'today' => () {
        final six = DateTime(now.year, now.month, now.day, 18);
        return six.isAfter(now.add(const Duration(minutes: 30))) ? six : now.add(const Duration(hours: 3));
      }(),
      'tomorrow' => DateTime(now.year, now.month, now.day + 1, 9),
      _ => DateTime(now.year, now.month, now.day + ((8 - now.weekday) % 7 == 0 ? 7 : (8 - now.weekday) % 7), 9),
    };
    await _guard(
      () => ref.read(mailApiProvider).createTask(
        title: d.subject.isEmpty ? l10n.mailNoSubject : d.subject,
        description: '${l10n.mailFrom}: ${d.from}',
        sourceType: 'email',
        sourceId: d.id,
        reminderAt: at,
      ),
      successText: l10n.mailReminderCreated,
    );
  }

  Future<void> _addToTasks(MailMessageDetail d) async {
    final l10n = context.l10n;
    final router = GoRouter.of(context);
    await _guard(
      () => ref.read(mailApiProvider).createTask(
        title: d.subject.isEmpty ? l10n.mailNoSubject : d.subject,
        description: '${l10n.mailFrom}: ${d.from}',
        sourceType: 'email',
        sourceId: d.id,
      ),
      successText: l10n.mailAddedToTasks,
      successAction: ref.read(tasksEnabledProvider) ? SnackBarAction(label: l10n.tasksOpen, onPressed: () => router.go(Routes.tasks)) : null,
    );
    ref.invalidate(tasksProvider);
  }

  /// «Переслать в чат»: the chosen attachments are downloaded, then the chat
  /// share picker opens with the summary text and the files.
  Future<void> _forwardToChat(MailMessageDetail d) async {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final router = GoRouter.of(context);
    var chosen = const <MailAttachment>[];
    if (d.attachments.isNotEmpty) {
      final picked = await showDialog<List<MailAttachment>>(
        context: context,
        builder: (_) => MailToChatAttachmentsDialog(attachments: d.attachments),
      );
      if (picked == null || !mounted) return;
      chosen = picked;
    }
    final text = MailToChat.text(
      d,
      subjectLabel: l10n.mailUxChatSubject,
      fromLabel: l10n.mailUxChatFrom,
      dateLabel: l10n.mailUxChatDate,
      noSubject: l10n.mailNoSubject,
      date: FormatUtils.fullDate(d.date, locale),
    );
    final files = <({String path, String name})>[];
    if (chosen.isNotEmpty) {
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _busy = true);
      messenger.showSnackBar(SnackBar(content: Text(l10n.mailUxDownloading)));
      try {
        final downloader = ref.read(attachmentDownloaderProvider);
        for (final a in chosen) {
          final file = await downloader.download(a);
          files.add((path: file.path, name: a.filename));
        }
        messenger.hideCurrentSnackBar();
      } on Object catch (e) {
        DiagnosticLog.warn('mail', 'forward to chat: download failed', error: e);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e is AppException ? ErrorText.describe(l10n, e) : l10n.errUnexpected)));
        return;
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      if (!mounted) return;
    }
    ref.read(chatPendingShareProvider.notifier).set(ChatShareContent(text: text, files: files));
    unawaited(router.push(Routes.chatShare));
  }

  void _compose(ComposeMode mode, MailMessageDetail d) => openCompose(ref, ComposeArgs(mode: mode, original: d));

  /// Desktop «Печать» (Ctrl+P): the browser's print dialog.
  /// Desktop «Назначить встречу» (the web's link from a letter): the
  /// new-event dialog titled after the letter, with its sender and other
  /// recipients invited (not oneself).
  Future<void> _scheduleMeeting(MailMessageDetail d) {
    final self = ref.read(currentUserProvider)?.email.toLowerCase() ?? '';
    final people = <String>{
      for (final a in [d.from, for (final r in d.recipients) r.address])
        if (a.trim().isNotEmpty && a.trim().toLowerCase() != self) a.trim().toLowerCase(),
    };
    final title = d.subject.replaceFirst(RegExp(r'^\s*((re|fwd?|ответ|пересл)\s*:\s*)+', caseSensitive: false), '').trim();
    return openEventEditor(
      context,
      EventEditArgs.create(title: title, participants: [for (final a in people) DraftParticipant.external(a)]),
    );
  }

  Future<void> _print(MailMessageDetail d) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final locale = Localizations.localeOf(context);
    final ok = await printMailMessage(
      d,
      labels: MailPrintLabels(
        from: l10n.mailFrom,
        to: l10n.mailTo,
        cc: l10n.mailCc,
        date: l10n.desktopPrintDate,
        attachments: l10n.desktopPrintAttachments,
        noSubject: l10n.mailNoSubject,
      ),
      date: d.date == null ? '' : FormatUtils.fullDate(d.date!, locale.toString()),
      language: locale.languageCode,
    );
    if (!ok) messenger.showSnackBar(SnackBar(content: Text(l10n.desktopPrintFailed)));
  }

  /// Desktop shortcuts of the web reading pane.
  Map<ShortcutActivator, VoidCallback> _keys(MailMessageDetail? d, bool canSend) {
    if (d == null) return {const SingleActivator(LogicalKeyboardKey.escape): _leave};
    final replies = canSend && d.folder != MailFolderType.drafts;
    return {
      const SingleActivator(LogicalKeyboardKey.escape): _leave,
      if (replies) ...{
        const SingleActivator(LogicalKeyboardKey.keyR): () => _compose(ComposeMode.reply, d),
        const SingleActivator(LogicalKeyboardKey.keyA): () => _compose(ComposeMode.replyAll, d),
        const SingleActivator(LogicalKeyboardKey.keyF): () => _compose(ComposeMode.forward, d),
      },
      const SingleActivator(LogicalKeyboardKey.keyU): () =>
          _guard(() => ref.read(mailRepositoryProvider).setRead(d.id, !d.isRead)),
      const SingleActivator(LogicalKeyboardKey.keyS): () =>
          _guard(() => ref.read(mailRepositoryProvider).setStarred(d.id, !d.isStarred)),
      const SingleActivator(LogicalKeyboardKey.delete): () => _delete(d),
      const CharacterActivator('#'): () => _delete(d),
      commandShortcut(LogicalKeyboardKey.keyP): () => _print(d),
    };
  }

  Future<void> _openLink(String url) async {
    final l10n = context.l10n;
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http' || uri.scheme == 'mailto')) return;
    if (ref.read(desktopLayoutProvider)) return _openLinkDesktop(uri, url);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.mailOpenLinkTitle),
        content: Text(url),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.mailOpen)),
        ],
      ),
    );
    if (ok == true) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Desktop, as the web: a link opens at once, unless its text shows one
  /// site and it opens another — then «Ссылка ведёт на другой сайт».
  Future<void> _openLinkDesktop(Uri uri, String url) async {
    final l10n = context.l10n;
    final d = _detail;
    final html = d == null ? null : MailHtml.htmlOf(bodyHtml: d.bodyHtml, bodyText: d.bodyText) ?? d.bodyHtml;
    final mismatch = html == null || html.isEmpty || uri.scheme == 'mailto' ? null : LinkCheck.mismatchIn(html, url);
    if (mismatch != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const Key('link_mismatch'),
          icon: Icon(LucideIcons.triangleAlert, color: ctx.tokens.danger),
          title: Text(l10n.desktopMailLinkElsewhereTitle),
          content: Text(l10n.desktopMailLinkElsewhereBody(mismatch.shown, mismatch.real)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            FilledButton(
              key: const Key('link_mismatch_open'),
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: ctx.tokens.danger),
              child: Text(l10n.desktopMailLinkOpenAnyway),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final d = _detail;
    final canSend = ref.watch(hasPermissionProvider(Permissions.mailSend));
    final desktop = ref.watch(desktopLayoutProvider);
    final body = Column(
      children: [
        _Toolbar(
          detail: d,
          busy: _busy,
          canSend: canSend,
          embedded: widget.embedded,
          showHtml: _showHtml,
          canTranslate: ref.watch(translationAvailableProvider),
          onTranslate: () => setState(() => _translatedId = d?.id),
          onClose: _leave,
          onReply: (mode) => _compose(mode, d!),
          onStar: () => _guard(() => ref.read(mailRepositoryProvider).setStarred(d!.id, !d.isStarred)),
          onSave: () => _saveToFolder(d!),
          onNotSpam: () => _report(d!, MailReportKind.ham),
          onSpam: () => _report(d!, MailReportKind.spam),
          onPhishing: () => _reportPhishing(d!),
          onRead: (read) => _guard(() => ref.read(mailRepositoryProvider).setRead(d!.id, read)),
          onRemind: (kind) => _remind(d!, kind),
          onDelete: () => _delete(d!),
          onMove: () => _moveTo(d!),
          onMoveToInbox: () => _guard(() async {
            await ref.read(mailRepositoryProvider).moveTo(d.id, MailFolderType.inbox);
            _leave();
          }, successText: context.l10n.mailActionDone, successAction: _undoMove(d!)),
          onTasks: () => _addToTasks(d!),
          onForwardToChat: ref.watch(chatEnabledProvider) ? () => _forwardToChat(d!) : null,
          onSortSender: () => _sortSender(d!),
          onDelivery: () => showDeliverySheet(context, d!.id),
          onToggleHtml: () => setState(() => _showHtml = !_showHtml),
          onCopyAddress: () async {
            final messenger = ScaffoldMessenger.of(context);
            final copied = context.l10n.mailAddressCopied;
            await Clipboard.setData(ClipboardData(text: d!.from));
            messenger.showSnackBar(SnackBar(content: Text(copied)));
          },
          onPrint: isDesktop ? () => _print(d!) : null,
          onScheduleMeeting: ref.watch(calendarEnabledProvider) && ref.watch(calendarCanCreateProvider)
              ? () => _scheduleMeeting(d!)
              : null,
          onOpenInWindow: isDesktop && widget.keyboard
              ? () => ref.read(messageWindowsProvider.notifier).open(d!.id)
              : null,
          listHidden: widget.listHidden,
          onToggleList: widget.onToggleList,
        ),
        Expanded(child: _buildBody(context)),
        // Desktop: the quick reply stays at the bottom of the pane, open.
        if (desktop && d != null && d.folder != MailFolderType.drafts && canSend)
          DecoratedBox(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border, width: t.borderWidth))),
            child: DesktopQuickReply(
              key: ValueKey('desktop_quick_reply_${d.id}'),
              detail: d,
              selfAddress: ref.watch(mailSummaryProvider).summary?.mailboxAddress ?? ref.watch(currentUserProvider)?.email ?? '',
            ),
          ),
      ],
    );
    final page = widget.embedded
        ? Material(color: t.surface, child: body)
        : Scaffold(
            backgroundColor: t.surface,
            appBar: AppBar(
              leading: BackButton(onPressed: _leave),
              title: Text(d == null ? '' : folderDisplayName(context.l10n, d.folder)),
            ),
            body: body,
          );
    return DesktopKeyBindings(enabled: widget.keyboard && !_busy, bindings: _keys(d, canSend), child: page);
  }

  Widget _buildBody(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final d = _detail;
    if (_loading && d == null) return const StateView.loading();
    if (d == null) {
      final err = _error!;
      return ErrorText.isOffline(err)
          ? StateView.offline(message: ErrorText.describe(l10n, err), onRetry: _load)
          : StateView.error(message: ErrorText.describe(l10n, err), onRetry: _load);
    }
    final theme = Theme.of(context);
    final isReply = d.folder == MailFolderType.sent && RegExp(r'^(?:\s*re\s*:\s*)+', caseSensitive: false).hasMatch(d.subject);
    final subject = isReply ? d.subject.replaceFirst(RegExp(r'^(?:\s*re\s*:\s*)+', caseSensitive: false), '').trim() : d.subject;
    final showConversation = d.thread.length > 1 && d.thread.any((i) => i.id == d.id);
    final selfAddress = ref.watch(mailSummaryProvider).summary?.mailboxAddress ?? ref.watch(currentUserProvider)?.email ?? '';

    final opened = _OpenedMessage(
      detail: d,
      selfAddress: selfAddress,
      showHtml: _showHtml,
      translated: _translatedId == d.id,
      onShowOriginal: () => setState(() => _translatedId = null),
      onOpenLink: _openLink,
      onReportPhishing: () => _reportPhishing(d),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.mlg, Space.mlg, Space.mlg, Space.xl),
      children: [
        if (_fromCache) OfflineBanner(text: l10n.offlineBanner, onRetry: _load),
        // Subject row: reply badge, subject, conversation line; folder badge + star.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isReply) ...[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: t.infoSoft,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: t.border, width: t.borderWidth),
                ),
                child: Icon(LucideIcons.reply, size: 16, color: t.info),
              ),
              const SizedBox(width: Space.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    subject.isEmpty ? l10n.mailNoSubject : subject,
                    style: theme.textTheme.titleLarge!.copyWith(fontSize: 20 * t.display.scale, height: 28 / 20, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                  ),
                  if (showConversation)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${l10n.mailConversation} · ${l10n.mailThreadCount(d.thread.length)} · ${l10n.mailConversationHistory}',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            if (d.folder != MailFolderType.inbox) XBadge(folderDisplayName(l10n, d.folder), small: true),
            if (d.isStarred) ...[const SizedBox(width: 6), Icon(LucideIcons.bookmark, size: 14, color: t.warning)],
          ],
        ),
        if (d.folder == MailFolderType.drafts && ref.watch(hasPermissionProvider(Permissions.mailSend)))
          Padding(
            padding: const EdgeInsets.only(top: Space.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => _compose(ComposeMode.draft, d),
                icon: const Icon(LucideIcons.pen),
                label: Text(l10n.mailEditSend),
              ),
            ),
          ),
        const SizedBox(height: Space.mlg),
        if (!showConversation)
          opened
        else
          for (var i = 0; i < d.thread.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: SizedBox(height: 20, child: VerticalDivider(width: 2, thickness: 2, color: t.border)),
              ),
            if (d.thread[i].id == d.id)
              Container(
                padding: const EdgeInsets.all(Space.md),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(t.radiusLg),
                  border: Border.all(color: t.primary.withValues(alpha: 0.3), width: t.borderWidth),
                  boxShadow: t.shadowSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ConversationRole(first: i == 0, last: i == d.thread.length - 1, current: true),
                    opened,
                  ],
                ),
              )
            else
              _ConversationMessage(
                item: d.thread[i],
                first: i == 0,
                last: i == d.thread.length - 1,
                selfAddress: selfAddress,
                onOpen: () => (widget.onOpenMessage ?? (id) => context.push(Routes.mailMessagePath(id)))(d.thread[i].id),
              ),
          ],
        // Phone: the desktop's quick reply (attachments, the receipt, «Открыть
        // в редакторе» with text and files) as a card under the letter.
        if (!ref.watch(desktopLayoutProvider) && d.folder != MailFolderType.drafts && ref.watch(hasPermissionProvider(Permissions.mailSend)))
          Padding(
            padding: const EdgeInsets.only(top: Space.lg),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(context.tokens.radiusLg),
                border: Border.all(color: context.tokens.border, width: context.tokens.borderWidth),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.xs),
                child: DesktopQuickReply(key: ValueKey('quick_reply_${d.id}'), detail: d, selfAddress: selfAddress),
              ),
            ),
          ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.detail,
    required this.busy,
    required this.canSend,
    required this.embedded,
    required this.showHtml,
    required this.canTranslate,
    required this.onTranslate,
    required this.onClose,
    required this.onReply,
    required this.onStar,
    required this.onSave,
    required this.onNotSpam,
    required this.onSpam,
    required this.onPhishing,
    required this.onRead,
    required this.onRemind,
    required this.onDelete,
    required this.onMove,
    required this.onMoveToInbox,
    required this.onTasks,
    this.onForwardToChat,
    required this.onSortSender,
    required this.onDelivery,
    required this.onToggleHtml,
    required this.onCopyAddress,
    this.onPrint,
    this.onScheduleMeeting,
    this.onOpenInWindow,
    this.listHidden = false,
    this.onToggleList,
  });

  final MailMessageDetail? detail;
  final bool busy;
  final bool canSend;
  final bool embedded;
  final bool showHtml;
  final bool canTranslate;
  final VoidCallback onTranslate;
  final VoidCallback onClose;
  final ValueChanged<ComposeMode> onReply;
  final VoidCallback onStar;
  final VoidCallback onSave;
  final VoidCallback onNotSpam;
  final VoidCallback onSpam;
  final VoidCallback onPhishing;
  final ValueChanged<bool> onRead;
  final ValueChanged<String> onRemind;
  final VoidCallback onDelete;
  final VoidCallback onMove;
  final VoidCallback onMoveToInbox;
  final VoidCallback onTasks;

  /// «Переслать в чат»; null when the chat module is off.
  final VoidCallback? onForwardToChat;
  final VoidCallback onSortSender;
  final VoidCallback onDelivery;
  final VoidCallback onToggleHtml;
  final VoidCallback onCopyAddress;

  /// Desktop: «Печать» and «Открыть в отдельном окне» (null elsewhere).
  final VoidCallback? onPrint;
  final VoidCallback? onOpenInWindow;

  /// Desktop «Назначить встречу»: an event with the letter's people.
  final VoidCallback? onScheduleMeeting;

  /// Desktop reading pane: hides / shows the message list (null elsewhere).
  final bool listHidden;
  final VoidCallback? onToggleList;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final d = detail;
    final compact = context.isCompact;
    Widget button(Key key, IconData icon, String label, VoidCallback? onPressed, {Color? color}) => IconButton(
      key: key,
      tooltip: label,
      icon: Icon(icon, size: 18, color: color),
      onPressed: busy || d == null ? null : onPressed,
    );
    final divider = Container(width: 1, height: 16, color: t.border, margin: const EdgeInsets.symmetric(horizontal: 4));

    return Container(
      height: Space.mailBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: t.surfaceSubtle,
        border: Border(bottom: BorderSide(color: t.border, width: t.borderWidth)),
      ),
      child: Row(
        children: [
          if (embedded) button(const Key('pane_close'), LucideIcons.x, l10n.close, onClose),
          if (onToggleList != null)
            IconButton(
              key: const Key('pane_toggle_list'),
              tooltip: listHidden ? l10n.desktopMailShowList : l10n.desktopMailHideList,
              icon: Icon(listHidden ? LucideIcons.eye : LucideIcons.eyeOff, size: 18),
              onPressed: onToggleList,
            ),
          if (d != null && d.folder == MailFolderType.drafts && canSend)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilledButton.icon(
                onPressed: busy ? null : () => onReply(ComposeMode.draft),
                icon: const Icon(LucideIcons.pen, size: 14),
                label: Text(l10n.mailEditSend),
                style: FilledButton.styleFrom(minimumSize: const Size(0, Space.controlSm), padding: const EdgeInsets.symmetric(horizontal: 10)),
              ),
            )
          else if (canSend) ...[
            button(const Key('action_reply'), LucideIcons.reply, l10n.mailReply, () => onReply(ComposeMode.reply)),
            button(const Key('action_reply_all'), LucideIcons.replyAll, l10n.mailReplyAll, () => onReply(ComposeMode.replyAll)),
            if (!compact) button(const Key('action_forward'), LucideIcons.forward, l10n.mailForward, () => onReply(ComposeMode.forward)),
          ],
          divider,
          button(
            const Key('action_star'),
            LucideIcons.bookmark,
            d?.isStarred == true ? l10n.mailUnstar : l10n.mailStar,
            onStar,
            color: d?.isStarred == true ? t.warning : null,
          ),
          if (!compact) button(const Key('action_save'), LucideIcons.bookmarkPlus, l10n.mailSaveToBookmarkFolder, onSave),
          if (d?.folder == MailFolderType.spam)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: OutlinedButton.icon(
                key: const Key('action_not_spam'),
                onPressed: busy ? null : onNotSpam,
                icon: const Icon(LucideIcons.inbox, size: 14),
                label: Text(l10n.mailReportNotSpam),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, Space.controlSm), padding: const EdgeInsets.symmetric(horizontal: 10)),
              ),
            ),
          if (!compact && d != null && d.isRead)
            button(const Key('action_unread'), LucideIcons.mail, l10n.mailMarkUnread, () => onRead(false)),
          if (!compact)
            PopupMenuButton<_Remind>(
              key: const Key('action_remind'),
              tooltip: l10n.mailRemindMe,
              enabled: !busy && d != null,
              icon: const Icon(LucideIcons.clock, size: 18),
              onSelected: (r) => onRemind(r.name),
              itemBuilder: (_) => [
                PopupMenuItem(value: _Remind.today, child: Text(l10n.mailRemindLaterToday)),
                PopupMenuItem(value: _Remind.tomorrow, child: Text(l10n.mailRemindTomorrow)),
                PopupMenuItem(value: _Remind.week, child: Text(l10n.mailRemindNextWeek)),
              ],
            ),
          button(
            const Key('action_delete'),
            LucideIcons.trash2,
            d?.deleteIsPermanent == true ? l10n.mailDeleteForever : l10n.mailMoveToTrash,
            onDelete,
          ),
          const Spacer(),
          PopupMenuButton<String>(
            key: const Key('action_more'),
            tooltip: l10n.mailMoreActions,
            enabled: !busy && d != null,
            icon: const Icon(LucideIcons.ellipsis, size: 18),
            onSelected: (v) {
              switch (v) {
                case 'forward':
                  onReply(ComposeMode.forward);
                case 'save':
                  onSave();
                case 'unread':
                  onRead(false);
                case 'read':
                  onRead(true);
                case 'spam':
                  onSpam();
                case 'ham':
                  onNotSpam();
                case 'phishing':
                  onPhishing();
                case 'delivery':
                  onDelivery();
                case 'move':
                  onMove();
                case 'inbox':
                  onMoveToInbox();
                case 'tasks':
                  onTasks();
                case 'to_chat':
                  onForwardToChat?.call();
                case 'sort':
                  onSortSender();
                case 'remind_today':
                  onRemind('today');
                case 'remind_tomorrow':
                  onRemind('tomorrow');
                case 'remind_week':
                  onRemind('week');
                case 'html':
                  onToggleHtml();
                case 'translate':
                  onTranslate();
                case 'copy':
                  onCopyAddress();
                case 'print':
                  onPrint?.call();
                case 'window':
                  onOpenInWindow?.call();
                case 'meeting':
                  onScheduleMeeting?.call();
              }
            },
            itemBuilder: (_) => [
              if (onOpenInWindow != null)
                PopupMenuItem(
                  key: const Key('menu_open_in_window'),
                  value: 'window',
                  child: _MenuRow(LucideIcons.appWindow, l10n.desktopOpenInWindow),
                ),
              if (onPrint != null)
                PopupMenuItem(
                  key: const Key('menu_print'),
                  value: 'print',
                  child: _MenuRow(LucideIcons.printer, '${l10n.desktopPrint}  ($commandKeyLabel+P)'),
                ),
              if (onScheduleMeeting != null)
                PopupMenuItem(
                  key: const Key('menu_schedule_meeting'),
                  value: 'meeting',
                  child: _MenuRow(LucideIcons.calendarPlus, l10n.desktopContactScheduleMeeting),
                ),
              if (onOpenInWindow != null || onPrint != null || onScheduleMeeting != null) const PopupMenuDivider(),
              if (compact && canSend && d?.folder != MailFolderType.drafts)
                PopupMenuItem(value: 'forward', child: _MenuRow(LucideIcons.forward, l10n.mailForward)),
              if (compact) PopupMenuItem(value: 'save', child: _MenuRow(LucideIcons.bookmarkPlus, l10n.mailSaveToBookmarkFolder)),
              PopupMenuItem(
                value: d?.isRead == true ? 'unread' : 'read',
                child: _MenuRow(d?.isRead == true ? LucideIcons.mail : LucideIcons.mailOpen, d?.isRead == true ? l10n.mailMarkUnread : l10n.mailMarkRead),
              ),
              if (compact) ...[
                PopupMenuItem(value: 'remind_today', child: _MenuRow(LucideIcons.clock, '${l10n.mailRemindMe}: ${l10n.mailRemindLaterToday}')),
                PopupMenuItem(value: 'remind_tomorrow', child: _MenuRow(LucideIcons.clock, '${l10n.mailRemindMe}: ${l10n.mailRemindTomorrow}')),
                PopupMenuItem(value: 'remind_week', child: _MenuRow(LucideIcons.clock, '${l10n.mailRemindMe}: ${l10n.mailRemindNextWeek}')),
              ],
              PopupMenuItem(value: 'tasks', child: _MenuRow(LucideIcons.circleCheck, l10n.mailAddToTasks)),
              if (onForwardToChat != null)
                PopupMenuItem(key: const Key('menu_forward_to_chat'), value: 'to_chat', child: _MenuRow(LucideIcons.messageCircle, l10n.mailUxForwardToChat)),
              if (d != null && d.folder != MailFolderType.sent && d.folder != MailFolderType.drafts)
                PopupMenuItem(value: 'sort', child: _MenuRow(LucideIcons.folderInput, l10n.mailSortSender)),
              if (d?.folder == MailFolderType.spam)
                PopupMenuItem(value: 'ham', child: _MenuRow(LucideIcons.inbox, l10n.mailReportNotSpam))
              else ...[
                PopupMenuItem(value: 'spam', child: _MenuRow(LucideIcons.octagonAlert, l10n.mailReportSpam)),
                PopupMenuItem(key: const Key('menu_phishing'), value: 'phishing', child: _MenuRow(LucideIcons.triangleAlert, l10n.mailReportPhishing)),
              ],
              if (d != null && d.folder != MailFolderType.inbox && d.folder != MailFolderType.sent && d.folder != MailFolderType.drafts)
                PopupMenuItem(value: 'inbox', child: _MenuRow(LucideIcons.inbox, l10n.mailMoveToInbox)),
              PopupMenuItem(value: 'move', child: _MenuRow(LucideIcons.folder, l10n.mailMoveTo)),
              if (d?.folder == MailFolderType.sent)
                PopupMenuItem(key: const Key('menu_delivery'), value: 'delivery', child: _MenuRow(LucideIcons.send, l10n.mailDeliveryStatus)),
              if (canTranslate && d != null && (d.bodyText.trim().isNotEmpty || d.bodyHtml.isNotEmpty))
                PopupMenuItem(key: const Key('menu_translate'), value: 'translate', child: _MenuRow(LucideIcons.languages, l10n.translateMail)),
              if (d != null && d.bodyHtml.isNotEmpty)
                PopupMenuItem(value: 'html', child: _MenuRow(LucideIcons.code, showHtml ? l10n.mailShowText : l10n.mailShowHtml)),
              PopupMenuItem(value: 'copy', child: _MenuRow(LucideIcons.atSign, l10n.mailCopyAddress)),
            ],
          ),
        ],
      ),
    );
  }
}

enum _Remind { today, tomorrow, week }

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: context.tokens.textSecondary),
      const SizedBox(width: 10),
      Expanded(child: Text(label)),
    ],
  );
}

/// The opened message: header block, invitation, lookalike warning, body,
/// attachment chips.
class _OpenedMessage extends ConsumerWidget {
  const _OpenedMessage({
    required this.detail,
    required this.selfAddress,
    required this.showHtml,
    this.translated = false,
    this.onShowOriginal,
    required this.onOpenLink,
    required this.onReportPhishing,
  });

  final MailMessageDetail detail;
  final String selfAddress;
  final bool showHtml;

  /// «Перевести письмо»: the translated plain text replaces the body.
  final bool translated;
  final VoidCallback? onShowOriginal;
  final ValueChanged<String> onOpenLink;
  final VoidCallback onReportPhishing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final d = detail;
    final locale = Localizations.localeOf(context).toString();
    final ownDomain = Lookalike.domainOf(selfAddress);
    final senderDomain = Lookalike.domainOf(d.from);
    final isExternal = ownDomain.isNotEmpty && senderDomain.isNotEmpty && senderDomain != ownDomain;
    final lookalike = Lookalike.isLookalike(senderDomain, ownDomain);
    // The sender's layout as the web shows it (DesktopMailBody): remote
    // pictures and the ones attached to the letter (`cid:`), on desktop and
    // phones alike — letters read as they were sent.
    final desktopHtml = showHtml ? MailHtml.htmlOf(bodyHtml: d.bodyHtml, bodyText: d.bodyText) : null;
    final sanitized = desktopHtml == null && d.bodyHtml.isNotEmpty && showHtml ? HtmlSanitizer.sanitize(d.bodyHtml, remoteImages: true) : null;
    final text = d.bodyText.isNotEmpty ? d.bodyText : (d.bodyHtml.isNotEmpty ? HtmlSanitizer.toPlainText(d.bodyHtml) : '');
    // Dark skins: a message written for a white page keeps its own colours
    // unreadable, so inline ink is lifted to the theme's and backgrounds are
    // dropped (web `themed-html`).
    final CustomStylesBuilder? darkStyles = !t.palette.isDark
        ? null
        : (element) {
            final style = element.attributes['style'] ?? '';
            final hasColor = style.contains('color') || style.contains('background') || element.attributes.containsKey('bgcolor');
            if (!hasColor && element.localName != 'a') return null;
            return {
              'color': element.localName == 'a' ? _hex(t.info) : _hex(t.textPrimary),
              'background-color': 'transparent',
            };
          };
    // Desktop: pictures the text draws are not listed as files.
    final inlineCids = desktopHtml == null ? const <String>{} : MailHtml.referencedCids(desktopHtml);
    final files = [
      for (final a in d.attachments)
        if (a.contentId.isEmpty || !inlineCids.contains(a.contentId.toLowerCase())) a,
    ];
    final meta = theme.textTheme.labelSmall!.copyWith(fontSize: t.display.fontSizeMeta, color: t.textSecondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header block.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(email: d.from, label: d.senderLabel, radius: 20, domainLogo: true),
            const SizedBox(width: Space.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(d.senderLabel, style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600)),
                      if (isExternal) XBadge(l10n.mailExternalSender, tone: lookalike ? BadgeTone.danger : BadgeTone.neutral, small: true),
                      if (d.fromDisplay.isNotEmpty && d.fromDisplay != d.from)
                        Text('<${d.from}>', style: meta, overflow: TextOverflow.ellipsis),
                      if (d.folder != MailFolderType.sent)
                        XBadge(l10n.mailRecipientsCount(d.to.isEmpty ? 1 : d.to.length), small: true),
                    ],
                  ),
                  if (d.folder == MailFolderType.sent) ...[
                    const SizedBox(height: 4),
                    _RecipientsLine(label: l10n.mailTo, addresses: d.to),
                    if (d.cc.isNotEmpty) _RecipientsLine(label: l10n.mailCc, addresses: d.cc),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            Text(FormatUtils.fullDate(d.date, locale), style: meta, textAlign: TextAlign.right),
          ],
        ),
        for (final a in d.attachments.where((a) => a.isCalendarInvitation))
          Padding(
            padding: const EdgeInsets.only(top: Space.mlg),
            child: InvitationCard(key: ValueKey('invitation_${d.id}_${a.id}'), messageId: d.id, blobId: a.id),
          ),
        if (lookalike)
          Container(
            key: const Key('lookalike_warning'),
            margin: const EdgeInsets.only(top: Space.md),
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.smd),
            decoration: BoxDecoration(
              color: t.dangerSoft,
              borderRadius: BorderRadius.circular(t.radiusMd),
              border: Border.all(color: t.danger.withValues(alpha: 0.4), width: t.borderWidth),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.triangleAlert, size: 20, color: t.danger),
                const SizedBox(width: Space.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$senderDomain ≠ $ownDomain', style: theme.textTheme.bodyMedium!.copyWith(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w600)),
                      Text(l10n.mailLookalikeWarning, style: theme.textTheme.bodySmall),
                      const SizedBox(height: Space.sm),
                      FilledButton(
                        onPressed: onReportPhishing,
                        style: FilledButton.styleFrom(backgroundColor: t.danger, minimumSize: const Size(0, Space.controlSm)),
                        child: Text(l10n.mailReportPhishing),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        // Body.
        Container(
          // Desktop: the hairline runs across the pane, as on the web.
          width: isDesktop ? double.infinity : null,
          margin: const EdgeInsets.only(top: Space.mlg),
          padding: const EdgeInsets.only(top: Space.mlg),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border, width: t.borderWidth))),
          child: translated && text.trim().isNotEmpty
              ? MailTranslationView(
                  key: ValueKey('mail_translation_${d.id}'),
                  messageId: d.id,
                  text: text,
                  onShowOriginal: onShowOriginal ?? () {},
                )
              : desktopHtml != null
              ? DesktopMailBody(
                  key: ValueKey('desktop_body_${d.id}'),
                  detail: d,
                  html: desktopHtml,
                  textStyle: theme.textTheme.bodyLarge!.copyWith(height: 1.6),
                  customStylesBuilder: darkStyles,
                  onOpenLink: onOpenLink,
                )
              : sanitized == null
              ? (text.isEmpty
                    ? Text(l10n.mailNoBody, style: theme.textTheme.bodySmall!.copyWith(color: t.textTertiary))
                    : SelectableText(text, style: theme.textTheme.bodyLarge!.copyWith(height: 1.6)))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (sanitized.blockedRemoteContent)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.sm),
                        child: Text(l10n.mailRemoteContentBlocked, style: theme.textTheme.bodySmall),
                      ),
                    HtmlWidget(
                      sanitized.html,
                      textStyle: theme.textTheme.bodyLarge!.copyWith(height: 1.6),
                      customStylesBuilder: darkStyles,
                      onTapUrl: (url) {
                        onOpenLink(url);
                        return true;
                      },
                    ),
                  ],
                ),
        ),
        // Attachments as chips.
        if (files.isNotEmpty)
          Container(
            width: isDesktop ? double.infinity : null,
            margin: const EdgeInsets.only(top: Space.lg),
            padding: const EdgeInsets.only(top: Space.md),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border, width: t.borderWidth))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.mailAttachmentsCount(files.length), style: theme.textTheme.labelMedium),
                const SizedBox(height: 10),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    for (final a in files)
                      // Desktop: drag out to Explorer / Finder, Space for a quick look.
                      DesktopFileGestures(
                        resolve: () async => (await ref.read(attachmentDownloaderProvider).download(a)).path,
                        child: _AttachmentChip(key: ValueKey('attachment_${a.id}'), attachment: a, onTap: () => showAttachmentActions(context, ref, a)),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

class _RecipientsLine extends StatelessWidget {
  const _RecipientsLine({required this.label, required this.addresses});
  final String label;
  final List<String> addresses;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme.labelSmall!.copyWith(fontSize: t.display.fontSizeMeta, color: t.textSecondary, height: 20 / 12);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label: ', style: style.copyWith(color: t.textPrimary, fontWeight: FontWeight.w500)),
          TextSpan(text: addresses.join(', ')),
        ],
      ),
      style: style,
    );
  }
}

/// `chip` of the web attachment list: icon tile, name, size; tap opens the
/// existing attachment actions (open / preview as PDF).
class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({super.key, required this.attachment, required this.onTap});
  final MailAttachment attachment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = attachment;
    final type = a.contentType.toLowerCase();
    final icon = type.startsWith('image/')
        ? LucideIcons.image
        : (type.contains('pdf') || a.isOfficeDocument ? LucideIcons.fileText : LucideIcons.paperclip);
    return Material(
      color: t.appBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusMd), side: BorderSide(color: t.border, width: t.borderWidth)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(t.radiusMd),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.smd, 10, Space.smd, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: t.border, width: t.borderWidth),
                ),
                child: Icon(icon, size: 16, color: t.textSecondary),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(a.filename.isEmpty ? a.id : a.filename, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.textPrimary, fontWeight: FontWeight.w500)),
                    Text(FormatUtils.bytes(a.sizeBytes), style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(LucideIcons.download, size: 16, color: t.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Start / Reply / Latest / This message badges of a conversation card.
class _ConversationRole extends StatelessWidget {
  const _ConversationRole({required this.first, required this.last, this.current = false});
  final bool first;
  final bool last;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Wrap(
        spacing: 6,
        children: [
          if (first) XBadge(l10n.mailRoleStart, small: true),
          if (!first) XBadge(l10n.mailRoleReply, small: true),
          if (last && !first) XBadge(l10n.mailRoleLatest, tone: BadgeTone.info, small: true),
          if (current) XBadge(l10n.mailRoleCurrent, tone: BadgeTone.primary, small: true),
        ],
      ),
    );
  }
}

/// A sibling of the conversation: role badges, sender, date, preview lines,
/// "Open message".
class _ConversationMessage extends StatelessWidget {
  const _ConversationMessage({required this.item, required this.first, required this.last, required this.selfAddress, required this.onOpen});
  final MailThreadItem item;
  final bool first;
  final bool last;
  final String selfAddress;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final you = selfAddress.isNotEmpty && item.from.toLowerCase() == selfAddress.toLowerCase();
    return Material(
      color: t.surfaceSubtle,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusLg), side: BorderSide(color: t.border, width: t.borderWidth)),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(t.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ConversationRole(first: first, last: last),
              Row(
                children: [
                  UserAvatar(email: item.from, label: item.senderLabel, radius: 16, domainLogo: true),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      you ? l10n.mailThreadYou : item.senderLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(FormatUtils.listDate(item.date, locale), style: theme.textTheme.labelSmall),
                ],
              ),
              if ((item.preview ?? '').isNotEmpty) ...[
                const SizedBox(height: Space.sm),
                Text(item.preview!, maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  Icon(LucideIcons.externalLink, size: 14, color: t.info),
                  const SizedBox(width: 6),
                  Text(l10n.mailOpenMessage, style: theme.textTheme.labelMedium!.copyWith(color: t.info)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The reading pane with nothing open (wide layout): the oversized bird and
/// a line of copy, as `MessagePanePlaceholder` on the web.
class MessagePanePlaceholder extends StatelessWidget {
  const MessagePanePlaceholder({super.key, required this.folder, this.desktop = false});
  final String folder;

  /// Desktop: the web's «Выберите письмо» copy.
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return Material(
      color: t.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(size: 96, color: t.border),
            const SizedBox(height: Space.md),
            Text(
              desktop ? l10n.desktopSelectMessageToRead : l10n.mailSelectAccount,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: Space.xs),
            Text(
              desktop ? l10n.desktopSelectMessageToReadHint : l10n.mailSelectAccountHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
