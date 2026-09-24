import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/storage/app_database.dart';
import 'package:xatbox_mobile/features/chat/data/chat_cache.dart';
import 'package:xatbox_mobile/features/chat/data/chat_messenger2.dart';
import 'package:xatbox_mobile/features/chat/data/chat_models.dart';
import 'package:xatbox_mobile/features/chat/data/chat_translation.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/conversation_screen.dart';
import 'package:xatbox_mobile/features/chat/presentation/translation/translation_providers.dart';
import 'package:xatbox_mobile/features/chat/presentation/translation/translation_settings.dart';
import 'package:xatbox_mobile/features/mail/presentation/message_detail_screen.dart';

import '../helpers/chat_fixtures.dart';
import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Message translation: chat menu «Перевести», auto translation per chat,
/// target language setting, «Перевести письмо», hidden when the server flag
/// is off.
void main() {
  const conv = ChatFixtures.conv;

  group('data', () {
    test('language detection and chunks', () {
      expect(TranslateLanguages.detect('Добрый день, коллеги'), 'ru');
      expect(TranslateLanguages.detect('Сәлеметсіз бе, әріптестер'), 'kk');
      expect(TranslateLanguages.detect('Good morning'), 'en');
      expect(TranslateLanguages.normalize('de'), 'ru');
      expect(TranslateLanguages.normalize('KK'), 'kk');

      final text = '${'Первое предложение. ' * 30}\n\n${'Второй абзац. ' * 30}';
      final parts = TranslateLanguages.chunks(text, 400);
      expect(parts.join(), text);
      expect(parts.every((p) => p.length <= 400), isTrue);
      expect(parts.length, greaterThan(1));
      expect(TranslateLanguages.chunks('коротко', 400), ['коротко']);
    });

    test('features flag and translatable messages', () {
      final f = ChatFeatures.fromJson({
        'translation': true,
        'translation_max_chars': 3000,
      });
      expect(f.translation, isTrue);
      expect(f.translationMaxChars, 3000);
      expect(ChatFeatures.fromJson({}).translation, isFalse);
      ChatMessage msg(Map<String, dynamic> j) => ChatMessage.fromJson(j);
      expect(
        chatMessageTranslatable(
          msg(ChatFixtures.message(id: 'a', seq: 1, body: 'Привет')),
        ),
        isTrue,
      );
      expect(
        chatMessageTranslatable(
          msg(
            ChatFixtures.message(id: 'b', seq: 1, type: 'sticker', body: '{}'),
          ),
        ),
        isFalse,
      );
      expect(
        chatMessageTranslatable(
          msg(ChatFixtures.message(id: 'c', seq: 1, body: '  ')),
        ),
        isFalse,
      );
    });

    test('device store keys by edit version and stays bounded', () async {
      final db = await AppDatabase.inMemory();
      final store = ChatTranslationStore(ChatCache(db));
      final m = ChatMessage.fromJson(
        ChatFixtures.message(id: 'm1', seq: 1, body: 'Привет'),
      );
      final edited = ChatMessage.fromJson({
        ...ChatFixtures.message(id: 'm1', seq: 1, body: 'Привет!'),
        'edited_at': '2026-09-17T10:00:00Z',
      });
      final key = ChatTranslationStore.key(m, 'en');
      expect(ChatTranslationStore.key(edited, 'en'), isNot(key));
      await store.write(
        key,
        const ChatTranslationResult(text: 'Hi', source: 'ru', target: 'en'),
      );
      final back = await store.read(key);
      expect(back!.text, 'Hi');
      expect(back.source, 'ru');
      expect(await store.read(ChatTranslationStore.key(edited, 'en')), isNull);
      for (var i = 0; i < ChatTranslationStore.maxEntries + 5; i++) {
        await store.write(
          'x$i|0|en',
          const ChatTranslationResult(text: 't', source: 'ru', target: 'en'),
        );
      }
      expect(
        await store.read(key),
        isNull,
        reason: 'oldest entries are dropped',
      );
      expect(
        await store.read('x${ChatTranslationStore.maxEntries + 4}|0|en'),
        isNotNull,
      );
      await db.close();
    });
  });

  group('widgets', () {
    late TestHarness h;
    late Directory tmp;

    Future<void> prepare({bool translation = true}) async {
      const recordChannel = MethodChannel('com.llfbandit.record/messages');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(recordChannel, (_) async => null);
      addTearDown(
        () => messenger.setMockMethodCallHandler(recordChannel, null),
      );
      tmp = Directory.systemTemp.createTempSync('xatbox_translation');
      h = await TestHarness.create(
        storedToken: Fixtures.token,
        chatBaseUrl: 'http://chat.local/api/v1',
        overrides: [chatMediaRootProvider.overrideWithValue(() async => tmp)],
      );
      h.adapter.onJson('GET', '/me', Fixtures.me());
      h.chatAdapter.onPattern(
        'POST',
        r'^/messages/[^/]+/read$',
        (_) => const FakeResponse(204),
      );
      h.chatAdapter.onJson('GET', '/features', {
        'translation': translation,
        'translation_max_chars': 5000,
      });
      h.chatAdapter.onJson('GET', '/sticker-packs', {'packs': []});
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
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
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

    void stubConversation(List<Map<String, dynamic>> messages) {
      final c = ChatFixtures.conversation(lastSeq: messages.length);
      h.chatAdapter.onJson('GET', '/chats/${c['id']}', c);
      h.chatAdapter.onJson(
        'GET',
        '/chats/${c['id']}/messages',
        ChatFixtures.messages(messages),
      );
    }

    Future<void> openConversation(WidgetTester tester) async {
      await tester.runAsync(() => h.session.restore());
      await tester.pumpWidget(
        wrapWidget(
          const ConversationScreen(conversationId: conv),
          container: h.container,
        ),
      );
      await settle(tester, 14);
    }

    testWidgets(
      '360 px: «Перевести» shows the translation under the message, «Показать оригинал» hides it',
      (tester) async {
        useSize(tester);
        await prepare();
        stubConversation([
          ChatFixtures.message(
            id: 'm1',
            seq: 1,
            body: 'Good morning, colleagues',
          ),
        ]);
        h.chatAdapter.on(
          'POST',
          '/messages/m1/translate',
          (_) => const FakeResponse(
            200,
            json: {
              'message_id': 'm1',
              'text': 'Доброе утро, коллеги',
              'source_detected': 'en',
              'target': 'ru',
              'cached': false,
            },
          ),
        );
        await openConversation(tester);

        await tester.longPress(find.text('Good morning, colleagues'));
        await settle(tester, 6);
        await tester.ensureVisible(find.byKey(const Key('message_translate')));
        await tester.tap(find.byKey(const Key('message_translate')));
        await settle(tester, 10);

        final calls = h.chatAdapter.of('POST', '/messages/m1/translate');
        expect(calls, hasLength(1));
        expect(
          calls.single.query['target'],
          'ru',
          reason: 'the app language by default',
        );
        expect(find.text('Good morning, colleagues'), findsOneWidget);
        expect(find.text('Доброе утро, коллеги'), findsOneWidget);
        expect(find.text('Перевод: английский → русский'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('message_translation_original_m1')),
        );
        await settle(tester, 4);
        expect(find.text('Доброе утро, коллеги'), findsNothing);

        // Again from the menu: memory, no second request.
        await tester.longPress(find.text('Good morning, colleagues'));
        await settle(tester, 6);
        await tester.ensureVisible(find.byKey(const Key('message_translate')));
        await tester.tap(find.byKey(const Key('message_translate')));
        await settle(tester, 6);
        expect(find.text('Доброе утро, коллеги'), findsOneWidget);
        expect(
          h.chatAdapter.of('POST', '/messages/m1/translate'),
          hasLength(1),
        );
        expect(tester.takeException(), isNull);
        await finish(tester);
      },
    );

    testWidgets(
      'auto translation: only incoming messages not in the target language',
      (tester) async {
        useSize(tester);
        await prepare();
        stubConversation([
          ChatFixtures.message(
            id: 'm1',
            seq: 1,
            body: 'Сәлеметсіз бе, әріптестер',
          ),
          ChatFixtures.message(id: 'm2', seq: 2, body: 'Добрый день'),
          ChatFixtures.message(
            id: 'm3',
            seq: 3,
            body: 'Hello from me',
            sender: ChatFixtures.me,
          ),
        ]);
        h.chatAdapter.onPattern(
          'POST',
          r'^/messages/[^/]+/translate$',
          (req) => FakeResponse(
            200,
            json: {
              'message_id': req.path.split('/')[2],
              'text': 'Здравствуйте, коллеги',
              'source_detected': 'kk',
              'target': 'ru',
            },
          ),
        );
        await tester.runAsync(
          () => h.container
              .read(chatAutoTranslateProvider.notifier)
              .set(conv, true),
        );
        await openConversation(tester);
        await settle(tester, 8);

        final paths = h.chatAdapter.requests
            .where((r) => r.method == 'POST' && r.path.endsWith('/translate'))
            .map((r) => r.path)
            .toList();
        expect(
          paths,
          hasLength(1),
          reason: 'Russian text and own messages are not sent: $paths',
        );
        expect(paths.single, endsWith('/messages/m1/translate'));
        expect(find.text('Здравствуйте, коллеги'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await finish(tester);
      },
    );

    testWidgets('flag off: no menu item, no auto translation, no settings', (
      tester,
    ) async {
      useSize(tester);
      await prepare(translation: false);
      stubConversation([
        ChatFixtures.message(id: 'm1', seq: 1, body: 'Сәлеметсіз бе'),
      ]);
      await tester.runAsync(
        () => h.container
            .read(chatAutoTranslateProvider.notifier)
            .set(conv, true),
      );
      await openConversation(tester);
      await tester.longPress(find.text('Сәлеметсіз бе'));
      await settle(tester, 6);
      expect(find.byKey(const Key('message_translate')), findsNothing);
      expect(
        h.chatAdapter.requests.where((r) => r.path.endsWith('/translate')),
        isEmpty,
      );

      await tester.pumpWidget(
        wrapWidget(
          const Material(
            child: Column(
              children: [
                TranslateTargetSettingsTile(),
                ChatAutoTranslateTile(conversationId: conv),
              ],
            ),
          ),
          container: h.container,
        ),
      );
      await settle(tester, 4);
      expect(find.byKey(const Key('settings_translate_target')), findsNothing);
      expect(find.byKey(const Key('chat_info_auto_translate')), findsNothing);
      await finish(tester);
    });

    testWidgets('settings: target language changes the request', (
      tester,
    ) async {
      useSize(tester);
      await prepare();
      await tester.runAsync(() => h.session.restore());
      await tester.pumpWidget(
        wrapWidget(
          const Material(
            child: Column(
              children: [
                TranslateTargetSettingsTile(),
                ChatAutoTranslateTile(conversationId: conv),
              ],
            ),
          ),
          container: h.container,
        ),
      );
      await settle(tester, 8);
      expect(find.text('Как в приложении (русский)'), findsOneWidget);
      expect(find.text('Переводить автоматически на русский'), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings_translate_target')));
      await settle(tester, 4);
      await tester.tap(find.byKey(const ValueKey('translate_target_kk')));
      await settle(tester, 4);
      expect(h.container.read(translateTargetPrefProvider), 'kk');
      expect(
        find.text('Переводить автоматически на казахский'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('chat_info_auto_translate')));
      await settle(tester, 4);
      expect(h.container.read(chatAutoTranslateProvider), contains(conv));
      final stored = await tester.runAsync(
        () => h.container
            .read(chatCacheProvider)
            .readMeta('pref:translate_target'),
      );
      expect(stored, 'kk');
      await finish(tester);
    });

    testWidgets(
      'mail: «Перевести письмо» translates the body through chat-service',
      (tester) async {
        useSize(tester);
        await prepare();
        h.adapter.onJson('GET', '/mail/messages/m1', Fixtures.detail());
        h.chatAdapter.on(
          'POST',
          '/translate',
          (req) => FakeResponse(
            200,
            json: {
              'text': 'Сәлем!\nБұл сынақ хат.',
              'source_detected': 'ru',
              'target': req.json['target'],
            },
          ),
        );
        await tester.runAsync(() => h.session.restore());
        await tester.runAsync(
          () =>
              h.container.read(translateTargetPrefProvider.notifier).set('kk'),
        );
        await tester.pumpWidget(
          wrapWidget(
            const MessageDetailScreen(messageId: 'm1'),
            container: h.container,
          ),
        );
        await settle(tester, 14);

        await tester.tap(find.byKey(const Key('action_more')));
        await settle(tester, 4);
        await settle(tester, 8);
        await tester.ensureVisible(find.byKey(const Key('menu_translate')));
        await settle(tester, 4);
        await tester.tap(find.byKey(const Key('menu_translate')));
        await settle(tester, 10);
        final sent = h.chatAdapter.of('POST', '/translate').single.json;
        expect(sent, {
          'text': 'Привет!\nЭто тестовое письмо.',
          'source': 'auto',
          'target': 'kk',
        });
        expect(find.text('Сәлем!\nБұл сынақ хат.'), findsOneWidget);
        expect(find.text('Перевод: русский → казахский'), findsOneWidget);

        await tester.tap(find.byKey(const Key('mail_translation_original')));
        await settle(tester, 4);
        expect(find.byKey(const Key('mail_translation')), findsNothing);
        expect(find.textContaining('Это тестовое письмо'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await finish(tester);
      },
    );

    testWidgets('mail: menu item hidden when the flag is off', (tester) async {
      useSize(tester);
      await prepare(translation: false);
      h.adapter.onJson('GET', '/mail/messages/m1', Fixtures.detail());
      await tester.runAsync(() => h.session.restore());
      await tester.pumpWidget(
        wrapWidget(
          const MessageDetailScreen(messageId: 'm1'),
          container: h.container,
        ),
      );
      await settle(tester, 14);
      await tester.tap(find.byKey(const Key('action_more')));
      await settle(tester, 4);
      expect(find.byKey(const Key('menu_translate')), findsNothing);
      await finish(tester);
    });
  });
}
