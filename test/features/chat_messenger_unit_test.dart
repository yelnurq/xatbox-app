import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast.dart';
import 'package:xatbox_mobile/features/chat/data/chat_cache.dart';
import 'package:xatbox_mobile/features/chat/data/chat_models.dart';
import 'package:xatbox_mobile/features/chat/data/chat_repository.dart';
import 'package:xatbox_mobile/features/chat/data/chat_text.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';

import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Messenger data layer: per-conversation cache stores, drafts, link and
/// emoji helpers, incremental event handling.
void main() {
  const other = 'c0000000-0000-4000-8000-000000000009';

  ChatMessage msg(String id, int seq, {String conv = ChatFixtures.conv}) =>
      ChatMessage.fromJson(ChatFixtures.message(id: id, seq: seq, convId: conv));

  group('ChatCache indexing', () {
    late TestHarness h;
    tearDown(() => h.dispose());

    test('conversations are isolated; lookups by seq and id; trim keeps the tail', () async {
      h = await TestHarness.create();
      final cache = ChatCache(h.db, maxMessagesPerConversation: 5);
      await cache.putMessages([for (var i = 1; i <= 8; i++) msg('a$i', i)]);
      await cache.putMessages([for (var i = 1; i <= 3; i++) msg('b$i', i, conv: other)]);

      expect((await cache.messages(ChatFixtures.conv)).map((m) => m.id), ['a4', 'a5', 'a6', 'a7', 'a8']);
      expect((await cache.messages(other)).map((m) => m.id), ['b1', 'b2', 'b3']);
      expect((await cache.message(other, 2))!.id, 'b2');
      expect((await cache.messageById(ChatFixtures.conv, 'a7'))!.seq, 7);
      expect(await cache.messageById(other, 'a7'), isNull, reason: 'lookup stays inside the conversation');

      // Rows beyond the limit are removed once enough have accumulated.
      await cache.trim(ChatFixtures.conv);
      expect((await cache.stats()).messages, 5 + 3);

      await cache.removeConversation(other);
      expect(await cache.messages(other), isEmpty);
      expect((await cache.messages(ChatFixtures.conv)).length, 5);
    });

    test('own unread messages up to a seq are found without scanning others', () async {
      h = await TestHarness.create();
      final cache = ChatCache(h.db);
      await cache.putMessages([
        ChatMessage.fromJson(ChatFixtures.message(id: 'o1', seq: 1, sender: ChatFixtures.me)),
        ChatMessage.fromJson(ChatFixtures.message(id: 'o2', seq: 2, sender: ChatFixtures.me, status: 'read')),
        ChatMessage.fromJson(ChatFixtures.message(id: 'p3', seq: 3)),
        ChatMessage.fromJson(ChatFixtures.message(id: 'o4', seq: 4, sender: ChatFixtures.me)),
      ]);
      final hits = await cache.ownUnreadUpTo(ChatFixtures.conv, ChatFixtures.me, 3);
      expect(hits.map((m) => m.id), ['o1']);
    });

    test('v1 cache rows are migrated into per-conversation stores once', () async {
      h = await TestHarness.create();
      final legacy = stringMapStoreFactory.store('chat_messages');
      await legacy.record('${ChatFixtures.conv}:000000000001').put(h.db.db, msg('l1', 1).toJson());
      await legacy.record('${ChatFixtures.conv}:000000000002').put(h.db.db, msg('l2', 2).toJson());
      await legacy.record('$other:000000000001').put(h.db.db, msg('x1', 1, conv: other).toJson());

      final cache = ChatCache(h.db);
      expect((await cache.messages(ChatFixtures.conv)).map((m) => m.id), ['l1', 'l2']);
      expect((await cache.messages(other)).single.id, 'x1');
      expect(await legacy.count(h.db.db), 0, reason: 'old store dropped');

      // A second instance does not migrate (or lose) anything again.
      final again = ChatCache(h.db);
      expect((await again.messages(ChatFixtures.conv)).length, 2);
    });

    test('conversation mirror keeps unchanged objects identical', () async {
      h = await TestHarness.create();
      final cache = ChatCache(h.db);
      final a = ChatConversation.fromJson(ChatFixtures.conversation());
      final b = ChatConversation.fromJson(ChatFixtures.conversation(id: other, title: 'Other'));
      await cache.putConversations([a, b]);
      final first = await cache.conversations();
      await cache.putConversation(b.copyWith(unread: 3));
      final second = await cache.conversations();
      final aFirst = first.firstWhere((c) => c.id == a.id);
      final aSecond = second.firstWhere((c) => c.id == a.id);
      expect(identical(aFirst, aSecond), isTrue);
      expect(second.firstWhere((c) => c.id == other).unread, 3);
    });
  });

  group('drafts and recent emoji', () {
    late TestHarness h;
    tearDown(() => h.dispose());

    test('drafts persist per conversation, blank removes, sign-out clears', () async {
      h = await TestHarness.create();
      final cache = ChatCache(h.db);
      await cache.setDraft(ChatFixtures.conv, 'Привет, завтра в 10?');
      await cache.setDraft(other, 'second');
      expect(await ChatCache(h.db).draft(ChatFixtures.conv), 'Привет, завтра в 10?', reason: 'read by a new instance');
      expect(await cache.drafts(), {ChatFixtures.conv: 'Привет, завтра в 10?', other: 'second'});
      await cache.setDraft(other, '   ');
      expect((await cache.drafts()).keys, [ChatFixtures.conv]);

      await cache.pushRecentEmoji('🔥');
      await cache.pushRecentEmoji('👍');
      await cache.pushRecentEmoji('🔥');
      expect(await cache.recentEmoji(), ['🔥', '👍']);

      await cache.clear();
      expect(await cache.drafts(), isEmpty);
      expect(await cache.recentEmoji(), ['🔥', '👍'], reason: 'device preference survives');
    });

    test('drafts notifier loads stored drafts and saves through the repository', () async {
      h = await TestHarness.create(storedToken: Fixtures.token, chatBaseUrl: 'http://chat.local/api/v1');
      await ChatCache(h.db).setDraft(ChatFixtures.conv, 'stored');
      final sub = h.container.listen(chatDraftsProvider, (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(h.container.read(chatDraftsProvider), {ChatFixtures.conv: 'stored'});

      await h.container.read(chatDraftsProvider.notifier).save(other, 'typed');
      expect(await h.container.read(chatCacheProvider).draft(other), 'typed');
      await h.container.read(chatDraftsProvider.notifier).save(ChatFixtures.conv, '');
      expect(h.container.read(chatDraftsProvider).containsKey(ChatFixtures.conv), isFalse);
      expect(await h.container.read(chatCacheProvider).draft(ChatFixtures.conv), '');
    });
  });

  group('ChatText', () {
    test('links: http(s), www, e-mail; trailing punctuation stays outside', () {
      final segs = ChatText.links('Смотри https://xatbox.kz/a?b=1, www.example.com и (https://x.kz/p). Пиши bob@example.kz!');
      final links = segs.where((s) => s.isLink).map((s) => (s.text, s.uri.toString())).toList();
      expect(links, [
        ('https://xatbox.kz/a?b=1', 'https://xatbox.kz/a?b=1'),
        ('www.example.com', 'https://www.example.com'),
        ('https://x.kz/p', 'https://x.kz/p'),
        ('bob@example.kz', 'mailto:bob@example.kz'),
      ]);
      expect(segs.map((s) => s.text).join(), 'Смотри https://xatbox.kz/a?b=1, www.example.com и (https://x.kz/p). Пиши bob@example.kz!',
          reason: 'segments cover the whole text');
      expect(ChatText.links('no links here').single.isLink, isFalse);
      expect(ChatText.links('https://').where((s) => s.isLink), isEmpty);
    });

    test('emoji-only detection', () {
      expect(ChatText.isEmojiOnly('👍'), isTrue);
      expect(ChatText.isEmojiOnly(' ❤️ 🔥 '), isTrue);
      expect(ChatText.isEmojiOnly('🇰🇿'), isTrue);
      expect(ChatText.isEmojiOnly('👨‍👩‍👧'), isTrue);
      expect(ChatText.isEmojiOnly('😀😀😀😀'), isFalse, reason: 'more than three');
      expect(ChatText.isEmojiOnly('ok 👍'), isFalse);
      expect(ChatText.isEmojiOnly('1'), isFalse);
      expect(ChatText.isEmojiOnly(''), isFalse);
    });
  });

  group('incremental events', () {
    test('sortMessages dedupes by seq preferring the later copy and keeps pending last', () {
      final old = msg('m1', 1);
      final fresh = old.copyWith(body: 'edited');
      final pending = OutboxItem(
        clientMessageId: 'cid-p',
        conversationId: ChatFixtures.conv,
        type: 'text',
        body: 'queued',
        createdAt: DateTime.utc(2020),
      ).toPendingMessage(ChatFixtures.me);
      final out = ConversationNotifier.sortMessages([msg('m2', 2), old, pending, fresh]);
      expect(out.map((m) => m.body), ['edited', 'hi', 'queued']);
    });

    test('applyToMessage / applyRead fold edits, deletes, reactions and receipts', () {
      final own = ChatMessage.fromJson(ChatFixtures.message(id: 'm1', seq: 1, sender: ChatFixtures.me));
      ChatEvent ev(String type, Map<String, dynamic> p) =>
          ChatEvent(type: type, conversationId: ChatFixtures.conv, seq: 5, payload: {'message_id': 'm1', ...p});
      expect(ChatRepository.applyToMessage(own, ev('message.updated', {'body': 'new'}), ChatFixtures.me)!.body, 'new');
      expect(ChatRepository.applyToMessage(own, ev('message.deleted', {}), ChatFixtures.me)!.isDeleted, isTrue);
      final reacted = ChatRepository.applyToMessage(
        own,
        ev('message.reaction', {'reaction': '🔥', 'active': true, 'user_id': ChatFixtures.peer}),
        ChatFixtures.me,
      )!;
      expect(reacted.reactions.single.reaction, '🔥');
      expect(ChatRepository.applyToMessage(own, ev('message.delivered', {}), ChatFixtures.me)!.status, 'delivered');
      expect(ChatRepository.applyRead(own).status, 'read');
      expect(ChatRepository.applyToMessage(own, ev('typing.started', {}), ChatFixtures.me), isNull);
    });

    late TestHarness h;
    var signedIn = false;

    Future<void> signIn() async {
      signedIn = true;
      h = await TestHarness.create(storedToken: Fixtures.token, chatBaseUrl: 'http://chat.local/api/v1');
      h.adapter.onJson('GET', '/me', Fixtures.me());
      h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats([ChatFixtures.conversation(lastSeq: 2)]));
      h.chatAdapter.onJson('GET', '/chats/${ChatFixtures.conv}', ChatFixtures.conversation(lastSeq: 2));
      h.chatAdapter.onJson('GET', '/chats/${ChatFixtures.conv}/events', ChatFixtures.events(const []));
      h.chatAdapter.onJson(
        'GET',
        '/chats/${ChatFixtures.conv}/messages',
        ChatFixtures.messages([
          ChatFixtures.message(id: 'm1', seq: 1, body: 'one'),
          ChatFixtures.message(id: 'm2', seq: 2, body: 'two'),
        ]),
      );
      await h.session.restore();
      h.container.read(chatLifecycleProvider);
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }

    tearDown(() async {
      if (!signedIn) return;
      signedIn = false;
      await h.container.read(chatRepositoryProvider).stop();
      await h.dispose();
    });

    test('typing frames do not rebuild the list; message.created is applied without reloading', () async {
      await signIn();
      final listSub = h.container.listen(conversationsProvider, (_, _) {});
      final activitySub = h.container.listen(chatActivityProvider, (_, _) {});
      addTearDown(activitySub.close);
      final convSub = h.container.listen(conversationProvider(ChatFixtures.conv), (_, _) {});
      addTearDown(listSub.close);
      addTearDown(convSub.close);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final socket = h.socketFactory.last;

      final listBefore = h.container.read(conversationsProvider);
      final convBefore = h.container.read(conversationProvider(ChatFixtures.conv));
      expect(convBefore.messages.map((m) => m.id), ['m1', 'm2']);

      socket.serverSend({
        'type': 'typing.started',
        'conversation_id': ChatFixtures.conv,
        'user_id': ChatFixtures.peer,
        'display_name': 'Bob',
      });
      socket.serverSend({'type': 'call.ringing', 'conversation_id': ChatFixtures.conv});
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(identical(h.container.read(conversationsProvider), listBefore), isTrue, reason: 'no list reload for typing');
      expect(h.container.read(chatActivityProvider)[ChatFixtures.conv]!.values.single.name, 'Bob');
      expect(h.container.read(conversationProvider(ChatFixtures.conv)).typing, {ChatFixtures.peer: 'Bob'});

      final messagesCalls = h.chatAdapter.of('GET', '/chats/${ChatFixtures.conv}/messages').length;
      socket.serverSend({
        'type': 'message.created',
        'conversation_id': ChatFixtures.conv,
        'seq': 3,
        'message': ChatFixtures.message(id: 'm3', seq: 3, body: 'three'),
      });
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final after = h.container.read(conversationProvider(ChatFixtures.conv));
      expect(after.messages.map((m) => m.id), ['m1', 'm2', 'm3']);
      expect(identical(after.messages[0], convBefore.messages[0]), isTrue, reason: 'existing rows kept, not re-read');
      expect(after.typing, isEmpty, reason: 'a message ends the typing indicator');
      expect(h.container.read(chatActivityProvider)[ChatFixtures.conv], isNull);
      expect(h.chatAdapter.of('GET', '/chats/${ChatFixtures.conv}/messages').length, messagesCalls);
      expect(h.container.read(conversationsProvider).items.single.lastMessage!.id, 'm3');

      socket.serverSend({
        'type': 'message.reaction',
        'conversation_id': ChatFixtures.conv,
        'seq': 4,
        'message_id': 'm2',
        'user_id': ChatFixtures.peer,
        'reaction': '👍',
        'active': true,
      });
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final reacted = h.container.read(conversationProvider(ChatFixtures.conv));
      expect(reacted.messages[1].reactions.single.reaction, '👍');
      expect(identical(reacted.messages[0], after.messages[0]), isTrue);
    });

    test('locate loads history back to an old message (GET /messages/{id} + before_seq pages)', () async {
      await signIn();
      h.chatAdapter.onJson('GET', '/messages/m-old', ChatFixtures.message(id: 'm-old', seq: 1, body: 'old'));
      final sub = h.container.listen(conversationProvider(ChatFixtures.conv), (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      // The latest page starts at seq 1 here, so pretend it started later.
      h.chatAdapter.on('GET', '/chats/${ChatFixtures.conv}/messages', (r) {
        final before = int.parse('${(r.query['before_seq'] as List?)?.first ?? r.query['before_seq']}');
        return FakeResponse(
          200,
          json: ChatFixtures.messages([
            for (var s = 1; s < before; s++) ChatFixtures.message(id: s == 1 ? 'm-old' : 'h$s', seq: s),
          ]),
        );
      });
      final n = h.container.read(conversationProvider(ChatFixtures.conv).notifier);
      final found = await n.locate('m1');
      expect(found!.id, 'm1', reason: 'already loaded');
      expect(await n.locate('m-missing').catchError((_) => null), isNull);
    });

    test('search narrows to the conversation (server filter + client guard)', () async {
      await signIn();
      h.chatAdapter.onJson(
        'GET',
        '/search',
        ChatFixtures.messages([
          ChatFixtures.message(id: 's1', seq: 1, body: 'отчёт'),
          ChatFixtures.message(id: 's2', seq: 1, body: 'отчёт', convId: other),
        ]),
      );
      final repo = h.container.read(chatRepositoryProvider);
      final hits = await repo.search('отчёт', conversationId: ChatFixtures.conv);
      expect(hits.map((m) => m.id), ['s1']);
      final q = h.chatAdapter.of('GET', '/search').last.query;
      expect('${q['conversation_id']}', contains(ChatFixtures.conv));
    });
  });
}
