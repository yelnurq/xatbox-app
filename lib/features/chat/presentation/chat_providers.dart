import 'dart:async';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/lifecycle/app_visibility.dart';
import '../../../core/lifecycle/background_connection.dart';
import '../../../core/localization/localization.dart';
import '../../../core/network/network_status.dart';
import '../../../core/platform/open_file.dart';
import '../../../core/preferences/app_preferences.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/link_router.dart';
import '../../../core/routing/routes.dart';
import '../../../core/websocket/realtime_client.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../calls/data/call_push.dart';
import '../../calls/presentation/calls_providers.dart';
import '../data/chat_api.dart';
import '../data/chat_cache.dart';
import '../data/chat_models.dart';
import '../data/chat_push.dart';
import '../data/chat_repository.dart';
import '../data/desktop_notifications.dart';
import '../data/media_auto_download.dart';
import '../../settings/data/notification_preferences.dart';
import 'chat_formatters.dart';
import 'chat_share.dart';

// ---------------------------------------------------------------------------
// Wiring
// ---------------------------------------------------------------------------

final chatEnabledProvider = Provider<bool>(
  (ref) => ref.watch(appEnvProvider).chatEnabled,
);

/// Separate HTTP client for the Chat Service (own base URL, same token and
/// the same global 401 → sign-out behaviour as the Mail API).
final chatApiClientProvider = Provider<ApiClient>((ref) {
  final env = ref.watch(appEnvProvider);
  return ApiClient(
    baseUrl: env.chatBaseUrl,
    userAgent: ref.watch(userAgentProvider),
    tokenReader: () => ref.read(authSessionProvider).currentToken(),
    onUnauthenticated: () => ref.read(authSessionProvider).expire(),
  );
});

final chatApiProvider = Provider<ChatApi>(
  (ref) => ChatApi(ref.watch(chatApiClientProvider)),
);

final chatCacheProvider = Provider<ChatCache>(
  (ref) => ChatCache(ref.watch(appDatabaseProvider)),
);

final chatSocketProvider = Provider<RealtimeClient>((ref) {
  final env = ref.watch(appEnvProvider);
  final wsBase = env.chatBaseUrl.replaceFirst(RegExp(r'^http'), 'ws');
  final client = RealtimeClient(
    url: () => Uri.parse('$wsBase/ws'),
    tokenProvider: () async => ref.read(authSessionProvider).currentToken(),
    connector: WebSocketConnection.connect,
  );
  ref.onDispose(client.dispose);
  return client;
});

