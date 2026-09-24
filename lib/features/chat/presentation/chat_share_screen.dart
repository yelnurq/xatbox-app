import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/state_view.dart';
import '../data/chat_models.dart';
import 'chat_avatar.dart';
import 'chat_formatters.dart';
import 'chat_providers.dart';
import 'chat_share.dart';

/// Target picker for content shared from another app: search, «Избранное»
/// on top, then recent chats. The chosen chat opens with the composer
/// prefilled (text in the input, files above it).
class ChatShareScreen extends ConsumerStatefulWidget {
  const ChatShareScreen({super.key, this.onOpenConversation});

  /// Opens the chosen conversation (default: replace this route).
  final void Function(BuildContext context, String conversationId)?
  onOpenConversation;

  @override
  ConsumerState<ChatShareScreen> createState() => _ChatShareScreenState();
}

class _ChatShareScreenState extends ConsumerState<ChatShareScreen> {
  String _query = '';
  bool _busy = false;

  Future<void> _pick(ChatShareContent content, ChatConversation? conv) async {
    if (_busy) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final target =
          conv ?? await ref.read(chatRepositoryProvider).savedConversation();
      ref.read(chatSharePrefillProvider.notifier).put(target.id, content);
      ref.read(chatPendingShareProvider.notifier).clear();
      if (!mounted) return;
      final open = widget.onOpenConversation;
      if (open != null) {
        open(context, target.id);
      } else {
        GoRouter.of(
          context,
        ).pushReplacement(Routes.chatConversationPath(target.id));
      }
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ChatFormat.error(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final content = ref.watch(chatPendingShareProvider);
    final all = ref.watch(conversationsProvider.select((s) => s.items));
    final saved = all.where((c) => c.isSaved).firstOrNull;
    final q = _query.toLowerCase();
    final chats = all
        .where(
          (c) =>
              !c.isSaved &&
              !c.settings.archived &&
              (q.isEmpty ||
                  c.title.toLowerCase().contains(q) ||
                  (c.peer?.email.toLowerCase().contains(q) ?? false)),
        )
        .toList();
    final showSaved = q.isEmpty || l10n.chatSaved.toLowerCase().contains(q);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('share_close'),
          tooltip: l10n.close,
          icon: const Icon(LucideIcons.x),
          onPressed: () {
            ref.read(chatPendingShareProvider.notifier).clear();
            Navigator.of(context).maybePop();
          },
        ),
        title: Text(l10n.chatShareTitle),
      ),
      body: content == null || content.isEmpty
          ? StateView.empty(title: l10n.chatShareNothing, icon: LucideIcons.share2)
          : Column(
              children: [
                Container(
                  key: const Key('share_summary'),
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(
                    Space.md,
                    Space.sm,
                    Space.md,
                    Space.sm,
                  ),
                  padding: const EdgeInsets.all(Space.smd),
                  decoration: BoxDecoration(
                    color: t.surfaceSubtle,
                    borderRadius: BorderRadius.circular(t.radiusMd),
                    border: Border.all(color: t.border, width: t.borderWidth),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (content.files.isNotEmpty)
                        Row(
                          children: [
                            Icon(LucideIcons.paperclip, size: 16, color: t.primary),
                            const SizedBox(width: Space.xs),
                            Expanded(
                              child: Text(
                                '${l10n.chatShareFiles(content.files.length)}: '
                                '${content.files.map((f) => f.name).join(', ')}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      if (content.text.trim().isNotEmpty)
                        Text(
                          content.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: t.textSecondary),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.md),
                  child: TextField(
                    key: const Key('share_search'),
                    decoration: InputDecoration(
                      hintText: l10n.chatSearch,
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                    ),
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
                if (_busy) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(top: Space.sm),
                    children: [
                      if (showSaved)
                        ListTile(
                          key: const Key('share_pick_saved'),
                          leading: saved == null
                              ? const SavedMessagesAvatar()
                              : ChatAvatar(conversation: saved),
                          title: Text(l10n.chatSaved),
                          subtitle: Text(
                            l10n.chatSavedHint,
                            style: TextStyle(color: t.textTertiary),
                          ),
                          onTap: _busy ? null : () => _pick(content, saved),
                        ),
                      if (chats.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Space.md,
                            Space.md,
                            Space.md,
                            Space.xs,
                          ),
                          child: Text(
                            t.sectionLabel(l10n.chatShareRecent),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: t.textTertiary,
                                  letterSpacing: 0.6,
                                ),
                          ),
                        ),
                      for (final c in chats)
                        ListTile(
                          key: ValueKey('share_pick_${c.id}'),
                          leading: ChatAvatar(conversation: c),
                          title: Text(
                            c.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: _busy ? null : () => _pick(content, c),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
