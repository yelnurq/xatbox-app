import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/localization/localization.dart';
import '../../../core/platform/desktop_keys.dart';
import '../../../core/platform/desktop_layout.dart';
import '../../../core/platform/launcher_requests.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/ds/folder_chip.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../../shared/widgets/state_view.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../data/mail_models.dart';
import 'folder_drawer.dart';
import 'folder_names.dart';
import 'mail_outbox.dart';
import 'mail_providers.dart';
import 'mail_selection.dart';
import 'message_detail_screen.dart';
import 'message_list_view.dart';
import 'sender_accounts_view.dart';
import 'compose_window.dart';
import '../../../shared/widgets/desktop_frame.dart';

/// The message shown in the reading pane on wide screens (`?m=` on the web).
final mailOpenMessageProvider = NotifierProvider<_OpenMessage, String?>(_OpenMessage.new);

class _OpenMessage extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(selectedFolderProvider);
    return null;
  }

  void open(String? id) => state = id;
}

/// Desktop «Скрыть список» (web eye-off in the reading pane): the list
/// pane is hidden while a letter is open, so the letter has the full width.
final mailListHiddenProvider = NotifierProvider<_ListHidden, bool>(_ListHidden.new);

class _ListHidden extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

/// Root of the "Почта" tab (ТЗ п.24.5) laid out like the web mail workspace:
/// topbar (menu, folder, search, bell, calendar, account), the list toolbar
/// (select-all, folder, count, refresh) or the bulk toolbar when rows are
/// ticked, the paginated list. From `lg` the sidebar is static and the
/// reading pane sits beside the list.
class MailHomeScreen extends ConsumerStatefulWidget {
  const MailHomeScreen({super.key});

  @override
  ConsumerState<MailHomeScreen> createState() => _MailHomeScreenState();
}

