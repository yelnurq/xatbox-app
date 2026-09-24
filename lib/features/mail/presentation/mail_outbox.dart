import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/localization/localization.dart';
import '../../../core/network/network_status.dart';
import '../../../core/platform/desktop.dart';
import '../../../core/platform/desktop_layout.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../../shared/utils/error_text.dart';
import '../../chat/data/desktop_notifications.dart';
import '../data/mail_models.dart';
import '../data/mail_outbox_store.dart';
import 'mail_providers.dart';

final mailOutboxStoreProvider = Provider<MailOutboxStore>(
  (ref) => MailOutboxStore(ref.watch(appDatabaseProvider)),
);

/// «Исходящие»: a letter that could not go out for lack of network (after
/// the undo delay, if any) is kept in the app database and sent when the
/// connection returns — on the network coming back, at start, on returning
/// to the app and, on desktop, every [retryInterval] — with a toast. A letter the server refuses
/// stays with its error until sent again by hand or removed.
class MailOutboxNotifier extends Notifier<List<MailOutboxItem>> {
  static const retryInterval = Duration(minutes: 1);

  bool _flushing = false;

  MailOutboxStore get _store => ref.read(mailOutboxStoreProvider);

  @override
  List<MailOutboxItem> build() {
    ref.listen<bool>(isOnlineProvider, (prev, next) {
      if (next && prev == false) unawaited(flush());
    });
    if (desktopBackgroundWork) {
      // The network may be up while the server is not reachable yet.
      final timer = Timer.periodic(retryInterval, (_) {
        if (state.any((i) => !i.failed)) unawaited(flush());
      });
      ref.onDispose(timer.cancel);
    }
    // Phone: no timer in the background (battery); back in the app, retry.
    final lifecycle = AppLifecycleListener(
      onResume: () {
        if (state.any((i) => !i.failed)) unawaited(flush());
      },
    );
    ref.onDispose(lifecycle.dispose);
    unawaited(_load());
    return const [];
  }

  Future<void> _load() async {
    try {
      final stored = await _store.all();
      if (!ref.mounted) return;
      final ids = stored.map((i) => i.id).toSet();
      state = [...stored, ...state.where((i) => !ids.contains(i.id))];
      if (state.any((i) => !i.failed) && ref.read(isOnlineProvider)) unawaited(flush());
    } on Object catch (e) {
      DiagnosticLog.warn('mail', 'outbox not read', error: e);
    }
  }

  /// Keeps [request] for sending later.
  Future<MailOutboxItem> enqueue(MailSendRequest request, {String? draftId}) async {
    final item = MailOutboxItem(
      id: 'o${DateTime.now().microsecondsSinceEpoch}',
      request: request,
      queuedAt: DateTime.now().toUtc(),
      draftId: draftId,
    );
    state = [...state, item];
    await _store.put(item);
    DiagnosticLog.info('mail', 'letter queued in the outbox');
    return item;
  }

  /// Sends the waiting letters in order; stops at the first network failure.
  /// [includeFailed]: also those the server refused before («Отправить
  /// сейчас»). Returns how many went out.
  Future<int> flush({bool includeFailed = false}) async {
    if (_flushing) return 0;
    _flushing = true;
    var sent = 0;
    try {
      for (final item in List.of(state)) {
        if (item.failed && !includeFailed) continue;
        if (!ref.mounted) return sent;
        _replace(item.copyWith(sending: true, clearError: true));
        try {
          await ref.read(mailRepositoryProvider).send(item.request, draftIdToDelete: item.draftId);
          await _store.remove(item.id);
          if (!ref.mounted) return sent;
          state = state.where((i) => i.id != item.id).toList();
          sent++;
        } on AppException catch (e) {
          if (!ref.mounted) return sent;
          if (ErrorText.isOffline(e)) {
            _replace(item.copyWith(sending: false));
            break;
          }
          DiagnosticLog.warn('mail', 'outbox letter refused', error: e);
          final failed = item.copyWith(sending: false, failed: true, error: e);
          _replace(failed);
          await _store.put(failed);
        }
      }
    } finally {
      _flushing = false;
    }
    if (sent > 0) unawaited(_announce(sent));
    return sent;
  }

