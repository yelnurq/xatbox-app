import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/network/network_status.dart';
import '../../../../shared/utils/diagnostic_log.dart';
import '../../data/chat_folders.dart';
import '../../data/chat_models.dart';
import '../chat_providers.dart';

final chatFoldersApiProvider = Provider<ChatFoldersApi>(
  (ref) => ChatFoldersApi(ref.watch(chatApiClientProvider)),
);

enum ChatFoldersSync { loading, synced, pending, failed }

@immutable
class ChatFoldersState {
  const ChatFoldersState({
    this.folders = const [],
    this.sync = ChatFoldersSync.loading,
    this.hasData = false,
    this.error,
  });

  final List<ChatFolder> folders;
  final ChatFoldersSync sync;

  /// False until the cache or the server answered.
  final bool hasData;

  /// Last rejection of a change (the server list was restored).
  final Object? error;

  bool get canAdd => folders.length < ChatFolder.maxFolders;

  ChatFolder? byId(String id) => folders.where((f) => f.id == id).firstOrNull;

  ChatFoldersState copyWith({
    List<ChatFolder>? folders,
    ChatFoldersSync? sync,
    bool? hasData,
    Object? error,
    bool clearError = false,
  }) => ChatFoldersState(
    folders: folders ?? this.folders,
    sync: sync ?? this.sync,
    hasData: hasData ?? this.hasData,
    error: clearError ? null : (error ?? this.error),
  );
}

/// The user's chat folders: cached in the chat meta store (wiped on
/// sign-out), changed optimistically and sent as a full replacement; an
/// offline change stays pending and is resent when the network returns.
/// Other devices' changes arrive as `chat_folders.updated`.
class ChatFoldersNotifier extends Notifier<ChatFoldersState> {
  static const metaKey = 'chat_folders';
  static const _uuid = Uuid();
  int _generation = 0;

  ChatFoldersApi get _api => ref.read(chatFoldersApiProvider);

  @override
  ChatFoldersState build() {
    if (!ref.watch(chatEnabledProvider)) {
      return const ChatFoldersState(sync: ChatFoldersSync.synced, hasData: true);
    }
    ref.watch(currentUserProvider.select((u) => u?.id));
    final repo = ref.watch(chatRepositoryProvider);
    final sub = repo.events.listen((ev) {
      if (ev.type != 'chat_folders.updated') return;
      // A local change still on its way wins; it replaces the list anyway.
      if (state.sync == ChatFoldersSync.pending) return;
      final list = parseChatFolders(ev.payload['folders']);
      _generation++;
      state = state.copyWith(
        folders: list,
        sync: ChatFoldersSync.synced,
        hasData: true,
        clearError: true,
      );
      unawaited(_write(list, dirty: false));
    });
    ref.onDispose(sub.cancel);
    ref.listen<bool>(isOnlineProvider, (was, online) {
      if (online && was != true && state.sync == ChatFoldersSync.pending) {
        unawaited(sync());
      }
    });
    Future.microtask(_load);
    return const ChatFoldersState();
  }

  Future<void> _load() async {
    try {
      final raw = await ref.read(chatCacheProvider).readMeta(metaKey);
      if (!ref.mounted) return;
      if (raw != null && raw.isNotEmpty) {
        final json = jsonDecode(raw);
        if (json is Map) {
          state = state.copyWith(
            folders: parseChatFolders(json['folders']),
            hasData: true,
            sync: json['dirty'] == true
                ? ChatFoldersSync.pending
                : ChatFoldersSync.loading,
          );
        }
      }
    } on Object catch (e) {
      DiagnosticLog.warn('chat', 'folders cache read failed', error: e);
    }
    await sync();
  }

  Future<void> _write(List<ChatFolder> folders, {required bool dirty}) async {
    try {
      await ref
          .read(chatCacheProvider)
          .writeMeta(
            metaKey,
            jsonEncode({
              'folders': [for (final f in folders) f.toJson()],
              'dirty': dirty,
            }),
          );
    } on Object catch (e) {
      DiagnosticLog.warn('chat', 'folders cache write failed', error: e);
    }
  }

