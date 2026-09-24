import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/localization/localization.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/error_text.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/ds/folder_chip.dart';
import '../../../shared/widgets/ds/sidebar_nav_item.dart';
import '../../../shared/widgets/ds/x_badge.dart';
import '../../tasks/presentation/tasks_providers.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../data/mail_models.dart';
import '../../official/presentation/official_widgets.dart';
import 'folder_names.dart';
import 'mail_providers.dart';
import 'mail_selection.dart';
import 'compose_window.dart';

/// The web `MailSidebar`, as the mail tab's drawer (and the static sidebar on
/// wide screens): brand row, Compose + Refresh, the Mail section with the
/// system folders — Inbox expands into the smart folders, Bookmarks into the
/// bookmark collections — the Workspace section and Settings at the bottom.
/// Colours come from the sidebar tokens, so the kok skin's drawer is deep teal.
class FolderDrawer extends ConsumerStatefulWidget {
  const FolderDrawer({super.key, this.embedded = false})
    : desktop = null;

  /// The desktop app's sidebar: the web `MailSidebar` for every module
  /// (full height, collapsible to icons, workspace links with their badges).
  const FolderDrawer.desktop({super.key, required DesktopSidebarHost this.desktop})
    : embedded = true;

  /// True when shown as a static column beside the content (≥ lg): no
  /// `Navigator.pop` after navigation.
  final bool embedded;

  /// Desktop shell state (null on phones and tablets).
  final DesktopSidebarHost? desktop;

  @override
  ConsumerState<FolderDrawer> createState() => _FolderDrawerState();
}

/// What the desktop shell tells its sidebar: where the app is, how to go
/// elsewhere (the sidebar sits above the router's navigator), and whether
/// it is collapsed to icons.
class DesktopSidebarHost {
  const DesktopSidebarHost({
    required this.path,
    required this.navigate,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.dialogContext,
  });

  final String path;
  final void Function(String route) navigate;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;

  /// A context under the root navigator, for dialogs.
  final BuildContext? Function() dialogContext;

  bool on(String route) => path == route || path.startsWith('$route/');
}

class _FolderDrawerState extends ConsumerState<FolderDrawer> {
  bool? _inboxOpen;
  bool? _bookmarksOpen;
  bool _refreshing = false;

