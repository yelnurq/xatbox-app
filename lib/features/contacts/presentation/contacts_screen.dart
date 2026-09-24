import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/platform/desktop_layout.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/localization/localization.dart';
import '../../../core/platform/launcher_requests.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/error_text.dart';
import '../../../shared/widgets/state_view.dart';
import '../../chat/presentation/chat_formatters.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../search/presentation/unified_search_button.dart';
import '../data/contact_models.dart';
import 'contact_widgets.dart';
import 'contact_menu.dart';
import 'contacts_providers.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/split_pane.dart';
import 'contact_profile_screen.dart';
import 'contacts_desktop.dart' show PersonalContactPage, PersonalContactTile, showPersonalContactDialog;
import 'my_contacts_providers.dart';

export 'contact_widgets.dart' show ContactAvatar, ContactTile;

/// Flat rows of the directory for the current data and view; labels are the
/// localized section titles (no department / favourites / recent).
final contactsRowsProvider = Provider.autoDispose
    .family<ContactRows, (String, String, String)>((ref, labels) {
      final (contacts, query) = ref.watch(
        contactsProvider.select((s) => (s.contacts, s.query)),
      );
      return buildContactRows(
        contacts: contacts,
        view: ref.watch(contactsViewProvider),
        favourites: ref.watch(contactsFavouritesProvider),
        recent: ref.watch(contactsRecentProvider),
        query: query,
        noDepartment: labels.$1,
        favouritesTitle: labels.$2,
        recentTitle: labels.$3,
        selfId: ref.watch(currentUserProvider)?.id,
      );
    });

