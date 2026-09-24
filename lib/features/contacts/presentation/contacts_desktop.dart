import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/localization/localization.dart';
import '../../../core/platform/launcher_requests.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/error_text.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/state_view.dart';
import '../../chat/presentation/chat_formatters.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../mail/presentation/compose_screen.dart';
import '../../mail/presentation/compose_window.dart';
import '../data/contact_models.dart';
import '../data/personal_contacts.dart';
import 'contact_menu.dart';
import 'contact_profile_screen.dart';
import 'contact_widgets.dart';
import 'contacts_providers.dart';
import 'my_contacts_providers.dart';

enum _View { mine, all, online, department }

/// Desktop «Контакты»: on the left «Мои контакты», all colleagues, who is
/// online and the departments; in the middle the people of that view with
/// a star to pin a colleague to «Мои контакты»; on the right the open
/// profile. «Новый контакт» adds someone who is not in the directory.
class DesktopContactsScreen extends ConsumerStatefulWidget {
  const DesktopContactsScreen({super.key});

  @override
  ConsumerState<DesktopContactsScreen> createState() => _DesktopContactsScreenState();
}

class _DesktopContactsScreenState extends ConsumerState<DesktopContactsScreen> {
  static const _debounce = Duration(milliseconds: 350);

  /// Null until the user picks: «Мои контакты» when there are any.
  _View? _view;
  String _departmentId = '';
  final _search = TextEditingController();
  final _listScroll = ScrollController();
  Timer? _timer;
  String _query = '';

  /// Rows still below the fold when the next page is asked for.
  static const _prefetchExtent = 480.0;

  /// How many pages [_fillViewport] may pull in a row. A view that hides
  /// most of what it loads («Онлайн», a small department) would otherwise
  /// walk the whole directory by itself; past this the list waits for
  /// «Показать ещё».
  static const _autoFillPages = 4;

  int _autoFilled = 0;

  /// The open person: a directory [Contact] or a [PersonalContact] id.
  Contact? _employee;
  String? _personalId;

