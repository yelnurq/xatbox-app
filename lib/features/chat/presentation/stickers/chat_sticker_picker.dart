import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../../data/chat_messenger2.dart';
import '../chat_emoji_picker.dart';
import '../chat_providers.dart';
import '../messenger2_providers.dart';
import 'chat_sticker_view.dart';
import '../../../../shared/widgets/app_sheet.dart';

/// What the composer's picker returned: an emoji to insert or a sticker to send.
class ChatPickerResult {
  const ChatPickerResult.emoji(String this.emoji) : sticker = null;
  const ChatPickerResult.sticker(ChatSticker this.sticker) : emoji = null;
  final String? emoji;
  final ChatSticker? sticker;
}

/// Composer sheet with two tabs: «Эмодзи» (inserted into the text) and
/// «Стикеры» (recent + packs; long press previews, tap sends).
class ChatStickerPickerSheet extends ConsumerStatefulWidget {
  const ChatStickerPickerSheet({super.key, this.initialStickers = true});
  final bool initialStickers;

  static Future<ChatPickerResult?> show(
    BuildContext context, {
    bool stickers = true,
  }) => showAppSheet<ChatPickerResult>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => ChatStickerPickerSheet(initialStickers: stickers),
  );

  @override
  ConsumerState<ChatStickerPickerSheet> createState() =>
      _ChatStickerPickerSheetState();
}

