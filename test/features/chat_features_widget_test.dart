import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xatbox_mobile/core/localization/localization.dart';
import 'package:xatbox_mobile/core/network/network_status.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/core/theme/app_theme.dart';
import 'package:xatbox_mobile/features/calls/presentation/calls_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_video.dart';
import 'package:xatbox_mobile/features/chat/presentation/conversation_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/group_info_screen.dart';

import '../helpers/call_fakes.dart';
import '../helpers/fake_video.dart';
import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Mentions, contact cards, video previews with auto-download, group avatar
/// change — against the fake Chat API (and the fake Call Service).
void main() {
  late TestHarness h;
  late Directory tmp;
  late FixedNetworkMonitor network;
  final opened = <String>[];
  const conv = ChatFixtures.conv;
  const carolContact = {
    'user_id': ChatFixtures.carol,
    'display_name': 'Карина Ахметова',
    'email': 'karina@example.kz',
  };

  tearDown(() async {
    await h.dispose();
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // A file may still be open on Windows; temp is cleaned by the OS.
    }
  });

  Future<void> prepare({
    String callsBaseUrl = '',
    NetworkKind kind = NetworkKind.wifi,
    List<Override> extra = const [],
  }) async {
    // The composer constructs an AudioRecorder; answer its platform channel
    // (these tests let real async work complete, so the call would fail).
    const recordChannel = MethodChannel('com.llfbandit.record/messages');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(recordChannel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(recordChannel, null));
    tmp = Directory.systemTemp.createTempSync('xatbox_chat_widget');
    network = FixedNetworkMonitor(kind);
    opened.clear();
    h = await TestHarness.create(
      storedToken: Fixtures.token,
      chatBaseUrl: 'http://chat.local/api/v1',
      callsBaseUrl: callsBaseUrl,
      network: network,
      overrides: [
        chatMediaRootProvider.overrideWithValue(() async => tmp),
        chatFileOpenerProvider.overrideWithValue((path, mime) async {
          opened.add(path);
          return true;
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

  /// Widget tests run in FakeAsync; file I/O (media cache) completes only in
  /// real time, so alternate real waits with frames.
  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.runAsync(() => h.session.restore());
  }

  /// Unmounts the screens and lets debounce/snackbar timers expire.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  }

  List<Map<String, dynamic>> groupMembers() => [
    ChatFixtures.member(ChatFixtures.me, 'Me', role: 'owner'),
    ChatFixtures.member(ChatFixtures.peer, 'Bob'),
    ChatFixtures.member(ChatFixtures.carol, 'Карина Ахметова'),
  ];

  testWidgets(
    'mention picker inserts @Name, sends member ids; mentions are highlighted',
    (tester) async {
      await prepare();
      final group = ChatFixtures.conversation(
        group: true,
        title: 'Проект',
        members: groupMembers(),
      );
      stubConversation(group, [
        ChatFixtures.message(
          id: 'm1',
          seq: 1,
          body: '@Me посмотри, пожалуйста',
          mentions: [ChatFixtures.me],
        ),
      ]);
      h.chatAdapter.on('POST', '/chats/$conv/messages', (r) {
        return FakeResponse(
          201,
          json: ChatFixtures.message(
            id: 'm2',
            seq: 2,
            sender: ChatFixtures.me,
            body: r.json['body'] as String,
            mentions: ((r.json['mentions'] as List?) ?? const []).cast<String>(),
            clientId: r.json['client_message_id'] as String,
          ),
        );
      });
      await signIn(tester);
      await tester.pumpWidget(
        wrapWidget(
          const ConversationScreen(conversationId: conv),
          container: h.container,
        ),
      );
      await settle(tester);
      expect(
        find.byKey(const ValueKey('mentions_me_m1')),
        findsOneWidget,
        reason: 'a message mentioning me is emphasized',
      );
      expect(find.byKey(const ValueKey('mention_text_m1')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('chat_input')), 'Привет @ка');
      await tester.pump();
      expect(find.byKey(const Key('mention_picker')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mention_option_${ChatFixtures.carol}')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mention_option_${ChatFixtures.peer}')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('mention_option_${ChatFixtures.me}')),
        findsNothing,
        reason: 'you cannot mention yourself',
      );

      await tester.tap(
        find.byKey(const ValueKey('mention_option_${ChatFixtures.carol}')),
      );
      await tester.pump();
      final input = tester.widget<TextField>(find.byKey(const Key('chat_input')));
      expect(input.controller!.text, 'Привет @Карина Ахметова ');
      expect(find.byKey(const Key('mention_picker')), findsNothing);

      await tester.tap(find.byKey(const Key('chat_send')));
      await settle(tester);
      final sent = h.chatAdapter.of('POST', '/chats/$conv/messages').single.json;
      expect(sent.keys.toSet(), {'client_message_id', 'type', 'body', 'mentions'});
      expect(sent['body'], 'Привет @Карина Ахметова');
      expect(sent['mentions'], [ChatFixtures.carol]);
      expect(find.byKey(const ValueKey('mention_text_m2')), findsOneWidget);
      await finish(tester);
    },
  );

  testWidgets(
    'contact card: «Написать» opens the direct chat, «Позвонить» starts an audio call',
    (tester) async {
      await prepare(
        callsBaseUrl: 'http://calls.local/api/v1',
        extra: [
          callNativeProvider.overrideWithValue(FakeCallNative()),
          callMediaFactoryProvider.overrideWithValue(FakeCallMedia.new),
        ],
      );
      final calls = FakeCallServer(
        h.callsAdapter,
        selfId: ChatFixtures.me,
        selfName: 'Me',
      );
      stubConversation(ChatFixtures.conversation(), [
        ChatFixtures.message(
          id: 'mc',
          seq: 1,
          type: 'contact',
          body: '{"user_id":"${ChatFixtures.carol}"}',
          contact: carolContact,
        ),
      ]);
      const direct = 'c0000000-0000-4000-8000-000000000002';
      final directJson = ChatFixtures.conversation(
        id: direct,
        title: 'Карина Ахметова',
        lastSeq: 0,
      );
      h.chatAdapter.on('POST', '/chats', (_) => FakeResponse(201, json: directJson));
      stubConversation(directJson, const []);
      await signIn(tester);

      final router = GoRouter(
        initialLocation: Routes.chatConversationPath(conv),
        routes: [
          GoRoute(
            path: Routes.chatConversation,
            builder: (_, s) =>
                ConversationScreen(conversationId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: Routes.call,
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('CALL_SCREEN'))),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalization.delegates,
            supportedLocales: AppLocalization.supportedLocales,
            locale: const Locale('ru'),
            routerConfig: router,
          ),
        ),
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('contact_card_mc')), findsOneWidget);
      expect(find.text('Карина Ахметова'), findsOneWidget);
      expect(find.text('karina@example.kz'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('contact_write_${ChatFixtures.carol}')),
      );
      await settle(tester);
      expect(h.chatAdapter.of('POST', '/chats').single.json, {
        'type': 'direct',
        'user_id': ChatFixtures.carol,
      });
      expect(
        find.byWidgetPredicate(
          (w) => w is ConversationScreen && w.conversationId == direct,
        ),
        findsOneWidget,
        reason: 'the direct chat is opened',
      );

      router.pop();
      await settle(tester);
      await tester.tap(
        find.byKey(const ValueKey('contact_call_${ChatFixtures.carol}')),
      );
      await settle(tester, 20);
      expect(calls.createPosts, 1);
      final created = h.callsAdapter.of('POST', '/calls').single.json;
      expect(created['callee_ids'], [ChatFixtures.carol]);
      expect(created['type'], 'audio');
      expect(find.text('CALL_SCREEN'), findsOneWidget);

      unawaited(h.container.read(callControllerProvider.notifier).hangUp());
      await tester.pump(const Duration(seconds: 1));
      await finish(tester);
    },
  );

  testWidgets(
    'video tile shows the thumbnail and duration; a tap opens the in-app viewer',
    (tester) async {
      final videos = <FakeChatVideoController>[];
      await prepare(
        extra: [
          chatVideoFactoryProvider.overrideWithValue((_) {
            final c = FakeChatVideoController();
            videos.add(c);
            return c;
          }),
        ],
      );
      stubConversation(ChatFixtures.conversation(lastSeq: 2), [
        ChatFixtures.message(
          id: 'mv',
          seq: 1,
          type: 'video',
          body: '',
          attachments: [
            ChatFixtures.attachment(
              id: 'att-v1',
              width: 1280,
              height: 720,
              durationMs: 65000,
            ),
          ],
        ),
        ChatFixtures.message(
          id: 'mc',
          seq: 2,
          type: 'contact',
          body: '{"user_id":"${ChatFixtures.carol}"}',
          contact: carolContact,
        ),
      ]);
      h.chatAdapter.on(
        'GET',
        '/attachments/att-v1/thumbnail',
        (_) => const FakeResponse(200, text: 'thumb', contentType: 'image/jpeg'),
      );
      h.chatAdapter.on(
        'GET',
        '/attachments/att-v1',
        (_) => const FakeResponse(200, text: 'video', contentType: 'video/mp4'),
      );
      await signIn(tester);
      await tester.pumpWidget(
        wrapWidget(
          const ConversationScreen(conversationId: conv),
          container: h.container,
        ),
      );
      await settle(tester, 16);

      expect(h.chatAdapter.of('GET', '/attachments/att-v1/thumbnail'), hasLength(1));
      expect(
        h.chatAdapter.of('GET', '/attachments/att-v1'),
        isEmpty,
        reason: 'no original before a tap',
      );
      expect(find.byKey(const ValueKey('video_thumb_att-v1')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('video_duration_att-v1')),
          matching: find.text('1:05'),
        ),
        findsOneWidget,
      );
      // Calls are not configured: the contact card offers only «Написать».
      expect(
        find.byKey(const ValueKey('contact_write_${ChatFixtures.carol}')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('contact_call_${ChatFixtures.carol}')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('video_tile_att-v1')));
      await settle(tester, 16);
      // Wi-Fi: the viewer fetches the original ahead and plays it in-app.
      expect(find.byKey(const Key('chat_media_viewer')), findsOneWidget);
      expect(h.chatAdapter.of('GET', '/attachments/att-v1'), hasLength(1));
      expect(find.byKey(const Key('chat_video_player')), findsOneWidget);
      expect(videos.single.calls, ['init'], reason: 'not played until asked');
      expect(opened, isEmpty);
      await finish(tester);
    },
  );

  testWidgets(
    'Wi-Fi only on mobile data: previews wait for a tap on the placeholder',
    (tester) async {
      await prepare(kind: NetworkKind.mobile);
      stubConversation(ChatFixtures.conversation(), [
        ChatFixtures.message(
          id: 'mi',
          seq: 1,
          type: 'image',
          body: '',
          attachments: [
            ChatFixtures.attachment(
              id: 'att-i1',
              kind: 'image',
              filename: 'photo.jpg',
              mimeType: 'image/jpeg',
            ),
          ],
        ),
      ]);
      h.chatAdapter.on(
        'GET',
        '/attachments/att-i1/thumbnail',
        (_) => const FakeResponse(200, text: 'thumb', contentType: 'image/jpeg'),
      );
      await signIn(tester);
      await tester.pumpWidget(
        wrapWidget(
          const ConversationScreen(conversationId: conv),
          container: h.container,
        ),
      );
      await settle(tester);
      expect(h.chatAdapter.of('GET', '/attachments/att-i1/thumbnail'), isEmpty);
      expect(find.byKey(const ValueKey('image_thumb_att-i1')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('thumb_load_att-i1')));
      await settle(tester);
      expect(h.chatAdapter.of('GET', '/attachments/att-i1/thumbnail'), hasLength(1));
      expect(find.byKey(const ValueKey('image_thumb_att-i1')), findsOneWidget);
      expect(h.chatAdapter.of('GET', '/attachments/att-i1'), isEmpty);
      await finish(tester);
    },
  );

  testWidgets(
    'group admin changes the avatar: pick → upload → POST avatar → picture shown',
    (tester) async {
      late File picked;
      await prepare(
        extra: [
          chatImagePickerProvider.overrideWithValue(
            () async => (path: picked.path, name: 'team.jpg'),
          ),
        ],
      );
      picked = File('${tmp.path}${Platform.pathSeparator}team.jpg')
        ..writeAsStringSync('fake-jpeg');
      final group = ChatFixtures.conversation(
        group: true,
        title: 'Проект',
        members: groupMembers(),
      );
      stubConversation(group, const []);
      h.chatAdapter.on(
        'POST',
        '/chats/$conv/attachments',
        (_) => FakeResponse(
          201,
          json: ChatFixtures.attachment(
            id: 'att-avatar',
            kind: 'image',
            filename: 'team.jpg',
            mimeType: 'image/jpeg',
          ),
        ),
      );
      h.chatAdapter.on(
        'POST',
        '/chats/$conv/avatar',
        (_) => FakeResponse(
          200,
          json: ChatFixtures.conversation(
            group: true,
            title: 'Проект',
            members: groupMembers(),
            hasAvatar: true,
          ),
        ),
      );
      h.chatAdapter.on(
        'GET',
        '/chats/$conv/avatar',
        (_) => const FakeResponse(200, text: 'avatar', contentType: 'image/jpeg'),
      );
      await signIn(tester);
      await tester.pumpWidget(
        wrapWidget(
          const GroupInfoScreen(conversationId: conv),
          container: h.container,
        ),
      );
      await settle(tester);
      expect(
        find.byKey(const ValueKey('chat_avatar_fallback_$conv')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('group_avatar_change')));
      await settle(tester, 24);
      final upload = h.chatAdapter.of('POST', '/chats/$conv/attachments').single;
      expect(upload.body, contains('team.jpg'));
      expect(h.chatAdapter.of('POST', '/chats/$conv/avatar').single.json, {
        'attachment_id': 'att-avatar',
      });
      expect(h.chatAdapter.of('GET', '/chats/$conv/avatar'), hasLength(1));
      expect(
        find.byKey(const ValueKey('chat_avatar_image_$conv')),
        findsOneWidget,
      );
      expect(find.text('Фото группы обновлено'), findsOneWidget);
      await finish(tester);
    },
  );
}