class _MailHomeScreenState extends ConsumerState<MailHomeScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _closeSearch() {
    _searchController.clear();
    ref.read(mailFiltersProvider.notifier).setQuery('');
    setState(() => _searching = false);
  }

  /// Desktop J / K and the arrows: the next or previous message of the list
  /// in the reading pane (the first one when none is open). Past the last
  /// loaded row the next page loads.
  void _step(MailListQuery query, int delta) {
    final items = ref.read(mailListProvider(query)).items;
    if (items.isEmpty) return;
    final open = ref.read(mailOpenMessageProvider);
    final i = open == null ? -1 : items.indexWhere((m) => m.id == open);
    final next = i < 0 ? 0 : (i + delta).clamp(0, items.length - 1);
    if (next == i) {
      if (delta > 0) ref.read(mailListProvider(query).notifier).loadMore();
      return;
    }
    ref.read(mailOpenMessageProvider.notifier).open(items[next].id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final user = ref.watch(currentUserProvider);
    final canRead = ref.watch(hasPermissionProvider(Permissions.mailRead));
    final canSend = ref.watch(hasPermissionProvider(Permissions.mailSend));
    final offlineProfile = ref.watch(authStateProvider).offlineProfile;
    final folderType = ref.watch(selectedFolderProvider);
    final filters = ref.watch(mailFiltersProvider);
    final query = ref.watch(currentMailQueryProvider);
    final summary = ref.watch(mailSummaryProvider).summary;
    final folder = summary?.folderByType(folderType);
    final filtersAllowed = MailFolderType.supportsFilters(folderType);
    final threadsMode = ref.watch(mailThreadsModeProvider);
    final expanded = context.isExpanded;
    final desktop = ref.watch(desktopLayoutProvider);
    final width = MediaQuery.sizeOf(context).width;
    final openId = ref.watch(mailOpenMessageProvider);
    final listHidden = desktop && openId != null && ref.watch(mailListHiddenProvider);
    final title = folderDisplayName(l10n, folderType, serverName: folder?.name);
    final filtersOn = filters.unread || filters.starred || filters.attachments;
    // «Показать все» of the unified search: Inbox, search field pre-filled.
    if (ref.watch(mailSearchRequestProvider) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final q = ref.read(mailSearchRequestProvider);
        if (!mounted || q == null) return;
        ref.read(mailSearchRequestProvider.notifier).consume();
        if (!canRead) return;
        ref.read(selectedFolderProvider.notifier).select(MailFolderType.inbox);
        ref.read(mailFiltersProvider.notifier).setQuery(q);
        _searchController.text = q;
        setState(() => _searching = true);
      });
    }

    final Widget? filterMenu = filtersAllowed && canRead
        ? PopupMenuButton<String>(
            tooltip: l10n.filterUnread,
            icon: Icon(LucideIcons.filter, size: desktop ? 18 : null, color: filtersOn ? t.primary : null),
            onSelected: (v) {
              final n = ref.read(mailFiltersProvider.notifier);
              switch (v) {
                case 'unread':
                  n.toggleUnread();
                case 'starred':
                  n.toggleStarred();
                case 'attachments':
                  n.toggleAttachments();
              }
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem(value: 'unread', checked: filters.unread, child: Text(l10n.filterUnread)),
              CheckedPopupMenuItem(value: 'starred', checked: filters.starred, child: Text(l10n.filterStarred)),
              CheckedPopupMenuItem(value: 'attachments', checked: filters.attachments, child: Text(l10n.filterAttachments)),
            ],
          )
        : null;
    final Widget? threadsToggle = MailFolderType.supportsThreads(folderType) && canRead && threadsMode != null
        ? IconButton(
            key: const Key('mail_threads_toggle'),
            tooltip: l10n.mailThreadsMode,
            isSelected: threadsMode,
            icon: Icon(LucideIcons.messagesSquare, size: desktop ? 18 : null),
            selectedIcon: Icon(LucideIcons.messagesSquare, size: desktop ? 18 : null, color: t.primary),
            onPressed: () => ref.read(mailThreadsModeProvider.notifier).set(!threadsMode),
          )
        : null;

    // A smart folder opens on its senders; a sender narrows it to messages.
    final accountsView = folder != null && folder.isSmart && filters.sender == null;
    final list = Column(
      children: [
        if (offlineProfile) OfflineBanner(text: l10n.offlineProfileBanner),
        _MailBar(
          query: query,
          folder: folder,
          title: title,
          accountsView: accountsView,
          // Desktop: the web shell's top bar holds search and the account;
          // the list's own controls sit on its bar.
          trailing: desktop
              ? [
                  ?filterMenu,
                  if (canRead)
                    PopupMenuButton<String>(
                      key: const Key('mail_settings_button'),
                      tooltip: l10n.mailSettingsTitle,
                      icon: const Icon(LucideIcons.ellipsis, size: 18),
                      onSelected: (v) => switch (v) {
                        'threads' => ref.read(mailThreadsModeProvider.notifier).set(!(threadsMode ?? false)),
                        _ => context.push(Routes.settingsMail),
                      },
                      itemBuilder: (_) => [
                        if (threadsToggle != null)
                          CheckedPopupMenuItem(
                            key: const Key('mail_threads_toggle'),
                            value: 'threads',
                            checked: threadsMode ?? false,
                            child: Text(l10n.mailThreadsMode),
                          ),
                        PopupMenuItem(value: 'settings', child: Text(l10n.mailSettingsTitle)),
                      ],
                    ),
                ]
              : const [],
        ),
        // Letters waiting for the network («Исходящие»).
        const MailOutboxBanner(),
        Expanded(
          child: threadsMode == null
              ? const StateView.loading()
              : accountsView
              ? SenderAccountsView(key: ValueKey('accounts_${folder.id}'), folder: folder)
              : MessageListView(
                  query: query,
                  activeId: expanded ? openId : null,
                  onOpen: expanded ? (id) => ref.read(mailOpenMessageProvider.notifier).open(id) : null,
                ),
        ),
      ],
    );

    final page = Scaffold(
      appBar: desktop ? null : AppBar(
        leading: expanded || !canRead
            ? null
            : Builder(
                builder: (ctx) => IconButton(
                  key: const Key('mail_menu'),
                  tooltip: l10n.sectionMail,
                  icon: const Icon(LucideIcons.menu),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
        title: _searching
            ? TextField(
                key: const Key('mail_search_field'),
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.mailSearchHint,
                  prefixIcon: const Icon(LucideIcons.search, size: 16),
                  fillColor: t.surfaceSubtle,
                  constraints: const BoxConstraints(minHeight: Space.controlLg, maxHeight: Space.controlLg),
                ),
                onSubmitted: (v) => ref.read(mailFiltersProvider.notifier).setQuery(v),
              )
            : LayoutBuilder(
                builder: (context, c) => Row(
                  children: [
                    // The "MAIL" tile of the web topbar; dropped when the
                    // actions leave no room for it (large text sizes).
                    if (c.maxWidth >= 140) ...[
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: t.primarySoft,
                          borderRadius: BorderRadius.circular(t.radiusSm),
                          border: Border.all(color: t.border, width: t.borderWidth),
                        ),
                        child: Icon(LucideIcons.mail, size: 16, color: t.primary),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (c.maxWidth >= 140)
                            Text(
                              l10n.sectionMail.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: Theme.of(context).textTheme.labelSmall!.copyWith(letterSpacing: 0.6, fontWeight: FontWeight.w700),
                            ),
                          Text(t.pageTitle(title), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).appBarTheme.titleTextStyle),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        actions: [
          if (_searching)
            IconButton(key: const Key('mail_search_close'), tooltip: l10n.close, icon: const Icon(LucideIcons.x), onPressed: _closeSearch)
          else if (filtersAllowed && canRead)
            IconButton(
              key: const Key('mail_search'),
              tooltip: l10n.search,
              icon: const Icon(LucideIcons.search),
              onPressed: () => setState(() => _searching = true),
            ),
          ?filterMenu,
          ?threadsToggle,
          const NotificationsBellButton(),
          // Desktop: search, profile and settings are on the module rail.
          if (desktop && canRead)
            IconButton(
              key: const Key('mail_settings_button'),
              tooltip: l10n.mailSettingsTitle,
              icon: const Icon(LucideIcons.settings2),
              onPressed: () => context.push(Routes.settingsMail),
            )
          else if (!desktop)
            PopupMenuButton<String>(
              tooltip: l10n.profileTitle,
              icon: user == null
                  ? const Icon(LucideIcons.circleUser)
                  : UserAvatar(email: user.email, label: user.displayName, radius: InitialsAvatar.radiusSm),
              onSelected: (v) {
                switch (v) {
                  case 'profile':
                    context.push(Routes.profile);
                  case 'settings':
                    context.push(Routes.settings);
                  case 'mail_settings':
                    context.push(Routes.settingsMail);
                  case 'search_all':
                    context.push(Routes.search);
                }
              },
              itemBuilder: (_) => [
                if (user != null)
                  PopupMenuItem(
                    enabled: false,
                    child: Text(user.displayName, style: Theme.of(context).textTheme.labelMedium),
                  ),
                PopupMenuItem(key: const Key('mail_menu_search_all'), value: 'search_all', child: Text(l10n.searchEverywhere)),
                PopupMenuItem(value: 'profile', child: Text(l10n.profileTitle)),
                if (canRead) PopupMenuItem(value: 'mail_settings', child: Text(l10n.mailSettingsTitle)),
                PopupMenuItem(value: 'settings', child: Text(l10n.settingsTitle)),
              ],
            ),
        ],
      ),
      drawer: canRead && !expanded ? const Drawer(child: FolderDrawer()) : null,
      body: !canRead
          ? StateView.error(message: l10n.mailNoPermission, icon: LucideIcons.lock)
          : !expanded
              ? list
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Desktop: the folders are the shell's sidebar.
                    if (!desktop)
                      SizedBox(
                        width: Space.sidebarWidth,
                        child: DecoratedBox(
                          decoration: BoxDecoration(border: Border(right: BorderSide(color: t.sidebarBorder, width: t.borderWidth))),
                          child: const FolderDrawer(embedded: true),
                        ),
                      ),
                    if (!listHidden)
                    SizedBox(
                      // The web's `--message-list-width`: clamp(240px, 22vw,
                      // 360px) of the window; desktop measures the whole window.
                      width: desktop
                          ? ((width + DesktopNav.sidebarWidth) * 0.22).clamp(300.0, 400.0)
                          : (width * 0.22).clamp(240.0, 360.0),
                      // Material, not a coloured DecoratedBox: the list tiles'
                      // selection and ink splashes paint on it (FlutterError
                      // «ListTile background color or ink splashes may be invisible»).
                      child: Material(
                        color: t.surface,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(right: BorderSide(color: t.border, width: t.borderWidth)),
                          ),
                          child: list,
                        ),
                      ),
                    ),
                    Expanded(
                      child: openId == null
                          ? MessagePanePlaceholder(folder: folderType, desktop: desktop)
                          : MessageDetailScreen(
                              key: ValueKey(openId),
                              messageId: openId,
                              embedded: true,
                              onClose: () => ref.read(mailOpenMessageProvider.notifier).open(null),
                              onOpenMessage: (id) => ref.read(mailOpenMessageProvider.notifier).open(id),
                              listHidden: listHidden,
                              onToggleList: desktop ? ref.read(mailListHiddenProvider.notifier).toggle : null,
                            ),
                    ),
                  ],
                ),
      floatingActionButton: canSend && canRead && !expanded
          ? FloatingActionButton.extended(
              key: const Key('compose_fab'),
              onPressed: () => openCompose(ref),
              icon: const Icon(LucideIcons.pencil),
              label: Text(l10n.mailCompose),
            )
          : null,
    );
    if (!desktop) return page;
    // The web's list shortcuts; the open message's own (R, Delete…) are in
    // MessageDetailScreen.
    void openFirst() {
      if (ref.read(mailOpenMessageProvider) == null) _step(query, 1);
    }

    return DesktopKeyBindings(
      enabled: expanded && canRead && !accountsView,
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyJ): () => _step(query, 1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _step(query, 1),
        const SingleActivator(LogicalKeyboardKey.keyK): () => _step(query, -1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _step(query, -1),
        const SingleActivator(LogicalKeyboardKey.enter): openFirst,
        const SingleActivator(LogicalKeyboardKey.keyO): openFirst,
      },
      child: page,
    );
  }
}

