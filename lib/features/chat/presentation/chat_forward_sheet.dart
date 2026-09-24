import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/state_view.dart';
import '../data/chat_models.dart';
import 'chat_avatar.dart';
import 'chat_providers.dart';
import '../../../shared/widgets/app_sheet.dart';

/// Pick one or several chats to forward messages to, with search.
class ChatForwardSheet extends ConsumerStatefulWidget {
  const ChatForwardSheet({super.key});

  static Future<List<ChatConversation>?> show(BuildContext context) =>
      showAppSheet<List<ChatConversation>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const ChatForwardSheet(),
      );

  @override
  ConsumerState<ChatForwardSheet> createState() => _ChatForwardSheetState();
}

class _ChatForwardSheetState extends ConsumerState<ChatForwardSheet> {
  final _selected = <String, ChatConversation>{};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final q = _query.toLowerCase();
    final chats = ref
        .watch(conversationsProvider.select((s) => s.items))
        .where(
          (c) =>
              q.isEmpty ||
              c.title.toLowerCase().contains(q) ||
              (c.peer?.email.toLowerCase().contains(q) ?? false),
        )
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.md,
                  0,
                  Space.md,
                  Space.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.chatForwardTo,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: Space.sm),
                    TextField(
                      key: const Key('forward_search'),
                      decoration: InputDecoration(
                        hintText: l10n.chatSearch,
                        prefixIcon: const Icon(LucideIcons.search, size: 18),
                      ),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: chats.isEmpty
                    ? StateView.empty(
                        title: l10n.chatSearchNoResults,
                        icon: LucideIcons.searchX,
                      )
                    : ListView.builder(
                        itemCount: chats.length,
                        itemBuilder: (context, i) {
                          final c = chats[i];
                          final on = _selected.containsKey(c.id);
                          return ListTile(
                            key: ValueKey('forward_pick_${c.id}'),
                            leading: ChatAvatar(conversation: c),
                            title: Text(
                              c.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              child: Icon(
                                on ? LucideIcons.circleCheck : LucideIcons.circle,
                                key: ValueKey(on),
                                color: on ? t.primary : t.textTertiary,
                              ),
                            ),
                            selected: on,
                            selectedTileColor: t.surfaceSelected,
                            onTap: () => setState(() {
                              if (_selected.remove(c.id) == null) {
                                _selected[c.id] = c;
                              }
                            }),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(Space.md),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('forward_send'),
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.pop(
                            context,
                            _selected.values.toList(),
                          ),
                    icon: const Icon(LucideIcons.forward, size: 18),
                    label: Text(
                      _selected.isEmpty
                          ? l10n.chatForward
                          : '${l10n.chatForward} · ${_selected.length}',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
