import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/permissions.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../calendar/data/calendar_models.dart';
import '../../calendar/presentation/calendar_providers.dart';
import '../../calls/data/call_models.dart';
import '../../calls/presentation/calls_providers.dart';
import '../../chat/data/chat_models.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../mail/data/mail_models.dart';
import '../../mail/presentation/mail_providers.dart';

/// Rows per «Сегодня» section.
const todayPreview = 3;

/// «Сегодня» only reads what the modules already load: the mail summary
/// (tab badge), the conversation list (chat badge), cached calendar windows
/// (synced by the calendar lifecycle), the missed-call count and the cached
/// call history. It never starts a request of its own; pull-to-refresh on
/// the screen asks the modules to refresh.

/// Unread messages of the Inbox: the live first page when the mail tab has
/// loaded it, else the cached first page.
final todayMailUnreadProvider = FutureProvider.autoDispose<List<MailListItem>>((
  ref,
) async {
  if (!ref.watch(hasPermissionProvider(Permissions.mailRead))) {
    return const [];
  }
  // Re-read when the unread count moves.
  ref.watch(mailSummaryProvider.select((s) => s.summary?.inboxUnreadTotal));
  final threads = ref.watch(mailThreadsModeProvider) ?? false;
  final query = MailListQuery(folder: MailFolderType.inbox, threads: threads);
  List<MailListItem> unread(Iterable<MailListItem> items) => [
    for (final m in items)
      if (!m.isRead || (m.threadUnread ?? 0) > 0) m,
  ].take(todayPreview).toList();
  if (ref.exists(mailListProvider(query))) {
    final live = ref.watch(mailListProvider(query));
    if (live.items.isNotEmpty) return unread(live.items);
  }
  final cached = await ref
      .read(mailRepositoryProvider)
      .cache
      .readList(MailFolderType.inbox);
  return unread(cached?.items ?? const []);
});

/// Chats with unread messages, most recent first.
final todayUnreadChatsProvider = Provider.autoDispose<List<ChatConversation>>((
  ref,
) {
  if (!ref.watch(chatEnabledProvider)) return const [];
  final items = ref.watch(conversationsProvider.select((s) => s.items));
  DateTime at(ChatConversation c) =>
      c.lastMessage?.createdAt ??
      c.updatedAt ??
      DateTime.fromMillisecondsSinceEpoch(0);
  return ([
    for (final c in items)
      if (!c.isSaved && (c.unread > 0 || c.settings.markedUnread)) c,
  ]..sort((a, b) => at(b).compareTo(at(a))));
});

/// Today's events that have not ended yet (cached windows).
final todayEventsProvider =
    Provider.autoDispose<AsyncValue<List<CalendarOccurrence>>>((ref) {
      if (!ref.watch(calendarEnabledProvider)) return const AsyncData([]);
      final today = ref.watch(calendarTodayProvider);
      final now = ref.watch(calendarClockProvider)();
      return ref
          .watch(calendarRangeProvider((from: today, to: today.addDays(1))))
          .whenData(
            (list) => [
              for (final o in list)
                if (o.end.isAfter(now) && !o.event.isCancelled) o,
            ]..sort((a, b) => a.start.compareTo(b.start)),
          );
    });

/// Missed calls since local midnight, from the cached (or live) history.
final todayMissedCallsProvider = FutureProvider.autoDispose<List<CallInfo>>((
  ref,
) async {
  if (!ref.watch(callsEnabledProvider)) return const [];
  ref.watch(missedCallsProvider);
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day);
  final calls = <CallInfo>[];
  for (final missedOnly in const [true, false]) {
    if (ref.exists(callsHistoryProvider(missedOnly))) {
      calls.addAll(ref.watch(callsHistoryProvider(missedOnly)).calls);
    }
    try {
      final cached = await ref
          .read(callsCacheProvider)
          .history(missedOnly: missedOnly);
      calls.addAll(cached?.calls ?? const []);
    } on Object catch (e) {
      DiagnosticLog.warn('today', 'calls cache unreadable', error: e);
    }
  }
  final seen = <String>{};
  return [
    for (final c in calls)
      if (c.outcome == CallOutcome.missed &&
          c.createdAt != null &&
          !c.createdAt!.toLocal().isBefore(midnight) &&
          seen.add(c.id))
        c,
  ]..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
});

/// Refreshes what the sections show (pull-to-refresh only).
Future<void> refreshToday(WidgetRef ref) async {
  final waits = <Future<void>>[];
  if (ref.read(hasPermissionProvider(Permissions.mailRead))) {
    waits.add(ref.read(mailSummaryProvider.notifier).refresh());
  }
  if (ref.read(chatEnabledProvider)) {
    waits.add(ref.read(conversationsProvider.notifier).refresh());
  }
  if (ref.read(calendarEnabledProvider)) {
    waits.add(
      ref
          .read(calendarSyncProvider.notifier)
          .sync(around: ref.read(calendarTodayProvider)),
    );
  }
  if (ref.read(callsEnabledProvider)) {
    waits.add(ref.read(missedCallsProvider.notifier).refresh());
  }
  await Future.wait(waits);
  ref.invalidate(todayMailUnreadProvider);
  ref.invalidate(todayMissedCallsProvider);
}

/// First name for the greeting ('' when unknown).
final todayFirstNameProvider = Provider.autoDispose<String>((ref) {
  final name = ref.watch(currentUserProvider)?.displayName.trim() ?? '';
  return name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
});
