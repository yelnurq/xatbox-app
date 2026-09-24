import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/notifications/local_notification_hub.dart';
import '../../../core/platform/desktop.dart';
import '../../../core/platform/desktop_shell.dart';
import '../../../core/platform/desktop_sounds.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../settings/data/notification_preferences.dart';
import 'chat_models.dart';
import 'chat_notification_actions.dart';
import 'chat_repository.dart';
import 'push_notifications.dart';

/// Messages older than this are catch-up after a reconnect, not news.
const desktopNotificationFreshness = Duration(minutes: 2);

/// Push-shaped data (the keys of a decrypted chat push, see
/// [buildPushNotificationContent]) for a socket event, or null when the
/// desktop app should stay quiet (pure, unit-tested).
///
/// The desktop app has no FCM: while the socket is open the server sends no
/// push at all, so the notifications a phone would get are raised here from
/// `message.created` with the same filters the server applies to pushes
/// (the person's notification preferences and quiet hours, muted chats).
Map<String, String>? desktopChatNotificationData({
  required ChatEvent event,
  required ChatConversation? conversation,
  required String selfId,
  required NotificationPreferences prefs,
  required DateTime now,
  required String preview,
}) {
  if (event.type != 'message.created') return null;
  final m = event.message;
  final c = conversation;
  if (m == null || (c?.isSaved ?? false)) return null;
  if (m.senderId.isEmpty || m.senderId == selfId) return null;
  if (m.isServiceLike || m.isDeleted || m.isComment) return null;
  if (now.difference(m.createdAt).abs() > desktopNotificationFreshness) return null;
  if ((c?.isMuted ?? false) || inQuietHours(prefs.quietHours, now)) return null;
  final mentioned = m.mentions.contains(selfId);
  // The chat list may not be loaded yet (the app opened on mail): the
  // message still notifies, as a direct one, under the app's name.
  if (c == null) {
    if (!prefs.directMessages) return null;
    return {
      'type': mentioned ? 'chat.mention' : 'chat.message',
      'conversation_id': m.conversationId,
      'message_id': m.id,
      'chat_type': 'direct',
      'title': 'XatBox',
      'body': preview,
    };
  }
  final wanted = switch (c.type) {
    'direct' => prefs.directMessages,
    'channel' => prefs.channels,
    _ => prefs.groupMessages && (!prefs.groupMentionsOnly || mentioned),
  };
  if (!wanted) return null;
  final sender = c.isDirect
      ? (c.peer?.label ?? c.title)
      : (c.members.where((x) => x.userId == m.senderId).map((x) => x.label).firstOrNull ?? '');
  return {
    'type': mentioned ? 'chat.mention' : 'chat.message',
    'conversation_id': c.id,
    'message_id': m.id,
    'chat_type': c.isDirect ? 'direct' : 'group',
    'conversation_title': c.title,
    'title': c.title,
    'sender_name': c.isChannel ? '' : sender,
    'body': preview,
  };
}

/// Quiet hours in the device's local time (the zone the settings screen
/// stores for this device); chat and mail toasts keep them.
bool inQuietHours(QuietHoursPrefs q, DateTime now) {
  if (!q.enabled) return false;
  final start = QuietHoursPrefs.parseClock(q.start);
  final end = QuietHoursPrefs.parseClock(q.end);
  if (start == null || end == null || start == end) return false;
  final local = now.toLocal();
  final minute = local.hour * 60 + local.minute;
  return start < end ? minute >= start && minute < end : minute >= start || minute < end;
}

/// Texts of the reply box and buttons on a Windows chat toast.
class ChatToastTexts {
  const ChatToastTexts({required this.replyHint, required this.send, required this.markRead});
  final String replyHint;
  final String send;
  final String markRead;
}

/// Windows: a reply box with «Отправить» and «Прочитано» under a chat toast,
/// answered in place by handleChatNotificationAction like on the phone.
WindowsNotificationDetails chatToastWindowsDetails(String payload, ChatToastTexts texts) => WindowsNotificationDetails(
  inputs: [WindowsTextInput(id: 'reply', placeHolderContent: texts.replyHint)],
  actions: [
    WindowsAction(
      content: texts.send,
      arguments: LocalNotificationHub.windowsActionArguments(chatReplyActionId, payload),
      inputId: 'reply',
    ),
    WindowsAction(
      content: texts.markRead,
      arguments: LocalNotificationHub.windowsActionArguments(chatMarkReadActionId, payload),
    ),
  ],
);

