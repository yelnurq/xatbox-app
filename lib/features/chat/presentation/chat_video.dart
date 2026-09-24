import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/diagnostic_log.dart';
import 'chat_formatters.dart';

/// Playback state of a chat video, independent of the player plugin.
@immutable
class ChatVideoValue {
  const ChatVideoValue({
    this.initialized = false,
    this.playing = false,
    this.buffering = false,
    this.completed = false,
    this.hasError = false,
    this.muted = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.aspectRatio = 16 / 9,
  });
  final bool initialized;
  final bool playing;
  final bool buffering;
  final bool completed;
  final bool hasError;
  final bool muted;
  final Duration position;
  final Duration duration;
  final double aspectRatio;
}

/// The player behind the in-app video viewer (fake in tests).
abstract class ChatVideoController {
  ValueListenable<ChatVideoValue> get value;
  Future<void> initialize();
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  Future<void> setMuted(bool muted);
  Widget buildView();
  Future<void> dispose();
}

typedef ChatVideoFactory = ChatVideoController Function(File file);

final chatVideoFactoryProvider = Provider<ChatVideoFactory>(
  (_) => PlatformChatVideoController.new,
);

/// [ChatVideoController] on the official `video_player` plugin.
class PlatformChatVideoController implements ChatVideoController {
  PlatformChatVideoController(File file)
    : _c = VideoPlayerController.file(file) {
    _c.addListener(_sync);
  }

  final VideoPlayerController _c;
  final _value = ValueNotifier(const ChatVideoValue());

  void _sync() {
    final v = _c.value;
    _value.value = ChatVideoValue(
      initialized: v.isInitialized,
      playing: v.isPlaying,
      buffering: v.isBuffering,
      completed: v.isCompleted,
      hasError: v.hasError,
      muted: v.volume == 0,
      position: v.position,
      duration: v.duration,
      aspectRatio: v.isInitialized && v.aspectRatio > 0 ? v.aspectRatio : 16 / 9,
    );
  }

  @override
  ValueListenable<ChatVideoValue> get value => _value;

  @override
  Future<void> initialize() => _c.initialize();

  @override
  Future<void> play() => _c.play();

  @override
  Future<void> pause() => _c.pause();

  @override
  Future<void> seekTo(Duration position) => _c.seekTo(position);

  @override
  Future<void> setMuted(bool muted) => _c.setVolume(muted ? 0 : 1);

  @override
  Widget buildView() => VideoPlayer(_c);

  @override
  Future<void> dispose() async {
    _c.removeListener(_sync);
    await _c.dispose();
    _value.dispose();
  }
}

/// Plays a downloaded chat video with controls: play / pause, seek bar,
/// position / duration and mute. [onFailed] fires once when the player
/// cannot open the file (the viewer then falls back to an external app).
class ChatVideoPlayer extends ConsumerStatefulWidget {
  const ChatVideoPlayer({
    super.key,
    required this.file,
    required this.onFailed,
    this.autoPlay = true,
  });

  final File file;
  final VoidCallback onFailed;
  final bool autoPlay;

  @override
  ConsumerState<ChatVideoPlayer> createState() => _ChatVideoPlayerState();
}

class _ChatVideoPlayerState extends ConsumerState<ChatVideoPlayer> {
  late final ChatVideoController _controller = ref.read(
    chatVideoFactoryProvider,
  )(widget.file);
  bool _failed = false;
  bool _controls = true;
  double? _dragMs;

  @override
  void initState() {
    super.initState();
    _controller.value.addListener(_watchError);
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      await _controller.initialize();
      if (widget.autoPlay && mounted) await _controller.play();
    } on Object catch (e) {
      DiagnosticLog.warn('chat', 'video init failed', error: e);
      _fail();
    }
  }

  void _watchError() {
    if (_controller.value.value.hasError) _fail();
  }

  void _fail() {
    if (_failed || !mounted) return;
    setState(() => _failed = true);
    widget.onFailed();
  }

  @override
  void dispose() {
    _controller.value.removeListener(_watchError);
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _toggle(ChatVideoValue v) async {
    if (v.playing) {
      await _controller.pause();
      return;
    }
    if (v.completed || (v.duration > Duration.zero && v.position >= v.duration)) {
      await _controller.seekTo(Duration.zero);
    }
    await _controller.play();
  }

  @override
  Widget build(BuildContext context) {
    const dark = XatBoxTokens.dark;
    final l10n = context.l10n;
    if (_failed) {
      return Icon(LucideIcons.videoOff, size: 48, color: dark.textTertiary);
    }
    return ValueListenableBuilder<ChatVideoValue>(
      valueListenable: _controller.value,
      builder: (context, v, _) {
        if (!v.initialized) {
          return SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: dark.textSecondary,
            ),
          );
        }
        final totalMs = v.duration.inMilliseconds.toDouble();
        final posMs = (_dragMs ?? v.position.inMilliseconds.toDouble()).clamp(
          0.0,
          totalMs <= 0 ? 0.0 : totalMs,
        );
        final label = TextStyle(
          color: dark.textPrimary,
          fontSize: 12,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
        return GestureDetector(
          key: const Key('chat_video_player'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _controls = !_controls),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: v.aspectRatio,
                  child: _controller.buildView(),
                ),
              ),
              if (v.buffering)
                Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: dark.textSecondary,
                  ),
                ),
              if (_controls) ...[
                Center(
                  child: IconButton.filled(
                    key: const Key('video_toggle'),
                    iconSize: 40,
                    tooltip: v.playing ? l10n.chatVideoPause : l10n.chatVideoPlay,
                    style: IconButton.styleFrom(
                      backgroundColor: dark.surface.withValues(alpha: 0.7),
                      foregroundColor: dark.textPrimary,
                    ),
                    onPressed: () => _toggle(v),
                    icon: Icon(v.playing ? LucideIcons.pause : LucideIcons.play),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Container(
                      color: dark.appBg.withValues(alpha: 0.6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.sm,
                        vertical: Space.xs,
                      ),
                      child: Row(
                        children: [
                          Text(
                            ChatFormat.duration(posMs.round()),
                            key: const Key('video_position'),
                            style: label,
                          ),
                          Expanded(
                            child: Slider(
                              key: const Key('video_seek'),
                              value: posMs,
                              max: totalMs <= 0 ? 1 : totalMs,
                              activeColor: dark.primary,
                              inactiveColor: dark.textTertiary,
                              onChanged: totalMs <= 0
                                  ? null
                                  : (x) => setState(() => _dragMs = x),
                              onChangeEnd: totalMs <= 0
                                  ? null
                                  : (x) async {
                                      await _controller.seekTo(
                                        Duration(milliseconds: x.round()),
                                      );
                                      if (mounted) setState(() => _dragMs = null);
                                    },
                            ),
                          ),
                          Text(
                            ChatFormat.duration(v.duration.inMilliseconds),
                            style: label,
                          ),
                          IconButton(
                            key: const Key('video_mute'),
                            tooltip: v.muted
                                ? l10n.chatVideoUnmute
                                : l10n.chatVideoMute,
                            color: dark.textPrimary,
                            onPressed: () => _controller.setMuted(!v.muted),
                            icon: Icon(
                              v.muted ? LucideIcons.volumeX : LucideIcons.volume2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