/// Parent directory of `chat_media` (overridden with a temp dir in tests).
final chatMediaRootProvider = Provider<Future<Directory> Function()>(
  (_) => getApplicationSupportDirectory,
);

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final repo = ChatRepository(
    api: ref.watch(chatApiProvider),
    cache: ref.watch(chatCacheProvider),
    socket: ref.watch(chatSocketProvider),
    selfId: () => ref.read(currentUserProvider)?.id ?? '',
    mediaRoot: ref.watch(chatMediaRootProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

/// A picked local file.
typedef ChatPickedFile = ({String path, String name});

/// Image picker for the group avatar (`file_picker`; faked in tests).
final chatImagePickerProvider = Provider<Future<ChatPickedFile?> Function()>(
  (_) => () async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    final f = files.firstOrNull;
    final path = f?.path;
    return f == null || path == null ? null : (path: path, name: f.name);
  },
);

/// Opens a downloaded file with the system viewer (`open_filex`); `false`
/// when no application can open it. Faked in tests.
final chatFileOpenerProvider =
    Provider<Future<bool> Function(String path, String mimeType)>(
      (_) => (path, mimeType) async {
        final res = await openLocalFile(path, mimeType: mimeType);
        return res != OpenFileOutcome.noApp;
      },
    );

final chatPushProvider = Provider<ChatPushService>((ref) {
  final service = ChatPushService(
    options: ref.watch(appEnvProvider).firebase,
    repo: ref.watch(chatRepositoryProvider),
    openConversation: (id, messageId) {
      if (messageId != null) {
        ref.read(chatJumpRequestProvider.notifier).request(id, messageId);
      }
      ref.read(chatOpenRequestProvider.notifier).request(id);
    },
    // `chat.comment`: the commented post's thread.
    openThread: (id, postId) => ref
        .read(pendingNavigationProvider.notifier)
        .request(Routes.chatCommentsPath(id, postId)),
    // call.* pushes: foreground data goes to the call controller; in
    // background the top-level handler shows the system call UI.
    onData: (data) {
      if (!isCallPush(data) || !ref.read(callsEnabledProvider)) return;
      unawaited(ref.read(callControllerProvider.notifier).onPushSignal(data));
    },
    // Other taps (calendar, mail…) open their screen once signed in.
    onTap: (data) {
      if (isCallPush(data)) return;
      final location = pushTapLocation(data);
      if (location != null) {
        ref.read(pendingNavigationProvider.notifier).request(location);
      }
    },
    backgroundHandler: xatboxBackgroundPush,
    // A registered token shortens the default background grace period.
    onRegistrationChanged: (registered) =>
        ref.read(pushRegisteredProvider.notifier).set(registered),
    // A push reached the running app: reconnect a suspended socket now.
    onMessage: () {
      if (ref.read(authStateProvider).status == AuthStatus.authenticated) {
        ref.read(chatBackgroundPolicyProvider).wake();
      }
    },
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Battery: the chat socket stays open for the «Оставаться на связи в фоне»
/// grace period after the app is hidden, then disconnects until the app
/// returns (or a push arrives). Never while a call is ringing or active.
/// Without push nothing can reach a disconnected app — see
/// backgroundGraceProvider for the defaults.
final chatBackgroundPolicyProvider = Provider<BackgroundConnectionPolicy>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  final callsEnabled = ref.watch(callsEnabledProvider);
  final policy = BackgroundConnectionPolicy(
    visibility: ref.watch(appVisibilityProvider),
    grace: () => ref.read(backgroundGraceProvider),
    busy: () => callsEnabled && ref.read(callControllerProvider).inCall,
    suspend: () {
      DiagnosticLog.info('ws', 'hidden past the grace period: disconnecting');
      unawaited(repo.stop());
    },
    resume: () {
      if (ref.read(authStateProvider).status != AuthStatus.authenticated) return;
      DiagnosticLog.info('ws', 'foreground again: reconnecting');
      repo.start();
    },
  );
  ref.listen<Duration?>(backgroundGraceProvider, (_, _) => policy.reevaluate());
  if (callsEnabled) {
    ref.listen<bool>(
      callControllerProvider.select((s) => s.inCall),
      (_, _) => policy.reevaluate(),
    );
  }
  policy.start();
  ref.onDispose(policy.dispose);
  return policy;
});

/// Conversation id requested by a push tap / deep link; the router listens.
final chatOpenRequestProvider = NotifierProvider<_OpenRequest, String?>(
  _OpenRequest.new,
);

class _OpenRequest extends Notifier<String?> {
  @override
  String? build() => null;
  void request(String? id) => state = id;
}

/// Desktop toasts for new messages (the phone gets FCM pushes instead).
final desktopChatNotifierProvider = Provider<DesktopChatNotifier>((ref) {
  AppLocalizations l10n() {
    final code =
        ref.read(appPreferencesProvider).languageCode ??
        Platform.localeName.split(RegExp('[_-]')).first;
    final supported = AppLocalization.supportedLocales.map((l) => l.languageCode);
    return lookupAppLocalizations(Locale(supported.contains(code) ? code : 'ru'));
  }

  final notifier = DesktopChatNotifier(
    repo: ref.watch(chatRepositoryProvider),
    conversation: (id) => ref
        .read(conversationsProvider)
        .items
        .where((c) => c.id == id)
        .firstOrNull,
    prefs: () => ref.read(notificationPreferencesProvider).prefs,
    preview: (m) => ChatFormat.preview(l10n(), m),
    texts: () {
      final t = l10n();
      return ChatToastTexts(replyHint: t.chatMessageHint, send: t.send, markRead: t.chatMarkRead);
    },
    // The conversation on screen: its own page, or the right pane of the
    // chat tab.
    isOpen: (id) {
      final path = ref.read(appRouterProvider).routerDelegate.currentConfiguration.uri.path;
      if (path.startsWith(Routes.chatConversationPath(id))) return true;
      return path == Routes.chat && ref.read(chatSelectedConversationProvider) == id;
    },
  );
  ref.onDispose(() => unawaited(notifier.dispose()));
  return notifier;
});

/// Keeps the socket alive while signed in and stops it on sign-out. Watched
/// once from the app root.
final chatLifecycleProvider = Provider<void>((ref) {
  if (!ref.watch(chatEnabledProvider)) return;
  // «Поделиться» from other apps: kept until signed in, then the picker opens.
  ref.watch(chatShareIntakeProvider);
  final status = ref.watch(authStateProvider).status;
  final repo = ref.watch(chatRepositoryProvider);
  if (status == AuthStatus.authenticated) {
    final policy = ref.watch(chatBackgroundPolicyProvider);
    if (!policy.suspended) repo.start();
    unawaited(ref.read(chatPushProvider).init());
    ref.read(desktopChatNotifierProvider).start();
    // No reconnect attempts while the device has no network at all; the
    // socket reconnects at once when it returns.
    ref.listen<bool>(
      isOnlineProvider,
      (_, online) => ref.read(chatSocketProvider).setNetworkAvailable(online),
      fireImmediately: true,
    );
  } else {
    unawaited(repo.stop());
  }
  // A 4401 close means the Mail/Auth session is gone.
  final sub = repo.socketCloses.listen((code) {
    if (code == 4401) ref.read(authSessionProvider).expire();
  });
  ref.onDispose(sub.cancel);
});

final chatConnectionProvider = StreamProvider<RealtimeStatus>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.connection;
});

final chatSyncingProvider = StreamProvider<bool>(
  (ref) => ref.watch(chatRepositoryProvider).syncing,
);

// ---------------------------------------------------------------------------
// Conversation list
// ---------------------------------------------------------------------------

class ConversationsState {
  const ConversationsState({
    this.items = const [],
    this.loading = false,
    this.error,
    this.fromCache = false,
    this.loaded = false,
  });
  final List<ChatConversation> items;
  final bool loading;
  final Object? error;
  final bool fromCache;
  final bool loaded;

