import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/localization/generated/app_localizations.dart';
import 'package:xatbox_mobile/features/chat/data/chat_messenger2.dart';
import 'package:xatbox_mobile/features/chat/data/chat_models.dart';
import 'package:xatbox_mobile/features/chat/data/chat_repository.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_formatters.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/conversation_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/messenger2_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/moderation/moderation_screens.dart';
import 'package:xatbox_mobile/features/chat/presentation/protected/chat_protection.dart';

import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Messenger part 2: protected chats, disappearing messages, stickers, voice
/// transcripts, reports and moderation.
void main() {
  const conv = ChatFixtures.conv;
  const s1 = '5a000000-0000-4000-8000-000000000001';
  const s2 = '5a000000-0000-4000-8000-000000000002';

  group('models', () {
    test('protection is parsed, round-tripped and drives the shield', () {
      final c = ChatConversation.fromJson({
        ...ChatFixtures.conversation(),
        'protection': {
          'no_forward': true,
          'screenshot_protection': false,
          'disappearing_ttl': 86400,
        },
      });
      expect(c.protection.noForward, isTrue);
      expect(c.protection.disappearingTtl, 86400);
      expect(c.protection.active, isTrue);
      final again = ChatConversation.fromJson(c.toJson());
      expect(again.protection, c.protection);
      expect(ChatConversation.fromJson(ChatFixtures.conversation()).protection.active, isFalse);
      expect(canEditProtection(c), isTrue, reason: 'either member of a 1:1 chat');
      final member = ChatConversation.fromJson({
        ...ChatFixtures.conversation(group: true, myRole: 'member'),
      });
      expect(canEditProtection(member), isFalse);
    });

    test('messages carry expiry, sticker and transcript', () {
      final m = ChatMessage.fromJson({
        ...ChatFixtures.message(id: 'm1', seq: 1, type: 'sticker', body: '{"sticker_id":"$s1"}'),
        'expires_at': '2026-09-20T10:00:00Z',
        'sticker': {'id': s1, 'pack_id': 'p', 'emoji': '👍', 'width': 512, 'height': 512},
        'transcript': {'status': 'done', 'text': 'Привет'},
      });
      expect(m.isSticker, isTrue);
      expect(m.sticker!.emoji, '👍');
      expect(m.transcript!.done, isTrue);
      expect(m.isExpiredAt(DateTime.utc(2026, 9, 21)), isTrue);
      expect(m.isExpiredAt(DateTime.utc(2026, 9, 19)), isFalse);
      final back = ChatMessage.fromJson(m.toJson());
      expect(back.expiresAt, m.expiresAt);
      expect(back.sticker!.id, s1);
      expect(back.transcript!.text, 'Привет');
      expect(m.copyWith(clearTranscript: true).transcript, isNull);
      expect(ChatSticker.idFromBody('{"sticker_id":"${s1.toUpperCase()}"}'), s1);
      expect(ChatSticker.idFromBody('hello'), isNull);
    });

    test('expired messages are filtered and the next expiry is found', () {
      final now = DateTime.utc(2026, 9, 15, 12);
      ChatMessage msg(String id, int seq, String? expires, {bool deleted = false}) =>
          ChatMessage.fromJson({
            ...ChatFixtures.message(id: id, seq: seq),
            'expires_at': ?expires,
            if (deleted) 'deleted_at': '2026-09-15T11:00:00Z',
          });
      final plain = [msg('a', 1, null), msg('b', 2, null)];
      expect(identical(withoutExpired(plain, now), plain), isTrue);
      final list = [
        msg('a', 1, null),
        msg('b', 2, '2026-09-15T11:00:00Z'),
        msg('c', 3, '2026-09-16T12:00:00Z', deleted: true),
        msg('d', 4, '2026-09-15T13:00:00Z'),
        msg('e', 5, '2026-09-15T12:30:00Z'),
      ];
      expect(withoutExpired(list, now).map((m) => m.id), ['a', 'd', 'e']);
      expect(nextExpiry(list, now), DateTime.utc(2026, 9, 15, 12, 30));
      expect(nextExpiry(plain, now), isNull);
    });

    test('message.transcript folds into the message', () {
      final m = ChatMessage.fromJson(ChatFixtures.message(id: 'm1', seq: 1, type: 'voice'));
      final next = ChatRepository.applyToMessage(
        m,
        const ChatEvent(
          type: 'message.transcript',
          conversationId: conv,
          seq: 5,
          payload: {
            'message_id': 'm1',
            'transcript': {'status': 'done', 'text': 'Добрый день'},
          },
        ),
        ChatFixtures.me,
      );
      expect(next!.transcript!.text, 'Добрый день');
    });

    test('reports, features and labels', () {
      final r = ChatReport.fromJson({
        'id': 'r1',
        'conversation_id': conv,
        'conversation_type': 'group',
        'message_id': 'm1',
        'reason': 'confidential',
        'status': 'resolved',
        'resolution': 'mute',
        'snapshot': {'type': 'text', 'body': 'пароль', 'attachments': ['a.pdf']},
        'context': [ChatFixtures.message(id: 'm1', seq: 1)],
        'reported_is_member': true,
      });
      expect(r.reason, ChatReportReason.confidential);
      expect(r.resolution, ModerationAction.mute);
      expect(r.isOpen, isFalse);
      expect(r.isGroupLike, isTrue);
      expect(r.snapshotAttachments, ['a.pdf']);
      expect(r.context, hasLength(1));
      final f = ChatFeatures.fromJson({'transcription': true, 'moderation': true});
      expect(f.transcription && f.moderation && !f.moderationGlobal, isTrue);

      final ru = lookupAppLocalizations(const Locale('ru'));
      expect(disappearingLabel(ru, 604800), '1 неделя');
      expect(disappearingLabel(ru, 0), 'Выкл.');
      final sys = ChatMessage.fromJson(
        ChatFixtures.message(id: 's', seq: 3, type: 'system', body: 'protection_changed', sender: ChatFixtures.peer),
      );
      expect(
        ChatFormat.systemText(ru, sys, names: const {ChatFixtures.peer: 'Bob'}),
        'Bob изменил(а) настройки защиты чата',
      );
      final sticker = ChatMessage.fromJson({
        ...ChatFixtures.message(id: 'x', seq: 4, type: 'sticker', body: '{"sticker_id":"$s1"}'),
        'sticker': {'id': s1, 'emoji': '🎓'},
      });
      expect(ChatFormat.preview(ru, sticker), '🎓 Стикер');
    });
  });

  group('widgets', () {
    late TestHarness h;
    late Directory tmp;

    Future<void> prepare({List<Map<String, dynamic>> packs = const []}) async {
      const recordChannel = MethodChannel('com.llfbandit.record/messages');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(recordChannel, (_) async => null);
      addTearDown(() => messenger.setMockMethodCallHandler(recordChannel, null));
      tmp = Directory.systemTemp.createTempSync('xatbox_messenger2');
      h = await TestHarness.create(
        storedToken: Fixtures.token,
        chatBaseUrl: 'http://chat.local/api/v1',
        overrides: [chatMediaRootProvider.overrideWithValue(() async => tmp)],
      );
      h.adapter.onJson('GET', '/me', Fixtures.me());
      h.chatAdapter.onPattern('POST', r'^/messages/[^/]+/read$', (_) => const FakeResponse(204));
      h.chatAdapter.onJson('GET', '/features', {
        'transcription': true,
        'stickers': true,
        'reports': true,
        'protected_chats': true,
        'moderation': true,
      });
      h.chatAdapter.onJson('GET', '/sticker-packs', {'packs': packs});
    }

    tearDown(() async {
      await h.dispose();
      try {
        tmp.deleteSync(recursive: true);
      } on FileSystemException {
        // cleaned later by the OS
      }
    });

    Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
      for (var i = 0; i < rounds; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

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

    Future<void> openConversation(WidgetTester tester) async {
      await tester.runAsync(() => h.session.restore());
      await tester.pumpWidget(
        wrapWidget(const ConversationScreen(conversationId: conv), container: h.container),
      );
      await settle(tester, 14);
    }

    testWidgets('protected chat: shield, no copy/forward/save, report is sent', (tester) async {
      useSize(tester);
      await prepare();
      stubConversation(
        {
          ...ChatFixtures.conversation(lastSeq: 1),
          'protection': {'no_forward': true, 'screenshot_protection': true, 'disappearing_ttl': 0},
        },
        [ChatFixtures.message(id: 'm1', seq: 1, body: 'Секретный текст')],
      );
      h.chatAdapter.on(
        'POST',
        '/messages/m1/report',
        (_) => const FakeResponse(201, json: {'report': {'id': 'r1', 'status': 'open'}}),
      );
      await openConversation(tester);

      expect(find.byKey(const Key('chat_protection_shield')), findsOneWidget);
      await tester.longPress(find.text('Секретный текст'));
      await settle(tester, 6);
      expect(find.byKey(const Key('message_save_to_saved')), findsNothing);
      expect(find.text('Копировать'), findsNothing);
      expect(find.text('Переслать'), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('message_report')));
      await tester.tap(find.byKey(const Key('message_report')));
      await settle(tester, 6);

      expect(find.byKey(const Key('report_sheet')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('report_reason_confidential')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('report_comment')), 'пароль в чате');
      await tester.ensureVisible(find.byKey(const Key('report_send')));
      await tester.tap(find.byKey(const Key('report_send')));
      await settle(tester, 8);
      final sent = h.chatAdapter.of('POST', '/messages/m1/report').single.json;
      expect(sent, {'reason': 'confidential', 'comment': 'пароль в чате'});
      expect(find.text('Жалоба отправлена. Модераторы её рассмотрят.'), findsOneWidget);

      // The shield sheet explains what is on.
      await tester.tap(find.byKey(const Key('chat_protection_shield')));
      await settle(tester, 6);
      expect(find.byKey(const Key('chat_protection_sheet')), findsOneWidget);
      expect(find.text('Защита от скриншотов'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finish(tester);
    });

    testWidgets('protection sheet changes no_forward through PUT', (tester) async {
      useSize(tester);
      await prepare();
      final c = ChatFixtures.conversation(lastSeq: 1);
      stubConversation(c, [ChatFixtures.message(id: 'm1', seq: 1)]);
      h.chatAdapter.on('PUT', '/chats/$conv/protection', (req) => FakeResponse(
        200,
        json: {
          ...c,
          'protection': {'no_forward': req.json['no_forward'] == true, 'screenshot_protection': false, 'disappearing_ttl': 0},
        },
      ));
      await openConversation(tester);
      await tester.tap(find.byKey(const Key('chat_search_open')));
      await tester.pump();
      await tester.tap(find.byTooltip('Закрыть').first);
      await tester.pump();
      final ctx = tester.element(find.byType(ConversationScreen));
      ChatProtectionSheet.show(ctx, conv);
      await settle(tester, 6);
      await tester.tap(find.descendant(of: find.byKey(const Key('protection_no_forward')), matching: find.byType(Switch)));
      await settle(tester, 10);
      expect(h.chatAdapter.of('PUT', '/chats/$conv/protection').single.json, {'no_forward': true});
      final cached = await tester.runAsync(() => h.container.read(chatCacheProvider).conversation(conv));
      expect(cached!.protection.noForward, isTrue);
      expect(tester.takeException(), isNull);
      await finish(tester);
    });

    testWidgets('360 px: sticker without bubble, disappearing timer, expired hidden, transcripts', (tester) async {
      useSize(tester);
      await prepare();
      final voice = ChatFixtures.attachment(
        id: 'a2', kind: 'voice', filename: 'voice.m4a', mimeType: 'audio/mp4', hasThumbnail: false, durationMs: 4000,
      );
      final voice3 = ChatFixtures.attachment(
        id: 'a3', kind: 'voice', filename: 'voice.m4a', mimeType: 'audio/mp4', hasThumbnail: false, durationMs: 4000,
      );
      stubConversation(ChatFixtures.conversation(lastSeq: 5), [
        {
          ...ChatFixtures.message(id: 'm1', seq: 1, type: 'sticker', body: '{"sticker_id":"$s1"}'),
          'sticker': {'id': s1, 'emoji': '🎓', 'width': 512, 'height': 512},
          'expires_at': '2099-01-01T00:00:00Z',
        },
        {...ChatFixtures.message(id: 'm2', seq: 2, type: 'voice', body: '', attachments: [voice])},
        {
          ...ChatFixtures.message(id: 'm3', seq: 3, type: 'voice', body: '', attachments: [voice3]),
          'transcript': {'status': 'done', 'text': 'Пара переносится на завтра'},
        },
        {...ChatFixtures.message(id: 'm4', seq: 4, body: 'Уже исчезло'), 'expires_at': '2020-01-01T00:00:00Z'},
        ChatFixtures.message(id: 'm5', seq: 5, body: 'Обычное'),
      ]);
      h.chatAdapter.on(
        'POST',
        '/messages/m2/transcribe',
        (_) => const FakeResponse(200, json: {'transcript': {'status': 'done', 'text': 'Сәлем, әріптестер'}}),
      );
      await openConversation(tester);

      expect(find.byKey(const ValueKey('sticker_message_m1')), findsOneWidget);
      expect(find.byKey(const ValueKey('disappearing_m1')), findsOneWidget);
      expect(find.text('Уже исчезло'), findsNothing);
      expect(find.text('Обычное'), findsOneWidget);

      expect(find.text('Пара переносится на завтра'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('voice_transcript_toggle_m3')));
      await settle(tester, 4);
      expect(find.text('Пара переносится на завтра'), findsNothing);

      await tester.ensureVisible(find.byKey(const ValueKey('voice_transcribe_m2')));
      await tester.tap(find.byKey(const ValueKey('voice_transcribe_m2')));
      await settle(tester, 8);
      expect(h.chatAdapter.of('POST', '/messages/m2/transcribe'), hasLength(1));
      expect(find.text('Сәлем, әріптестер'), findsOneWidget);
      expect(find.byKey(const ValueKey('voice_transcript_copy_m2')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finish(tester);
    });

    testWidgets('composer picker: emoji goes into the text, a sticker is sent', (tester) async {
      useSize(tester);
      await prepare(packs: [
        {
          'id': 'p1',
          'title': 'Университет',
          'is_default': true,
          'cover_sticker_id': s1,
          'stickers': [
            {'id': s1, 'pack_id': 'p1', 'emoji': '👋'},
            {'id': s2, 'pack_id': 'p1', 'emoji': '🎓'},
          ],
        },
      ]);
      stubConversation(ChatFixtures.conversation(lastSeq: 1), [ChatFixtures.message(id: 'm1', seq: 1)]);
      h.chatAdapter.on('POST', '/chats/$conv/messages', (req) => FakeResponse(
        201,
        json: {
          ...ChatFixtures.message(
            id: 'st1',
            seq: 2,
            type: 'sticker',
            sender: ChatFixtures.me,
            clientId: req.json['client_message_id'] as String,
            body: req.json['body'] as String,
          ),
          'sticker': {'id': s2, 'emoji': '🎓'},
        },
      ));
      await openConversation(tester);

      await tester.tap(find.byKey(const Key('chat_emoji_stickers')));
      await settle(tester, 10);
      await tester.tap(find.text('Эмодзи'));
      await settle(tester, 10);
      await tester.tap(find.byKey(const ValueKey('composer_emoji_😀')).first);
      await settle(tester, 10);
      expect(find.byKey(const Key('composer_emoji_grid')), findsNothing, reason: 'the sheet closes');
      expect(find.text('😀'), findsWidgets);

      await tester.tap(find.byKey(const Key('chat_emoji_stickers')));
      await settle(tester, 10);
      expect(find.byKey(const Key('sticker_grid')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sticker_$s2')));
      await settle(tester, 12);
      final sent = h.chatAdapter.of('POST', '/chats/$conv/messages').single.json;
      expect(sent['type'], 'sticker');
      expect(sent['body'], '{"sticker_id":"$s2"}');
      final recent = h.container.read(chatRecentStickersProvider);
      expect(recent.first.id, s2);
      expect(tester.takeException(), isNull);
      await finish(tester);
    });

    testWidgets('moderation: queue lists reports, details apply an action', (tester) async {
      useSize(tester);
      await prepare();
      Map<String, dynamic> report({String status = 'open', String? resolution}) => {
        'id': 'r1',
        'conversation_id': conv,
        'conversation_type': 'group',
        'conversation_title': 'Кафедра информатики',
        'message_id': 'm1',
        'reporter_id': ChatFixtures.carol,
        'reporter_name': 'Carol',
        'reported_user_id': ChatFixtures.peer,
        'reported_user_name': 'Bob',
        'reason': 'abuse',
        'comment': 'грубо',
        'status': status,
        'resolution': ?resolution,
        'snapshot': {'type': 'text', 'body': 'Грубое сообщение'},
        'created_at': '2026-09-15T10:00:00Z',
        'reported_is_member': true,
        'context': [
          ChatFixtures.message(id: 'm0', seq: 1, body: 'До', sender: ChatFixtures.carol),
          ChatFixtures.message(id: 'm1', seq: 2, body: 'Грубое сообщение'),
        ],
      };
      h.chatAdapter.onJson('GET', '/moderation/reports', {
        'reports': [report()],
        'next_cursor': '',
        'open_count': 1,
        'global': false,
      });
      var resolved = false;
      h.chatAdapter.on('GET', '/moderation/reports/r1', (_) => FakeResponse(
        200,
        json: {'report': resolved ? report(status: 'resolved', resolution: 'mute') : report()},
      ));
      h.chatAdapter.on('POST', '/moderation/reports/r1/actions', (req) {
        resolved = true;
        return FakeResponse(200, json: {'report': report(status: 'resolved', resolution: 'mute')});
      });
      await tester.runAsync(() => h.session.restore());

      await tester.pumpWidget(wrapWidget(const ModerationQueueScreen(), container: h.container));
      await settle(tester, 8);
      expect(find.byKey(const ValueKey('moderation_report_r1')), findsOneWidget);
      expect(find.text('Грубое сообщение'), findsOneWidget);
      expect(find.text('Группы, где вы администратор'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(wrapWidget(const ModerationReportScreen(reportId: 'r1'), container: h.container));
      await settle(tester, 8);
      expect(find.byKey(const Key('moderation_report_details')), findsOneWidget);
      expect(find.byKey(const ValueKey('moderation_context_m0')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('moderation_action_mute')));
      await tester.tap(find.byKey(const ValueKey('moderation_action_mute')));
      await settle(tester, 4);
      await tester.tap(find.byKey(const ValueKey('mute_hours_24')));
      await settle(tester, 4);
      await tester.enterText(find.byKey(const Key('moderation_note')), 'первое нарушение');
      await tester.tap(find.byKey(const Key('moderation_confirm')));
      await settle(tester, 8);
      expect(
        h.chatAdapter.of('POST', '/moderation/reports/r1/actions').single.json,
        {'action': 'mute', 'hours': 24, 'note': 'первое нарушение'},
      );
      expect(find.byKey(const ValueKey('moderation_action_mute')), findsNothing, reason: 'resolved reports have no actions');
      expect(tester.takeException(), isNull);
      await finish(tester);
    });
  });
}
