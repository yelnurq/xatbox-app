import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/localization.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/widgets/ds/x_badge.dart';
import '../../../core/auth/auth_providers.dart';
import '../../calendar/data/calendar_models.dart';
import '../../calendar/presentation/calendar_providers.dart';
import '../../calendar/presentation/calendar_widgets.dart';
import '../../calls/data/meetings.dart';
import '../../calls/presentation/calls_format.dart';
import '../../calls/presentation/calls_providers.dart';
import '../../chat/presentation/chat_avatar.dart';
import '../../chat/presentation/chat_formatters.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../mail/presentation/mail_providers.dart';
import '../../../core/auth/permissions.dart';
import '../../official/presentation/official_providers.dart';
import '../../tasks/data/task_models.dart';
import '../../tasks/presentation/tasks_format.dart';
import '../../tasks/presentation/tasks_providers.dart';
import 'today_providers.dart';

/// One «Сегодня» section. A builder returns [SizedBox.shrink] when its module
/// is unavailable (permission, service not configured) or has nothing today.
typedef TodaySectionBuilder = Widget Function(BuildContext context);

/// EXTENSION POINT — the sections of «Сегодня», top to bottom (the greeting
/// and the quick actions frame them). A new module adds ONE line here, e.g.
///
/// ```dart
///   (_) => const OfficialTodaySection(), // lib/features/official
///   (_) => const TasksTodaySection(),    // lib/features/tasks
/// ```
///
/// using [TodayCard] for a consistent look and only providers its module
/// already loads (no extra network on start). Tests may override the list.
final todaySectionsProvider = Provider<List<TodaySectionBuilder>>(
  (ref) => [
    (_) => const TodayMailSection(),
    (_) => const TodayChatsSection(),
    (_) => const TodayEventsSection(),
    (_) => const TodayMissedCallsSection(),
    (_) => const TodayOfficialSection(),
    (_) => const TodayTasksSection(),
  ],
);

/// Card of a «Сегодня» section: icon, title, count pill, «Открыть» and rows.
class TodayCard extends StatelessWidget {
  const TodayCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.count = 0,
    this.onOpen,
    this.empty,
  });

  final IconData icon;
  final String title;
  final int count;
  final VoidCallback? onOpen;

  /// Shown instead of [children] when they are empty (null = no body).
  final String? empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.smd),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                Space.smd,
                Space.sm,
                Space.xs,
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: t.primary),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(title, style: text.titleSmall),
                    ),
                  ),
                  if (count > 0) CountPill(count),
                  if (onOpen != null)
                    Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: t.textTertiary,
                    ),
                ],
              ),
            ),
          ),
          if (children.isEmpty && empty != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                Space.xs,
                Space.md,
                Space.smd,
              ),
              child: Text(
                empty!,
                style: text.bodySmall?.copyWith(color: t.textTertiary),
              ),
            ),
          ...children,
          if (children.isNotEmpty) const SizedBox(height: Space.xs),
        ],
      ),
    );
  }
}

class TodayMailSection extends ConsumerWidget {
  const TodayMailSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(hasPermissionProvider(Permissions.mailRead))) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final t = context.tokens;
    final count = ref.watch(mailUnreadBadgeProvider);
    final items = ref.watch(todayMailUnreadProvider).value ?? const [];
    final locale = Localizations.localeOf(context).toLanguageTag();
    return TodayCard(
      key: const Key('today_mail'),
      icon: LucideIcons.mail,
      title: l10n.todayMailTitle,
      count: count,
      onOpen: () => context.go(Routes.mail),
      empty: count == 0 ? l10n.todayMailEmpty : null,
      children: [
        for (final m in items)
          ListTile(
            key: ValueKey('today_mail_${m.id}'),
            dense: true,
            title: Text(
              m.subject.isEmpty ? l10n.searchNoSubject : m.subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              m.fromDisplay.isNotEmpty ? m.fromDisplay : m.from,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.textSecondary),
            ),
            trailing: Text(
              FormatUtils.listDate(m.date, locale),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: t.textTertiary),
            ),
            onTap: () => context.push(Routes.mailMessagePath(m.id)),
          ),
      ],
    );
  }
}

class TodayChatsSection extends ConsumerWidget {
  const TodayChatsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(chatEnabledProvider)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final t = context.tokens;
    final chats = ref.watch(todayUnreadChatsProvider);
    return TodayCard(
      key: const Key('today_chats'),
      icon: LucideIcons.messageCircle,
      title: l10n.todayChatsTitle,
      count: chats.length,
      onOpen: () => context.go(Routes.chat),
      empty: l10n.todayChatsEmpty,
      children: [
        for (final c in chats.take(todayPreview))
          ListTile(
            key: ValueKey('today_chat_${c.id}'),
            leading: ChatAvatar(conversation: c, radius: 18),
            title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: c.lastMessage == null
                ? null
                : Text(
                    ChatFormat.preview(l10n, c.lastMessage!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: t.textSecondary),
                  ),
            trailing: c.unread > 0 ? CountPill(c.unread) : null,
            onTap: () => context.push(Routes.chatConversationPath(c.id)),
          ),
      ],
    );
  }
}