/// The list toolbar of the web folder page (`--mail-bar-height` 48px on the
/// subtle surface): select-all, folder colour, title, total count, refresh.
/// With rows ticked it becomes the bulk toolbar: "N selected" + actions.
class _MailBar extends ConsumerWidget {
  const _MailBar({required this.query, required this.folder, required this.title, this.accountsView = false, this.trailing = const []});

  /// Desktop: filters, conversations, mail settings (the phone keeps them
  /// in the app bar).
  final List<Widget> trailing;
  final MailListQuery query;
  final MailFolder? folder;
  final String title;

  /// The smart folder shows its senders: no selection, no count.
  final bool accountsView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final selection = ref.watch(mailSelectionProvider);
    final state = ref.watch(mailListProvider(query));
    final items = state.items;
    final allChecked = items.isNotEmpty && items.every((i) => selection.contains(i.id));
    final someChecked = selection.isNotEmpty;
    final folderType = query.folder;
    final noSpam = folderType == MailFolderType.spam || folderType == MailFolderType.trash || folderType == MailFolderType.drafts;

    Widget iconButton(Key key, IconData icon, String label, BulkAction action) => IconButton(
      key: key,
      tooltip: label,
      icon: Icon(icon, size: 18),
      onPressed: () {
        final chosen = items.where((i) => selection.contains(i.id)).toList();
        MailBulk(ref, context).run(action, chosen, folder: folderType);
      },
    );

