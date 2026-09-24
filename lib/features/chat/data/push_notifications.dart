import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/notifications/local_notification_hub.dart';
import '../../../core/platform/desktop.dart';
import '../../../shared/utils/diagnostic_log.dart';
import 'chat_notification_actions.dart';
import 'desktop_notifications.dart';

/// Local rendering of decrypted pushes (encrypted FCM messages are data-only,
/// so Android shows nothing by itself). Also creates the notification
/// channels the server targets.
const chatMessagesChannelId = 'chat_messages';
const callsChannelId = 'calls';
const calendarChannelId = 'calendar';

const _channels = [
  AndroidNotificationChannel(
    chatMessagesChannelId,
    'Сообщения',
    description: 'Новые сообщения в чатах',
    importance: Importance.high,
  ),
  AndroidNotificationChannel(
    callsChannelId,
    'Звонки',
    description: 'Входящие и пропущенные звонки',
    importance: Importance.max,
  ),
  AndroidNotificationChannel(
    calendarChannelId,
    'Календарь',
    description: 'Приглашения и изменения встреч',
  ),
  AndroidNotificationChannel(
    'chat_reminders',
    'Напоминания',
    description: 'Напоминания о сообщениях чата',
    importance: Importance.high,
  ),
];

/// Creates the Android channels (idempotent; no-op elsewhere; never throws).
Future<void> ensurePushChannels() async {
  if (!Platform.isAndroid) return;
  try {
    final android = FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    for (final c in _channels) {
      await android?.createNotificationChannel(c);
    }
  } on Object catch (e) {
    DiagnosticLog.warn('push', 'notification channels failed', error: e);
  }
}

/// «Ответить» (inline input) and «Прочитано» under a chat notification. Both
/// keep the notification open: the reply is appended to it, and «Прочитано»
/// dismisses it itself once the server has been told.
const _chatActions = <AndroidNotificationAction>[
  AndroidNotificationAction(
    chatReplyActionId,
    'Ответить',
    inputs: [AndroidNotificationActionInput(label: 'Сообщение')],
    semanticAction: SemanticAction.reply,
    cancelNotification: false,
  ),
  AndroidNotificationAction(
    chatMarkReadActionId,
    'Прочитано',
    semanticAction: SemanticAction.markAsRead,
    cancelNotification: false,
  ),
];

/// Stable positive 31-bit id (FNV-1a) — the same in every isolate and run.
int stableNotificationId(String key) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(key)) {
    h ^= b;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}

/// What to show for a decrypted push (pure, unit-tested).
class PushNotificationContent {
  const PushNotificationContent({
    required this.channelId,
    required this.id,
    required this.tag,
    required this.title,
    required this.body,
    required this.payload,
    this.sender = '',
    this.text = '',
    this.group = false,
  });

  final String channelId;
  final int id;
  final String tag;
  final String title;
  final String body;

  /// `push:` + JSON of the ids needed to open the target screen.
  final String payload;

  /// Chat only: sender name and message text for the messaging style.
  final String sender;
  final String text;
  final bool group;
}

/// Decodes a tapped push notification payload; null for foreign payloads.
Map<String, dynamic>? decodePushTapPayload(String payload) {
  if (!payload.startsWith(LocalNotificationHub.pushPayloadPrefix)) return null;
  try {
    final m = jsonDecode(
      payload.substring(LocalNotificationHub.pushPayloadPrefix.length),
    );
    return m is Map<String, dynamic> ? m : null;
  } on FormatException {
    return null;
  }
}

String chatNotificationTag(String conversationId) => conversationId;
int chatNotificationId(String conversationId) =>
    stableNotificationId('chat:$conversationId');

