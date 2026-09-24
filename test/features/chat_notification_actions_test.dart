import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/features/chat/data/chat_notification_actions.dart';

import '../helpers/fake_http.dart';

/// «Ответить» and «Прочитано» under a chat notification: both talk to the
/// server from whatever isolate the system gives the action, so they are
/// plain functions with the token and the base URL injected.
void main() {
  late FakeHttpAdapter http;
  late Dio dio;

  setUp(() {
    http = FakeHttpAdapter();
    dio = Dio()..httpClientAdapter = http;
  });

  group('reply from the notification', () {
    test('POST /chats/{id}/messages with the bearer token and the text', () async {
      http.on(
        'POST',
        '/chats/c-1/messages',
        (_) => const FakeResponse(201, json: {'id': 'm-2'}),
      );
      final ok = await sendChatReplyInBackground(
        conversationId: 'c-1',
        text: '  Буду через 10 минут  ',
        chatBaseUrl: 'https://mail.kaztbu.edu.kz/xatbox/chat/api/v1/',
        readToken: () async => 'secret-token',
        dio: dio,
        clientMessageId: 'cid-1',
      );
      expect(ok, isTrue);
      final r = http.requests.single;
      expect(r.method, 'POST');
      expect(r.path, '/chats/c-1/messages');
      expect(r.headers['Authorization'], 'Bearer secret-token');
      expect(r.json, {
        'client_message_id': 'cid-1',
        'type': 'text',
        'body': 'Буду через 10 минут',
      });
    });

    test('signed out, empty text or no chat URL: nothing is sent', () async {
      expect(
        await sendChatReplyInBackground(
          conversationId: 'c-1',
          text: 'привет',
          chatBaseUrl: 'http://chat.local/api/v1',
          readToken: () async => null,
          dio: dio,
        ),
        isFalse,
      );
      expect(
        await sendChatReplyInBackground(
          conversationId: 'c-1',
          text: '   ',
          chatBaseUrl: 'http://chat.local/api/v1',
          readToken: () async => 'tok',
          dio: dio,
        ),
        isFalse,
      );
      expect(
        await sendChatReplyInBackground(
          conversationId: 'c-1',
          text: 'привет',
          chatBaseUrl: '',
          readToken: () async => 'tok',
          dio: dio,
        ),
        isFalse,
      );
      // A locked keystore must not crash the background isolate.
      expect(
        await sendChatReplyInBackground(
          conversationId: 'c-1',
          text: 'привет',
          chatBaseUrl: 'http://chat.local/api/v1',
          readToken: () async => throw StateError('keystore locked'),
          dio: dio,
        ),
        isFalse,
      );
      expect(http.requests, isEmpty);
    });

    test('rejected by the server or offline: false, no throw', () async {
      http.onError('POST', '/chats/c-1/messages', 403, 'CHANNEL_READ_ONLY');
      expect(
        await sendChatReplyInBackground(
          conversationId: 'c-1',
          text: 'привет',
          chatBaseUrl: 'http://chat.local/api/v1',
          readToken: () async => 'tok',
          dio: dio,
        ),
        isFalse,
      );
      http.onOffline('POST', '/chats/c-1/messages');
      expect(
        await sendChatReplyInBackground(
          conversationId: 'c-1',
          text: 'привет',
          chatBaseUrl: 'http://chat.local/api/v1',
          readToken: () async => 'tok',
          dio: dio,
        ),
        isFalse,
      );
    });
  });

  group('«Прочитано» from the notification', () {
    test('POST /messages/{id}/read (204) with the bearer token', () async {
      http.on('POST', '/messages/m-1/read', (_) => const FakeResponse(204));
      final ok = await markChatMessageReadInBackground(
        messageId: 'm-1',
        chatBaseUrl: 'http://chat.local/api/v1/',
        readToken: () async => 'tok',
        dio: dio,
      );
      expect(ok, isTrue);
      expect(http.requests.single.headers['Authorization'], 'Bearer tok');
    });

    test('no message id or signed out: nothing is sent', () async {
      expect(
        await markChatMessageReadInBackground(
          messageId: '',
          chatBaseUrl: 'http://chat.local/api/v1',
          readToken: () async => 'tok',
          dio: dio,
        ),
        isFalse,
      );
      expect(
        await markChatMessageReadInBackground(
          messageId: 'm-1',
          chatBaseUrl: 'http://chat.local/api/v1',
          readToken: () async => '',
          dio: dio,
        ),
        isFalse,
      );
      expect(http.requests, isEmpty);
    });
  });
}
