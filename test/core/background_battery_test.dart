import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/lifecycle/app_visibility.dart';
import 'package:xatbox_mobile/core/lifecycle/background_connection.dart';
import 'package:xatbox_mobile/core/preferences/app_preferences.dart';
import 'package:xatbox_mobile/core/websocket/realtime_client.dart';

/// Battery: foreground-only timers, the background socket grace period and
/// the offline reconnect hold. Timers run in the fake-async zone of
/// testWidgets, so `tester.pump(duration)` is the fake clock.
void main() {
  group('backgroundGraceFor', () {
    test('auto: 15 min without push, 1 min with a registered token', () {
      expect(backgroundGraceFor(BackgroundConnection.auto, pushReady: false), backgroundGraceLong);
      expect(backgroundGraceFor(BackgroundConnection.auto, pushReady: true), backgroundGraceShort);
      expect(backgroundGraceLong, const Duration(minutes: 15));
      expect(backgroundGraceShort, const Duration(minutes: 1));
    });

    test('explicit choices win over the push state; always = no limit', () {
      for (final push in [false, true]) {
        expect(backgroundGraceFor(BackgroundConnection.oneMinute, pushReady: push), backgroundGraceShort);
        expect(backgroundGraceFor(BackgroundConnection.fifteenMinutes, pushReady: push), backgroundGraceLong);
        expect(backgroundGraceFor(BackgroundConnection.always, pushReady: push), isNull);
      }
      expect(
        effectiveBackgroundConnection(BackgroundConnection.auto, pushReady: false),
        BackgroundConnection.fifteenMinutes,
      );
    });

    test('preference survives JSON; unknown or missing value is auto', () {
      const p = AppPreferences(backgroundConnection: BackgroundConnection.always);
      expect(AppPreferences.fromJson(p.toJson()).backgroundConnection, BackgroundConnection.always);
      expect(AppPreferences.fromJson(const {}).backgroundConnection, BackgroundConnection.auto);
      expect(
        AppPreferences.fromJson(const {'background_connection': 'forever'}).backgroundConnection,
        BackgroundConnection.auto,
      );
    });
  });

  group('ForegroundPeriodic', () {
    testWidgets('ticks only in the foreground and catches up on return', (tester) async {
      final v = FakeAppVisibility();
      var now = DateTime(2026, 9, 15, 12);
      var ticks = 0;
      final p = ForegroundPeriodic(v, const Duration(minutes: 15), () => ticks++, now: () => now);

      Future<void> advance(Duration d) async {
        now = now.add(d);
        await tester.pump(d);
      }

      await advance(const Duration(minutes: 15));
      expect(ticks, 1);

      v.set(foreground: false);
      expect(p.isRunning, isFalse, reason: 'no timer while hidden');
      await advance(const Duration(hours: 2));
      expect(ticks, 1, reason: 'no background wake-ups');

      v.set(foreground: true);
      expect(ticks, 2, reason: 'overdue tick fires on return');
      expect(p.isRunning, isTrue);

      // Short absence: nothing overdue, the period simply restarts.
      await advance(const Duration(minutes: 5));
      v.set(foreground: false);
      await advance(const Duration(minutes: 1));
      v.set(foreground: true);
      expect(ticks, 2);
      await advance(const Duration(minutes: 15));
      expect(ticks, 3);

      p.dispose();
      await advance(const Duration(hours: 1));
      expect(ticks, 3);
    });

    testWidgets('without catch-up a return does not tick; started hidden = idle', (tester) async {
      final v = FakeAppVisibility(foreground: false);
      var ticks = 0;
      final p = ForegroundPeriodic(v, const Duration(minutes: 30), () => ticks++, catchUpOnResume: false);
      expect(p.isRunning, isFalse);
      await tester.pump(const Duration(hours: 1));
      v.set(foreground: true);
      expect(ticks, 0);
      await tester.pump(const Duration(minutes: 30));
      expect(ticks, 1);
      p.dispose();
    });
  });

  group('BackgroundConnectionPolicy', () {
    late FakeAppVisibility v;
    late List<String> log;
    Duration? grace;
    var busy = false;

    BackgroundConnectionPolicy make() {
      v = FakeAppVisibility();
      log = [];
      final p = BackgroundConnectionPolicy(
        visibility: v,
        grace: () => grace,
        busy: () => busy,
        suspend: () => log.add('suspend'),
        resume: () => log.add('resume'),
      )..start();
      addTearDown(p.dispose);
      return p;
    }

    setUp(() {
      grace = const Duration(minutes: 15);
      busy = false;
    });

    testWidgets('disconnects after the grace period, reconnects at once on resume', (tester) async {
      final p = make();
      v.set(foreground: false);
      await tester.pump(const Duration(minutes: 14, seconds: 59));
      expect(log, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      expect(log, ['suspend']);
      expect(p.suspended, isTrue);

      v.set(foreground: true);
      expect(log, ['suspend', 'resume']);
      expect(p.suspended, isFalse);
      expect(p.graceRunning, isFalse);
    });

    testWidgets('a short trip to the background changes nothing', (tester) async {
      final p = make();
      v.set(foreground: false);
      await tester.pump(const Duration(minutes: 3));
      v.set(foreground: true);
      await tester.pump(const Duration(hours: 1));
      expect(log, isEmpty);
      expect(p.graceRunning, isFalse);
    });

    testWidgets('«always» never disconnects', (tester) async {
      grace = null;
      final p = make();
      v.set(foreground: false);
      await tester.pump(const Duration(hours: 10));
      expect(log, isEmpty);
      expect(p.graceRunning, isFalse);
    });

    testWidgets('an active call keeps the socket; the grace restarts when it ends', (tester) async {
      final p = make();
      busy = true;
      v.set(foreground: false);
      await tester.pump(const Duration(minutes: 30));
      expect(log, isEmpty, reason: 'in a call at expiry');

      busy = false;
      p.reevaluate(); // call ended
      await tester.pump(const Duration(minutes: 14));
      expect(log, isEmpty);
      await tester.pump(const Duration(minutes: 1));
      expect(log, ['suspend']);
    });

    testWidgets('a shorter grace (push registered) applies from now', (tester) async {
      final p = make();
      v.set(foreground: false);
      await tester.pump(const Duration(minutes: 5));
      grace = const Duration(minutes: 1);
      p.reevaluate();
      await tester.pump(const Duration(minutes: 1));
      expect(log, ['suspend']);
    });

    testWidgets('a push wakes a suspended socket and restarts the grace', (tester) async {
      final p = make();
      grace = const Duration(minutes: 1);
      v.set(foreground: false);
      await tester.pump(const Duration(minutes: 1));
      expect(log, ['suspend']);

      p.wake();
      expect(log, ['suspend', 'resume']);
      await tester.pump(const Duration(seconds: 59));
      expect(log, hasLength(2));
      await tester.pump(const Duration(seconds: 1));
      expect(log, ['suspend', 'resume', 'suspend']);
    });

    testWidgets('dispose cancels a running grace timer', (tester) async {
      final p = make();
      v.set(foreground: false);
      p.dispose();
      await tester.pump(const Duration(hours: 1));
      expect(log, isEmpty);
    });
  });

  group('RealtimeClient without network', () {
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('no reconnect loop while offline; reconnects at once when the network returns', () async {
      var attempts = 0;
      final client = RealtimeClient(
        url: () => Uri.parse('ws://test/ws'),
        tokenProvider: () async => 't',
        connector: (_) {
          attempts++;
          throw const SocketUnavailable();
        },
      );
      addTearDown(client.dispose);

      client.start();
      await settle();
      expect(attempts, 1);
      expect(client.current, RealtimeStatus.disconnected, reason: 'a failed attempt is not "connecting"');
      expect(client.reconnectPending, isTrue);

      client.setNetworkAvailable(false);
      expect(client.reconnectPending, isFalse, reason: 'no wake-ups without network');

      client.setNetworkAvailable(true);
      await settle();
      expect(attempts, 2, reason: 'immediate attempt, no backoff wait');
      expect(client.reconnectPending, isTrue);
    });
  });
}

class SocketUnavailable implements Exception {
  const SocketUnavailable();
}
