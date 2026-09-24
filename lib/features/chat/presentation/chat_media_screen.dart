import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/widgets/state_view.dart';
import '../data/chat_models.dart';
import 'chat_formatters.dart';
import 'chat_media_viewer.dart';
import 'chat_providers.dart';
import 'message_bubble.dart' show VoicePlayer;

typedef ChatMediaKey = ({String conversationId, ChatMediaKind kind});

@immutable
class ChatMediaListState {
  const ChatMediaListState({
    this.items = const [],
    this.loading = false,
    this.loadingMore = false,
    this.loaded = false,
    this.error,
    this.nextCursor = '',
  });
  final List<ChatMediaEntry> items;
  final bool loading;
  final bool loadingMore;
  final bool loaded;
  final Object? error;
  final String nextCursor;

  bool get hasMore => nextCursor.isNotEmpty;

  ChatMediaListState copyWith({
    List<ChatMediaEntry>? items,
    bool? loading,
    bool? loadingMore,
    bool? loaded,
    Object? error,
    bool clearError = false,
    String? nextCursor,
  }) => ChatMediaListState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    loaded: loaded ?? this.loaded,
    error: clearError ? null : (error ?? this.error),
    nextCursor: nextCursor ?? this.nextCursor,
  );
}

/// One tab of the listing with cursor pagination (`GET /chats/{id}/media`).
class ChatMediaListNotifier extends Notifier<ChatMediaListState> {
  ChatMediaListNotifier(this.key);
  final ChatMediaKey key;

  static const pageSize = 30;

  /// Empty pages that still carry a cursor (the server bounds its link scan)
  /// are followed up to this many times.
  static const maxEmptyPages = 5;

  @override
  ChatMediaListState build() {
    Future.microtask(refresh);
    return const ChatMediaListState(loading: true);
  }

  Future<({List<ChatMediaEntry> items, String nextCursor})> _page(
    String? cursor,
  ) async {
    final repo = ref.read(chatRepositoryProvider);
    var page = await repo.listMedia(
      key.conversationId,
      kind: key.kind,
      cursor: cursor,
      limit: pageSize,
    );
    for (var i = 0;
        i < maxEmptyPages && page.items.isEmpty && page.nextCursor.isNotEmpty;
        i++) {
      page = await repo.listMedia(
        key.conversationId,
        kind: key.kind,
        cursor: page.nextCursor,
        limit: pageSize,
      );
    }
    return page;
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await _page(null);
      if (!ref.mounted) return;
      state = ChatMediaListState(
        items: page.items,
        nextCursor: page.nextCursor,
        loaded: true,
      );
    } on AppException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, loaded: true, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _page(state.nextCursor);
      if (!ref.mounted) return;
      state = state.copyWith(
        items: [...state.items, ...page.items],
        nextCursor: page.nextCursor,
        loadingMore: false,
      );
    } on AppException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loadingMore: false, error: e);
    }
  }
}

final chatMediaListProvider = NotifierProvider.autoDispose
    .family<ChatMediaListNotifier, ChatMediaListState, ChatMediaKey>(
      ChatMediaListNotifier.new,
    );

/// «Медиа, файлы, ссылки, голосовые» of a conversation. «Показать в чате»
/// pops the screen with the message id; the caller jumps to it.
class ChatMediaScreen extends ConsumerWidget {
  const ChatMediaScreen({
    super.key,
    required this.conversationId,
    this.initialKind = ChatMediaKind.media,
  });

