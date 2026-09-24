import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/localization/localization.dart';
import '../../../core/platform/desktop.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../../shared/utils/error_text.dart';
import '../../../shared/widgets/state_view.dart';
import '../data/mail_models.dart';
import 'mail_providers.dart';
import 'mail_selection.dart';
import 'mail_ux_settings.dart';
import 'message_tile.dart';
import 'message_window.dart';

/// Paginated list for one [MailListQuery], with loading / empty / error /
/// offline states, row selection, the swipe tray and "loaded / total" at the
/// end, as the web list pane.
class MessageListView extends ConsumerWidget {
  const MessageListView({super.key, required this.query, this.activeId, this.onOpen});

  final MailListQuery query;

  /// The message shown in the reading pane (wide screens): drawn selected.
  final String? activeId;

  /// Opens a message; defaults to pushing the detail route.
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(mailListProvider(query));
    final notifier = ref.read(mailListProvider(query).notifier);
    final selection = ref.watch(mailSelectionProvider);
    final selfAddress = ref.watch(mailSummaryProvider).summary?.mailboxAddress ?? ref.watch(currentUserProvider)?.email ?? '';

    if (state.status == MailListStatus.error && state.items.isEmpty) {
      final err = state.error!;
      return ErrorText.isOffline(err)
          ? StateView.offline(message: ErrorText.describe(l10n, err), onRetry: notifier.load)
          : StateView.error(message: ErrorText.describe(l10n, err), onRetry: notifier.load);
    }
    if ((state.status == MailListStatus.loading || state.status == MailListStatus.initial) && state.items.isEmpty) {
      return const StateView.loading();
    }
    if (state.isEmpty) {
      return RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.6,
              child: StateView.empty(
                title: query.hasFilters ? l10n.mailEmptySearch : l10n.mailEmptyFolder,
                icon: query.hasFilters ? LucideIcons.searchX : _emptyIcon(query.folder),
              ),
            ),
          ],
        ),
      );
    }

    final showOffline = state.fromCache || (state.error != null && ErrorText.isOffline(state.error));
    final selectionMode = selection.isNotEmpty || context.isExpanded;
    final ux = ref.watch(mailUxSettingsProvider);
    final archiveFolder = ref.watch(mailArchiveFolderProvider);

    void open(String id) => (onOpen ?? (id) => context.push(Routes.mailMessagePath(id)))(id);

    return Column(
      children: [
        if (showOffline)
          OfflineBanner(text: l10n.offlineBanner, onRetry: notifier.refresh)
        else if (state.error != null)
          OfflineBanner(text: ErrorText.describe(l10n, state.error!), onRetry: notifier.refresh),
        Expanded(
          child: RefreshIndicator(
            onRefresh: notifier.refresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels >= n.metrics.maxScrollExtent - 400) notifier.loadMore();
                return false;
              },
              child: ListView.builder(
                key: const PageStorageKey('mail_list'),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: state.items.length + 1,
                itemBuilder: (context, index) {
                  if (index >= state.items.length) {
                    return _ListFooter(
                      loaded: state.items.length,
                      total: state.total,
                      loading: state.loadingMore,
                      error: state.loadMoreError,
                      onRetry: notifier.loadMore,
                    );
                  }
                  final item = state.items[index];
                  final bulk = MailBulk(ref, context);
                  final tile = MessageTile(
                    key: ValueKey(item.id),
                    item: item,
                    folder: query.folder,
                    selfAddress: selfAddress,
                    active: item.id == activeId,
                    checked: selection.contains(item.id),
                    selectionMode: selectionMode,
                    onCheck: (_) => ref.read(mailSelectionProvider.notifier).toggle(item.id),
                    onLongPress: () => ref.read(mailSelectionProvider.notifier).toggle(item.id),
                    onTap: () {
                      // Desktop, as the web: a click opens the letter even
                      // while rows are ticked; Ctrl / ⌘ + click ticks it.
                      final keys = HardwareKeyboard.instance;
                      final addToSelection = keys.isControlPressed || keys.isMetaPressed;
                      if (isDesktop && !addToSelection) {
                        open(item.id);
                      } else if (selection.isNotEmpty || (isDesktop && addToSelection)) {
                        ref.read(mailSelectionProvider.notifier).toggle(item.id);
                      } else {
                        open(item.id);
                      }
                    },
                    onToggleStar: () => _guard(context, () => ref.read(mailRepositoryProvider).setStarred(item.id, !item.isStarred)),
                    onToggleRead: () => bulk.run(item.isRead ? BulkAction.markUnread : BulkAction.markRead, [item], folder: query.folder),
                    onDelete: () => bulk.run(BulkAction.delete, [item], folder: query.folder),
                    onRestore: query.folder == MailFolderType.spam ? () => bulk.run(BulkAction.notSpam, [item], folder: query.folder) : null,
                    // Swipes are off while several rows are being selected,
                    // and on desktop (as the web; rows are dragged there).
                    swipeEnabled: selection.isEmpty && !isDesktop,
                    swipeLeft: _swipe(context, ux.swipeLeft, item, bulk, archiveFolder),
                    swipeRight: _swipe(context, ux.swipeRight, item, bulk, archiveFolder),
                    onOpenInWindow: isDesktop ? () => ref.read(messageWindowsProvider.notifier).open(item.id) : null,
                    // Desktop: moved rows come back with Undo, as on the web.
                    onMove: isDesktop
                        ? () async {
                            final target = await pickMoveFolder(context, query.folder);
                            if (target == null || !context.mounted) return;
                            await bulk.run(BulkAction.move, [item], folder: query.folder, archiveFolder: target);
                          }
                        : null,
                  );
                  if (!isDesktop) return tile;
                  // Desktop: the row chosen with J / K scrolls into view, and
                  // rows can be dragged onto a folder of the sidebar (the
                  // ticked ones together when this one is ticked).
                  final dragged = selection.contains(item.id)
                      ? state.items.where((i) => selection.contains(i.id)).toList()
                      : [item];
                  return Draggable<MailDrag>(
                    data: MailDrag(dragged, query.folder),
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    feedback: _DragFeedback(items: dragged),
                    child: _KeepVisible(active: item.id == activeId, child: tile),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The configured swipe as a row action, through the same bulk actions
  /// (cache, events, Undo toast) as the selection toolbar.
  SwipeAction? _swipe(BuildContext context, MailSwipeAction action, MailListItem item, MailBulk bulk, String? archiveFolder) {
    final l10n = context.l10n;
    final t = context.tokens;
    final folder = query.folder;
    switch (action) {
      case MailSwipeAction.none:
        return null;
      case MailSwipeAction.trash:
        final permanent = folder == MailFolderType.trash || folder == MailFolderType.drafts;
        return SwipeAction(
          icon: LucideIcons.trash2,
          label: permanent ? l10n.mailDeleteForever : l10n.mailMoveToTrash,
          color: t.danger,
          onTap: () async {
            if (permanent && !await confirmDeleteForever(context)) return;
            await bulk.run(BulkAction.delete, [item], folder: folder);
          },
        );
      case MailSwipeAction.archive:
        if (archiveFolder == null || folder == archiveFolder) return null;
        return SwipeAction(
          icon: LucideIcons.archive,
          label: l10n.mailUxSwipeArchive,
          color: t.info,
          onTap: () => bulk.run(BulkAction.archive, [item], folder: folder, archiveFolder: archiveFolder),
        );
      case MailSwipeAction.read:
        return SwipeAction(
          icon: item.isRead ? LucideIcons.mail : LucideIcons.mailOpen,
          label: item.isRead ? l10n.mailMarkUnread : l10n.mailMarkRead,
          color: t.primary,
          onTap: () => bulk.run(item.isRead ? BulkAction.markUnread : BulkAction.markRead, [item], folder: folder),
        );
      case MailSwipeAction.bookmark:
        return SwipeAction(
          icon: LucideIcons.bookmark,
          label: item.isStarred ? l10n.mailUnstar : l10n.mailStar,
          color: t.warning,
          onTap: () => bulk.run(item.isStarred ? BulkAction.unbookmark : BulkAction.bookmark, [item], folder: folder),
        );
    }
  }

  static IconData _emptyIcon(String folder) => switch (folder) {
    MailFolderType.sent => LucideIcons.send,
    MailFolderType.drafts => LucideIcons.fileText,
    MailFolderType.spam => LucideIcons.octagonAlert,
    MailFolderType.trash => LucideIcons.trash2,
    MailFolderType.bookmarks => LucideIcons.bookmark,
    _ when MailFolderType.isBookmarkFolder(folder) => LucideIcons.bookmark,
    _ when MailFolderType.isSmart(folder) => LucideIcons.folder,
    _ => LucideIcons.inbox,
  };

  static Future<void> _guard(BuildContext context, Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await action();
    } on AppException catch (e) {
      DiagnosticLog.warn('mail', 'message action failed', error: e);
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.describe(l10n, e))));
    }
  }
}

