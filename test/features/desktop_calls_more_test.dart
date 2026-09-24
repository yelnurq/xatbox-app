import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/platform/desktop.dart';
import 'package:xatbox_mobile/core/platform/desktop_layout.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_reminders.dart';
import 'package:xatbox_mobile/features/calendar/presentation/calendar_providers.dart';
import 'package:xatbox_mobile/features/calls/presentation/call_controller.dart';
import 'package:xatbox_mobile/features/calls/presentation/call_screen.dart';
import 'package:xatbox_mobile/features/calls/presentation/calls_providers.dart';
import 'package:xatbox_mobile/features/calls/presentation/calls_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';

import '../helpers/call_fakes.dart';
import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Desktop calls: the chat and the participants list dock beside the video
/// (one panel at a time), the call's keys, Enter / Esc on an incoming call,
/// «Новый звонок» as a dialog. Phones keep their sheets and pages.
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

  Future<void> launch(WidgetTester tester, {bool desktop = true}) async {
    if (desktop) {
      debugDesktopOverride = true;
      addTearDown(() => debugDesktopOverride = null);
      tester.view.physicalSize = const Size(1440, 900);
    } else {
      tester.view.physicalSize = const Size(400, 800);
    }
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    medias = [];
    h = await TestHarness.create(
      storedToken: Fixtures.token,
      chatBaseUrl: 'http://chat.local/api/v1',
      callsBaseUrl: 'http://calls.local/api/v1',
      overrides: [
        if (desktop) desktopLayoutProvider.overrideWithValue(true),
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
    h.chatAdapter.onPattern(
      'POST',
      r'^/push/devices$',
      (_) => const FakeResponse(204),
    );
    h.chatAdapter.onJson('GET', '/users', {
      'users': [ChatFixtures.user(id: 'u-bob', name: 'Болат')],
    });
    server = FakeCallServer(
      h.callsAdapter,
      selfId: ChatFixtures.me,
      selfName: 'Тест Пользователь',
    );
    tester.platformDispatcher.localeTestValue = const Locale('ru');
    tester.platformDispatcher.localesTestValue = const [Locale('ru')];
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    // The desktop shell signs in on the first frames (as desktop_pages_test).
    if (!desktop) await tester.runAsync(() => h.session.restore());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: const XatBoxApp(),
      ),
    );
    await settle(tester);
  }

  Future<void> dial(
    WidgetTester tester,
    List<String> ids, {
    String mode = 'direct',
  }) async {
    unawaited(
      h.container
          .read(callControllerProvider.notifier)
          .startCall(calleeIds: ids, video: false, mode: mode),
    );
    unawaited(h.container.read(appRouterProvider).push(Routes.call));
    await settle(tester, 20);
    for (final id in ids) {
      medias.single.join(id);
    }
    await settle(tester);
    expect(h.container.read(callControllerProvider).phase, CallPhase.active);
  }

  Future<void> finish(WidgetTester tester) async {
    unawaited(h.container.read(callControllerProvider.notifier).hangUp());
    await tester.pump(const Duration(seconds: 1));
    unawaited(h.container.read(chatRepositoryProvider).stop());
    await tester.pump(const Duration(seconds: 10));
  }

  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool ctrl = false,
    bool shift = false,
  }) async {
    if (ctrl) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (ctrl) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
  }

  String location() => h.container
      .read(appRouterProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .path;

  final chatPanel = find.byKey(const Key('call_chat_panel'));
  final participantsPanel = find.byKey(const Key('call_participants_panel'));

  testWidgets(
    'chat and participants dock on the right of the video, one at a time, ✕ closes',
    (tester) async {
      await launch(tester);
      await dial(tester, ['u-a', 'u-b'], mode: 'group');
      final stageWidth = tester
          .getSize(find.byKey(const ValueKey('stage')))
          .width;

      await tester.tap(find.byKey(const Key('call_participants')));
      await settle(tester);
      expect(participantsPanel, findsOneWidget);
      expect(
        find.byType(Dialog),
        findsNothing,
        reason: 'a panel, not a dialog over the video',
      );
      expect(find.byType(BottomSheet), findsNothing);
      final panel = tester.getRect(participantsPanel);
      expect(panel.width, 360);
      expect(
        panel.right,
        greaterThan(1440 - 40),
        reason: 'docked on the right',
      );
      expect(find.byKey(const ValueKey('participant_u-a')), findsOneWidget);
      // The stage keeps its size; its tiles leave the panel's width free.
      expect(
        tester.getSize(find.byKey(const ValueKey('stage'))).width,
        stageWidth,
      );

      await tester.tap(find.byKey(const Key('call_chat')));
      await settle(tester);
      expect(chatPanel, findsOneWidget);
      expect(participantsPanel, findsNothing, reason: 'one panel at a time');
      expect(find.byType(Dialog), findsNothing);

      await tester.tap(find.byKey(const Key('call_participants')));
      await settle(tester);
      expect(participantsPanel, findsOneWidget);
      expect(chatPanel, findsNothing);

      // The same button closes it; so does its ✕.
      await tester.tap(find.byKey(const Key('call_participants')));
      await settle(tester);
      expect(participantsPanel, findsNothing);
      await tester.tap(find.byKey(const Key('call_participants')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('call_participants_close')));
      await settle(tester);
      expect(participantsPanel, findsNothing);
      expect(
        find.byType(CallScreen),
        findsOneWidget,
        reason: '✕ closes the panel, not the call',
      );

      await tester.tap(find.byKey(const Key('call_chat')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('call_chat_close')));
      await settle(tester);
      expect(chatPanel, findsNothing);
      await finish(tester);
    },
  );

  testWidgets(
    'call keys: M / Ctrl+D, V / Ctrl+E, Ctrl+Shift+C / P, Ctrl+Shift+H; typed letters stay in the chat',
    (tester) async {
      await launch(tester);
      await dial(tester, ['u-a', 'u-b'], mode: 'group');
      final id = h.container.read(callControllerProvider).callId!;
      final media = medias.single;

      expect(find.byTooltip('Микрофон (M, Ctrl+D)'), findsOneWidget);
      expect(find.byTooltip('Камера (V, Ctrl+E)'), findsOneWidget);
      expect(find.byTooltip('Участники (Ctrl+Shift+P)'), findsOneWidget);
      expect(find.byTooltip('Чат (Ctrl+Shift+C)'), findsOneWidget);
      expect(find.byTooltip('Выйти из звонка (Ctrl+Shift+H)'), findsOneWidget);

      expect(media.micOn, isTrue);
      await press(tester, LogicalKeyboardKey.keyM);
      expect(media.micOn, isFalse);
      await press(tester, LogicalKeyboardKey.keyD, ctrl: true);
      expect(media.micOn, isTrue);

      await press(tester, LogicalKeyboardKey.keyV);
      expect(h.container.read(callControllerProvider).cameraOn, isTrue);
      await press(tester, LogicalKeyboardKey.keyE, ctrl: true);
      expect(h.container.read(callControllerProvider).cameraOn, isFalse);

      await press(tester, LogicalKeyboardKey.keyP, ctrl: true, shift: true);
      expect(participantsPanel, findsOneWidget);
      await press(tester, LogicalKeyboardKey.keyC, ctrl: true, shift: true);
      expect(chatPanel, findsOneWidget);
      expect(participantsPanel, findsNothing);

      // Typing in the chat: M is a letter, not the microphone.
      await tester.tap(find.byKey(const Key('call_chat_input')));
      await settle(tester, 2);
      await press(tester, LogicalKeyboardKey.keyM);
      expect(media.micOn, isTrue);
      // Keys with Ctrl still work there.
      await press(tester, LogicalKeyboardKey.keyD, ctrl: true);
      expect(media.micOn, isFalse);

      await press(tester, LogicalKeyboardKey.keyC, ctrl: true, shift: true);
      expect(chatPanel, findsNothing);

      await press(tester, LogicalKeyboardKey.keyH, ctrl: true, shift: true);
      expect(
        h.callsAdapter.of('POST', '/calls/$id/end'),
        hasLength(1),
        reason: 'hangs up without asking',
      );
      expect(find.byType(AlertDialog), findsNothing);
      await finish(tester);
    },
  );

  testWidgets(
    'incoming call: Enter answers, Esc declines; tooltips name the keys',
    (tester) async {
      await launch(tester);
      final first = server.addIncoming(callerId: 'u-bob', callerName: 'Болат');
      h.socketFactory.last.serverSend({
        'type': 'call.incoming',
        'call_id': first,
        'call': server.calls[first],
      });
      await settle(tester, 20);
      expect(find.byKey(const Key('call_accept')), findsOneWidget);
      expect(find.byTooltip('Ответить (Enter)'), findsOneWidget);
      expect(find.byTooltip('Отклонить (Esc)'), findsOneWidget);

      await press(tester, LogicalKeyboardKey.escape);
      await settle(tester, 20);
      expect(h.callsAdapter.of('POST', '/calls/$first/reject'), hasLength(1));
      await tester.pump(const Duration(seconds: 4));
      await settle(tester);

      final second = server.addIncoming(callerId: 'u-bob', callerName: 'Болат');
      h.socketFactory.last.serverSend({
        'type': 'call.incoming',
        'call_id': second,
        'call': server.calls[second],
      });
      await settle(tester, 20);
      expect(find.byKey(const Key('call_accept')), findsOneWidget);
      await press(tester, LogicalKeyboardKey.enter);
      await settle(tester, 20);
      expect(h.callsAdapter.of('POST', '/calls/$second/accept'), hasLength(1));
      expect(
        h.container.read(callControllerProvider).phase,
        CallPhase.connecting,
      );
      await finish(tester);
    },
  );

  testWidgets(
    '«Новый звонок» is a dialog from the header and from C; «Позвонить» with video',
    (tester) async {
      await launch(tester);
      h.container.read(appRouterProvider).go(Routes.calls);
      await settle(tester);

      await tester.tap(find.byKey(const Key('calls_new')));
      await settle(tester, 20);
      expect(find.byKey(const Key('new_call_dialog')), findsOneWidget);
      expect(location(), Routes.calls, reason: 'over the list, not a page');
      expect(
        tester.getSize(find.byType(NewCallScreen)).width,
        lessThanOrEqualTo(560),
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('new_call_start')))
            .onPressed,
        isNull,
        reason: 'nobody picked yet',
      );
      await tester.tap(find.byKey(const Key('new_call_close')));
      await settle(tester);
      expect(find.byKey(const Key('new_call_dialog')), findsNothing);

      await press(tester, LogicalKeyboardKey.keyC);
      await settle(tester, 20);
      expect(find.byKey(const Key('new_call_dialog')), findsOneWidget);
      expect(find.byType(NewCallScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('call_pick_u-bob')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('new_call_with_video')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('new_call_start')));
      await settle(tester, 20);

      final create = h.callsAdapter.of('POST', '/calls').single.json;
      expect(create['callee_ids'], ['u-bob']);
      expect(create['type'], 'video');
      expect(find.byKey(const Key('new_call_dialog')), findsNothing);
      expect(find.byType(CallScreen), findsOneWidget);
      // Pushed over the list (the location stays the list's).
      expect(
        h.container
            .read(appRouterProvider)
            .routerDelegate
            .currentConfiguration
            .matches
            .last
            .matchedLocation,
        Routes.call,
      );

      // No new call from C during a call.
      await press(tester, LogicalKeyboardKey.keyC);
      expect(find.byKey(const Key('new_call_dialog')), findsNothing);
      await finish(tester);
    },
  );

  testWidgets(
    'phone: participants stay a sheet, a new call a page, no key hints',
    (tester) async {
      await launch(tester, desktop: false);
      await dial(tester, ['u-a', 'u-b'], mode: 'group');
      expect(find.byTooltip('Микрофон (M, Ctrl+D)'), findsNothing);
      await tester.tap(find.byKey(const Key('call_participants')));
      await settle(tester);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(participantsPanel, findsNothing);
      expect(find.byKey(const ValueKey('participant_u-a')), findsOneWidget);
      Navigator.of(
        tester.element(find.byKey(const ValueKey('participant_u-a'))),
      ).pop();
      await settle(tester);
      await finish(tester);

      h.container.read(appRouterProvider).go(Routes.calls);
      await settle(tester);
      await tester.tap(find.byKey(const Key('calls_new')));
      await settle(tester, 20);
      expect(
        h.container
            .read(appRouterProvider)
            .routerDelegate
            .currentConfiguration
            .matches
            .last
            .matchedLocation,
        Routes.callsNew,
      );
      expect(find.byType(NewCallScreen), findsOneWidget);
      expect(find.byKey(const Key('new_call_dialog')), findsNothing);
      expect(find.byKey(const Key('new_call_start')), findsNothing);
    },
  );
}

class _NoReminders implements ReminderScheduler {
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> schedule(ReminderRequest request) async {}
  @override
  Future<void> cancel(int id) async {}
}