class _ChatStickerPickerSheetState extends ConsumerState<ChatStickerPickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialStickers ? 1 : 0,
  );

  /// Selected pack id; '' = recent.
  String? _pack;
  OverlayEntry? _preview;

  @override
  void dispose() {
    _hidePreview();
    _tabs.dispose();
    super.dispose();
  }

  void _showPreview(ChatSticker s) {
    _hidePreview();
    unawaited(HapticFeedback.selectionClick());
    final t = context.tokens;
    _preview = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: ColoredBox(
          color: t.textPrimary.withValues(alpha: 0.25),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.7, end: 1),
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChatStickerImage(
                    key: const Key('sticker_preview'),
                    sticker: s,
                    size: 240,
                  ),
                  if (s.emoji.isNotEmpty)
                    Text(s.emoji, style: const TextStyle(fontSize: 28)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_preview!);
  }

  void _hidePreview() {
    _preview?.remove();
    _preview = null;
  }

  void _pick(ChatSticker s) {
    unawaited(ref.read(chatRecentStickersProvider.notifier).use(s));
    Navigator.pop(context, ChatPickerResult.sticker(s));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.55,
        child: Column(
          children: [
            TabBar(
              controller: _tabs,
              labelColor: t.primary,
              unselectedLabelColor: t.textTertiary,
              indicatorColor: t.primary,
              tabs: [
                Tab(
                  key: const Key('picker_tab_emoji'),
                  icon: const Icon(LucideIcons.smile, size: 20),
                  text: l10n.chatEmoji,
                ),
                Tab(
                  key: const Key('picker_tab_stickers'),
                  icon: const Icon(LucideIcons.sticker, size: 20),
                  text: l10n.chatStickers,
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [_emojiTab(context), _stickersTab(context)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emojiTab(BuildContext context) {
    final t = context.tokens;
    final recent = ref.watch(chatRecentEmojiProvider);
    Widget grid(List<String> emoji, String prefix) => SliverPadding(
      padding: const EdgeInsets.all(Space.sm),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 46,
          mainAxisExtent: 46,
        ),
        itemCount: emoji.length,
        itemBuilder: (context, i) => InkWell(
          key: ValueKey('${prefix}_${emoji[i]}'),
          borderRadius: BorderRadius.circular(t.radiusSm),
          onTap: () {
            unawaited(ref.read(chatRecentEmojiProvider.notifier).use(emoji[i]));
            Navigator.pop(context, ChatPickerResult.emoji(emoji[i]));
          },
          child: Center(
            child: Text(emoji[i], style: const TextStyle(fontSize: 26)),
          ),
        ),
      ),
    );
    return CustomScrollView(
      key: const Key('composer_emoji_grid'),
      slivers: [
        if (recent.isNotEmpty) grid(recent, 'composer_emoji_recent'),
        for (final g in chatEmojiGroups) grid(g, 'composer_emoji'),
      ],
    );
  }

  Widget _stickersTab(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final packs = ref.watch(chatStickerPacksProvider);
    final recent = ref.watch(chatRecentStickersProvider);
    return packs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _emptyStickers(context, retry: true),
      data: (list) {
        if (list.isEmpty && recent.isEmpty) return _emptyStickers(context);
        final selected =
            _pack ?? (recent.isNotEmpty ? '' : list.firstOrNull?.id ?? '');
        final pack = list.where((p) => p.id == selected).firstOrNull;
        final stickers = selected.isEmpty ? recent : (pack?.stickers ?? []);
        return Column(
          children: [
            SizedBox(
              height: 52,
              child: ListView(
                key: const Key('sticker_pack_bar'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                children: [
                  if (recent.isNotEmpty)
                    _PackTab(
                      key: const Key('sticker_pack_recent'),
                      selected: selected.isEmpty,
                      tooltip: l10n.chatStickersRecent,
                      onTap: () => setState(() => _pack = ''),
                      child: Icon(LucideIcons.clock, color: t.textSecondary),
                    ),
                  for (final p in list)
                    _PackTab(
                      key: ValueKey('sticker_pack_${p.id}'),
                      selected: selected == p.id,
                      tooltip: p.title,
                      onTap: () => setState(() => _pack = p.id),
                      child: _cover(p),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: t.divider),
            if (pack != null || selected.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.md,
                  Space.sm,
                  Space.md,
                  0,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    selected.isEmpty ? l10n.chatStickersRecent : pack!.title,
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: t.textTertiary),
                  ),
                ),
              ),
            Expanded(
              child: GridView.builder(
                key: const Key('sticker_grid'),
                padding: const EdgeInsets.all(Space.sm),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 84,
                  mainAxisSpacing: Space.xs,
                  crossAxisSpacing: Space.xs,
                ),
                itemCount: stickers.length,
                itemBuilder: (context, i) {
                  final s = stickers[i];
                  return GestureDetector(
                    key: ValueKey('sticker_${s.id}'),
                    onTap: () => _pick(s),
                    onLongPressStart: (_) => _showPreview(s),
                    onLongPressEnd: (_) => _hidePreview(),
                    onLongPressCancel: _hidePreview,
                    child: Padding(
                      padding: const EdgeInsets.all(Space.xxs),
                      child: ChatStickerImage(sticker: s, size: 76),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _cover(ChatStickerPack p) {
    final cover =
        p.stickers.where((s) => s.id == p.coverStickerId).firstOrNull ??
        p.stickers.firstOrNull;
    return cover == null
        ? const Icon(LucideIcons.sticker)
        : ChatStickerImage(sticker: cover, size: 34);
  }

  Widget _emptyStickers(BuildContext context, {bool retry = false}) {
    final t = context.tokens;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.sticker, size: 40, color: t.textTertiary),
          const SizedBox(height: Space.sm),
          Text(
            context.l10n.chatStickersEmpty,
            style: TextStyle(color: t.textSecondary),
          ),
          if (retry)
            TextButton(
              onPressed: () => ref.invalidate(chatStickerPacksProvider),
              child: Text(context.l10n.chatTranscriptRetry),
            ),
        ],
      ),
    );
  }
}

class _PackTab extends StatelessWidget {
  const _PackTab({
    super.key,
    required this.selected,
    required this.tooltip,
    required this.onTap,
    required this.child,
  });
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: Space.xs),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: selected ? t.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(t.radiusSm),
          child: InkWell(
            borderRadius: BorderRadius.circular(t.radiusSm),
            onTap: onTap,
            child: SizedBox(width: 44, height: 44, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}