  /// Unread messages of unmuted chats; a chat marked as unread counts once.
  int get unreadTotal => items
      .where((c) => !c.isMuted && !c.isSaved)
      .fold(
        0,
        (n, c) =>
            n + (c.unread > 0 ? c.unread : (c.settings.markedUnread ? 1 : 0)),
      );

  ConversationsState copyWith({
    List<ChatConversation>? items,
    bool? loading,
    Object? error,
    bool clearError = false,
    bool? fromCache,
    bool? loaded,
  }) => ConversationsState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    fromCache: fromCache ?? this.fromCache,
    loaded: loaded ?? this.loaded,
  );
}

class ConversationsNotifier extends Notifier<ConversationsState> {
  StreamSubscription<ChatEvent>? _sub;
  Timer? _reload;

  /// Bursts of events re-read the (in-memory) cache once per frame.
  static const coalesce = Duration(milliseconds: 16);

  @override
  ConversationsState build() {
    final repo = ref.watch(chatRepositoryProvider);
    _sub?.cancel();
    _sub = repo.events.listen((ev) {
      // Typing, recording and call frames do not change the list.
      if (ChatRepository.isEphemeral(ev.type)) return;
      _reload ??= Timer(coalesce, () {
        _reload = null;
        unawaited(_reloadFromCache());
      });
    });
    ref.onDispose(() {
      _sub?.cancel();
      _reload?.cancel();
      _reload = null;
    });
    Future.microtask(_initial);
    return const ConversationsState(loading: true);
  }

  Future<void> _initial() async {
    final repo = ref.read(chatRepositoryProvider);
    final cached = await repo.cachedConversations();
    if (!ref.mounted) return;
    if (cached.isNotEmpty) {
      state = state.copyWith(items: cached, fromCache: true, loaded: true);
    }
    await refresh();
  }

  Future<void> _reloadFromCache() async {
    final items = await ref.read(chatRepositoryProvider).cachedConversations();
    if (!ref.mounted) return;
    // The cache keeps unchanged conversations as the same objects: skip
    // rebuilding the list when nothing moved.
    final same =
        state.loaded &&
        items.length == state.items.length &&
        Iterable<int>.generate(
          items.length,
        ).every((i) => identical(items[i], state.items[i]));
    if (!same) state = state.copyWith(items: items, loaded: true);
  }

  Future<void> refresh() async {
    final repo = ref.read(chatRepositoryProvider);
    state = state.copyWith(loading: true, clearError: true);
    try {
      final items = await repo.loadConversations();
      if (!ref.mounted) return;
      state = ConversationsState(items: items, loaded: true);
    } on AppException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        error: e,
        fromCache: state.items.isNotEmpty,
        loaded: true,
      );
    }
  }
}

final conversationsProvider =
    NotifierProvider<ConversationsNotifier, ConversationsState>(
      ConversationsNotifier.new,
    );

/// Badge for the "Чат" tab: unread messages across unmuted chats.
final chatUnreadBadgeProvider = Provider<int>((ref) {
  if (!ref.watch(chatEnabledProvider)) return 0;
  if (ref.watch(authStateProvider).status != AuthStatus.authenticated) return 0;
  return ref.watch(conversationsProvider).unreadTotal;
});

/// Someone typing or recording in a chat (for list tiles).
@immutable
class ChatActivity {
  const ChatActivity(this.name, {this.recording = false});
  final String name;
  final bool recording;
}

/// conversation id → user id → activity, fed by `typing.*` /
/// `voice_recording.*` frames; entries expire after 6 s or on a message.
class ChatActivityNotifier
    extends Notifier<Map<String, Map<String, ChatActivity>>> {
  final Map<String, Timer> _timers = {};

  @override
  Map<String, Map<String, ChatActivity>> build() {
    final repo = ref.watch(chatRepositoryProvider);
    final sub = repo.events.listen((ev) => _on(ev, repo.selfId));
    ref.onDispose(() {
      sub.cancel();
      for (final t in _timers.values) {
        t.cancel();
      }
      _timers.clear();
    });
    return const {};
  }

  void _on(ChatEvent ev, String selfId) {
    final conv = ev.conversationId;
    if (conv.isEmpty) return;
    if (ev.type == 'message.created') {
      final sender = ev.message?.senderId;
      if (sender != null) _remove(conv, sender);
      return;
    }
    final typing = ev.type.startsWith('typing.');
    final recording = ev.type.startsWith('voice_recording.');
    if (!typing && !recording) return;
    final uid = ev.userId;
    if (uid.isEmpty || uid == selfId) return;
    if (!ev.type.endsWith('started')) {
      _remove(conv, uid);
      return;
    }
    final key = '$conv:$uid';
    _timers.remove(key)?.cancel();
    _timers[key] = Timer(const Duration(seconds: 6), () => _remove(conv, uid));
    state = {
      ...state,
      conv: {
        ...?state[conv],
        uid: ChatActivity(
          (ev.payload['display_name'] as String?) ?? '',
          recording: recording,
        ),
      },
    };
  }

  void _remove(String conv, String uid) {
    _timers.remove('$conv:$uid')?.cancel();
    final current = state[conv];
    if (current == null || !current.containsKey(uid)) return;
    final users = Map.of(current)..remove(uid);
    final next = Map.of(state);
    if (users.isEmpty) {
      next.remove(conv);
    } else {
      next[conv] = users;
    }
    state = next;
  }
}