  @override
  void initState() {
    super.initState();
    _listScroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _listScroll.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Endless directory: the next page is fetched before the list runs out.
  /// «Мои контакты» is a local list and never pages.
  void _onScroll() {
    if (_effective == _View.mine || !_listScroll.hasClients) return;
    final position = _listScroll.position;
    if (position.pixels >= position.maxScrollExtent - _prefetchExtent) {
      unawaited(ref.read(contactsProvider.notifier).loadMore());
    }
  }

  /// A page that leaves the viewport unfilled (a narrow department, the
  /// «онлайн» filter) would never trigger [_onScroll], so the next one is
  /// asked for as soon as the list is laid out — up to [_autoFillPages].
  void _fillViewport() {
    if (_autoFilled >= _autoFillPages) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _effective == _View.mine || !_listScroll.hasClients) {
        return;
      }
      if (_listScroll.position.maxScrollExtent <= 0 &&
          ref.read(contactsProvider).canLoadMore) {
        _autoFilled++;
        unawaited(ref.read(contactsProvider.notifier).loadMore());
      }
    });
  }

  /// A new search, department or view starts the automatic filling over.
  void _resetAutoFill() => _autoFilled = 0;

  _View get _effective {
    if (_view != null) return _view!;
    final hasMine = ref.read(contactsFavouritesProvider).isNotEmpty || ref.read(personalContactsProvider).isNotEmpty;
    return hasMine ? _View.mine : _View.all;
  }

  /// Once the user works with the list, the view stays put (pinning the
  /// first colleague must not jump to «Мои контакты»).
  void _lockView() {
    if (_view == null) setState(() => _view = _effective);
  }

  void _select(_View view, {String departmentId = ''}) {
    _resetAutoFill();
    setState(() {
      _view = view;
      _departmentId = departmentId;
    });
    final notifier = ref.read(contactsProvider.notifier);
    unawaited(notifier.setDepartment(view == _View.department ? departmentId : ''));
  }

  void _onQuery(String q) {
    _resetAutoFill();
    setState(() => _query = q.trim());
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      if (mounted) unawaited(ref.read(contactsProvider.notifier).setQuery(q));
    });
  }

  void _openEmployee(Contact c) => setState(() {
    _employee = c;
    _personalId = null;
  });

  void _openPersonal(PersonalContact c) => setState(() {
    _personalId = c.id;
    _employee = null;
  });

  Future<void> _newContact() async {
    final saved = await showPersonalContactDialog(context);
    if (saved != null && mounted) {
      setState(() {
        _view = _View.mine;
        _personalId = saved.id;
        _employee = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // «Показать все» of the unified search: the field pre-filled.
    if (ref.watch(contactsSearchRequestProvider) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final q = ref.read(contactsSearchRequestProvider);
        if (!mounted || q == null) return;
        ref.read(contactsSearchRequestProvider.notifier).consume();
        _search.text = q;
        setState(() {
          _view = _View.all;
          _query = q.trim();
        });
        unawaited(ref.read(contactsProvider.notifier).setQuery(q));
      });
    }
    if (!ref.watch(chatEnabledProvider)) {
      return Scaffold(
        body: StateView.empty(title: context.l10n.contactsChatDisabled, icon: LucideIcons.bookUser),
      );
    }
    final personalId = _personalId;
    final personal = personalId == null
        ? null
        : ref.watch(personalContactsProvider).where((c) => c.id == personalId).firstOrNull;
    final employee = _employee;
    final Widget detail;
    if (employee != null) {
      detail = ContactProfileScreen(key: ValueKey('pane_${employee.id}'), userId: employee.id, initial: employee);
    } else if (personal != null) {
      detail = _PersonalPane(
        key: ValueKey('personal_${personal.id}'),
        contact: personal,
        onDeleted: () => setState(() => _personalId = null),
      );
    } else {
      detail = _Placeholder(text: context.l10n.myContactsSelect);
    }
    final divider = VerticalDivider(width: t.borderWidth, thickness: t.borderWidth, color: t.border);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, box) {
          final detailWidth = (box.maxWidth * 0.38).clamp(340.0, 480.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 248, child: _nav(context)),
              divider,
              Expanded(
                child: Listener(onPointerDown: (_) => _lockView(), child: _list(context)),
              ),
              divider,
              SizedBox(width: detailWidth, child: detail),
            ],
          );
        },
      ),
    );
  }

  Widget _nav(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final view = _effective;
    final mineCount = ref.watch(contactsFavouritesProvider).length + ref.watch(personalContactsProvider).length;
    final departments = ref.watch(contactsDepartmentsProvider).value ?? const <Department>[];
    return Material(
      color: t.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.sm),
            child: Text(
              t.pageTitle(l10n.contactsTitle),
              style: TextStyle(fontFamily: t.fontDisplay, fontSize: 20, fontWeight: FontWeight.w700, color: t.textPrimary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.smd),
            child: FilledButton.icon(
              key: const Key('contacts_new'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(40)),
              onPressed: _newContact,
              icon: const Icon(LucideIcons.userPlus, size: 16),
              label: Text(l10n.myContactsNew),
            ),
          ),
          _NavItem(
            key: const Key('contacts_view_mine'),
            icon: LucideIcons.star,
            iconColor: t.warning,
            label: l10n.myContactsTitle,
            count: mineCount,
            selected: view == _View.mine,
            onTap: () => _select(_View.mine),
          ),
          _NavItem(
            key: const Key('contacts_view_all'),
            icon: LucideIcons.users,
            label: l10n.myContactsAllStaff,
            selected: view == _View.all,
            onTap: () => _select(_View.all),
          ),
          _NavItem(
            key: const Key('contacts_view_online'),
            icon: LucideIcons.circleDot,
            iconColor: t.success,
            label: l10n.contactsFilterOnline,
            selected: view == _View.online,
            onTap: () => _select(_View.online),
          ),
          if (departments.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xs),
              child: Text(
                t.sectionLabel(l10n.myContactsDepartments),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: t.textTertiary),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: Space.md),
                children: [
                  for (final d in departments)
                    _NavItem(
                      key: ValueKey('contacts_department_${d.id}'),
                      icon: LucideIcons.building2,
                      label: d.name,
                      selected: view == _View.department && _departmentId == d.id,
                      onTap: () => _select(_View.department, departmentId: d.id),
                    ),
                ],
              ),
            ),
          ] else
            const Spacer(),
        ],
      ),
    );
  }

  Widget _list(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final view = _effective;
    final selfId = ref.watch(currentUserProvider)?.id;
    final state = ref.watch(contactsProvider);
    final favourites = ref.watch(contactsFavouritesProvider);
    final favIds = ref.watch(contactsFavouriteIdsProvider);
    final personal = ref.watch(personalContactsProvider);
    final byId = {for (final c in state.contacts) c.id: c};

    final String title;
    final List<Widget> rows = [];
    var count = 0;
    Widget person(Contact c) => _PersonRow(
      key: ValueKey('contact_row_${c.id}'),
      contact: c,
      pinned: favIds.contains(c.id),
      selected: _employee?.id == c.id,
      query: _query,
      onTap: () => _openEmployee(c),
    );

    if (view == _View.mine) {
      title = l10n.myContactsTitle;
      final staff = [
        for (final f in favourites)
          if (f.id != selfId) byId[f.id] ?? f,
      ].where((c) => c.matches(_query)).toList()
        ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
      final own = personal.where((c) => c.matches(_query)).toList();
      count = staff.length + own.length;
      if (staff.isNotEmpty) {
        rows.add(_Header(text: l10n.myContactsSectionStaff, count: staff.length));
        rows.addAll(staff.map(person));
      }
      if (own.isNotEmpty) {
        rows.add(_Header(text: l10n.myContactsSectionPersonal, count: own.length));
        rows.addAll(
          own.map(
            (c) => _PersonalRow(
              key: ValueKey('personal_row_${c.id}'),
              contact: c,
              selected: _personalId == c.id,
              query: _query,
              onTap: () => _openPersonal(c),
            ),
          ),
        );
      }
    } else {
      final dept = view == _View.department ? ref.watch(contactsDepartmentProvider(_departmentId)) : null;
      title = switch (view) {
        _View.online => l10n.contactsFilterOnline,
        _View.department => dept?.name ?? l10n.myContactsDepartments,
        _ => l10n.myContactsAllStaff,
      };
      final list = [
        for (final c in state.contacts)
          if (c.id != selfId && (view != _View.online || c.online)) c,
      ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
      count = list.length;
      rows.addAll(list.map(person));
    }

    final Widget content;
    final directory = view != _View.mine;
    if (directory && !state.loaded && state.contacts.isEmpty) {
      content = const StateView.loading();
    } else if (directory && state.contacts.isEmpty && state.error != null) {
      final notifier = ref.read(contactsProvider.notifier);
      content = ErrorText.isOffline(state.error)
          ? StateView.offline(message: ErrorText.describe(l10n, state.error!), onRetry: notifier.refresh)
          : StateView.error(message: ChatFormat.error(l10n, state.error!), onRetry: notifier.refresh);
    } else if (rows.isEmpty) {
      content = view == _View.mine && _query.isEmpty
          ? _MineEmpty(onBrowse: () => _select(_View.all), onNew: _newContact)
          : _Placeholder(text: l10n.myContactsNothingFound, icon: LucideIcons.searchX);
    } else {
      if (directory) {
        if (state.loadingMore) {
          rows.add(const _LoadingMoreRow());
        } else if (state.hasMore && _autoFilled >= _autoFillPages) {
          rows.add(
            _LoadMoreRow(
              onPressed: () {
                _resetAutoFill();
                unawaited(ref.read(contactsProvider.notifier).loadMore());
              },
            ),
          );
        }
        _fillViewport();
      }
      content = ListView(
        controller: _listScroll,
        padding: const EdgeInsets.only(bottom: Space.lg),
        children: rows,
      );
    }

    return Material(
      color: t.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.sm, Space.sm),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('contacts_search'),
                    controller: _search,
                    onChanged: _onQuery,
                    decoration: InputDecoration(
                      hintText: l10n.contactsSearchHint,
                      prefixIcon: const Icon(LucideIcons.search, size: 16),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: l10n.contactsClearSearch,
                              icon: const Icon(LucideIcons.x, size: 16),
                              onPressed: () {
                                _search.clear();
                                _onQuery('');
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: Space.xs),
                IconButton(
                  key: const Key('contacts_refresh'),
                  tooltip: l10n.desktopRefresh,
                  icon: const Icon(LucideIcons.refreshCw),
                  onPressed: () {
                    ref.invalidate(contactsDepartmentsProvider);
                    unawaited(ref.read(contactsProvider.notifier).refresh());
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.sm),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(fontFamily: t.fontDisplay, fontSize: 16, fontWeight: FontWeight.w700, color: t.textPrimary),
                ),
                const SizedBox(width: Space.sm),
                Text(
                  directory && state.hasMore ? '$count+' : '$count',
                  style: TextStyle(fontSize: 13, color: t.textTertiary, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (directory && state.loading && state.contacts.isNotEmpty)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
          Divider(height: 1, color: t.divider),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.iconColor,
    this.count,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? iconColor;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 1),
      child: Material(
        color: selected ? t.surfaceSelected : Colors.transparent,
        borderRadius: BorderRadius.circular(t.navRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(t.navRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.smd, vertical: 9),
            child: Row(
              children: [
                Icon(icon, size: 16, color: iconColor ?? (selected ? t.primary : t.textSecondary)),
                const SizedBox(width: Space.smd),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? t.textPrimary : t.textSecondary,
                    ),
                  ),
                ),
                if (count != null && count! > 0)
                  Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.textTertiary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.text, required this.count});

  final String text;
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xs),
      child: Text(
        '${t.sectionLabel(text)} · $count',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: t.textTertiary),
      ),
    );
  }
}

