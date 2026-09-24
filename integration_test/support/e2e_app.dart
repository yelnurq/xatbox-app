import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_reminders.dart';
import 'package:xatbox_mobile/features/calendar/presentation/calendar_providers.dart';
import 'package:xatbox_mobile/features/calls/presentation/calls_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';

import '../../test/helpers/call_fakes.dart';
import '../../test/helpers/chat_fixtures.dart';
import '../../test/helpers/fake_http.dart';
import '../../test/helpers/test_app.dart';

/// Shared glue for the end-to-end flows: the real [XatBoxApp] with every
/// backend faked (Mail/Auth API, Chat API + WebSocket, Call Service, LiveKit
/// media, system call UI, sounds, PiP, reminders).
///
/// The same files run on the host (`flutter test integration_test -d
/// flutter-tester`, default flutter_test binding) and on a device/emulator
/// (`flutter test integration_test -d emulator-5554`, integration binding).
void ensureE2EBinding() {
  if (!kIsHost) IntegrationTestWidgetsFlutterBinding.ensureInitialized();
}

/// True when running in the host `flutter_tester` VM, not on a phone.
bool get kIsHost => !(Platform.isAndroid || Platform.isIOS);

const chatBase = 'http://chat.local/api/v1';
const callsBase = 'http://calls.local/api/v1';
const selfId = ChatFixtures.me;
const selfName = 'Тест Пользователь';

/// A harness plus the call fakes, created per test.
class E2E {
  E2E._(this.h, this.native, this.medias, this.calls);

  final TestHarness h;
  final FakeCallNative native;
  final List<FakeCallMedia> medias;

  /// Null when the Call Service is not configured for the test.
  final FakeCallServer? calls;

  static Future<E2E> create({
    String? storedToken,
    bool chat = true,
    bool withCalls = true,
    List<Override> overrides = const [],
  }) async {
    final native = FakeCallNative();
    final medias = <FakeCallMedia>[];
    final h = await TestHarness.create(
      storedToken: storedToken,
      chatBaseUrl: chat ? chatBase : '',
      callsBaseUrl: withCalls ? callsBase : '',
      overrides: [
        callNativeProvider.overrideWithValue(native),
        callSoundsProvider.overrideWithValue(FakeCallSounds()),
        callPipProvider.overrideWithValue(FakeCallPip()),
        callMediaFactoryProvider.overrideWithValue(() {
          final m = FakeCallMedia();
          medias.add(m);
          return m;
        }),
        reminderSchedulerProvider.overrideWithValue(NoReminders()),
        ...overrides,
      ],
    );
    if (chat) {
      h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats(const []));
      h.chatAdapter.onPattern('POST', r'^/push/devices$', (_) => const FakeResponse(204));
      h.chatAdapter.onPattern('POST', r'^/messages/[^/]+/read$', (_) => const FakeResponse(204));
    }
    final calls = withCalls ? FakeCallServer(h.callsAdapter, selfId: selfId, selfName: selfName) : null;
    return E2E._(h, native, medias, calls);
  }
}

/// Deterministic Russian UI regardless of the machine locale.
void useRussian(WidgetTester tester) {
  tester.platformDispatcher.localeTestValue = const Locale('ru');
  tester.platformDispatcher.localesTestValue = const [Locale('ru')];
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

/// The composer constructs an `AudioRecorder`; answer its platform channel so
/// the host has no missing-plugin errors (on a device the real plugin answers).
void muteRecorderChannel() {
  if (!kIsHost) return;
  const channel = MethodChannel('com.llfbandit.record/messages');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (_) async => null);
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
}

/// Mounts the real app on top of [e2e]'s container.
Future<void> pumpE2EApp(WidgetTester tester, E2E e2e) async {
  await tester.pumpWidget(UncontrolledProviderScope(container: e2e.h.container, child: const XatBoxApp()));
  await settle(tester);
}

/// Advances frames in small steps and lets real I/O (sembast, files) finish
/// between them: spinners never "settle", so pumpAndSettle is not used.
Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Taps the bottom navigation destination with [label].
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await settle(tester);
}

/// Hangs up any call, stops the chat socket (ping timer) and lets debounce,
/// snackbar and ring timers expire before the framework checks for them.
Future<void> finishE2E(WidgetTester tester, E2E e2e) async {
  final c = e2e.h.container;
  if (e2e.calls != null) {
    unawaited(c.read(callControllerProvider.notifier).hangUp());
    await tester.pump(const Duration(seconds: 1));
  }
  if (c.read(chatEnabledProvider)) {
    unawaited(c.read(chatRepositoryProvider).stop());
  }
  await tester.pump(const Duration(seconds: 10));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

class NoReminders implements ReminderScheduler {
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> schedule(ReminderRequest request) async {}
  @override
  Future<void> cancel(int id) async {}
}