    return Container(
      height: Space.mailBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: Space.sm),
      decoration: BoxDecoration(
        color: someChecked ? t.primarySoft : t.surfaceSubtle,
        border: Border(bottom: BorderSide(color: t.border, width: t.borderWidth)),
      ),
      child: Row(
        children: [
          if (query.sender != null)
            IconButton(
              key: const Key('mail_back_to_senders'),
              tooltip: l10n.mailBackToAccounts,
              icon: const Icon(LucideIcons.arrowLeft, size: 18),
              onPressed: () => ref.read(mailFiltersProvider.notifier).setSender(null),
            ),
          if (!accountsView)
          SizedBox(
            width: 32,
            child: Checkbox(
              key: const Key('mail_select_all'),
              value: allChecked ? true : (someChecked ? null : false),
              tristate: true,
              onChanged: items.isEmpty
                  ? null
                  : (_) => allChecked
                        ? ref.read(mailSelectionProvider.notifier).clear()
                        : ref.read(mailSelectionProvider.notifier).set(items.map((i) => i.id)),
              semanticLabel: l10n.mailSelectAll,
            ),
          ),
          if (someChecked) ...[
            Expanded(
              child: Text(
                l10n.mailSelectedCount(selection.length),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            iconButton(const Key('bulk_read'), LucideIcons.mailOpen, l10n.mailMarkReadSelected, BulkAction.markRead),
            iconButton(const Key('bulk_unread'), LucideIcons.mail, l10n.mailMarkUnreadSelected, BulkAction.markUnread),
            iconButton(const Key('bulk_bookmark'), LucideIcons.bookmark, l10n.mailBookmarkSelected, BulkAction.bookmark),
            if (!noSpam) iconButton(const Key('bulk_spam'), LucideIcons.octagonAlert, l10n.mailSpamSelected, BulkAction.spam),
            if (folderType == MailFolderType.spam)
              iconButton(const Key('bulk_not_spam'), LucideIcons.inbox, l10n.mailNotSpamSelected, BulkAction.notSpam),
            iconButton(
              const Key('bulk_delete'),
              LucideIcons.trash2,
              folderType == MailFolderType.trash ? l10n.mailDeleteForever : l10n.mailDeleteSelected,
              BulkAction.delete,
            ),
            IconButton(
              key: const Key('bulk_clear'),
              tooltip: l10n.close,
              icon: const Icon(LucideIcons.x, size: 18),
              onPressed: () => ref.read(mailSelectionProvider.notifier).clear(),
            ),
          ] else ...[
            if (folder != null && folder!.isSmart) ...[
              FolderIconTile(color: folder!.color, size: 22),
              const SizedBox(width: Space.sm),
            ],
            Flexible(
              child: Text(
                query.sender != null ? query.sender! : t.pageTitle(title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (state.total > 0 && !accountsView) ...[
              const SizedBox(width: Space.sm),
              if (trailing.isEmpty)
                Text(
                  '· ${l10n.mailMessagesTotal(state.total)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                )
              else
                // Desktop: the bar also holds the list controls.
                Flexible(
                  child: Text(
                    '· ${l10n.mailMessagesTotal(state.total)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
            if (folder?.accounts != null && folder!.accounts! > 0 && query.sender == null) ...[
              const SizedBox(width: Space.sm),
              Text('· ${l10n.mailSendersTotal(folder!.accounts!)}', style: Theme.of(context).textTheme.labelSmall),
            ],
            const Spacer(),
            if (trailing.isNotEmpty)
              IconButtonTheme(
                data: IconButtonThemeData(
                  style: IconButton.styleFrom(visualDensity: VisualDensity.compact, minimumSize: const Size(32, 32)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: trailing),
              ),
            IconButton(
              key: const Key('mail_list_refresh'),
              tooltip: l10n.mailRefresh,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              onPressed: () {
                ref.read(mailListProvider(query).notifier).refresh();
                ref.read(mailSummaryProvider.notifier).refresh();
              },
            ),
          ],
        ],
      ),
    );
  }
}