  final String conversationId;
  final ChatMediaKind initialKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final labels = {
      ChatMediaKind.media: l10n.chatMediaTabMedia,
      ChatMediaKind.file: l10n.chatMediaTabFiles,
      ChatMediaKind.link: l10n.chatMediaTabLinks,
      ChatMediaKind.voice: l10n.chatMediaTabVoice,
    };
    return DefaultTabController(
      length: ChatMediaKind.values.length,
      initialIndex: initialKind.index,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.chatMediaFilesLinks),
          bottom: TabBar(
            key: const Key('chat_media_tabs'),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final k in ChatMediaKind.values)
                Tab(key: Key('chat_media_tab_${k.name}'), text: labels[k]),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final k in ChatMediaKind.values)
              _MediaTab(
                key: PageStorageKey('chat_media_${k.name}'),
                conversationId: conversationId,
                kind: k,
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaTab extends ConsumerWidget {
  const _MediaTab({
    super.key,
    required this.conversationId,
    required this.kind,
  });
  final String conversationId;
  final ChatMediaKind kind;

  ChatMediaKey get _key => (conversationId: conversationId, kind: kind);

  Map<String, String> _names(BuildContext context, WidgetRef ref) {
    final conv = ref.watch(
      conversationsProvider.select(
        (s) => s.items.where((c) => c.id == conversationId).firstOrNull,
      ),
    );
    return {
      for (final m in conv?.members ?? const <ChatMember>[]) m.userId: m.label,
      if (conv?.peer != null) conv!.peer!.userId: conv.peer!.label,
      ref.read(chatRepositoryProvider).selfId: context.l10n.chatYou,
    };
  }

  void _showInChat(BuildContext context, String messageId) =>
      Navigator.of(context).pop(messageId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(chatMediaListProvider(_key));
    final notifier = ref.read(chatMediaListProvider(_key).notifier);
    if (state.loading && !state.loaded) return const StateView.loading();
    if (state.error != null && state.items.isEmpty) {
      return StateView.error(
        message: ChatFormat.error(l10n, state.error!),
        onRetry: notifier.refresh,
      );
    }
    if (state.items.isEmpty) {
      return StateView.empty(
        title: l10n.chatMediaEmpty,
        icon: switch (kind) {
          ChatMediaKind.media => LucideIcons.images,
          ChatMediaKind.file => LucideIcons.fileText,
          ChatMediaKind.link => LucideIcons.link,
          ChatMediaKind.voice => LucideIcons.mic,
        },
      );
    }
    final names = _names(context, ref);
    final extra = state.loadingMore ? 1 : 0;
    Widget spinner() => const Padding(
      padding: EdgeInsets.all(Space.md),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );

    final Widget list;
    if (kind == ChatMediaKind.media) {
      final items = [
        for (final e in state.items)
          if (e.attachment != null)
            (message: e.message, attachment: e.attachment!),
      ];
      list = GridView.builder(
        key: const Key('chat_media_grid'),
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 130,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: items.length + extra,
        itemBuilder: (context, i) {
          if (i >= items.length) return spinner();
          final item = items[i];
          return _MediaGridTile(
            key: ValueKey('media_grid_${item.attachment.id}'),
            item: item,
            onTap: () => ChatMediaViewer.open(
              context,
              items: items,
              index: i,
              names: names,
              onShowInChat: (picked) =>
                  _showInChat(context, picked.message.id),
            ),
          );
        },
      );
    } else {
      list = ListView.builder(
        key: Key('chat_media_list_${kind.name}'),
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        itemCount: state.items.length + extra,
        itemBuilder: (context, i) {
          if (i >= state.items.length) return spinner();
          final e = state.items[i];
          final show = IconButton(
            key: ValueKey('media_show_${e.attachment?.id ?? e.message.id}'),
            tooltip: l10n.chatShowInChat,
            icon: const Icon(LucideIcons.locateFixed, size: 20),
            onPressed: () => _showInChat(context, e.message.id),
          );
          final meta =
              '${names[e.message.senderId] ?? ''} · '
              '${ChatFormat.daySeparator(context, e.message.createdAt)}, '
              '${ChatFormat.time(context, e.message.createdAt)}';
          return switch (kind) {
            ChatMediaKind.file when e.attachment != null => _FileTile(
              entry: e,
              meta: meta,
              trailing: show,
            ),
            ChatMediaKind.link => _LinkTile(entry: e, meta: meta, trailing: show),
            ChatMediaKind.voice when e.attachment != null => _VoiceTile(
              entry: e,
              meta: meta,
              trailing: show,
            ),
            _ => const SizedBox.shrink(),
          };
        },
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 400) unawaited(notifier.loadMore());
        return false;
      },
      child: RefreshIndicator(onRefresh: notifier.refresh, child: list),
    );
  }
}

class _MediaGridTile extends ConsumerStatefulWidget {
  const _MediaGridTile({super.key, required this.item, required this.onTap});
  final ChatMediaItem item;
  final VoidCallback onTap;

  @override
  ConsumerState<_MediaGridTile> createState() => _MediaGridTileState();
}