/// A colleague: avatar, name, position · department; the star pins him to
/// «Мои контакты»; on hover «Написать» and «Письмо»; right click the menu.
class _PersonRow extends ConsumerStatefulWidget {
  const _PersonRow({
    super.key,
    required this.contact,
    required this.pinned,
    required this.selected,
    required this.query,
    required this.onTap,
  });

  final Contact contact;
  final bool pinned;
  final bool selected;
  final String query;
  final VoidCallback onTap;

  @override
  ConsumerState<_PersonRow> createState() => _PersonRowState();
}

class _PersonRowState extends ConsumerState<_PersonRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final c = widget.contact;
    final details = [c.position, c.department].where((s) => s.isNotEmpty).join(' · ');
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onSecondaryTapUp: (d) => unawaited(showContactMenu(context, ref, c, d.globalPosition)),
        child: Material(
          color: widget.selected ? t.primarySoft : (_hover ? t.surfaceHover : Colors.transparent),
          child: InkWell(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.sm, Space.sm),
              child: Row(
                children: [
                  ContactAvatar(contact: c),
                  const SizedBox(width: Space.smd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HighlightText(
                          c.label,
                          query: widget.query,
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: t.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        HighlightText(
                          details.isNotEmpty ? details : c.mailAddress,
                          query: widget.query,
                          style: TextStyle(fontSize: 12.5, color: t.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  if (_hover) ...[
                    if (ref.watch(chatEnabledProvider))
                      _RowAction(
                        icon: LucideIcons.messageCircle,
                        tooltip: l10n.contactsWrite,
                        onTap: () => unawaited(runContactAction(context, ref, c, 'chat')),
                      ),
                    if (c.mailAddress.isNotEmpty)
                      _RowAction(
                        icon: LucideIcons.mail,
                        tooltip: l10n.contactsWriteEmail,
                        onTap: () => unawaited(runContactAction(context, ref, c, 'mail')),
                      ),
                  ],
                  _RowAction(
                    key: Key('contact_pin_${c.id}'),
                    icon: LucideIcons.star,
                    filled: widget.pinned,
                    color: widget.pinned || _hover ? t.warning : Colors.transparent,
                    tooltip: widget.pinned ? l10n.myContactsUnpin : l10n.myContactsPin,
                    onTap: () => unawaited(runContactAction(context, ref, c, 'pin')),
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

class _RowAction extends StatelessWidget {
  const _RowAction({super.key, required this.icon, required this.tooltip, required this.onTap, this.color, this.filled = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          // Lucide has no filled glyphs: a pinned star is Material's.
          child: filled
              ? Icon(Icons.star_rounded, size: 20, color: color ?? t.warning)
              : Icon(icon, size: 18, color: color ?? t.textSecondary),
        ),
      ),
    );
  }
}

/// A person added by hand: initials, name, details or email, a «Личный» tag.
class _PersonalRow extends StatelessWidget {
  const _PersonalRow({super.key, required this.contact, required this.selected, required this.query, required this.onTap});

  final PersonalContact contact;
  final bool selected;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final c = contact;
    return Material(
      color: selected ? t.primarySoft : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.sm),
          child: Row(
            children: [
              InitialsAvatar(label: c.name, colorKey: c.email.isNotEmpty ? c.email : c.id, radius: 20),
              const SizedBox(width: Space.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HighlightText(c.name, query: query, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: t.textPrimary)),
                    const SizedBox(height: 2),
                    HighlightText(
                      c.details.isNotEmpty ? c.details : (c.email.isNotEmpty ? c.email : c.phone),
                      query: query,
                      style: TextStyle(fontSize: 12.5, color: t.textTertiary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: t.labelPurple, borderRadius: BorderRadius.circular(999)),
                child: Text(l10n.myContactsPersonalTag, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.labelPurpleText)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Foot of the endless directory when it has stopped filling itself: the
/// view hides most of what it loads, so the next pages are asked for.
class _LoadMoreRow extends StatelessWidget {
  const _LoadMoreRow({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.sm),
    child: Center(
      child: TextButton(
        key: const Key('contacts_load_more'),
        onPressed: onPressed,
        child: Text(context.l10n.contactsLoadMore),
      ),
    ),
  );
}

/// Foot of the endless directory: the next page is on its way.
class _LoadingMoreRow extends StatelessWidget {
  const _LoadingMoreRow();

  @override
  Widget build(BuildContext context) => const Padding(
    key: Key('contacts_loading_more'),
    padding: EdgeInsets.symmetric(vertical: Space.md),
    child: Center(
      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
    ),
  );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.text, this.icon = LucideIcons.contactRound});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: t.surfaceSubtle,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.border),
                ),
                child: Icon(icon, size: 24, color: t.textTertiary),
              ),
              const SizedBox(height: Space.md),
              Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: t.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MineEmpty extends StatelessWidget {
  const _MineEmpty({required this.onBrowse, required this.onNew});

  final VoidCallback onBrowse;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: t.warningSoft, shape: BoxShape.circle),
                child: Icon(LucideIcons.star, size: 32, color: t.warning),
              ),
              const SizedBox(height: Space.md),
              Text(
                l10n.myContactsEmptyTitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: t.fontDisplay, fontSize: 17, fontWeight: FontWeight.w700, color: t.textPrimary),
              ),
              const SizedBox(height: Space.sm),
              Text(l10n.myContactsEmptyHint, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, height: 1.45, color: t.textSecondary)),
              const SizedBox(height: Space.lg),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    key: const Key('contacts_browse_staff'),
                    onPressed: onBrowse,
                    icon: const Icon(LucideIcons.users),
                    label: Text(l10n.myContactsBrowseStaff),
                  ),
                  FilledButton.icon(
                    onPressed: onNew,
                    icon: const Icon(LucideIcons.userPlus, size: 16),
                    label: Text(l10n.myContactsNew),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The open personal contact: a card with the ways to reach the person.
class _PersonalPane extends ConsumerWidget {
  const _PersonalPane({super.key, required this.contact, required this.onDeleted});

  final PersonalContact contact;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final c = contact;
    final messenger = ScaffoldMessenger.of(context);

    Future<void> delete() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.personalContactDelete),
          content: Text(l10n.personalContactDeleteConfirm(c.name)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            FilledButton(key: const Key('personal_delete_confirm'), onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.delete)),
          ],
        ),
      );
      if (ok != true) return;
      await ref.read(personalContactsProvider.notifier).remove(c.id);
      onDeleted();
      messenger.showSnackBar(SnackBar(content: Text(l10n.personalContactDeleted)));
    }

    Widget info(IconData icon, String label, String value, {VoidCallback? onCopy}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: t.textTertiary),
          const SizedBox(width: Space.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: t.textTertiary)),
                const SizedBox(height: 2),
                SelectableText(value, style: TextStyle(fontSize: 14, color: t.textPrimary)),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(tooltip: l10n.desktopContactCopyAddress, icon: const Icon(LucideIcons.copy, size: 16), onPressed: onCopy),
        ],
      ),
    );

    Future<void> copy(String value) async {
      await Clipboard.setData(ClipboardData(text: value));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.contactsCopied(value))));
    }

    return Material(
      color: t.surface,
      child: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          Center(child: InitialsAvatar(label: c.name, colorKey: c.email.isNotEmpty ? c.email : c.id, radius: 44)),
          const SizedBox(height: Space.md),
          Text(
            c.name,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: t.fontDisplay, fontSize: 20, fontWeight: FontWeight.w700, color: t.textPrimary),
          ),
          if (c.details.isNotEmpty) ...[
            const SizedBox(height: Space.xs),
            Text(c.details, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: t.textSecondary)),
          ],
          const SizedBox(height: Space.sm),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: t.labelPurple, borderRadius: BorderRadius.circular(999)),
              child: Text(l10n.myContactsPersonalTag, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.labelPurpleText)),
            ),
          ),
          const SizedBox(height: Space.lg),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              if (c.email.isNotEmpty)
                FilledButton.icon(
                  key: const Key('personal_write_email'),
                  onPressed: () => openCompose(ref, ComposeArgs.to([c.email])),
                  icon: const Icon(LucideIcons.mail, size: 16),
                  label: Text(l10n.contactsWriteEmail),
                ),
              if (c.phone.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => unawaited(launchUrl(Uri(scheme: 'tel', path: c.phone.replaceAll(RegExp(r'[^\d+]'), '')))),
                  icon: const Icon(LucideIcons.phone),
                  label: Text(l10n.personalContactCall),
                ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Divider(color: t.divider),
          if (c.email.isNotEmpty) info(LucideIcons.atSign, l10n.personalContactEmail, c.email, onCopy: () => unawaited(copy(c.email))),
          if (c.phone.isNotEmpty) info(LucideIcons.phone, l10n.personalContactPhone, c.phone, onCopy: () => unawaited(copy(c.phone))),
          if (c.organization.isNotEmpty) info(LucideIcons.building2, l10n.personalContactOrganization, c.organization),
          if (c.position.isNotEmpty) info(LucideIcons.briefcase, l10n.personalContactPosition, c.position),
          if (c.note.isNotEmpty) info(LucideIcons.stickyNote, l10n.personalContactNote, c.note),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('personal_edit'),
                  onPressed: () => unawaited(showPersonalContactDialog(context, existing: c)),
                  icon: const Icon(LucideIcons.pencil),
                  label: Text(l10n.personalContactEdit),
                ),
              ),
              const SizedBox(width: Space.sm),
              IconButton(
                key: const Key('personal_delete'),
                tooltip: l10n.personalContactDelete,
                icon: Icon(LucideIcons.trash2, color: t.danger),
                onPressed: () => unawaited(delete()),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(l10n.personalContactLocalNote, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: t.textTertiary)),
        ],
      ),
    );
  }
}

