import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/localization/localization.dart';
import '../../../core/network/network_status.dart';
import '../../../core/platform/launcher_requests.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/widgets/state_view.dart';
import '../../calendar/data/calendar_models.dart';
import '../../calendar/presentation/calendar_widgets.dart';
import '../../chat/data/chat_models.dart';
import '../../chat/presentation/chat_avatar.dart';
import '../../chat/presentation/chat_formatters.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../contacts/data/contact_models.dart';
import '../../contacts/presentation/contact_widgets.dart';
import '../../mail/data/mail_models.dart';
import 'search_providers.dart';

/// «Единый поиск»: one field, searched in parallel across colleagues, chats
/// (titles + server message search), mail (Inbox server search) and calendar
/// events (cached months). Each section shows a few hits and «Показать все»,
/// which opens the module's own search pre-filled. Offline, sections fall
/// back to caches and a hint says so.
class UnifiedSearchScreen extends ConsumerStatefulWidget {
  const UnifiedSearchScreen({super.key});

  static const debounce = Duration(milliseconds: 350);

  /// Hits shown per section before «Показать все».
  static const preview = 3;

  @override
  ConsumerState<UnifiedSearchScreen> createState() =>
      _UnifiedSearchScreenState();
}

class _UnifiedSearchScreenState extends ConsumerState<UnifiedSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Desktop: the query typed into the top bar's search field.
    final prefill = ref.read(unifiedSearchRequestProvider);
    if (prefill != null) {
      _controller.text = prefill;
      _query = prefill.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(unifiedSearchRequestProvider.notifier).consume();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(UnifiedSearchScreen.debounce, () {
      if (mounted) setState(() => _query = v.trim());
    });
    setState(() {}); // clear button
  }

  void _setQuery(String q) {
    _debounce?.cancel();
    _controller.text = q;
    _controller.selection = TextSelection.collapsed(offset: q.length);
    setState(() => _query = q.trim());
  }

  void _remember() =>
      unawaited(ref.read(recentSearchesProvider.notifier).add(_query));

  void _showAll(SearchModule module) {
    _remember();
    final q = _query;
    switch (module) {
      case SearchModule.contacts:
        ref.read(contactsSearchRequestProvider.notifier).request(q);
        context.go(Routes.contacts);
      case SearchModule.chats:
        ref.read(chatSearchRequestProvider.notifier).request(q);
        context.go(Routes.chat);
      case SearchModule.mail:
        ref.read(mailSearchRequestProvider.notifier).request(q);
        context.go(Routes.mail);
      case SearchModule.calendar:
        context.push(Routes.calendarSearchPath(q));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    // A new top-bar search while this page is open.
    ref.listen<String?>(unifiedSearchRequestProvider, (_, q) {
      if (q == null) return;
      _setQuery(q);
      ref.read(unifiedSearchRequestProvider.notifier).consume();
    });
    final modules = ref.watch(searchModulesProvider);
    final active = _query.length >= searchMinLength;

    var offline = !ref.watch(isOnlineProvider);
    var pending = false;
    var anyHit = false;
    final sections = <Widget>[];
    if (active) {
      for (final m in modules) {
        final AsyncValue<SearchSection<Object?>> value = switch (m) {
          SearchModule.contacts => ref.watch(searchContactsProvider(_query)),
          SearchModule.chats => ref.watch(searchChatsProvider(_query)),
          SearchModule.mail => ref.watch(searchMailProvider(_query)),
          SearchModule.calendar => ref.watch(searchCalendarProvider(_query)),
        };
        final data = value.value;
        if (data != null && data.offline) offline = true;
        if (value.isLoading && data == null) pending = true;
        final tiles = data == null ? const <Widget>[] : _tiles(m, data.items);
        if (tiles.isNotEmpty) anyHit = true;
        if (tiles.isEmpty &&
            !(value.isLoading && data == null) &&
            !value.hasError) {
          continue;
        }
        sections.add(
          _Section(
            key: Key('search_section_${m.name}'),
            title: _title(l10n, m),
            loading: value.isLoading && data == null,
            error: value.hasError && data == null
                ? l10n.searchSectionError
                : null,
            onShowAll: tiles.isEmpty ? null : () => _showAll(m),
            moreKey: Key('search_more_${m.name}'),
            children: tiles,
          ),
        );
      }
    }

    final Widget body;
    if (!active) {
      body = _Recent(onPick: _setQuery);
    } else if (modules.isEmpty) {
      body = StateView.empty(
        title: l10n.searchNothingAvailable,
        icon: LucideIcons.searchX,
      );
    } else if (!pending && !anyHit && sections.isEmpty) {
      body = StateView.empty(
        title: l10n.searchEmpty,
        icon: LucideIcons.searchX,
      );
    } else {
      body = ListView(
        key: const Key('search_results'),
        padding: const EdgeInsets.only(bottom: Space.xl),
        children: sections,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const Key('unified_search_field'),
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (v) {
            _setQuery(v.trim());
            _remember();
          },
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            isDense: true,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              key: const Key('unified_search_clear'),
              tooltip: l10n.close,
              icon: const Icon(LucideIcons.x),
              onPressed: () => _setQuery(''),
            ),
        ],
      ),
      body: Column(
        children: [
          if (offline)
            Container(
              key: const Key('search_offline_hint'),
              width: double.infinity,
              color: t.warningSoft,
              padding: const EdgeInsets.symmetric(
                horizontal: Space.md,
                vertical: Space.sm,
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.cloudOff, size: 16, color: t.warning),
                  const SizedBox(width: Space.sm),
                  Expanded(child: Text(l10n.searchOfflineHint)),
                ],
              ),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }

  String _title(AppLocalizations l10n, SearchModule m) => switch (m) {
    SearchModule.contacts => l10n.searchSectionPeople,
    SearchModule.chats => l10n.searchSectionChats,
    SearchModule.mail => l10n.searchSectionMail,
    SearchModule.calendar => l10n.searchSectionEvents,
  };

  List<Widget> _tiles(SearchModule m, List<Object?> items) {
    const n = UnifiedSearchScreen.preview;
    switch (m) {
      case SearchModule.contacts:
        return [
          for (final c in items.whereType<Contact>().take(n))
            SizedBox(
              key: ValueKey('search_contact_${c.id}'),
              height: 64,
              child: ContactTile(
                contact: c,
                query: _query,
                onTap: () {
                  _remember();
                  context.push(Routes.contactProfilePath(c.id), extra: c);
                },
              ),
            ),
        ];
      case SearchModule.chats:
        final hits = items.whereType<ChatSearchHits>().firstOrNull;
        if (hits == null) return const [];
        return [
          for (final c in hits.conversations.take(n))
            ListTile(
              key: ValueKey('search_chat_${c.id}'),
              leading: ChatAvatar(conversation: c),
              title: Text(
                c.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                _remember();
                context.push(Routes.chatConversationPath(c.id));
              },
            ),
          for (final msg in hits.messages.take(n))
            _MessageHit(message: msg, onOpen: _remember),
        ];
      case SearchModule.mail:
        return [
          for (final mail in items.whereType<MailListItem>().take(n))
            _MailHit(item: mail, onOpen: _remember),
        ];
      case SearchModule.calendar:
        return [
          for (final o in items.whereType<CalendarOccurrence>().take(n))
            GestureDetector(
              key: ValueKey('search_event_${o.key}'),
              behavior: HitTestBehavior.translucent,
              onTapDown: (_) => _remember(),
              child: OccurrenceTile(occurrence: o, showDate: true),
            ),
        ];
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.title,
    required this.children,
    required this.moreKey,
    this.loading = false,
    this.error,
    this.onShowAll,
  });

  final String title;
  final List<Widget> children;
  final Key moreKey;
  final bool loading;
  final String? error;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.md,
            Space.md,
            Space.sm,
            Space.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    t.sectionLabel(title),
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: t.textTertiary, letterSpacing: 0.6),
                  ),
                ),
              ),
              if (onShowAll != null)
                TextButton(
                  key: moreKey,
                  onPressed: onShowAll,
                  child: Text(l10n.searchShowAll),
                ),
            ],
          ),
        ),
        if (loading) const LinearProgressIndicator(minHeight: 2),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.md,
              vertical: Space.xs,
            ),
            child: Text(error!, style: TextStyle(color: t.textSecondary)),
          ),
        ...children,
      ],
    );
  }
}

