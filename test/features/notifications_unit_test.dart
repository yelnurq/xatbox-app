import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/routing/routes.dart';
import 'package:xatbox_mobile/features/notifications/data/notification_models.dart';
import 'package:xatbox_mobile/features/notifications/domain/notification_target.dart';
import 'package:xatbox_mobile/features/notifications/presentation/notifications_providers.dart';

import '../helpers/fake_http.dart';
import '../helpers/fixtures.dart';
import '../helpers/notification_fixtures.dart';
import '../helpers/test_app.dart';

Future<void> _flush() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  group('notificationTargetLocation', () {
    const table = <String?, String?>{
      null: null,
      '': null,
      '   ': null,
      // Web app paths from the Mail API.
      '/mail/calendar?event=ev1': '/calendar/event/ev1',
      '/mail/calendar?event=ev1&occ=2026-09-14T10:00:00Z':
          '/calendar/event/ev1?occ=2026-09-14T10%3A00%3A00Z',
      '/mail/calendar': Routes.calendar,
      '/mail/messages?conversation=c1': Routes.chat,
      '/mail/messages': Routes.chat,
      '/mail/message/m1': '/mail/message/m1',
      '/mail/inbox?message=m2': '/mail/message/m2',
      '/mail?message=m3': '/mail/message/m3',
      '/mail': Routes.mail,
      '/mail/my-list': Routes.tasks,
      '/mail/official': Routes.official,
      '/mail/official?id=o1': '/official/m/o1',
      '/mail/tasks?task=t1': '/tasks/t1',
      '/tasks/t2': '/tasks/t2',
      'xatbox://tasks': Routes.tasks,
      'xatbox://tasks/t3': '/tasks/t3',
      'https://mail.example.kz/mail/calendar?event=ev2': '/calendar/event/ev2',
      // App paths.
      '/chat/c/c9': '/chat/c/c9',
      '/chat': Routes.chat,
      '/call/call-1': Routes.calls,
      '/calls': Routes.calls,
      '/calendar/event/ev3': '/calendar/event/ev3',
      // Deep links (lib/core/routing/deep_links.dart).
      'xatbox://mail/m4': '/mail/message/m4',
      'xatbox://chat/c5/message/x': '/chat/c/c5',
      'xatbox://call/k1': '/calls/c/k1',
      // Unknown.
      '/admin/users': null,
      'ftp://example.kz/mail': null,
      'mailto:someone@example.kz': null,
    };
    for (final entry in table.entries) {
      test('${entry.key} → ${entry.value}', () {
        expect(notificationTargetLocation(entry.key), entry.value);
      });
    }

    test('tab roots are navigated with go', () {
      expect(isTabRootLocation(Routes.chat), isTrue);
      expect(isTabRootLocation(Routes.contacts), isTrue);
      expect(isTabRootLocation('/mail/message/m1'), isFalse);
    });
  });

  group('AppNotification', () {
    test('parses PostgreSQL timestamps; read_at omitted = unread', () {
      final page = NotificationFixtures.list(2, unread: 1);
      final items = (page['notifications'] as List)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      expect(
        items.first.createdAt,
        DateTime.utc(2026, 9, 14, 10, 21, 33, 123, 456),
      );
      expect(items.first.isRead, isFalse);
      expect(items.last.readAt, DateTime.utc(2026, 9, 14, 11));
    });
  });

  group('NotificationsNotifier', () {
    late TestHarness h;
    tearDown(() => h.dispose());

    Future<void> signedIn() async {
      h = await TestHarness.create(storedToken: Fixtures.token);
      h.adapter.onJson('GET', '/me', Fixtures.me());
      await h.session.restore();
    }

    test(
      'GET /notifications without parameters; rows revealed by pages locally',
      () async {
        await signedIn();
        h.adapter.onJson(
          'GET',
          '/notifications',
          NotificationFixtures.list(25, unread: 3),
        );
        h.container.read(notificationsProvider);
        await _flush();

        var state = h.container.read(notificationsProvider);
        final req = h.adapter.of('GET', '/notifications').single;
        expect(req.query, isEmpty, reason: 'the endpoint has no parameters');
        expect(state.items, hasLength(25));
        expect(state.visible, hasLength(NotificationsNotifier.pageSize));
        expect(state.hasMore, isTrue);
        expect(h.container.read(notificationsUnreadBadgeProvider), 3);

        h.container.read(notificationsProvider.notifier).loadMore();
        state = h.container.read(notificationsProvider);
        expect(state.visible, hasLength(25));
        expect(state.hasMore, isFalse);
        expect(
          h.adapter.of('GET', '/notifications'),
          hasLength(1),
          reason: 'no pagination request exists',
        );

        // Refresh keeps the revealed rows.
        await h.container.read(notificationsProvider.notifier).refresh();
        expect(h.container.read(notificationsProvider).visible, hasLength(25));
      },
    );

    test('mark one read: POST /notifications/{id}/read without body', () async {
      await signedIn();
      h.adapter.onJson(
        'GET',
        '/notifications',
        NotificationFixtures.list(3, unread: 2),
      );
      h.adapter.onPattern(
        'POST',
        r'^/notifications/[^/]+/read$',
        (_) => const FakeResponse(204),
      );
      h.container.read(notificationsProvider);
      await _flush();

      await h.container.read(notificationsProvider.notifier).markRead('n1');
      final posts = h.adapter.of('POST', '/notifications/n1/read');
      expect(posts, hasLength(1));
      expect(posts.single.body, isEmpty);
      expect(h.container.read(notificationsUnreadBadgeProvider), 1);

      // Already read: no request.
      await h.container.read(notificationsProvider.notifier).markRead('n1');
      await h.container.read(notificationsProvider.notifier).markRead('n3');
      expect(
        h.adapter.requests.where((r) => r.method == 'POST'),
        hasLength(1),
      );
    });

    test('read-all: POST /notifications/read-all without body clears the badge', () async {
      await signedIn();
      h.adapter.onJson(
        'GET',
        '/notifications',
        NotificationFixtures.list(5, unread: 4),
      );
      h.adapter.onError('POST', '/notifications/read-all', 500, 'INTERNAL');
      h.container.read(notificationsProvider);
      await _flush();

      final failure = await h.container
          .read(notificationsProvider.notifier)
          .markAllRead();
      expect(failure, isNotNull);
      expect(
        h.container.read(notificationsUnreadBadgeProvider),
        4,
        reason: 'unchanged until the server confirms',
      );

      h.adapter.onJson('POST', '/notifications/read-all', null, status: 204);
      expect(
        await h.container.read(notificationsProvider.notifier).markAllRead(),
        isNull,
      );
      final req = h.adapter.of('POST', '/notifications/read-all').last;
      expect(req.body, isEmpty);
      expect(h.container.read(notificationsUnreadBadgeProvider), 0);
      expect(
        h.container.read(notificationsProvider).items.every((n) => n.isRead),
        isTrue,
      );
    });
  });
}