/// Phone: a personal contact in the «Мои» list (the desktop's row).
class PersonalContactTile extends StatelessWidget {
  const PersonalContactTile({super.key, required this.contact, required this.query, required this.onTap});

  final PersonalContact contact;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _PersonalRow(contact: contact, selected: false, query: query, onTap: onTap);
}

/// Phone: a personal contact's card as a page (the desktop's pane).
class PersonalContactPage extends StatelessWidget {
  const PersonalContactPage({super.key, required this.contact});

  final PersonalContact contact;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(contact.name)),
    body: _PersonalPane(
      key: ValueKey('personal_page_${contact.id}'),
      contact: contact,
      onDeleted: () => Navigator.of(context).maybePop(),
    ),
  );
}

/// «Новый контакт» / «Изменить контакт»: name (required), email, phone,
/// organization, position and a note. Resolves to the saved contact.
Future<PersonalContact?> showPersonalContactDialog(BuildContext context, {PersonalContact? existing}) =>
    showDialog<PersonalContact>(context: context, builder: (_) => _PersonalContactDialog(existing: existing));

class _PersonalContactDialog extends ConsumerStatefulWidget {
  const _PersonalContactDialog({this.existing});

  final PersonalContact? existing;

  @override
  ConsumerState<_PersonalContactDialog> createState() => _PersonalContactDialogState();
}

