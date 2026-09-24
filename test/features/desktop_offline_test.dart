import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/app.dart';
import 'package:xatbox_mobile/core/localization/localization.dart';
import 'package:xatbox_mobile/core/network/network_status.dart';
import 'package:xatbox_mobile/core/notifications/local_notification_hub.dart';
import 'package:xatbox_mobile/core/platform/desktop.dart';
import 'package:xatbox_mobile/core/platform/desktop_layout.dart';
import 'package:xatbox_mobile/features/calendar/data/calendar_reminders.dart';
import 'package:xatbox_mobile/features/calendar/data/local_reminder_scheduler.dart';
import 'package:xatbox_mobile/features/chat/presentation/chat_providers.dart';
import 'package:xatbox_mobile/features/mail/data/mail_models.dart';
import 'package:xatbox_mobile/features/mail/data/mail_outbox_store.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_home_screen.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_outbox.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_providers.dart';
import 'package:xatbox_mobile/features/mail/presentation/mail_undo_send.dart';

import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Desktop without network: calendar reminders on Windows / macOS / Linux,
/// search over the cached mail, and «Исходящие» for letters sent offline.
void main() {
  Future<void> settle(WidgetTester tester, [int steps = 12]) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  ReminderRequest reminder(int id, DateTime fireAt, {bool meeting = false}) => ReminderRequest(
    id: id,
    fireAt: fireAt,
    title: 'Совет',
    body: '10:00–11:00',
    payload: meeting ? 'meet:abc-defg-hij' : 'e$id|',
    actionId: meeting ? 'join' : null,
    actionLabel: meeting ? 'Подключиться' : null,
  );

  group('calendar reminders on desktop', () {
    test('Windows: «Подключиться» carries the payload and is routed like a tap', () {
      expect(reminderWindowsDetails(reminder(1, DateTime.utc(2026))), isNull, reason: 'no button without a meeting');
      final details = reminderWindowsDetails(reminder(1, DateTime.utc(2026), meeting: true))!;
      final action = details.actions.single;
      expect(action.content, 'Подключиться');
      final r = LocalNotificationHub.normalizeWindowsResponse(
        NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotificationAction,
          actionId: action.arguments,
          payload: action.arguments,
        ),
      );
      expect(r.actionId, 'join');
      expect(r.payload, 'meet:abc-defg-hij');
    });

    test('macOS: meeting reminders use the category with «Подключиться»', () {
      expect(reminderMacDetails(reminder(1, DateTime.utc(2026))).categoryIdentifier, isNull);
      expect(reminderMacDetails(reminder(1, DateTime.utc(2026), meeting: true)).categoryIdentifier, LocalNotificationHub.macMeetingCategoryId);
      expect(macMeetingNotificationCategory.actions.single.identifier, 'join');
      expect(reminderLinuxDetails(reminder(1, DateTime.utc(2026), meeting: true)).actions.single.key, 'join');
    });

    testWidgets('Linux: the running app fires reminders at their time; cancel stops them', (tester) async {
      var now = DateTime.utc(2026, 9, 18, 8);
      final shown = <int>[];
      final timers = InProcessReminderTimers(
        show: (r) async => shown.add(r.id),
        now: () => now,
        tick: const Duration(seconds: 1),
      );
      addTearDown(timers.dispose);
      timers
        ..schedule(reminder(1, now.add(const Duration(minutes: 5))))
        ..schedule(reminder(2, now.add(const Duration(minutes: 10))))
        ..schedule(reminder(3, now.subtract(const Duration(hours: 2))));
      expect(timers.pendingIds, unorderedEquals([1, 2]), reason: 'long past reminders are dropped');

      timers.cancel(2);
      // The same id again replaces the reminder.
      timers.schedule(reminder(1, now.add(const Duration(minutes: 6))));
      now = now.add(const Duration(minutes: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(shown, isEmpty);

      // A sleep past the time: the wall clock decides, not the timer.
      now = now.add(const Duration(minutes: 3));
      await tester.pump(const Duration(seconds: 1));
      expect(shown, [1]);
      expect(timers.pendingIds, isEmpty);
      now = now.add(const Duration(minutes: 10));
      await tester.pump(const Duration(seconds: 2));
      expect(shown, [1], reason: 'the cancelled reminder never fires');
    });
  });

  Future<TestHarness> launch(WidgetTester tester, {bool desktop = true}) async {
    debugDesktopOverride = desktop;
    addTearDown(() => debugDesktopOverride = null);
    tester.view.physicalSize = desktop ? const Size(1440, 900) : const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localeTestValue = const Locale('ru');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final h = await TestHarness.create(
      storedToken: Fixtures.token,
      chatBaseUrl: desktop ? 'http://chat.local/api/v1' : '',
      overrides: [desktopLayoutProvider.overrideWithValue(desktop)],
    );
    addTearDown(h.dispose);
    h.stubSignedIn(messages: Fixtures.messages(3), total: 3);
    h.adapter.onPattern('GET', r'^/mail/messages/m\d+$', (req) {
      return FakeResponse(200, json: Fixtures.detail(id: req.path.split('/').last));
    });
    h.adapter.onJson('GET', '/mail/client-config', {'enabled': true, 'attachment_limit_bytes': 1024 * 1024});
    h.adapter.onJson('GET', '/mail/folders', {'folders': <Object>[]});
    h.adapter.onJson('GET', '/mail/bookmark-folders', {'folders': <Object>[]});
    h.chatAdapter.onJson('GET', '/chats', {'chats': <Object>[]});
    h.chatAdapter.onPattern('POST', r'^/push/devices$', (_) => const FakeResponse(204));
    await tester.pumpWidget(UncontrolledProviderScope(container: h.container, child: const XatBoxApp()));
    await settle(tester);
    return h;
  }

  Future<void> finish(WidgetTester tester, TestHarness h) async {
    unawaited(h.container.read(chatRepositoryProvider).stop());
    await tester.pump(const Duration(seconds: 10));
  }

  AppLocalizations l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  group('offline mail search', () {
    testWidgets('desktop: without network the search runs over the cached letters', (tester) async {
      final h = await launch(tester);
      // Opened once, so its text is cached too.
      h.container.read(mailOpenMessageProvider.notifier).open('m2');
      await settle(tester);
      h.container.read(mailOpenMessageProvider.notifier).open(null);
      h.adapter.onOffline('GET', '/mail/messages');

      h.container.read(mailFiltersProvider.notifier).setQuery('ПРЕВЬЮ ПИСЬМА 3');
      await settle(tester, 20);
      expect(find.byKey(const ValueKey('m3')), findsOneWidget);
      expect(find.byKey(const ValueKey('m1')), findsNothing);
      expect(find.text(l10n(tester).offlineBanner), findsOneWidget);

      // Sender names and the text of opened letters match as well.
      h.container.read(mailFiltersProvider.notifier).setQuery('тестовое');
      await settle(tester, 20);
      expect(find.byKey(const ValueKey('m2')), findsOneWidget);
      expect(find.byKey(const ValueKey('m3')), findsNothing);
      await finish(tester, h);
    });

    testWidgets('phone: the same — an offline search runs over the cached letters', (tester) async {
      final h = await launch(tester, desktop: false);
      h.adapter.onOffline('GET', '/mail/messages');
      h.container.read(mailFiltersProvider.notifier).setQuery('превью');
      await settle(tester, 20);
      final state = h.container.read(mailListProvider(h.container.read(currentMailQueryProvider)));
      expect(state.status, MailListStatus.ready);
      expect(state.items, isNotEmpty);
    });
  });

  group('outbox', () {
    const request = MailSendRequest(to: ['boss@kaztbu.edu.kz'], subject: 'Отчёт', text: 'Готово');

    testWidgets('a letter sent offline waits, is kept, and goes out when the network returns', (tester) async {
      final h = await launch(tester);
      h.adapter.onOffline('POST', '/mail/send');
      final queued = <String>[];
      final failed = <Object>[];
      h.container
          .read(mailUndoSendProvider.notifier)
          .schedule(
            request: request,
            snapshot: const ComposeSnapshot(modeName: 'newMessage', to: 'boss@kaztbu.edu.kz', subject: 'Отчёт'),
            delay: const Duration(seconds: 1),
            onSent: () {},
            onFailed: failed.add,
            onQueued: () => queued.add('queued'),
          );
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(queued, ['queued']);
      expect(failed, isEmpty);

      // Kept in the database and shown above the list with its status.
      final stored = await tester.runAsync(() => MailOutboxStore(h.db).all());
      expect(stored!.single.request.subject, 'Отчёт');
      expect(stored.single.request.to, ['boss@kaztbu.edu.kz']);
      await settle(tester);
      expect(find.byKey(const Key('mail_outbox_banner')), findsOneWidget);
      expect(find.textContaining('Отчёт → boss@kaztbu.edu.kz'), findsOneWidget);
      expect(find.text(l10n(tester).mailOutboxWaiting), findsOneWidget);

      // The network comes back: sent once, with a notice.
      h.adapter.onJson('POST', '/mail/send', {'message_id': 'msg_9'}, status: 202);
      h.network.set(NetworkKind.none);
      await settle(tester);
      h.network.set(NetworkKind.wifi);
      await settle(tester, 20);
      expect(h.adapter.of('POST', '/mail/send').last.json['subject'], 'Отчёт');
      expect(find.byKey(const Key('mail_outbox_banner')), findsNothing);
      expect(find.byKey(const Key('mail_outbox_sent_snackbar')), findsOneWidget);
      expect(await tester.runAsync(() => MailOutboxStore(h.db).all()), isEmpty);
      await finish(tester, h);
    });

    testWidgets('the quick reply goes to the outbox offline; a refusal stays with its error', (tester) async {
      final h = await launch(tester);
      h.adapter.onOffline('POST', '/mail/send');
      h.container.read(mailOpenMessageProvider.notifier).open('m1');
      await settle(tester);
      await tester.enterText(find.byKey(const Key('quick_reply_text')), 'Спасибо');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      expect(find.byKey(const Key('mail_outbox_queued_snackbar')), findsOneWidget);
      final items = h.container.read(mailOutboxProvider);
      expect(items.single.request.text, 'Спасибо');

      h.adapter.onError('POST', '/mail/send', 422, 'VALIDATION_ERROR');
      unawaited(h.container.read(mailOutboxProvider.notifier).flush());
      await settle(tester);
      expect(h.container.read(mailOutboxProvider).single.failed, isTrue);
      // Not retried by itself; removed by hand.
      unawaited(h.container.read(mailOutboxProvider.notifier).flush());
      await settle(tester);
      expect(h.adapter.of('POST', '/mail/send'), hasLength(2));
      unawaited(h.container.read(mailOutboxProvider.notifier).discard(items.single.id));
      await settle(tester);
      expect(find.byKey(const Key('mail_outbox_banner')), findsNothing);
      await finish(tester, h);
    });

    testWidgets('phone: the same — an offline send waits in «Исходящие» and goes out later', (tester) async {
      final h = await launch(tester, desktop: false);
      h.adapter.onOffline('POST', '/mail/send');
      final queued = <String>[];
      final failed = <Object>[];
      h.container
          .read(mailUndoSendProvider.notifier)
          .schedule(
            request: request,
            snapshot: const ComposeSnapshot(modeName: 'newMessage'),
            delay: const Duration(seconds: 1),
            onSent: () {},
            onFailed: failed.add,
            onQueued: () => queued.add('queued'),
          );
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(queued, ['queued']);
      expect(failed, isEmpty);
      expect((await tester.runAsync(() => MailOutboxStore(h.db).all()))!.single.request.subject, 'Отчёт');
      expect(find.byKey(const Key('mail_outbox_banner')), findsOneWidget);

      h.adapter.onJson('POST', '/mail/send', {'message_id': 'msg_9'}, status: 202);
      h.network.set(NetworkKind.none);
      await settle(tester);
      h.network.set(NetworkKind.wifi);
      await settle(tester, 20);
      expect(find.byKey(const Key('mail_outbox_banner')), findsNothing);
      expect(await tester.runAsync(() => MailOutboxStore(h.db).all()), isEmpty);
    });
  });
}