/// Root of the "Контакты" tab: the organization directory with debounced
/// search, filters, favourites, recent colleagues, alphabetical or
/// department sections with sticky headers and a fast-scroll index.
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  static const debounce = Duration(milliseconds: 350);

  final _search = TextEditingController();
  Timer? _debounce;

  /// «Мои»: the contacts the user added by hand (the desktop's «Мои
  /// контакты»), searched by the same field.
  bool _mine = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(debounce, () {
      if (mounted) unawaited(ref.read(contactsProvider.notifier).setQuery(q));
    });
    setState(() {}); // clear button visibility
  }

  void _clear() {
    _debounce?.cancel();
    _search.clear();
    setState(() {});
    unawaited(ref.read(contactsProvider.notifier).setQuery(''));
  }

  void _resetFilters() {
    ref.read(contactsViewProvider.notifier).setFilter(ContactsFilter.all);
    unawaited(ref.read(contactsProvider.notifier).setDepartment(''));
    if (_search.text.isNotEmpty) _clear();
  }

  Future<void> _pickDepartment() async {
    final selected = ref.read(contactsProvider).departmentId;
    final id = await showAppSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _DepartmentSheet(selected: selected),
    );
    if (id == null || !mounted) return;
    unawaited(ref.read(contactsProvider.notifier).setDepartment(id));
  }

  /// The profile open in the right pane of the wide layout.
  Contact? _selected;

  void _open(Contact contact) {
    if (context.isExpanded) {
      setState(() => _selected = contact);
      return;
    }
    context.push(Routes.contactProfilePath(contact.id), extra: contact);
  }

  @override
  Widget build(BuildContext context) {
    final list = _list(context);
    if (!context.isExpanded || !ref.watch(chatEnabledProvider)) return list;
    final selected = _selected;
    return SplitPane(
      list: list,
      placeholderTitle: context.l10n.contactsSelect,
      placeholderIcon: LucideIcons.contactRound,
      detail: selected == null
          ? null
          : ContactProfileScreen(key: ValueKey('pane_${selected.id}'), userId: selected.id, initial: selected),
    );
  }

  Widget _list(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    if (!ref.watch(chatEnabledProvider)) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.contactsTitle)),
        body: StateView.empty(
          title: l10n.contactsChatDisabled,
          icon: LucideIcons.bookUser,
        ),
      );
    }
    // «Показать все» of the unified search: the field pre-filled.
    if (ref.watch(contactsSearchRequestProvider) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final q = ref.read(contactsSearchRequestProvider);
        if (!mounted || q == null) return;
        ref.read(contactsSearchRequestProvider.notifier).consume();
        _debounce?.cancel();
        _search.text = q;
        setState(() {});
        unawaited(ref.read(contactsProvider.notifier).setQuery(q));
      });
    }
    final state = ref.watch(contactsProvider);
    final view = ref.watch(contactsViewProvider);
    final favIds = ref.watch(contactsFavouriteIdsProvider);
    final rows = ref.watch(
      contactsRowsProvider((
        l10n.contactsNoDepartment,
        l10n.contactsFavourites,
        l10n.contactsRecent,
      )),
    );
    final department = ref.watch(
      contactsDepartmentProvider(state.departmentId),
    );
    final notifier = ref.read(contactsProvider.notifier);

    final Widget content;
    if (_mine) {
      content = _myContacts(context);
    } else if (!state.loaded && state.contacts.isEmpty) {
      content = const StateView.loading();
    } else if (rows.rows.isEmpty && state.error != null && !state.fromCache) {
      final message = ErrorText.isOffline(state.error)
          ? ErrorText.describe(l10n, state.error!)
          : ChatFormat.error(l10n, state.error!);
      content = ErrorText.isOffline(state.error)
          ? StateView.offline(message: message, onRetry: notifier.refresh)
          : StateView.error(message: message, onRetry: notifier.refresh);
    } else {
      final filtered =
          state.query.isNotEmpty ||
          state.departmentId.isNotEmpty ||
          view.filter != ContactsFilter.all;
      content = RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(contactsDepartmentsProvider);
          await notifier.refresh();
        },
        child: rows.visibleCount == 0 && !state.loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (rows.rows.isNotEmpty)
                    ..._staticRows(rows.rows, favIds, state.query),
                  SizedBox(
                    height: 360,
                    child: _EmptyState(
                      filter: view.filter,
                      searching: filtered,
                      onReset: filtered ? _resetFilters : null,
                    ),
                  ),
                ],
              )
            : rows.rows.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 320, child: StateView.loading()),
                ],
              )
            : _ContactsList(
                rows: rows,
                favIds: favIds,
                query: state.query,
                showIndex: !view.byDepartment,
                onOpen: _open,
                selectedId: ref.watch(desktopLayoutProvider) && context.isExpanded ? _selected?.id : null,
                onContextMenu: ref.watch(desktopLayoutProvider) ? (c, at) => showContactMenu(context, ref, c, at) : null,
                footer: state.truncated
                    ? l10n.contactsLimitHint(state.contacts.length)
                    : null,
              ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.contactsTitle),
        actions: [
          const UnifiedSearchButton(),
          // Desktop: no pull to refresh with a mouse.
          if (ref.watch(desktopLayoutProvider))
            IconButton(
              key: const Key('contacts_refresh'),
              tooltip: l10n.desktopRefresh,
              icon: const Icon(LucideIcons.refreshCw),
              onPressed: () {
                ref.invalidate(contactsDepartmentsProvider);
                unawaited(notifier.refresh());
              },
            ),
          IconButton(
            key: const Key('contacts_group_toggle'),
            tooltip: view.byDepartment
                ? l10n.contactsGroupByName
                : l10n.contactsGroupByDepartment,
            icon: Icon(
              view.byDepartment
                  ? LucideIcons.arrowDownAZ
                  : LucideIcons.building2,
            ),
            onPressed: ref.read(contactsViewProvider.notifier).toggleGrouping,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.md,
              Space.sm,
              Space.md,
              Space.xs,
            ),
            child: TextField(
              key: const Key('contacts_search'),
              controller: _search,
              onChanged: _onQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.contactsSearchHint,
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.contactsClearSearch,
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: _clear,
                      ),
              ),
            ),
          ),
          // Pills stay compact; each pill's tap area fills the strip (≥ 48 dp).
          SizedBox(
            height: math.max(
              52,
              MediaQuery.textScalerOf(context).scale(13) * 1.4 + 30,
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: Space.md,
                vertical: Space.xxs,
              ),
              children: [
                _FilterPill(
                  key: const Key('contacts_filter_all'),
                  label: l10n.contactsFilterAll,
                  selected:
                      !_mine &&
                      view.filter == ContactsFilter.all &&
                      state.departmentId.isEmpty,
                  onTap: () {
                    setState(() => _mine = false);
                    ref
                        .read(contactsViewProvider.notifier)
                        .setFilter(ContactsFilter.all);
                    unawaited(notifier.setDepartment(''));
                  },
                ),
                _FilterPill(
                  key: const Key('contacts_filter_online'),
                  label: l10n.contactsFilterOnline,
                  icon: LucideIcons.circleDot,
                  iconColor: t.success,
                  selected: view.filter == ContactsFilter.online,
                  onTap: () => ref
                      .read(contactsViewProvider.notifier)
                      .setFilter(
                        view.filter == ContactsFilter.online
                            ? ContactsFilter.all
                            : ContactsFilter.online,
                      ),
                ),
                _FilterPill(
                  key: const Key('contacts_filter_favourites'),
                  label: l10n.contactsFilterFavourites,
                  icon: LucideIcons.star,
                  selected: view.filter == ContactsFilter.favourites,
                  onTap: () => ref
                      .read(contactsViewProvider.notifier)
                      .setFilter(
                        view.filter == ContactsFilter.favourites
                            ? ContactsFilter.all
                            : ContactsFilter.favourites,
                      ),
                ),
                _FilterPill(
                  key: const Key('contacts_filter_department'),
                  label: department?.name ?? l10n.contactsFilterDepartment,
                  icon: LucideIcons.building2,
                  trailing: LucideIcons.chevronDown,
                  selected: state.departmentId.isNotEmpty,
                  onTap: _pickDepartment,
                ),
                _FilterPill(
                  key: const Key('contacts_filter_mine'),
                  label: l10n.contactsFilterMine,
                  icon: LucideIcons.bookUser,
                  selected: _mine,
                  onTap: () => setState(() => _mine = !_mine),
                ),
              ],
            ),
          ),
          if (state.fromCache && state.error != null)
            OfflineBanner(
              key: const Key('contacts_offline_banner'),
              text: ErrorText.isOffline(state.error)
                  ? l10n.offlineBanner
                  : l10n.contactsCachedBanner,
              onRetry: notifier.refresh,
            ),
          SizedBox(
            height: 2,
            child: state.loading && state.contacts.isNotEmpty
                ? const LinearProgressIndicator(minHeight: 2)
                : null,
          ),
          Expanded(child: content),
        ],
      ),
    );
  }

  /// «Мои»: personal contacts matching the search, «Новый контакт» first.
  Widget _myContacts(BuildContext context) {
    final l10n = context.l10n;
    final q = _search.text.trim().toLowerCase();
    final all = ref.watch(personalContactsProvider);
    final list = [
      for (final c in all)
        if (q.isEmpty || '${c.name} ${c.email} ${c.phone} ${c.details}'.toLowerCase().contains(q)) c,
    ];
    return ListView(
      key: const Key('contacts_mine_list'),
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + Space.md),
      children: [
        ListTile(
          key: const Key('contacts_mine_add'),
          leading: const Icon(LucideIcons.userPlus),
          title: Text(l10n.myContactsNew),
          onTap: () => unawaited(showPersonalContactDialog(context)),
        ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Text(
              all.isEmpty ? l10n.myContactsEmptyHint : l10n.contactsNotFound,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.tokens.textMuted),
            ),
          ),
        for (final c in list)
          PersonalContactTile(
            key: ValueKey('personal_${c.id}'),
            contact: c,
            query: q,
            onTap: () => unawaited(
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PersonalContactPage(contact: c))),
            ),
          ),
      ],
    );
  }

  /// Favourites / recent above an empty filtered list (short, not lazy).
  List<Widget> _staticRows(
    List<ContactRow> rows,
    Set<String> favIds,
    String query,
  ) {
    final (rowExtent, headerExtent) = _contactExtents(context);
    return [
      for (final row in rows)
        switch (row) {
          ContactHeaderRow() => _SectionHeader(row: row, height: headerExtent),
          // Min height: rows grow with the text instead of clipping.
          ContactItemRow(:final contact, :final section) => ConstrainedBox(
          constraints: BoxConstraints(minHeight: rowExtent),
          child: ContactTile(
            key: ValueKey('contact_${section}_${contact.id}'),
            contact: contact,
            query: query,
            favourite: favIds.contains(contact.id),
            onTap: () => _open(contact),
            selected: ref.watch(desktopLayoutProvider) && context.isExpanded && contact.id == _selected?.id,
            onContextMenu: ref.watch(desktopLayoutProvider) ? (at) => showContactMenu(context, ref, contact, at) : null,
          ),
        ),
        },
    ];
  }
}