final chatActivityProvider =
    NotifierProvider<
      ChatActivityNotifier,
      Map<String, Map<String, ChatActivity>>
    >(ChatActivityNotifier.new);

/// Composer drafts per conversation, persisted in the chat cache.
class ChatDraftsNotifier extends Notifier<Map<String, String>> {
  bool _loaded = false;

  @override
  Map<String, String> build() {
    final repo = ref.watch(chatRepositoryProvider);
    Future.microtask(() async {
      final stored = await repo.drafts();
      if (!ref.mounted) return;
      _loaded = true;
      // Drafts typed before the load finished win over stored ones.
      state = {...stored, ...state};
    });
    return const {};
  }

  bool get loaded => _loaded;

  Future<void> save(String conversationId, String text) async {
    final trimmed = text.trim();
    final current = state[conversationId] ?? '';
    if (current == text || (trimmed.isEmpty && current.isEmpty)) return;
    final next = Map.of(state);
    if (trimmed.isEmpty) {
      next.remove(conversationId);
    } else {
      next[conversationId] = text;
    }
    state = next;
    await ref.read(chatRepositoryProvider).setDraft(conversationId, text);
  }
}

final chatDraftsProvider =
    NotifierProvider<ChatDraftsNotifier, Map<String, String>>(
      ChatDraftsNotifier.new,
    );

/// Loads archived chats into the cache (the list screen filters them).
final chatArchivedLoadProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  final list = await repo.loadArchived();
  await ref.read(conversationsProvider.notifier)._reloadFromCache();
  return list.length;
});

// ---------------------------------------------------------------------------
// One conversation
// ---------------------------------------------------------------------------

class ConversationState {
  const ConversationState({
    this.conversation,
    this.messages = const [],
    this.loading = true,
    this.loadingOlder = false,
    this.hasMore = true,
    this.error,
    this.typing = const {},
    this.recording = const {},
  });
  final ChatConversation? conversation;

  /// Ascending by seq; pending outbox items at the end.
  final List<ChatMessage> messages;
  final bool loading;
  final bool loadingOlder;
  final bool hasMore;
  final Object? error;
  final Map<String, String> typing; // userId → display name
  final Map<String, String> recording;

  ConversationState copyWith({
    ChatConversation? conversation,
    List<ChatMessage>? messages,
    bool? loading,
    bool? loadingOlder,
    bool? hasMore,
    Object? error,
    bool clearError = false,
    Map<String, String>? typing,
    Map<String, String>? recording,
  }) => ConversationState(
    conversation: conversation ?? this.conversation,
    messages: messages ?? this.messages,
    loading: loading ?? this.loading,
    loadingOlder: loadingOlder ?? this.loadingOlder,
    hasMore: hasMore ?? this.hasMore,
    error: clearError ? null : (error ?? this.error),
    typing: typing ?? this.typing,
    recording: recording ?? this.recording,
  );
}

class ConversationNotifier extends Notifier<ConversationState> {
  ConversationNotifier(this.conversationId);
  final String conversationId;

  StreamSubscription<ChatEvent>? _sub;
  final Map<String, Timer> _typingTimers = {};
  final List<ChatMessage> _older = []; // history pages beyond the cached tail
  Timer? _typingDebounce;
  Timer? _refresh;
  bool _refreshMessages = false;
  bool _typingSent = false;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  ConversationState build() {
    final repo = ref.watch(chatRepositoryProvider);
    _sub?.cancel();
    _sub = repo.events.listen(_onEvent);
    ref.onDispose(() {
      _sub?.cancel();
      for (final t in _typingTimers.values) {
        t.cancel();
      }
      _typingDebounce?.cancel();
      _refresh?.cancel();
      _refresh = null;
    });
    Future.microtask(load);
    return const ConversationState();
  }

