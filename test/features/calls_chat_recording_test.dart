import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/api/api_client.dart';
import 'package:xatbox_mobile/core/api/api_exception.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_reminders.dart';
import 'package:xatbox_mobile/features/calendar/presentation/calendar_providers.dart';
import 'package:xatbox_mobile/features/calls/data/call_chat.dart';
import 'package:xatbox_mobile/features/calls/data/call_models.dart';
import 'package:xatbox_mobile/features/calls/data/calls_api.dart';
import 'package:xatbox_mobile/features/calls/data/calls_config.dart';
import 'package:xatbox_mobile/features/calls/presentation/call_controller.dart';
import 'package:xatbox_mobile/features/calls/presentation/call_details_screen.dart';
import 'package:xatbox_mobile/features/calls/presentation/calls_providers.dart';
import 'package:xatbox_mobile/features/calls/presentation/widgets/call_recording.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';

import '../helpers/call_fakes.dart';
import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// In-call chat (data channel + persistence) and call recording (REC for
/// everyone, one-time banner, start/stop, recordings in the call card).
void main() {
  group('controller', () {
    late FakeHttpAdapter http;
    late FakeCallServer server;
    late List<FakeCallMedia> medias;
    late ProviderContainer container;
    late NotifierProvider<CallController, CallSessionState> provider;
    Future<String> Function(String, String)? sendToConversation;
    StreamController<CallChatMessage>? conversation;
    const self = 'u-self';

    setUp(() {
      http = FakeHttpAdapter();
      server = FakeCallServer(http, selfId: self, selfName: 'Я');
      medias = [];
      sendToConversation = null;
      conversation = null;
      var ids = 0;
      final api = CallsApi(
        ApiClient(baseUrl: 'http://calls.local/api/v1', userAgent: 'test', adapter: http, tokenReader: () => 'tok', onUnauthenticated: () {}),
      );
      provider = NotifierProvider<CallController, CallSessionState>(
        () => CallController(
          (_) => CallDeps(
            api: api,
            native: FakeCallNative(),
            mediaFactory: () {
              final m = FakeCallMedia();
              medias.add(m);
              return m;
            },
            deviceId: () async => 'device-A',
            selfId: () => self,
            selfName: () => 'Я',
            socketConnected: () => true,
            newId: () => 'client-${ids++}',
            sendToConversation: sendToConversation,
            conversationMessages: conversation == null ? null : (_) => conversation!.stream,
          ),
        ),
      );
      container = ProviderContainer();
    });
    tearDown(() {
      container.dispose();
      unawaited(conversation?.close());
    });

    CallController ctl() => container.read(provider.notifier);
    CallSessionState st() => container.read(provider);

    Future<void> flush() async {
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    Future<String> activeCall({String? conversationId, String mode = 'direct'}) async {
      await ctl().startCall(calleeIds: ['u-bob'], video: false, conversationId: conversationId, mode: mode);
      await flush();
      medias.single.join('u-bob');
      await flush();
      expect(st().phase, CallPhase.active);
      return st().callId!;
    }

    Map<String, Object?> chat(String id, String body, {String sender = 'u-bob'}) => {
      'type': 'chat',
      'id': id,
      'sender_id': sender,
      'sender_name': 'Болат',
      'body': body,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    test('ad-hoc call: data channel + Call Service; unread until the panel opens; copies collapse; failed messages retry', () async {
      final id = await activeCall();
      final toasts = <CallChatMessage>[];
      final sub = ctl().chatToasts.listen(toasts.add);
      addTearDown(sub.cancel);

      expect(await ctl().sendChatMessage('   '), isFalse);
      expect(await ctl().sendChatMessage('  Привет  '), isTrue);
      await flush();
      final mine = st().chat.single;
      expect([mine.body, mine.local, mine.status, mine.senderId], ['Привет', true, CallChatStatus.sent, self]);
      expect(medias.single.sentData.last, containsPair('type', 'chat'));
      expect(medias.single.sentData.last, containsPair('id', mine.id));
      expect(http.of('POST', '/calls/$id/messages').single.json, {'client_message_id': mine.id, 'body': 'Привет'});
      expect(st().chatUnread, 0, reason: 'own messages are read');

      // A participant cannot speak for someone else: the identity wins.
      medias.single.receive('u-bob#d1', chat('m-1', 'Здравствуйте', sender: 'u-mallory'));
      await flush();
      expect(st().chat.last.senderId, 'u-bob');
      expect(st().chatUnread, 1);
      expect(toasts.single.body, 'Здравствуйте');
      // The Call Service broadcast of the same message (no identity) is a copy.
      medias.single.receive('', chat('m-1', 'Здравствуйте'));
      medias.single.receive('', chat(mine.id, 'Привет', sender: self));
      await flush();
      expect(st().chat, hasLength(2));

      ctl().setChatOpen(true);
      expect(st().chatUnread, 0);
      medias.single.receive('u-bob#d1', chat('m-2', 'Ещё'));
      await flush();
      expect([st().chatUnread, toasts.length], [0, 1], reason: 'the open panel shows it');
      ctl().setChatOpen(false);

      http.onError('POST', '/calls/$id/messages', 503, 'INTERNAL');
      await ctl().sendChatMessage('Не дойдёт');
      await flush();
      final failed = st().chat.last;
      expect(failed.status, CallChatStatus.failed);
      http.on('POST', '/calls/$id/messages', (r) => FakeResponse(201, json: {'message': {...r.json, 'id': 'srv'}}));
      await ctl().retryChatMessage(failed.id);
      await flush();
      expect(st().chat.last.status, CallChatStatus.sent);
      expect(http.of('POST', '/calls/$id/messages').last.json['client_message_id'], failed.id, reason: 'same id: the server de-duplicates');
    });

    test('late joiner loads the history of an ad-hoc call', () async {
      final id = server.addIncoming(callerId: 'u-bob', callerName: 'Болат');
      server.messages[id] = [
        {'id': 's2', 'client_message_id': 'b-2', 'sender_id': 'u-bob', 'sender_name': 'Болат', 'body': 'второе', 'created_at': '2026-09-15T10:01:00Z'},
        {'id': 's1', 'client_message_id': 'b-1', 'sender_id': 'u-bob', 'sender_name': 'Болат', 'body': 'первое', 'created_at': '2026-09-15T10:00:00Z'},
      ];
      await ctl().onIncoming(CallInfo.fromJson(server.calls[id]!));
      await ctl().accept();
      await flush();
      expect(st().chat.map((m) => m.body), ['первое', 'второе']);
      expect(st().chatUnread, 0, reason: 'history is not «new»');
    });

    test('conversation call: sent into the conversation (no Call Service copy), its live messages appear once', () async {
      final sent = <String>[];
      sendToConversation = (conv, body) async {
        sent.add('$conv|$body');
        return 'outbox-1';
      };
      conversation = StreamController<CallChatMessage>.broadcast();
      final id = await activeCall(conversationId: 'conv-1', mode: 'group');

      await ctl().sendChatMessage('Всем привет');
      await flush();
      expect(sent, ['conv-1|Всем привет']);
      expect(http.of('POST', '/calls/$id/messages'), isEmpty);
      expect(medias.single.sentData.last['id'], 'outbox-1', reason: 'the outbox id travels with the data packet');

      conversation!.add(CallChatMessage(id: 'outbox-1', senderId: self, body: 'Всем привет', createdAt: DateTime.now()));
      conversation!.add(CallChatMessage(id: 'web-7', senderId: 'u-bob', body: 'Из веба', createdAt: DateTime.now()));
      await flush();
      expect(st().chat.map((m) => m.body), ['Всем привет', 'Из веба']);
      expect(st().chat.last.senderName, 'User u-bob', reason: 'named from the call participants');
      expect(st().chatUnread, 1);
    });

    test('recording: server state for everyone, banner once per recording, participants cannot hide it; start/stop', () async {
      final id = await activeCall();
      final notices = <CallRecordingState>[];
      final sub = ctl().recordingNotices.listen(notices.add);
      addTearDown(sub.cancel);
      Map<String, Object?> rec(String status, {String recId = 'rec-1'}) => {
        'type': 'recording',
        'call_id': id,
        'recording_id': recId,
        'status': status,
        'started_by': 'u-bob',
        'started_at': '2026-09-15T10:30:00Z',
      };

      expect(callCanStartRecording(st(), enabled: true), isTrue, reason: '1:1: either side');
      expect(callCanStartRecording(st(), enabled: false), isFalse, reason: 'feature off');

      medias.single.receive('', rec('active'));
      await flush();
      expect(st().recording.active, isTrue);
      expect(st().recording.startedBy, 'u-bob');
      medias.single.receive('', rec('active'));
      await flush();
      expect(notices, hasLength(1));
      expect(callCanStartRecording(st(), enabled: true), isFalse, reason: 'already recorded');
      expect(callCanStopRecording(st(), self), isTrue, reason: '1:1: the other side may stop');

      medias.single.receive('u-bob#d1', rec('none'));
      await flush();
      expect(st().recording.active, isTrue, reason: 'only the Call Service announces recording state');
      medias.single.receive('', rec('none'));
      await flush();
      expect(st().recording.active, isFalse);

      // call.recording frame from the chat socket.
      final frame = {
        'type': 'call.recording',
        'call_id': id,
        'call': {
          ...server.calls[id]!,
          'recording': {'enabled': true, 'status': 'starting', 'recording_id': 'rec-7', 'started_by': 'u-bob', 'started_at': null},
        },
      };
      await ctl().onSignal(CallSignal.fromFrame(frame)!);
      expect(st().recording.status, 'starting');
      expect(notices.map((n) => n.recordingId), ['rec-1', 'rec-7']);
      medias.single.receive('', rec('none', recId: 'rec-7'));
      await flush();

      await ctl().startRecording();
      await flush();
      expect(http.of('POST', '/calls/$id/recording/start'), hasLength(1));
      expect(st().recording.active, isTrue);
      expect(st().recording.startedBy, self);
      expect(notices, hasLength(3));
      await ctl().stopRecording();
      expect(http.of('POST', '/calls/$id/recording/stop'), hasLength(1));
      expect(st().recording.active, isFalse);

      server.recordingError = 'RECORDING_UNAVAILABLE';
      await expectLater(ctl().startRecording(), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'RECORDING_UNAVAILABLE')));
      expect(st().recordingBusy, isFalse);
    });

    test('group calls: moderators record; the starter or a moderator stops', () {
      CallSessionState group(String role, {Map<String, Object?>? recording}) => CallSessionState(
        phase: CallPhase.active,
        call: CallInfo.fromJson({
          'id': 'g',
          'mode': 'group',
          'status': 'active',
          'my_role': role,
          'recording': recording ?? {'status': 'none'},
        }),
        recording: CallRecordingState.fromJson(recording),
      );
      expect(callCanStartRecording(group('participant'), enabled: true), isFalse);
      expect(callCanStartRecording(group('moderator'), enabled: true), isTrue);
      expect(callCanStartRecording(group('host'), enabled: true), isTrue);
      final byMe = {'status': 'active', 'recording_id': 'r', 'started_by': self};
      final byBob = {'status': 'active', 'recording_id': 'r', 'started_by': 'u-bob'};
      expect(callCanStopRecording(group('participant', recording: byMe), self), isTrue);
      expect(callCanStopRecording(group('participant', recording: byBob), self), isFalse);
      expect(callCanStopRecording(group('moderator', recording: byBob), self), isTrue);
    });

    test('models: config flag, data packet validation, recordings download without partial files', () async {
      expect(CallsConfig.fromJson(const {'recording_enabled': true}).recordingEnabled, isTrue);
      expect(CallsConfig.fromJson(const {'recording_enabled': 'yes'}).recordingEnabled, isFalse);
      expect(const CallsConfig().toJson()['recording_enabled'], isFalse);
      expect(CallChatMessage.fromData('', {'id': 'x', 'sender_id': 'u-srv', 'body': ' hi '})?.senderId, 'u-srv');
      expect(CallChatMessage.fromData('u-a#d', {'id': 'x', 'body': 'x' * (callChatMaxLength + 1)}), isNull);
      expect(CallChatMessage.fromData('u-a#d', {'id': '', 'body': 'hi'}), isNull);
      expect(CallRecordingState.fromJson({'status': 'starting'}).active, isTrue);
      expect(CallRecordingState.fromJson(null).active, isFalse);

      final api = CallsApi(
        ApiClient(baseUrl: 'http://calls.local/api/v1', userAgent: 'test', adapter: http, tokenReader: () => 'tok', onUnauthenticated: () {}),
      );
      final dir = Directory.systemTemp.createTempSync('call_rec_');
      addTearDown(() => dir.deleteSync(recursive: true));
      server.downloads['rec-1'] = 'MP4DATA';
      final path = '${dir.path}/rec-1.mp4';
      await api.downloadRecording(CallRecordingItem.fromJson(FakeCallServer.recordingItem('rec-1', 'c')), path);
      expect(File(path).readAsStringSync(), 'MP4DATA');
      final missing = '${dir.path}/rec-x.mp4';
      await expectLater(
        api.downloadRecording(CallRecordingItem.fromJson(FakeCallServer.recordingItem('rec-x', 'c')), missing),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'RECORDING_NOT_FOUND')),
      );
      expect(File(missing).existsSync(), isFalse);
    });
  });

  group('widgets', () {
    late TestHarness h;
    late FakeCallServer server;
    late List<FakeCallMedia> medias;
    late Directory recordingsDir;
    late List<String> opened;

    setUp(() {
      recordingsDir = Directory.systemTemp.createTempSync('call_recordings_');
      opened = [];
    });
    tearDown(() {
      h.dispose();
      if (recordingsDir.existsSync()) recordingsDir.deleteSync(recursive: true);
    });

    Future<void> settle(WidgetTester tester, [int steps = 12]) async {
      for (var i = 0; i < steps; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> launch(WidgetTester tester, {bool recording = false, void Function()? before}) async {
      medias = [];
      h = await TestHarness.create(
        storedToken: Fixtures.token,
        chatBaseUrl: 'http://chat.local/api/v1',
        callsBaseUrl: 'http://calls.local/api/v1',
        overrides: [
          callNativeProvider.overrideWithValue(FakeCallNative()),
          callSoundsProvider.overrideWithValue(FakeCallSounds()),
          callPipProvider.overrideWithValue(FakeCallPip()),
          callMediaFactoryProvider.overrideWithValue(() {
            final m = FakeCallMedia();
            medias.add(m);
            return m;
          }),
          reminderSchedulerProvider.overrideWithValue(_NoReminders()),
          callRecordingsDirProvider.overrideWithValue(() async => recordingsDir),
          chatFileOpenerProvider.overrideWithValue((path, mime) async {
            opened.add('$path|$mime');
            return true;
          }),
        ],
      );
      h.stubSignedIn();
      h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats(const []));
      h.chatAdapter.onPattern('POST', r'^/push/devices$', (_) => const FakeResponse(204));
      server = FakeCallServer(h.callsAdapter, selfId: ChatFixtures.me, selfName: 'Тест Пользователь');
      server.config = {'max_video_tiles': 9, 'ring_timeout_sec': 45, 'max_group': 50, 'max_conference': 150, 'recording_enabled': recording};
      before?.call();
      tester.platformDispatcher.localeTestValue = const Locale('ru');
      tester.platformDispatcher.localesTestValue = const [Locale('ru')];
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.runAsync(() => h.session.restore());
      await tester.pumpWidget(UncontrolledProviderScope(container: h.container, child: const XatBoxApp()));
      await settle(tester);
    }

    Future<String> dial(WidgetTester tester, {bool video = false}) async {
      unawaited(h.container.read(callControllerProvider.notifier).startCall(calleeIds: ['u-bob'], video: video));
      unawaited(h.container.read(appRouterProvider).push(Routes.call));
      await settle(tester, 20);
      medias.single.join('u-bob', cameraOn: video);
      await settle(tester);
      expect(h.container.read(callControllerProvider).phase, CallPhase.active);
      return h.container.read(callControllerProvider).callId!;
    }

    Future<void> finish(WidgetTester tester) async {
      unawaited(h.container.read(callControllerProvider.notifier).hangUp());
      await tester.pump(const Duration(seconds: 1));
      unawaited(h.container.read(chatRepositoryProvider).stop());
      await tester.pump(const Duration(seconds: 10));
    }

    Map<String, Object?> chat(String id, String body) => {
      'type': 'chat',
      'id': id,
      'sender_id': 'u-bob',
      'body': body,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    testWidgets('360 px video call: chat in the dock with an unread badge, toast preview, sheet with send and emoji, mini bar badge', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await launch(tester);
      final id = await dial(tester, video: true);

      expect(find.byKey(const Key('call_chat')), findsOneWidget);
      expect(find.byKey(const Key('call_switch_camera')), findsNothing, reason: 'moved to «Ещё» on phones');
      expect(find.byKey(const Key('call_chat_badge')), findsNothing);

      medias.single.receive('u-bob#d1', chat('m-1', 'Слышно меня?'));
      await settle(tester);
      expect(find.byKey(const Key('call_chat_badge')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('call_chat_badge')), matching: find.text('1')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('call_chat_toast')), matching: find.text('Слышно меня?')), findsOneWidget);

      await tester.tap(find.byKey(const Key('call_chat')));
      await settle(tester);
      expect(find.byKey(const Key('call_chat_panel')), findsOneWidget);
      expect(find.byKey(const ValueKey('call_chat_msg_m-1')), findsOneWidget);
      expect(find.byKey(const Key('call_chat_badge')), findsNothing, reason: 'read while the panel is open');
      expect(h.container.read(callControllerProvider).chatUnread, 0);

      await tester.enterText(find.byKey(const Key('call_chat_input')), 'Да, отлично');
      await settle(tester, 2); // the send button enables on the next frame
      await tester.tap(find.byKey(const Key('call_chat_send')));
      await settle(tester);
      expect(h.callsAdapter.of('POST', '/calls/$id/messages').single.json['body'], 'Да, отлично');
      expect(medias.single.sentData.last['body'], 'Да, отлично');
      expect(find.text('Да, отлично'), findsOneWidget);

      await tester.tap(find.byKey(const Key('call_chat_emoji')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('call_chat_emoji_0')));
      await settle(tester);
      expect(tester.widget<TextField>(find.byKey(const Key('call_chat_input'))).controller!.text, '👍');

      await tester.tap(find.byKey(const Key('call_chat_close')));
      await settle(tester);
      expect(find.byKey(const Key('call_chat_panel')), findsNothing);

      await tester.tap(find.byKey(const Key('call_more')));
      await settle(tester);
      expect(find.byKey(const Key('call_switch_camera_more')), findsOneWidget);
      expect(find.byKey(const Key('call_record')), findsNothing, reason: 'recording is off on this server');
      Navigator.of(tester.element(find.byKey(const Key('call_switch_camera_more')))).pop();
      await settle(tester);

      h.container.read(appRouterProvider).pop(); // minimise
      await settle(tester);
      expect(find.byKey(const Key('call_mini_bar')), findsOneWidget);
      medias.single.receive('u-bob#d1', chat('m-2', 'Вы тут?'));
      await settle(tester);
      expect(find.byKey(const Key('call_mini_chat_badge')), findsOneWidget);
      await finish(tester);
    });

    testWidgets('360 px: «Записать» with confirmation, REC • timer and a one-time banner for everyone, stop; remote recording by a colleague', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await launch(tester, recording: true);
      final id = await dial(tester);
      expect(find.byKey(const Key('call_rec_indicator')), findsNothing);

      await tester.tap(find.byKey(const Key('call_more')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('call_record')));
      await settle(tester);
      expect(find.byKey(const Key('call_record_confirm')), findsOneWidget);
      await tester.tap(find.byKey(const Key('call_record_confirm_start')));
      await settle(tester);
      expect(h.callsAdapter.of('POST', '/calls/$id/recording/start'), hasLength(1));
      expect(find.byKey(const Key('call_rec_indicator')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('call_rec_indicator')), matching: find.text('REC')), findsOneWidget);
      expect(find.byKey(const Key('call_recording_banner')), findsOneWidget);
      expect(find.text('Звонок записывается'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
      expect(find.byKey(const Key('call_recording_banner')), findsNothing, reason: 'the banner is shown once');
      expect(find.byKey(const Key('call_rec_indicator')), findsOneWidget, reason: 'REC stays');

      await tester.tap(find.byKey(const Key('call_more')));
      await settle(tester);
      expect(find.byKey(const Key('call_record')), findsNothing);
      await tester.tap(find.byKey(const Key('call_record_stop')));
      await settle(tester);
      expect(h.callsAdapter.of('POST', '/calls/$id/recording/stop'), hasLength(1));
      expect(find.byKey(const Key('call_rec_indicator')), findsNothing);
      expect(find.text('Запись остановлена'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));

      // A colleague starts recording: announced by the Call Service.
      medias.single.receive('', {
        'type': 'recording',
        'call_id': id,
        'recording_id': 'rec-remote',
        'status': 'active',
        'started_by': 'u-bob',
        'started_at': DateTime.now().toUtc().toIso8601String(),
      });
      await settle(tester);
      expect(find.byKey(const Key('call_rec_indicator')), findsOneWidget);
      expect(find.text('Запись включил(а) User u-bob'), findsOneWidget);
      medias.single.receive('u-bob#d1', {'type': 'recording', 'call_id': id, 'status': 'none'});
      await settle(tester);
      expect(find.byKey(const Key('call_rec_indicator')), findsOneWidget, reason: 'a participant cannot hide REC');

      h.container.read(appRouterProvider).pop(); // minimise
      await settle(tester);
      expect(find.byKey(const Key('call_rec_compact')), findsOneWidget, reason: 'REC in the mini bar too');
      await finish(tester);
    });

    testWidgets('call card lists recordings: download with progress, open with the system viewer, failed shown', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await launch(
        tester,
        recording: true,
        before: () {
          server.calls['old'] = server.callJson(
            id: 'old',
            callerId: 'u-bob',
            others: [('u-bob', 'Болат')],
            status: 'ended',
            direction: 'incoming',
            outcome: 'answered',
          )..['duration_sec'] = 342;
          server.recordings['old'] = [
            FakeCallServer.recordingItem('rec-1', 'old'),
            FakeCallServer.recordingItem('rec-2', 'old', status: 'failed', type: 'audio'),
          ];
          server.downloads['rec-1'] = 'MP4-BYTES';
        },
      );

      // Звонки live under «Ещё» of the glass bar.
      await tester.tap(find.byKey(const Key('tab_more')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('more_calls')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('call_old')));
      await settle(tester);
      expect(find.byType(CallDetailsScreen), findsOneWidget);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await settle(tester);

      expect(find.byKey(const Key('call_recordings')), findsOneWidget);
      expect(find.text('Видеозапись · 15 сент., 10:30').evaluate().isNotEmpty || find.textContaining('Видеозапись').evaluate().isNotEmpty, isTrue);
      expect(find.textContaining('05:42 · 13 МБ · Болат'), findsOneWidget);
      expect(find.text('Запись не удалась'), findsOneWidget);
      expect(find.byKey(const ValueKey('call_recording_download_rec-2')), findsNothing, reason: 'failed recordings cannot be downloaded');

      final saved = File('${recordingsDir.path}/rec-1.mp4');
      // Real file I/O: tap and wait outside the fake clock.
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('call_recording_download_rec-1')));
        for (var i = 0; i < 60 && !saved.existsSync(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await settle(tester);
      expect(h.callsAdapter.of('GET', '/recordings/rec-1/download'), hasLength(1));
      expect(saved.readAsStringSync(), 'MP4-BYTES');
      expect(File('${saved.path}.part').existsSync(), isFalse);
      expect(find.byKey(const ValueKey('call_recording_open_rec-1')), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('call_recording_open_rec-1')));
        for (var i = 0; i < 40 && opened.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      });
      await settle(tester);
      expect(opened, ['${saved.path}|video/mp4']);
      unawaited(h.container.read(chatRepositoryProvider).stop());
      await tester.pump(const Duration(seconds: 10));
    });
  });
}

class _NoReminders implements ReminderScheduler {
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> schedule(ReminderRequest request) async {}
  @override
  Future<void> cancel(int id) async {}
}