/// Row and section-header extents of the directory for the current text
/// scale (the lazy list needs fixed extents).
(double, double) _contactExtents(BuildContext context) {
  final text = Theme.of(context).textTheme;
  final scaler = MediaQuery.textScalerOf(context);
  final titleSize = text.bodyLarge?.fontSize ?? 15;
  final subSize = text.bodySmall?.fontSize ?? 12;
  final row = math.max(
    64.0,
    scaler.scale(titleSize) * 1.5 + scaler.scale(subSize) * 1.5 + 22,
  );
  final header = math.max(
    32.0,
    scaler.scale(text.titleSmall?.fontSize ?? 14) * 1.5 + 12,
  );
  return (row, header);
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.iconColor,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // textPrimary, not the accent: accent glyphs on primarySoft fail WCAG
    // 4.5:1 once rendered (yellow on teal in «Көк»); the accent border marks
    // the selection.
    final fg = selected ? t.textPrimary : t.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(right: Space.sm),
      child: Semantics(
        container: true,
        button: true,
        selected: selected,
        // The strip is taller than the pill: a tap just above or below it
        // counts too, so the hit area is ≥ 48 dp while the pill stays small.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onTap,
          child: Center(
            child: Material(
              color: selected ? t.primarySoft : t.surface,
              shape: StadiumBorder(
                side: BorderSide(
                  color: selected ? t.primary : t.border,
                  width: t.borderWidth,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 36, minWidth: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.smd,
                      vertical: Space.xs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 14, color: iconColor ?? fg),
                          const SizedBox(width: Space.xs),
                        ],
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: fg,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: Space.xxs),
                          Icon(trailing, size: 14, color: fg),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.filter,
    required this.searching,
    this.onReset,
  });

  final ContactsFilter filter;
  final bool searching;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (filter) {
      ContactsFilter.favourites => KeyedSubtree(
        key: const Key('contacts_empty_favourites'),
        child: StateView.empty(
          title: l10n.contactsNoFavourites,
          subtitle: l10n.contactsNoFavouritesHint,
          icon: LucideIcons.star,
        ),
      ),
      ContactsFilter.online => KeyedSubtree(
        key: const Key('contacts_empty_online'),
        child: StateView.empty(
          title: l10n.contactsNoOnline,
          icon: LucideIcons.userRound,
          actionLabel: l10n.contactsFilterAll,
          onAction: onReset,
        ),
      ),
      ContactsFilter.all when searching => KeyedSubtree(
        key: const Key('contacts_no_results'),
        child: StateView.empty(
          title: l10n.contactsNotFound,
          subtitle: l10n.contactsNotFoundHint,
          icon: LucideIcons.userSearch,
          actionLabel: l10n.contactsClearSearch,
          onAction: onReset,
        ),
      ),
      ContactsFilter.all => StateView.empty(
        title: l10n.contactsEmpty,
        icon: LucideIcons.bookUser,
      ),
    };
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({super.key, required this.row, required this.height});
  final ContactHeaderRow row;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final icon = switch (row.icon) {
      'star' => LucideIcons.star,
      'clock' => LucideIcons.clock,
      _ => null,
    };
    return Container(
      height: height,
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: row.icon == 'star' ? t.warning : t.textTertiary,
            ),
            const SizedBox(width: Space.xs),
          ],
          Expanded(
            child: Text(
              row.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall?.copyWith(
                color: icon == null ? t.primary : t.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (row.count > 0)
            Text(
              '${row.count}',
              style: text.labelSmall?.copyWith(color: t.textTertiary),
            ),
        ],
      ),
    );
  }
}

