import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/network/network_status.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_list_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_media_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_share.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_share_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_video.dart';
import 'package:xatbox_mobile/features/chat/presentation/conversation_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/group_info_screen.dart';

import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fake_video.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Widgets of the new messenger features: Избранное, marked unread, delete
/// for me, link previews, group description, media screen, share flow and
/// in-app video — with 360 px layouts checked for overflow.
void main() {
  late TestHarness h;
  late Directory tmp;
  final openedLinks = <Uri>[];
  final openedFiles = <String>[];
  final videos = <FakeChatVideoController>[];
  const conv = ChatFixtures.conv;
  const group = 'c0000000-0000-4000-8000-000000000003';
  const saved = 'c0000000-0000-4000-8000-00000000005a';
  const pinned = 'c0000000-0000-4000-8000-000000000011';

  tearDown(() async {
    await h.dispose();
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // the OS cleans temp later
    }
  });

  Future<void> prepare({
    NetworkKind kind = NetworkKind.wifi,
    bool failVideo = false,
    List<Override> extra = const [],
  }) async {
    const recordChannel = MethodChannel('com.llfbandit.record/messages');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(recordChannel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(recordChannel, null));
    tmp = Directory.systemTemp.createTempSync('xatbox_new_features');
    openedLinks.clear();
    openedFiles.clear();
    videos.clear();
    h = await TestHarness.create(
      storedToken: Fixtures.token,
      chatBaseUrl: 'http://chat.local/api/v1',
      network: FixedNetworkMonitor(kind),
      overrides: [
        chatMediaRootProvider.overrideWithValue(() async => tmp),
        chatLinkOpenerProvider.overrideWithValue((uri) async {
          openedLinks.add(uri);
          return true;
        }),
        chatFileOpenerProvider.overrideWithValue((path, _) async {
          openedFiles.add(path);
          return true;
        }),
        chatVideoFactoryProvider.overrideWithValue((_) {
          final c = FakeChatVideoController(failInit: failVideo);
          videos.add(c);
          return c;
        }),
        ...extra,
      ],
    );
    h.adapter.onJson('GET', '/me', Fixtures.me());
    h.chatAdapter.onPattern(
      'POST',
      r'^/messages/[^/]+/read$',
      (_) => const FakeResponse(204),
    );
  }

  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> signIn(WidgetTester tester) =>
      tester.runAsync(() => h.session.restore());

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  }

  void useSize(WidgetTester tester) {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360, 740) * 3;
    addTearDown(tester.view.reset);
  }

  Map<String, dynamic> settings(
    Map<String, dynamic> c, {
    bool pin = false,
    bool marked = false,
  }) => {
    ...c,
    'settings': {
      'pinned': pin,
      'archived': false,
      'last_read_seq': 0,
      'marked_unread': marked,
    },
  };

  Map<String, dynamic> savedJson() {
    final j = ChatFixtures.conversation(id: saved, title: '', lastSeq: 0)
      ..remove('peer');
    return {
      ...j,
      'type': 'saved',
      'updated_at': '2026-09-01T10:00:00Z',
      'member_count': 1,
      'members': [ChatFixtures.member(ChatFixtures.me, 'Me', role: 'owner')],
    };
  }

  void stubConversation(
    Map<String, dynamic> c,
    List<Map<String, dynamic>> messages,
  ) {
    h.chatAdapter.onJson('GET', '/chats/${c['id']}', c);
    h.chatAdapter.onJson(
      'GET',
      '/chats/${c['id']}/messages',
      ChatFixtures.messages(messages),
    );
  }

  testWidgets(
    '360 px list: Избранное on top with a bookmark, marked unread dot, mark unread from the menu',
    (tester) async {
      useSize(tester);
      await prepare();
      final marked = settings(
        ChatFixtures.conversation(
          id: group,
          title: 'Очень длинное название рабочей группы для проверки переполнения',
          group: true,
          lastMessage: ChatFixtures.message(id: 'g1', seq: 1, convId: group, body: 'Длинный текст ' * 8),
        ),
        marked: true,
      );
      final pinnedChat = settings(ChatFixtures.conversation(id: pinned, title: 'Закреплённый'), pin: true);
      final direct = ChatFixtures.conversation(
        lastMessage: ChatFixtures.message(id: 'm1', seq: 1, body: 'Привет!'),
      );
      h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats([marked, direct, pinnedChat, savedJson()]));
      h.chatAdapter.on('PATCH', '/chats/$conv', (req) => FakeResponse(
        200,
        json: settings(direct, marked: req.json['marked_unread'] == true),
      ));
      await signIn(tester);
      await tester.pumpWidget(wrapWidget(const ChatListScreen(), container: h.container));
      await settle(tester);

      expect(find.byKey(const ValueKey('chat_avatar_saved_$saved')), findsOneWidget);
      expect(find.text('Избранное'), findsOneWidget);
      expect(find.text('Заметки и файлы только для вас'), findsOneWidget);
      double top(String id) => tester.getTopLeft(find.byKey(ValueKey('chat_$id'))).dy;
      expect(top(saved), lessThan(top(pinned)));
      expect(top(pinned), lessThan(top(group)));
      expect(find.byKey(const ValueKey('chat_marked_unread_$group')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.longPress(find.byKey(const ValueKey('chat_$conv')));
      await settle(tester, 6);
      expect(find.text('Пометить как непрочитанное'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat_action_mark_unread')));
      await settle(tester, 8);
      expect(h.chatAdapter.of('PATCH', '/chats/$conv').single.json, {'marked_unread': true});
      expect(find.byKey(const ValueKey('chat_marked_unread_$conv')), findsOneWidget);

      // The unread filter keeps marked chats and drops Избранное.
      await tester.tap(find.byKey(const Key('chat_filter_unread')));
      await settle(tester, 4);
      expect(find.byKey(const ValueKey('chat_$group')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat_$conv')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat_$saved')), findsNothing);
      expect(tester.takeException(), isNull);
      await finish(tester);
    },
  );

  testWidgets('delete for me hides a message; «Сохранить в Избранное» forwards it', (tester) async {
    useSize(tester);
    await prepare();
    stubConversation(ChatFixtures.conversation(lastSeq: 2), [
      ChatFixtures.message(id: 'm1', seq: 1, body: 'Секрет'),
      ChatFixtures.message(id: 'm2', seq: 2, body: 'Важная заметка'),
    ]);
    h.chatAdapter.on('POST', '/messages/m1/hide', (_) => const FakeResponse(204));
    h.chatAdapter.onJson('POST', '/chats/saved', savedJson(), status: 201);
    h.chatAdapter.on('POST', '/chats/$saved/messages', (req) => FakeResponse(
      201,
      json: ChatFixtures.message(
        id: 's1',
        seq: 1,
        convId: saved,
        sender: ChatFixtures.me,
        clientId: req.json['client_message_id'] as String,
        body: 'Важная заметка',
      ),
    ));
    await signIn(tester);
    await tester.pumpWidget(
      wrapWidget(const ConversationScreen(conversationId: conv), container: h.container),
    );
    await settle(tester, 14);

    await tester.longPress(find.text('Секрет'));
    await settle(tester, 6);
    expect(find.text('Удалить у меня'), findsOneWidget);
    expect(find.text('Удалить у всех'), findsOneWidget, reason: 'owners of a direct chat may delete');
    await tester.ensureVisible(find.byKey(const Key('message_delete_for_me')));
    await tester.tap(find.byKey(const Key('message_delete_for_me')));
    await settle(tester, 8);
    expect(h.chatAdapter.of('POST', '/messages/m1/hide'), hasLength(1));
    expect(find.text('Секрет'), findsNothing);

    await tester.longPress(find.text('Важная заметка'));
    await settle(tester, 6);
    await tester.ensureVisible(find.byKey(const Key('message_save_to_saved')));
    await tester.tap(find.byKey(const Key('message_save_to_saved')));
    await settle(tester, 12);
    expect(h.chatAdapter.of('POST', '/chats/saved'), hasLength(1));
    final sent = h.chatAdapter.of('POST', '/chats/$saved/messages');
    expect(sent.single.json['forward_of_id'], 'm2');
    expect(find.text('Сохранено в Избранное'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('360 px: link preview card shows site, title and opens the link', (tester) async {
    useSize(tester);
    await prepare(kind: NetworkKind.mobile);
    stubConversation(ChatFixtures.conversation(), [
      {
        ...ChatFixtures.message(id: 'm1', seq: 1, body: 'Смотри https://example.kz/news/${'long-segment/' * 8}'),
        'link_preview': {
          'url': 'https://example.kz/news',
          'title': 'Очень длинный заголовок новости для проверки переноса строк ' * 2,
          'description': 'Описание ' * 40,
          'site_name': 'example.kz',
          'has_image': true,
          'image_width': 400,
          'image_height': 210,
        },
      },
    ]);
    await signIn(tester);
    await tester.pumpWidget(
      wrapWidget(const ConversationScreen(conversationId: conv), container: h.container),
    );
    await settle(tester, 14);
    final card = find.byKey(const ValueKey('link_preview_m1'));
    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('example.kz')), findsOneWidget);
    expect(
      h.chatAdapter.requests.where((r) => r.path.contains('link-preview')),
      isEmpty,
      reason: 'no picture on mobile data with Wi-Fi-only auto-download',
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.descendant(of: card, matching: find.text('example.kz')));
    await settle(tester, 4);
    expect(openedLinks.single, Uri.parse('https://example.kz/news'));
    await finish(tester);
  });

  testWidgets('360 px group info: description is shown and edited by an admin', (tester) async {
    useSize(tester);
    await prepare();
    final g = {
      ...ChatFixtures.conversation(
        id: group,
        title: 'Проект',
        group: true,
        members: [
          ChatFixtures.member(ChatFixtures.me, 'Me', role: 'owner'),
          ChatFixtures.member(ChatFixtures.peer, 'Bob'),
        ],
      ),
      'description': 'Обсуждаем проект ' * 12,
    };
    stubConversation(g, const []);
    h.chatAdapter.on('PATCH', '/chats/$group', (req) => FakeResponse(
      200,
      json: {...g, 'description': req.json['description']},
    ));
    await signIn(tester);
    await tester.pumpWidget(
      wrapWidget(const GroupInfoScreen(conversationId: group), container: h.container),
    );
    await settle(tester, 12);
    expect(find.byKey(const Key('group_description')), findsOneWidget);
    expect(find.byKey(const Key('chat_info_media')), findsOneWidget);
    expect(find.text('Медиа, файлы и ссылки'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('group_description')));
    await settle(tester, 6);
    await tester.enterText(find.byKey(const Key('group_description_field')), 'Новое описание');
    await tester.tap(find.byKey(const Key('group_description_save')));
    await settle(tester, 8);
    expect(h.chatAdapter.of('PATCH', '/chats/$group').single.json, {'description': 'Новое описание'});
    expect(find.text('Новое описание'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a member sees the description but cannot edit it', (tester) async {
    await prepare();
    final g = {
      ...ChatFixtures.conversation(id: group, title: 'Проект', group: true, myRole: 'member'),
      'description': '',
    };
    stubConversation(g, const []);
    await signIn(tester);
    await tester.pumpWidget(
      wrapWidget(const GroupInfoScreen(conversationId: group), container: h.container),
    );
    await settle(tester, 12);
    expect(find.byKey(const Key('group_description')), findsNothing);
    expect(find.byKey(const Key('chat_info_media')), findsOneWidget);
    await finish(tester);
  });

  testWidgets('360 px media screen: tabs by kind; «Показать в чате» returns the message id', (
    tester,
  ) async {
    useSize(tester);
    await prepare();
    h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats([ChatFixtures.conversation()]));
    h.chatAdapter.on('GET', '/chats/$conv/media', (req) {
      final items = switch (req.query['kind']) {
        'media' => [
          {
            'message': ChatFixtures.message(id: 'mp', seq: 5, type: 'image', body: ''),
            'attachment': ChatFixtures.attachment(id: 'att-img', kind: 'image', filename: 'p.jpg', mimeType: 'image/jpeg'),
          },
        ],
        'file' => [
          {
            'message': ChatFixtures.message(id: 'mf', seq: 4, type: 'file', body: ''),
            'attachment': ChatFixtures.attachment(
              id: 'att-f',
              kind: 'document',
              filename: '${'очень_длинное_имя_файла_' * 5}.pdf',
              mimeType: 'application/pdf',
              hasThumbnail: false,
            ),
          },
        ],
        'link' => [
          {
            'message': {
              ...ChatFixtures.message(id: 'ml', seq: 3, body: 'https://example.kz/news'),
              'link_preview': {'url': 'https://example.kz/news', 'title': 'Новости', 'has_image': false},
            },
            'url': 'https://example.kz/news',
          },
        ],
        _ => [
          {
            'message': ChatFixtures.message(id: 'mv', seq: 2, type: 'voice', body: ''),
            'attachment': ChatFixtures.attachment(
              id: 'att-voice',
              kind: 'voice',
              filename: 'voice.m4a',
              mimeType: 'audio/mp4',
              hasThumbnail: false,
              durationMs: 83000,
            ),
          },
        ],
      };
      return FakeResponse(200, json: {'items': items, 'next_cursor': ''});
    });
    h.chatAdapter.on('GET', '/attachments/att-img/thumbnail', (_) => const FakeResponse(200, text: 'x', contentType: 'image/jpeg'));
    h.chatAdapter.on('GET', '/attachments/att-img', (_) => const FakeResponse(200, text: 'x', contentType: 'image/jpeg'));
    await signIn(tester);
    String? result;
    await tester.pumpWidget(
      wrapWidget(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('open_media'),
                onPressed: () async {
                  result = await Navigator.of(context).push<String>(
                    MaterialPageRoute(builder: (_) => const ChatMediaScreen(conversationId: conv)),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
        container: h.container,
      ),
    );
    await tester.tap(find.byKey(const Key('open_media')));
    await settle(tester, 12);
    expect(find.byKey(const ValueKey('media_grid_att-img')), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Grid → viewer → «Показать в чате».
    await tester.tap(find.byKey(const ValueKey('media_grid_att-img')));
    await settle(tester, 10);
    expect(find.byKey(const Key('chat_media_viewer')), findsOneWidget);
    await tester.tap(find.byKey(const Key('media_show_in_chat')));
    await settle(tester, 10);
    expect(result, 'mp');
    expect(find.byKey(const Key('chat_media_viewer')), findsNothing);

    await tester.tap(find.byKey(const Key('open_media')));
    await settle(tester, 10);
    for (final (tab, key) in [
      ('file', 'media_file_att-f'),
      ('link', 'media_link_ml'),
      ('voice', 'media_voice_att-voice'),
    ]) {
      await tester.tap(find.byKey(Key('chat_media_tab_$tab')));
      await settle(tester, 10);
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: tab);
      expect(tester.takeException(), isNull, reason: tab);
      if (tab == 'link') {
        await tester.tap(find.byKey(const ValueKey('media_link_ml')));
        await settle(tester, 4);
        expect(openedLinks.single, Uri.parse('https://example.kz/news'));
      }
    }
    await tester.tap(find.byKey(const ValueKey('media_show_att-voice')));
    await settle(tester, 8);
    expect(result, 'mv');
    expect(
      h.chatAdapter.of('GET', '/chats/$conv/media').map((r) => r.query['kind']).toSet(),
      {'media', 'file', 'link', 'voice'},
    );
    await finish(tester);
  });

  testWidgets('share flow: pick Избранное, the composer is prefilled, send uploads and posts', (
    tester,
  ) async {
    useSize(tester);
    await prepare();
    final shared = File('${tmp.path}/report.pdf')..writeAsStringSync('%PDF-1.4 test');
    h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats([ChatFixtures.conversation()]));
    h.chatAdapter.onJson('POST', '/chats/saved', savedJson(), status: 201);
    stubConversation(savedJson(), const []);
    h.chatAdapter.onJson(
      'POST',
      '/chats/$saved/attachments',
      ChatFixtures.attachment(id: 'att-up', kind: 'document', filename: 'report.pdf', mimeType: 'application/pdf', convId: saved),
      status: 201,
    );
    var seq = 0;
    h.chatAdapter.on('POST', '/chats/$saved/messages', (req) {
      seq++;
      return FakeResponse(
        201,
        json: ChatFixtures.message(
          id: 's$seq',
          seq: seq,
          convId: saved,
          sender: ChatFixtures.me,
          clientId: req.json['client_message_id'] as String,
          body: (req.json['body'] as String?) ?? '',
        ),
      );
    });
    await signIn(tester);
    h.container.read(chatPendingShareProvider.notifier).set(
      ChatShareContent(text: 'Отчёт за неделю', files: [(path: shared.path, name: 'report.pdf')]),
    );
    String? opened;
    await tester.pumpWidget(
      wrapWidget(
        ChatShareScreen(onOpenConversation: (_, id) => opened = id),
        container: h.container,
      ),
    );
    await settle(tester, 8);
    expect(find.byKey(const Key('share_summary')), findsOneWidget);
    expect(find.text('Вложений: 1: report.pdf'), findsOneWidget);
    expect(find.byKey(const ValueKey('share_pick_$conv')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('share_pick_saved')));
    await settle(tester, 8);
    expect(opened, saved);
    expect(h.container.read(chatPendingShareProvider), isNull);

    await tester.pumpWidget(
      wrapWidget(const ConversationScreen(conversationId: saved), container: h.container),
    );
    await settle(tester, 12);
    expect(find.text('Избранное'), findsOneWidget);
    expect(find.byKey(const ValueKey('pending_file_0')), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const Key('chat_input'))).controller!.text,
      'Отчёт за неделю',
    );
    expect(find.byKey(const Key('chat_audio_call')), findsNothing, reason: 'no calls in Избранное');
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('chat_send')));
    await settle(tester, 20);
    expect(h.chatAdapter.of('POST', '/chats/$saved/attachments'), hasLength(1));
    final posts = h.chatAdapter.of('POST', '/chats/$saved/messages');
    expect(posts, hasLength(2));
    expect(posts.any((r) => (r.json['attachment_ids'] as List?)?.contains('att-up') ?? false), isTrue);
    expect(posts.any((r) => r.json['body'] == 'Отчёт за неделю'), isTrue);
    expect(find.byKey(const ValueKey('pending_file_0')), findsNothing);
    await finish(tester);
  });

  Future<void> openVideo(WidgetTester tester) async {
    stubConversation(ChatFixtures.conversation(), [
      ChatFixtures.message(
        id: 'mv',
        seq: 1,
        type: 'video',
        body: '',
        attachments: [ChatFixtures.attachment(id: 'att-v1', width: 1280, height: 720, durationMs: 65000)],
      ),
    ]);
    h.chatAdapter.on('GET', '/attachments/att-v1/thumbnail', (_) => const FakeResponse(200, text: 't', contentType: 'image/jpeg'));
    h.chatAdapter.on('GET', '/attachments/att-v1', (_) => const FakeResponse(200, text: 'video', contentType: 'video/mp4'));
    await signIn(tester);
    await tester.pumpWidget(
      wrapWidget(const ConversationScreen(conversationId: conv), container: h.container),
    );
    await settle(tester, 14);
    final tile = find.byKey(const ValueKey('video_tile_att-v1'));
    await tester.tapAt(tester.getTopLeft(tile) + const Offset(12, 12));
    await settle(tester, 10);
    expect(find.byKey(const Key('chat_media_viewer')), findsOneWidget);
    expect(
      h.chatAdapter.of('GET', '/attachments/att-v1'),
      isEmpty,
      reason: 'mobile data: the original waits for play',
    );
    await tester.tap(find.byKey(const ValueKey('viewer_play_att-v1')));
    await settle(tester, 12);
    expect(h.chatAdapter.of('GET', '/attachments/att-v1'), hasLength(1));
  }

  testWidgets('video plays in the viewer with play/pause and mute', (tester) async {
    useSize(tester);
    await prepare(kind: NetworkKind.mobile);
    await openVideo(tester);
    expect(find.byKey(const Key('chat_video_player')), findsOneWidget);
    final video = videos.single;
    expect(video.calls, containsAllInOrder(['init', 'play']));
    expect(find.byKey(const Key('video_seek')), findsOneWidget);
    await tester.tap(find.byKey(const Key('video_toggle')));
    await settle(tester, 2);
    expect(video.calls.last, 'pause');
    await tester.tap(find.byKey(const Key('video_mute')));
    await settle(tester, 2);
    expect(video.calls.last, 'mute:true');
    expect(openedFiles, isEmpty);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('a video the player cannot open falls back to another app', (tester) async {
    await prepare(kind: NetworkKind.mobile, failVideo: true);
    await openVideo(tester);
    expect(openedFiles.single, endsWith('att-v1_clip.mp4'));
    expect(find.text('Не удалось воспроизвести видео'), findsWidgets);
    await finish(tester);
  });
}
