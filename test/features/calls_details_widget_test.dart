import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_reminders.dart';
import 'package:xatbox_mobile/features/calendar/presentation/calendar_providers.dart';
import 'package:xatbox_mobile/features/calls/data/call_media.dart';
import 'package:xatbox_mobile/features/calls/data/call_sounds.dart';
import 'package:xatbox_mobile/features/calls/presentation/call_controller.dart';
import 'package:xatbox_mobile/features/calls/presentation/call_details_screen.dart';
import 'package:xatbox_mobile/features/calls/presentation/call_screen.dart';
import 'package:xatbox_mobile/features/calls/presentation/calls_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/conversation_screen.dart';

import '../helpers/call_fakes.dart';
import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Calls iteration 5 through the real app: call card from a history row
/// (call again, «Написать»), inviting colleagues as a moderator, grid size
/// from `/calls/config`, remote link quality, PiP compact stage.
void main() {
  late TestHarness h;
  late FakeCallServer server;
  late FakeCallNative native;
  late FakeCallSounds sounds;
  late FakeCallPip pip;
  late List<FakeCallMedia> medias;

  tearDown(() => h.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 12]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> launch(WidgetTester tester) async {
    native = FakeCallNative();
    sounds = FakeCallSounds();
    pip = FakeCallPip();
    medias = [];
    h = await TestHarness.create(
      storedToken: Fixtures.token,
      chatBaseUrl: 'http://chat.local/api/v1',
      callsBaseUrl: 'http://calls.local/api/v1',
      overrides: [
        callNativeProvider.overrideWithValue(native),
        callSoundsProvider.overrideWithValue(sounds),
        callPipProvider.overrideWithValue(pip),
        callMediaFactoryProvider.overrideWithValue(() {
          final m = FakeCallMedia();
          medias.add(m);
          return m;
        }),
        reminderSchedulerProvider.overrideWithValue(_NoReminders()),
      ],
    );
    h.stubSignedIn();
    h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats(const []));
    h.chatAdapter.onPattern('POST', r'^/push/devices$', (_) => const FakeResponse(204));
    server = FakeCallServer(h.callsAdapter, selfId: ChatFixtures.me, selfName: 'Тест Пользователь');
    tester.platformDispatcher.localeTestValue = const Locale('ru');
    tester.platformDispatcher.localesTestValue = const [Locale('ru')];
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }

  Future<void> start(WidgetTester tester) async {
    await tester.runAsync(() => h.session.restore());
    await tester.pumpWidget(UncontrolledProviderScope(container: h.container, child: const XatBoxApp()));
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    unawaited(h.container.read(callControllerProvider.notifier).hangUp());
    await tester.pump(const Duration(seconds: 1));
    unawaited(h.container.read(chatRepositoryProvider).stop());
    await tester.pump(const Duration(seconds: 10));
  }

  testWidgets('history row opens the call card; «Написать» opens the direct chat; video call redials', (tester) async {
    // Phone-sized view: the whole card (participants included) is built.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await launch(tester);
    server.calls['old'] = server.callJson(
      id: 'old',
      callerId: 'u-bob',
      others: [('u-bob', 'Болат')],
      status: 'ended',
      direction: 'incoming',
      outcome: 'answered',
    )..['duration_sec'] = 125;
    h.chatAdapter.on('POST', '/chats', (_) => FakeResponse(201, json: ChatFixtures.conversation()));
    await start(tester);

    // Звонки live under «Ещё» of the glass bar.
    await tester.tap(find.byKey(const Key('tab_more')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('more_calls')));
    await settle(tester);
    expect(find.byKey(const ValueKey('redial_old')), findsOneWidget, reason: 'redial button kept on the row');
    await tester.tap(find.byKey(const ValueKey('call_old')));
    await settle(tester);

    expect(find.byType(CallDetailsScreen), findsOneWidget);
    expect(tester.widget<CallDetailsScreen>(find.byType(CallDetailsScreen)).callId, 'old');
    expect(find.text('Аудиозвонок · Личный'), findsOneWidget);
    expect(find.text('Входящий · Состоялся'), findsOneWidget);
    expect(find.text('02:05'), findsOneWidget);
    expect(find.byKey(const ValueKey('call_details_participant_u-bob')), findsOneWidget);
    expect(find.text('организатор · принял'), findsOneWidget);
    expect(h.callsAdapter.of('GET', '/calls/old'), hasLength(1), reason: 'card refreshes the call');

    await tester.tap(find.byKey(const Key('call_details_message')));
    await settle(tester);
    expect(h.chatAdapter.of('POST', '/chats').single.json, {'type': 'direct', 'user_id': 'u-bob'});
    expect(tester.widget<ConversationScreen>(find.byType(ConversationScreen)).conversationId, ChatFixtures.conv);

    h.container.read(appRouterProvider).pop();
    await settle(tester);
    expect(find.byType(CallDetailsScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('call_details_video')));
    await settle(tester, 20);
    final create = h.callsAdapter.of('POST', '/calls').single.json;
    expect(create['callee_ids'], ['u-bob']);
    expect(create['type'], 'video');
    expect(find.byType(CallScreen), findsOneWidget);
    expect(sounds.playing, CallTone.ringback);
    await finish(tester);
  });

  testWidgets('moderator invites colleagues: current participants excluded, server errors shown', (tester) async {
    await launch(tester);
    h.chatAdapter.onJson('GET', '/users', {
      'users': [
        ChatFixtures.user(id: 'u-a', name: 'Anna'),
        ChatFixtures.user(id: 'u-c', name: 'Serik'),
      ],
    });
    await start(tester);
    unawaited(
      h.container.read(callControllerProvider.notifier).startCall(calleeIds: ['u-a', 'u-b'], video: false, mode: 'group'),
    );
    unawaited(h.container.read(appRouterProvider).push(Routes.call));
    await settle(tester, 20);
    final id = h.container.read(callControllerProvider).callId!;

    await tester.tap(find.byKey(const Key('call_participants')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('call_invite')));
    await settle(tester, 20);

    expect(find.byKey(const ValueKey('invite_pick_u-a')), findsNothing, reason: 'already in the call');
    expect(find.byKey(const ValueKey('invite_pick_u-c')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('invite_pick_u-c')));
    await settle(tester);

    server
      ..inviteError = 'TOO_MANY_PARTICIPANTS'
      ..inviteErrorStatus = 400;
    await tester.tap(find.byKey(const Key('call_invite_submit')));
    await settle(tester);
    expect(find.text('Слишком много участников для звонка.'), findsOneWidget);
    expect(find.byKey(const Key('call_invite_submit')), findsOneWidget, reason: 'sheet stays open');

    server.inviteError = null;
    await tester.tap(find.byKey(const Key('call_invite_submit')));
    await settle(tester, 20);
    expect(h.callsAdapter.of('POST', '/calls/$id/invite').last.json, {
      'user_ids': ['u-c'],
    });
    expect(find.byKey(const Key('call_invite_submit')), findsNothing, reason: 'sheet closed');
    expect(h.container.read(callControllerProvider).call!.participant('u-c'), isNotNull);
    expect(find.byKey(const ValueKey('participant_u-c')), findsOneWidget, reason: 'participants list updated');
    await finish(tester);
  });

  testWidgets('max_video_tiles=4 gives 2 grid pages for 6 people; remote poor link shown; PiP shows only video', (tester) async {
    await launch(tester);
    server.config = {'max_video_tiles': 4, 'ring_timeout_sec': 45, 'max_group': 50, 'max_conference': 150};
    await start(tester);
    expect(h.container.read(callsConfigProvider).maxVideoTiles, 4);

    unawaited(
      h.container
          .read(callControllerProvider.notifier)
          .startCall(calleeIds: ['u1', 'u2', 'u3', 'u4', 'u5'], video: true, mode: 'group'),
    );
    unawaited(h.container.read(appRouterProvider).push(Routes.call));
    await settle(tester, 20);
    final media = medias.single;
    // First grid row (visible in the 800×600 test view): me, u1.
    media.join('u1', cameraOn: true, quality: LinkQuality.poor);
    media.join('u2');
    media.join('u3', quality: LinkQuality.lost);
    media.join('u4');
    media.join('u5');
    await settle(tester);

    expect(h.container.read(callControllerProvider).phase, CallPhase.active);
    expect(sounds.playing, isNull, reason: 'ringback stops when connected');
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('tile_quality_poor_u1#d1')), findsOneWidget);
    expect(find.byKey(const ValueKey('tile_quality_lost_u1#d1')), findsNothing);
    expect(find.byKey(const ValueKey('tile_me#dev')), findsOneWidget);
    expect(find.byKey(const ValueKey('tile_quality_poor_me#dev')), findsNothing, reason: 'no indicator on the local tile');

    expect(pip.autoEnter.last, isTrue, reason: 'active video call on the call screen');
    pip.modes.add(true);
    await settle(tester);
    expect(find.byKey(const Key('call_pip_stage')), findsOneWidget);
    expect(find.byKey(const Key('call_hangup')), findsNothing, reason: 'no controls in PiP');
    expect(find.byKey(const ValueKey('video_u1#d1')), findsOneWidget, reason: 'remote camera');
    pip.modes.add(false);
    await settle(tester);
    expect(find.byKey(const Key('call_hangup')), findsOneWidget);
    await finish(tester);
    expect(pip.autoEnter.last, isFalse);
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