/// Lazy list with fixed extents (so offsets are known without layout):
/// sticky section header overlay and the alphabet fast-scroll index.
class _ContactsList extends StatefulWidget {
  const _ContactsList({
    required this.rows,
    required this.favIds,
    required this.query,
    required this.showIndex,
    required this.onOpen,
    this.footer,
    this.selectedId,
    this.onContextMenu,
  });

  final ContactRows rows;
  final Set<String> favIds;
  final String query;
  final bool showIndex;
  final ValueChanged<Contact> onOpen;
  final String? footer;

  /// Desktop: the contact open in the right pane (its row is highlighted).
  final String? selectedId;

  /// Desktop: right click on a row, at the pointer.
  final void Function(Contact contact, Offset at)? onContextMenu;

  @override
  State<_ContactsList> createState() => _ContactsListState();
}

class _ContactsListState extends State<_ContactsList> {
  final _controller = ScrollController();
  String? _activeLetter;

  // Offsets cache: rebuilt only when rows or extents change.
  ContactRows? _forRows;
  double _forRow = 0, _forHeader = 0;
  List<double> _offsets = const [];
  List<int> _headers = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _layout(double rowExtent, double headerExtent) {
    if (identical(_forRows, widget.rows) &&
        _forRow == rowExtent &&
        _forHeader == headerExtent) {
      return;
    }
    final rows = widget.rows.rows;
    final offsets = List<double>.filled(rows.length, 0);
    final headers = <int>[];
    var y = 0.0;
    for (var i = 0; i < rows.length; i++) {
      offsets[i] = y;
      if (rows[i] is ContactHeaderRow) {
        headers.add(i);
        y += headerExtent;
      } else {
        y += rowExtent;
      }
    }
    _forRows = widget.rows;
    _forRow = rowExtent;
    _forHeader = headerExtent;
    _offsets = offsets;
    _headers = headers;
  }

