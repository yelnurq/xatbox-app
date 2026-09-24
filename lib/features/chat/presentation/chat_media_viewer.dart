import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../../../core/platform/desktop_modal_observer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/platform/desktop.dart';
import '../../../core/theme/tokens.dart';
import '../data/chat_models.dart';
import 'chat_formatters.dart';
import 'chat_providers.dart';
import 'chat_video.dart';

/// One photo or video of a conversation shown in the viewer.
typedef ChatMediaItem = ({ChatMessage message, ChatAttachment attachment});

/// Photos and videos of the loaded messages, oldest first.
List<ChatMediaItem> chatMediaItems(List<ChatMessage> messages) => [
  for (final m in messages)
    if (!m.isDeleted)
      for (final a in m.attachments)
        if ((a.kind == 'image' || a.kind == 'video') &&
            !a.id.startsWith('local:'))
          (message: m, attachment: a),
];

/// Full-screen media viewer: swipe between the chat's photos and videos,
/// pinch or double-tap to zoom, open the original in another app. Videos
/// play inside the app (downloaded on tap, or ahead of time when media
/// auto-download allows it); the system player is the fallback.
class ChatMediaViewer extends ConsumerStatefulWidget {
  const ChatMediaViewer({
    super.key,
    required this.items,
    required this.initialIndex,
    this.names = const {},
    this.onShowInChat,
  });

  final List<ChatMediaItem> items;
  final int initialIndex;
  final Map<String, String> names;

  /// «Показать в чате»: the viewer closes, then this is called.
  final void Function(ChatMediaItem item)? onShowInChat;

  static Future<void> open(
    BuildContext context, {
    required List<ChatMediaItem> items,
    required int index,
    Map<String, String> names = const {},
    void Function(ChatMediaItem item)? onShowInChat,
  }) => Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      // Desktop: the shell goes dark around the viewer (full window).
      settings: const RouteSettings(name: desktopFullscreenRouteName),
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, _, _) => ChatMediaViewer(
        items: items,
        initialIndex: index,
        names: names,
        onShowInChat: onShowInChat,
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );

  @override
  ConsumerState<ChatMediaViewer> createState() => _ChatMediaViewerState();
}

class _ChatMediaViewerState extends ConsumerState<ChatMediaViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  bool _zoomed = false;
  bool _chrome = true;
  bool _opening = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _openExternally() async {
    if (_opening) return;
    final item = widget.items[_index];
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _opening = true);
    try {
      final file = await ref
          .read(chatRepositoryProvider)
          .attachmentFile(item.attachment);
      final ok = await ref.read(chatFileOpenerProvider)(
        file.path,
        item.attachment.mimeType,
      );
      if (!ok) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.attachmentNoApp)));
      }
    } on AppException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ChatFormat.error(l10n, e))),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The viewer always sits on the dark ground of the standard dark skin.
    const dark = XatBoxTokens.dark;
    final item = widget.items[_index];
    final sender = widget.names[item.message.senderId] ?? '';
    final meta =
        '${ChatFormat.daySeparator(context, item.message.createdAt)}, '
        '${ChatFormat.time(context, item.message.createdAt)}';
    final ink = dark.textPrimary;
    return Scaffold(
      key: const Key('chat_media_viewer'),
      backgroundColor: dark.appBg,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedOpacity(
          opacity: _chrome ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: AppBar(
            backgroundColor: dark.appBg.withValues(alpha: 0.6),
            foregroundColor: ink,
            iconTheme: IconThemeData(color: ink),
            leading: IconButton(
              tooltip: l10n.close,
              icon: const Icon(LucideIcons.x),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sender,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: ink, fontSize: 16),
                ),
                Text(
                  widget.items.length > 1
                      ? '$meta · ${l10n.chatSearchPosition(_index + 1, widget.items.length)}'
                      : meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: dark.textSecondary, fontSize: 12),
                ),
              ],
            ),
            actions: [
              if (widget.onShowInChat != null)
                IconButton(
                  key: const Key('media_show_in_chat'),
                  tooltip: l10n.chatShowInChat,
                  icon: const Icon(LucideIcons.locateFixed),
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onShowInChat!(item);
                  },
                ),
              IconButton(
                key: const Key('media_open_external'),
                tooltip: l10n.chatOpenExternally,
                onPressed: _opening ? null : _openExternally,
                icon: _opening
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ink,
                        ),
                      )
                    : const Icon(LucideIcons.externalLink),
              ),
            ],
          ),
        ),
      ),
      body: _desktopPaging(PageView.builder(
        controller: _pages,
        physics: _zoomed
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        itemCount: widget.items.length,
        onPageChanged: (i) => setState(() {
          _index = i;
          _zoomed = false;
        }),
        itemBuilder: (context, i) => _MediaPage(
          key: ValueKey(widget.items[i].attachment.id),
          item: widget.items[i],
          onTap: () => setState(() => _chrome = !_chrome),
          onZoomChanged: (z) {
            if (z != _zoomed) setState(() => _zoomed = z);
          },
          onPlay: _openExternally,
        ),
      )),
    );
  }

  void _go(int delta) {
    final i = _index + delta;
    if (i < 0 || i >= widget.items.length) return;
    unawaited(_pages.animateToPage(i, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic));
  }

  /// Desktop: a mouse cannot swipe the pages; ←/→ buttons and keys, Esc
  /// closes.
  Widget _desktopPaging(Widget pages) {
    if (!isDesktop) return pages;
    final l10n = context.l10n;
    Widget arrow(int delta, IconData icon, String tooltip, Alignment at) => Align(
      alignment: at,
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: IconButton.filledTonal(
          key: Key(delta < 0 ? 'media_prev' : 'media_next'),
          tooltip: tooltip,
          icon: Icon(icon),
          onPressed: () => _go(delta),
        ),
      ),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            pages,
            if (_chrome && _index > 0) arrow(-1, LucideIcons.chevronLeft, l10n.desktopPrevious, Alignment.centerLeft),
            if (_chrome && _index < widget.items.length - 1)
              arrow(1, LucideIcons.chevronRight, l10n.desktopNext, Alignment.centerRight),
          ],
        ),
      ),
    );
  }
}

