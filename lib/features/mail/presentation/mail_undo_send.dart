import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../data/mail_models.dart';
import 'mail_outbox.dart';
import 'mail_providers.dart';

/// An attachment of a composer snapshot: already staged on the server
/// (`att_…`), or a stored blob that still has to be staged.
class ComposeAttachmentSnapshot {
  const ComposeAttachmentSnapshot({
    required this.name,
    required this.size,
    this.staged,
    this.blob,
  });
  final String name;
  final int size;
  final MailComposeAttachment? staged;
  final MailAttachment? blob;
}

/// Everything the composer showed when «Отправить» was tapped, so «Отменить»
/// can reopen it exactly (recipients, subject, markup body, attachments,
/// reply target, draft id, title mode).
class ComposeSnapshot {
  const ComposeSnapshot({
    required this.modeName,
    this.to = '',
    this.cc = '',
    this.bcc = '',
    this.subject = '',
    this.body = '',
    this.inReplyTo,
    this.draftId,
    this.attachments = const [],
  });

  /// `ComposeMode.name` of the original composer (title).
  final String modeName;
  final String to;
  final String cc;
  final String bcc;
  final String subject;
  final String body;
  final String? inReplyTo;
  final String? draftId;
  final List<ComposeAttachmentSnapshot> attachments;

  ComposeSnapshot withDraftId(String? id) => ComposeSnapshot(
    modeName: modeName,
    to: to,
    cc: cc,
    bcc: bcc,
    subject: subject,
    body: body,
    inReplyTo: inReplyTo,
    draftId: id,
    attachments: attachments,
  );
}

/// A message waiting out the undo delay.
class PendingMailSend {
  const PendingMailSend({
    required this.id,
    required this.request,
    required this.snapshot,
    required this.deadline,
  });
  final int id;
  final MailSendRequest request;
  final ComposeSnapshot snapshot;
  final DateTime deadline;

  /// The server copy saved before the delay (deleted after a successful send).
  String? get draftId => snapshot.draftId;
}

/// Pending sends live here, not in the composer, so closing the composer
/// does not cancel them. When the delay ends the full form goes to
/// `POST /mail/send` (the draft-send endpoint drops HTML, attachments and
/// threading) and the draft copy saved beforehand is deleted; if the app is
/// killed meanwhile, that draft stays in «Черновики». «Отменить» deletes
/// nothing: the composer reopens on the same draft.
class MailUndoSendNotifier extends Notifier<List<PendingMailSend>> {
  final _timers = <int, Timer>{};
  final _callbacks =
      <
        int,
        ({
          void Function() onSent,
          void Function(AppException) onFailed,
          void Function()? onQueued,
        })
      >{};
  int _seq = 0;

  @override
  List<PendingMailSend> build() {
    ref.onDispose(() {
      for (final t in _timers.values) {
        t.cancel();
      }
      _timers.clear();
      _callbacks.clear();
    });
    return const [];
  }

  /// Queues [request]; it is sent after [delay] unless [cancel]led.
  PendingMailSend schedule({
    required MailSendRequest request,
    required ComposeSnapshot snapshot,
    required Duration delay,
    required void Function() onSent,
    required void Function(AppException error) onFailed,
    void Function()? onQueued,
  }) {
    final pending = PendingMailSend(
      id: ++_seq,
      request: request,
      snapshot: snapshot,
      deadline: DateTime.now().add(delay),
    );
    state = [...state, pending];
    _callbacks[pending.id] = (onSent: onSent, onFailed: onFailed, onQueued: onQueued);
    _timers[pending.id] = Timer(delay, () => unawaited(_commit(pending.id)));
    DiagnosticLog.info('mail', 'send scheduled (${delay.inSeconds}s undo)');
    return pending;
  }

  /// Stops a pending send; returns its snapshot, or null when it already
  /// went out (or never existed).
  ComposeSnapshot? cancel(int id) {
    final pending = state.where((p) => p.id == id).firstOrNull;
    if (pending == null) return null;
    _timers.remove(id)?.cancel();
    _callbacks.remove(id);
    state = state.where((p) => p.id != id).toList();
    DiagnosticLog.info('mail', 'send undone');
    return pending.snapshot;
  }

  Future<void> _commit(int id) async {
    final pending = state.where((p) => p.id == id).firstOrNull;
    _timers.remove(id);
    final callbacks = _callbacks.remove(id);
    if (pending == null) return;
    final repo = ref.read(mailRepositoryProvider);
    state = state.where((p) => p.id != id).toList();
    try {
      await repo.send(pending.request, draftIdToDelete: pending.draftId);
      callbacks?.onSent();
    } on AppException catch (e) {
      // Without network: the letter waits in «Исходящие» instead.
      if (e is NetworkException) {
        DiagnosticLog.warn('mail', 'delayed send offline, queued', error: e);
        await ref.read(mailOutboxProvider.notifier).enqueue(pending.request, draftId: pending.draftId);
        callbacks?.onQueued?.call();
        return;
      }
      DiagnosticLog.warn('mail', 'delayed send failed', error: e);
      callbacks?.onFailed(e);
    }
  }
}

final mailUndoSendProvider =
    NotifierProvider<MailUndoSendNotifier, List<PendingMailSend>>(
      MailUndoSendNotifier.new,
    );
