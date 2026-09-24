import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/app_env.dart';
import '../../../core/auth/token_storage.dart';
import '../../../shared/utils/diagnostic_log.dart';
import 'push_notifications.dart';

/// «Ответить» and «Прочитано» on a chat notification: both are answered
/// without opening the app, exactly like the reject action of an incoming
/// call (`call_background.dart`) — the work happens in whichever isolate the
/// system hands the action to, including one started while the app is dead.
const chatReplyActionId = 'chat_reply';
const chatMarkReadActionId = 'chat_mark_read';

/// iOS: the same actions under APNs chat banners (`aps.category`, set by
/// backend/platform/push/apns.go). The system shows them; AppDelegate.swift
/// answers them natively, so they never reach [handleChatNotificationAction].
/// Replying needs an unlocked phone; «Прочитано» does not.
const iosChatCategoryId = 'XATBOX_CHAT_MESSAGE';

final iosChatNotificationCategories = <DarwinNotificationCategory>[
  DarwinNotificationCategory(
    iosChatCategoryId,
    actions: [
      DarwinNotificationAction.text(
        chatReplyActionId,
        'Ответить',
        buttonTitle: 'Отправить',
        placeholder: 'Сообщение',
        options: {DarwinNotificationActionOption.authenticationRequired},
      ),
      DarwinNotificationAction.plain(chatMarkReadActionId, 'Прочитано'),
    ],
  ),
];

String _base(String url) {
  var base = url.trim();
  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  return base;
}

/// `POST {chatBaseUrl}/chats/{id}/messages` with the typed answer.
///
/// Pure apart from [dio]: the token and base URL are injected, so the whole
/// path is unit-testable. Returns true when the server stored the message.
/// The token is never logged.
Future<bool> sendChatReplyInBackground({
  required String conversationId,
  required String text,
  required String chatBaseUrl,
  required Future<String?> Function() readToken,
  required Dio dio,
  String? clientMessageId,
}) async {
  final base = _base(chatBaseUrl);
  final body = text.trim();
  if (conversationId.isEmpty || body.isEmpty || base.isEmpty) return false;
  final String? token;
  try {
    token = await readToken();
  } on Object catch (e) {
    DiagnosticLog.warn('chat', 'notification reply: token unavailable (${e.runtimeType})');
    return false;
  }
  if (token == null || token.isEmpty) return false; // signed out
  try {
    final res = await dio.post<dynamic>(
      '$base/chats/${Uri.encodeComponent(conversationId)}/messages',
      data: {
        'client_message_id': clientMessageId ?? const Uuid().v4(),
        'type': 'text',
        'body': body,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        validateStatus: (_) => true,
      ),
    );
    final status = res.statusCode ?? 0;
    if (status == 200 || status == 201) return true;
    DiagnosticLog.warn('chat', 'notification reply: HTTP $status');
    return false;
  } on DioException catch (e) {
    DiagnosticLog.warn('chat', 'notification reply failed: ${e.type.name}');
    return false;
  }
}

/// `POST {chatBaseUrl}/messages/{id}/read` — «Прочитано» without opening the
/// app, so the sender's receipt is honest.
Future<bool> markChatMessageReadInBackground({
  required String messageId,
  required String chatBaseUrl,
  required Future<String?> Function() readToken,
  required Dio dio,
}) async {
  final base = _base(chatBaseUrl);
  if (messageId.isEmpty || base.isEmpty) return false;
  final String? token;
  try {
    token = await readToken();
  } on Object catch (e) {
    DiagnosticLog.warn('chat', 'notification read: token unavailable (${e.runtimeType})');
    return false;
  }
  if (token == null || token.isEmpty) return false;
  try {
    final res = await dio.post<dynamic>(
      '$base/messages/${Uri.encodeComponent(messageId)}/read',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        validateStatus: (_) => true,
      ),
    );
    return res.statusCode == 204 || res.statusCode == 200;
  } on DioException catch (e) {
    DiagnosticLog.warn('chat', 'notification read failed: ${e.type.name}');
    return false;
  }
}

/// True when the response is one of our chat actions rather than a tap on the
/// notification itself (those open the conversation through the listeners).
bool isChatNotificationAction(NotificationResponse response) =>
    response.actionId == chatReplyActionId ||
    response.actionId == chatMarkReadActionId;

/// Runs the action. Safe to call from any isolate; never throws.
Future<void> handleChatNotificationAction(NotificationResponse response) async {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;
  final data = decodePushTapPayload(payload);
  if (data == null) return;
  String id(String key) {
    final v = data[key];
    return v is String ? v.trim() : '';
  }

  final conversationId = id('conversation_id');
  if (conversationId.isEmpty) return;
  final messageId = id('message_id');

  final AppEnv env;
  try {
    env = AppEnv.fromDefines();
  } on AppEnvError {
    return;
  }
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': 'XatBoxMobile/background (${Platform.operatingSystem})',
      },
    ),
  );
  final readToken = SecureTokenStorage().read;

  if (response.actionId == chatMarkReadActionId) {
    await markChatMessageReadInBackground(
      messageId: messageId,
      chatBaseUrl: env.chatBaseUrl,
      readToken: readToken,
      dio: dio,
    );
    await cancelChatNotificationFor(conversationId);
    return;
  }

  final text = (response.input ?? '').trim();
  if (text.isEmpty) return; // the input was dismissed
  final sent = await sendChatReplyInBackground(
    conversationId: conversationId,
    text: text,
    chatBaseUrl: env.chatBaseUrl,
    readToken: readToken,
    dio: dio,
  );
  // Answering a message is reading it; a failed read receipt changes nothing
  // for the person, so its result is ignored.
  if (sent && messageId.isNotEmpty) {
    await markChatMessageReadInBackground(
      messageId: messageId,
      chatBaseUrl: env.chatBaseUrl,
      readToken: readToken,
      dio: dio,
    );
  }
  await showChatReplyResult(
    conversationId: conversationId,
    reply: text,
    sent: sent,
    payload: payload,
  );
}

/// Entry point the system calls in a background isolate when the app is not
/// running. Must stay top-level and annotated, or the compiler strips it.
@pragma('vm:entry-point')
Future<void> xatboxNotificationBackgroundResponse(
  NotificationResponse response,
) async {
  if (!isChatNotificationAction(response)) return;
  DartPluginRegistrant.ensureInitialized();
  await handleChatNotificationAction(response);
}