/// Raises toasts for new chat messages, as desktop messengers do: always,
/// except for the conversation that is open in the focused window. A tap
/// opens the conversation through the same `push:` payload routing as a
/// phone push (ChatPushService).
class DesktopChatNotifier {
  DesktopChatNotifier({
    required ChatRepository repo,
    required ChatConversation? Function(String id) conversation,
    required NotificationPreferences Function() prefs,
    required String Function(ChatMessage message) preview,
    required bool Function(String conversationId) isOpen,
    Future<bool> Function()? windowFocused,
    this.texts,
  }) : _repo = repo, // ignore: prefer_initializing_formals
       _conversation = conversation, // ignore: prefer_initializing_formals
       _prefs = prefs, // ignore: prefer_initializing_formals
       _preview = preview, // ignore: prefer_initializing_formals
       _isOpen = isOpen, // ignore: prefer_initializing_formals
       _focused = windowFocused ?? desktopWindowFocused;

  final ChatRepository _repo;
  final ChatConversation? Function(String id) _conversation;
  final NotificationPreferences Function() _prefs;
  final String Function(ChatMessage message) _preview;
  final Future<bool> Function() _focused;
  final bool Function(String conversationId) _isOpen;

  /// Windows: the reply box and buttons (none when null).
  final ChatToastTexts Function()? texts;
  StreamSubscription<ChatEvent>? _sub;

  void start() {
    if (!isDesktop || _sub != null) return;
    unawaited(LocalNotificationHub.ensureInitialized());
    _sub = _repo.events.listen((ev) => unawaited(_handle(ev)));
  }

  Future<void> _handle(ChatEvent ev) async {
    if (ev.type != 'message.created') return;
    final m = ev.message;
    if (m == null) return;
    final data = desktopChatNotificationData(
      event: ev,
      conversation: _conversation(m.conversationId),
      selfId: _repo.selfId,
      prefs: _prefs(),
      now: DateTime.now(),
      preview: _preview(m),
    );
    if (data == null) return;
    if (_isOpen(m.conversationId) && await _focused()) return;
    final c = buildPushNotificationContent(data);
    if (c == null) return;
    final t = texts?.call();
    await showDesktopToast(
      id: c.id,
      title: c.title,
      body: c.body,
      payload: c.payload,
      details: t == null || c.payload.isEmpty
          ? null
          : NotificationDetails(
              windows: Platform.isWindows ? chatToastWindowsDetails(c.payload, t) : null,
              // macOS: the buttons of the chat category (reply, «Прочитано»).
              macOS: Platform.isMacOS ? const DarwinNotificationDetails(categoryIdentifier: iosChatCategoryId) : null,
            ),
    );
    // The taskbar button flashes until the window is activated.
    await DesktopShell.flash();
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}

/// Shows a system notification on desktop; returns the error text when the
/// system refused it (Настройки → Уведомления → «Проверить»), null on success.
Future<String?> showDesktopToast({
  required int id,
  required String title,
  required String body,
  String? payload,
  NotificationDetails? details,
}) async {
  try {
    await LocalNotificationHub.ensureInitialized();
    final initError = LocalNotificationHub.initError;
    if (initError != null) return initError;
    // «Звук уведомлений»: the toast stays silent and XatBox chimes itself
    // (or nothing); «Системный» keeps the operating system's sound.
    final silent = DesktopSounds.silenceToasts;
    await FlutterLocalNotificationsPlugin().show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: silent ? silencedToastDetails(details) : details,
    );
    unawaited(DesktopSounds.chimeForToast());
    DiagnosticLog.info('notifications', 'desktop toast shown');
    return null;
  } on Object catch (e) {
    DiagnosticLog.warn('notifications', 'desktop toast failed', error: e);
    return e.toString();
  }
}
