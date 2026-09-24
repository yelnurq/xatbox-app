import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/network/network_status.dart';
import '../../../core/preferences/app_preferences.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../../shared/utils/error_text.dart';
import '../../calendar/data/calendar_models.dart';
import '../../calendar/presentation/calendar_providers.dart';
import '../../chat/data/chat_models.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../contacts/data/contact_models.dart';
import '../../contacts/presentation/contacts_providers.dart';
import '../../mail/data/mail_models.dart';
import '../../mail/presentation/mail_providers.dart';
import '../data/recent_searches.dart';

/// Modules the unified search covers, in display order.
enum SearchModule { contacts, chats, mail, calendar }

/// Shortest query that is searched (as in the module searches).
const searchMinLength = 2;

/// One module's hits.
class SearchSection<T> {
  const SearchSection({this.items = const [], this.offline = false});
  final List<T> items;

  /// The network was unavailable: [items] come from local caches only.
  final bool offline;
}

/// Chat hits: conversation titles (local) and messages (server search).
class ChatSearchHits {
  const ChatSearchHits({
    this.conversations = const [],
    this.messages = const [],
  });
  final List<ChatConversation> conversations;
  final List<ChatMessage> messages;
  bool get isEmpty => conversations.isEmpty && messages.isEmpty;
}

/// Modules available to this user (chat service configured, permissions).
final searchModulesProvider = Provider<List<SearchModule>>((ref) {
  final chat = ref.watch(chatEnabledProvider);
  return [
    if (chat) SearchModule.contacts,
    if (chat) SearchModule.chats,
    if (ref.watch(hasPermissionProvider(Permissions.mailRead)))
      SearchModule.mail,
    if (ref.watch(calendarEnabledProvider)) SearchModule.calendar,
  ];
});

/// Colleagues: directory search (server, cached directory when offline).
final searchContactsProvider = FutureProvider.autoDispose
    .family<SearchSection<Contact>, String>((ref, q) async {
      final selfId = ref.read(currentUserProvider)?.id;
      try {
        final r = await ref.read(contactsRepositoryProvider).load(q);
        return SearchSection(
          items: [
            for (final c in r.contacts)
              if (c.id != selfId) c,
          ],
          offline: r.fromCache,
        );
      } on AppException catch (e) {
        if (!ErrorText.isOffline(e)) rethrow;
        return const SearchSection(offline: true);
      }
    });

/// Chats: titles over the live (or cached) list, messages via `GET /search`.
final searchChatsProvider = FutureProvider.autoDispose
    .family<SearchSection<ChatSearchHits>, String>((ref, q) async {
      final repo = ref.read(chatRepositoryProvider);
      final live = ref.read(conversationsProvider);
      final convs = live.loaded ? live.items : await repo.cachedConversations();
      final ql = q.toLowerCase();
      final titles = [
        for (final c in convs)
          if (!c.isSaved &&
              (c.title.toLowerCase().contains(ql) ||
                  (c.peer?.email.toLowerCase().contains(ql) ?? false)))
            c,
      ];
      var offline = !ref.read(isOnlineProvider);
      var messages = const <ChatMessage>[];
      if (!offline) {
        try {
          messages = [
            for (final m in await repo.search(q))
              if (!m.isDeleted) m,
          ];
        } on AppException catch (e) {
          if (ErrorText.isOffline(e)) {
            offline = true;
          } else {
            DiagnosticLog.warn(
              'search',
              'chat message search failed',
              error: e,
            );
          }
        }
      }
      return SearchSection(
        items: [ChatSearchHits(conversations: titles, messages: messages)],
        offline: offline,
      );
    });

bool _mailMatches(MailListItem m, String ql) =>
    m.subject.toLowerCase().contains(ql) ||
    m.fromDisplay.toLowerCase().contains(ql) ||
    m.from.toLowerCase().contains(ql) ||
    m.snippet.toLowerCase().contains(ql);

/// Mail: Inbox server search (`q` of `GET /mail/messages`); offline, the
/// cached first pages of Inbox and Sent.
final searchMailProvider = FutureProvider.autoDispose
    .family<SearchSection<MailListItem>, String>((ref, q) async {
      final repo = ref.read(mailRepositoryProvider);
      Future<SearchSection<MailListItem>> fromCache() async {
        final ql = q.toLowerCase();
        final seen = <String>{};
        final hits = <MailListItem>[];
        for (final folder in const [
          MailFolderType.inbox,
          MailFolderType.sent,
        ]) {
          final cached = await repo.cache.readList(folder);
          for (final m in cached?.items ?? const <MailListItem>[]) {
            if (_mailMatches(m, ql) && seen.add(m.id)) hits.add(m);
          }
        }
        return SearchSection(items: hits, offline: true);
      }

      if (!ref.read(isOnlineProvider)) return fromCache();
      final cancel = CancelToken();
      ref.onDispose(cancel.cancel);
      try {
        final page = await repo.fetchPage(
          MailListQuery(folder: MailFolderType.inbox, q: q, limit: 20),
          cancelToken: cancel,
        );
        return SearchSection(items: page.items);
      } on AppException catch (e) {
        if (!ErrorText.isOffline(e)) rethrow;
        return fromCache();
      }
    });

/// Calendar: cached month windows (the API has no search).
final searchCalendarProvider = FutureProvider.autoDispose
    .family<SearchSection<CalendarOccurrence>, String>((ref, q) async {
      final list = await ref
          .read(calendarRepositoryProvider)
          .search(q, device: ref.read(deviceLocationProvider));
      return SearchSection(items: list);
    });

// ---------------------------------------------------------------------------
// Recent queries
// ---------------------------------------------------------------------------

final recentSearchStoreProvider = Provider<RecentSearchStore>(
  (ref) => RecentSearchStore(ref.watch(appDatabaseProvider)),
);

/// Recent queries. With the app lock or «Скрывать содержимое» on they stay
/// in memory only (and what was stored before is removed), like the launcher
/// widgets that hide content in that case.
class RecentSearchesNotifier extends Notifier<List<String>> {
  bool get _hide {
    final p = ref.read(appPreferencesProvider);
    return p.lockEnabled || p.hideInSwitcher;
  }

  @override
  List<String> build() {
    final store = ref.watch(recentSearchStoreProvider);
    Future.microtask(() async {
      try {
        if (_hide) {
          await store.clear();
          return;
        }
        final saved = await store.read();
        if (ref.mounted && state.isEmpty) state = saved;
      } on Object catch (e) {
        DiagnosticLog.warn('search', 'recent queries unreadable', error: e);
      }
    });
    return const [];
  }

  Future<void> add(String query) async {
    if (query.trim().length < searchMinLength) return;
    state = RecentSearchStore.push(state, query);
    await _save();
  }

  Future<void> remove(String query) async {
    state = [
      for (final q in state)
        if (q != query) q,
    ];
    await _save();
  }

  Future<void> clear() async {
    state = const [];
    await _save();
  }

  Future<void> _save() async {
    try {
      final store = ref.read(recentSearchStoreProvider);
      if (_hide || state.isEmpty) {
        await store.clear();
      } else {
        await store.write(state);
      }
    } on Object catch (e) {
      DiagnosticLog.warn('search', 'recent queries not saved', error: e);
    }
  }
}

final recentSearchesProvider =
    NotifierProvider<RecentSearchesNotifier, List<String>>(
      RecentSearchesNotifier.new,
    );

/// Sign-out hook: recent queries belong to the signed-in user.
Future<void> searchSignOut(ProviderContainer container) =>
    container.read(recentSearchStoreProvider).clear();
