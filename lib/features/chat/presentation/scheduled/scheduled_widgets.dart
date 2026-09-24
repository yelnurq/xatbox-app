import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/state_view.dart';
import '../../data/chat_broadcast.dart';
import '../broadcast/broadcast_format.dart';
import '../broadcast/broadcast_providers.dart';
import '../chat_providers.dart';
import 'when_picker.dart';

/// «Отправить позже»: uploads the files now (the server claims them at send
/// time) and stores the message. True when it was scheduled.
Future<bool> scheduleMessageFlow(
  BuildContext context,
  WidgetRef ref, {
  required String conversationId,
  required String text,
  DateTime? at,
  bool whenOnline = false,
  List<ChatPickedFile> files = const [],
  String? replyToId,
  List<String> mentions = const [],
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final whenText = at == null ? '' : formatWhen(context, at);
  try {
    final repo = ref.read(chatRepositoryProvider);
    final ids = <String>[];
    for (final f in files) {
      final att = await repo.api.upload(
        conversationId,
        filePath: f.path,
        filename: f.name,
      );
      ids.add(att.id);
    }
    await ref
        .read(scheduledMessagesProvider(conversationId).notifier)
        .schedule(
          body: text,
          sendAt: at,
          whenOnline: whenOnline,
          attachmentIds: ids,
          replyToId: replyToId,
          mentions: mentions,
        );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          whenOnline
              ? l10n.scheduledWhenOnlineCreated
              : l10n.scheduledCreated(whenText),
        ),
      ),
    );
    return true;
  } on AppException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(broadcastErrorText(l10n, e))));
    return false;
  }
}

Future<void> openScheduledMessages(BuildContext context, String conversationId) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScheduledMessagesScreen(conversationId: conversationId),
      ),
    );

/// Strip above the composer: «2 запланированных сообщения».
class ScheduledIndicator extends StatelessWidget {
  const ScheduledIndicator({super.key, required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.primarySoft.withValues(alpha: 0.6),
      child: InkWell(
        key: const Key('composer_scheduled'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs + 2),
          child: Row(
            children: [
              Icon(LucideIcons.clock, size: 16, color: t.primary),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  context.l10n.scheduledBadge(count),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: t.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 16, color: t.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// «Запланированные» of one chat: edit text or time, send now, delete.
class ScheduledMessagesScreen extends ConsumerWidget {
  const ScheduledMessagesScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final state = ref.watch(scheduledMessagesProvider(conversationId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scheduledTitle)),
      body: state.when(
        loading: () => const StateView.loading(),
        error: (e, _) => _Empty(icon: LucideIcons.cloudOff, text: broadcastErrorText(l10n, e)),
        data: (items) => items.isEmpty
            ? _Empty(icon: LucideIcons.clock, text: l10n.scheduledEmpty)
            : ListView.separated(
                key: const Key('scheduled_list'),
                padding: const EdgeInsets.all(Space.md),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                itemBuilder: (context, i) => _ScheduledTile(
                  item: items[i],
                  conversationId: conversationId,
                ),
              ),
      ),
      backgroundColor: t.appBg,
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: t.textTertiary),
            const SizedBox(height: Space.md),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduledTile extends ConsumerWidget {
  const _ScheduledTile({required this.item, required this.conversationId});
  final ChatScheduledMessage item;
  final String conversationId;

  Future<void> _act(BuildContext context, WidgetRef ref, String action) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(scheduledMessagesProvider(conversationId).notifier);
    try {
      switch (action) {
        case 'send':
          await notifier.sendNow(item.id);
        case 'time':
          final at = await showWhenPicker(context, title: l10n.scheduledEditTime);
          if (at != null) await notifier.updateTime(item.id, at);
        case 'text':
          final ctrl = TextEditingController(text: item.body);
          final text = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.scheduledEditText),
              content: TextField(
                key: const Key('scheduled_text_field'),
                controller: ctrl,
                autofocus: true,
                minLines: 1,
                maxLines: 6,
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
                FilledButton(
                  key: const Key('scheduled_text_save'),
                  onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                  child: Text(l10n.save),
                ),
              ],
            ),
          );
          if (text != null && text != item.body && (text.isNotEmpty || item.attachments.isNotEmpty)) {
            await notifier.updateText(item.id, text);
          }
        case 'delete':
          await notifier.remove(item.id);
      }
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(broadcastErrorText(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final accent = item.failed ? t.danger : t.primary;
    return Container(
      key: ValueKey('scheduled_${item.id}'),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: t.cardRadius,
        border: Border.all(color: t.border, width: t.borderWidth),
      ),
      padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.xs, Space.smd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.failed
                    ? LucideIcons.circleAlert
                    : (item.whenOnline ? LucideIcons.wifi : LucideIcons.clock),
                size: 16,
                color: accent,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  item.whenOnlineTimedOut
                      ? l10n.scheduledWhenOnlineTimeout
                      : item.failed
                      ? l10n.scheduledFailed
                      : item.whenOnline
                      ? l10n.scheduledWhenOnline
                      : formatWhen(context, item.sendAt),
                  key: ValueKey('scheduled_when_${item.id}'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(color: accent, fontWeight: FontWeight.w600),
                ),
              ),
              PopupMenuButton<String>(
                key: ValueKey('scheduled_menu_${item.id}'),
                icon: Icon(LucideIcons.ellipsisVertical, color: t.textTertiary),
                onSelected: (a) => _act(context, ref, a),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    key: const Key('scheduled_send_now'),
                    value: 'send',
                    child: ListTile(
                      leading: const Icon(LucideIcons.send),
                      title: Text(l10n.scheduledSendNow),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    key: const Key('scheduled_edit_text'),
                    value: 'text',
                    child: ListTile(
                      leading: const Icon(LucideIcons.pencil),
                      title: Text(l10n.scheduledEditText),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    key: const Key('scheduled_edit_time'),
                    value: 'time',
                    child: ListTile(
                      leading: const Icon(LucideIcons.calendarClock),
                      title: Text(l10n.scheduledEditTime),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    key: const Key('scheduled_delete'),
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(LucideIcons.trash2, color: t.danger),
                      title: Text(l10n.chatDelete, style: TextStyle(color: t.danger)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (item.body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: Text(
                item.body,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: t.textPrimary),
              ),
            ),
          if (item.attachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Row(
                children: [
                  Icon(LucideIcons.paperclip, size: 14, color: t.textTertiary),
                  const SizedBox(width: Space.xs),
                  Text(
                    l10n.scheduledAttachments(item.attachments.length),
                    style: theme.textTheme.bodySmall?.copyWith(color: t.textTertiary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
