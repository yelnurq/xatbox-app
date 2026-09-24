import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/network/network_status.dart';
import 'package:xatbox_mobile/features/chat/data/chat_broadcast.dart';
import 'package:xatbox_mobile/features/chat/data/chat_reminder_notifications.dart';
import 'package:xatbox_mobile/features/chat/presentation/broadcast/broadcast_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/channels/channel_discover_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_list_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/conversation_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/reminders/reminders_screen.dart';

import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

class _RecordingReminderNotifier implements ChatReminderNotifier {
  final calls = <List<ChatReminder>>[];

  @override
  Future<void> sync(
    List<ChatReminder> reminders, {
    required String title,
    required String Function(ChatReminder reminder) bodyOf,
  }) async {
    for (final r in reminders) {
      bodyOf(r);
    }
    calls.add(reminders);
  }
}

/// Channels, polls, «Отправить позже» and «Напомнить» in the UI, with 360 px
/// layouts checked for overflow.
void main() {
  late TestHarness h;
  late Directory tmp;
  late _RecordingReminderNotifier reminderNotifier;
  const conv = ChatFixtures.conv;
  const group = 'c0000000-0000-4000-8000-000000000003';
  const channel = 'c0000000-0000-4000-8000-0000000000c1';

  tearDown(() async {
    await h.dispose();
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // the OS cleans temp later
    }
  });

  Future<void> prepare({List<Override> extra = const []}) async {
    const recordChannel = MethodChannel('com.llfbandit.record/messages');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(recordChannel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(recordChannel, null));
    tmp = Directory.systemTemp.createTempSync('xatbox_broadcast');
    reminderNotifier = _RecordingReminderNotifier();
    h = await TestHarness.create(
      storedToken: Fixtures.token,
      chatBaseUrl: 'http://chat.local/api/v1',
      network: FixedNetworkMonitor(NetworkKind.wifi),
      overrides: [
        chatMediaRootProvider.overrideWithValue(() async => tmp),
        chatReminderNotifierProvider.overrideWithValue(reminderNotifier),
        ...extra,
      ],
    );
    h.adapter.onJson('GET', '/me', Fixtures.me());
    h.chatAdapter.onPattern('POST', r'^/messages/[^/]+/read$', (_) => const FakeResponse(204));
    h.chatAdapter.onPattern('GET', r'^/chats/[^/]+/scheduled$', (_) => const FakeResponse(200, json: {'scheduled': []}));
  }

  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> signIn(WidgetTester tester) => tester.runAsync(() => h.session.restore());

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
  }

  void useSize(WidgetTester tester) {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360, 740) * 3;
    addTearDown(tester.view.reset);
  }

  void stubConversation(Map<String, dynamic> c, List<Map<String, dynamic>> messages) {
    h.chatAdapter.onJson('GET', '/chats/${c['id']}', c);
    h.chatAdapter.onJson('GET', '/chats/${c['id']}/messages', ChatFixtures.messages(messages));
  }

  Map<String, dynamic> groupJson() => ChatFixtures.conversation(
    id: group,
    title: 'Отдел кадров',
    group: true,
    members: [
      ChatFixtures.member(ChatFixtures.me, 'Me', role: 'owner'),
      ChatFixtures.member(ChatFixtures.peer, 'Bob'),
    ],
  );

  Map<String, dynamic> pollJson({
    List<int>? myVotes = const [],
    int total = 0,
    List<int> votes = const [0, 0, 0],
    bool anonymous = false,
    bool multiple = false,
    bool closed = false,
    int? correct,
    String createdBy = ChatFixtures.peer,
  }) => {
    'question': 'Где обедаем в пятницу всем отделом?',
    'options': [
      {'text': 'Столовая', 'votes': votes[0]},
      {'text': 'Кафе с очень длинным названием на соседней улице у парка', 'votes': votes[1]},
      {'text': 'Дома', 'votes': votes[2]},
    ],
    'anonymous': anonymous,
    'multiple': multiple,
    'quiz': correct != null,
    'correct_option': ?correct,
    'closed': closed,
    'total_voters': total,
    'my_votes': ?myVotes,
    'created_by': createdBy,
  };

  Map<String, dynamic> pollMessage(String id, int seq, Map<String, dynamic> poll, {String sender = ChatFixtures.peer}) => {
    ...ChatFixtures.message(id: id, seq: seq, convId: group, sender: sender, type: 'poll', body: poll['question'] as String),
    'poll': poll,
  };

  testWidgets('360 px: «Опрос» in the attach grid validates and creates a poll', (tester) async {
    useSize(tester);
    await prepare();
    stubConversation(groupJson(), const []);
    h.chatAdapter.on('POST', '/chats/$group/polls', (req) => FakeResponse(
      201,
      json: pollMessage('p9', 1, pollJson(createdBy: ChatFixtures.me), sender: ChatFixtures.me),
    ));
    await signIn(tester);
    await tester.pumpWidget(wrapWidget(const ConversationScreen(conversationId: group), container: h.container));
    await settle(tester, 14);

    await tester.tap(find.byKey(const Key('chat_attach')));
    await settle(tester, 6);
    expect(find.text('Опрос'), findsOneWidget);
    await tester.tap(find.byKey(const Key('attach_poll')));
    await settle(tester, 6);
    expect(find.text('Новый опрос'), findsOneWidget);
    await tester.tap(find.byKey(const Key('poll_create')));
    await settle(tester, 2);
    expect(find.byKey(const Key('poll_error')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byKey(const Key('poll_question')), 'Где обедаем?');
    await tester.enterText(find.byKey(const Key('poll_option_0')), 'Столовая');
    await tester.enterText(find.byKey(const Key('poll_option_1')), 'Кафе');
    await tester.tap(find.byKey(const Key('poll_add_option')));
    await settle(tester, 2);
    await tester.enterText(find.byKey(const Key('poll_option_2')), 'Дома');
    await tester.ensureVisible(find.byKey(const Key('poll_anonymous')));
    await tester.tap(find.byKey(const Key('poll_anonymous')));
    await tester.tap(find.byKey(const Key('poll_multiple')));
    await tester.ensureVisible(find.byKey(const Key('poll_close_day')));
    await tester.tap(find.byKey(const Key('poll_close_day')));
    await settle(tester, 2);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('poll_create')));
    await settle(tester, 8);

    final body = h.chatAdapter.of('POST', '/chats/$group/polls').single.json;
    expect(body['question'], 'Где обедаем?');
    expect(body['options'], ['Столовая', 'Кафе', 'Дома']);
    expect(body['anonymous'], isFalse);
    expect(body['multiple'], isTrue);
    expect(body['quiz'], isFalse);
    expect(body['client_message_id'], isNotEmpty);
    final closeAt = DateTime.parse(body['close_at'] as String);
    expect(closeAt.difference(DateTime.now()).inHours, inInclusiveRange(23, 24));
    expect(find.text('Новый опрос'), findsNothing);
    await finish(tester);
  });

  testWidgets('360 px poll voting: tap a choice, animated results, voters of a public poll', (tester) async {
    useSize(tester);
    await prepare();
    stubConversation(groupJson(), [pollMessage('p1', 1, pollJson())]);
    h.chatAdapter.onJson('POST', '/messages/p1/poll/votes', {
      'poll': pollJson(myVotes: [1], total: 1, votes: [0, 1, 0]),
    });
    h.chatAdapter.onJson('GET', '/messages/p1/poll/voters', {
      'voters': [
        {'user_id': ChatFixtures.peer, 'display_name': 'Bob Builder', 'options': [1], 'voted_at': '2026-09-15T10:00:00Z'},
      ],
    });
    await signIn(tester);
    await tester.pumpWidget(wrapWidget(const ConversationScreen(conversationId: group), container: h.container));
    await settle(tester, 14);

    expect(find.byKey(const ValueKey('poll_p1')), findsOneWidget);
    expect(find.text('Открытый опрос'), findsOneWidget);
    expect(find.text('Нет голосов'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('poll_opt_p1_1')));
    await settle(tester, 10);
    expect(h.chatAdapter.of('POST', '/messages/p1/poll/votes').single.json, {'options': [1]});
    expect(find.byKey(const ValueKey('poll_result_p1_1')), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('1 голос'), findsOneWidget);
    expect(find.byKey(const ValueKey('poll_retract_p1')), findsOneWidget);
    expect(find.byKey(const ValueKey('poll_close_p1')), findsOneWidget, reason: 'the group owner may close');
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('poll_result_p1_1')));
    await settle(tester, 10);
    expect(find.byKey(const Key('poll_voters_sheet')), findsOneWidget);
    expect(find.text('Bob Builder'), findsOneWidget);
    expect(h.chatAdapter.of('GET', '/messages/p1/poll/voters').single.query['option'], '1');
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('multiple choice votes with the button; a closed quiz shows the answer', (tester) async {
    useSize(tester);
    await prepare();
    stubConversation(groupJson(), [
      pollMessage('p1', 1, pollJson(multiple: true, anonymous: true)),
      pollMessage('p2', 2, pollJson(closed: true, correct: 0, myVotes: [1], total: 3, votes: [2, 1, 0])),
    ]);
    h.chatAdapter.onJson('POST', '/messages/p1/poll/votes', {
      'poll': pollJson(multiple: true, anonymous: true, myVotes: [0, 2], total: 1, votes: [1, 0, 1]),
    });
    await signIn(tester);
    await tester.pumpWidget(wrapWidget(const ConversationScreen(conversationId: group), container: h.container));
    await settle(tester, 14);

    final quiz = find.byKey(const ValueKey('poll_p2'));
    expect(find.descendant(of: quiz, matching: find.text('Опрос завершён')), findsOneWidget);
    expect(find.descendant(of: quiz, matching: find.text('67%')), findsOneWidget);
    expect(find.byKey(const ValueKey('poll_opt_p2_0')), findsNothing, reason: 'closed polls show results only');

    await tester.ensureVisible(find.byKey(const ValueKey('poll_p1')));
    final vote = find.byKey(const ValueKey('poll_vote_p1'));
    expect(tester.widget<FilledButton>(vote).onPressed, isNull);
    // Choice rows have 48 dp tap targets now, so the card is taller than the
    // viewport slack: bring each control into view before tapping it.
    for (final key in ['poll_opt_p1_0', 'poll_opt_p1_2']) {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey(key)));
    }
    await settle(tester, 2);
    await tester.ensureVisible(vote);
    await tester.pump();
    await tester.tap(vote);
    await settle(tester, 10);
    expect(h.chatAdapter.of('POST', '/messages/p1/poll/votes').single.json, {'options': [0, 2]});
    expect(find.byKey(const ValueKey('poll_result_p1_2')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('360 px «Отправить позже»: long press send → «Завтра утром», indicator, list, send now', (tester) async {
    useSize(tester);
    await prepare();
    stubConversation(ChatFixtures.conversation(), [ChatFixtures.message(id: 'm1', seq: 1, body: 'Привет')]);
    final items = <Map<String, dynamic>>[];
    h.chatAdapter.on('GET', '/chats/$conv/scheduled', (_) => FakeResponse(200, json: {'scheduled': items}));
    h.chatAdapter.on('POST', '/chats/$conv/scheduled', (req) {
      final item = {
        'id': 's1',
        'conversation_id': conv,
        'body': req.json['body'],
        'send_at': req.json['send_at'],
        'attachments': <Object>[],
        'status': 'pending',
      };
      items.add(item);
      return FakeResponse(201, json: item);
    });
    h.chatAdapter.on('POST', '/scheduled/s1/send', (_) {
      items.clear();
      return FakeResponse(201, json: ChatFixtures.message(id: 'm2', seq: 2, sender: ChatFixtures.me, body: 'Отчёт будет завтра'));
    });
    await signIn(tester);
    await tester.pumpWidget(wrapWidget(const ConversationScreen(conversationId: conv), container: h.container));
    await settle(tester, 14);
    expect(find.byKey(const Key('composer_scheduled')), findsNothing);

    await tester.enterText(find.byKey(const Key('chat_input')), 'Отчёт будет завтра');
    await settle(tester, 4);
    await tester.longPress(find.byKey(const Key('chat_send')));
    await settle(tester, 6);
    expect(find.text('Отправить позже'), findsOneWidget);
    expect(find.byKey(const Key('when_inOneHour')), findsOneWidget);
    expect(find.byKey(const Key('when_pick')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('when_tomorrowMorning')));
    await settle(tester, 10);

    final sent = h.chatAdapter.of('POST', '/chats/$conv/scheduled').single.json;
    expect(sent['body'], 'Отчёт будет завтра');
    final now = DateTime.now();
    expect(DateTime.parse(sent['send_at'] as String).toLocal(), DateTime(now.year, now.month, now.day + 1, 9));
    expect(find.widgetWithText(TextField, 'Отчёт будет завтра'), findsNothing, reason: 'the input is cleared');
    expect(find.byKey(const Key('composer_scheduled')), findsOneWidget);
    expect(find.text('1 запланированное сообщение'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The confirmation snackbar sits over the composer: dismiss it first.
    ScaffoldMessenger.of(tester.element(find.byKey(const Key('composer_scheduled')))).removeCurrentSnackBar();
    await settle(tester, 4);
    await tester.tap(find.byKey(const Key('composer_scheduled')));
    await settle(tester, 8);
    expect(find.byKey(const ValueKey('scheduled_s1')), findsOneWidget);
    expect(find.textContaining('завтра в 09:00'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('scheduled_menu_s1')));
    await settle(tester, 4);
    await tester.tap(find.byKey(const Key('scheduled_send_now')));
    await settle(tester, 8);
    expect(h.chatAdapter.of('POST', '/scheduled/s1/send'), hasLength(1));
    expect(find.text('Нет запланированных сообщений'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('360 px «Каналы организации»: search, subscribe, create', (tester) async {
    useSize(tester);
    await prepare();
    h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats(const []));
    h.chatAdapter.on('GET', '/channels', (req) => FakeResponse(200, json: {
      'channels': [
        {
          'id': 'ch1',
          'title': 'Новости колледжа и объявления ректората для всех сотрудников',
          'description': 'Официальные объявления, приказы и расписание ' * 3,
          'subscriber_count': 128,
          'subscribed': false,
          'is_public': true,
        },
        if (req.query['q'] == null)
          {'id': 'ch2', 'title': 'Спорт', 'subscriber_count': 1, 'subscribed': true, 'my_role': 'member', 'is_public': true},
      ],
      'has_more': false,
    }));
    h.chatAdapter.onJson('POST', '/channels/ch1/subscription', {
      ...ChatFixtures.conversation(id: 'ch1', group: true, title: 'Новости', myRole: 'member'),
      'type': 'channel',
      'is_public': true,
    }, status: 201);
    h.chatAdapter.on('POST', '/chats', (req) => FakeResponse(201, json: {
      ...ChatFixtures.conversation(id: channel, group: true, title: req.json['title'] as String),
      'type': 'channel',
      'is_public': req.json['is_public'],
    }));
    await signIn(tester);
    await tester.pumpWidget(wrapWidget(const ChannelDiscoverScreen(), container: h.container));
    await settle(tester, 10);

    expect(find.text('Каналы организации'), findsOneWidget);
    expect(find.textContaining('128 подписчиков'), findsOneWidget);
    expect(find.byKey(const ValueKey('channel_open_ch2')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('channel_subscribe_ch1')));
    await settle(tester, 8);
    expect(h.chatAdapter.of('POST', '/channels/ch1/subscription'), hasLength(1));
    expect(find.byKey(const ValueKey('channel_open_ch1')), findsOneWidget);
    expect(find.textContaining('129 подписчиков'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('channel_search')), 'новости');
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester, 8);
    expect(h.chatAdapter.of('GET', '/channels').last.query['q'], 'новости');
    expect(find.byKey(const ValueKey('channel_open_ch2')), findsNothing);

    await tester.tap(find.byKey(const Key('channel_create_fab')));
    await settle(tester, 6);
    await tester.tap(find.byKey(const Key('channel_create')));
    await settle(tester, 2);
    expect(h.chatAdapter.of('POST', '/chats'), isEmpty, reason: 'a name is required');
    await tester.enterText(find.byKey(const Key('channel_title')), 'Кафедра информатики');
    await tester.tap(find.byKey(const Key('channel_public')));
    await settle(tester, 2);
    expect(find.text('Подписчиков добавляют администраторы канала'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('channel_create')));
    await settle(tester, 8);
    expect(h.chatAdapter.of('POST', '/chats').single.json, {
      'type': 'channel',
      'title': 'Кафедра информатики',
      'description': '',
      'is_public': false,
    });
    await finish(tester);
  });

  testWidgets('360 px channel for a subscriber: read-only bar, view counts, megaphone and filter in the list', (tester) async {
    useSize(tester);
    await prepare();
    final ch = {
      ...ChatFixtures.conversation(
        id: channel,
        title: 'Ректорат: официальные объявления для сотрудников',
        group: true,
        myRole: 'member',
        members: [ChatFixtures.member(ChatFixtures.peer, 'Bob', role: 'owner')],
        lastMessage: ChatFixtures.message(id: 'post1', seq: 1, convId: channel, body: 'Завтра выходной'),
      ),
      'type': 'channel',
      'is_public': true,
      'member_count': 250,
    };
    stubConversation(ch, [
      {...ChatFixtures.message(id: 'post1', seq: 1, convId: channel, body: 'Завтра выходной'), 'views': 1234},
    ]);
    h.chatAdapter.on('PATCH', '/chats/$channel', (req) => FakeResponse(200, json: ch));
    await signIn(tester);
    await tester.pumpWidget(wrapWidget(const ConversationScreen(conversationId: channel), container: h.container));
    await settle(tester, 14);

    expect(find.byKey(const Key('channel_read_only_bar')), findsOneWidget);
    expect(find.byKey(const Key('chat_input')), findsNothing);
    expect(find.text('250 подписчиков'), findsOneWidget);
    expect(find.byKey(const ValueKey('views_post1')), findsOneWidget);
    expect(find.text('1234 '), findsOneWidget);
    expect(find.byKey(const Key('chat_audio_call')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('channel_mute_toggle')));
    await settle(tester, 6);
    expect(h.chatAdapter.of('PATCH', '/chats/$channel').single.json.containsKey('muted_until'), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    final direct = ChatFixtures.conversation(lastMessage: ChatFixtures.message(id: 'm1', seq: 1, body: 'Привет'));
    h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats([ch, direct]));
    await tester.pumpWidget(wrapWidget(const ChatListScreen(), container: h.container));
    await settle(tester, 12);
    expect(find.byKey(const ValueKey('chat_channel_badge_$channel')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('chat_filter_channels')),
      80,
      scrollable: find.ancestor(of: find.byKey(const Key('chat_filter_all')), matching: find.byType(Scrollable)).first,
    );
    await tester.tap(find.byKey(const Key('chat_filter_channels')));
    await settle(tester, 4);
    expect(find.byKey(const ValueKey('chat_$channel')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat_$conv')), findsNothing);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('360 px «Напомнить» from the message menu; «Напоминания» lists and deletes', (tester) async {
    useSize(tester);
    await prepare();
    stubConversation(ChatFixtures.conversation(), [ChatFixtures.message(id: 'm1', seq: 1, body: 'Созвон в пятницу')]);
    final reminders = <Map<String, dynamic>>[];
    h.chatAdapter.on('GET', '/reminders', (_) => FakeResponse(200, json: {'reminders': reminders}));
    h.chatAdapter.on('POST', '/messages/m1/reminders', (req) {
      final r = {
        'id': 'r1',
        'message_id': 'm1',
        'conversation_id': conv,
        'remind_at': req.json['remind_at'],
        'note': '',
        'status': 'pending',
        'conversation_title': 'Bob',
        'conversation_type': 'direct',
        'message': ChatFixtures.message(id: 'm1', seq: 1, body: 'Созвон в пятницу'),
      };
      reminders.add(r);
      return FakeResponse(201, json: r);
    });
    h.chatAdapter.on('DELETE', '/reminders/r1', (_) {
      reminders.clear();
      return const FakeResponse(204);
    });
    await signIn(tester);
    await tester.pumpWidget(wrapWidget(const ConversationScreen(conversationId: conv), container: h.container));
    await settle(tester, 14);

    await tester.longPress(find.text('Созвон в пятницу'));
    await settle(tester, 6);
    await tester.ensureVisible(find.byKey(const Key('message_remind')));
    await tester.tap(find.byKey(const Key('message_remind')));
    await settle(tester, 6);
    expect(find.text('Напомнить о сообщении'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('when_inOneHour')));
    await settle(tester, 10);

    final at = DateTime.parse(h.chatAdapter.of('POST', '/messages/m1/reminders').single.json['remind_at'] as String);
    expect(at.difference(DateTime.now()).inMinutes, inInclusiveRange(58, 60));
    expect(find.textContaining('Напомню'), findsOneWidget);
    expect(reminderNotifier.calls.last.single.id, 'r1');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(wrapWidget(const RemindersScreen(), container: h.container));
    await settle(tester, 10);
    expect(find.text('Предстоящие'.toUpperCase()), findsOneWidget);
    expect(find.byKey(const ValueKey('reminder_r1')), findsOneWidget);
    expect(find.textContaining('Bob: Созвон в пятницу'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('reminder_menu_r1')));
    await settle(tester, 4);
    await tester.tap(find.byKey(const Key('reminder_delete')));
    await settle(tester, 8);
    expect(h.chatAdapter.of('DELETE', '/reminders/r1'), hasLength(1));
    expect(find.text('Напоминаний нет'), findsOneWidget);
    expect(reminderNotifier.calls.last, isEmpty);
    await finish(tester);
  });
}
