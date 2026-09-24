import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/notifications/exact_alarms.dart';
import '../../../core/notifications/local_notification_hub.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../calendar/domain/calendar_time.dart';
import 'chat_broadcast.dart';
import 'push_notifications.dart';

/// Android channel of message reminders (local fallback and server pushes).
const chatRemindersChannelId = 'chat_reminders';

/// Local notifications for «Напомнить», so a reminder fires even without a
/// push (no Firebase, no network). The server push of the same reminder uses
/// the same notification id and replaces it.
abstract class ChatReminderNotifier {
  Future<void> sync(
    List<ChatReminder> reminders, {
    required String title,
    required String Function(ChatReminder reminder) bodyOf,
  });
}

class NoopChatReminderNotifier implements ChatReminderNotifier {
  const NoopChatReminderNotifier();

  @override
  Future<void> sync(
    List<ChatReminder> reminders, {
    required String title,
    required String Function(ChatReminder reminder) bodyOf,
  }) async {}
}

/// Reminders that need a local notification: pending and still ahead.
List<ChatReminder> localReminderTargets(
  List<ChatReminder> reminders,
  DateTime now,
) => [
  for (final r in reminders)
    if (r.pending && r.remindAt.isAfter(now)) r,
];

int chatReminderNotificationId(String reminderId) =>
    stableNotificationId('reminder:$reminderId');

/// Tap payload in the push format, so the chat push service opens the chat.
String chatReminderPayload(ChatReminder r) =>
    LocalNotificationHub.pushPayloadPrefix +
    jsonEncode({
      'type': 'chat.reminder',
      'conversation_id': r.conversationId,
      'message_id': r.messageId,
      'kind': 'reminder',
    });

class LocalChatReminderNotifier implements ChatReminderNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();

  @override
  Future<void> sync(
    List<ChatReminder> reminders, {
    required String title,
    required String Function(ChatReminder reminder) bodyOf,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      CalendarZones.ensureInitialized();
      await LocalNotificationHub.ensureInitialized();
      final wanted = {
        for (final r in localReminderTargets(reminders, DateTime.now()))
          chatReminderNotificationId(r.id): r,
      };
      for (final p in await _plugin.pendingNotificationRequests()) {
        final ours = (p.payload ?? '').contains('"chat.reminder"');
        if (ours && !wanted.containsKey(p.id)) await _plugin.cancel(id: p.id);
      }
      // Exact when allowed (USE_EXACT_ALARM on 13+, SCHEDULE_EXACT_ALARM on
      // 12); an inexact alarm may come many minutes late in Doze.
      final exact = await canScheduleExactReminders(_plugin);
      for (final e in wanted.entries) {
        await scheduleWithExactFallback(
          exact: exact,
          schedule: (mode) => _schedule(e.key, e.value, title, bodyOf, mode),
        );
      }
    } on Object catch (e) {
      DiagnosticLog.warn('chat', 'reminder notifications sync failed', error: e);
    }
  }

  Future<void> _schedule(
    int id,
    ChatReminder reminder,
    String title,
    String Function(ChatReminder reminder) bodyOf,
    AndroidScheduleMode mode,
  ) => _plugin.zonedSchedule(
          id: id,
          title: title,
          body: bodyOf(reminder),
          payload: chatReminderPayload(reminder),
          scheduledDate: tz.TZDateTime.from(reminder.remindAt.toUtc(), tz.UTC),
          androidScheduleMode: mode,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              chatRemindersChannelId,
              title,
              tag: 'reminder:${reminder.id}',
              importance: Importance.high,
              priority: Priority.high,
              category: AndroidNotificationCategory.reminder,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
            ),
          ),
        );
}