  Future<void> discard(String id) async {
    state = state.where((i) => i.id != id).toList();
    await _store.remove(id);
  }

  void _replace(MailOutboxItem item) => state = [
    for (final i in state) i.id == item.id ? item : i,
  ];

  /// «Письма из «Исходящих» отправлены»: in the window, and as a system
  /// toast while it is in the background.
  Future<void> _announce(int count) async {
    final messenger = desktopMessengerKey.currentState;
    if (messenger == null || !messenger.mounted) return;
    final text = AppLocalizations.of(messenger.context).mailOutboxSent(count);
    messenger.showSnackBar(SnackBar(key: const Key('mail_outbox_sent_snackbar'), content: Text(text)));
    if (desktopBackgroundWork && !await desktopWindowFocused()) {
      await showDesktopToast(id: 0x6f757462, title: 'XatBox', body: text);
    }
  }
}

final mailOutboxProvider = NotifierProvider<MailOutboxNotifier, List<MailOutboxItem>>(
  MailOutboxNotifier.new,
);

/// Watched from the app root: the outbox runs while signed in.
final mailOutboxLifecycleProvider = Provider<void>((ref) {
  if (ref.watch(authStateProvider.select((s) => s.status)) != AuthStatus.authenticated) return;
  ref.read(mailOutboxProvider.notifier);
});

/// Sign-out: queued letters belong to the user who wrote them.
Future<void> mailOutboxSignOut(ProviderContainer container) async {
  try {
    await container.read(mailOutboxStoreProvider).clear();
  } on Object catch (e) {
    DiagnosticLog.warn('mail', 'outbox not cleared', error: e);
  }
  container.invalidate(mailOutboxProvider);
}

/// The strip above the desktop mail list while letters wait in «Исходящие»:
/// each with its status, «Отправить сейчас» and removal.
class MailOutboxBanner extends ConsumerWidget {
  const MailOutboxBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(mailOutboxProvider);
    if (items.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final notifier = ref.read(mailOutboxProvider.notifier);
    String status(MailOutboxItem i) {
      if (i.sending) return l10n.mailOutboxSending;
      if (i.failed) {
        final e = i.error;
        return l10n.mailOutboxFailed(e == null ? l10n.errUnexpected : ErrorText.describe(l10n, e));
      }
      return l10n.mailOutboxWaiting;
    }

    return Material(
      key: const Key('mail_outbox_banner'),
      color: t.warningSoft,
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.divider, width: t.borderWidth))),
        padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.xs, Space.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(LucideIcons.clock, size: 16, color: t.warning),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: l10n.mailOutboxTitle(items.length), style: const TextStyle(fontWeight: FontWeight.w600)),
                        TextSpan(text: ' · ${l10n.mailOutboxHint}'),
                      ],
                    ),
                    style: text.bodySmall?.copyWith(color: t.warning),
                  ),
                ),
                TextButton(
                  key: const Key('mail_outbox_send_now'),
                  onPressed: items.any((i) => i.sending) ? null : () => unawaited(notifier.flush(includeFailed: true)),
                  style: TextButton.styleFrom(foregroundColor: t.warning, minimumSize: const Size(0, Space.controlSm)),
                  child: Text(l10n.mailOutboxSendNow),
                ),
              ],
            ),
            for (final i in items)
              Row(
                key: Key('mail_outbox_item_${i.id}'),
                children: [
                  const SizedBox(width: 16 + Space.sm),
                  Expanded(
                    child: Text(
                      '${i.request.subject.isEmpty ? l10n.mailNoSubject : i.request.subject} → ${i.request.to.join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Flexible(
                    child: Text(
                      status(i),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: i.failed ? t.danger : t.textSecondary),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.mailOutboxDiscard,
                    visualDensity: VisualDensity.compact,
                    iconSize: 14,
                    onPressed: i.sending ? null : () => unawaited(notifier.discard(i.id)),
                    icon: const Icon(LucideIcons.x),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
