import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/platform/desktop_layout.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../../shared/utils/error_text.dart';
import '../data/attachment_downloader.dart';
import '../data/mail_api.dart';
import '../data/mail_cache.dart';
import '../data/mail_models.dart';
import '../data/mail_prefs.dart';
import '../data/mail_repository.dart';
import '../data/mail_settings_models.dart';

// ---------------------------------------------------------------------------
// Wiring
// ---------------------------------------------------------------------------

final mailApiProvider = Provider<MailApi>(
  (ref) => MailApi(ref.watch(apiClientProvider)),
);

final mailCacheProvider = Provider<MailCache>(
  (ref) => MailCache(ref.watch(appDatabaseProvider)),
);

final mailRepositoryProvider = Provider<MailRepository>((ref) {
  final repo = MailRepository(
    api: ref.watch(mailApiProvider),
    cache: ref.watch(mailCacheProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

final attachmentDownloaderProvider = Provider<AttachmentDownloader>(
  (ref) => AttachmentDownloader(ref.watch(mailApiProvider)),
);

/// Attachment size limit from `GET /mail/client-config`; falls back to the
/// spec default so compose still works when the call fails.
final mailClientConfigProvider = FutureProvider<MailClientConfig>((ref) async {
  try {
    return await ref.watch(mailApiProvider).clientConfig();
  } on AppException catch (e) {
    DiagnosticLog.warn(
      'mail',
      'client-config unavailable, using default limit',
      error: e,
    );
    return const MailClientConfig(
      enabled: true,
      attachmentLimitBytes: MailClientConfig.defaultAttachmentLimitBytes,
    );
  }
});

// ---------------------------------------------------------------------------
// Folder summary (drawer + unread badge)
// ---------------------------------------------------------------------------

class MailSummaryState {
  const MailSummaryState({
    this.summary,
    this.loading = false,
    this.error,
    this.fromCache = false,
  });

  final MailSummary? summary;
  final bool loading;
  final Object? error;
  final bool fromCache;

  MailSummaryState copyWith({
    MailSummary? summary,
    bool? loading,
    Object? error,
    bool clearError = false,
    bool? fromCache,
  }) => MailSummaryState(
    summary: summary ?? this.summary,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    fromCache: fromCache ?? this.fromCache,
  );
}

class MailSummaryNotifier extends Notifier<MailSummaryState> {
  StreamSubscription<MailEvent>? _sub;

  @override
  MailSummaryState build() {
    final repo = ref.watch(mailRepositoryProvider);
    _sub?.cancel();
    _sub = repo.events.listen((e) {
      if (e is MailSummaryStale) refresh();
    });
    ref.onDispose(() => _sub?.cancel());
    // Respect x-required-permission: no mail.read → no request at all.
    if (!ref.watch(hasPermissionProvider(Permissions.mailRead))) {
      return const MailSummaryState();
    }
    // Folders made or renamed on the web show up when the app comes back
    // to the front (the phone has no periodic mail check).
    final lifecycle = AppLifecycleListener(onResume: () => unawaited(refresh()));
    ref.onDispose(lifecycle.dispose);
    Future.microtask(_initialLoad);
    return const MailSummaryState(loading: true);
  }

  Future<void> _initialLoad() async {
    final repo = ref.read(mailRepositoryProvider);
    final cached = await repo.cachedSummary();
    if (cached != null && !ref.mounted) return;
    if (cached != null) {
      state = MailSummaryState(summary: cached, loading: true, fromCache: true);
    }
    await refresh();
  }

  Future<void> refresh() async {
    final repo = ref.read(mailRepositoryProvider);
    state = state.copyWith(loading: true, clearError: true);
    try {
      final summary = await repo.fetchSummary();
      if (!ref.mounted) return;
      state = MailSummaryState(summary: summary);
    } on AppException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: e);
    }
  }
}

final mailSummaryProvider =
    NotifierProvider<MailSummaryNotifier, MailSummaryState>(
      MailSummaryNotifier.new,
    );

/// Badge for the "Почта" tab: unread mail in the Inbox (incl. smart folders).
final mailUnreadBadgeProvider = Provider<int>(
  (ref) => ref.watch(mailSummaryProvider).summary?.inboxUnreadTotal ?? 0,
);

// ---------------------------------------------------------------------------
// Current folder + filters
// ---------------------------------------------------------------------------

class SelectedFolderNotifier extends Notifier<String> {
  @override
  String build() => MailFolderType.inbox;

  void select(String folderType) {
    state = folderType;
    ref.read(mailFiltersProvider.notifier).reset();
  }
}

final selectedFolderProvider = NotifierProvider<SelectedFolderNotifier, String>(
  SelectedFolderNotifier.new,
);

class MailFilters {
  const MailFilters({
    this.q = '',
    this.unread = false,
    this.starred = false,
    this.attachments = false,
    this.sender,
  });
  final String q;
  final bool unread;
  final bool starred;
  final bool attachments;

  /// A smart folder opened for one of its senders (`?sender=` on the web);
  /// null shows the folder's per-sender overview instead.
  final String? sender;

  bool get isActive => q.trim().isNotEmpty || unread || starred || attachments;

  MailFilters copyWith({
    String? q,
    bool? unread,
    bool? starred,
    bool? attachments,
    String? sender,
    bool clearSender = false,
  }) => MailFilters(
    q: q ?? this.q,
    unread: unread ?? this.unread,
    starred: starred ?? this.starred,
    attachments: attachments ?? this.attachments,
    sender: clearSender ? null : (sender ?? this.sender),
  );
}

class MailFiltersNotifier extends Notifier<MailFilters> {
  @override
  MailFilters build() => const MailFilters();

  void setQuery(String q) => state = state.copyWith(q: q);
  void toggleUnread() => state = state.copyWith(unread: !state.unread);
  void toggleStarred() => state = state.copyWith(starred: !state.starred);
  void toggleAttachments() =>
      state = state.copyWith(attachments: !state.attachments);
  void setSender(String? sender) => state = sender == null ? state.copyWith(clearSender: true) : state.copyWith(sender: sender);
  void reset() => state = const MailFilters();
}

final mailFiltersProvider = NotifierProvider<MailFiltersNotifier, MailFilters>(
  MailFiltersNotifier.new,
);

// ---------------------------------------------------------------------------
// Conversation (threads) mode, persisted
// ---------------------------------------------------------------------------

final mailPrefsStoreProvider = Provider<MailPrefsStore>(
  (ref) => MailPrefsStore(ref.watch(appDatabaseProvider)),
);

/// `null` until the stored preference is read, so the list is requested
/// once, in the right mode.
class MailThreadsModeNotifier extends Notifier<bool?> {
  @override
  bool? build() {
    Future.microtask(_load);
    return null;
  }

  Future<void> _load() async {
    bool value;
    // Desktop lists conversations by default (web `threads=1`); a saved
    // choice wins.
    final fallback = ref.read(desktopLayoutProvider);
    try {
      value = await ref.read(mailPrefsStoreProvider).readThreadsMode(fallback: fallback);
    } on Object catch (e) {
      DiagnosticLog.warn('mail', 'threads preference unreadable', error: e);
      value = fallback;
    }
    if (ref.mounted && state == null) state = value;
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    try {
      await ref.read(mailPrefsStoreProvider).writeThreadsMode(enabled);
    } on Object catch (e) {
      DiagnosticLog.warn('mail', 'threads preference not saved', error: e);
    }
  }
}

final mailThreadsModeProvider =
    NotifierProvider<MailThreadsModeNotifier, bool?>(
      MailThreadsModeNotifier.new,
    );

/// What the server appends on send; null when unavailable (silent).
final mailSignaturePreviewProvider =
    FutureProvider.autoDispose<MailSignaturePreview?>((ref) async {
      if (!ref.watch(hasPermissionProvider(Permissions.mailRead))) return null;
      try {
        return await ref.watch(mailApiProvider).signaturePreview();
      } on AppException catch (e) {
        DiagnosticLog.warn('mail', 'signature preview unavailable', error: e);
        return null;
      }
    });

/// The query the home screen is currently showing (offset excluded).
final currentMailQueryProvider = Provider<MailListQuery>((ref) {
  final folder = ref.watch(selectedFolderProvider);
  final f = ref.watch(mailFiltersProvider);
  final threads = ref.watch(mailThreadsModeProvider) ?? false;
  return MailListQuery(
    folder: folder,
    q: f.q.trim().isEmpty ? null : f.q.trim(),
    unread: f.unread,
    starred: f.starred,
    attachments: f.attachments,
    threads: threads && MailFolderType.supportsThreads(folder),
    sender: MailFolderType.isSmart(folder) ? f.sender : null,
  );
});

// ---------------------------------------------------------------------------
// Message list (one notifier per query)
// ---------------------------------------------------------------------------

enum MailListStatus { initial, loading, ready, error }

class MailListState {
  const MailListState({
    this.items = const [],
    this.total = 0,
    this.nextOffset,
    this.status = MailListStatus.initial,
    this.loadingMore = false,
    this.error,
    this.loadMoreError,
    this.fromCache = false,
  });

  final List<MailListItem> items;
  final int total;
  final int? nextOffset;
  final MailListStatus status;
  final bool loadingMore;
  final Object? error;
  final Object? loadMoreError;

  /// Data came from the local cache because the network failed.
  final bool fromCache;

  bool get hasMore => nextOffset != null;
  bool get isEmpty => status == MailListStatus.ready && items.isEmpty;

  MailListState copyWith({
    List<MailListItem>? items,
    int? total,
    int? nextOffset,
    bool clearNextOffset = false,
    MailListStatus? status,
    bool? loadingMore,
    Object? error,
    bool clearError = false,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
    bool? fromCache,
  }) => MailListState(
    items: items ?? this.items,
    total: total ?? this.total,
    nextOffset: clearNextOffset ? null : (nextOffset ?? this.nextOffset),
    status: status ?? this.status,
    loadingMore: loadingMore ?? this.loadingMore,
    error: clearError ? null : (error ?? this.error),
    loadMoreError: clearLoadMoreError
        ? null
        : (loadMoreError ?? this.loadMoreError),
    fromCache: fromCache ?? this.fromCache,
  );
}

class MailListNotifier extends Notifier<MailListState> {
  MailListNotifier(this.query);

  /// Base query; `offset` is managed here.
  final MailListQuery query;

  CancelToken? _cancel;
  StreamSubscription<MailEvent>? _sub;

  @override
  MailListState build() {
    final repo = ref.watch(mailRepositoryProvider);
    _sub?.cancel();
    _sub = repo.events.listen(_onEvent);
    ref.onDispose(() {
      _sub?.cancel();
      _cancel?.cancel();
    });
    Future.microtask(load);
    return const MailListState();
  }

  Future<void> load() async {
    final repo = ref.read(mailRepositoryProvider);
    state = state.copyWith(status: MailListStatus.loading, clearError: true);
    // Instant start from cache, then network.
    final cached = await repo.cachedFirstPage(query);
    if (!ref.mounted) return;
    if (cached != null && state.items.isEmpty) {
      state = state.copyWith(
        items: cached.items,
        total: cached.total,
        nextOffset: cached.nextOffset,
        fromCache: true,
      );
    }
    await _fetchFirstPage(repo);
  }

  Future<void> refresh() => _fetchFirstPage(ref.read(mailRepositoryProvider));

  Future<void> _fetchFirstPage(MailRepository repo) async {
    _cancel?.cancel();
    final token = _cancel = CancelToken();
    try {
      final page = await repo.fetchPage(
        query.copyWith(offset: 0),
        cancelToken: token,
      );
      if (!ref.mounted || token.isCancelled) return;
      state = MailListState(
        items: _dedupe(page.items),
        total: page.total,
        nextOffset: page.nextOffset,
        status: MailListStatus.ready,
      );
    } on CancelledException {
      // superseded
    } on AppException catch (e) {
      if (!ref.mounted || token.isCancelled) return;
      // No network: the search runs over the cached mail instead.
      if (ErrorText.isOffline(e) && (query.q?.trim().isNotEmpty ?? false)) {
        final hits = await repo.searchCached(query);
        if (!ref.mounted || token.isCancelled) return;
        if (hits.isNotEmpty) {
          state = MailListState(
            items: _dedupe(hits),
            total: hits.length,
            status: MailListStatus.ready,
            error: e,
            fromCache: true,
          );
          return;
        }
      }
      if (state.items.isNotEmpty) {
        // Keep showing cached rows; surface the error as a banner.
        state = state.copyWith(
          status: MailListStatus.ready,
          error: e,
          fromCache: true,
        );
      } else {
        state = state.copyWith(status: MailListStatus.error, error: e);
      }
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore ||
        !state.hasMore ||
        state.status != MailListStatus.ready) {
      return;
    }
    final repo = ref.read(mailRepositoryProvider);
    state = state.copyWith(loadingMore: true, clearLoadMoreError: true);
    try {
      final page = await repo.fetchPage(
        query.copyWith(offset: state.nextOffset!),
      );
      if (!ref.mounted) return;
      state = state.copyWith(
        items: _dedupe([...state.items, ...page.items]),
        total: page.total,
        nextOffset: page.nextOffset,
        clearNextOffset: page.nextOffset == null,
        loadingMore: false,
      );
    } on AppException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loadingMore: false, loadMoreError: e);
    }
  }

  /// Conversation mode can repeat a thread across page boundaries.
  List<MailListItem> _dedupe(List<MailListItem> items) {
    if (!query.threads) return items;
    final seen = <String>{};
    return items.where((i) => seen.add(i.threadId ?? i.id)).toList();
  }

  void _onEvent(MailEvent event) {
    switch (event) {
      case MailFlagsChanged(:final id, :final isRead, :final isStarred):
        var changed = false;
        final items = state.items.map((i) {
          if (i.id != id) return i;
          changed = true;
          return i.copyWith(isRead: isRead, isStarred: isStarred);
        }).toList();
        if (changed) state = state.copyWith(items: items);
      case MailMessageRemoved(:final id, :final movedTo):
        if (state.items.any((i) => i.id == id)) {
          state = state.copyWith(
            items: state.items.where((i) => i.id != id).toList(),
            total: state.total > 0 ? state.total - 1 : 0,
          );
        } else if (movedTo == query.folder) {
          // Mail moved into this folder (Undo after a delete or a move)
          // shows up without a manual refresh.
          unawaited(refresh());
        }
      case MailSummaryStale():
        break;
    }
  }
}

final mailListProvider = NotifierProvider.autoDispose
    .family<MailListNotifier, MailListState, MailListQuery>(
      MailListNotifier.new,
    );