  Future<void> load() async {
    // The screen may close while this awaits: after that `ref` is unusable,
    // so the repository is taken once, up front.
    if (!ref.mounted) return;
    final repo = _repo;
    final conv = await repo.conversation(conversationId);
    final cached = await repo.cachedMessages(conversationId);
    if (!ref.mounted) return;
    state = state.copyWith(
      conversation: conv,
      messages: _merge(cached),
      loading: cached.isEmpty && conv == null,
    );
    try {
      final latest = await repo.loadLatest(conversationId);
      final fresh = await repo.conversation(
        conversationId,
        refresh: conv == null,
      );
      final messages = await repo.cachedMessages(conversationId);
      if (!ref.mounted) return;
      state = state.copyWith(
        conversation: fresh ?? conv,
        messages: _merge(messages),
        loading: false,
        hasMore: latest.length >= 50,
        clearError: true,
      );
      if ((fresh ?? conv)?.settings.markedUnread ?? false) {
        unawaited(_clearMarkedUnread());
      }
    } on AppException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: e);
    }
  }

  /// Opening a chat clears «Пометить как непрочитанное».
  Future<void> _clearMarkedUnread() async {
    try {
      final conv = await _repo.markUnread(conversationId, false);
      if (ref.mounted) state = state.copyWith(conversation: conv);
    } on AppException catch (e) {
      DiagnosticLog.warn('chat', 'clear marked unread failed', error: e);
    }
  }

  List<ChatMessage> _merge(List<ChatMessage> tail) =>
      sortMessages([..._older, ...tail]);

  /// Dedupes (the later copy wins: the cache tail is fresher than a loaded
  /// history page) and orders by seq; pending outbox items go last.
  static List<ChatMessage> sortMessages(Iterable<ChatMessage> input) {
    final seen = <String>{};
    final all = <ChatMessage>[];
    for (final m in input.toList().reversed) {
      final key = m.seq > 0 ? 'seq:${m.seq}' : m.id;
      if (seen.add(key)) all.add(m);
    }
    all.sort((a, b) {
      if (a.seq > 0 && b.seq > 0) return a.seq.compareTo(b.seq);
      if (a.seq > 0) return -1;
      if (b.seq > 0) return 1;
      return a.createdAt.compareTo(b.createdAt);
    });
    return all;
  }

  Future<void> _refreshFromCache() async {
    final tail = await _repo.cachedMessages(conversationId);
    final conv = await _repo.conversation(conversationId);
    if (ref.mounted) {
      state = state.copyWith(messages: _merge(tail), conversation: conv);
    }
  }

  /// Coalesces reloads caused by a burst of events into one.
  void _scheduleRefresh({bool messages = true}) {
    _refreshMessages = _refreshMessages || messages;
    _refresh ??= Timer(ConversationsNotifier.coalesce, () async {
      _refresh = null;
      final withMessages = _refreshMessages;
      _refreshMessages = false;
      if (!ref.mounted) return;
      if (withMessages) {
        await _refreshFromCache();
        return;
      }
      final conv = await _repo.conversation(conversationId);
      if (ref.mounted && conv != null && !identical(conv, state.conversation)) {
        state = state.copyWith(conversation: conv);
      }
    });
  }

  int get _oldestSeq {
    for (final m in state.messages) {
      if (m.seq > 0) return m.seq;
    }
    return 0;
  }

  Future<void> loadOlder() async {
    if (state.loadingOlder || !state.hasMore) return;
    final oldest = _oldestSeq;
    if (oldest <= 1) {
      state = state.copyWith(hasMore: false);
      return;
    }
    state = state.copyWith(loadingOlder: true);
    try {
      final page = await _repo.loadOlder(conversationId, beforeSeq: oldest);
      _older.insertAll(0, page);
      if (!ref.mounted) return;
      state = state.copyWith(
        messages: sortMessages([...page, ...state.messages]),
        loadingOlder: false,
        hasMore: page.length >= 50,
      );
    } on AppException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loadingOlder: false, error: e);
    }
  }

  static const _jumpPage = 100;
  static const _jumpMaxPages = 30;

  /// Loads history pages (contiguous with what is shown) until the message
  /// with [seq] is present. False when it cannot be reached.
  Future<bool> ensureSeqLoaded(int seq) async {
    for (var i = 0; i <= _jumpMaxPages; i++) {
      if (state.messages.any((m) => m.seq == seq)) return true;
      final oldest = _oldestSeq;
      if (i == _jumpMaxPages || oldest == 0 || seq >= oldest) return false;
      final want = (oldest - seq + 20).clamp(1, _jumpPage);
      final page = await _repo.loadOlder(
        conversationId,
        beforeSeq: oldest,
        limit: want,
      );
      if (!ref.mounted) return false;
      if (page.isEmpty) {
        state = state.copyWith(hasMore: false);
        return false;
      }
      _older.insertAll(0, page);
      state = state.copyWith(
        messages: sortMessages([...page, ...state.messages]),
        hasMore: page.first.seq > 1,
      );
    }
    return false;
  }

  /// The message with [messageId], loading history around it when needed
  /// (`GET /messages/{id}` gives the seq). Null when it is not reachable.
  Future<ChatMessage?> locate(String messageId) async {
    final here = state.messages.where((m) => m.id == messageId).firstOrNull;
    if (here != null) return here;
    final m = await _repo.findMessage(conversationId, messageId);
    if (m.conversationId != conversationId || m.seq <= 0) return null;
    if (!await ensureSeqLoaded(m.seq)) return null;
    return state.messages.where((x) => x.seq == m.seq).firstOrNull;
  }

  void _onEvent(ChatEvent ev) {
    // Status / presence of the peer or a member: the cache already holds
    // the folded conversation.
    if (ev.type == 'user.status' || ev.type == 'presence.changed') {
      final c = state.conversation;
      if (c != null &&
          (c.peer?.userId == ev.userId ||
              c.members.any((m) => m.userId == ev.userId))) {
        _scheduleRefresh(messages: false);
      }
      return;
    }
    if (ev.conversationId != conversationId) return;
    final type = ev.type;
    if (type.startsWith('typing.') || type.startsWith('voice_recording.')) {
      _indicator(ev);
      return;
    }
    if (type.startsWith('call.')) return;
    final selfId = _repo.selfId;
    switch (type) {
      case 'message.created':
        final m = ev.message;
        if (m == null) {
          _scheduleRefresh();
          return;
        }
        // Comments belong to the post's thread screen.
        if (m.isComment) return;
        _upsert(m);
        _clearIndicator(m.senderId);
        _scheduleRefresh(messages: false);
      case 'message.updated' ||
          'message.deleted' ||
          'message.reaction' ||
          'message.delivered' ||
          'message.link_preview' ||
          'message.transcript' ||
          'poll.updated' ||
          'post.comments':
        _patch(
          (m) => m.id == ev.messageId,
          (m) => ChatRepository.applyToMessage(m, ev, selfId),
        );
      case 'message.hidden':
        if (ev.userId.isNotEmpty && ev.userId != selfId) return;
        _removeMessage(ev.messageId);
        _scheduleRefresh(messages: false);
      case 'message.read':
        if (ev.userId == selfId) {
          _scheduleRefresh(messages: false);
          return;
        }
        final upTo = (ev.payload['up_to_seq'] as num?)?.toInt() ?? 0;
        _patch(
          (m) =>
              m.senderId == selfId &&
              m.seq > 0 &&
              m.seq <= upTo &&
              m.status != 'read',
          ChatRepository.applyRead,
        );
      default:
        _scheduleRefresh();
    }
  }

  /// Inserts or replaces a server message (drops its pending placeholder).
  void _upsert(ChatMessage m) {
    bool replaced(ChatMessage x) =>
        x.id == m.id ||
        (m.seq > 0 && x.seq == m.seq) ||
        (x.seq == 0 &&
            m.clientMessageId.isNotEmpty &&
            x.clientMessageId == m.clientMessageId);
    state = state.copyWith(
      messages: sortMessages([
        for (final x in state.messages)
          if (!replaced(x)) x,
        m,
      ]),
    );
  }

  void _removeMessage(String messageId) {
    _older.removeWhere((m) => m.id == messageId);
    if (!state.messages.any((m) => m.id == messageId)) return;
    state = state.copyWith(
      messages: [
        for (final m in state.messages)
          if (m.id != messageId) m,
      ],
    );
  }

  void _patch(
    bool Function(ChatMessage) where,
    ChatMessage? Function(ChatMessage) change,
  ) {
    var changed = false;
    final next = [
      for (final m in state.messages)
        if (where(m)) (change(m) ?? m) else m,
    ];
    for (var i = 0; i < next.length; i++) {
      if (!identical(next[i], state.messages[i])) changed = true;
    }
    for (var i = 0; i < _older.length; i++) {
      if (where(_older[i])) _older[i] = change(_older[i]) ?? _older[i];
    }
    if (changed) state = state.copyWith(messages: next);
  }

  void _clearIndicator(String uid) {
    if (!state.typing.containsKey(uid) && !state.recording.containsKey(uid)) {
      return;
    }
    _typingTimers.removeWhere((k, t) {
      final hit = k.endsWith(':$uid');
      if (hit) t.cancel();
      return hit;
    });
    state = state.copyWith(
      typing: Map.of(state.typing)..remove(uid),
      recording: Map.of(state.recording)..remove(uid),
    );
  }

  void _indicator(ChatEvent ev) {
    final uid = ev.userId;
    if (uid.isEmpty || uid == _repo.selfId) return;
    final name = (ev.payload['display_name'] as String?) ?? '';
    final recording = ev.type.startsWith('voice_recording');
    final started = ev.type.endsWith('started');
    final map = Map<String, String>.from(
      recording ? state.recording : state.typing,
    );
    _typingTimers.remove('${ev.type}:$uid')?.cancel();
    if (started) {
      map[uid] = name;
      _typingTimers['${ev.type}:$uid'] = Timer(const Duration(seconds: 6), () {
        final m = Map<String, String>.from(
          recording ? state.recording : state.typing,
        )..remove(uid);
        if (ref.mounted) {
          state = recording
              ? state.copyWith(recording: m)
              : state.copyWith(typing: m);
        }
      });
    } else {
      map.remove(uid);
    }
    state = recording
        ? state.copyWith(recording: map)
        : state.copyWith(typing: map);
  }

  // ---- actions -----------------------------------------------------------------

  Future<void> sendText(
    String text, {
    String? replyToId,
    List<String> mentions = const [],
  }) async {
    stopTyping();
    await _repo.sendText(
      conversationId,
      text.trim(),
      replyToId: replyToId,
      mentions: mentions,
    );
    await _refreshFromCache();
  }

  Future<void> sendContact(ChatUser user) async {
    await _repo.sendContact(
      conversationId,
      ChatContact(
        userId: user.userId,
        displayName: user.displayName,
        email: user.email,
      ),
    );
    await _refreshFromCache();
  }

  Future<void> sendFile({
    required String path,
    required String filename,
    bool voice = false,
    int? durationMs,
  }) async {
    await _repo.sendFile(
      conversationId,
      filePath: path,
      filename: filename,
      voice: voice,
      durationMs: durationMs,
    );
    await _refreshFromCache();
  }

  Future<void> retry(String clientMessageId) =>
      _repo.retryOutbox(clientMessageId);
  Future<void> discard(String clientMessageId) =>
      _repo.discardOutbox(clientMessageId, conversationId);

  /// Marks the newest visible message as read (debounced by the repository).
  Future<void> markReadLatest() async {
    ChatMessage? last;
    for (final m in state.messages) {
      if (m.seq > 0 && m.senderId != _repo.selfId) last = m;
    }
    if (last != null) await _repo.markRead(last);
  }

  void typing() {
    if (!_typingSent) {
      _typingSent = true;
      _repo.typing(conversationId, started: true);
    }
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 4), stopTyping);
  }

  void stopTyping() {
    _typingDebounce?.cancel();
    if (_typingSent) {
      _typingSent = false;
      _repo.typing(conversationId, started: false);
    }
  }

  void recording(bool started) =>
      _repo.typing(conversationId, started: started, kind: 'recording');

  Future<void> react(ChatMessage m, String emoji) =>
      _repo.toggleReaction(m, emoji);
  Future<void> edit(ChatMessage m, String body) =>
      _repo.editMessage(m.id, body);
  Future<void> delete(ChatMessage m) => _repo.deleteMessage(m.id);

  /// «Удалить у меня».
  Future<void> hideForMe(ChatMessage m) => _repo.hideMessage(m);
}

