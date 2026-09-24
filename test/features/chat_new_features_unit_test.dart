import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:xatbox_mobile/core/routing/link_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/features/chat/data/chat_cache.dart';
import 'package:xatbox_mobile/features/chat/data/chat_models.dart';
import 'package:xatbox_mobile/features/chat/data/chat_repository.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_media_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_share.dart';

import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Saved Messages, link previews, delete for me, mark as unread, group
/// description, media listing and share intake: data layer and providers.
void main() {
  const conv = ChatFixtures.conv;
  const saved = 'c0000000-0000-4000-8000-00000000005a';
  const pinned = 'c0000000-0000-4000-8000-000000000011';

  Map<String, dynamic> savedJson({String updatedAt = '2026-09-01T10:00:00Z'}) {
    final j = ChatFixtures.conversation(id: saved, title: '', lastSeq: 0)
      ..remove('peer');
    return {
      ...j,
      'type': 'saved',
      'updated_at': updatedAt,
      'member_count': 1,
      'members': [ChatFixtures.member(ChatFixtures.me, 'Me', role: 'owner')],
    };
  }

  Map<String, dynamic> withSettings(
    Map<String, dynamic> c, {
    bool pinned = false,
    bool markedUnread = false,
  }) => {
    ...c,
    'settings': {
      'pinned': pinned,
      'archived': false,
      'last_read_seq': 0,
      'marked_unread': markedUnread,
    },
  };

  const preview = {
    'url': 'https://example.kz/news',
    'title': 'Новости',
    'description': 'Главное за день',
    'site_name': 'example.kz',
    'has_image': true,
    'image_width': 400,
    'image_height': 210,
  };

  group('models', () {
    test('saved chat, description, marked unread and link preview round-trip', () {
      final s = ChatConversation.fromJson(withSettings(savedJson(), markedUnread: true));
      expect(s.isSaved, isTrue);
      expect(s.hasUnread, isFalse, reason: 'Избранное never counts as unread');
      final g = ChatConversation.fromJson({
        ...withSettings(ChatFixtures.conversation(group: true), markedUnread: true),
        'description': 'Про проект',
      });
      expect(g.description, 'Про проект');
      expect(g.settings.markedUnread, isTrue);
      expect(g.hasUnread, isTrue);
      final again = ChatConversation.fromJson(g.toJson());
      expect(again.description, 'Про проект');
      expect(again.settings.markedUnread, isTrue);
      expect(again.copyWith(description: 'x').description, 'x');

      final m = ChatMessage.fromJson({
        ...ChatFixtures.message(id: 'm1', seq: 1, body: 'https://example.kz/news'),
        'link_preview': preview,
      });
      expect(m.linkPreview!.title, 'Новости');
      expect(m.linkPreview!.uri, Uri.parse('https://example.kz/news'));
      final back = ChatMessage.fromJson(m.toJson());
      expect(back.linkPreview!.imageWidth, 400);
      expect(m.copyWith(clearLinkPreview: true).linkPreview, isNull);
      expect(m.copyWith(body: 'edited').linkPreview, isNotNull);
    });

    test('media entries parse attachments and links', () {
      final a = ChatMediaEntry.fromJson({
        'message': ChatFixtures.message(id: 'mf', seq: 3),
        'attachment': ChatFixtures.attachment(id: 'att-f', kind: 'document'),
      });
      expect(a.attachment!.id, 'att-f');
      expect(a.url, isNull);
      final l = ChatMediaEntry.fromJson({
        'message': ChatFixtures.message(id: 'ml', seq: 4),
        'url': 'https://example.kz',
      });
      expect(l.attachment, isNull);
      expect(l.url, 'https://example.kz');
    });

    test('applyToMessage folds message.link_preview (set and clear)', () {
      final m = ChatMessage.fromJson(ChatFixtures.message(id: 'm1', seq: 1));
      ChatEvent ev(Object? p) => ChatEvent(
        type: 'message.link_preview',
        conversationId: conv,
        seq: 2,
        payload: {'message_id': 'm1', 'link_preview': p},
      );
      final withPreview = ChatRepository.applyToMessage(m, ev(preview), ChatFixtures.me)!;
      expect(withPreview.linkPreview!.siteName, 'example.kz');
      expect(withPreview.editedAt, isNull, reason: 'a preview is not an edit');
      expect(ChatRepository.applyToMessage(withPreview, ev(null), ChatFixtures.me)!.linkPreview, isNull);
      expect(ChatRepository.applyToMessage(m, ev(null), ChatFixtures.me), isNull);
    });

    test('unread badge: marked chats count once, Избранное and muted do not', () {
      final state = ConversationsState(
        items: [
          ChatConversation.fromJson(ChatFixtures.conversation(unread: 3)),
          ChatConversation.fromJson(
            withSettings(ChatFixtures.conversation(id: pinned), markedUnread: true),
          ),
          ChatConversation.fromJson(withSettings(savedJson(), markedUnread: true)),
        ],
      );
      expect(state.unreadTotal, 4);
    });

    test('shared intents map text, URLs, files and captions', () {
      final c = ChatShareContent.fromShared([
        SharedMediaFile(path: 'Посмотри', type: SharedMediaType.text),
        SharedMediaFile(path: 'https://example.kz', type: SharedMediaType.url),
        SharedMediaFile(
          path: 'file:///data/cache/photo%201.jpg',
          type: SharedMediaType.image,
          message: 'Посмотри',
        ),
        SharedMediaFile(path: '/data/cache/report.pdf', type: SharedMediaType.file),
      ]);
      expect(c.text, 'Посмотри\nhttps://example.kz');
      expect(c.files.map((f) => f.name), ['photo 1.jpg', 'report.pdf']);
      expect(c.files.first.path, '/data/cache/photo 1.jpg');
      expect(const ChatShareContent().isEmpty, isTrue);
    });
  });

  group('cache', () {
    late TestHarness h;
    tearDown(() => h.dispose());

    test('Избранное sorts above pinned chats; removeMessage drops one row', () async {
      h = await TestHarness.create();
      final cache = ChatCache(h.db);
      await cache.putConversations([
        ChatConversation.fromJson(ChatFixtures.conversation()),
        ChatConversation.fromJson(
          withSettings(ChatFixtures.conversation(id: pinned, title: 'Pinned'), pinned: true),
        ),
        ChatConversation.fromJson(savedJson()),
      ]);
      expect((await cache.conversations()).map((c) => c.id), [saved, pinned, conv]);

      await cache.putMessages([
        ChatMessage.fromJson(ChatFixtures.message(id: 'm1', seq: 1)),
        ChatMessage.fromJson(ChatFixtures.message(id: 'm2', seq: 2)),
      ]);
      expect(await cache.removeMessage(conv, 'm1'), isTrue);
      expect(await cache.removeMessage(conv, 'm1'), isFalse);
      expect((await cache.messages(conv)).map((m) => m.id), ['m2']);
    });
  });

  group('repository', () {
    late TestHarness h;
    tearDown(() => h.dispose());

    Future<ChatRepository> repo() async {
      h = await TestHarness.create(
        storedToken: Fixtures.token,
        chatBaseUrl: 'http://chat.local/api/v1',
      );
      return h.container.read(chatRepositoryProvider);
    }

    test('savedConversation creates Избранное once, then uses the cache', () async {
      final r = await repo();
      h.chatAdapter.onJson('POST', '/chats/saved', savedJson(), status: 201);
      final first = await r.savedConversation();
      final second = await r.savedConversation();
      expect(first.isSaved, isTrue);
      expect(second.id, saved);
      expect(h.chatAdapter.of('POST', '/chats/saved'), hasLength(1));
    });

    test('hide, mark unread and description call the API and update the cache', () async {
      final r = await repo();
      await r.cache.putConversation(ChatConversation.fromJson(ChatFixtures.conversation()));
      final m1 = ChatMessage.fromJson(ChatFixtures.message(id: 'm1', seq: 1));
      await r.cache.putMessages([m1, ChatMessage.fromJson(ChatFixtures.message(id: 'm2', seq: 2))]);
      h.chatAdapter.on('POST', '/messages/m1/hide', (_) => const FakeResponse(204));
      final events = <ChatEvent>[];
      final sub = r.events.listen(events.add);
      addTearDown(sub.cancel);

      await r.hideMessage(m1);
      await Future<void>.delayed(Duration.zero);
      expect(h.chatAdapter.of('POST', '/messages/m1/hide'), hasLength(1));
      expect((await r.cache.messages(conv)).map((m) => m.id), ['m2']);
      expect(events.single.type, 'message.hidden');
      expect(events.single.messageId, 'm1');

      h.chatAdapter.onJson(
        'PATCH',
        '/chats/$conv',
        withSettings(ChatFixtures.conversation(), markedUnread: true),
      );
      final marked = await r.markUnread(conv, true);
      expect(h.chatAdapter.of('PATCH', '/chats/$conv').last.json, {'marked_unread': true});
      expect(marked.settings.markedUnread, isTrue);
      expect((await r.cache.conversation(conv))!.settings.markedUnread, isTrue);

      h.chatAdapter.onJson('PATCH', '/chats/$conv', {
        ...ChatFixtures.conversation(group: true),
        'description': 'Итоги недели',
      });
      final described = await r.setDescription(conv, '  Итоги недели ');
      expect(h.chatAdapter.of('PATCH', '/chats/$conv').last.json, {'description': 'Итоги недели'});
      expect(described.description, 'Итоги недели');
    });

    test('media pages follow the cursor (notifier)', () async {
      await repo();
      h.chatAdapter.on('GET', '/chats/$conv/media', (req) {
        final second = req.query['cursor'] == 'c1';
        return FakeResponse(
          200,
          json: {
            'items': [
              {
                'message': ChatFixtures.message(id: second ? 'f2' : 'f1', seq: second ? 1 : 2),
                'attachment': ChatFixtures.attachment(id: second ? 'a2' : 'a1', kind: 'document'),
              },
            ],
            'next_cursor': second ? '' : 'c1',
          },
        );
      });
      const key = (conversationId: conv, kind: ChatMediaKind.file);
      final sub = h.container.listen(chatMediaListProvider(key), (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(h.container.read(chatMediaListProvider(key)).items, hasLength(1));
      expect(h.container.read(chatMediaListProvider(key)).hasMore, isTrue);
      await h.container.read(chatMediaListProvider(key).notifier).loadMore();
      final state = h.container.read(chatMediaListProvider(key));
      expect(state.items.map((e) => e.attachment!.id), ['a1', 'a2']);
      expect(state.hasMore, isFalse);
      final reqs = h.chatAdapter.of('GET', '/chats/$conv/media');
      expect(reqs.first.query['kind'], 'file');
      expect(reqs.first.query.containsKey('cursor'), isFalse);
      expect(reqs.last.query['cursor'], 'c1');
    });

    test('opening a chat marked as unread clears the flag', () async {
      await repo();
      final marked = withSettings(ChatFixtures.conversation(), markedUnread: true);
      h.chatAdapter.onJson('GET', '/chats/$conv', marked);
      h.chatAdapter.onJson('GET', '/chats/$conv/messages', ChatFixtures.messages(const []));
      h.chatAdapter.onJson('PATCH', '/chats/$conv', withSettings(ChatFixtures.conversation()));
      final sub = h.container.listen(conversationProvider(conv), (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(h.chatAdapter.of('PATCH', '/chats/$conv').single.json, {'marked_unread': false});
      expect(
        h.container.read(conversationProvider(conv)).conversation!.settings.markedUnread,
        isFalse,
      );
    });
  });

  group('socket events', () {
    late TestHarness h;

    Future<void> signIn() async {
      h = await TestHarness.create(storedToken: Fixtures.token, chatBaseUrl: 'http://chat.local/api/v1');
      h.adapter.onJson('GET', '/me', Fixtures.me());
      h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats([ChatFixtures.conversation(lastSeq: 2)]));
      h.chatAdapter.onJson('GET', '/chats/$conv', ChatFixtures.conversation(lastSeq: 2));
      h.chatAdapter.onJson('GET', '/chats/$conv/events', ChatFixtures.events(const []));
      h.chatAdapter.onJson(
        'GET',
        '/chats/$conv/messages',
        ChatFixtures.messages([
          ChatFixtures.message(id: 'm1', seq: 1, body: 'one https://example.kz/news'),
          ChatFixtures.message(id: 'm2', seq: 2, body: 'two'),
        ]),
      );
      await h.session.restore();
      h.container.read(chatLifecycleProvider);
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }

    tearDown(() async {
      await h.container.read(chatRepositoryProvider).stop();
      await h.dispose();
    });

    test('link previews arrive by event; hidden messages vanish; marked unread syncs', () async {
      await signIn();
      final listSub = h.container.listen(conversationsProvider, (_, _) {});
      final convSub = h.container.listen(conversationProvider(conv), (_, _) {});
      addTearDown(listSub.close);
      addTearDown(convSub.close);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final socket = h.socketFactory.last;
      final repo = h.container.read(chatRepositoryProvider);

      socket.serverSend({
        'type': 'message.link_preview',
        'conversation_id': conv,
        'seq': 3,
        'message_id': 'm1',
        'link_preview': preview,
      });
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final m1 = h.container.read(conversationProvider(conv)).messages.first;
      expect(m1.linkPreview!.title, 'Новости');
      expect((await repo.cache.messageById(conv, 'm1'))!.linkPreview, isNotNull);

      socket.serverSend({
        'type': 'message.hidden',
        'conversation_id': conv,
        'seq': 4,
        'message_id': 'm2',
        'user_id': ChatFixtures.me,
      });
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(h.container.read(conversationProvider(conv)).messages.map((m) => m.id), ['m1']);
      expect(await repo.cache.messageById(conv, 'm2'), isNull);

      final refreshes = h.chatAdapter.of('GET', '/chats/$conv').length;
      socket.serverSend({
        'type': 'chat.updated',
        'conversation_id': conv,
        'seq': 5,
        'change': 'marked_unread',
        'user_id': ChatFixtures.me,
        'marked_unread': true,
      });
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final item = h.container.read(conversationsProvider).items.single;
      expect(item.settings.markedUnread, isTrue);
      expect(item.hasUnread, isTrue);
      expect(h.chatAdapter.of('GET', '/chats/$conv').length, refreshes, reason: 'applied without a refetch');
    });
  });

  group('share intake', () {
    late TestHarness h;
    tearDown(() => h.dispose());

    test('a cold-start share is kept and opens the picker route; later shares replace it', () async {
      final source = _FakeShareSource(const ChatShareContent(text: 'Привет'));
      h = await TestHarness.create(
        chatBaseUrl: 'http://chat.local/api/v1',
        overrides: [chatShareSourceProvider.overrideWithValue(source)],
      );
      h.container.read(chatLifecycleProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(h.container.read(chatPendingShareProvider)!.text, 'Привет');
      expect(h.container.read(pendingNavigationProvider), Routes.chatShare);
      expect(source.resets, 1);

      source.controller.add(
        const ChatShareContent(files: [(path: '/tmp/a.jpg', name: 'a.jpg')]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(h.container.read(chatPendingShareProvider)!.files.single.name, 'a.jpg');
      expect(source.resets, 2);

      final prefill = h.container.read(chatSharePrefillProvider.notifier);
      prefill.put(conv, const ChatShareContent(text: 'x'));
      expect(prefill.take(conv)!.text, 'x');
      expect(prefill.take(conv), isNull, reason: 'taken once');
      await source.controller.close();
    });
  });
}

class _FakeShareSource implements ChatShareSource {
  _FakeShareSource(this.first);
  final ChatShareContent? first;
  final controller = StreamController<ChatShareContent>.broadcast();
  int resets = 0;

  @override
  Future<ChatShareContent?> initial() async => first;

  @override
  Stream<ChatShareContent> get shares => controller.stream;

  @override
  Future<void> reset() async => resets++;
}