  void _jump(String letter) {
    final i = widget.rows.index[letter];
    if (i == null || !_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    _controller.jumpTo(math.min(_offsets[i], max));
    if (_activeLetter != letter) setState(() => _activeLetter = letter);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final (rowExtent, headerExtent) = _contactExtents(context);
    _layout(rowExtent, headerExtent);
    final rows = widget.rows.rows;
    final letters = widget.rows.index.keys.toList();
    final index = widget.showIndex && letters.length > 1;
    const footerExtent = 64.0;

    final list = ListView.builder(
      key: const Key('contacts_list'),
      controller: _controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(right: index ? Space.md : 0),
      itemCount: rows.length + (widget.footer == null ? 0 : 1),
      itemExtentBuilder: (i, _) {
        if (i >= rows.length) return footerExtent;
        return rows[i] is ContactHeaderRow ? headerExtent : rowExtent;
      },
      itemBuilder: (context, i) {
        if (i >= rows.length) {
          return Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Text(
              widget.footer!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: t.textMuted,
              ),
            ),
          );
        }
        return switch (rows[i]) {
          final ContactHeaderRow row => _SectionHeader(
            key: row.icon == null
                ? ValueKey('contacts_section_${row.title}')
                : ValueKey('contacts_special_${row.icon}'),
            row: row,
            height: headerExtent,
          ),
          ContactItemRow(:final contact, :final section) => ContactTile(
            key: ValueKey(
              section.isEmpty
                  ? 'contact_${contact.id}'
                  : 'contact_${section}_${contact.id}',
            ),
            contact: contact,
            query: widget.query,
            favourite: widget.favIds.contains(contact.id),
            onTap: () => widget.onOpen(contact),
            selected: contact.id == widget.selectedId,
            onContextMenu: widget.onContextMenu == null ? null : (at) => widget.onContextMenu!(contact, at),
          ),
        };
      },
    );

    return Stack(
      children: [
        list,
        // Sticky header: the section the viewport top is in, pushed up by
        // the next header.
        Positioned(
          top: 0,
          left: 0,
          right: index ? Space.md : 0,
          height: headerExtent,
          // A copy of a section header already in the list: hidden from
          // screen readers.
          child: ExcludeSemantics(
            child: IgnorePointer(
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final off = _controller.hasClients
                      ? _controller.offset
                      : 0.0;
                  if (off <= 0 || _headers.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  var lo = 0, hi = _headers.length - 1, found = -1;
                  while (lo <= hi) {
                    final mid = (lo + hi) >> 1;
                    if (_offsets[_headers[mid]] <= off) {
                      found = mid;
                      lo = mid + 1;
                    } else {
                      hi = mid - 1;
                    }
                  }
                  if (found < 0) return const SizedBox.shrink();
                  final header = rows[_headers[found]] as ContactHeaderRow;
                  var dy = 0.0;
                  if (found + 1 < _headers.length) {
                    final next = _offsets[_headers[found + 1]];
                    dy = math.min(0, next - off - headerExtent);
                  }
                  return Transform.translate(
                    offset: Offset(0, dy),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: t.divider,
                            width: t.borderWidth,
                          ),
                        ),
                      ),
                      child: _SectionHeader(
                        key: const Key('contacts_sticky_header'),
                        row: header,
                        height: headerExtent,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          ),
        ),
        if (index)
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: 24,
            child: _AlphabetIndex(
              letters: letters,
              onSelect: _jump,
              onEnd: () => setState(() => _activeLetter = null),
            ),
          ),
        if (index && _activeLetter != null)
          Center(
            child: ExcludeSemantics(
              child: IgnorePointer(
              child: Container(
                key: const Key('contacts_index_bubble'),
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.primary,
                  borderRadius: BorderRadius.circular(t.radiusLg),
                  boxShadow: t.shadowMd,
                ),
                child: Text(
                  _activeLetter!,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: t.textInverse,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            ),
          ),
      ],
    );
  }
}

/// Vertical strip of section letters on the right edge; tap or drag jumps.
/// When the letters do not fit, every n-th is drawn but the drag still maps
/// over all of them.
class _AlphabetIndex extends StatelessWidget {
  const _AlphabetIndex({
    required this.letters,
    required this.onSelect,
    required this.onEnd,
  });

