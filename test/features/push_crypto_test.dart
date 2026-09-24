import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/features/chat/data/chat_push.dart';
import 'package:xatbox_mobile/features/chat/data/push_crypto.dart';
import 'package:xatbox_mobile/features/chat/data/push_notifications.dart';

// Shared test vector: the same constants live in
// backend/platform/push/crypto_test.go (key = bytes 0x00..0x1f,
// nonce = bytes 0xa0..0xab).
const vectorKeyB64 = 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=';
const vectorEnc =
    'oKGio6SlpqeoqaqrnToeQiGyIIVAtRgCh6p4DsJ87MEQm2K8IN6eV/+JWSOxGSmJylAgXCv1a6ZWE+fbfTklZVPyNlwyO2U6wQLa3tXR4E0KhzRwJFkvoF5B7pbvf9LUoOOjWI0dX+6f9yjn/OVMziHTHJN/FUCNmOA2mew3oM2wgQ==';

void main() {
  final key = base64.decode(vectorKeyB64);

  group('push decryption', () {
    test('decrypts the Go test vector', () {
      expect(decryptPushPayload(key, vectorEnc), {
        'body': 'Привет, мир',
        'conversation_id': 'c-1',
        'sender_name': 'Алия',
        'type': 'chat.message',
      });
    });

    test('rejects tampering and wrong keys', () {
      final raw = base64.decode(vectorEnc);
      raw[raw.length - 1] ^= 1;
      expect(() => decryptPushPayload(key, base64.encode(raw)), throwsA(anything));
      final other = base64.decode(vectorKeyB64)..[0] ^= 1;
      expect(() => decryptPushPayload(other, vectorEnc), throwsA(anything));
      expect(() => decryptPushPayload(key, 'AAAA'), throwsA(anything));
    });

    test('resolvePushData: plain passthrough, encrypted decrypted, unreadable dropped', () async {
      final plain = {'type': 'call.cancelled', 'call_id': 'c'};
      expect(await resolvePushData(plain, keys: InMemoryPushKeyStore()), plain);

      final enc = {'v': '1', 't': 'chat', 'enc': vectorEnc};
      final data = await resolvePushData(enc, keys: InMemoryPushKeyStore(vectorKeyB64));
      expect(data?['sender_name'], 'Алия');

      expect(await resolvePushData(enc, keys: InMemoryPushKeyStore()), isNull);
      expect(
        await resolvePushData(enc, keys: InMemoryPushKeyStore(generatePushKey())),
        isNull,
      );
      expect(
        await resolvePushData({'v': '2', 'enc': 'x'}, keys: InMemoryPushKeyStore(vectorKeyB64)),
        isNull,
      );
    });

    test('key store creates, reuses and rotates a 32-byte key', () async {
      final store = InMemoryPushKeyStore();
      expect(await store.read(), isNull);
      final a = await store.readOrCreate();
      expect(base64.decode(a), hasLength(32));
      expect(await store.readOrCreate(), a);
      await store.clear();
      expect(await store.readOrCreate(), isNot(a));
    });
  });

  group('push notification content', () {
    test('direct chat: sender title, text body, tagged by conversation', () {
      final c = buildPushNotificationContent({
        'type': 'chat.message',
        'conversation_id': 'conv-1',
        'message_id': 'm1',
        'sender_name': 'Алия',
        'chat_type': 'direct',
        'title': 'Алия',
        'body': 'Привет',
        'channel': 'chat_messages',
      })!;
      expect(c.channelId, chatMessagesChannelId);
      expect(c.title, 'Алия');
      expect(c.body, 'Привет');
      expect(c.tag, 'conv-1');
      expect(c.id, chatNotificationId('conv-1'));
      expect(decodePushTapPayload(c.payload), {
        'type': 'chat.message',
        'conversation_id': 'conv-1',
        'message_id': 'm1',
      });
    });

    test('group chat: chat title, "Sender: text" body', () {
      final c = buildPushNotificationContent({
        'type': 'chat.mention',
        'conversation_id': 'g1',
        'sender_name': 'Бекзат',
        'conversation_title': 'Кафедра',
        'chat_type': 'group',
        'body': 'Смотри',
      })!;
      expect(c.title, 'Кафедра');
      expect(c.body, 'Бекзат: Смотри');
      expect(c.group, isTrue);
    });

    test('calls and calendar', () {
      expect(
        buildPushNotificationContent({'type': 'call.incoming', 'call_id': 'c'}),
        isNull,
      );
      expect(
        buildPushNotificationContent({'type': 'call.cancelled', 'call_id': 'c', 'silent': '1'}),
        isNull,
      );
      final missed = buildPushNotificationContent({
        'type': 'call.missed',
        'call_id': 'c9',
        'title': 'Пропущенный звонок',
        'body': 'Алия',
      })!;
      expect(missed.channelId, callsChannelId);
      expect(missed.body, 'Алия');
      final cal = buildPushNotificationContent({
        'type': 'calendar.invite',
        'event_id': 'e1',
        'kind': 'invited',
        'title': 'Совещание',
        'body': 'Алия приглашает вас на встречу',
      })!;
      expect(cal.channelId, calendarChannelId);
      expect(decodePushTapPayload(cal.payload)?['event_id'], 'e1');
    });

    test('reminder and mention taps scroll to their message', () {
      expect(
        pushJumpMessageId({'type': 'chat.reminder', 'conversation_id': 'c', 'message_id': 'm1'}),
        'm1',
      );
      expect(pushJumpMessageId({'type': 'chat.mention', 'message_id': 'm2'}), 'm2');
      expect(
        pushJumpMessageId({'type': 'chat.message', 'message_id': 'm3'}),
        isNull,
        reason: 'a new-message push opens the chat at the first unread',
      );
      expect(pushJumpMessageId({'type': 'chat.reminder', 'message_id': ''}), isNull);
    });

    test('ids are stable and positive; foreign payloads ignored', () {
      expect(stableNotificationId('chat:x'), stableNotificationId('chat:x'));
      expect(stableNotificationId('chat:x'), isNot(stableNotificationId('chat:y')));
      expect(stableNotificationId('chat:x'), greaterThanOrEqualTo(0));
      expect(decodePushTapPayload('event-123'), isNull);
    });
  });
}