  /// Sends a pending change, otherwise refreshes from the server.
  Future<void> sync() async {
    if (!ref.mounted) return;
    final generation = _generation;
    final pending = state.sync == ChatFoldersSync.pending;
    try {
      final result = pending
          ? await _api.save(state.folders)
          : await _api.fetch();
      if (!ref.mounted || generation != _generation) return;
      await _write(result.folders, dirty: false);
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(
        folders: result.folders,
        sync: ChatFoldersSync.synced,
        hasData: true,
        clearError: true,
      );
    } on ApiException catch (e) {
      if (!ref.mounted || generation != _generation) return;
      if (pending && e.statusCode >= 400 && e.statusCode < 500 && e.statusCode != 429) {
        // Rejected (INVALID_FOLDER / TOO_MANY_FOLDERS): back to the server's.
        DiagnosticLog.warn('chat', 'folders rejected', error: e);
        _generation++;
        state = state.copyWith(sync: ChatFoldersSync.loading, error: e);
        await _write(state.folders, dirty: false);
        await sync();
        if (ref.mounted) state = state.copyWith(error: e);
        return;
      }
      _failed(e, pending);
    } on AppException catch (e) {
      if (!ref.mounted || generation != _generation) return;
      _failed(e, pending);
    }
  }

  void _failed(AppException e, bool pending) {
    DiagnosticLog.warn('chat', 'folders sync failed', error: e);
    state = state.copyWith(
      sync: pending ? ChatFoldersSync.pending : ChatFoldersSync.failed,
    );
  }

  Future<void> _commit(List<ChatFolder> next) async {
    _generation++;
    state = state.copyWith(
      folders: next,
      sync: ChatFoldersSync.pending,
      hasData: true,
      clearError: true,
    );
    await _write(next, dirty: true);
    await sync();
  }

  /// A new id for a folder created on this device.
  static String newId() => _uuid.v4();

  /// Adds or replaces [folder]; false when a new one would exceed the limit.
  Future<bool> upsert(ChatFolder folder) async {
    final list = [...state.folders];
    final i = list.indexWhere((f) => f.id == folder.id);
    if (i >= 0) {
      list[i] = folder;
    } else {
      if (list.length >= ChatFolder.maxFolders) return false;
      list.add(folder);
    }
    await _commit(list);
    return true;
  }

  Future<void> remove(String id) =>
      _commit([
        for (final f in state.folders)
          if (f.id != id) f,
      ]);

  /// Moves the folder at [from] to the final position [to]
  /// (`ReorderableListView.onReorderItem` indices).
  Future<void> move(int from, int to) async {
    final list = [...state.folders];
    if (from < 0 || from >= list.length || from == to) return;
    final moved = list.removeAt(from);
    list.insert(to.clamp(0, list.length), moved);
    await _commit(list);
  }

  /// Adds [chatId] to the folder's explicit chats, or removes it.
  Future<void> toggleChat(String folderId, String chatId) async {
    final f = state.byId(folderId);
    if (f == null) return;
    final ids = f.chatIds.contains(chatId)
        ? [
            for (final id in f.chatIds)
              if (id != chatId) id,
          ]
        : [...f.chatIds, chatId];
    if (ids.length > ChatFolder.maxChats) return;
    await upsert(f.copyWith(chatIds: ids));
  }
}

final chatFoldersProvider =
    NotifierProvider<ChatFoldersNotifier, ChatFoldersState>(
      ChatFoldersNotifier.new,
    );

/// Tabs of the chat list: built-in filters, then the user's folders.
abstract final class ChatListTabs {
  static const all = 'all';
  static const unread = 'unread';
  static const groups = 'groups';
  static const channels = 'channels';
  static const builtIn = [all, unread, groups, channels];
  static const _folderPrefix = 'folder:';

  static String folder(String id) => '$_folderPrefix$id';

  static String? folderId(String tab) =>
      tab.startsWith(_folderPrefix) ? tab.substring(_folderPrefix.length) : null;

  /// The tab still exists (a deleted folder falls back to «Все»).
  static String effective(String tab, List<ChatFolder> folders) {
    final id = folderId(tab);
    if (id == null) return builtIn.contains(tab) ? tab : all;
    return folders.any((f) => f.id == id) ? tab : all;
  }

  /// Whether [c] is listed under [tab] (pure, unit-tested).
  static bool matches(
    String tab,
    ChatConversation c,
    List<ChatFolder> folders,
    DateTime now,
  ) {
    switch (tab) {
      case all:
        return true;
      case unread:
        return c.hasUnread;
      case groups:
        return c.isGroup;
      case channels:
        return c.isChannel;
    }
    final id = folderId(tab);
    final f = id == null ? null : folders.where((x) => x.id == id).firstOrNull;
    return f?.matches(c, now) ?? true;
  }

  /// Chats of [tab] with something unread (the counter on the tab).
  static int unreadChats(
    String tab,
    Iterable<ChatConversation> convs,
    List<ChatFolder> folders,
    DateTime now,
  ) => convs
      .where(
        (c) =>
            !c.settings.archived &&
            c.hasUnread &&
            matches(tab, c, folders, now),
      )
      .length;
}