  final List<String> letters;
  final ValueChanged<String> onSelect;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Pointer-only fast scroll: screen-reader users have the search field and
    // the list (a semantics tap here could only jump to the first letter).
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxHeight - Space.md * 2;
          if (available <= 0) return const SizedBox.shrink();
          final n = letters.length;
          final slot = math.min(16.0, available / n);
          final step = slot >= 11 ? 1 : (11 / slot).ceil();
          final height = slot * n;
          void pick(double dy) {
            final i = (dy / height * n).floor().clamp(0, n - 1);
            onSelect(letters[i]);
          }

          return Center(
            child: GestureDetector(
              key: const Key('contacts_alphabet_index'),
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => pick(d.localPosition.dy),
              onTapUp: (_) => onEnd(),
              onTapCancel: onEnd,
              onVerticalDragStart: (d) => pick(d.localPosition.dy),
              onVerticalDragUpdate: (d) => pick(d.localPosition.dy),
              onVerticalDragEnd: (_) => onEnd(),
              onVerticalDragCancel: onEnd,
              child: SizedBox(
                width: 24,
                height: height,
                child: Column(
                  children: [
                    for (var i = 0; i < n; i += step)
                      SizedBox(
                        height: slot * math.min(step, n - i),
                        child: Center(
                          child: Text(
                            letters[i],
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(
                              fontSize: math
                                  .min(11, slot * 0.8)
                                  .clamp(8, 11)
                                  .toDouble(),
                              fontWeight: FontWeight.w700,
                              color: t.primary,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Department picker: all departments (archived hidden) with head counts.
class _DepartmentSheet extends ConsumerWidget {
  const _DepartmentSheet({required this.selected});
  final String selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final async = ref.watch(contactsDepartmentsProvider);
    final list = (async.value ?? const <Department>[])
        .where((d) => !d.isArchived || d.id == selected)
        .toList();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                0,
                Space.md,
                Space.sm,
              ),
              child: Text(
                l10n.contactsDepartmentsTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: async.isLoading && list.isEmpty
                  ? const SizedBox(height: 160, child: StateView.loading())
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        _DepartmentOption(
                          key: const Key('contacts_department_all'),
                          title: l10n.contactsAllDepartments,
                          selected: selected.isEmpty,
                          onTap: () => Navigator.pop(context, ''),
                        ),
                        if (list.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(Space.md),
                            child: Text(
                              l10n.contactsDepartmentsEmpty,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: t.textTertiary),
                            ),
                          ),
                        for (final d in list)
                          _DepartmentOption(
                            key: ValueKey('contacts_department_${d.id}'),
                            title: d.name,
                            subtitle: d.employeeCount > 0
                                ? l10n.contactsEmployeeCount(d.employeeCount)
                                : null,
                            selected: d.id == selected,
                            onTap: () => Navigator.pop(context, d.id),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepartmentOption extends StatelessWidget {
  const _DepartmentOption({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListTile(
      onTap: onTap,
      selected: selected,
      selectedTileColor: t.surfaceSelected,
      leading: Icon(LucideIcons.building2, color: t.textSecondary),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: selected ? Icon(LucideIcons.check, color: t.primary) : null,
    );
  }
}
