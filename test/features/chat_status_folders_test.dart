import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/localization/generated/app_localizations.dart';
import 'package:xatbox_mobile/core/network/network_status.dart';
import 'package:xatbox_mobile/features/chat/data/chat_folders.dart';
import 'package:xatbox_mobile/features/chat/data/chat_models.dart';
import 'package:xatbox_mobile/features/chat/data/chat_repository.dart';
import 'package:xatbox_mobile/features/chat/data/chat_status.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_formatters.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_list_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/conversation_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/folders/chat_folders_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/folders/chat_folders_screen.dart';
import 'package:xatbox_mobile/features/contacts/presentation/contacts_screen.dart';
import 'package:xatbox_mobile/features/settings/my_status_sheet.dart';

import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Statuses with auto-reply and chat folders: models, folding, UI.
void main() {
  const conv = ChatFixtures.conv;
  const grp = 'c0000000-0000-4000-8000-000000000003';
  const channel = 'c0000000-0000-4000-8000-0000000000c1';

  ChatConversation convOf(Map<String, dynamic> j) => ChatConversation.fromJson(j);

  group('status model', () {
    test('parses, keeps the auto-reply for the own status and validates limits', () {
      final s = ChatUserStatus.fromJson({
        'preset': 'meeting',
        'emoji': '📅',
        'text': '',
        'until': '2026-09-15T15:00:00Z',
        'set_at': '2026-09-15T10:00:00Z',
        'auto_reply': 'Отвечу после 15:00',
      });
      expect(s.preset, ChatStatusPreset.meeting);
      expect(s.autoReply, 'Отвечу после 15:00');
      expect(s.toRequest(), {
        'preset': 'meeting',
        'emoji': '📅',
        'text': '',
        'until': '2026-09-15T15:00:00.000Z',
        'auto_reply': 'Отвечу после 15:00',
      });
      expect(ChatUserStatus.fromJsonOrNull(null), isNull);
      expect(ChatStatusPreset.parse('unknown'), ChatStatusPreset.custom);

      final now = DateTime.utc(2026, 9, 15, 12);
      expect(s.isActiveAt(now), isTrue);
      expect(s.isActiveAt(DateTime.utc(2026, 9, 15, 16)), isFalse);
      expect(s.validate(now), isNull);
      expect(const ChatUserStatus(preset: ChatStatusPreset.custom).validate(now), 'text');
      expect(ChatUserStatus(preset: ChatStatusPreset.sick, text: 'x' * 71).validate(now), 'text');
      expect(ChatUserStatus(preset: ChatStatusPreset.sick, autoReply: 'x' * 501).validate(now), 'auto_reply');
      expect(ChatUserStatus(preset: ChatStatusPreset.sick, until: now.subtract(const Duration(minutes: 1))).validate(now), 'until');
      expect(ChatUserStatus(preset: ChatStatusPreset.sick, until: now.add(const Duration(days: 400))).validate(now), 'until');
    });

    test('«До» presets: an hour, end of day, end of week (Sunday), picked', () {
      final wed = DateTime(2026, 9, 16, 10, 30); // Wednesday
      expect(ChatStatusDurations.resolve(ChatStatusUntil.none, wed), isNull);
      expect(ChatStatusDurations.resolve(ChatStatusUntil.hour, wed), DateTime(2026, 9, 16, 11, 30));
      expect(ChatStatusDurations.resolve(ChatStatusUntil.endOfDay, wed), DateTime(2026, 9, 16, 23, 59));
      expect(ChatStatusDurations.resolve(ChatStatusUntil.endOfWeek, wed), DateTime(2026, 9, 20, 23, 59));
      final sunday = DateTime(2026, 9, 20, 9);
      expect(ChatStatusDurations.resolve(ChatStatusUntil.endOfWeek, sunday), DateTime(2026, 9, 20, 23, 59));
      final picked = DateTime(2026, 10, 1, 9);
      expect(ChatStatusDurations.resolve(ChatStatusUntil.custom, wed, picked: picked), picked);
    });

    test('peer, members and contacts carry the public status; presence_hidden', () {
      final c = convOf({
        ...ChatFixtures.conversation(),
        'peer': {
          ...ChatFixtures.user(),
          'presence_hidden': true,
          'status': {'preset': 'vacation', 'emoji': '🌴', 'text': ''},
        },
      });
      expect(c.peer!.status!.preset, ChatStatusPreset.vacation);
      expect(c.peer!.presenceHidden, isTrue);
      final back = ChatConversation.fromJson(c.toJson());
      expect(back.peer!.status, c.peer!.status);
      expect(back.peer!.presenceHidden, isTrue);
    });

    test('user.status fold: peer and members get the status, cleared by null', () {
      final c = convOf({
        ...ChatFixtures.conversation(group: true, members: [
          ChatFixtures.member(ChatFixtures.me, 'Me'),
          ChatFixtures.member(ChatFixtures.peer, 'Bob'),
        ]),
      });
      const status = ChatUserStatus(preset: ChatStatusPreset.inClass, emoji: '📚');
      final withStatus = ChatRepository.applyUserToConversation(c, ChatFixtures.peer, status: (status,));
      expect(withStatus.members.firstWhere((m) => m.userId == ChatFixtures.peer).status, status);
      expect(withStatus.members.firstWhere((m) => m.userId == ChatFixtures.me).status, isNull);
      final cleared = ChatRepository.applyUserToConversation(withStatus, ChatFixtures.peer, status: (null,));
      expect(cleared.members.firstWhere((m) => m.userId == ChatFixtures.peer).status, isNull);
      expect(identical(ChatRepository.applyUserToConversation(c, 'someone-else', status: (status,)), c), isTrue);

      final direct = convOf(ChatFixtures.conversation());
      final online = ChatRepository.applyUserToConversation(direct, ChatFixtures.peer, online: true, status: (status,));
      expect(online.peer!.online, isTrue);
      expect(online.peer!.status, status);
      // Presence without a status keeps the known status.
      final offline = ChatRepository.applyUserToConversation(online, ChatFixtures.peer, online: false);
      expect(offline.peer!.status, status);
    });

    test('auto_reply is a service message with a localized preview', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      final m = ChatMessage.fromJson(
        ChatFixtures.message(id: 'a1', seq: 3, type: 'auto_reply', body: 'Я в отпуске до понедельника'),
      );
      expect(m.isAutoReply, isTrue);
      expect(m.isServiceLike, isTrue);
      expect(ChatFormat.preview(l10n, m), 'Автоответ: Я в отпуске до понедельника');
    });
  });

  group('folder rules', () {
    final now = DateTime.utc(2026, 9, 15, 12);
    ChatConversation c(String id, String type, {int unread = 0, bool marked = false, DateTime? mutedUntil}) =>
        convOf({
          ...ChatFixtures.conversation(id: id, unread: unread),
          'type': type,
          'settings': {
            'marked_unread': marked,
            'muted_until': ?mutedUntil?.toIso8601String(),
          },
        });

    test('id or type, the saved chat only by id, unread only, exclude muted', () {
      const byType = ChatFolder(id: 'f', name: 'Работа', types: ['group', 'saved']);
      expect(byType.matches(c('g', 'group'), now), isTrue);
      expect(byType.matches(c('d', 'direct'), now), isFalse);
      expect(byType.matches(c('s', 'saved'), now), isFalse, reason: 'saved only explicitly');
      expect(const ChatFolder(id: 'f', name: 'x', chatIds: ['s']).matches(c('s', 'saved'), now), isTrue);
      expect(const ChatFolder(id: 'f', name: 'x', chatIds: ['d']).matches(c('d', 'direct'), now), isTrue);

      const unread = ChatFolder(id: 'f', name: 'x', types: ['direct'], unreadOnly: true);
      expect(unread.matches(c('d', 'direct'), now), isFalse);
      expect(unread.matches(c('d', 'direct', unread: 2), now), isTrue);
      expect(unread.matches(c('d', 'direct', marked: true), now), isTrue);

      const muted = ChatFolder(id: 'f', name: 'x', types: ['channel'], excludeMuted: true);
      expect(muted.matches(c('ch', 'channel', mutedUntil: now.add(const Duration(hours: 1))), now), isFalse);
      expect(muted.matches(c('ch', 'channel', mutedUntil: now.subtract(const Duration(hours: 1))), now), isTrue);
    });

    test('validation and JSON', () {
      expect(const ChatFolder(id: 'f', name: '', types: ['group']).validate(), 'name');
      expect(ChatFolder(id: 'f', name: 'x' * 33, types: const ['group']).validate(), 'name');
      expect(const ChatFolder(id: 'f', name: 'Работа').validate(), 'empty');
      expect(ChatFolder(id: 'f', name: 'x', chatIds: List.generate(201, (i) => '$i')).validate(), 'chats');
      const f = ChatFolder(id: 'f1', name: 'Работа', emoji: '💼', chatIds: ['a'], types: ['group'], unreadOnly: true);
      expect(f.validate(), isNull);
      expect(ChatFolder.fromJson(f.toJson()), f);
    });

    test('tabs: built-in filters, folders, unread counters, deleted folder falls back', () {
      final list = [
        c(conv, 'direct', unread: 2),
        c(grp, 'group'),
        c(channel, 'channel', unread: 1),
      ];
      const folders = [ChatFolder(id: 'f1', name: 'Работа', types: ['group'], chatIds: [conv])];
      expect(ChatListTabs.unreadChats(ChatListTabs.all, list, folders, now), 2);
      expect(ChatListTabs.unreadChats(ChatListTabs.channels, list, folders, now), 1);
      expect(ChatListTabs.unreadChats(ChatListTabs.folder('f1'), list, folders, now), 1);
      expect(
        list.where((x) => ChatListTabs.matches(ChatListTabs.folder('f1'), x, folders, now)).map((x) => x.id),
        [conv, grp],
      );
      expect(ChatListTabs.effective(ChatListTabs.folder('gone'), folders), ChatListTabs.all);
      expect(ChatListTabs.effective(ChatListTabs.unread, folders), ChatListTabs.unread);
    });
  });

  group('widgets', () {
    late TestHarness h;
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('xatbox_status');
    });

    tearDown(() async {
      await h.dispose();
      try {
        tmp.deleteSync(recursive: true);
      } on FileSystemException {
        // cleaned later
      }
    });

    Future<void> prepare() async {
      const recordChannel = MethodChannel('com.llfbandit.record/messages');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(recordChannel, (_) async => null);
      addTearDown(() => messenger.setMockMethodCallHandler(recordChannel, null));
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
      h.chatAdapter.onJson('GET', '/me/chat-folders', {'folders': [], 'updated_at': null});
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

    Widget opener(Future<void> Function(BuildContext) open) => Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: FilledButton(key: const Key('open'), onPressed: () => open(context), child: const Text('open')),
        ),
      ),
    );

    testWidgets('status sheet: preset, «До», auto-reply → PUT body; 360 dp / 130 % guidelines', (tester) async {
      usePhone(tester);
      await prepare();
      h.chatAdapter.on('PUT', '/me/status', (req) => FakeResponse(200, json: {
        'status': {...req.json, 'set_at': '2026-09-15T10:00:00Z'},
      }));
      await signIn(tester);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(wrapWidget(opener(showMyStatusSheet), container: h.container));
      await tester.tap(find.byKey(const Key('open')));
      await settle(tester, 8);

      expect(find.byKey(const Key('my_status_sheet')), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('status_save'))).onPressed, isNull,
          reason: 'nothing chosen yet');
      await tester.tap(find.byKey(const Key('status_preset_dnd')));
      await settle(tester, 2);
      expect(find.byKey(const Key('status_dnd_hint')), findsOneWidget);
      await tester.tap(find.byKey(const Key('status_preset_meeting')));
      await settle(tester, 2);
      await expectGuidelines(tester);

      await tester.ensureVisible(find.byKey(const Key('status_until_hour')));
      await tester.tap(find.byKey(const Key('status_until_hour')));
      await tester.enterText(find.byKey(const Key('status_auto_reply')), 'Отвечу после совещания');
      await settle(tester, 2);
      await tester.ensureVisible(find.byKey(const Key('status_save')));
      await tester.tap(find.byKey(const Key('status_save')));
      await settle(tester, 8);

      final body = h.chatAdapter.of('PUT', '/me/status').single.json;
      expect(body['preset'], 'meeting');
      expect(body['emoji'], '📅');
      expect(body['text'], '');
      expect(body['auto_reply'], 'Отвечу после совещания');
      final until = DateTime.parse(body['until'] as String);
      expect(until.difference(DateTime.now()).inMinutes, inInclusiveRange(58, 60));
      expect(find.byKey(const Key('my_status_sheet')), findsNothing);
      expect(find.text('Статус установлен'), findsOneWidget);
      semantics.dispose();
      await finish(tester);
    });

    testWidgets('status sheet: custom needs text or emoji; «Сбросить статус» sends DELETE', (tester) async {
      usePhone(tester, textScale: 1);
      await prepare();
      h.chatAdapter.onJson('GET', '/me/status', {
        'status': {'preset': 'vacation', 'emoji': '🌴', 'text': 'До понедельника', 'auto_reply': 'Я в отпуске'},
      });
      h.chatAdapter.on('DELETE', '/me/status', (_) => const FakeResponse(204));
      await signIn(tester);
      await tester.pumpWidget(wrapWidget(opener(showMyStatusSheet), container: h.container));
      await tester.tap(find.byKey(const Key('open')));
      await settle(tester, 10);

      expect(find.widgetWithText(TextField, 'До понедельника'), findsOneWidget, reason: 'prefilled');
      expect(find.widgetWithText(TextField, 'Я в отпуске'), findsOneWidget);
      await tester.tap(find.byKey(const Key('status_preset_custom')));
      await tester.enterText(find.byKey(const Key('status_text')), '');
      await settle(tester, 2);
      await tester.ensureVisible(find.byKey(const Key('status_save')));
      await tester.tap(find.byKey(const Key('status_save')));
      await settle(tester, 4);
      expect(find.byKey(const Key('status_error')), findsOneWidget);
      expect(h.chatAdapter.of('PUT', '/me/status'), isEmpty);

      await tester.ensureVisible(find.byKey(const Key('status_clear')));
      await tester.tap(find.byKey(const Key('status_clear')));
      await settle(tester, 8);
      expect(h.chatAdapter.of('DELETE', '/me/status'), hasLength(1));
      expect(find.text('Статус сброшен'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('1:1 header shows the peer status; user.status frames update it; auto-reply pill', (tester) async {
      usePhone(tester, textScale: 1);
      await prepare();
      final direct = {
        ...ChatFixtures.conversation(lastSeq: 2),
        'peer': {
          ...ChatFixtures.user(online: true),
          'status': {'preset': 'meeting', 'emoji': '📅', 'text': ''},
        },
      };
      h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats([direct]));
      h.chatAdapter.onJson('GET', '/chats/$conv', direct);
      h.chatAdapter.onJson('GET', '/chats/$conv/messages', ChatFixtures.messages([
        ChatFixtures.message(id: 'm1', seq: 1, sender: ChatFixtures.me, body: 'Вы свободны?'),
        ChatFixtures.message(id: 'm2', seq: 2, type: 'auto_reply', body: 'Я на совещании до 15:00'),
      ]));
      await signIn(tester);
      h.container.read(chatLifecycleProvider);
      await tester.pumpWidget(wrapWidget(const ConversationScreen(conversationId: conv), container: h.container));
      await settle(tester, 16);

      expect(find.text('📅 На совещании'), findsOneWidget, reason: 'status instead of «в сети»');
      expect(find.text('Автоответ: Я на совещании до 15:00'), findsOneWidget);
      expect(tester.takeException(), isNull);

      h.socketFactory.last.serverSend({
        'type': 'user.status',
        'user_id': ChatFixtures.peer,
        'status': {'preset': 'vacation', 'emoji': '🌴', 'text': 'До 20 сентября'},
      });
      await settle(tester, 8);
      expect(find.text('🌴 До 20 сентября'), findsOneWidget);
      final cached = await tester.runAsync(() => h.container.read(chatRepositoryProvider).cache.conversation(conv));
      expect(cached!.peer!.status!.preset, ChatStatusPreset.vacation);

      // Typing keeps priority over the status.
      h.socketFactory.last.serverSend({
        'type': 'typing.started',
        'conversation_id': conv,
        'user_id': ChatFixtures.peer,
        'display_name': 'Bob',
      });
      await settle(tester, 4);
      expect(find.textContaining('печатает'), findsOneWidget);
      // Let the subtitle cross-fade finish.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('🌴 До 20 сентября'), findsNothing);

      h.socketFactory.last.serverSend({'type': 'typing.stopped', 'conversation_id': conv, 'user_id': ChatFixtures.peer});
      h.socketFactory.last.serverSend({'type': 'user.status', 'user_id': ChatFixtures.peer, 'status': null});
      await settle(tester, 8);
      expect(find.textContaining('До 20 сентября'), findsNothing);
      expect(find.text('в сети'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('contacts show statuses and follow user.status frames', (tester) async {
      usePhone(tester);
      await prepare();
      h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats(const []));
      h.chatAdapter.onJson('GET', '/users', {
        'users': [
          {...ChatFixtures.user(name: 'Болат Сейтов'), 'status': {'preset': 'in_class', 'emoji': '📚', 'text': ''}},
          ChatFixtures.user(id: 'u-alia', name: 'Алия Нурланова'),
        ],
      });
      await signIn(tester);
      h.container.read(chatLifecycleProvider);
      await tester.pumpWidget(wrapWidget(const ContactsScreen(), container: h.container));
      await settle(tester, 12);
      expect(find.textContaining('📚 На паре'), findsOneWidget);
      expect(tester.takeException(), isNull);

      h.socketFactory.last.serverSend({
        'type': 'user.status',
        'user_id': 'u-alia',
        'status': {'preset': 'sick', 'emoji': '🤒', 'text': ''},
      });
      await settle(tester, 6);
      expect(find.textContaining('🤒 Болею'), findsOneWidget);
      await finish(tester);
    });

    Map<String, dynamic> listConv(String id, String type, {int unread = 0, String? title}) => {
      ...ChatFixtures.conversation(id: id, unread: unread, title: title ?? id, group: type != 'direct'),
      'type': type,
    };

    testWidgets('folder tabs: built-ins then folders with unread counters; a folder filters', (tester) async {
      usePhone(tester, textScale: 1);
      await prepare();
      h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats([
        listConv(conv, 'direct', unread: 2, title: 'Bob'),
        listConv(grp, 'group', title: 'Кафедра'),
        listConv(channel, 'channel', unread: 1, title: 'Новости'),
      ]));
      h.chatAdapter.onJson('GET', '/me/chat-folders', {
        'folders': [
          {'id': 'f1', 'name': 'Работа', 'emoji': '💼', 'chat_ids': [conv], 'types': ['group'], 'unread_only': false, 'exclude_muted': false},
          {'id': 'f2', 'name': 'Важное', 'emoji': '', 'chat_ids': [], 'types': ['direct', 'group', 'channel'], 'unread_only': true, 'exclude_muted': false},
        ],
        'updated_at': '2026-09-15T10:00:00Z',
      });
      await signIn(tester);
      await tester.pumpWidget(wrapWidget(const ChatListScreen(), container: h.container));
      await settle(tester, 14);

      final tabRow = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
      );
      // Built-in tabs first (the rest of the row scrolls at 360 dp).
      expect(find.byKey(const Key('chat_filter_all')), findsOneWidget);
      expect(find.byKey(const Key('chat_filter_unread')), findsOneWidget);
      final work = find.byKey(const ValueKey('chat_folder_f1'));
      await tester.scrollUntilVisible(work, 80,
          scrollable: tabRow);
      expect(find.descendant(of: work, matching: find.text('💼 Работа')), findsOneWidget);
      expect(find.descendant(of: work, matching: find.text('1')), findsOneWidget, reason: 'Bob is unread');
      await tester.ensureVisible(work);
      await tester.pump();
      await tester.tap(work);
      await settle(tester, 4);
      expect(find.byKey(const ValueKey('chat_$conv')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat_$grp')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat_$channel')), findsNothing);

      final important = find.byKey(const ValueKey('chat_folder_f2'));
      await tester.scrollUntilVisible(important, 80,
          scrollable: tabRow);
      expect(find.descendant(of: important, matching: find.text('2')), findsOneWidget);
      await tester.ensureVisible(important);
      await tester.pump();
      await tester.tap(important);
      await settle(tester, 4);
      expect(find.byKey(const ValueKey('chat_$grp')), findsNothing, reason: 'unread only');
      expect(find.byKey(const ValueKey('chat_$channel')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finish(tester);
    });

    testWidgets('«Папки чатов»: create in the editor, PUT body, limit of 10; guidelines', (tester) async {
      usePhone(tester);
      await prepare();
      h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats([
        listConv(conv, 'direct', title: 'Bob'),
        listConv(grp, 'group', title: 'Кафедра'),
      ]));
      h.chatAdapter.on('PUT', '/me/chat-folders', (req) => FakeResponse(200, json: {
        'folders': req.json['folders'],
        'updated_at': '2026-09-15T11:00:00Z',
      }));
      await signIn(tester);
      h.container.read(conversationsProvider);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(wrapWidget(const ChatFoldersScreen(), container: h.container));
      await settle(tester, 10);
      expect(find.text('Соберите рабочие чаты, группы или каналы в отдельную вкладку'), findsOneWidget);

      await tester.tap(find.byKey(const Key('folders_add')));
      await settle(tester, 8);
      await tester.tap(find.byKey(const Key('folder_save')));
      await settle(tester, 2);
      expect(find.byKey(const Key('folder_error')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('folder_name')), 'Работа');
      await tester.tap(find.byKey(const Key('folder_save')));
      await settle(tester, 2);
      expect(find.text('Добавьте чаты или выберите тип чатов'), findsOneWidget);
      await tester.tap(find.byKey(const Key('folder_type_group')));
      await tester.ensureVisible(find.byKey(const ValueKey('folder_chat_$conv')));
      await tester.tap(find.byKey(const ValueKey('folder_chat_$conv')));
      await settle(tester, 2);
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester, 2);
      await expectGuidelines(tester);
      await tester.tap(find.byKey(const Key('folder_save')));
      await settle(tester, 10);

      final sent = h.chatAdapter.of('PUT', '/me/chat-folders').single.json['folders'] as List;
      final folder = (sent.single as Map).cast<String, dynamic>();
      expect(folder['name'], 'Работа');
      expect(folder['types'], ['group']);
      expect(folder['chat_ids'], [conv]);
      expect(folder['id'], isNotEmpty);
      expect(find.byKey(ValueKey('folder_tile_${folder['id']}')), findsOneWidget);
      await expectGuidelines(tester);
      semantics.dispose();

      // Ten folders: «Новая папка» is disabled with the limit hint.
      await tester.runAsync(() async {
        final n = h.container.read(chatFoldersProvider.notifier);
        for (var i = 1; i < ChatFolder.maxFolders; i++) {
          await n.upsert(ChatFolder(id: 'x$i', name: 'Папка $i', types: const ['direct']));
        }
        expect(await n.upsert(const ChatFolder(id: 'x11', name: 'Лишняя', types: ['direct'])), isFalse);
      });
      await settle(tester, 6);
      expect(h.container.read(chatFoldersProvider).folders, hasLength(10));
      expect(tester.widget<FilledButton>(find.byKey(const Key('folders_add'))).onPressed, isNull);
      expect(find.byKey(const Key('folders_limit')), findsOneWidget);
      await finish(tester);
    });

    testWidgets('folders: reorder moves and sends; other devices update; offline stays pending', (tester) async {
      await prepare();
      var offline = true;
      h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats(const []));
      h.chatAdapter.onJson('GET', '/me/chat-folders', {
        'folders': [
          {'id': 'a', 'name': 'A', 'types': ['group']},
          {'id': 'b', 'name': 'B', 'types': ['direct']},
        ],
      });
      h.chatAdapter.on('PUT', '/me/chat-folders', (req) {
        if (offline) throw const SocketException('offline');
        return FakeResponse(200, json: {'folders': req.json['folders']});
      });
      await signIn(tester);
      h.container.read(chatLifecycleProvider);
      final sub = h.container.listen(chatFoldersProvider, (_, _) {});
      addTearDown(sub.close);
      await settle(tester, 8);
      final n = h.container.read(chatFoldersProvider.notifier);

      await tester.runAsync(() => n.move(1, 0));
      expect(h.container.read(chatFoldersProvider).folders.map((f) => f.id), ['b', 'a']);
      expect(h.container.read(chatFoldersProvider).sync, ChatFoldersSync.pending);
      // A frame from another device does not overwrite a pending change.
      h.socketFactory.last.serverSend({'type': 'chat_folders.updated', 'folders': [{'id': 'z', 'name': 'Z', 'types': ['group']}]});
      await settle(tester, 4);
      expect(h.container.read(chatFoldersProvider).folders.map((f) => f.id), ['b', 'a']);

      offline = false;
      await tester.runAsync(n.sync);
      expect(h.container.read(chatFoldersProvider).sync, ChatFoldersSync.synced);
      final order = (h.chatAdapter.of('PUT', '/me/chat-folders').last.json['folders'] as List).map((f) => (f as Map)['id']);
      expect(order, ['b', 'a']);

      h.socketFactory.last.serverSend({'type': 'chat_folders.updated', 'folders': [{'id': 'z', 'name': 'Z', 'types': ['group']}]});
      await settle(tester, 4);
      expect(h.container.read(chatFoldersProvider).folders.map((f) => f.id), ['z']);
      await finish(tester);
    });

    testWidgets('long press a chat → «Добавить в папку» toggles chat_ids', (tester) async {
      usePhone(tester, textScale: 1);
      await prepare();
      h.chatAdapter.onJson('GET', '/chats', ChatFixtures.chats([listConv(conv, 'direct', title: 'Bob')]));
      h.chatAdapter.onJson('GET', '/me/chat-folders', {
        'folders': [
          {'id': 'f1', 'name': 'Работа', 'emoji': '💼', 'chat_ids': [], 'types': ['group']},
        ],
      });
      h.chatAdapter.on('PUT', '/me/chat-folders', (req) => FakeResponse(200, json: {'folders': req.json['folders']}));
      await signIn(tester);
      await tester.pumpWidget(wrapWidget(const ChatListScreen(), container: h.container));
      await settle(tester, 12);

      await tester.longPress(find.byKey(const ValueKey('chat_$conv')));
      await settle(tester, 6);
      await tester.tap(find.byKey(const Key('chat_action_add_to_folder')));
      await settle(tester, 8);
      expect(find.byKey(const Key('add_to_folder_sheet')), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('add_to_folder_f1'))).value, isFalse);
      await tester.tap(find.byKey(const ValueKey('add_to_folder_f1')));
      await settle(tester, 8);
      final folders = h.chatAdapter.of('PUT', '/me/chat-folders').single.json['folders'] as List;
      expect((folders.single as Map)['chat_ids'], [conv]);
      expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('add_to_folder_f1'))).value, isTrue);
      expect(find.byKey(const Key('add_to_folder_new')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finish(tester);
    });
  });
}