  void _close() {
    if (!widget.embedded && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  void _select(String type) {
    ref.read(selectedFolderProvider.notifier).select(type);
    final host = widget.desktop;
    if (host != null && !host.on(Routes.mail)) host.navigate(Routes.mail);
    _close();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await ref.read(mailSummaryProvider.notifier).refresh();
      ref.invalidate(mailListProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.mailRefreshed)));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ErrorText.describe(l10n, e))));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _create({required bool bookmark}) async {
    final l10n = context.l10n;
    final created = await showDialog<MailFolder>(
      context: widget.desktop?.dialogContext() ?? context,
      builder: (_) => _CreateFolderDialog(bookmark: bookmark),
    );
    if (created == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(bookmark ? l10n.mailBookmarkFolderCreated : l10n.mailFolderCreated)),
    );
    await ref.read(mailSummaryProvider.notifier).refresh();
    _select(created.type);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final host = widget.desktop;
    final collapsed = host?.collapsed ?? false;
    final round = host != null;
    // Folders are «current» only while the mail module is open.
    final onMail = host == null || host.on(Routes.mail);
    final summaryState = ref.watch(mailSummaryProvider);
    final selected = ref.watch(selectedFolderProvider);
    final user = ref.watch(currentUserProvider);
    final canSend = ref.watch(hasPermissionProvider(Permissions.mailSend));
    final folders = summaryState.summary?.folders ?? const <MailFolder>[];
    final byType = {for (final f in folders) f.type: f};
    final smart = folders.where((f) => f.isSmart).toList();
    final bookmark = folders.where((f) => f.isBookmarkFolder).toList();
    // Both trees start expanded as on the web, so the folders made there are
    // in sight instead of hidden under a collapsed Inbox.
    final inboxOpen = !collapsed && (_inboxOpen ?? true);
    final bookmarksOpen = !collapsed && (_bookmarksOpen ?? true);

    Widget systemItem(String type, IconData icon, {bool? expanded, VoidCallback? onToggle, String? toggleLabel}) {
      final f = byType[type];
      final count = type == MailFolderType.drafts ? (f?.total ?? 0) : (f?.unread ?? 0);
      final active = onMail && selected == type;
      final item = SidebarNavItem(
        semanticKey: Key('folder_$type'),
        icon: icon,
        label: folderDisplayName(l10n, type, serverName: f?.name),
        active: active,
        onTap: () => _select(type),
        badge: count > 0 ? CountPill(count, accent: type != MailFolderType.drafts, active: active && t.navActive == NavActiveStyle.tint) : null,
        expanded: collapsed ? null : expanded,
        onToggle: collapsed ? null : onToggle,
        toggleLabel: toggleLabel,
        round: round,
        iconOnly: collapsed,
      );
      if (host == null) return item;
      // Desktop: mail rows dragged from the list drop here (MailDrag).
      return DragTarget<MailDrag>(
        onWillAcceptWithDetails: (d) => canDropMail(d.data, type),
        onAcceptWithDetails: (d) => MailBulk(ref, context).run(BulkAction.move, d.data.items, folder: d.data.folder, archiveFolder: type),
        builder: (context, candidates, _) => candidates.isEmpty
            ? item
            : DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  border: Border.all(color: t.primary, width: 2),
                  borderRadius: BorderRadius.circular(round ? 999 : 10),
                ),
                child: item,
              ),
      );
    }

    Widget tree(List<MailFolder> items, {required IconData icon, required bool bookmarkTree}) => SidebarTree(
      children: [
        for (final f in items)
          SidebarTreeItem(
            semanticKey: Key('folder_${f.type}'),
            leading: FolderIconTile(color: f.color, icon: icon),
            label: f.name,
            active: onMail && selected == f.type,
            onTap: () => _select(f.type),
            trailing: f.unread > 0
                ? CountPill(f.unread, color: t.folderColors(f.color).foreground, background: t.folderColors(f.color).background)
                : null,
          ),
        SidebarTreeItem(
          semanticKey: Key(bookmarkTree ? 'create_bookmark_folder' : 'create_smart_folder'),
          leading: FolderIconTile(dashed: true, icon: items.isEmpty ? LucideIcons.folderPlus : LucideIcons.plus),
          label: items.isEmpty
              ? (bookmarkTree ? l10n.mailCreateFirstBookmarkFolder : l10n.mailCreateFirstFolder)
              : (bookmarkTree ? l10n.mailNewBookmarkFolder : l10n.mailNewFolder),
          active: false,
          onTap: () => _create(bookmark: bookmarkTree),
        ),
      ],
    );

    final Widget brand;
    if (host == null) {
      brand = Row(
        children: [
          BrandLockup(markColor: t.sidebarMark, nameColor: t.sidebarText),
          const Spacer(),
          if (user != null)
            Tooltip(
              message: user.email,
              child: InkWell(
                borderRadius: BorderRadius.circular(XatBoxTokens.radiusPill),
                onTap: () {
                  _close();
                  context.push(Routes.profile);
                },
                child: InitialsAvatar(label: user.displayName, colorKey: user.email, radius: InitialsAvatar.radiusSm),
              ),
            ),
        ],
      );
    } else if (collapsed) {
      brand = Center(
        child: Tooltip(
          message: l10n.desktopExpandSidebar,
          child: InkWell(
            key: const Key('sidebar_expand'),
            customBorder: const CircleBorder(),
            onTap: host.onToggleCollapsed,
            child: Padding(padding: const EdgeInsets.all(8), child: Icon(LucideIcons.chevronRight, size: 18, color: t.sidebarTextSecondary)),
          ),
        ),
      );
    } else {
      brand = Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                borderRadius: BorderRadius.circular(t.radiusSm),
                onTap: () => host.navigate(Routes.mail),
                // The mark is on the module rail beside it.
                child: BrandName(color: t.sidebarText, size: 20),
              ),
            ),
          ),
          IconButton(
            key: const Key('sidebar_collapse'),
            tooltip: l10n.desktopCollapseSidebar,
            onPressed: host.onToggleCollapsed,
            visualDensity: VisualDensity.compact,
            icon: Icon(LucideIcons.chevronLeft, size: 16, color: t.sidebarTextSecondary),
          ),
        ],
      );
    }

    final label = collapsed ? (String _) => const SizedBox(height: Space.smd) : (String text) => SidebarSectionLabel(text);

    return Material(
      color: t.sidebarSurface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand row: mark + wordmark, 56px, hairline below.
            Container(
              height: Space.topbarHeight,
              padding: EdgeInsets.symmetric(horizontal: collapsed ? Space.sm : Space.md),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.sidebarBorder, width: t.borderWidth))),
              child: brand,
            ),
            // Compose + Refresh.
            Padding(
              padding: EdgeInsets.fromLTRB(collapsed ? Space.sm : Space.smd, Space.smd, collapsed ? Space.sm : Space.smd, Space.xs),
              child: collapsed
                  ? Center(
                      child: Tooltip(
                        message: l10n.mailCompose,
                        child: Material(
                          color: t.sidebarPrimary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            key: const Key('compose_button'),
                            customBorder: const CircleBorder(),
                            onTap: canSend ? () => openCompose(ref) : null,
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(LucideIcons.pencil, size: 18, color: t.sidebarTextInverse),
                            ),
                          ),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _ComposeButton(
                            enabled: canSend,
                            onPressed: () {
                              _close();
                              openCompose(ref);
                            },
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        _SidebarIconButton(
                          key: const Key('mail_refresh'),
                          tooltip: l10n.mailRefresh,
                          icon: LucideIcons.refreshCw,
                          spinning: _refreshing,
                          onPressed: _refresh,
                        ),
                      ],
                    ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: Space.md, left: collapsed ? 0 : 0),
                children: [
                  if (summaryState.loading && folders.isEmpty)
                    LinearProgressIndicator(minHeight: 2, color: t.sidebarPrimary, backgroundColor: Colors.transparent),
                  if (summaryState.error != null && folders.isEmpty && !collapsed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
                      child: Row(
                        children: [
                          Icon(LucideIcons.circleAlert, size: 16, color: t.danger),
                          const SizedBox(width: Space.sm),
                          Expanded(
                            child: Text(
                              ErrorText.describe(l10n, summaryState.error!),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.sidebarTextSecondary),
                            ),
                          ),
                          TextButton(
                            onPressed: () => ref.read(mailSummaryProvider.notifier).refresh(),
                            style: TextButton.styleFrom(foregroundColor: t.sidebarPrimary),
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                    ),
                  label(l10n.sectionMail),
                  systemItem(
                    MailFolderType.inbox,
                    LucideIcons.inbox,
                    expanded: inboxOpen,
                    onToggle: () => setState(() => _inboxOpen = !inboxOpen),
                    toggleLabel: inboxOpen ? l10n.mailCollapseInbox : l10n.mailExpandInbox,
                  ),
                  if (inboxOpen) tree(smart, icon: LucideIcons.folder, bookmarkTree: false),
                  systemItem(
                    MailFolderType.bookmarks,
                    LucideIcons.bookmark,
                    expanded: bookmarksOpen,
                    onToggle: () => setState(() => _bookmarksOpen = !bookmarksOpen),
                    toggleLabel: bookmarksOpen ? l10n.mailCollapseInbox : l10n.mailExpandInbox,
                  ),
                  if (bookmarksOpen) tree(bookmark, icon: LucideIcons.bookmark, bookmarkTree: true),
                  systemItem(MailFolderType.sent, LucideIcons.send),
                  systemItem(MailFolderType.drafts, LucideIcons.fileText),
                  systemItem(MailFolderType.spam, LucideIcons.octagonAlert),
                  systemItem(MailFolderType.trash, LucideIcons.trash2),
                  // Desktop: the modules are on the rail (DesktopFrame).
                  if (host == null) label(l10n.sectionWorkspace),
                  if (host == null) ...[
                    SidebarNavItem(
                      icon: LucideIcons.messageCircle,
                      label: l10n.chatTitle,
                      active: false,
                      onTap: () {
                        _close();
                        context.go(Routes.chat);
                      },
                    ),
                    SidebarNavItem(
                      semanticKey: const Key('sidebar_calendar'),
                      icon: LucideIcons.calendarDays,
                      label: l10n.calendarTitle,
                      active: false,
                      onTap: () {
                        _close();
                        context.go(Routes.calendar);
                      },
                    ),
                    OfficialNavItem(
                      onTap: () {
                        _close();
                        context.push(Routes.official);
                      },
                    ),
                    if (ref.watch(tasksEnabledProvider))
                      SidebarNavItem(
                        semanticKey: const Key('sidebar_tasks'),
                        icon: LucideIcons.listTodo,
                        label: l10n.tasksTitle,
                        active: false,
                        badge: ref.watch(tasksBadgeProvider) > 0 ? CountPill(ref.watch(tasksBadgeProvider)) : null,
                        onTap: () {
                          _close();
                          context.go(Routes.tasks);
                        },
                      ),
                    SidebarNavItem(
                      icon: LucideIcons.users,
                      label: l10n.contactsTitle,
                      active: false,
                      onTap: () {
                        _close();
                        context.go(Routes.contacts);
                      },
                    ),
                  ],
                ],
              ),
            ),
            // Footer: Settings on a hairline (desktop: on the rail).
            if (host == null)
            Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: t.sidebarBorder, width: t.borderWidth))),
              padding: const EdgeInsets.symmetric(vertical: Space.xs),
              child: SidebarNavItem(
                semanticKey: const Key('sidebar_settings'),
                icon: LucideIcons.settings,
                label: l10n.settingsTitle,
                active: host != null && (host.on(Routes.settings) || host.on(Routes.profile)),
                round: round,
                iconOnly: collapsed,
                onTap: () {
                  if (host != null) {
                    host.navigate(Routes.settings);
                    return;
                  }
                  _close();
                  context.push(Routes.settings);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.sidebar-compose-btn`: 40px, strong border, radius 11, pencil in a tile,
/// 600 display label.
class _ComposeButton extends StatelessWidget {
  const _ComposeButton({required this.enabled, required this.onPressed});
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final radius = BorderRadius.circular(11);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: t.sidebarSubtle == t.sidebarSurface ? t.surface : t.sidebarSubtle,
        borderRadius: radius,
        child: InkWell(
          key: const Key('compose_button'),
          onTap: enabled ? onPressed : null,
          borderRadius: radius,
          child: Container(
            height: Space.controlLg,
            padding: const EdgeInsets.fromLTRB(5, 0, Space.smd, 0),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: t.palette.sidebar?.borderStrong ?? t.borderStrong, width: t.borderWidth),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: t.sidebarPrimary, borderRadius: BorderRadius.circular(8)),
                  child: Icon(LucideIcons.pencil, size: 15, color: t.sidebarTextInverse),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.mailCompose,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontFamily: t.fontDisplay,
                      fontWeight: FontWeight.w600,
                      color: t.sidebarText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarIconButton extends StatefulWidget {
  const _SidebarIconButton({super.key, required this.tooltip, required this.icon, required this.onPressed, this.spinning = false});
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool spinning;

  @override
  State<_SidebarIconButton> createState() => _SidebarIconButtonState();
}

class _SidebarIconButtonState extends State<_SidebarIconButton> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(covariant _SidebarIconButton old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_spin.isAnimating) _spin.repeat();
    if (!widget.spinning && _spin.isAnimating) _spin.stop();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: Space.controlLg,
      height: Space.controlLg,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: widget.spinning ? null : widget.onPressed,
          borderRadius: BorderRadius.circular(11),
          child: Tooltip(
            message: widget.tooltip,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: t.palette.sidebar?.borderStrong ?? t.borderStrong, width: t.borderWidth),
              ),
              child: RotationTransition(
                turns: _spin,
                child: Icon(widget.icon, size: 16, color: t.sidebarTextSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `CreateFolderDialog` of the web sidebar: name field + hint, Create.
class _CreateFolderDialog extends ConsumerStatefulWidget {
  const _CreateFolderDialog({required this.bookmark});
  final bool bookmark;

  @override
  ConsumerState<_CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends ConsumerState<_CreateFolderDialog> {
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = ref.read(mailApiProvider);
    try {
      final MailFolder folder;
      if (widget.bookmark) {
        final created = await api.createBookmarkFolder(name);
        folder = MailFolder(
          id: created.id,
          name: created.name,
          type: '${MailFolderType.bookmarkPrefix}${created.id}',
          color: created.color,
          unread: 0,
          total: 0,
        );
      } else {
        folder = await api.createSmartFolder(name);
      }
      if (mounted) Navigator.of(context).pop(folder);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = ErrorText.describe(context.l10n, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return AlertDialog(
      title: Text(widget.bookmark ? l10n.mailNewBookmarkFolder : l10n.mailNewFolder),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.bookmark ? l10n.mailBookmarkModalHint : l10n.mailFolderModalHint, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: Space.md),
          Text(l10n.mailFolderName, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: Space.xs),
          TextField(
            key: const Key('folder_name'),
            controller: _name,
            autofocus: true,
            maxLength: 80,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(hintText: l10n.mailFolderNameHint, counterText: '', errorText: _error),
            onSubmitted: (_) => _submit(),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(
          key: const Key('folder_create'),
          onPressed: _busy || _name.text.trim().isEmpty ? null : _submit,
          child: _busy
              ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: t.textInverse))
              : Text(l10n.save),
        ),
      ],
    );
  }
}