PushNotificationContent? buildPushNotificationContent(
  Map<String, dynamic> data,
) {
  String s(String k) {
    final v = data[k];
    return v is String ? v.trim() : '';
  }

  final type = s('type');
  if (s('silent') == '1') return null;
  final payload =
      LocalNotificationHub.pushPayloadPrefix +
      jsonEncode({
        'type': type,
        for (final k in const [
          'conversation_id',
          'message_id',
          'event_id',
          'kind',
          'call_id',
          'thread_root_id',
          'scheduled_id',
        ])
          if (s(k).isNotEmpty) k: s(k),
      });

  if (type == 'chat.scheduled_failed') {
    // «Отправить, когда появится в сети» gave up (the peer stayed offline).
    final conv = s('conversation_id');
    if (conv.isEmpty) return null;
    return PushNotificationContent(
      channelId: chatMessagesChannelId,
      id: stableNotificationId('scheduled:${s('scheduled_id')}'),
      tag: 'scheduled:${s('scheduled_id')}',
      title: s('title').isEmpty ? 'Отложенное сообщение' : s('title'),
      body: s('body').isEmpty
          ? 'Не отправлено: собеседник не появился в сети'
          : s('body'),
      payload: payload,
    );
  }

  if (type == 'chat.reminder') {
    // Same id/tag as the local fallback (chat_reminder_notifications.dart),
    // so the push replaces it instead of showing twice.
    final conv = s('conversation_id');
    final reminder = s('reminder_id');
    if (conv.isEmpty) return null;
    return PushNotificationContent(
      channelId: 'chat_reminders',
      id: stableNotificationId('reminder:$reminder'),
      tag: 'reminder:$reminder',
      title: s('title').isEmpty ? 'Напоминание' : s('title'),
      body: s('body'),
      payload: payload,
    );
  }
  if (type.startsWith('chat.')) {
    final conv = s('conversation_id');
    if (conv.isEmpty) return null;
    final group = s('chat_type') == 'group';
    final sender = s('sender_name');
    final text = s('body').isEmpty ? 'Новое сообщение' : s('body');
    final title = group
        ? (s('conversation_title').isNotEmpty ? s('conversation_title') : s('title'))
        : (sender.isNotEmpty ? sender : s('title'));
    return PushNotificationContent(
      channelId: s('channel').isNotEmpty ? s('channel') : chatMessagesChannelId,
      id: chatNotificationId(conv),
      tag: chatNotificationTag(conv),
      title: title.isEmpty ? 'XatBox' : title,
      body: group && sender.isNotEmpty ? '$sender: $text' : text,
      payload: payload,
      sender: sender,
      text: text,
      group: group,
    );
  }
  if (type == 'call.missed') {
    final call = s('call_id');
    return PushNotificationContent(
      channelId: callsChannelId,
      id: stableNotificationId('call:$call'),
      tag: call,
      title: s('title').isEmpty ? 'Пропущенный звонок' : s('title'),
      body: s('body').isNotEmpty ? s('body') : s('caller_name'),
      payload: payload,
    );
  }
  if (type.startsWith('calendar.')) {
    if (s('title').isEmpty && s('body').isEmpty) return null;
    final event = s('event_id');
    return PushNotificationContent(
      channelId: calendarChannelId,
      id: stableNotificationId('calendar:$event:$type'),
      tag: event,
      title: s('title').isEmpty ? 'Календарь' : s('title'),
      body: s('body'),
      payload: payload,
    );
  }
  // call.incoming / call.cancelled are handled by the call UI; unknown types
  // are not shown.
  return null;
}

