import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/platform/desktop.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/state_view.dart';
import '../../data/chat_broadcast.dart';
import '../../data/chat_models.dart';
import '../broadcast/broadcast_format.dart';
import '../broadcast/broadcast_providers.dart';
import '../chat_providers.dart';
import '../scheduled/when_picker.dart';

Future<void> openRemindersScreen(BuildContext context) => Navigator.of(context).push(
  MaterialPageRoute<void>(builder: (_) => const RemindersScreen()),
);

/// «Напомнить» from the message menu: presets → `POST /messages/{id}/reminders`,
/// then the local notification fallback is refreshed.
Future<void> remindMessageFlow(BuildContext context, WidgetRef ref, ChatMessage message) async {
  final l10n = context.l10n;
  final at = await showWhenPicker(context, title: l10n.remindSheetTitle);
  if (at == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final whenText = formatWhen(context, at);
  try {
    await ref.read(chatRemindersProvider.notifier).create(message, at);
    messenger.showSnackBar(SnackBar(content: Text(l10n.reminderSetDone(whenText))));
    unawaited(syncReminderNotifications(ref, l10n));
  } on AppException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(broadcastErrorText(l10n, e))));
  }
}

/// «Напоминания»: upcoming and recently fired reminders; a tap opens the
/// chat at the message.
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(chatRemindersProvider.notifier).reload());
  }

  void _open(ChatReminder r) {
    ref.read(chatJumpRequestProvider.notifier).request(r.conversationId, r.messageId);
    final router = GoRouter.maybeOf(context);
    if (router != null) unawaited(router.push(Routes.chatConversationPath(r.conversationId)));
  }

  Future<void> _act(ChatReminder r, String action) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(chatRemindersProvider.notifier);
    try {
      switch (action) {
        case 'reschedule':
          final at = await showWhenPicker(context, title: l10n.reminderReschedule);
          if (at != null) await notifier.reschedule(r.id, at);
        case 'delete':
          await notifier.remove(r.id);
      }
      if (mounted) unawaited(syncReminderNotifications(ref, l10n));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(broadcastErrorText(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    ref.listen(chatRemindersProvider, (_, next) {
      if (next.hasValue) unawaited(syncReminderNotifications(ref, l10n));
    });
    final state = ref.watch(chatRemindersProvider);
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xs),
      child: Text(
        t.sectionLabel(text),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: t.textTertiary, fontWeight: FontWeight.w600),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.remindersTitle)),
      body: state.when(
        loading: () => const StateView.loading(),
        error: (e, _) => _Empty(icon: LucideIcons.cloudOff, title: broadcastErrorText(l10n, e)),
        data: (list) {
          if (list.isEmpty) {
            return _Empty(icon: LucideIcons.alarmClock, title: l10n.remindersEmpty, hint: (isDesktop ? l10n.remindersEmptyHintDesktop : l10n.remindersEmptyHint));
          }
          final upcoming = [for (final r in list) if (r.pending) r];
          final done = [for (final r in list) if (!r.pending) r];
          return RefreshIndicator(
            onRefresh: ref.read(chatRemindersProvider.notifier).reload,
            child: ListView(
              key: const Key('reminders_list'),
              children: [
                if (upcoming.isNotEmpty) header(l10n.remindersUpcoming),
                for (final r in upcoming) _tile(context, r),
                if (done.isNotEmpty) header(l10n.remindersDone),
                for (final r in done) _tile(context, r),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, ChatReminder r) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final when = formatWhen(context, r.pending ? r.remindAt : (r.firedAt ?? r.remindAt));
    final preview = r.message == null ? '' : reminderPreviewText(l10n, r);
    return ListTile(
      key: ValueKey('reminder_${r.id}'),
      onTap: () => _open(r),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: r.pending ? t.primarySoft : t.surfaceMuted,
          shape: BoxShape.circle,
        ),
        child: Icon(
          r.pending ? LucideIcons.alarmClock : LucideIcons.checkCheck,
          size: 20,
          color: r.pending ? t.primary : t.textTertiary,
        ),
      ),
      title: Text(
        when,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          color: r.pending ? t.textPrimary : t.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        preview,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(color: t.textTertiary),
      ),
      trailing: PopupMenuButton<String>(
        key: ValueKey('reminder_menu_${r.id}'),
        icon: Icon(LucideIcons.ellipsisVertical, color: t.textTertiary),
        onSelected: (a) => _act(r, a),
        itemBuilder: (_) => [
          PopupMenuItem(
            key: const Key('reminder_reschedule'),
            value: 'reschedule',
            child: ListTile(
              leading: const Icon(LucideIcons.calendarClock),
              title: Text(l10n.reminderReschedule),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            key: const Key('reminder_delete'),
            value: 'delete',
            child: ListTile(
              leading: Icon(LucideIcons.trash2, color: t.danger),
              title: Text(l10n.reminderDelete, style: TextStyle(color: t.danger)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, this.hint});
  final IconData icon;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: t.textTertiary),
            const SizedBox(height: Space.md),
            Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleSmall),
            if (hint != null) ...[
              const SizedBox(height: Space.xs),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: t.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
