import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_reminders.dart';
import 'package:xatbox_mobile/features/calendar/presentation/calendar_providers.dart';
import 'package:xatbox_mobile/features/calls/presentation/call_controller.dart';
import 'package:xatbox_mobile/features/calls/presentation/call_screen.dart';
import 'package:xatbox_mobile/features/calls/presentation/calls_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';

import '../helpers/call_fakes.dart';
import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// The redesigned in-call experience through the real app: minimising into
/// the floating mini bar, raise hand and reactions over the data channel,
/// the ended summary, and layouts at phone width.
void main() {
  late TestHarness h;
  late FakeCallServer server;
  late List<FakeCallMedia> medias;

  tearDown(() => h.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 12]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> launch(WidgetTester tester) async {
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
    await tester.runAsync(() => h.session.restore());
    await tester.pumpWidget(UncontrolledProviderScope(container: h.container, child: const XatBoxApp()));
    await settle(tester);
  }

  Future<String> dial(WidgetTester tester, List<String> ids, {bool video = false, String? mode}) async {
    unawaited(h.container.read(callControllerProvider.notifier).startCall(calleeIds: ids, video: video, mode: mode));
    unawaited(h.container.read(appRouterProvider).push(Routes.call));
    await settle(tester, 20);
    return h.container.read(callControllerProvider).callId!;
  }

  Future<void> finish(WidgetTester tester) async {
    unawaited(h.container.read(callControllerProvider.notifier).hangUp());
    await tester.pump(const Duration(seconds: 1));
    unawaited(h.container.read(chatRepositoryProvider).stop());
    await tester.pump(const Duration(seconds: 10));
  }

  testWidgets('back minimises the call into the floating mini bar; tap returns; the mini bar hangs up', (tester) async {
    await launch(tester);
    final id = await dial(tester, ['u-bob']);
    expect(find.byType(CallScreen), findsOneWidget);
    expect(find.byKey(const Key('call_mini_bar')), findsNothing, reason: 'hidden over the call screen');

    h.container.read(appRouterProvider).pop(); // system back
    await settle(tester);
    expect(find.byType(CallScreen), findsNothing);
    expect(h.container.read(callControllerProvider).inCall, isTrue, reason: 'minimised, not ended');
    expect(find.byKey(const Key('call_mini_bar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('call_mini_bar')));
    await settle(tester);
    expect(find.byType(CallScreen), findsOneWidget);
    expect(find.byKey(const Key('call_mini_bar')), findsNothing);

    await tester.tap(find.byKey(const Key('call_minimize')));
    await settle(tester);
    expect(find.byType(CallScreen), findsNothing);
    expect(find.byKey(const Key('call_mini_bar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('call_mini_hangup')));
    await settle(tester);
    expect(h.callsAdapter.of('POST', '/calls/$id/cancel'), hasLength(1));
    expect(find.byKey(const Key('call_mini_bar')), findsNothing);
    await finish(tester);
  });

  testWidgets('group call: raise hand and emoji reactions travel over the data channel', (tester) async {
    await launch(tester);
    await dial(tester, ['u1', 'u2'], mode: 'group');
    final media = medias.single;
    media.join('u1');
    await settle(tester);
    expect(h.container.read(callControllerProvider).phase, CallPhase.active);

    await tester.tap(find.byKey(const Key('call_more')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('call_raise_hand')));
    await settle(tester);
    expect(media.sentData.last, {'type': 'hand', 'up': true});
    expect(h.container.read(callControllerProvider).handRaised, isTrue);
    expect(find.byKey(const ValueKey('tile_hand_me#dev')), findsOneWidget);

    media.receive('u1#d1', {'type': 'hand', 'up': true});
    await settle(tester);
    expect(find.byKey(const ValueKey('tile_hand_u1#d1')), findsOneWidget);
    media.receive('u1#d1', {'type': 'hand', 'up': false});
    await settle(tester);
    expect(find.byKey(const ValueKey('tile_hand_u1#d1')), findsNothing);

    media.receive('u1#d1', {'type': 'reaction', 'emoji': '🎉'});
    media.receive('u1#d1', {'type': 'reaction', 'emoji': 'not-an-emoji'});
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('🎉'), findsOneWidget);
    expect(find.text('not-an-emoji'), findsNothing, reason: 'only the offered reactions are shown');
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('🎉'), findsNothing, reason: 'floats away');

    await tester.tap(find.byKey(const Key('call_more')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('call_react_0')));
    await settle(tester);
    expect(media.sentData.last, {'type': 'reaction', 'emoji': '👍'});
    await finish(tester);
  });

  testWidgets('ended summary: a touch keeps it open; «Перезвонить» calls the same person again', (tester) async {
    await launch(tester);
    final first = await dial(tester, ['u-bob']);
    medias.single.join('u-bob');
    await settle(tester);
    await tester.tap(find.byKey(const Key('call_hangup')));
    await settle(tester);
    expect(h.callsAdapter.of('POST', '/calls/$first/end'), hasLength(1));
    expect(find.text('Звонок завершён'), findsOneWidget);
    expect(find.byKey(const Key('call_ended_duration')), findsOneWidget);

    await tester.tap(find.byKey(const Key('call_status')));
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    expect(find.byType(CallScreen), findsOneWidget, reason: 'kept open after a touch');

    await tester.tap(find.byKey(const Key('call_redial')));
    await settle(tester, 20);
    expect(server.createPosts, 2);
    expect(h.callsAdapter.of('POST', '/calls').last.json['callee_ids'], ['u-bob']);
    expect(h.container.read(callControllerProvider).phase, CallPhase.outgoing);
    expect(find.text('Вызов…'), findsWidgets);
    await finish(tester);
  });

  testWidgets('phone width 360: incoming, 1:1 video with auto-hiding controls, sheets, group layouts, ended', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await launch(tester);

    final id = server.addIncoming(callerId: 'u-bob', callerName: 'Болат Сейтов', type: 'video');
    h.socketFactory.last.serverSend({'type': 'call.incoming', 'call_id': id, 'call': server.calls[id]});
    await settle(tester, 20);
    expect(find.byKey(const Key('call_accept')), findsOneWidget);

    await tester.tap(find.byKey(const Key('call_decline_message')));
    await settle(tester);
    expect(find.byKey(const Key('call_quick_reply_0')), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const Key('call_quick_reply_0')))).pop();
    await settle(tester);

    await tester.tap(find.byKey(const Key('call_accept')));
    await settle(tester, 20);
    medias.single.join('u-bob', cameraOn: true);
    await settle(tester);
    expect(find.byKey(const Key('call_local_preview')), findsOneWidget);
    await tester.tap(find.byKey(const Key('call_local_preview')));
    await settle(tester);

    await tester.tap(find.byKey(const Key('call_more')));
    await settle(tester);
    expect(find.byKey(const Key('call_screen_share')), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const Key('call_screen_share')))).pop();
    await settle(tester);

    Offset dockOffset() => tester
        .widget<AnimatedSlide>(find.ancestor(of: find.byKey(const Key('call_hangup')), matching: find.byType(AnimatedSlide)).first)
        .offset;
    expect(dockOffset(), Offset.zero);
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    expect(dockOffset(), isNot(Offset.zero), reason: 'controls hide on a video call');
    await tester.tapAt(const Offset(180, 330));
    await settle(tester);
    expect(dockOffset(), Offset.zero, reason: 'a tap brings them back');

    await tester.tap(find.byKey(const Key('call_hangup')));
    await settle(tester);
    expect(find.text('Звонок завершён'), findsOneWidget);
    h.container.read(callControllerProvider.notifier).dismiss();
    await settle(tester);
    expect(find.byType(CallScreen), findsNothing);

    await dial(tester, ['u1', 'u2', 'u3', 'u4', 'u5'], video: true, mode: 'group');
    final media = medias.last;
    for (final u in ['u1', 'u2', 'u3', 'u4', 'u5']) {
      media.join(u, cameraOn: u == 'u2', speaking: u == 'u3');
    }
    await settle(tester);
    expect(find.byKey(const ValueKey('tile_u5#d1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('call_layout')));
    await settle(tester);
    expect(find.byKey(const ValueKey('tile_u3#d1')), findsWidgets, reason: 'the speaker in the spotlight');
    await tester.tap(find.byKey(const Key('call_participants')));
    await settle(tester);
    expect(find.byKey(const ValueKey('participant_u5')), findsOneWidget);
    await finish(tester);
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