class _MessageHit extends ConsumerWidget {
  const _MessageHit({required this.message, required this.onOpen});
  final ChatMessage message;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final conv = ref.watch(
      conversationsProvider.select(
        (s) => s.items.where((c) => c.id == message.conversationId).firstOrNull,
      ),
    );
    return ListTile(
      key: ValueKey('search_message_${message.id}'),
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
      onTap: () {
        onOpen();
        ref
            .read(chatJumpRequestProvider.notifier)
            .request(message.conversationId, message.id);
        context.push(Routes.chatConversationPath(message.conversationId));
      },
    );
  }
}

class _MailHit extends StatelessWidget {
  const _MailHit({required this.item, required this.onOpen});
  final MailListItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final from = item.fromDisplay.isNotEmpty ? item.fromDisplay : item.from;
    return ListTile(
      key: ValueKey('search_mail_${item.id}'),
      leading: Icon(
        item.isRead ? LucideIcons.mailOpen : LucideIcons.mail,
        color: item.isRead ? t.textTertiary : t.primary,
      ),
      title: Text(
        item.subject.isEmpty ? context.l10n.searchNoSubject : item.subject,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: item.isRead ? FontWeight.w400 : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        [from, if (item.snippet.isNotEmpty) item.snippet].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: t.textSecondary),
      ),
      trailing: Text(
        FormatUtils.listDate(item.date, locale),
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: t.textTertiary),
      ),
      onTap: () {
        onOpen();
        context.push(Routes.mailMessagePath(item.id));
      },
    );
  }
}

class _Recent extends ConsumerWidget {
  const _Recent({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final recent = ref.watch(recentSearchesProvider);
    if (recent.isEmpty) {
      return StateView.empty(
        title: l10n.searchIntro,
        icon: LucideIcons.textSearch,
      );
    }
    final notifier = ref.read(recentSearchesProvider.notifier);
    return ListView(
      key: const Key('search_recent'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.md,
            Space.md,
            Space.sm,
            Space.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.sectionLabel(l10n.searchRecent),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: t.textTertiary, letterSpacing: 0.6),
                ),
              ),
              TextButton(
                key: const Key('search_recent_clear'),
                onPressed: () => unawaited(notifier.clear()),
                child: Text(l10n.searchRecentClear),
              ),
            ],
          ),
        ),
        for (final q in recent)
          ListTile(
            key: ValueKey('search_recent_$q'),
            leading: const Icon(LucideIcons.history),
            title: Text(q, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              tooltip: l10n.searchRecentRemove,
              icon: const Icon(LucideIcons.x, size: 18),
              onPressed: () => unawaited(notifier.remove(q)),
            ),
            onTap: () => onPick(q),
          ),
      ],
    );
  }
}