/// Scrolls its row into view when it becomes the open message.
/// What follows the pointer while mail rows are dragged to a folder.
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.items});

  final List<MailListItem> items;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final subject = items.first.subject;
    return Material(
      color: t.surface,
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.mail, size: 16, color: t.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                items.length > 1 ? '${items.length} × ${subject.isEmpty ? context.l10n.mailNoSubject : subject}' : (subject.isEmpty ? context.l10n.mailNoSubject : subject),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: t.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeepVisible extends StatefulWidget {
  const _KeepVisible({required this.active, required this.child});
  final bool active;
  final Widget child;

  @override
  State<_KeepVisible> createState() => _KeepVisibleState();
}

class _KeepVisibleState extends State<_KeepVisible> {
  @override
  void didUpdateWidget(_KeepVisible old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final box = context.findRenderObject();
        if (box == null) return;
        // Below the viewport the first call aligns the bottom, above it the
        // second aligns the top; in view both do nothing.
        Scrollable.maybeOf(context)?.position.ensureVisible(
          box,
          duration: const Duration(milliseconds: 120),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
        Scrollable.maybeOf(context)?.position.ensureVisible(
          box,
          duration: const Duration(milliseconds: 120),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// "loaded / total" under the list; a spinner while the next page loads;
/// the retry row when it failed.
class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.loaded, required this.total, required this.loading, required this.error, required this.onRetry});
  final int loaded;
  final int total;
  final bool loading;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          children: [
            Text(l10n.mailLoadMoreError, style: TextStyle(color: t.danger)),
            TextButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.smd),
      child: Center(
        child: loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(
                total > 0 ? '$loaded / $total' : '',
                style: Theme.of(context).textTheme.labelSmall,
              ),
      ),
    );
  }
}
