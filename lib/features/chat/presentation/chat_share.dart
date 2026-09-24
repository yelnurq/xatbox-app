import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../../core/routing/link_router.dart';
import '../../../core/routing/routes.dart';
import '../../../shared/utils/diagnostic_log.dart';
import 'chat_providers.dart';

/// Text and files shared into XatBox from another app.
@immutable
class ChatShareContent {
  const ChatShareContent({this.text = '', this.files = const []});
  final String text;
  final List<ChatPickedFile> files;

  bool get isEmpty => text.trim().isEmpty && files.isEmpty;

  /// Maps `receive_sharing_intent` items: text and URLs become the message
  /// text, everything else a file (the plugin copies content:// streams into
  /// the app cache and hands over a path).
  static ChatShareContent fromShared(List<SharedMediaFile> shared) {
    final texts = <String>[];
    final files = <ChatPickedFile>[];
    void addText(String? value) {
      final v = value?.trim() ?? '';
      if (v.isNotEmpty && !texts.contains(v)) texts.add(v);
    }

    for (final s in shared) {
      switch (s.type) {
        case SharedMediaType.text || SharedMediaType.url:
          addText(s.path);
        case SharedMediaType.image ||
            SharedMediaType.video ||
            SharedMediaType.file:
          final path = s.path.startsWith('file://')
              ? Uri.parse(s.path).toFilePath()
              : s.path;
          if (path.isNotEmpty) files.add((path: path, name: p.basename(path)));
          addText(s.message);
      }
    }
    return ChatShareContent(text: texts.join('\n'), files: files);
  }
}

/// Where shared content comes from (the plugin on Android/iOS; fake in tests).
abstract class ChatShareSource {
  /// Content that launched the app (cold start), if any.
  Future<ChatShareContent?> initial();

  /// Content shared while the app is running.
  Stream<ChatShareContent> get shares;

  /// Forgets the handled intent so it is not delivered again.
  Future<void> reset();
}

class PluginChatShareSource implements ChatShareSource {
  @override
  Future<ChatShareContent?> initial() async {
    final media = await ReceiveSharingIntent.instance.getInitialMedia();
    return media.isEmpty ? null : ChatShareContent.fromShared(media);
  }

  @override
  Stream<ChatShareContent> get shares => ReceiveSharingIntent.instance
      .getMediaStream()
      .where((m) => m.isNotEmpty)
      .map(ChatShareContent.fromShared);

  @override
  Future<void> reset() async {
    await ReceiveSharingIntent.instance.reset();
  }
}

class NoChatShareSource implements ChatShareSource {
  const NoChatShareSource();

  @override
  Future<ChatShareContent?> initial() async => null;

  @override
  Stream<ChatShareContent> get shares => const Stream.empty();

  @override
  Future<void> reset() async {}
}

final chatShareSourceProvider = Provider<ChatShareSource>(
  // iOS: delivered by ios/ShareExtension; without that target the plugin
  // simply never has anything to hand over.
  (_) => !kIsWeb && (Platform.isAndroid || Platform.isIOS)
      ? PluginChatShareSource()
      : const NoChatShareSource(),
);

/// The share waiting for a target chat (survives the sign-in screen).
class ChatPendingShareNotifier extends Notifier<ChatShareContent?> {
  @override
  ChatShareContent? build() => null;

  void set(ChatShareContent? content) => state = content;
  void clear() => state = null;
}

final chatPendingShareProvider =
    NotifierProvider<ChatPendingShareNotifier, ChatShareContent?>(
      ChatPendingShareNotifier.new,
    );

/// Shared content handed to a conversation's composer, taken once.
class ChatSharePrefillNotifier extends Notifier<Map<String, ChatShareContent>> {
  @override
  Map<String, ChatShareContent> build() => const {};

  void put(String conversationId, ChatShareContent content) =>
      state = {...state, conversationId: content};

  ChatShareContent? take(String conversationId) {
    final content = state[conversationId];
    if (content != null) {
      state = Map.of(state)..remove(conversationId);
    }
    return content;
  }
}

final chatSharePrefillProvider =
    NotifierProvider<ChatSharePrefillNotifier, Map<String, ChatShareContent>>(
      ChatSharePrefillNotifier.new,
    );

/// Receives shares (cold start and while running) and opens the chat picker
/// once the user is signed in (through [pendingNavigationProvider]).
final chatShareIntakeProvider = Provider<void>((ref) {
  final source = ref.watch(chatShareSourceProvider);

  void handle(ChatShareContent? content) {
    if (!ref.mounted || content == null || content.isEmpty) return;
    ref.read(chatPendingShareProvider.notifier).set(content);
    final navigation = ref.read(pendingNavigationProvider.notifier);
    navigation.consume();
    navigation.request(Routes.chatShare);
    unawaited(
      source.reset().catchError(
        (Object e) => DiagnosticLog.warn('chat', 'share reset failed', error: e),
      ),
    );
  }

  unawaited(
    source.initial().then(handle).catchError(
      (Object e) => DiagnosticLog.warn('chat', 'initial share failed', error: e),
    ),
  );
  final sub = source.shares.listen(
    handle,
    onError: (Object e) =>
        DiagnosticLog.warn('chat', 'share stream failed', error: e),
  );
  ref.onDispose(sub.cancel);
});
