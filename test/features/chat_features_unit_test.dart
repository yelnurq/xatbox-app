import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/network/network_status.dart';
import 'package:xatbox_mobile/features/chat/data/chat_cache.dart';
import 'package:xatbox_mobile/features/chat/data/chat_mentions.dart';
import 'package:xatbox_mobile/features/chat/data/chat_models.dart';
import 'package:xatbox_mobile/features/chat/data/media_auto_download.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';

import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

void main() {
  group('ChatMentions', () {
    test('active query starts at a word boundary and stops at whitespace', () {
      expect(ChatMentions.activeQuery('@', 1), (start: 0, query: ''));
      expect(ChatMentions.activeQuery('Привет @Ка', 10), (start: 7, query: 'Ка'));
      expect(ChatMentions.activeQuery('mail@example', 12), isNull, reason: 'not after a space');
      expect(ChatMentions.activeQuery('@Bob done', 9), isNull, reason: 'query ended with a space');
      expect(ChatMentions.activeQuery('hi @Bo and', 6), (start: 3, query: 'Bo'), reason: 'cursor in the middle');
      expect(ChatMentions.activeQuery('no mention', 10), isNull);
    });

    test('insert replaces the typed query and places the cursor after the name', () {
      final out = ChatMentions.insert('Привет @Ка', start: 7, cursor: 10, label: 'Карина Ахметова');
      expect(out.text, 'Привет @Карина Ахметова ');
      expect(out.cursor, out.text.length);

      final middle = ChatMentions.insert('hi @Bo see you', start: 3, cursor: 6, label: 'Bob');
      expect(middle.text, 'hi @Bob see you', reason: 'no doubled space');
      expect(middle.cursor, 8);
    });

    test('filter matches any word of the label or the e-mail prefix', () {
      final people = [('Карина Ахметова', 'karina@x.kz'), ('Bob', 'bob@x.kz'), ('Болат', 'bolat@x.kz')];
      List<String> f(String q) =>
          ChatMentions.filter(people, q, label: (p) => p.$1, email: (p) => p.$2).map((p) => p.$1).toList();
      expect(f(''), hasLength(3));
      expect(f('ах'), ['Карина Ахметова']);
      expect(f('бо'), ['Болат']);
      expect(f('bo'), ['Bob', 'Болат'], reason: 'bolat@ matches by e-mail');
    });

    test('resolve keeps only names still present, in text order', () {
      final picked = {'u-carol': 'Карина Ахметова', 'u-bob': 'Bob', 'u-gone': 'Удалён'};
      expect(ChatMentions.resolve('@Bob и @Карина Ахметова, привет', picked), ['u-bob', 'u-carol']);
      expect(ChatMentions.resolve('@Bobby привет', picked), isEmpty, reason: 'word boundary');
    });

    test('segments highlight mentioned ids only, longer names first', () {
      final names = {'u1': 'Анна', 'u2': 'Анна Петрова', 'u3': 'Bob'};
      final segs = ChatMentions.segments('@Анна Петрова и @Bob, @Анна', ['u1', 'u2'], names);
      expect(segs.map((s) => (s.text, s.userId)).toList(), [
        ('@Анна Петрова', 'u2'),
        (' и @Bob, ', null),
        ('@Анна', 'u1'),
      ]);
      expect(ChatMentions.segments('plain', const [], names).single.isMention, isFalse);
    });
  });

  group('contact messages', () {
    test('JSON round-trip: message, body and outbox placeholder', () {
      final json = ChatFixtures.message(
        id: 'm1',
        seq: 4,
        type: 'contact',
        body: '{"user_id":"${ChatFixtures.carol}"}',
        contact: {'user_id': ChatFixtures.carol, 'display_name': 'Карина', 'email': 'karina@example.kz'},
      );
      final m = ChatMessage.fromJson(json);
      expect(m.isContact, isTrue);
      expect(m.contact!.userId, ChatFixtures.carol);
      expect(m.contact!.label, 'Карина');
      final again = ChatMessage.fromJson(jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>);
      expect(again.contact!.toJson(), m.contact!.toJson());
      expect(again.body, m.body);

      const contact = ChatContact(userId: 'u-1', displayName: 'A', email: 'a@x');
      expect(jsonDecode(contact.toMessageBody()), {'user_id': 'u-1'}, reason: 'only user_id is sent');
      expect(ChatContact.userIdFromBody(contact.toMessageBody()), 'u-1');
      expect(ChatContact.userIdFromBody('not json'), isNull);

      final item = OutboxItem(
        clientMessageId: 'cid',
        conversationId: ChatFixtures.conv,
        type: 'contact',
        body: contact.toMessageBody(),
        createdAt: DateTime.utc(2026, 9, 14),
        contact: contact,
      );
      final restored = OutboxItem.fromJson(jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>);
      expect(restored.contact!.displayName, 'A');
      expect(restored.toPendingMessage('me').contact!.userId, 'u-1');
    });

    TestHarness? hh;
    tearDown(() async => hh?.dispose());

    test('send uses type contact with a JSON body; INVALID_CONTACT marks the item failed', () async {
      final h = hh = await TestHarness.create(storedToken: Fixtures.token, chatBaseUrl: 'http://chat.local/api/v1');
      h.adapter.onJson('GET', '/me', Fixtures.me());
      await h.session.restore();
      final repo = h.container.read(chatRepositoryProvider);
      await repo.cache.putConversation(ChatConversation.fromJson(ChatFixtures.conversation()));

      h.chatAdapter.on('POST', '/chats/${ChatFixtures.conv}/messages', (r) {
        return FakeResponse(
          201,
          json: ChatFixtures.message(
            id: 'srv-c',
            seq: 2,
            sender: ChatFixtures.me,
            type: 'contact',
            body: r.json['body'] as String,
            clientId: r.json['client_message_id'] as String,
            contact: {'user_id': ChatFixtures.carol, 'display_name': 'Карина', 'email': 'karina@example.kz'},
          ),
        );
      });
      await repo.sendContact(
        ChatFixtures.conv,
        const ChatContact(userId: ChatFixtures.carol, displayName: 'Карина', email: 'karina@example.kz'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final sent = h.chatAdapter.of('POST', '/chats/${ChatFixtures.conv}/messages').single.json;
      expect(sent.keys.toSet(), {'client_message_id', 'type', 'body'});
      expect(sent['type'], 'contact');
      expect(sent['body'], '{"user_id":"${ChatFixtures.carol}"}');
      final stored = (await repo.cache.messages(ChatFixtures.conv)).single;
      expect(stored.contact!.label, 'Карина');

      h.chatAdapter.onError('POST', '/chats/${ChatFixtures.conv}/messages', 400, 'INVALID_CONTACT');
      await repo.sendContact(ChatFixtures.conv, const ChatContact(userId: 'unknown'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final failed = (await repo.cache.outbox()).single;
      expect(failed.failed, isTrue);
      expect(failed.errorCode, 'INVALID_CONTACT');
      expect(failed.contact!.userId, 'unknown');
    });
  });

  group('media auto-download', () {
    test('decision table per NetworkKind', () {
      const expected = {
        MediaAutoDownload.never: {
          NetworkKind.none: false,
          NetworkKind.wifi: false,
          NetworkKind.mobile: false,
          NetworkKind.other: false,
        },
        MediaAutoDownload.wifiOnly: {
          NetworkKind.none: false,
          NetworkKind.wifi: true,
          NetworkKind.mobile: false,
          NetworkKind.other: false,
        },
        MediaAutoDownload.always: {
          NetworkKind.none: false,
          NetworkKind.wifi: true,
          NetworkKind.mobile: true,
          NetworkKind.other: true,
        },
      };
      for (final policy in MediaAutoDownload.values) {
        for (final kind in NetworkKind.values) {
          expect(policy.allows(kind), expected[policy]![kind], reason: '$policy on $kind');
        }
      }
      expect(MediaAutoDownload.parse(null), MediaAutoDownload.wifiOnly, reason: 'default');
      for (final p in MediaAutoDownload.values) {
        expect(MediaAutoDownload.parse(p.storageValue), p);
      }
    });

    TestHarness? hh;
    tearDown(() async => hh?.dispose());

    test('providers follow the stored policy and the network kind', () async {
      final monitor = FixedNetworkMonitor(NetworkKind.mobile);
      final h = hh = await TestHarness.create(
        chatBaseUrl: 'http://chat.local/api/v1',
        network: monitor,
      );
      final c = h.container;
      final sub = c.listen(chatMediaAutoAllowedProvider, (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.read(chatMediaAutoDownloadProvider), MediaAutoDownload.wifiOnly);
      expect(c.read(chatMediaAutoAllowedProvider), isFalse, reason: 'Wi-Fi only on mobile data');

      monitor.set(NetworkKind.wifi);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.read(chatMediaAutoAllowedProvider), isTrue);

      await c.read(chatMediaAutoDownloadProvider.notifier).set(MediaAutoDownload.never);
      expect(c.read(chatMediaAutoAllowedProvider), isFalse);
      expect(await c.read(chatCacheProvider).mediaAutoDownload(), MediaAutoDownload.never, reason: 'persisted in meta');
    });
  });

  group('chat storage', () {
    TestHarness? hh;
    tearDown(() async => hh?.dispose());

    test('messages kept per conversation is persisted, trims, and survives clear', () async {
      final h = hh = await TestHarness.create();
      final cache = ChatCache(h.db);
      await cache.putConversation(ChatConversation.fromJson(ChatFixtures.conversation()));
      for (var i = 1; i <= 120; i++) {
        await cache.putMessage(ChatMessage.fromJson(ChatFixtures.message(id: 'm$i', seq: i)));
      }
      expect(await cache.messages(ChatFixtures.conv), hasLength(100), reason: 'default 100');

      await cache.setMessageLimit(50);
      expect((await cache.messages(ChatFixtures.conv)).first.seq, 71);

      await cache.setMediaAutoDownload(MediaAutoDownload.always);
      await cache.clear();
      final fresh = ChatCache(h.db);
      expect(await fresh.messageLimit(), 50, reason: 'read back from meta by a new instance');
      expect(await fresh.mediaAutoDownload(), MediaAutoDownload.always);
    });

    test('media size, cached group avatar and clearing the media directory', () async {
      final tmp = Directory.systemTemp.createTempSync('xatbox_chat_unit');
      addTearDown(() {
        try {
          tmp.deleteSync(recursive: true);
        } on FileSystemException {
          // Windows may still hold a handle; the OS cleans temp later.
        }
      });
      final h = hh = await TestHarness.create(
        storedToken: Fixtures.token,
        chatBaseUrl: 'http://chat.local/api/v1',
        overrides: [chatMediaRootProvider.overrideWithValue(() async => tmp)],
      );
      h.adapter.onJson('GET', '/me', Fixtures.me());
      await h.session.restore();
      final repo = h.container.read(chatRepositoryProvider);
      expect(await repo.mediaSizeBytes(), 0);

      h.chatAdapter.on(
        'GET',
        '/chats/${ChatFixtures.conv}/avatar',
        (_) => const FakeResponse(200, text: 'JPEGDATA', contentType: 'image/jpeg'),
      );
      final first = await repo.avatarFile(ChatFixtures.conv);
      expect(first, isNotNull);
      expect(await first!.readAsString(), 'JPEGDATA');
      final again = await repo.avatarFile(ChatFixtures.conv);
      expect(again!.path, first.path, reason: 'served from disk');
      expect(h.chatAdapter.of('GET', '/chats/${ChatFixtures.conv}/avatar'), hasLength(1));
      final headers = h.chatAdapter.of('GET', '/chats/${ChatFixtures.conv}/avatar').single.headers;
      expect(headers['Authorization'], 'Bearer ${Fixtures.token}');

      expect(await repo.mediaSizeBytes(), 'JPEGDATA'.length);
      await repo.clearMedia();
      expect(await repo.mediaSizeBytes(), 0);
    });
  });
}
