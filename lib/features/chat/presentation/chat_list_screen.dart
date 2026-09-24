import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/platform/desktop.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/platform/desktop_keys.dart';
import '../../../core/platform/desktop_layout.dart';
import '../../../core/platform/launcher_requests.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/websocket/realtime_client.dart';
import '../../../shared/widgets/ds/x_badge.dart';
import '../../../shared/widgets/state_view.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../data/chat_models.dart';
import 'channels/channel_discover_screen.dart';
import 'chat_avatar.dart';
import 'chat_formatters.dart';
import 'chat_providers.dart';
import 'conversation_screen.dart';
import 'new_chat_screen.dart';
import '../../settings/my_status_sheet.dart';
import '../data/chat_folders.dart';
import 'folders/chat_folders_providers.dart';
import 'folders/chat_folders_screen.dart';
import 'reminders/reminders_screen.dart';
import '../../../shared/widgets/app_sheet.dart';

enum ChatListFilter { all, unread, groups, channels }

/// Root of the "Чат" tab (ТЗ п.24.6): realtime list with unread / mute /
/// pin, filters, drafts and typing in the tiles, swipe actions, search over
/// chats and messages (a hit opens the chat at the message), the archive
/// from the server. From `lg` the list and the open chat sit side by side.
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  static const paneWidth = 380.0;

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _search = TextEditingController();
  final _openSwipe = ValueNotifier<String?>(null);
  Timer? _debounce;
  String _query = '';
  List<ChatMessage> _messageHits = const [];
  bool _searching = false;
  bool _showArchived = false;
  /// Built-in filter name or `folder:<id>` (ChatListTabs).
  String _tab = ChatListTabs.all;

  // memoised filtering
  List<ChatConversation>? _memoSource;
  List<ChatFolder>? _memoFolders;
  String _memoKey = '';
  List<ChatConversation> _memo = const [];

  @override
  void dispose() {
    _search.dispose();
    _openSwipe.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _query = q.trim());
      if (_query.length < 2) {
        setState(() => _messageHits = const []);
        return;
      }
      try {
        final hits = await ref.read(chatRepositoryProvider).search(_query);
        if (mounted) setState(() => _messageHits = hits);
      } on AppException {
        // search is best effort
      }
    });
  }

  List<ChatConversation> _visible(
    List<ChatConversation> all,
    List<ChatFolder> folders,
  ) {
    final tab = ChatListTabs.effective(_tab, folders);
    final key = '$tab|$_query|$_showArchived';
    if (identical(all, _memoSource) &&
        identical(folders, _memoFolders) &&
        key == _memoKey) {
      return _memo;
    }
    final q = _query.toLowerCase();
    final savedTitle = context.l10n.chatSaved.toLowerCase();
    final now = DateTime.now();
    _memoSource = all;
    _memoFolders = folders;
    _memoKey = key;
    _memo = all
        .where((c) {
          if (c.settings.archived != _showArchived) return false;
          if (q.isNotEmpty) {
            return (c.isSaved ? savedTitle : c.title.toLowerCase()).contains(
                  q,
                ) ||
                (c.peer?.email.toLowerCase().contains(q) ?? false);
          }
          return ChatListTabs.matches(tab, c, folders, now);
        })
        .toList(growable: false);
    return _memo;
  }

  void _open(String conversationId, {bool wide = false}) {
    _openSwipe.value = null;
    if (wide) {
      ref
          .read(chatSelectedConversationProvider.notifier)
          .select(conversationId);
    } else {
      context.push(Routes.chatConversationPath(conversationId));
    }
  }

  /// Desktop Alt+↑ / Alt+↓: the previous / next chat of the list as shown
  /// (filter and search applied) into the pane.
  void _step(int delta) {
    final items = _memo;
    if (items.isEmpty) return;
    final i = items.indexWhere((c) => c.id == ref.read(chatSelectedConversationProvider));
    final next = i < 0 ? (delta > 0 ? 0 : items.length - 1) : (i + delta).clamp(0, items.length - 1);
    if (next == i) return;
    _open(items[next].id, wide: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!ref.watch(chatEnabledProvider)) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.chatTitle)),
        body: StateView.empty(
          title: l10n.chatDisabled,
          icon: LucideIcons.messageCircle,
        ),
      );
    }
    final wide = context.isExpanded;
    final list = _listScaffold(context, wide);
    if (!wide) return list;
    final t = context.tokens;
    final selected = ref.watch(chatSelectedConversationProvider);
    final panes = Row(
      children: [
        SizedBox(
          // Desktop: a WhatsApp-style chat list, ~35% of the workspace
          // (360–480px). Tablets keep the fixed pane, capped at 40%.
          width: ref.watch(desktopLayoutProvider)
              ? (MediaQuery.sizeOf(context).width * 0.35).clamp(360.0, 480.0)
              : math.min(ChatListScreen.paneWidth, MediaQuery.sizeOf(context).width * 0.4),
          child: list,
        ),
        VerticalDivider(width: t.borderWidth, color: t.divider),
        Expanded(
          child: selected == null
              ? Scaffold(
                  body: StateView.empty(
                    title: l10n.chatSelectConversation,
                    icon: LucideIcons.messagesSquare,
                  ),
                )
              : ConversationScreen(
                  key: ValueKey('pane_$selected'),
                  conversationId: selected,
                  embedded: true,
                ),
        ),
      ],
    );
    if (!ref.watch(desktopLayoutProvider)) return panes;
    return DesktopKeyBindings(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): () => _step(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true): () => _step(1),
      },
      child: panes,
    );
  }

  Widget _listScaffold(BuildContext context, bool wide) {
    final l10n = context.l10n;
    final desktop = ref.watch(desktopLayoutProvider);
    final t = context.tokens;
    final state = ref.watch(conversationsProvider);
    final conn =
        ref.watch(chatConnectionProvider).value ??
        ref.read(chatRepositoryProvider).connectionStatus;
    final syncing = ref.watch(chatSyncingProvider).value ?? false;
    final subtitle = switch (conn) {
      RealtimeStatus.connected => syncing ? l10n.chatSyncing : null,
      RealtimeStatus.connecting ||
      RealtimeStatus.authenticating => l10n.chatConnecting,
      RealtimeStatus.disconnected => l10n.chatOffline,
    };
    final archiveLoad = _showArchived
        ? ref.watch(chatArchivedLoadProvider)
        : null;
    final folders = ref.watch(chatFoldersProvider.select((s) => s.folders));
    final items = _visible(state.items, folders);
    // `/chat/search` or «Показать все» of the unified search: open the
    // search field once, pre-filled.
    final searchRequest = ref.watch(chatSearchRequestProvider);
    if (searchRequest != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ref.read(chatSearchRequestProvider) == null) return;
        ref.read(chatSearchRequestProvider.notifier).consume();
        setState(() {
          _showArchived = false;
          _searching = true;
        });
        if (searchRequest.isNotEmpty) {
          _search.text = searchRequest;
          _onQuery(searchRequest);
        }
      });
    }

    return Scaffold(
      // Desktop: the list pane is one colour down to the bottom (the rows'
      // surface), not rows floating on the page background.
      backgroundColor: desktop ? t.surface : null,
      appBar: AppBar(
        leading: _showArchived && !_searching
            ? IconButton(
                key: const Key('chat_archive_back'),
                tooltip: l10n.close,
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: () => setState(() => _showArchived = false),
              )
            : null,
        title: _searching
            ? TextField(
                key: const Key('chat_list_search'),
                controller: _search,
                autofocus: true,
                onChanged: _onQuery,
                decoration: InputDecoration(
                  hintText: l10n.chatSearch,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.pageTitle(
                      _showArchived ? l10n.chatArchived : l10n.chatTitle,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: t.textTertiary),
                    ),
                ],
              ),
        actions: [
          if (_searching)
            IconButton(
              tooltip: l10n.close,
              icon: const Icon(LucideIcons.x),
              onPressed: () {
                _search.clear();
                setState(() {
                  _searching = false;
                  _query = '';
                  _messageHits = const [];
                });
              },
            )
          else ...[
            const NotificationsBellButton(),
            // Desktop: «Новый чат» sits in the header, no floating button.
            if (desktop && !_showArchived)
              IconButton(
                key: const Key('chat_new_button'),
                tooltip: l10n.chatNew,
                icon: const Icon(LucideIcons.squarePen),
                onPressed: () => openNewChat(context),
              ),
            IconButton(
              key: const Key('chat_search'),
              tooltip: l10n.chatSearch,
              icon: const Icon(LucideIcons.search),
              onPressed: () => setState(() => _searching = true),
            ),
            PopupMenuButton<String>(
              key: const Key('chat_list_menu'),
              tooltip: l10n.mailMoreActions,
              icon: const Icon(LucideIcons.ellipsisVertical),
              onSelected: (v) {
                if (v == 'channels') {
                  unawaited(openChannelDiscover(context));
                } else if (v == 'folders') {
                  unawaited(openChatFolders(context));
                } else if (v == 'status') {
                  unawaited(showMyStatusSheet(context));
                } else if (v == 'reminders') {
                  unawaited(openRemindersScreen(context));
                } else if (v == 'search_all') {
                  unawaited(context.push(Routes.search));
                } else {
                  setState(() => _showArchived = v == 'archived');
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'all',
                  child: ListTile(
                    leading: const Icon(LucideIcons.messagesSquare),
                    title: Text(l10n.chatTitle),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'archived',
                  child: ListTile(
                    leading: const Icon(LucideIcons.archive),
                    title: Text(l10n.chatArchived),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (!desktop)
                  PopupMenuItem(
                    key: const Key('chat_menu_search_all'),
                    value: 'search_all',
                    child: ListTile(
                      leading: const Icon(LucideIcons.textSearch),
                      title: Text(l10n.searchEverywhere),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                PopupMenuItem(
                  key: const Key('chat_menu_channels'),
                  value: 'channels',
                  child: ListTile(
                    leading: const Icon(LucideIcons.megaphone),
                    title: Text(l10n.channelsDiscoverTitle),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  key: const Key('chat_menu_reminders'),
                  value: 'reminders',
                  child: ListTile(
                    leading: const Icon(LucideIcons.alarmClock),
                    title: Text(l10n.remindersTitle),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  key: const Key('chat_menu_folders'),
                  value: 'folders',
                  child: ListTile(
                    leading: const Icon(LucideIcons.folders),
                    title: Text(l10n.chatFoldersEdit),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  key: const Key('chat_menu_status'),
                  value: 'status',
                  child: ListTile(
                    leading: const Icon(LucideIcons.smilePlus),
                    title: Text(l10n.statusTitle),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _body(context, state, items, conn, wide, archiveLoad),
      floatingActionButton: _showArchived || desktop
          ? null
          : FloatingActionButton(
              // Unique tag: the mail tab's compose FAB keeps the default one,
              // and both live in the shell at once (hero assert in debug).
              heroTag: 'fab_chat_new',
              key: const Key('chat_new_fab'),
              tooltip: l10n.chatNew,
              onPressed: () => context.push(Routes.chatNew),
              child: const Icon(LucideIcons.squarePen),
            ),
    );
  }

  /// Folder tabs: «Все», «Непрочитанные», «Группы», «Каналы», then the
  /// user's folders, each with the number of chats with unread messages.
  /// Long press on a tab (or the gear) opens «Папки чатов».
  Widget _filters(BuildContext context, List<ChatConversation> convs) {
    final l10n = context.l10n;
    final t = context.tokens;
    final folders = ref.watch(chatFoldersProvider.select((s) => s.folders));
    final selectedTab = ChatListTabs.effective(_tab, folders);
    final now = DateTime.now();
    final tabs = <(String, Key, String)>[
      (ChatListTabs.all, const Key('chat_filter_all'), l10n.chatFilterAll),
      (
        ChatListTabs.unread,
        const Key('chat_filter_unread'),
        l10n.chatFilterUnread,
      ),
      (
        ChatListTabs.groups,
        const Key('chat_filter_groups'),
        l10n.chatFilterGroups,
      ),
      (
        ChatListTabs.channels,
        const Key('chat_filter_channels'),
        l10n.chatFilterChannels,
      ),
      for (final f in folders)
        (
          ChatListTabs.folder(f.id),
          ValueKey('chat_folder_${f.id}'),
          chatFolderTitle(f),
        ),
    ];
    // The bar grows with the text scale and always leaves room for the
    // chips' padded 48 dp tap target (the chip itself stays compact).
    final height = math.max(
      52.0,
      MediaQuery.textScalerOf(context).scale(14) * 1.4 + 28,
    );
    return SizedBox(
      height: height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
        children: [
          for (final (tab, key, label) in tabs)
            Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: Center(
                child: GestureDetector(
                  // Touch shortcut only: screen readers use the gear button
                  // and the menu item «Настроить папки».
                  excludeFromSemantics: true,
                  onLongPress: () => openChatFolders(context),
                  onSecondaryTap: () => openChatFolders(context),
                  child: ChoiceChip(
                    key: key,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label),
                        if (ChatListTabs.unreadChats(tab, convs, folders, now)
                            case final count when count > 0) ...[
                          const SizedBox(width: Space.xs),
                          CountPill(
                            count,
                            color: t.textInverse,
                            background: t.primary,
                            semanticLabel: l10n.chatFolderUnreadChats(count),
                          ),
                        ],
                      ],
                    ),
                    selected: selectedTab == tab,
                    showCheckmark: false,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    // Selected text in textPrimary: a thin accent-coloured
                    // glyph on primarySoft falls below WCAG 4.5:1 once
                    // anti-aliased (e.g. yellow on teal in «Көк»). The accent
                    // stays on the border, so the selection is still visible.
                    labelStyle: TextStyle(
                      color: selectedTab == tab
                          ? t.textPrimary
                          : t.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    selectedColor: t.primarySoft,
                    backgroundColor: t.surface,
                    side: BorderSide(
                      color: selectedTab == tab ? t.primary : t.border,
                      width: t.borderWidth,
                    ),
                    shape: const StadiumBorder(),
                    onSelected: (_) => setState(() => _tab = tab),
                  ),
                ),
              ),
            ),
          Center(
            child: IconButton(
              key: const Key('chat_folders_edit'),
              tooltip: l10n.chatFoldersEdit,
              icon: Icon(LucideIcons.settings2, color: t.textSecondary),
              onPressed: () => openChatFolders(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    ConversationsState state,
    List<ChatConversation> items,
    RealtimeStatus conn,
    bool wide,
    AsyncValue<int>? archiveLoad,
  ) {
    final l10n = context.l10n;
    final notifier = ref.read(conversationsProvider.notifier);
    if (state.error != null && state.items.isEmpty) {
      final err = state.error!;
      if (err is ApiException &&
          (err.code == 'FORBIDDEN' || err.code == 'NO_ORGANIZATION')) {
        return StateView.error(
          message: l10n.chatNoAccess,
          icon: LucideIcons.lock,
        );
      }
      return StateView.error(
        message: ChatFormat.error(l10n, err),
        onRetry: notifier.refresh,
      );
    }
    if (state.loading && !state.loaded) return const StateView.loading();
    final showFilters = !_searching && !_showArchived;
    Future<void> refresh() async {
      if (_showArchived) {
        ref.invalidate(chatArchivedLoadProvider);
        await ref.read(chatArchivedLoadProvider.future);
      } else {
        await notifier.refresh();
      }
    }

    Widget content;
    if (items.isEmpty && _messageHits.isEmpty) {
      if (_showArchived && (archiveLoad?.isLoading ?? false)) {
        content = const StateView.loading();
      } else {
        final (title, icon, action) = _searching || _query.isNotEmpty
            ? (l10n.chatSearchNoResults, LucideIcons.searchX, false)
            : _showArchived
            ? (l10n.chatArchivedEmpty, LucideIcons.archive, false)
            : _tab != ChatListTabs.all
            ? (l10n.chatEmptyFilter, LucideIcons.listFilter, false)
            : (l10n.chatEmpty, LucideIcons.messagesSquare, true);
        content = RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.55,
                child: StateView.empty(
                  title: title,
                  icon: icon,
                  actionLabel: action ? l10n.chatNew : null,
                  onAction: action ? () => openNewChat(context) : null,
                ),
              ),
            ],
          ),
        );
      }
    } else {
      // «Избранное» and pinned chats lead the list.
      final pinnedCount = items
          .takeWhile((c) => c.isSaved || c.isRequests || c.settings.pinned)
          .length;
      final hitsHeader = _messageHits.isNotEmpty ? 1 : 0;
      final total = items.length + hitsHeader + _messageHits.length;
      final selected = wide
          ? ref.watch(chatSelectedConversationProvider)
          : null;
      content = RefreshIndicator(
        onRefresh: refresh,
        child: ListView.builder(
          key: const PageStorageKey('chat_list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: Space.xxxl + Space.xl),
          itemCount: total,
          itemBuilder: (context, i) {
            if (i < items.length) {
              final c = items[i];
              final actions = c.isSaved || c.isRequests
                  ? const <_SwipeAction>[]
                  : _swipeActions(context, c);
              final tile = _ConversationTile(
                conversation: c,
                selected: c.id == selected,
                dividerBelow:
                    pinnedCount > 0 &&
                    i == pinnedCount - 1 &&
                    pinnedCount < items.length,
                onTap: () => _open(c.id, wide: wide),
                onLongPress: c.isSaved || c.isRequests
                    ? null
                    : () => _actions(context, c),
                // Desktop: right click opens the menu at the pointer.
                onContextMenu:
                    c.isSaved ||
                        c.isRequests ||
                        !ref.watch(desktopLayoutProvider)
                    ? null
                    : (at) => _actions(context, c, at: at),
                // Swipe actions stay reachable from TalkBack / VoiceOver.
                semanticActions: {
                  for (final a in actions)
                    CustomSemanticsAction(label: a.semanticLabel ?? a.label):
                        a.onTap,
                },
              );
              // «Избранное» is always on top: no pin / mute / archive.
              // Desktop: no swipe with a mouse, the actions are on right click.
              if (c.isSaved || isDesktop) {
                return KeyedSubtree(
                  key: ValueKey('swipe_${c.id}'),
                  child: tile,
                );
              }
              return _SwipeActions(
                key: ValueKey('swipe_${c.id}'),
                id: c.id,
                openId: _openSwipe,
                actions: actions,
                child: tile,
              );
            }
            if (i == items.length) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.md,
                  Space.md,
                  Space.md,
                  Space.xs,
                ),
                child: Text(
                  context.tokens.sectionLabel(l10n.chatSearchMessages),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.tokens.textTertiary,
                    letterSpacing: 0.6,
                  ),
                ),
              );
            }
            final m = _messageHits[i - items.length - 1];
            return _MessageHitTile(
              message: m,
              onTap: () {
                ref
                    .read(chatJumpRequestProvider.notifier)
                    .request(m.conversationId, m.id);
                _open(m.conversationId, wide: wide);
              },
            );
          },
        ),
      );
    }
    return Column(
      children: [
        if (conn == RealtimeStatus.disconnected && state.fromCache)
          OfflineBanner(
            text: l10n.offlineBanner,
            onRetry: () => ref.read(chatRepositoryProvider).kick(),
          ),
        if (showFilters) _filters(context, state.items),
        Expanded(child: content),
      ],
    );
  }

  List<_SwipeAction> _swipeActions(BuildContext context, ChatConversation c) {
    final l10n = context.l10n;
    final t = context.tokens;
    final repo = ref.read(chatRepositoryProvider);
    Future<void> run(Future<void> Function() action) async {
      _openSwipe.value = null;
      unawaited(HapticFeedback.selectionClick());
      try {
        await action();
      } on AppException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(this.context)
            .showSnackBar(SnackBar(content: Text(ChatFormat.error(l10n, e))));
      }
    }

    return [
      _SwipeAction(
        key: 'swipe_unread_${c.id}',
        icon: c.hasUnread ? LucideIcons.mailOpen : LucideIcons.messageSquareDot,
        label: c.hasUnread ? l10n.chatReadShort : l10n.chatUnreadShort,
        semanticLabel: c.hasUnread ? l10n.chatMarkRead : l10n.chatMarkUnread,
        background: t.labelBlue,
        foreground: t.labelBlueText,
        onTap: () => run(() => _toggleUnread(c)),
      ),
      _SwipeAction(
        key: 'swipe_pin_${c.id}',
        icon: c.settings.pinned ? LucideIcons.pinOff : LucideIcons.pin,
        label: c.settings.pinned ? l10n.chatUnpin : l10n.chatPin,
        background: t.primary,
        foreground: t.textInverse,
        onTap: () =>
            run(() => repo.patchChat(c.id, pinned: !c.settings.pinned)),
      ),
      _SwipeAction(
        key: 'swipe_mute_${c.id}',
        icon: c.isMuted ? LucideIcons.volume2 : LucideIcons.volumeX,
        label: c.isMuted ? l10n.chatUnmute : l10n.chatMute,
        background: t.warning,
        foreground: t.textInverse,
        onTap: () => run(
          () => c.isMuted
              ? repo.patchChat(c.id, unmute: true)
              : repo.patchChat(
                  c.id,
                  mutedUntil: DateTime.now().add(const Duration(days: 3650)),
                ),
        ),
      ),
      _SwipeAction(
        key: 'swipe_archive_${c.id}',
        icon: c.settings.archived
            ? LucideIcons.archiveRestore
            : LucideIcons.archive,
        label: c.settings.archived ? l10n.chatUnarchive : l10n.chatArchive,
        background: t.textTertiary,
        foreground: t.textInverse,
        onTap: () =>
            run(() => repo.patchChat(c.id, archived: !c.settings.archived)),
      ),
    ];
  }

  /// «Пометить как прочитанное / непрочитанное». Reading up to the last
  /// message also clears the flag on the server.
  Future<void> _toggleUnread(ChatConversation c) async {
    final repo = ref.read(chatRepositoryProvider);
    if (!c.hasUnread) {
      await repo.markUnread(c.id, true);
      return;
    }
    final last = c.lastMessage;
    if (c.unread > 0 && last != null && last.seq > 0) await repo.markRead(last);
    if (c.settings.markedUnread || c.unread == 0) {
      await repo.markUnread(c.id, false);
    }
  }

  /// Desktop: the row's actions as a menu at the pointer [at] (the web's
  /// context menu), same choices as the phone's sheet.
  Future<String?> _actionsMenu(BuildContext context, ChatConversation c, Offset at) {
    final l10n = context.l10n;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    PopupMenuItem<String> item(String value, IconData icon, String label, {Key? key}) => PopupMenuItem(
      key: key,
      value: value,
      child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(icon, size: 18), title: Text(label)),
    );
    return showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(at & const Size(1, 1), Offset.zero & overlay.size),
      items: [
        item(
          'unread',
          c.hasUnread ? LucideIcons.mailOpen : LucideIcons.messageSquareDot,
          c.hasUnread ? l10n.chatMarkRead : l10n.chatMarkUnread,
          key: const Key('chat_menu_mark_unread'),
        ),
        item('pin', c.settings.pinned ? LucideIcons.pinOff : LucideIcons.pin, c.settings.pinned ? l10n.chatUnpin : l10n.chatPin),
        if (c.isMuted)
          item('unmute', LucideIcons.volume2, l10n.chatUnmute)
        else ...[
          item('mute1h', LucideIcons.volumeX, '${l10n.chatMute}: ${l10n.chatMuteHour}'),
          item('mute24h', LucideIcons.volumeX, '${l10n.chatMute}: ${l10n.chatMuteDay}'),
          item('muteForever', LucideIcons.volumeX, '${l10n.chatMute}: ${l10n.chatMuteForever}'),
        ],
        item(
          'archive',
          c.settings.archived ? LucideIcons.archiveRestore : LucideIcons.archive,
          c.settings.archived ? l10n.chatUnarchive : l10n.chatArchive,
        ),
        item('folder', LucideIcons.folderPlus, l10n.chatAddToFolder),
      ],
    );
  }

  Future<void> _actions(BuildContext context, ChatConversation c, {Offset? at}) async {
    final l10n = context.l10n;
    final repo = ref.read(chatRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    _openSwipe.value = null;
    final action = at != null
        ? await _actionsMenu(context, c, at)
        : await showAppSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('chat_action_mark_unread'),
              leading: Icon(
                c.hasUnread
                    ? LucideIcons.mailOpen
                    : LucideIcons.messageSquareDot,
              ),
              title: Text(
                c.hasUnread ? l10n.chatMarkRead : l10n.chatMarkUnread,
              ),
              onTap: () => Navigator.pop(ctx, 'unread'),
            ),
            ListTile(
              key: const Key('chat_action_pin'),
              leading: Icon(
                c.settings.pinned ? LucideIcons.pinOff : LucideIcons.pin,
              ),
              title: Text(c.settings.pinned ? l10n.chatUnpin : l10n.chatPin),
              onTap: () => Navigator.pop(ctx, 'pin'),
            ),
            if (c.isMuted)
              ListTile(
                leading: const Icon(LucideIcons.volume2),
                title: Text(l10n.chatUnmute),
                onTap: () => Navigator.pop(ctx, 'unmute'),
              )
            else ...[
              ListTile(
                leading: const Icon(LucideIcons.volumeX),
                title: Text('${l10n.chatMute}: ${l10n.chatMuteHour}'),
                onTap: () => Navigator.pop(ctx, 'mute1h'),
              ),
              ListTile(
                key: const Key('chat_action_mute_day'),
                leading: const Icon(LucideIcons.volumeX),
                title: Text('${l10n.chatMute}: ${l10n.chatMuteDay}'),
                onTap: () => Navigator.pop(ctx, 'mute24h'),
              ),
              ListTile(
                leading: const Icon(LucideIcons.volumeX),
                title: Text('${l10n.chatMute}: ${l10n.chatMuteForever}'),
                onTap: () => Navigator.pop(ctx, 'muteForever'),
              ),
            ],
            ListTile(
              leading: Icon(
                c.settings.archived
                    ? LucideIcons.archiveRestore
                    : LucideIcons.archive,
              ),
              title: Text(
                c.settings.archived ? l10n.chatUnarchive : l10n.chatArchive,
              ),
              onTap: () => Navigator.pop(ctx, 'archive'),
            ),
            ListTile(
              key: const Key('chat_action_add_to_folder'),
              leading: const Icon(LucideIcons.folderPlus),
              title: Text(l10n.chatAddToFolder),
              onTap: () => Navigator.pop(ctx, 'folder'),
            ),
          ],
        ),
        ),
      ),
    );
    if (action == null) return;
    try {
      switch (action) {
        case 'unread':
          await _toggleUnread(c);
        case 'pin':
          await repo.patchChat(c.id, pinned: !c.settings.pinned);
        case 'unmute':
          await repo.patchChat(c.id, unmute: true);
        case 'mute1h':
          await repo.patchChat(
            c.id,
            mutedUntil: DateTime.now().add(const Duration(hours: 1)),
          );
        case 'mute24h':
          await repo.patchChat(
            c.id,
            mutedUntil: DateTime.now().add(const Duration(hours: 24)),
          );
        case 'muteForever':
          await repo.patchChat(
            c.id,
            mutedUntil: DateTime.now().add(const Duration(days: 3650)),
          );
        case 'archive':
          await repo.patchChat(c.id, archived: !c.settings.archived);
        case 'folder':
          if (mounted) await showAddToFolderSheet(this.context, c);
      }
    } on AppException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ChatFormat.error(l10n, e))),
      );
    }
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    required this.onLongPress,
    this.onContextMenu,
    this.selected = false,
    this.dividerBelow = false,
    this.semanticActions = const {},
  });
  final ChatConversation conversation;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Desktop right click, with the pointer position (null: [onLongPress]).
  final ValueChanged<Offset>? onContextMenu;
  final bool selected;

  /// The swipe actions, exposed as custom accessibility actions.
  final Map<CustomSemanticsAction, VoidCallback> semanticActions;

  /// Thin rule after the last pinned chat.
  final bool dividerBelow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final c = conversation;
    final last = c.lastMessage;
    final selfId = ref.read(chatRepositoryProvider).selfId;
    final activity = ref.watch(chatActivityProvider.select((m) => m[c.id]));
    final draft = ref.watch(chatDraftsProvider.select((m) => m[c.id]));
    final unread = c.hasUnread;

    Widget subtitle;
    String subtitleText;
    final mutedStyle = theme.textTheme.bodyMedium?.copyWith(
      color: t.textTertiary,
      fontSize: t.display.fontSizeList,
    );
    if (activity != null && activity.isNotEmpty) {
      final a = activity.values.first;
      final text = c.isGroup && a.name.isNotEmpty
          ? (a.recording ? l10n.chatRecording(a.name) : l10n.chatTyping(a.name))
          : (a.recording ? l10n.chatRecordingShort : l10n.chatTypingShort);
      subtitleText = text;
      subtitle = Text(
        text,
        key: ValueKey('chat_typing_${c.id}'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: mutedStyle?.copyWith(color: t.primary),
      );
    } else if (draft != null && draft.trim().isNotEmpty) {
      subtitleText = '${l10n.chatDraft}: ${draft.replaceAll('\n', ' ')}';
      subtitle = Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${l10n.chatDraft}: ',
              style: TextStyle(color: t.danger, fontWeight: FontWeight.w600),
            ),
            TextSpan(text: draft.replaceAll('\n', ' ')),
          ],
        ),
        key: ValueKey('chat_draft_${c.id}'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: mutedStyle,
      );
    } else {
      var preview = last == null
          ? (c.isSaved
                ? l10n.chatSavedHint
                : (c.isRequests ? l10n.requestsListHint : ''))
          : ChatFormat.preview(l10n, last);
      if (last != null && !last.isServiceLike && !c.isSaved) {
        final sender = last.senderId == selfId
            ? l10n.chatYou
            : (c.isGroup
                  ? c.members
                            .where((m) => m.userId == last.senderId)
                            .map((m) => m.label.split(' ').first)
                            .firstOrNull ??
                        ''
                  : '');
        if (sender.isNotEmpty) preview = '$sender: $preview';
      }
      subtitleText = preview.replaceAll('\n', ' ');
      subtitle = Text(
        preview.replaceAll('\n', ' '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: mutedStyle?.copyWith(
          color: unread ? t.textSecondary : t.textTertiary,
        ),
      );
    }

    final ownLast =
        last != null &&
        last.senderId == selfId &&
        !last.isServiceLike &&
        !c.isSaved;
    final time = ChatFormat.listTime(context, c.updatedAt);
    final String? statusLabel = !ownLast
        ? null
        : last.failed
        ? l10n.chatFailed
        : last.pending
        ? l10n.chatPending
        : switch (last.status) {
            'read' => l10n.chatStatusRead,
            'delivered' => l10n.chatStatusDelivered,
            _ => l10n.chatStatusSent,
          };
    // One screen-reader node per row: «Имя, текст, время, прочитано».
    final semanticLabel = [
      c.isSaved ? l10n.chatSaved : c.title,
      if (c.isChannel) l10n.channelBadge,
      subtitleText,
      time,
      if (c.unread > 0) l10n.a11yUnreadCount(c.unread),
      if (c.unread <= 0 && c.settings.markedUnread && !c.isSaved)
        l10n.a11yMarkedUnread,
      if (c.isMuted) l10n.a11yMuted,
      if (c.settings.pinned && !c.isSaved) l10n.a11yPinned,
      ?statusLabel,
      if (c.peer?.online == true) l10n.chatOnline,
    ].where((s) => s.trim().isNotEmpty).join(', ');
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: semanticLabel,
      customSemanticsActions: semanticActions.isEmpty ? null : semanticActions,
      child: Material(
        color: selected ? t.surfaceSelected : t.surface,
        child: InkWell(
          key: ValueKey('chat_${c.id}'),
          onTap: onTap,
          onLongPress: onLongPress,
          onSecondaryTap: onContextMenu == null ? onLongPress : null,
          onSecondaryTapUp: onContextMenu == null ? null : (d) => onContextMenu!(d.globalPosition),
          child: ExcludeSemantics(
            child: Container(
              decoration: dividerBelow
                  ? BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: t.divider,
                          width: t.borderWidth,
                        ),
                      ),
                    )
                  : null,
              padding: EdgeInsets.symmetric(
                horizontal: Space.md,
                vertical: t.display.rowPaddingY,
              ),
              child: Row(
                children: [
                  ChatAvatar(conversation: c, radius: 26, showOnline: true),
                  const SizedBox(width: Space.smd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (c.isChannel)
                              Padding(
                                padding: const EdgeInsets.only(right: Space.xs),
                                child: Icon(
                                  LucideIcons.megaphone,
                                  key: ValueKey('chat_channel_badge_${c.id}'),
                                  size: 14,
                                  color: t.textTertiary,
                                  semanticLabel: l10n.channelBadge,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                c.isSaved ? l10n.chatSaved : c.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: t.textPrimary,
                                  fontWeight: unread
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                            if (c.isMuted)
                              Padding(
                                padding: const EdgeInsets.only(left: Space.xs),
                                child: Icon(
                                  LucideIcons.volumeX,
                                  size: 14,
                                  color: t.textTertiary,
                                ),
                              ),
                            const SizedBox(width: Space.sm),
                            if (ownLast && !last.pending && !last.failed)
                              Padding(
                                padding: const EdgeInsets.only(right: 3),
                                child: Icon(
                                  last.status == 'read'
                                      ? LucideIcons.checkCheck
                                      : LucideIcons.check,
                                  size: 14,
                                  color: last.status == 'read'
                                      ? t.primary
                                      : t.textTertiary,
                                ),
                              ),
                            Text(
                              time,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: t.display.fontSizeMeta,
                                color: unread && !c.isMuted
                                    ? t.primary
                                    : t.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Expanded(child: subtitle),
                            if (c.unread <= 0 &&
                                c.settings.markedUnread &&
                                !c.isSaved)
                              Padding(
                                padding: const EdgeInsets.only(left: Space.sm),
                                child: Container(
                                  key: ValueKey('chat_marked_unread_${c.id}'),
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: c.isMuted
                                        ? t.textTertiary
                                        : t.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              )
                            else if (c.unread > 0)
                              Padding(
                                padding: const EdgeInsets.only(left: Space.sm),
                                child: CountPill(
                                  c.unread,
                                  key: ValueKey('chat_unread_${c.id}'),
                                  color: c.isMuted
                                      ? t.textSecondary
                                      : t.textInverse,
                                  background: c.isMuted
                                      ? t.surfaceMuted
                                      : t.primary,
                                ),
                              )
                            else if (c.settings.pinned)
                              Padding(
                                padding: const EdgeInsets.only(left: Space.sm),
                                child: Icon(
                                  LucideIcons.pin,
                                  key: ValueKey('chat_pinned_${c.id}'),
                                  size: 15,
                                  color: t.textTertiary,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageHitTile extends ConsumerWidget {
  const _MessageHitTile({required this.message, required this.onTap});
  final ChatMessage message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final conv = ref.watch(
      conversationsProvider.select(
        (s) => s.items.where((c) => c.id == message.conversationId).firstOrNull,
      ),
    );
    return ListTile(
      key: ValueKey('chat_hit_${message.id}'),
      leading: conv == null
          ? CircleAvatar(
              backgroundColor: t.surfaceMuted,
              child: Icon(LucideIcons.messageSquare, color: t.textTertiary),
            )
          : ChatAvatar(conversation: conv),
      title: Text(
        conv?.isSaved == true ? context.l10n.chatSaved : (conv?.title ?? ''),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        message.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: t.textSecondary),
      ),
      trailing: Text(
        ChatFormat.listTime(context, message.createdAt),
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: t.textTertiary),
      ),
      onTap: onTap,
    );
  }
}

class _SwipeAction {
  const _SwipeAction({
    required this.key,
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.semanticLabel,
  });
  final String key;
  final IconData icon;
  final String label;

  /// Full wording for screen readers when [label] is abbreviated.
  final String? semanticLabel;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
}

/// Swipe a tile left to reveal actions (pin / mute / archive). One tile is
/// open at a time; a tap on an open tile closes it.
class _SwipeActions extends StatefulWidget {
  const _SwipeActions({
    super.key,
    required this.id,
    required this.openId,
    required this.actions,
    required this.child,
  });
  final String id;
  final ValueNotifier<String?> openId;
  final List<_SwipeAction> actions;
  final Widget child;

  static const actionWidth = 76.0;

  @override
  State<_SwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<_SwipeActions>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  double get _width => widget.actions.length * _SwipeActions.actionWidth;

  @override
  void initState() {
    super.initState();
    widget.openId.addListener(_onOpenChanged);
  }

  @override
  void didUpdateWidget(covariant _SwipeActions old) {
    super.didUpdateWidget(old);
    if (old.openId != widget.openId) {
      old.openId.removeListener(_onOpenChanged);
      widget.openId.addListener(_onOpenChanged);
    }
  }

  @override
  void dispose() {
    widget.openId.removeListener(_onOpenChanged);
    _c.dispose();
    super.dispose();
  }

  void _onOpenChanged() {
    if (widget.openId.value != widget.id && _c.value > 0) _c.animateTo(0);
  }

  void _settle(double velocity) {
    final open = velocity < -300 || (velocity <= 300 && _c.value > 0.45);
    _c.animateTo(open ? 1 : 0);
    if (!open && widget.openId.value == widget.id) widget.openId.value = null;
  }

  @override
  Widget build(BuildContext context) {
    // Screen readers use the tile's custom actions instead of the swipe.
    return GestureDetector(
      excludeFromSemantics: true,
      onHorizontalDragStart: (_) {
        _c.stop();
        widget.openId.value = widget.id;
      },
      onHorizontalDragUpdate: (d) =>
          _c.value = (_c.value - (d.primaryDelta ?? 0) / _width).clamp(0, 1),
      onHorizontalDragEnd: (d) => _settle(d.primaryVelocity ?? 0),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              // Hidden behind the closed tile: out of the semantics tree
              // until the row is swiped open.
              // Only the part the swipe has uncovered is painted: a glass
              // skin's see-through tile must not show the actions through.
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, child) => _c.value == 0
                    ? const SizedBox.shrink()
                    : Align(
                        alignment: Alignment.centerRight,
                        child: ClipRect(
                          child: SizedBox(
                            width: _c.value * _width,
                            child: OverflowBox(
                              alignment: Alignment.centerLeft,
                              minWidth: _width,
                              maxWidth: _width,
                              child: child,
                            ),
                          ),
                        ),
                      ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (final a in widget.actions)
                      SizedBox(
                        width: _SwipeActions.actionWidth,
                        child: Material(
                          color: a.background,
                          child: InkWell(
                            key: ValueKey(a.key),
                            onTap: a.onTap,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(a.icon, color: a.foreground, size: 20),
                                const SizedBox(height: Space.xs),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Space.xs,
                                  ),
                                  child: Text(
                                    a.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: a.foreground),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _c,
              builder: (context, child) => Transform.translate(
                offset: Offset(-_c.value * _width, 0),
                child: _c.value > 0
                    ? GestureDetector(
                        excludeFromSemantics: true,
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _settle(1000),
                        child: IgnorePointer(child: child),
                      )
                    : child,
              ),
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}