/// Shows a decrypted push on Android (never throws).
/// «Проверить уведомления» (phone): a test notification on the chat
/// channel, as a message would arrive. Returns the system's reason when it
/// could not be shown, null when it was.
Future<String?> showTestNotification({required String title, required String body}) async {
  try {
    await LocalNotificationHub.ensureInitialized();
    await ensurePushChannels();
    final channel = _channels.first;
    await FlutterLocalNotificationsPlugin().show(
      id: 0x74657374,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
    return null;
  } on Object catch (e) {
    DiagnosticLog.warn('push', 'test notification failed', error: e);
    return e.toString();
  }
}

Future<void> showPushNotification(Map<String, dynamic> data) async {
  if (!Platform.isAndroid) return;
  final c = buildPushNotificationContent(data);
  if (c == null) return;
  try {
    await LocalNotificationHub.ensureInitialized();
    await ensurePushChannels();
    final plugin = FlutterLocalNotificationsPlugin();
    final channel = _channels.firstWhere(
      (ch) => ch.id == c.channelId,
      orElse: () => _channels.first,
    );
    StyleInformation style = BigTextStyleInformation(c.body);
    if (c.channelId == chatMessagesChannelId) {
      // New messages of one chat stack in one notification.
      MessagingStyleInformation? previous;
      try {
        previous = await plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.getActiveNotificationMessagingStyle(id: c.id, tag: c.tag);
      } on Object {
        previous = null;
      }
      final messages = [
        ...?previous?.messages,
        Message(
          c.text,
          DateTime.now(),
          Person(name: c.sender.isNotEmpty ? c.sender : c.title),
        ),
      ];
      style = MessagingStyleInformation(
        const Person(name: 'Вы'),
        conversationTitle: c.group ? c.title : null,
        groupConversation: c.group,
        messages: messages.length > 8
            ? messages.sublist(messages.length - 8)
            : messages,
      );
    }
    await plugin.show(
      id: c.id,
      title: c.title,
      body: c.body,
      payload: c.payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: channel.importance == Importance.max ||
                  channel.importance == Importance.high
              ? Priority.high
              : Priority.defaultPriority,
          tag: c.tag.isEmpty ? null : c.tag,
          styleInformation: style,
          category: c.channelId == chatMessagesChannelId
              ? AndroidNotificationCategory.message
              : c.channelId == callsChannelId
              ? AndroidNotificationCategory.missedCall
              : AndroidNotificationCategory.event,
          actions: c.channelId == chatMessagesChannelId && c.text.isNotEmpty
              ? _chatActions
              : null,
        ),
      ),
    );
  } on Object catch (e) {
    DiagnosticLog.warn('push', 'local push notification failed', error: e);
  }
}

/// Removes the notification of [conversationId] (Android and desktop;
/// never throws).
Future<void> cancelChatNotificationFor(String conversationId) async {
  if (!(Platform.isAndroid || isDesktop) || conversationId.isEmpty) return;
  try {
    await FlutterLocalNotificationsPlugin().cancel(
      id: chatNotificationId(conversationId),
      tag: chatNotificationTag(conversationId),
    );
  } on Object catch (e) {
    DiagnosticLog.warn('push', 'cancel chat notification failed', error: e);
  }
}

/// Redraws the conversation's notification after «Ответить»: the answer is
/// appended to the thread the way Android's own messaging apps do, so the
/// person sees it left the phone. A failed send says so in place instead of
/// disappearing silently — the text is not lost, it is in the notification.
Future<void> showChatReplyResult({
  required String conversationId,
  required String reply,
  required bool sent,
  required String payload,
}) async {
  // Desktop: the toast is gone after the button; only a failure is news.
  if (isDesktop && !sent && conversationId.isNotEmpty) {
    await showDesktopToast(id: chatNotificationId(conversationId), title: 'XatBox', body: '$reply — не отправлено', payload: payload);
    return;
  }
  if (!Platform.isAndroid || conversationId.isEmpty) return;
  try {
    await LocalNotificationHub.ensureInitialized();
    await ensurePushChannels();
    final plugin = FlutterLocalNotificationsPlugin();
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final id = chatNotificationId(conversationId);
    final tag = chatNotificationTag(conversationId);
    MessagingStyleInformation? previous;
    try {
      previous = await android?.getActiveNotificationMessagingStyle(
        id: id,
        tag: tag,
      );
    } on Object {
      previous = null;
    }
    // The person of an own message is null: Android draws it as "you".
    final messages = [
      ...?previous?.messages,
      Message(
        sent ? reply : '$reply — не отправлено',
        DateTime.now(),
        null,
      ),
    ];
    final title = previous?.conversationTitle ?? 'XatBox';
    await plugin.show(
      id: id,
      title: title,
      body: sent ? reply : 'Ответ не отправлен',
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          chatMessagesChannelId,
          'Сообщения',
          importance: Importance.high,
          priority: Priority.high,
          tag: tag,
          category: AndroidNotificationCategory.message,
          // The answer is not news to its author: no second buzz.
          onlyAlertOnce: true,
          actions: _chatActions,
          styleInformation: MessagingStyleInformation(
            const Person(name: 'Вы'),
            conversationTitle: previous?.conversationTitle,
            groupConversation: previous?.groupConversation ?? false,
            messages: messages.length > 8
                ? messages.sublist(messages.length - 8)
                : messages,
          ),
        ),
      ),
    );
  } on Object catch (e) {
    DiagnosticLog.warn('push', 'reply notification update failed', error: e);
  }
}
