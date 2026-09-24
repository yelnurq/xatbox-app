import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import 'chat_providers.dart';
import '../../../shared/widgets/app_sheet.dart';

/// Common emoji for reactions, grouped like the system keyboards.
const chatEmojiGroups = <List<String>>[
  // smileys
  [
    '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃', '😉', '😊', //
    '😇', '🥰', '😍', '🤩', '😘', '😗', '😚', '😙', '😋', '😛', '😜', '🤪',
    '😝', '🤑', '🤗', '🤭', '🤫', '🤔', '🤐', '🤨', '😐', '😑', '😶', '😏',
    '😒', '🙄', '😬', '😌', '😔', '😪', '🤤', '😴', '😷', '🤒', '🤕', '🤢',
    '🤮', '🥵', '🥶', '🥴', '😵', '🤯', '🤠', '🥳', '😎', '🤓', '🧐', '😕',
    '😟', '🙁', '😮', '😯', '😲', '😳', '🥺', '😦', '😧', '😨', '😰', '😥',
    '😢', '😭', '😱', '😖', '😣', '😞', '😓', '😩', '😫', '🥱', '😤', '😡',
    '😠', '🤬', '😈', '💀', '💩', '🤡', '👻', '👽', '🤖', '😺', '😸', '😹',
  ],
  // gestures and people
  [
    '👍', '👎', '👌', '🤌', '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉', '👆', //
    '👇', '☝️', '✋', '🤚', '🖐️', '🖖', '👋', '🤝', '🙏', '✍️', '💪', '👏',
    '🙌', '👐', '🤲', '🫶', '👀', '🧠', '🙋', '🤷', '🤦', '🙅', '🙆', '💁',
  ],
  // hearts and symbols
  [
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔', '❣️', '💕', //
    '💞', '💓', '💗', '💖', '💘', '💝', '💯', '✅', '❌', '❓', '❗', '⚠️',
    '🔥', '✨', '⭐', '🌟', '⚡', '💥', '💤', '💬', '👁️‍🗨️', '🎉', '🎊', '🎁',
  ],
  // work and things
  [
    '📌', '📎', '📝', '📅', '📆', '⏰', '⌛', '📞', '💻', '🖥️', '⌨️', '🖨️', //
    '📧', '📨', '📦', '📊', '📈', '📉', '🗂️', '📁', '🔒', '🔑', '💡', '🔔',
    '☕', '🍵', '🍕', '🍰', '🎂', '🍎', '🏆', '🥇', '🚀', '✈️', '🚗', '🏠',
  ],
];

/// Bottom sheet with recent emoji and the full grid; pops the chosen emoji.
class ChatEmojiPickerSheet extends ConsumerWidget {
  const ChatEmojiPickerSheet({super.key});

  static Future<String?> show(BuildContext context) =>
      showAppSheet<String>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => const ChatEmojiPickerSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final recent = ref.watch(chatRecentEmojiProvider);
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: t.textTertiary);

    Widget grid(List<String> emoji, String keyPrefix) => SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 48,
        mainAxisExtent: 48,
      ),
      itemCount: emoji.length,
      itemBuilder: (context, i) => InkWell(
        key: ValueKey('${keyPrefix}_${emoji[i]}'),
        borderRadius: BorderRadius.circular(t.radiusSm),
        onTap: () => Navigator.pop(context, emoji[i]),
        child: Center(
          child: Text(emoji[i], style: const TextStyle(fontSize: 26)),
        ),
      ),
    );

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.55,
        child: CustomScrollView(
          key: const Key('chat_emoji_picker'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              sliver: SliverToBoxAdapter(
                child: Text(l10n.chatEmojiRecent, style: labelStyle),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(Space.sm),
              sliver: grid(recent, 'emoji_recent'),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              sliver: SliverToBoxAdapter(
                child: Text(l10n.chatEmojiAll, style: labelStyle),
              ),
            ),
            for (final group in chatEmojiGroups)
              SliverPadding(
                padding: const EdgeInsets.all(Space.sm),
                sliver: grid(group, 'emoji'),
              ),
          ],
        ),
      ),
    );
  }
}
