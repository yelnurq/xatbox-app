import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../../shared/utils/error_text.dart';
import '../data/mail_models.dart';
import '../data/mail_repository.dart';
import 'folder_names.dart';
import 'mail_providers.dart';

/// Ids of the rows ticked in the message list (the web's `selected` set).
/// Cleared whenever the folder or the filters change.
class MailSelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(currentMailQueryProvider);
    return const {};
  }

  void toggle(String id) => state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};
  void set(Iterable<String> ids) => state = {...ids};
  void clear() => state = const {};
}

final mailSelectionProvider = NotifierProvider<MailSelectionNotifier, Set<String>>(MailSelectionNotifier.new);

/// The messages a row acts on: the whole conversation in thread mode, itself
/// otherwise (`messageIds` in lib/conversation.ts).
List<String> rowMessageIds(MailListItem item) =>
    item.threadMessageIds?.isNotEmpty == true ? item.threadMessageIds! : [item.id];

enum BulkAction { markRead, markUnread, bookmark, unbookmark, spam, notSpam, delete, archive, move }

/// Runs one action over many messages the way the web bulk toolbar does:
/// conversation-aware (except bookmark), one toast with **Undo** where the
/// action can be reversed, errors surfaced once.
class MailBulk {
  MailBulk(this.ref, this.context);
  final WidgetRef ref;
  final BuildContext context;

  MailRepository get _repo => ref.read(mailRepositoryProvider);

  /// [archiveFolder]: target of [BulkAction.archive] and [BulkAction.move]
  /// (ignored otherwise).
  Future<void> run(BulkAction action, List<MailListItem> items, {required String folder, String? archiveFolder}) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ids = action == BulkAction.bookmark || action == BulkAction.unbookmark
        ? items.map((i) => i.id).toList()
        : items.expand(rowMessageIds).toSet().toList();
    if (ids.isEmpty) return;
    final permanent = folder == MailFolderType.trash || folder == MailFolderType.drafts;

    Future<void> each(Future<void> Function(String id) f) async {
      Object? failure;
      for (final id in ids) {
        try {
          await f(id);
        } on AppException catch (e) {
          failure = e;
          DiagnosticLog.warn('mail', 'bulk ${action.name} failed', error: e);
        }
      }
      if (failure != null) {
        messenger.showSnackBar(SnackBar(content: Text(ErrorText.describe(l10n, failure as AppException))));
      }
    }

    // As the web: Undo says «Возвращено» (the list shows the rows again by
    // itself, see MailListNotifier).
    void toast(String text, {Future<void> Function()? undo}) {
      final revert = undo == null
          ? undo
          : () async {
              await undo();
              showMailRestored(messenger, l10n);
            };
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(text),
            duration: Duration(seconds: undo == null ? 3 : 6),
            action: revert == null ? null : SnackBarAction(label: l10n.mailUndo, onPressed: () => revert()),
          ),
        );
    }

    switch (action) {
      case BulkAction.markRead:
        await each((id) => _repo.setRead(id, true));
        toast(l10n.mailMarkedReadCount(ids.length), undo: () => each((id) => _repo.setRead(id, false)));
      case BulkAction.markUnread:
        await each((id) => _repo.setRead(id, false));
        toast(l10n.mailMarkedUnreadCount(ids.length), undo: () => each((id) => _repo.setRead(id, true)));
      case BulkAction.bookmark:
        await each((id) => _repo.setStarred(id, true));
        toast(l10n.mailBookmarkedCount(ids.length), undo: () => each((id) => _repo.setStarred(id, false)));
      case BulkAction.unbookmark:
        await each((id) => _repo.setStarred(id, false));
        toast(l10n.mailUxUnbookmarkedCount(ids.length), undo: () => each((id) => _repo.setStarred(id, true)));
      case BulkAction.archive:
        final target = archiveFolder;
        if (target == null) return;
        await each((id) => _repo.moveTo(id, target));
        toast(l10n.mailUxArchivedCount(ids.length), undo: () => each((id) => _repo.moveTo(id, folder)));
      case BulkAction.move:
        final target = archiveFolder;
        if (target == null) return;
        await each((id) => _repo.moveTo(id, target));
        toast(l10n.desktopMailMovedTo(folderDisplayName(l10n, target)), undo: () => each((id) => _repo.moveTo(id, folder)));
      case BulkAction.spam:
        await each((id) => _repo.report(id, MailReportKind.spam));
        toast(l10n.mailMovedToSpamCount(ids.length), undo: () => each((id) => _repo.report(id, MailReportKind.ham)));
      case BulkAction.notSpam:
        await each((id) => _repo.report(id, MailReportKind.ham));
        toast(l10n.mailRestoredCount(ids.length), undo: () => each((id) => _repo.report(id, MailReportKind.spam)));
      case BulkAction.delete:
        await each((id) => _repo.delete(id, permanent: permanent));
        // Trashed mail comes back to the folder it left; destroyed mail cannot.
        toast(
          l10n.mailDeletedCount(ids.length),
          undo: permanent ? null : () => each((id) => _repo.moveTo(id, folder)),
        );
    }
    ref.read(mailSelectionProvider.notifier).clear();
  }
}

/// Desktop: the toast after Undo put mail back (web «Возвращено»).
void showMailRestored(ScaffoldMessengerState messenger, AppLocalizations l10n) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l10n.desktopMailRestored), duration: const Duration(seconds: 3)));
}

/// «Переместить в…»: one of the system folders other than [current].
Future<String?> pickMoveFolder(BuildContext context, String current) {
  final l10n = context.l10n;
  return showAppSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final f in MailFolderType.system)
            if (f != current)
              ListTile(
                key: Key('move_to_$f'),
                leading: Icon(folderIcon(f)),
                title: Text(folderDisplayName(l10n, f)),
                onTap: () => Navigator.pop(ctx, f),
              ),
        ],
      ),
    ),
  );
}

/// Desktop: mail rows dragged from the list onto a folder of the sidebar.
class MailDrag {
  const MailDrag(this.items, this.folder);

  /// The dragged row, or every ticked row when the dragged one is ticked.
  final List<MailListItem> items;

  /// The folder they are dragged out of (Undo moves them back there).
  final String folder;
}

/// Whether [drag] can be dropped on the sidebar folder [target] (the same
/// folders as «Переместить в…»).
bool canDropMail(MailDrag drag, String target) => MailFolderType.isSystem(target) && target != drag.folder;

/// «Удалить навсегда?» before destroying mail (Trash / Drafts).
Future<bool> confirmDeleteForever(BuildContext context) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.mailDeleteForever),
      content: Text(l10n.mailDeleteForeverConfirm),
      actions: [
        TextButton(key: const Key('delete_forever_cancel'), onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
        TextButton(key: const Key('delete_forever_confirm'), onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.delete)),
      ],
    ),
  );
  return ok == true;
}
