import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../../data/chat_models.dart';
import '../messenger2_providers.dart';

/// A sticker image (downloaded once, cached on disk); the emoji is shown
/// faintly while it loads and when it cannot be loaded (tap retries).
class ChatStickerImage extends ConsumerWidget {
  const ChatStickerImage({super.key, required this.sticker, this.size = 96});
  final ChatSticker sticker;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final file = ref.watch(chatStickerFileProvider(sticker.id));
    final dpr = MediaQuery.devicePixelRatioOf(context);
    Widget placeholder({bool failed = false}) {
      // The emoji only stands in for the picture: the sticker label below
      // already names it.
      final emoji = ExcludeSemantics(
        child: Center(
          child: Text(
            sticker.emoji.isEmpty ? '🙂' : sticker.emoji,
            style: TextStyle(
              fontSize: size * 0.42,
              color: t.textPrimary.withValues(alpha: failed ? 0.45 : 0.25),
            ),
          ),
        ),
      );
      if (!failed) return emoji;
      return Semantics(
        container: true,
        button: true,
        label: context.l10n.chatRetry,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => ref.invalidate(chatStickerFileProvider(sticker.id)),
          child: emoji,
        ),
      );
    }

    return Semantics(
      image: true,
      label: '${context.l10n.chatAttachmentSticker} ${sticker.emoji}'.trim(),
      child: SizedBox.square(
        dimension: size,
        child: file.when(
          data: (f) => Image.file(
            f,
            key: ValueKey('sticker_image_${sticker.id}'),
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            cacheWidth: (size * dpr).round(),
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => placeholder(failed: true),
          ),
          loading: placeholder,
          error: (_, _) => placeholder(failed: true),
        ),
      ),
    );
  }
}

/// The body of a `sticker` message: large, without a bubble.
class ChatStickerMessage extends StatelessWidget {
  const ChatStickerMessage({super.key, required this.message, this.size = 168});
  final ChatMessage message;
  final double size;

  /// The sticker of a message: the server's, or the id in the body (queued).
  static ChatSticker? stickerOf(ChatMessage m) {
    if (m.sticker != null) return m.sticker;
    final id = ChatSticker.idFromBody(m.body);
    return id == null ? null : ChatSticker(id: id);
  }

  @override
  Widget build(BuildContext context) {
    final sticker = stickerOf(message);
    if (sticker == null) {
      return Padding(
        padding: const EdgeInsets.all(Space.sm),
        child: Text(
          context.l10n.chatStickerUnavailable,
          style: TextStyle(color: context.tokens.textTertiary),
        ),
      );
    }
    return ChatStickerImage(
      key: ValueKey('sticker_message_${message.id}'),
      sticker: sticker,
      size: size,
    );
  }
}