class _MediaPage extends ConsumerStatefulWidget {
  const _MediaPage({
    super.key,
    required this.item,
    required this.onTap,
    required this.onZoomChanged,
    required this.onPlay,
  });
  final ChatMediaItem item;
  final VoidCallback onTap;
  final ValueChanged<bool> onZoomChanged;
  final VoidCallback onPlay;

  @override
  ConsumerState<_MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends ConsumerState<_MediaPage>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final AnimationController _zoomAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Matrix4>? _zoomTween;
  File? _thumb;
  File? _original;
  bool _failed = false;
  Offset _doubleTapAt = Offset.zero;

  /// Downloaded original of a video (then played in-app).
  File? _video;
  bool _videoLoading = false;
  bool _videoFailed = false;
  bool _videoAutoPlay = false;

  ChatAttachment get _a => widget.item.attachment;
  bool get _isVideo => _a.kind == 'video';

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
    _zoomAnim.addListener(() {
      final tween = _zoomTween;
      if (tween != null) _transform.value = tween.value;
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _transform.removeListener(_onTransform);
    _transform.dispose();
    _zoomAnim.dispose();
    super.dispose();
  }

  void _onTransform() =>
      widget.onZoomChanged(_transform.value.getMaxScaleOnAxis() > 1.01);

  Future<void> _load() async {
    final repo = ref.read(chatRepositoryProvider);
    if (_a.hasThumbnail) {
      final thumb = await repo.cachedAttachmentFile(_a, thumbnail: true);
      if (mounted && thumb != null) setState(() => _thumb = thumb);
    }
    if (_isVideo) {
      final original = await repo.cachedAttachmentFile(_a);
      if (original != null) {
        if (mounted) setState(() => _video = original);
        return;
      }
      if (_thumb == null && _a.hasThumbnail) {
        try {
          final t = await repo.attachmentFile(_a, thumbnail: true);
          if (mounted) setState(() => _thumb = t);
        } on AppException {
          // the placeholder stays
        }
      }
      // Originals are fetched ahead only when auto-download allows it.
      if (mounted && ref.read(chatMediaAutoAllowedProvider)) {
        await _prepareVideo(autoPlay: false);
      }
      return;
    }
    try {
      final original = await repo.attachmentFile(_a);
      if (mounted) setState(() => _original = original);
    } on AppException {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _prepareVideo({required bool autoPlay}) async {
    if (_videoLoading || _video != null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    setState(() {
      _videoLoading = true;
      _videoAutoPlay = autoPlay;
    });
    try {
      final file = await ref.read(chatRepositoryProvider).attachmentFile(_a);
      if (mounted) setState(() => _video = file);
    } on AppException catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text(ChatFormat.error(l10n, e))),
      );
    } finally {
      if (mounted) setState(() => _videoLoading = false);
    }
  }

  void _onVideoFailed() {
    if (!mounted) return;
    setState(() => _videoFailed = true);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(context.l10n.chatVideoFailed)),
    );
    widget.onPlay();
  }

  void _toggleZoom() {
    final zoomedIn = _transform.value.getMaxScaleOnAxis() > 1.01;
    const scale = 2.5;
    final p = _doubleTapAt;
    final target = zoomedIn
        ? Matrix4.identity()
        : (Matrix4.identity()
            ..translateByDouble(-p.dx * (scale - 1), -p.dy * (scale - 1), 0, 1)
            ..scaleByDouble(scale, scale, 1, 1));
    _zoomTween = Matrix4Tween(
      begin: _transform.value,
      end: target,
    ).animate(CurvedAnimation(parent: _zoomAnim, curve: Curves.easeOut));
    _zoomAnim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    const dark = XatBoxTokens.dark;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final file = _original ?? _thumb;
    Widget content;
    if (file == null) {
      content = _failed
          ? Icon(LucideIcons.imageOff, size: 48, color: dark.textTertiary)
          : SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: dark.textSecondary,
              ),
            );
    } else {
      content = Image.file(
        file,
        key: ValueKey('viewer_image_${_a.id}_${_original != null}'),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        cacheWidth: _original == null ? null : (width * dpr * 2).round(),
        errorBuilder: (_, _, _) =>
            Icon(LucideIcons.imageOff, size: 48, color: dark.textTertiary),
      );
    }
    if (_isVideo) {
      if (_video != null && !_videoFailed) {
        return ChatVideoPlayer(
          key: ValueKey('viewer_video_${_a.id}'),
          file: _video!,
          autoPlay: _videoAutoPlay,
          onFailed: _onVideoFailed,
        );
      }
      return GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            Center(child: content),
            Center(
              child: _videoLoading
                  ? SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: dark.textPrimary,
                      ),
                    )
                  : IconButton.filled(
                      key: ValueKey('viewer_play_${_a.id}'),
                      iconSize: 40,
                      tooltip: context.l10n.chatVideoPlay,
                      style: IconButton.styleFrom(
                        backgroundColor: dark.surface.withValues(alpha: 0.7),
                        foregroundColor: dark.textPrimary,
                      ),
                      onPressed: _videoFailed
                          ? widget.onPlay
                          : () => _prepareVideo(autoPlay: true),
                      icon: const Icon(LucideIcons.play),
                    ),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 5,
        child: SizedBox.expand(child: Center(child: content)),
      ),
    );
  }
}
