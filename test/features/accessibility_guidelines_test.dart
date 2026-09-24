import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_reminders.dart';
import 'package:xatbox_mobile/features/calendar/presentation/calendar_providers.dart';
import 'package:xatbox_mobile/features/calls/presentation/call_screen.dart';
import 'package:xatbox_mobile/features/calls/presentation/calls_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_list_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/conversation_screen.dart';
import 'package:xatbox_mobile/features/contacts/presentation/contacts_screen.dart';
import 'package:xatbox_mobile/features/settings/data/notification_preferences.dart';
import 'package:xatbox_mobile/features/settings/notification_settings_screen.dart';

import '../helpers/call_fakes.dart';
import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// TalkBack / VoiceOver basics on representative screens of a small phone
/// (360 dp) with the system font at 130 %: no overflow, every tap target
/// ≥ 48 dp and labelled, readable contrast; merged, meaningful labels for a
/// chat row and a message; no endless animation with reduced motion.
void main() {
  late TestHarness h;
  tearDown(() => h.dispose());

  Future<void> settle(WidgetTester tester, [int steps = 12]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  void usePhone(WidgetTester tester, {double textScale = 1.3}) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    tester.platformDispatcher.localeTestValue = const Locale('ru');
    tester.platformDispatcher.localesTestValue = const [Locale('ru')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }

  Future<void> expectGuidelines(WidgetTester tester) async {
    expect(tester.takeException(), isNull, reason: 'no overflow at 360 dp / 130 %');
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  Future<void> stopChat(WidgetTester tester) async {
    unawaited(h.container.read(chatRepositoryProvider).stop());
    await tester.pump(const Duration(seconds: 10));
  }

  Future<void> chatHarness(WidgetTester tester) async {
    // The composer creates an AudioRecorder: no platform plugin in tests.
    const recordChannel = MethodChannel('com.llfbandit.record/messages');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(recordChannel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(recordChannel, null));
    h = await TestHarness.create(storedToken: Fixtures.token, chatBaseUrl: 'http://chat.local/api/v1');
    h.adapter.onJson('GET', '/me', Fixtures.me());
    final conv = ChatFixtures.conversation(
      unread: 2,
      lastSeq: 2,
      lastMessage: ChatFixtures.message(id: 'm2', seq: 2, body: 'Когда встреча?'),
    );
    h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats([conv]));
    h.chatAdapter.onJson('GET', '/chats/${ChatFixtures.conv}', ChatFixtures.conversation(lastSeq: 2));
    h.chatAdapter.onJson('GET', '/chats/${ChatFixtures.conv}/events', ChatFixtures.events(const []));
    h.chatAdapter.onJson(
      'GET',
      '/chats/${ChatFixtures.conv}/messages',
      ChatFixtures.messages([
        ChatFixtures.message(id: 'm1', seq: 1, body: 'Привет!', sender: ChatFixtures.me, status: 'read'),
        ChatFixtures.message(id: 'm2', seq: 2, body: 'Когда встреча?'),
      ]),
    );
    await tester.runAsync(() => h.session.restore());
    h.container.read(chatLifecycleProvider);
  }

  testWidgets('chat list: guidelines, one merged label per conversation', (tester) async {
    usePhone(tester);
    await chatHarness(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(wrapWidget(const ChatListScreen(), container: h.container));
    await settle(tester);
    expect(find.text('Когда встреча?'), findsOneWidget);

    await expectGuidelines(tester);
    // Name, last message and unread count are announced together.
    expect(
      find.bySemanticsLabel(RegExp('Bob.*Когда встреча\\?.*2', dotAll: true)),
      findsOneWidget,
    );
    semantics.dispose();
    await stopChat(tester);
  });

  testWidgets('conversation: guidelines, a message reads sender, text, time and status', (tester) async {
    usePhone(tester);
    await chatHarness(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      wrapWidget(const ConversationScreen(conversationId: ChatFixtures.conv), container: h.container),
    );
    await settle(tester, 20);
    expect(find.text('Привет!'), findsOneWidget);

    await expectGuidelines(tester);
    expect(
      find.bySemanticsLabel(RegExp('Привет!.*\\d{1,2}:\\d{2}.*[Пп]рочитано', dotAll: true)),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('Bob.*Когда встреча\\?', dotAll: true)), findsWidgets);
    semantics.dispose();
    await stopChat(tester);
  });

  testWidgets('contacts: guidelines at 360 dp / 130 %', (tester) async {
    usePhone(tester);
    h = await TestHarness.create(storedToken: Fixtures.token, chatBaseUrl: 'http://chat.local/api/v1');
    h.adapter.onJson('GET', '/me', Fixtures.me());
    h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats(const []));
    h.chatAdapter.onJson('GET', '/users', {
      'users': [
        ChatFixtures.user(name: 'Болат Сейтов', online: true),
        {
          ...ChatFixtures.user(id: 'u-alia', name: 'Алия Нурланова'),
          'department_id': 'd1',
          'department_name': 'Бухгалтерия',
        },
        ChatFixtures.user(id: 'u-anna', name: 'Anna Smith'),
      ],
    });
    await tester.runAsync(() => h.session.restore());
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(wrapWidget(const ContactsScreen(), container: h.container));
    await settle(tester);
    expect(find.text('Алия Нурланова'), findsOneWidget);

    await expectGuidelines(tester);
    semantics.dispose();
    await stopChat(tester);
  });

  testWidgets('notification settings: guidelines at 360 dp / 130 %', (tester) async {
    usePhone(tester);
    h = await TestHarness.create(chatBaseUrl: 'http://chat.local/api/v1');
    h.chatAdapter.onJson('GET', NotificationPreferencesApi.path, {
      'direct_messages': true,
      'group_messages': true,
      'group_mentions_only': false,
      'calls': true,
      'quiet_hours': {'enabled': false, 'start': '22:00', 'end': '07:00', 'timezone': 'UTC', 'allow_calls': true},
    });
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(wrapWidget(const NotificationSettingsScreen(), container: h.container));
    await settle(tester);
    expect(find.text('Личные сообщения'), findsOneWidget);

    await expectGuidelines(tester);
    semantics.dispose();
  });

  group('incoming call', () {
    late FakeCallServer server;

    Future<void> ring(WidgetTester tester) async {
      h = await TestHarness.create(
        storedToken: Fixtures.token,
        chatBaseUrl: 'http://chat.local/api/v1',
        callsBaseUrl: 'http://calls.local/api/v1',
        overrides: [
          callNativeProvider.overrideWithValue(FakeCallNative()),
          callMediaFactoryProvider.overrideWithValue(FakeCallMedia.new),
          reminderSchedulerProvider.overrideWithValue(_NoReminders()),
        ],
      );
      h.stubSignedIn();
      h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats(const []));
      h.chatAdapter.onPattern('POST', r'^/push/devices$', (_) => const FakeResponse(204));
      server = FakeCallServer(
        h.callsAdapter,
        selfId: '11111111-1111-4111-8111-111111111111',
        selfName: 'Тест Пользователь',
      );
      await tester.runAsync(() => h.session.restore());
      await tester.pumpWidget(UncontrolledProviderScope(container: h.container, child: const XatBoxApp()));
      await settle(tester);
      final id = server.addIncoming(callerId: 'u-bob', callerName: 'Болат Сейтов', type: 'audio');
      h.socketFactory.last.serverSend({'type': 'call.incoming', 'call_id': id, 'call': server.calls[id]});
      await settle(tester, 20);
      expect(find.byType(CallScreen), findsOneWidget);
    }

    Future<void> finish(WidgetTester tester) async {
      unawaited(h.container.read(callControllerProvider.notifier).hangUp());
      await tester.pump(const Duration(seconds: 1));
      await stopChat(tester);
    }

    testWidgets('accept / decline are labelled, large and readable', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      await ring(tester);
      expect(find.bySemanticsLabel(RegExp('Ответить')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('Отклонить')), findsWidgets);
      await expectGuidelines(tester);
      semantics.dispose();
      await finish(tester);
    });

    testWidgets('reduced motion: no endless ringing animation', (tester) async {
      usePhone(tester, textScale: 1);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const _NoAnimations();
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await ring(tester);
      // Pulse rings, the bouncing accept button and the status dots are static:
      // once idle, nothing keeps asking for frames.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.hasScheduledFrame, isFalse);
      await finish(tester);
    });
  });
}

class _NoAnimations implements AccessibilityFeatures {
  const _NoAnimations();
  @override
  bool get disableAnimations => true;
  @override
  bool get accessibleNavigation => false;
  @override
  bool get boldText => false;
  @override
  bool get highContrast => false;
  @override
  bool get invertColors => false;
  @override
  bool get onOffSwitchLabels => false;
  @override
  bool get reduceMotion => true;
  @override
  bool get supportsAnnounce => true;
  @override
  bool get autoPlayAnimatedImages => true;
  @override
  bool get autoPlayVideos => true;
  @override
  bool get deterministicCursor => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoReminders implements ReminderScheduler {
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> schedule(ReminderRequest request) async {}
  @override
  Future<void> cancel(int id) async {}
}