final conversationProvider = NotifierProvider.autoDispose
    .family<ConversationNotifier, ConversationState, String>(
      ConversationNotifier.new,
    );

// ---------------------------------------------------------------------------
// Users / settings
// ---------------------------------------------------------------------------

final chatUserSearchProvider = FutureProvider.autoDispose
    .family<List<ChatUser>, String>((ref, q) async {
      final repo = ref.watch(chatRepositoryProvider);
      return repo.searchUsers(q);
    });

class ChatSettingsNotifier extends AsyncNotifier<ChatSettings> {
  @override
  Future<ChatSettings> build() => ref.watch(chatRepositoryProvider).settings();

  Future<void> save(ChatSettings s) async {
    state = AsyncData(s);
    try {
      state = AsyncData(
        await ref.read(chatRepositoryProvider).updateSettings(s),
      );
    } on AppException catch (e) {
      DiagnosticLog.warn('chat', 'settings update failed', error: e);
      state = AsyncError(e, StackTrace.current);
    }
  }
}

final chatSettingsProvider =
    AsyncNotifierProvider<ChatSettingsNotifier, ChatSettings>(
      ChatSettingsNotifier.new,
    );

// ---------------------------------------------------------------------------
// Media and storage preferences (Settings → chat storage)
// ---------------------------------------------------------------------------

