import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/shared/widgets/glass_tab_bar.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/routing/app_router.dart';
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

/// Calls through the real app: missed badge and history, call back, an
/// incoming call over the chat socket opening the call screen, accept,
/// in-call controls, hang up.
void main() {
  late TestHarness h;
  late FakeCallServer server;
  late FakeCallNative native;
  late List<FakeCallMedia> medias;
  const self = '11111111-1111-4111-8111-111111111111';

  tearDown(() => h.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 12]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> launch(WidgetTester tester) async {
    native = FakeCallNative();
    medias = [];
    h = await TestHarness.create(
      storedToken: Fixtures.token,
      chatBaseUrl: 'http://chat.local/api/v1',
      callsBaseUrl: 'http://calls.local/api/v1',
      overrides: [
        callNativeProvider.overrideWithValue(native),
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
    server = FakeCallServer(h.callsAdapter, selfId: self, selfName: 'Тест Пользователь');
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

  /// Hangs up, stops the chat socket (ping timer) and lets timers expire.
  Future<void> finish(WidgetTester tester) async {
    unawaited(h.container.read(callControllerProvider.notifier).hangUp());
    await tester.pump(const Duration(seconds: 1));
    unawaited(h.container.read(chatRepositoryProvider).stop());
    await tester.pump(const Duration(seconds: 10));
  }

  testWidgets('missed badge, history with missed filter, call back opens the call screen', (tester) async {
    await launch(tester);
    server.missed = 2;
    server.calls['old'] = server.callJson(
      id: 'old',
      callerId: 'u-bob',
      others: [('u-bob', 'Болат')],
      status: 'missed',
      direction: 'incoming',
      outcome: 'missed',
    );
    await start(tester);
    expect(h.container.read(callsEnabledProvider), isTrue);
    // Missed calls sit on «Ещё» of the glass bar and on its «Звонки» tile.
    expect(find.descendant(of: find.byType(GlassTabBar), matching: find.text('2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab_more')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('more_calls')));
    await settle(tester);
    expect(find.byType(CallsScreen), findsOneWidget);
    expect(find.text('Болат'), findsOneWidget);
    expect(find.textContaining('Пропущенный'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calls_filter_missed')));
    await settle(tester);
    expect(server.missed, 0, reason: 'viewing missed calls marks them seen');
    expect(find.descendant(of: find.byType(GlassTabBar), matching: find.text('2')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('redial_old')));
    await settle(tester, 20);
    expect(server.createPosts, 1);
    expect(h.callsAdapter.of('POST', '/calls').single.json['callee_ids'], ['u-bob']);
    expect(find.byType(CallScreen), findsOneWidget);
    expect(find.text('Вызов…'), findsWidgets);
    await finish(tester);
  });

  testWidgets('incoming call over the chat socket opens the call screen; accept, mute, hang up', (tester) async {
    await launch(tester);
    await start(tester);
    final id = server.addIncoming(callerId: 'u-bob', callerName: 'Болат Сейтов', type: 'video');
    h.socketFactory.last.serverSend({'type': 'call.incoming', 'call_id': id, 'call': server.calls[id]});
    await settle(tester, 20);

    expect(find.byType(CallScreen), findsOneWidget, reason: 'opened by the app root');
    expect(find.text('Входящий видеозвонок'), findsOneWidget);
    expect(native.shownIncoming, [id], reason: 'system UI too, once');

    await tester.tap(find.byKey(const Key('call_accept')));
    await settle(tester, 20);
    expect(h.container.read(callControllerProvider).phase, CallPhase.connecting);
    medias.single.join('u-bob');
    await settle(tester);
    expect(h.container.read(callControllerProvider).phase, CallPhase.active);
    expect(find.byKey(const Key('call_timer')), findsOneWidget);
    expect(find.byKey(const Key('call_hangup')), findsOneWidget);

    await tester.tap(find.byKey(const Key('call_mic')));
    await settle(tester);
    expect(medias.single.micOn, isFalse);

    await tester.tap(find.byKey(const Key('call_hangup')));
    await settle(tester);
    expect(h.callsAdapter.of('POST', '/calls/$id/end'), hasLength(1));
    expect(find.text('Звонок завершён'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await settle(tester);
    expect(find.byType(CallScreen), findsNothing, reason: 'closes itself');
    expect(h.container.read(appRouterProvider).routeInformationProvider.value.uri.path, isNot('/call'));
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
