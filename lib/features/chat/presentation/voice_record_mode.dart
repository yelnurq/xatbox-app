import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/desktop.dart';
import '../data/chat_cache.dart';
import 'chat_providers.dart';

/// «Запись голосовых»: hold the mic (default) or tap to start a locked
/// recording with stop / send / cancel buttons.
enum ChatVoiceRecordMode {
  hold,
  tap;

  static ChatVoiceRecordMode parse(String? raw) =>
      raw == 'tap' ? ChatVoiceRecordMode.tap : ChatVoiceRecordMode.hold;

  /// With a screen reader a hold gesture is unusable, and a mouse is no
  /// finger (no slide to cancel / lock): tap mode is forced.
  static ChatVoiceRecordMode effective(
    BuildContext context,
    ChatVoiceRecordMode chosen,
  ) => isDesktop || MediaQuery.accessibleNavigationOf(context)
      ? ChatVoiceRecordMode.tap
      : chosen;
}

/// Device preference, kept across sign-outs like the other chat prefs.
class ChatVoiceRecordModeNotifier extends Notifier<ChatVoiceRecordMode> {
  bool _touched = false;

  @override
  ChatVoiceRecordMode build() {
    final cache = ref.watch(chatCacheProvider);
    unawaited(
      cache.readMeta(ChatCache.prefVoiceRecordMode).then((v) {
        if (ref.mounted && !_touched) state = ChatVoiceRecordMode.parse(v);
      }),
    );
    return ChatVoiceRecordMode.hold;
  }

  Future<void> set(ChatVoiceRecordMode mode) async {
    _touched = true;
    state = mode;
    await ref
        .read(chatCacheProvider)
        .writeMeta(ChatCache.prefVoiceRecordMode, mode.name);
  }
}

final chatVoiceRecordModeProvider =
    NotifierProvider<ChatVoiceRecordModeNotifier, ChatVoiceRecordMode>(
      ChatVoiceRecordModeNotifier.new,
    );
