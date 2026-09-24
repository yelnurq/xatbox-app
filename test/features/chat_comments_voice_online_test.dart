import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/api/api_exception.dart';
import 'package:xatbox_mobile/core/localization/generated/app_localizations.dart';
import 'package:xatbox_mobile/core/network/network_status.dart';
import 'package:xatbox_mobile/features/chat/data/chat_broadcast.dart';
import 'package:xatbox_mobile/features/chat/data/chat_cache.dart';
import 'package:xatbox_mobile/features/chat/data/chat_models.dart';
import 'package:xatbox_mobile/features/chat/data/chat_repository.dart';
import 'package:xatbox_mobile/features/chat/data/push_notifications.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_storage_settings.dart';
import 'package:xatbox_mobile/features/chat/presentation/comments/channel_thread_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/conversation_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/group_info_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/scheduled/scheduled_widgets.dart';
import 'package:xatbox_mobile/features/chat/presentation/voice_record_mode.dart';

import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Channel post comments, tap-to-record voice and «Отправить, когда
/// появится в сети».
void main() {
  const conv = ChatFixtures.conv;
  const grp = 'c0000000-0000-4000-8000-000000000003';
  const channel = 'c0000000-0000-4000-8000-0000000000c1';

  group('units', () {
    test('post.comments sets the count; comment fields round-trip', () {
      final post = ChatMessage.fromJson({
        ...ChatFixtures.message(id: 'post1', seq: 1, convId: channel),
        'comment_count': 2,
      });
      final ev = ChatEvent.fromFrame({
        'type': 'post.comments',
        'conversation_id': channel,
        'message_id': 'post1',
        'comment_count': 3,
        'seq': 5,
      });
      expect(ChatRepository.applyToMessage(post, ev, ChatFixtures.me)!.commentCount, 3);
      expect(ChatRepository.applyToMessage(post.copyWith(commentCount: 3), ev, ChatFixtures.me), isNull);

      final comment = ChatMessage.fromJson({
        ...ChatFixtures.message(id: 'c1', seq: 2, convId: channel),
        'thread_root_id': 'post1',
      });
      expect(comment.isComment, isTrue);
      expect(ChatMessage.fromJson(comment.toJson()).threadRootId, 'post1');
      expect(ChatMessage.fromJson(post.toJson()).commentCount, 2);
      final c = ChatConversation.fromJson({...ChatFixtures.conversation(id: channel), 'type': 'channel', 'comments_enabled': true});
      expect(ChatConversation.fromJson(c.toJson()).commentsEnabled, isTrue);
    });

    test('scheduled «when online» items and the timeout', () {
      final waiting = ChatScheduledMessage.fromJson({
        'id': 's1',
        'conversation_id': conv,
        'send_at': '2026-09-22T10:00:00Z',
        'when_online_user_id': ChatFixtures.peer,
        'status': 'pending',
      });
      expect(waiting.whenOnline, isTrue);
      expect(waiting.whenOnlineTimedOut, isFalse);
      final failed = ChatScheduledMessage.fromJson({
        'id': 's2',
        'conversation_id': conv,
        'send_at': '2026-09-22T10:00:00Z',
        'when_online_user_id': ChatFixtures.peer,
        'status': 'failed',
        'last_error': 'WHEN_ONLINE_TIMEOUT',
      });
      expect(failed.whenOnlineTimedOut, isTrue);
    });

    test('chat.comment pushes keep the thread root; scheduled_failed has its text', () {
      final comment = buildPushNotificationContent({
        'type': 'chat.comment',
        'conversation_id': channel,
        'message_id': 'c1',
        'thread_root_id': 'post1',
        'chat_type': 'channel',
        'sender_name': 'Bob',
        'body': 'Согласен',
      })!;
      expect(comment.payload, contains('"thread_root_id":"post1"'));
      final failed = buildPushNotificationContent({
        'type': 'chat.scheduled_failed',
        'conversation_id': conv,
        'scheduled_id': 's2',
      })!;
      expect(failed.body, 'Не отправлено: собеседник не появился в сети');
      expect(failed.payload, contains('"scheduled_id":"s2"'));
    });
  });

  group('widgets', () {
    late TestHarness h;
    late Directory tmp;
    TestDefaultBinaryMessenger messenger() =>
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final recordCalls = <String>[];

    tearDown(() async {
      await h.dispose();
      try {
        tmp.deleteSync(recursive: true);
      } on FileSystemException {
        // cleaned later
      }
    });

    /// Record, microphone permission and temp dir plugins played by the test.
    void mockVoicePlugins() {
      recordCalls.clear();
      const record = MethodChannel('com.llfbandit.record/messages');
      const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
      const paths = MethodChannel('plugins.flutter.io/path_provider');
      messenger().setMockMethodCallHandler(record, (call) async {
        recordCalls.add(call.method);
        if (call.method == 'create') {
          final id = (call.arguments as Map)['recorderId'];
          messenger().setMockStreamHandler(
            EventChannel('com.llfbandit.record/events/$id'),
            MockStreamHandler.inline(onListen: (_, _) {}),
          );
        }
        if (call.method == 'stop') return '${tmp.path}/voice.m4a';
        if (call.method == 'hasPermission' || call.method == 'isRecording') return true;
        return null;
      });
      messenger().setMockMethodCallHandler(permissions, (call) async {
        if (call.method == 'requestPermissions') return {7: 1}; // microphone: granted
        if (call.method == 'checkPermissionStatus') return 1;
        return null;
      });
      messenger().setMockMethodCallHandler(paths, (_) async => tmp.path);
      addTearDown(() {
        messenger().setMockMethodCallHandler(record, null);
        messenger().setMockMethodCallHandler(permissions, null);
        messenger().setMockMethodCallHandler(paths, null);
      });
    }

    Future<void> prepare() async {
      tmp = Directory.systemTemp.createTempSync('xatbox_comments');
      mockVoicePlugins();
      h = await TestHarness.create(
        storedToken: Fixtures.token,
        chatBaseUrl: 'http://chat.local/api/v1',
        network: FixedNetworkMonitor(NetworkKind.wifi),
        overrides: [chatMediaRootProvider.overrideWithValue(() async => tmp)],
      );
      h.adapter.onJson('GET', '/me', Fixtures.me());
      h.chatAdapter.onPattern('POST', r'^/messages/[^/]+/read$', (_) => const FakeResponse(204));
      h.chatAdapter.onPattern('GET', r'^/chats/[^/]+/scheduled$', (_) => const FakeResponse(200, json: {'scheduled': []}));
      h.chatAdapter.onPattern('GET', r'^/chats/[^/]+/events$', (_) => const FakeResponse(200, json: {'events': []}));
      h.chatAdapter.onJson('GET', '/me/status', {'status': null});
      h.chatAdapter.onJson('GET', '/me/chat-folders', {'folders': []});
    }

    Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
      for (var i = 0; i < rounds; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> signIn(WidgetTester tester) => tester.runAsync(() => h.session.restore());

    Future<void> finish(WidgetTester tester) async {
      unawaited(h.container.read(chatRepositoryProvider).stop());
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 10));
    }

    void usePhone(WidgetTester tester, {double textScale = 1.3}) {
      tester.view.physicalSize = const Size(1080, 2220);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }

    Future<void> expectGuidelines(WidgetTester tester) async {
      expect(tester.takeException(), isNull, reason: 'no overflow at 360 dp / 130 %');
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }

    Map<String, dynamic> channelJson({bool enabled = true, String myRole = 'owner', int lastSeq = 2}) => {
      ...ChatFixtures.conversation(
        id: channel,
        title: 'Новости кафедры',
        group: true,
        myRole: myRole,
        lastSeq: lastSeq,
        members: [ChatFixtures.member(ChatFixtures.me, 'Me', role: 'owner')],
      ),
      'type': 'channel',
      'is_public': true,
      'comments_enabled': enabled,
      'member_count': 40,
    };

    Map<String, dynamic> post(String id, int seq, String body, {int? comments}) => {
      ...ChatFixtures.message(id: id, seq: seq, convId: channel, sender: ChatFixtures.me, body: body),
      'views': 12,
      'comment_count': ?comments,
    };

    Map<String, dynamic> comment(String id, int seq, String body, {String sender = ChatFixtures.peer, String? clientId}) => {
      ...ChatFixtures.message(id: id, seq: seq, convId: channel, sender: sender, body: body, clientId: clientId),
      'thread_root_id': 'post1',
    };

    testWidgets('channel posts: comment buttons; thread messages stay out of the feed; post.comments folds', (tester) async {
      usePhone(tester, textScale: 1);
      await prepare();
      h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats([channelJson()]));
      h.chatAdapter.onJson('GET', '/chats/$channel', channelJson());
      h.chatAdapter.onJson('GET', '/chats/$channel/messages', ChatFixtures.messages([
        post('post1', 1, 'Семинар в пятницу', comments: 3),
        post('post2', 2, 'Расписание обновлено', comments: 0),
      ]));
      await signIn(tester);
      h.container.read(chatLifecycleProvider);
      await tester.pumpWidget(wrapWidget(const ConversationScreen(conversationId: channel), container: h.container));
      await settle(tester, 16);

      expect(find.descendant(of: find.byKey(const ValueKey('comments_post1')), matching: find.text('3 комментария')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('comments_post2')), matching: find.text('Комментировать')), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('comments_post2'))).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);

      h.socketFactory.last.serverSend({
        'type': 'message.created',
        'conversation_id': channel,
        'seq': 3,
        'message': comment('c9', 3, 'Комментарий не для ленты'),
      });
      // Frames are applied one after another in real life; back-to-back
      // sends would look like a seq gap to the repository.
      await settle(tester, 6);
      h.socketFactory.last.serverSend({
        'type': 'post.comments',
        'conversation_id': channel,
        'seq': 4,
        'message_id': 'post1',
        'comment_count': 4,
      });
      await settle(tester, 10);
      expect(find.text('Комментарий не для ленты'), findsNothing);
      expect(find.text('4 комментария'), findsOneWidget);
      // (No sembast reads inside runAsync here: a write started by the
      // socket frame in the fake zone would deadlock it.)
      final state = h.container.read(conversationProvider(channel));
      expect(state.messages.map((m) => m.id), ['post1', 'post2'], reason: 'no comment in the feed');
      expect(state.messages.first.commentCount, 4);
      expect(state.conversation!.unread, 0);
      expect(state.conversation!.lastMessage?.id, isNot('c9'));
      await finish(tester);
    });

    testWidgets('thread screen: post and comments, sends to POST /messages/{id}/comments, live comments; guidelines', (tester) async {
      usePhone(tester);
      await prepare();
      h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats([channelJson(myRole: 'member')]));
      h.chatAdapter.onJson('GET', '/chats/$channel', channelJson(myRole: 'member'));
      h.chatAdapter.onJson('GET', '/messages/post1/comments', {
        'post': post('post1', 1, 'Семинар в пятницу', comments: 1),
        'comments': [comment('c1', 2, 'Во сколько начало?')],
        'comments_enabled': true,
      });
      h.chatAdapter.on('POST', '/messages/post1/comments', (req) => FakeResponse(201, json: comment(
        'c2',
        3,
        req.json['body'] as String,
        sender: ChatFixtures.me,
        clientId: req.json['client_message_id'] as String,
      )));
      await signIn(tester);
      h.container.read(chatLifecycleProvider);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(wrapWidget(
        const ChannelThreadScreen(conversationId: channel, postId: 'post1'),
        container: h.container,
      ));
      await settle(tester, 14);

      expect(find.text('Комментарии'), findsOneWidget);
      expect(find.text('Семинар в пятницу'), findsOneWidget);
      expect(find.text('Во сколько начало?'), findsOneWidget);
      expect(find.text('1 комментарий'), findsOneWidget);
      expect(find.byKey(const Key('chat_attach')), findsOneWidget);
      await expectGuidelines(tester);

      await tester.enterText(find.byKey(const Key('chat_input')), 'В 10:00');
      await settle(tester, 2);
      await tester.tap(find.byKey(const Key('chat_send')));
      await settle(tester, 10);
      final body = h.chatAdapter.of('POST', '/messages/post1/comments').single.json;
      expect(body['body'], 'В 10:00');
      expect(body['type'], 'text');
      expect(body['client_message_id'], isNotEmpty);
      expect(find.text('В 10:00'), findsOneWidget);

      h.socketFactory.last.serverSend({
        'type': 'message.created',
        'conversation_id': channel,
        'seq': 4,
        'message': comment('c3', 4, 'Спасибо!'),
      });
      await settle(tester, 6);
      h.socketFactory.last.serverSend({
        'type': 'post.comments',
        'conversation_id': channel,
        'seq': 5,
        'message_id': 'post1',
        'comment_count': 3,
      });
      await settle(tester, 10);
      expect(find.text('Спасибо!'), findsOneWidget);
      expect(find.text('3 комментария'), findsOneWidget);

      // The attach grid has no poll in a thread.
      await tester.tap(find.byKey(const Key('chat_attach')));
      await settle(tester, 6);
      expect(find.byKey(const Key('attach_poll')), findsNothing);
      semantics.dispose();
      await finish(tester);
    });

    testWidgets('thread: comments disabled bar and error text', (tester) async {
      usePhone(tester, textScale: 1);
      await prepare();
      h.chatAdapter.onJson('GET', '/chats/$channel', channelJson(enabled: false, myRole: 'member'));
      h.chatAdapter.onJson('GET', '/messages/post1/comments', {
        'post': post('post1', 1, 'Семинар в пятницу'),
        'comments': <Object>[],
        'comments_enabled': false,
      });
      await signIn(tester);
      await tester.pumpWidget(wrapWidget(
        const ChannelThreadScreen(conversationId: channel, postId: 'post1'),
        container: h.container,
      ));
      await settle(tester, 12);
      expect(find.byKey(const Key('comments_disabled_bar')), findsOneWidget);
      expect(find.byKey(const Key('chat_input')), findsNothing);
      expect(find.text('Комментариев пока нет — напишите первым'), findsOneWidget);
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(
        commentsErrorText(
          l10n,
          const ApiException(statusCode: 403, code: 'COMMENTS_DISABLED', serverMessage: 'x'),
        ),
        'Комментарии к постам отключены',
      );
      await finish(tester);
    });

    testWidgets('channel info: admins switch «Комментарии» with PATCH /channels/{id}', (tester) async {
      usePhone(tester, textScale: 1);
      await prepare();
      h.chatAdapter.onJson('GET', '/chats/$channel', channelJson(enabled: false));
      h.chatAdapter.onJson('GET', '/chats/$channel/messages', ChatFixtures.messages(const []));
      h.chatAdapter.on('PATCH', '/channels/$channel', (req) => FakeResponse(200, json: channelJson(enabled: req.json['comments_enabled'] as bool)));
      await signIn(tester);
      await tester.pumpWidget(wrapWidget(const GroupInfoScreen(conversationId: channel), container: h.container));
      await settle(tester, 12);

      final toggle = find.byKey(const Key('channel_comments_switch'));
      await tester.scrollUntilVisible(toggle, 120, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(toggle);
      await tester.pump();
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      await tester.tap(toggle);
      await settle(tester, 8);
      expect(h.chatAdapter.of('PATCH', '/channels/$channel').single.json, {'comments_enabled': true});
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      final cached = await tester.runAsync(() => h.container.read(chatRepositoryProvider).cache.conversation(channel));
      expect(cached!.commentsEnabled, isTrue);
      expect(tester.takeException(), isNull);
      await finish(tester);
    });

    testWidgets('«Запись голосовых» setting is persisted', (tester) async {
      await prepare();
      await tester.pumpWidget(wrapWidget(
        const Scaffold(body: SingleChildScrollView(child: ChatStorageSettingsSection())),
        container: h.container,
      ));
      await settle(tester, 6);
      expect(h.container.read(chatVoiceRecordModeProvider), ChatVoiceRecordMode.hold);
      await tester.ensureVisible(find.text('Нажать для записи'));
      await tester.tap(find.text('Нажать для записи'));
      await settle(tester, 4);
      expect(h.container.read(chatVoiceRecordModeProvider), ChatVoiceRecordMode.tap);
      final stored = await tester.runAsync(
        () => h.container.read(chatCacheProvider).readMeta(ChatCache.prefVoiceRecordMode),
      );
      expect(stored, 'tap');
      await finish(tester);
    });

    Future<void> openDirect(WidgetTester tester, {bool accessible = false, Map<String, dynamic>? peer}) async {
      final direct = {...ChatFixtures.conversation(), 'peer': ?peer};
      h.chatAdapter.onJson('GET', '/chats/$conv', direct);
      h.chatAdapter.onJson('GET', '/chats/$conv/messages', ChatFixtures.messages([ChatFixtures.message(id: 'm1', seq: 1, body: 'Привет')]));
      await signIn(tester);
      const screen = ConversationScreen(conversationId: conv);
      await tester.pumpWidget(wrapWidget(
        accessible
            ? Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(accessibleNavigation: true),
                  child: screen,
                ),
              )
            : screen,
        container: h.container,
      ));
      await settle(tester, 14);
    }

    testWidgets('hold mode (default): a tap only explains, recording needs a hold', (tester) async {
      usePhone(tester, textScale: 1);
      await prepare();
      await openDirect(tester);
      await tester.tap(find.byKey(const Key('chat_mic')));
      await settle(tester, 4);
      expect(find.text('Удерживайте для записи'), findsOneWidget);
      expect(recordCalls, isNot(contains('start')));
      expect(find.text('Запись'), findsNothing);
      await finish(tester);
    });

    testWidgets('tap mode: a tap starts a locked recording with cancel / stop', (tester) async {
      usePhone(tester, textScale: 1);
      await prepare();
      await tester.runAsync(() => h.container.read(chatVoiceRecordModeProvider.notifier).set(ChatVoiceRecordMode.tap));
      await openDirect(tester);
      expect(find.bySemanticsLabel('Записать голосовое'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat_mic')));
      await settle(tester, 8);
      expect(recordCalls, contains('start'));
      expect(find.bySemanticsLabel('Запись'), findsOneWidget, reason: 'locked recording bar (text or live waveform)');
      expect(find.text('Отменить'), findsOneWidget);
      expect(find.byKey(const Key('chat_mic')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Отменить'));
      await settle(tester, 4);
      expect(recordCalls, contains('cancel'));
      expect(find.byKey(const Key('chat_mic')), findsOneWidget);
      await finish(tester);
    });

    testWidgets('TalkBack (accessible navigation) forces tap mode', (tester) async {
      usePhone(tester, textScale: 1);
      await prepare();
      await openDirect(tester, accessible: true);
      expect(h.container.read(chatVoiceRecordModeProvider), ChatVoiceRecordMode.hold);
      await tester.tap(find.byKey(const Key('chat_mic')));
      await settle(tester, 8);
      expect(recordCalls, contains('start'));
      expect(find.bySemanticsLabel('Запись'), findsOneWidget);
      await tester.tap(find.text('Отменить'));
      await settle(tester, 4);
      await finish(tester);
    });

    testWidgets('«Когда появится в сети»: 1:1 with a visible peer → when_online body; list and timeout text', (tester) async {
      usePhone(tester);
      await prepare();
      final items = <Map<String, dynamic>>[];
      h.chatAdapter.on('GET', '/chats/$conv/scheduled', (_) => FakeResponse(200, json: {'scheduled': items}));
      h.chatAdapter.on('POST', '/chats/$conv/scheduled', (req) {
        final item = {
          'id': 's1',
          'conversation_id': conv,
          'body': req.json['body'],
          'send_at': DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String(),
          'when_online_user_id': ChatFixtures.peer,
          'status': 'pending',
        };
        items
          ..add(item)
          ..add({
            'id': 's2',
            'conversation_id': conv,
            'body': 'Старое сообщение',
            'send_at': '2026-09-10T10:00:00Z',
            'when_online_user_id': ChatFixtures.peer,
            'status': 'failed',
            'last_error': 'WHEN_ONLINE_TIMEOUT',
          });
        return FakeResponse(201, json: item);
      });
      await openDirect(tester);
      await tester.enterText(find.byKey(const Key('chat_input')), 'Позвони, как освободишься');
      await settle(tester, 4);
      await tester.longPress(find.byKey(const Key('chat_send')));
      await settle(tester, 6);
      expect(find.byKey(const Key('when_online')), findsOneWidget);
      await expectGuidelines(tester);
      await tester.tap(find.byKey(const Key('when_online')));
      await settle(tester, 10);

      final sent = h.chatAdapter.of('POST', '/chats/$conv/scheduled').single.json;
      expect(sent, {'when_online': true, 'body': 'Позвони, как освободишься'});
      expect(find.text('Отправим, когда собеседник появится в сети'), findsOneWidget);

      await tester.pumpWidget(wrapWidget(const ScheduledMessagesScreen(conversationId: conv), container: h.container));
      await settle(tester, 10);
      expect(tester.widget<Text>(find.byKey(const ValueKey('scheduled_when_s1'))).data, 'Когда появится в сети');
      expect(find.text('Не отправлено: собеседник не появился в сети'), findsOneWidget);
      await expectGuidelines(tester);
      await finish(tester);
    });

    testWidgets('«Когда появится в сети» is hidden for groups and a peer that hides presence', (tester) async {
      usePhone(tester, textScale: 1);
      await prepare();
      await openDirect(tester, peer: {...ChatFixtures.user(), 'presence_hidden': true});
      await tester.enterText(find.byKey(const Key('chat_input')), 'Текст');
      await settle(tester, 4);
      await tester.longPress(find.byKey(const Key('chat_send')));
      await settle(tester, 6);
      expect(find.byKey(const Key('when_inOneHour')), findsOneWidget);
      expect(find.byKey(const Key('when_online')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());

      final groupJson = ChatFixtures.conversation(
        id: grp,
        title: 'Кафедра',
        group: true,
        members: [ChatFixtures.member(ChatFixtures.me, 'Me', role: 'owner'), ChatFixtures.member(ChatFixtures.peer, 'Bob')],
      );
      h.chatAdapter.onJson('GET', '/chats/$grp', groupJson);
      h.chatAdapter.onJson('GET', '/chats/$grp/messages', ChatFixtures.messages(const []));
      await tester.pumpWidget(wrapWidget(const ConversationScreen(conversationId: grp), container: h.container));
      await settle(tester, 12);
      await tester.enterText(find.byKey(const Key('chat_input')), 'Текст');
      await settle(tester, 4);
      await tester.longPress(find.byKey(const Key('chat_send')));
      await settle(tester, 6);
      expect(find.byKey(const Key('when_inOneHour')), findsOneWidget);
      expect(find.byKey(const Key('when_online')), findsNothing);
      await finish(tester);
    });
  });
}