class _PersonalContactDialogState extends ConsumerState<_PersonalContactDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _email = TextEditingController(text: widget.existing?.email ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _organization = TextEditingController(text: widget.existing?.organization ?? '');
  late final _position = TextEditingController(text: widget.existing?.position ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _organization, _position, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final contact = PersonalContact(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      email: _email.text.trim().toLowerCase(),
      phone: _phone.text.trim(),
      organization: _organization.text.trim(),
      position: _position.text.trim(),
      note: _note.text.trim(),
    );
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    await ref.read(personalContactsProvider.notifier).save(contact);
    if (!mounted) return;
    Navigator.of(context).pop(contact);
    messenger.showSnackBar(SnackBar(content: Text(l10n.personalContactSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    InputDecoration deco(String label, IconData icon) => InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      prefixIcon: Icon(icon, size: 16),
    );
    return Dialog(
      insetPadding: const EdgeInsets.all(Space.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.enter, control: true): () => unawaited(_save())},
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(12)),
                        child: Icon(LucideIcons.userPlus, size: 20, color: t.primary),
                      ),
                      const SizedBox(width: Space.smd),
                      Expanded(
                        child: Text(
                          widget.existing == null ? l10n.myContactsNew : l10n.personalContactEdit,
                          style: TextStyle(fontFamily: t.fontDisplay, fontSize: 18, fontWeight: FontWeight.w700, color: t.textPrimary),
                        ),
                      ),
                      IconButton(tooltip: l10n.close, icon: const Icon(LucideIcons.x), onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                  const SizedBox(height: Space.lg),
                  TextFormField(
                    key: const Key('personal_name'),
                    controller: _name,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: deco(l10n.personalContactName, LucideIcons.user),
                    validator: (v) => (v ?? '').trim().isEmpty ? l10n.personalContactNameRequired : null,
                  ),
                  const SizedBox(height: Space.smd),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const Key('personal_email'),
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: deco(l10n.personalContactEmail, LucideIcons.atSign),
                          validator: (v) {
                            final text = (v ?? '').trim();
                            return text.isEmpty || _emailPattern.hasMatch(text) ? null : l10n.personalContactEmailInvalid;
                          },
                        ),
                      ),
                      const SizedBox(width: Space.smd),
                      Expanded(
                        child: TextFormField(
                          key: const Key('personal_phone'),
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: deco(l10n.personalContactPhone, LucideIcons.phone),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.smd),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _organization,
                          textInputAction: TextInputAction.next,
                          decoration: deco(l10n.personalContactOrganization, LucideIcons.building2),
                        ),
                      ),
                      const SizedBox(width: Space.smd),
                      Expanded(
                        child: TextFormField(
                          controller: _position,
                          textInputAction: TextInputAction.next,
                          decoration: deco(l10n.personalContactPosition, LucideIcons.briefcase),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.smd),
                  TextFormField(
                    controller: _note,
                    minLines: 2,
                    maxLines: 5,
                    decoration: deco(l10n.personalContactNote, LucideIcons.stickyNote).copyWith(alignLabelWithHint: true),
                  ),
                  const SizedBox(height: Space.md),
                  Row(
                    children: [
                      Icon(LucideIcons.monitor, size: 14, color: t.textTertiary),
                      const SizedBox(width: 6),
                      Expanded(child: Text(l10n.personalContactLocalNote, style: TextStyle(fontSize: 12, color: t.textTertiary))),
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
                      const SizedBox(width: Space.sm),
                      FilledButton(key: const Key('personal_save'), onPressed: () => unawaited(_save()), child: Text(l10n.save)),
                    ],
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
