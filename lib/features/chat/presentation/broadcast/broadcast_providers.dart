import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/localization/localization.dart';
import '../../data/chat_broadcast.dart';
import '../../data/chat_models.dart';
import '../../data/chat_reminder_notifications.dart';
import '../chat_formatters.dart';
import '../chat_providers.dart';

/// Channels, polls, scheduled messages and reminders: providers.

final chatBroadcastApiProvider = Provider<ChatBroadcastApi>(
  (ref) => ChatBroadcastApi(ref.watch(chatApiClientProvider)),
);

/// Local notification fallback of reminders (faked in tests).
final chatReminderNotifierProvider = Provider<ChatReminderNotifier>(
  (_) => LocalChatReminderNotifier(),
);

/// «Каналы организации» for a search query.
final channelDiscoverProvider = FutureProvider.autoDispose
    .family<({List<ChatChannelSummary> channels, bool hasMore}), String>(
      (ref, q) =>
          ref.watch(chatBroadcastApiProvider).listChannels(q: q.trim(), limit: 100),
    );

/// Voters of one option of a public poll.
final pollVotersProvider = FutureProvider.autoDispose
    .family<List<ChatPollVoter>, ({String messageId, int option})>(
      (ref, key) => ref
          .watch(chatBroadcastApiProvider)
          .pollVoters(key.messageId, option: key.option),
    );

/// Subscribers of a channel (admins), for a search query.
final channelSubscribersProvider = FutureProvider.autoDispose
    .family<({List<ChatMember> subscribers, int total}), ({String id, String q})>(
      (ref, key) => ref
          .watch(chatBroadcastApiProvider)
          .subscribers(key.id, q: key.q.trim(), limit: 200),
    );

/// The caller's unsent scheduled messages of one chat; reloads on
/// `scheduled.updated` from any of the user's devices.
class ScheduledMessagesNotifier
    extends AsyncNotifier<List<ChatScheduledMessage>> {
  ScheduledMessagesNotifier(this.conversationId);
  final String conversationId;

  ChatBroadcastApi get _api => ref.read(chatBroadcastApiProvider);

  @override
  Future<List<ChatScheduledMessage>> build() async {
    final repo = ref.watch(chatRepositoryProvider);
    final sub = repo.events.listen((ev) {
      if (ev.type == 'scheduled.updated' && ev.conversationId == conversationId) {
        unawaited(reload());
      }
    });
    ref.onDispose(sub.cancel);
    // The composer strip is optional: an older server or no network means
    // "nothing scheduled" (no error state, no provider retry loop).
    try {
      return await _api.listScheduled(conversationId);
    } on AppException {
      return const [];
    }
  }

  Future<void> reload() async {
    final next = await AsyncValue.guard(() => _api.listScheduled(conversationId));
    if (ref.mounted) state = next;
  }

  Future<ChatScheduledMessage> schedule({
    required String body,
    DateTime? sendAt,
    bool whenOnline = false,
    List<String> attachmentIds = const [],
    String? replyToId,
    List<String> mentions = const [],
  }) async {
    final created = await _api.schedule(
      conversationId,
      sendAt: sendAt,
      whenOnline: whenOnline,
      body: body,
      attachmentIds: attachmentIds,
      replyToId: replyToId,
      mentions: mentions,
    );
    await reload();
    return created;
  }

  Future<void> updateText(String id, String body) async {
    await _api.updateScheduled(id, body: body);
    await reload();
  }

  Future<void> updateTime(String id, DateTime sendAt) async {
    await _api.updateScheduled(id, sendAt: sendAt);
    await reload();
  }

  Future<void> remove(String id) async {
    await _api.deleteScheduled(id);
    await reload();
  }

  Future<void> sendNow(String id) async {
    await _api.sendScheduledNow(id);
    await reload();
  }
}

final scheduledMessagesProvider = AsyncNotifierProvider.autoDispose
    .family<ScheduledMessagesNotifier, List<ChatScheduledMessage>, String>(
      ScheduledMessagesNotifier.new,
    );

/// The user's reminders; reloads on `reminder.updated` / `reminder.fired`.
class ChatRemindersNotifier extends AsyncNotifier<List<ChatReminder>> {
  ChatBroadcastApi get _api => ref.read(chatBroadcastApiProvider);

  @override
  Future<List<ChatReminder>> build() async {
    final repo = ref.watch(chatRepositoryProvider);
    final sub = repo.events.listen((ev) {
      if (ev.type == 'reminder.updated' || ev.type == 'reminder.fired') {
        unawaited(reload());
      }
    });
    ref.onDispose(sub.cancel);
    return _api.listReminders();
  }

  Future<void> reload() async {
    final next = await AsyncValue.guard(_api.listReminders);
    if (ref.mounted) state = next;
  }

  Future<ChatReminder> create(ChatMessage message, DateTime at) async {
    final r = await _api.createReminder(message.id, remindAt: at);
    await reload();
    return r;
  }

  Future<void> reschedule(String id, DateTime at) async {
    await _api.updateReminder(id, remindAt: at);
    await reload();
  }

  Future<void> remove(String id) async {
    await _api.deleteReminder(id);
    await reload();
  }
}

final chatRemindersProvider =
    AsyncNotifierProvider<ChatRemindersNotifier, List<ChatReminder>>(
      ChatRemindersNotifier.new,
    );

/// Where and what a reminder is about, e.g. «Бухгалтерия: Отчёт к пятнице».
String reminderPreviewText(AppLocalizations l10n, ChatReminder r) {
  final where = r.conversationType == 'saved' ? l10n.chatSaved : r.conversationTitle;
  final what = r.message == null ? '' : ChatFormat.preview(l10n, r.message!);
  final text = [where, what].where((s) => s.isNotEmpty).join(': ');
  return r.note.isEmpty ? text : '${r.note} — $text';
}

/// Re-schedules the local notifications from the loaded reminders.
Future<void> syncReminderNotifications(
  WidgetRef ref,
  AppLocalizations l10n,
) async {
  final list = ref.read(chatRemindersProvider).value;
  if (list == null) return;
  await ref
      .read(chatReminderNotifierProvider)
      .sync(
        list,
        title: l10n.reminderNotificationTitle,
        bodyOf: (r) => reminderPreviewText(l10n, r),
      );
}