/// Auto-download policy for previews and voice notes, persisted in the chat
/// cache meta store. Wi-Fi only until the stored value is read.
class ChatMediaAutoDownloadNotifier extends Notifier<MediaAutoDownload> {
  @override
  MediaAutoDownload build() {
    final cache = ref.watch(chatCacheProvider);
    Future.microtask(() async {
      final stored = await cache.mediaAutoDownload();
      if (ref.mounted && stored != state) state = stored;
    });
    return MediaAutoDownload.fallback;
  }

  Future<void> set(MediaAutoDownload value) async {
    state = value;
    await ref.read(chatCacheProvider).setMediaAutoDownload(value);
  }
}

final chatMediaAutoDownloadProvider =
    NotifierProvider<ChatMediaAutoDownloadNotifier, MediaAutoDownload>(
      ChatMediaAutoDownloadNotifier.new,
    );

/// Whether previews and voice notes may be fetched without a tap right now.
/// Unknown network state (still checking) counts as "not allowed".
final chatMediaAutoAllowedProvider = Provider<bool>((ref) {
  final network = ref.watch(networkStatusProvider).value;
  if (network == null) return false;
  return ref.watch(chatMediaAutoDownloadProvider).allows(network);
});

/// Messages kept per conversation in the local cache (50 / 100 / 300).
class ChatMessageLimitNotifier extends Notifier<int> {
  @override
  int build() {
    final cache = ref.watch(chatCacheProvider);
    Future.microtask(() async {
      final stored = await cache.messageLimit();
      if (ref.mounted && stored != state) state = stored;
    });
    return cache.maxMessagesPerConversation;
  }

  Future<void> set(int limit) async {
    state = limit;
    await ref.read(chatCacheProvider).setMessageLimit(limit);
  }
}

final chatMessageLimitProvider =
    NotifierProvider<ChatMessageLimitNotifier, int>(
      ChatMessageLimitNotifier.new,
    );

/// Size in bytes of the chat media directory.
final chatMediaSizeProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(chatRepositoryProvider).mediaSizeBytes(),
);

/// Group picture on disk (null → initials / group icon). Re-fetched when the
/// avatar changes (`chat.updated` with `change: avatar`, or a local change).
final chatAvatarProvider = FutureProvider.autoDispose
    .family<File?, ({String id, bool hasAvatar})>((ref, key) async {
      final repo = ref.watch(chatRepositoryProvider);
      final sub = repo.events
          .where(
            (e) => e.conversationId == key.id && e.payload['change'] == 'avatar',
          )
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(sub.cancel);
      if (!key.hasAvatar) return null;
      return repo.avatarFile(key.id);
    });

// ---------------------------------------------------------------------------
// Messenger UX helpers
// ---------------------------------------------------------------------------

/// Where photos for a message come from.
enum ChatMediaSource { camera, gallery }

/// Camera capture (one photo) or a multi-select of photos and videos from
/// the gallery (`image_picker`; faked in tests).
final chatMediaPickerProvider =
    Provider<Future<List<ChatPickedFile>> Function(ChatMediaSource source)>(
      (_) => (source) async {
        final picker = ImagePicker();
        if (source == ChatMediaSource.camera) {
          final shot = await picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 85,
            maxWidth: 2560,
          );
          return shot == null ? const [] : [(path: shot.path, name: shot.name)];
        }
        final picked = await picker.pickMultipleMedia(
          imageQuality: 85,
          maxWidth: 2560,
        );
        return [for (final x in picked) (path: x.path, name: x.name)];
      },
    );