class TodayEventsSection extends ConsumerWidget {
  const TodayEventsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(calendarEnabledProvider)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final events = ref.watch(todayEventsProvider).value ?? const [];
    return TodayCard(
      key: const Key('today_events'),
      icon: LucideIcons.calendarDays,
      title: l10n.todayEventsTitle,
      count: events.length,
      onOpen: () => context.go(Routes.calendar),
      empty: l10n.todayEventsEmpty,
      children: [
        for (final o in events)
          OccurrenceTile(
            occurrence: o,
            trailing: _JoinButton(occurrence: o),
          ),
      ],
    );
  }
}

/// «Подключиться» for events with a call link: a XatBox meeting opens the
/// pre-join screen, another conference link opens outside the app.
class _JoinButton extends ConsumerWidget {
  const _JoinButton({required this.occurrence});
  final CalendarOccurrence occurrence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = occurrence.event;
    final code = XatBoxMeetingLinks.meetingCodeIn(
      '${e.meetingLink}\n${e.description}',
    );
    final link = Uri.tryParse(e.meetingLink.trim());
    final external =
        link != null && (link.scheme == 'https' || link.scheme == 'http');
    if (code == null && !external) return const SizedBox.shrink();
    return FilledButton.tonal(
      key: Key('today_join_${occurrence.key}'),
      onPressed: () {
        if (code != null) {
          context.push(Routes.meetPath(code));
        } else {
          launchUrl(link!, mode: LaunchMode.externalApplication);
        }
      },
      child: Text(context.l10n.todayJoin),
    );
  }
}

class TodayMissedCallsSection extends ConsumerWidget {
  const TodayMissedCallsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(callsEnabledProvider)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final t = context.tokens;
    final selfId = ref.watch(currentUserProvider)?.id ?? '';
    final calls = ref.watch(todayMissedCallsProvider).value ?? const [];
    return TodayCard(
      key: const Key('today_calls'),
      icon: LucideIcons.phoneMissed,
      title: l10n.todayMissedCallsTitle,
      count: calls.length,
      onOpen: () => context.go(Routes.calls),
      empty: l10n.todayMissedCallsEmpty,
      children: [
        for (final c in calls.take(todayPreview))
          ListTile(
            key: ValueKey('today_call_${c.id}'),
            dense: true,
            leading: Icon(LucideIcons.phoneMissed, color: t.danger),
            title: Text(
              c.displayTitle(selfId),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              CallsFormat.time(context, c.createdAt),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: t.textTertiary),
            ),
            onTap: () => context.push(Routes.callDetailsPath(c.id), extra: c),
          ),
      ],
    );
  }
}

/// Unread official messages, those awaiting «Ознакомлен(а)» first. Hidden
/// when there is nothing unread (a quiet day should not show an empty card).
class TodayOfficialSection extends ConsumerWidget {
  const TodayOfficialSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(officialEnabledProvider)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final t = context.tokens;
    final unread = [
      ...ref.watch(officialProvider.select((s) => s.messages)).where((m) => !m.isRead || m.awaitsAcknowledgement),
    ]..sort((a, b) => (b.awaitsAcknowledgement ? 1 : 0) - (a.awaitsAcknowledgement ? 1 : 0));
    if (unread.isEmpty) return const SizedBox.shrink();
    return TodayCard(
      key: const Key('today_official'),
      icon: LucideIcons.megaphone,
      title: l10n.officialTitle,
      count: unread.length,
      onOpen: () => context.push(Routes.official),
      children: [
        for (final m in unread.take(todayPreview))
          ListTile(
            key: ValueKey('today_official_${m.id}'),
            dense: true,
            title: Text(
              m.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: m.isRead ? null : const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: m.awaitsAcknowledgement
                ? Text(l10n.officialRequiresAck, style: TextStyle(color: t.primary))
                : null,
            onTap: () => context.push(Routes.officialMessagePath(m.id)),
          ),
      ],
    );
  }
}

/// The caller's own open tasks that are overdue or due today.
class TodayTasksSection extends ConsumerWidget {
  const TodayTasksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(tasksEnabledProvider)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final t = context.tokens;
    final locale = Localizations.localeOf(context).toString();
    final now = ref.read(tasksClockProvider)();
    final selfId = ref.watch(currentUserProvider)?.id ?? '';
    final tasks = ref.watch(tasksProvider.select((s) => s.tasks));
    final urgent = TaskSections.of(tasks, selfId).mine.where((x) => x.isOverdue(now) || x.isDueToday(now)).toList();
    return TodayCard(
      key: const Key('today_tasks'),
      icon: LucideIcons.listTodo,
      title: l10n.tasksScreenTitle,
      count: urgent.length,
      onOpen: () => context.go(Routes.tasks),
      empty: l10n.tasksEmpty,
      children: [
        for (final task in urgent.take(todayPreview))
          ListTile(
            key: ValueKey('today_task_${task.id}'),
            dense: true,
            title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text(
              task.isOverdue(now) ? l10n.tasksOverdue : TasksFormat.time(task.dueAt!, locale),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: task.isOverdue(now) ? t.danger : t.textTertiary,
              ),
            ),
            onTap: () => context.push(Routes.taskPath(task.id)),
          ),
      ],
    );
  }
}
