import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_video.dart';

/// Scriptable [ChatVideoController]: records calls, never touches a plugin.
class FakeChatVideoController implements ChatVideoController {
  FakeChatVideoController({this.failInit = false});

  final bool failInit;
  final List<String> calls = [];
  final _value = ValueNotifier(const ChatVideoValue());

  void _set({bool? playing, bool? muted, Duration? position}) {
    final v = _value.value;
    _value.value = ChatVideoValue(
      initialized: true,
      playing: playing ?? v.playing,
      muted: muted ?? v.muted,
      position: position ?? v.position,
      duration: const Duration(seconds: 65),
    );
  }

  @override
  ValueListenable<ChatVideoValue> get value => _value;

  @override
  Future<void> initialize() async {
    calls.add('init');
    if (failInit) throw PlatformException(code: 'VideoError');
    _set();
  }

  @override
  Future<void> play() async {
    calls.add('play');
    _set(playing: true);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _set(playing: false);
  }

  @override
  Future<void> seekTo(Duration position) async {
    calls.add('seek:${position.inSeconds}');
    _set(position: position);
  }

  @override
  Future<void> setMuted(bool muted) async {
    calls.add('mute:$muted');
    _set(muted: muted);
  }

  @override
  Widget buildView() => const ColoredBox(color: Color(0xFF000000));

  @override
  Future<void> dispose() async => calls.add('dispose');
}