/// Opens a link from a message outside the app (faked in tests).
final chatLinkOpenerProvider = Provider<Future<bool> Function(Uri uri)>(
  (_) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// A request to scroll a conversation to a message (search hit, push…).
typedef ChatJumpRequest = ({String conversationId, String messageId});

class ChatJumpNotifier extends Notifier<ChatJumpRequest?> {
  @override
  ChatJumpRequest? build() => null;

  int _generation = 0;
  int _taken = 0;

  void request(String conversationId, String messageId) {
    _generation++;
    state = (conversationId: conversationId, messageId: messageId);
  }

  /// Takes the pending request for [conversationId], if any. Called from
  /// `initState` of the conversation, i.e. while widgets build: the request
  /// is marked taken at once and cleared right after the frame's build
  /// (Riverpod forbids modifying providers during build).
  String? take(String conversationId) {
    final r = state;
    if (r == null || r.conversationId != conversationId) return null;
    if (_taken == _generation) return null;
    final gen = _taken = _generation;
    Future.microtask(() {
      if (ref.mounted && _generation == gen) state = null;
    });
    return r.messageId;
  }
}

final chatJumpRequestProvider =
    NotifierProvider<ChatJumpNotifier, ChatJumpRequest?>(ChatJumpNotifier.new);

/// Conversation shown in the right pane on wide screens.
class ChatSelectionNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

final chatSelectedConversationProvider =
    NotifierProvider<ChatSelectionNotifier, String?>(ChatSelectionNotifier.new);

/// Recently used reaction emoji (persisted, newest first).
class ChatRecentEmojiNotifier extends Notifier<List<String>> {
  static const defaults = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  @override
  List<String> build() {
    final cache = ref.watch(chatCacheProvider);
    Future.microtask(() async {
      final stored = await cache.recentEmoji();
      if (ref.mounted && stored.isNotEmpty) state = stored;
    });
    return defaults;
  }

  /// The quick-reaction row: recent first, topped up with the defaults.
  List<String> quick([int count = 6]) =>
      {...state, ...defaults}.take(count).toList();

  Future<void> use(String emoji) async {
    state = [emoji, ...state.where((e) => e != emoji)];
    state = await ref.read(chatCacheProvider).pushRecentEmoji(emoji);
  }
}

final chatRecentEmojiProvider =
    NotifierProvider<ChatRecentEmojiNotifier, List<String>>(
      ChatRecentEmojiNotifier.new,
    );

/// The pinned message of a chat, even when it is not in the loaded page.
final chatPinnedMessageProvider = FutureProvider.autoDispose
    .family<ChatMessage?, ({String conversationId, String messageId})>((
      ref,
      key,
    ) async {
      try {
        return await ref
            .watch(chatRepositoryProvider)
            .findMessage(key.conversationId, key.messageId);
      } on AppException catch (e) {
        DiagnosticLog.warn('chat', 'pinned message load failed', error: e);
        return null;
      }
    });

/// Who received / read an own message (groups).
final chatReceiptsProvider = FutureProvider.autoDispose
    .family<List<ChatReceipt>, String>(
      (ref, messageId) =>
          ref.watch(chatRepositoryProvider).receipts(messageId),
    );

/// One audio player for every voice note: starting one stops the previous.
/// The player is created on the first play.
class ChatAudioController {
  AudioPlayer? _player;

  /// Id of the attachment loaded into the player.
  final ValueNotifier<String?> current = ValueNotifier(null);

  /// Playback rate for voice notes (1×, 1.5×, 2×).
  final ValueNotifier<double> speed = ValueNotifier(1);
  static const speeds = [1.0, 1.5, 2.0];

  AudioPlayer get player => _player ??= AudioPlayer();
  bool get hasPlayer => _player != null;

  Future<void> play(String id, String path) async {
    final p = player;
    if (current.value != id) {
      await p.stop();
      await p.setFilePath(path);
      current.value = id;
      await p.setSpeed(speed.value);
    }
    if (p.processingState == ProcessingState.completed) {
      await p.seek(Duration.zero);
    }
    await p.play();
  }

  Future<void> pause() async => _player?.pause();

  Future<void> seek(String id, Duration position) async {
    if (current.value == id) await _player?.seek(position);
  }

  Future<void> cycleSpeed() async {
    final i = speeds.indexOf(speed.value);
    speed.value = speeds[(i + 1) % speeds.length];
    await _player?.setSpeed(speed.value);
  }

  /// Forgets [id] (e.g. a discarded preview) if it is loaded.
  Future<void> release(String id) async {
    if (current.value != id) return;
    await _player?.stop();
    current.value = null;
  }

  Future<void> dispose() async {
    current.dispose();
    speed.dispose();
    await _player?.dispose();
  }
}

final chatAudioProvider = Provider<ChatAudioController>((ref) {
  final c = ChatAudioController();
  ref.onDispose(c.dispose);
  return c;
});

/// Sign-out hook registered from main: wipes chat state and push registration.
Future<void> chatSignOut(ProviderContainer container) async {
  if (!container.read(chatEnabledProvider)) return;
  await container.read(chatPushProvider).unregister();
  await container.read(chatRepositoryProvider).signOut();
}