class _MediaGridTileState extends ConsumerState<_MediaGridTile> {
  File? _thumb;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final a = widget.item.attachment;
    if (!a.hasThumbnail) return;
    final repo = ref.read(chatRepositoryProvider);
    var file = await repo.cachedAttachmentFile(a, thumbnail: true);
    if (file == null && ref.read(chatMediaAutoAllowedProvider)) {
      try {
        file = await repo.attachmentFile(a, thumbnail: true);
      } on AppException catch (e) {
        DiagnosticLog.warn('chat', 'media grid thumbnail failed', error: e);
      }
    }
    if (mounted && file != null) setState(() => _thumb = file);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = widget.item.attachment;
    final video = a.kind == 'video';
    final px = (130 * MediaQuery.devicePixelRatioOf(context)).round();
    return Material(
      color: t.surfaceMuted,
      child: InkWell(
        onTap: widget.onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_thumb != null)
              Image.file(
                _thumb!,
                fit: BoxFit.cover,
                cacheWidth: px,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              )
            else
              Icon(
                video ? LucideIcons.video : LucideIcons.image,
                color: t.textTertiary,
              ),
            if (video)
              Positioned(
                left: Space.xs,
                bottom: Space.xs,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(XatBoxTokens.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.play, size: 11, color: Colors.white),
                      if ((a.durationMs ?? 0) > 0) ...[
                        const SizedBox(width: 2),
                        Text(
                          ChatFormat.duration(a.durationMs),
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FileTile extends ConsumerStatefulWidget {
  const _FileTile({
    required this.entry,
    required this.meta,
    required this.trailing,
  });
  final ChatMediaEntry entry;
  final String meta;
  final Widget trailing;

  @override
  ConsumerState<_FileTile> createState() => _FileTileState();
}

class _FileTileState extends ConsumerState<_FileTile> {
  bool _busy = false;

  Future<void> _open() async {
    if (_busy) return;
    final a = widget.entry.attachment!;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final file = await ref.read(chatRepositoryProvider).attachmentFile(a);
      final ok = await ref.read(chatFileOpenerProvider)(file.path, a.mimeType);
      if (!ok) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.attachmentNoApp)));
      }
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ChatFormat.error(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = widget.entry.attachment!;
    return ListTile(
      key: ValueKey('media_file_${a.id}'),
      onTap: _open,
      leading: CircleAvatar(
        backgroundColor: t.primarySoft,
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                a.kind == 'audio' ? LucideIcons.fileAudio : LucideIcons.fileText,
                color: t.primary,
                size: 20,
              ),
      ),
      title: Text(a.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${FormatUtils.bytes(a.size)} · ${widget.meta}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: t.textTertiary),
      ),
      trailing: widget.trailing,
    );
  }
}

class _LinkTile extends ConsumerWidget {
  const _LinkTile({
    required this.entry,
    required this.meta,
    required this.trailing,
  });
  final ChatMediaEntry entry;
  final String meta;
  final Widget trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final preview = entry.message.linkPreview;
    final url = entry.url ?? preview?.url ?? '';
    final uri = Uri.tryParse(url);
    final title = (preview?.title.isNotEmpty ?? false)
        ? preview!.title
        : (uri?.host.isNotEmpty ?? false ? uri!.host : url);
    return ListTile(
      key: ValueKey('media_link_${entry.message.id}'),
      onTap: uri == null
          ? null
          : () async {
              final ok = await ref.read(chatLinkOpenerProvider)(uri);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.attachmentNoApp)),
                );
              }
            },
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: t.primarySoft,
          borderRadius: BorderRadius.circular(t.radiusSm),
        ),
        child: Icon(LucideIcons.link, color: t.primary, size: 20),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: t.primary),
          ),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: t.textTertiary),
          ),
        ],
      ),
      trailing: trailing,
    );
  }
}

class _VoiceTile extends ConsumerWidget {
  const _VoiceTile({
    required this.entry,
    required this.meta,
    required this.trailing,
  });
  final ChatMediaEntry entry;
  final String meta;
  final Widget trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final a = entry.attachment!;
    return Padding(
      key: ValueKey('media_voice_${a.id}'),
      padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.xs, Space.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: t.textTertiary),
                ),
                const SizedBox(height: Space.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: VoicePlayer(
                    attachment: a,
                    autoFetch: ref.watch(chatMediaAutoAllowedProvider),
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
