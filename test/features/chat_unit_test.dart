import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/api/app_env.dart';
import 'package:xatbox_mobile/core/routing/deep_links.dart';
import 'package:xatbox_mobile/core/websocket/realtime_client.dart';
import 'package:xatbox_mobile/features/chat/data/chat_cache.dart';
import 'package:xatbox_mobile/features/chat/data/chat_models.dart';
import 'package:xatbox_mobile/features/chat/data/chat_repository.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';

import '../helpers/chat_fixtures.dart';
import '../helpers/fake_socket.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

void main() {
  group('RealtimeClient', () {
    test('backoff grows exponentially with jitter and caps', () {
      final r = Random(1);
      final d0 = RealtimeClient.backoffFor(0, const Duration(seconds: 30), r);
      final d3 = RealtimeClient.backoffFor(3, const Duration(seconds: 30), r);
      final d9 = RealtimeClient.backoffFor(9, const Duration(seconds: 30), r);
      expect(d0.inMilliseconds, inInclusiveRange(500, 1000));
      expect(d3.inMilliseconds, inInclusiveRange(4000, 8000));
      expect(d9.inMilliseconds, inInclusiveRange(15000, 30000));
    });

    test('sends the token as the first frame, reconnects after a drop, stops on 4401', () async {
      final factory = FakeSocketFactory();
      final client = RealtimeClient(
        url: () => Uri.parse('ws://test/ws'),
        tokenProvider: () async => 'tok',
        connector: factory.connect,
        maxBackoff: const Duration(milliseconds: 20),
      );
      final statuses = <RealtimeStatus>[];
      client.status.listen(statuses.add);
      client.start();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(factory.connections, hasLength(1));
      expect(factory.last.sent.first, {'type': 'auth', 'token': 'tok'});
      expect(client.isConnected, isTrue);

      // Server drops the connection (e.g. restart, 1001) → reconnect with backoff.
      factory.last.serverClose(1001);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(factory.connections.length, greaterThanOrEqualTo(2));
      expect(client.isConnected, isTrue);

      // Session revoked → 4401 → no further reconnects.
      factory.acceptAuth = false;
      factory.last.serverClose(4401);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final after = factory.connections.length;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        factory.connections.length,
        after,
        reason: 'must not reconnect after 4401',
      );
      expect(client.isConnected, isFalse);
      await client.dispose();
    });
  });

  group('ChatRepository.applyReaction', () {
    test('adds, counts and removes reactions', () {
      var r = ChatRepository.applyReaction(const [], '👍', 'u1', true, 'me');
      expect(r.single.count, 1);
      expect(r.single.me, isFalse);
      r = ChatRepository.applyReaction(r, '👍', 'me', true, 'me');
      expect(r.single.count, 2);
      expect(r.single.me, isTrue);
      r = ChatRepository.applyReaction(r, '👍', 'u1', false, 'me');
      expect(r.single.userIds, ['me']);
      r = ChatRepository.applyReaction(r, '👍', 'me', false, 'me');
      expect(r, isEmpty);
    });
  });

  group('ChatCache', () {
    late TestHarness h;
    tearDown(() => h.dispose());

    test('bounded message tail, outbox and sync cursor survive', () async {
      h = await TestHarness.create();
      final cache = ChatCache(h.db, maxMessagesPerConversation: 3);
      for (var i = 1; i <= 5; i++) {
        await cache.putMessage(
          ChatMessage.fromJson(ChatFixtures.message(id: 'm$i', seq: i)),
        );
      }
      final tail = await cache.messages(ChatFixtures.conv);
      expect(tail.map((m) => m.seq), [
        3,
        4,
        5,
      ], reason: 'only the newest rows are kept');
      await cache.setSyncedSeq(ChatFixtures.conv, 5);
      expect(await cache.syncedSeq(ChatFixtures.conv), 5);

      final item = OutboxItem(
        clientMessageId: 'cid-x',
        conversationId: ChatFixtures.conv,
        type: 'text',
        body: 'queued',
        createdAt: DateTime.now(),
      );
      await cache.putOutbox(item);
      expect((await cache.outbox()).single.clientMessageId, 'cid-x');
      final pending = item.toPendingMessage('me');
      expect(pending.pending, isTrue);
      expect(pending.clientMessageId, 'cid-x');

      await cache.writeMeta('device_id', 'dev-1');
      await cache.clear();
      expect(await cache.outbox(), isEmpty);
      expect(
        await cache.readMeta('device_id'),
        'dev-1',
        reason: 'device id survives sign-out',
      );
    });
  });

  group('ChatRepository outbox', () {
    late TestHarness h;
    tearDown(() => h.dispose());

    test('retries with the same client_message_id after a network failure; 4xx marks failed', () async {
      h = await TestHarness.create(
        storedToken: Fixtures.token,
        chatBaseUrl: 'http://chat.local/api/v1',
      );
      h.adapter.onJson('GET', '/me', Fixtures.me());
      await h.session.restore();
      final repo = h.container.read(chatRepositoryProvider);
      await repo.cache.putConversation(
        ChatConversation.fromJson(ChatFixtures.conversation()),
      );

      h.chatAdapter.onOffline('POST', '/chats/${ChatFixtures.conv}/messages');
      final item = await repo.sendText(ChatFixtures.conv, 'hello');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        (await repo.cache.outbox()).single.failed,
        isFalse,
        reason: 'network failure keeps the item queued',
      );
      final firstAttempt = h.chatAdapter
          .of('POST', '/chats/${ChatFixtures.conv}/messages')
          .single
          .json;
      expect(firstAttempt['client_message_id'], item.clientMessageId);

      // Server back: the retry carries the very same id → idempotent on the server.
      h.chatAdapter.onJson(
        'POST',
        '/chats/${ChatFixtures.conv}/messages',
        ChatFixtures.message(
          id: 'srv1',
          seq: 1,
          sender: ChatFixtures.me,
          body: 'hello',
          clientId: item.clientMessageId,
        ),
        status: 201,
      );
      await repo.flushOutbox();
      final attempts = h.chatAdapter.of(
        'POST',
        '/chats/${ChatFixtures.conv}/messages',
      );
      expect(attempts, hasLength(2));
      expect(attempts[1].json['client_message_id'], item.clientMessageId);
      expect(await repo.cache.outbox(), isEmpty);
      expect((await repo.cache.messages(ChatFixtures.conv)).single.id, 'srv1');

      // A 4xx (e.g. rate limited is transient, but MESSAGE_TOO_LONG is final) marks the item failed.
      h.chatAdapter.onError(
        'POST',
        '/chats/${ChatFixtures.conv}/messages',
        400,
        'MESSAGE_TOO_LONG',
      );
      final bad = await repo.sendText(ChatFixtures.conv, 'x' * 10);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final queued = (await repo.cache.outbox()).single;
      expect(queued.clientMessageId, bad.clientMessageId);
      expect(queued.failed, isTrue);
      expect(queued.errorCode, 'MESSAGE_TOO_LONG');
    });
  });

  group('env / deep links', () {
    test('chat URL falls back only in dev; prod requires https', () {
      expect(
        AppEnv.fromValues(flavorName: 'dev', apiBaseUrl: '').chatBaseUrl,
        'http://localhost:8090/api/v1',
      );
      expect(
        AppEnv.fromValues(
          flavorName: 'stage',
          apiBaseUrl: 'http://x/api/v1',
        ).chatEnabled,
        isFalse,
      );
      expect(
        () => AppEnv.fromValues(
          flavorName: 'prod',
          apiBaseUrl: 'https://x/api/v1',
          chatBaseUrl: 'http://c/api/v1',
        ),
        throwsA(isA<AppEnvError>()),
      );
      expect(
        FirebasePushOptions.fromValues(
          apiKey: 'a',
          appId: '',
          messagingSenderId: 'c',
          projectId: 'd',
        ),
        isNull,
      );
    });
    test('xatbox://chat/{id} opens the conversation', () {
      expect(DeepLinks.toRoute(Uri.parse('xatbox://chat/abc')), '/chat/c/abc');
    });
  });

  test('FakeHttpAdapter routes chat and mail hosts separately', () async {
    final h = await TestHarness.create(chatBaseUrl: 'http://chat.local/api/v1');
    expect(h.chatAdapter, isNot(same(h.adapter)));
    await h.dispose();
  });
}
