import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/features/chat/data/chat_broadcast.dart';
import 'package:xatbox_mobile/features/chat/data/chat_models.dart';
import 'package:xatbox_mobile/features/chat/data/chat_reminder_notifications.dart';
import 'package:xatbox_mobile/features/chat/data/chat_repository.dart';
import 'package:xatbox_mobile/features/chat/data/push_notifications.dart';
import 'package:xatbox_mobile/features/chat/presentation/broadcast/broadcast_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/poll/poll_create_sheet.dart';
import 'package:xatbox_mobile/features/chat/presentation/scheduled/when_picker.dart';
import 'package:xatbox_mobile/features/settings/data/notification_preferences.dart';

import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Channels, polls, scheduled messages and reminders: models, folds, pure
/// helpers and the REST client.
void main() {
  Map<String, dynamic> pollJson({
    List<int>? myVotes = const [],
    int total = 0,
    List<int> votes = const [0, 0],
    bool closed = false,
    int? correct,
  }) => {
    'question': 'Где обедаем?',
    'options': [
      {'text': 'Столовая', 'votes': votes[0]},
      {'text': 'Кафе', 'votes': votes[1]},
    ],
    'anonymous': false,
    'multiple': false,
    'quiz': correct != null,
    'correct_option': ?correct,
    'closed': closed,
    'total_voters': total,
    'my_votes': ?myVotes,
    'created_by': ChatFixtures.peer,
  };

  group('models', () {
    test('poll: json round trip, percentages, closing', () {
      final p = ChatPoll.fromJson(pollJson(myVotes: [1], total: 3, votes: [1, 2]));
      expect(p.voted, isTrue);
      expect(p.percentOf(0), 33);
      expect(p.percentOf(1), 67);
      expect(p.percentOf(5), 0);
      expect(ChatPoll.fromJson(p.toJson()).toJson(), p.toJson());
      final closeAt = DateTime.utc(2026, 9, 15, 12);
      final timed = ChatPoll(question: 'q', options: const [], closeAt: closeAt);
      expect(timed.isClosedAt(closeAt.subtract(const Duration(minutes: 1))), isFalse);
      expect(timed.isClosedAt(closeAt), isTrue);
    });

    test('poll.updated for other members keeps my votes and the revealed answer', () {
      final mine = ChatPoll.fromJson(pollJson(myVotes: [0], total: 1, votes: [1, 0], correct: 0));
      final broadcast = ChatPoll.fromJson(pollJson(myVotes: null, total: 2, votes: [1, 1]));
      final merged = mine.mergeUpdate(broadcast);
      expect(merged.myVotes, [0]);
      expect(merged.totalVoters, 2);
      expect(merged.correctOption, 0);
      final own = mine.mergeUpdate(ChatPoll.fromJson(pollJson(myVotes: const [], total: 1)));
      expect(own.myVotes, isEmpty, reason: 'the voter copy carries my_votes');
    });

    test('repository fold applies poll.updated to a cached message', () {
      final cur = ChatMessage.fromJson({
        ...ChatFixtures.message(id: 'p1', seq: 1, type: 'poll', body: 'Где обедаем?'),
        'poll': pollJson(myVotes: [1], total: 1, votes: [0, 1]),
      });
      final ev = ChatEvent.fromFrame({
        'type': 'poll.updated',
        'conversation_id': ChatFixtures.conv,
        'seq': 4,
        'message_id': 'p1',
        'poll': pollJson(myVotes: null, total: 2, votes: [1, 1], closed: true),
      });
      final next = ChatRepository.applyToMessage(cur, ev, ChatFixtures.me)!;
      expect(next.isPoll, isTrue);
      expect(next.poll!.closed, isTrue);
      expect(next.poll!.totalVoters, 2);
      expect(next.poll!.myVotes, [1]);
      expect(ChatMessage.fromJson(next.toJson()).poll!.totalVoters, 2, reason: 'cached with the poll');
    });

    test('channel conversation and channel post', () {
      final c = ChatConversation.fromJson({
        ...ChatFixtures.conversation(group: true, title: 'Новости'),
        'type': 'channel',
        'is_public': true,
      });
      expect(c.isChannel, isTrue);
      expect(c.isGroup, isFalse);
      expect(c.isPublic, isTrue);
      expect(ChatConversation.fromJson(c.toJson()).isPublic, isTrue);
      final m = ChatMessage.fromJson({...ChatFixtures.message(id: 'm1', seq: 1), 'views': 42});
      expect(m.views, 42);
      expect(m.copyWith(body: 'x').views, 42);
      expect(ChatMessage.fromJson(ChatFixtures.message(id: 'm2', seq: 2)).views, isNull);
    });

    test('notification preferences carry the channels toggle (default on)', () {
      expect(const NotificationPreferences().channels, isTrue);
      expect(NotificationPreferences.fromJson(const {}).channels, isTrue);
      final off = const NotificationPreferences().copyWith(channels: false);
      expect(off.toJson()['channels'], isFalse);
      expect(NotificationPreferences.fromJson(off.toJson()), off);
    });
  });

  group('pure helpers', () {
    test('poll draft validation and the correct option among filled inputs', () {
      expect(const PollDraft(question: ' ', options: ['a', 'b']).validate(), PollDraftError.question);
      expect(const PollDraft(question: 'q', options: ['a', '']).validate(), PollDraftError.options);
      expect(const PollDraft(question: 'q', options: ['Да', 'да ']).validate(), PollDraftError.options);
      expect(const PollDraft(question: 'q', options: ['a', 'b'], quiz: true).validate(), PollDraftError.quiz);
      const quiz = PollDraft(question: 'q', options: ['a', '', 'c'], quiz: true, correctOption: 2);
      expect(quiz.validate(), isNull);
      expect(quiz.cleanOptions, ['a', 'c']);
      expect(quiz.cleanCorrectOption, 1);
    });

    test('when presets: «сегодня вечером» only until 18:30, tomorrow at 9:00', () {
      final morning = WhenPresets.forNow(DateTime(2026, 9, 15, 10, 5));
      expect(morning.map((p) => p.$1), WhenPreset.values);
      expect(morning[0].$2, DateTime(2026, 9, 15, 11, 5));
      expect(morning[1].$2, DateTime(2026, 9, 15, 19));
      expect(morning[2].$2, DateTime(2026, 9, 16, 9));
      final evening = WhenPresets.forNow(DateTime(2026, 9, 30, 18, 45));
      expect(evening.map((p) => p.$1), [WhenPreset.inOneHour, WhenPreset.tomorrowMorning]);
      expect(evening.last.$2, DateTime(2026, 10, 1, 9));
      final now = DateTime(2026, 9, 15, 12);
      expect(WhenPresets.isValid(now.subtract(const Duration(minutes: 1)), now), isFalse);
      expect(WhenPresets.isValid(now.add(const Duration(days: 400)), now), isFalse);
      expect(WhenPresets.isValid(now.add(const Duration(hours: 2)), now), isTrue);
    });

    test('local reminder fallback: pending future ones, same id as the push', () {
      final now = DateTime.utc(2026, 9, 15, 12);
      ChatReminder r(String id, DateTime at, {String status = 'pending'}) => ChatReminder(
        id: id,
        messageId: 'm-$id',
        conversationId: ChatFixtures.conv,
        remindAt: at,
        status: status,
      );
      final targets = localReminderTargets([
        r('a', now.add(const Duration(hours: 1))),
        r('b', now.subtract(const Duration(minutes: 1))),
        r('c', now.add(const Duration(hours: 2)), status: 'fired'),
      ], now);
      expect(targets.map((x) => x.id), ['a']);
      expect(chatReminderPayload(targets.single), contains('"conversation_id":"${ChatFixtures.conv}"'));
      final push = buildPushNotificationContent({
        'type': 'chat.reminder',
        'conversation_id': ChatFixtures.conv,
        'message_id': 'm-a',
        'reminder_id': 'a',
        'kind': 'reminder',
        'title': 'Напоминание',
        'body': 'Bob: Созвон',
      })!;
      expect(push.id, chatReminderNotificationId('a'));
      expect(push.channelId, chatRemindersChannelId);
      expect(push.body, 'Bob: Созвон');
      expect(push.payload, contains('"message_id":"m-a"'));
    });
  });

  group('api', () {
    late TestHarness h;

    setUp(() async {
      h = await TestHarness.create(storedToken: Fixtures.token, chatBaseUrl: 'http://chat.local/api/v1');
      h.adapter.onJson('GET', '/me', Fixtures.me());
      await h.session.restore();
    });
    tearDown(() => h.dispose());

    test('channels: discover with a query, subscribe, subscribers', () async {
      h.chatAdapter.onJson('GET', '/channels', {
        'channels': [
          {'id': 'ch1', 'title': 'Новости', 'subscriber_count': 3, 'subscribed': false, 'is_public': true},
        ],
        'has_more': false,
      });
      h.chatAdapter.onJson('POST', '/channels/ch1/subscription', {
        ...ChatFixtures.conversation(id: 'ch1', group: true, title: 'Новости', myRole: 'member'),
        'type': 'channel',
        'is_public': true,
      }, status: 201);
      h.chatAdapter.onJson('GET', '/channels/ch1/subscribers', {
        'subscribers': [ChatFixtures.member(ChatFixtures.me, 'Me', role: 'owner')],
        'total': 7,
      });
      final api = h.container.read(chatBroadcastApiProvider);
      final res = await api.listChannels(q: 'нов');
      expect(res.channels.single.subscriberCount, 3);
      expect(h.chatAdapter.of('GET', '/channels').single.query['q'], 'нов');
      final conv = await api.subscribe('ch1');
      expect(conv.isChannel, isTrue);
      final subs = await api.subscribers('ch1');
      expect(subs.total, 7);
      expect(subs.subscribers.single.role, 'owner');
    });

    test('scheduled: the notifier posts and reloads the list', () async {
      final items = <Map<String, dynamic>>[];
      h.chatAdapter.on('GET', '/chats/${ChatFixtures.conv}/scheduled', (_) => FakeResponse(200, json: {'scheduled': items}));
      h.chatAdapter.on('POST', '/chats/${ChatFixtures.conv}/scheduled', (req) {
        final item = {
          'id': 's1',
          'conversation_id': ChatFixtures.conv,
          'body': req.json['body'],
          'send_at': req.json['send_at'],
          'attachments': <Object>[],
          'status': 'pending',
        };
        items.add(item);
        return FakeResponse(201, json: item);
      });
      final provider = scheduledMessagesProvider(ChatFixtures.conv);
      final sub = h.container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      expect(await h.container.read(provider.future), isEmpty);
      final at = DateTime.utc(2026, 9, 16, 4);
      await h.container.read(provider.notifier).schedule(body: 'Отчёт', sendAt: at, attachmentIds: const ['a1']);
      final sent = h.chatAdapter.of('POST', '/chats/${ChatFixtures.conv}/scheduled').single.json;
      expect(sent['body'], 'Отчёт');
      expect(DateTime.parse(sent['send_at'] as String), at);
      expect(sent['attachment_ids'], ['a1']);
      final list = h.container.read(provider).value!;
      expect(list.single.body, 'Отчёт');
      expect(list.single.sendAt, at);
    });

    test('polls and reminders endpoints', () async {
      h.chatAdapter.onJson('POST', '/messages/p1/poll/votes', {'poll': pollJson(myVotes: [1], total: 1, votes: [0, 1])});
      h.chatAdapter.onJson('DELETE', '/messages/p1/poll/votes', {'poll': pollJson(total: 0)});
      h.chatAdapter.onJson('GET', '/messages/p1/poll/voters', {
        'voters': [
          {'user_id': ChatFixtures.peer, 'display_name': 'Bob', 'options': [1], 'voted_at': '2026-09-15T10:00:00Z'},
        ],
      });
      h.chatAdapter.on('POST', '/messages/m1/reminders', (req) => FakeResponse(201, json: {
        'id': 'r1',
        'message_id': 'm1',
        'conversation_id': ChatFixtures.conv,
        'remind_at': req.json['remind_at'],
        'status': 'pending',
        'conversation_title': 'Bob',
        'conversation_type': 'direct',
        'message': ChatFixtures.message(id: 'm1', seq: 1, body: 'Созвон'),
      }));
      final api = h.container.read(chatBroadcastApiProvider);
      expect((await api.vote('p1', [1])).myVotes, [1]);
      expect(h.chatAdapter.of('POST', '/messages/p1/poll/votes').single.json, {'options': [1]});
      expect((await api.retractVote('p1')).voted, isFalse);
      final voters = await api.pollVoters('p1', option: 1);
      expect(voters.single.displayName, 'Bob');
      expect(h.chatAdapter.of('GET', '/messages/p1/poll/voters').single.query['option'], '1');
      final r = await api.createReminder('m1', remindAt: DateTime.utc(2026, 9, 15, 15));
      expect(r.pending, isTrue);
      expect(r.message!.body, 'Созвон');
      expect(reminderPreviewTextForTest(r), 'Bob: Созвон');
    });
  });
}

/// [reminderPreviewText] needs localizations; the pure join is checked here.
String reminderPreviewTextForTest(ChatReminder r) =>
    [r.conversationTitle, r.message?.body ?? ''].where((s) => s.isNotEmpty).join(': ');
