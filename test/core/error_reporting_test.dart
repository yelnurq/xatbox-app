import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/errors/error_reporter.dart';
import 'package:xatbox_mobile/core/errors/error_scrubber.dart';
import 'package:xatbox_mobile/core/storage/app_database.dart';

ErrorReport _report(String fingerprint, DateTime at, {int count = 1}) =>
    ErrorReport(
      id: '${at.microsecondsSinceEpoch}-$fingerprint',
      fingerprint: fingerprint,
      errorType: 'StateError',
      message: 'm',
      stack: 's',
      firstSeen: at,
      lastSeen: at,
      count: count,
    );

void main() {
  group('ErrorScrubber', () {
    test('removes e-mails, tokens, secrets and user paths', () {
      const input =
          'GET /users?q=alia.nurlanova@kaztbu.edu.kz Authorization: Bearer abcDEF1234567890abcdef\n'
          'token=s3cr3t-value&x=1 {"password": "hunter2"} '
          'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.sig opaque Zk9vQmFyQmF6MTIzNDU2Nzg5MGFiY2RlZmdoaWo\n'
          '/home/aliya/x.pdf C:\\Users\\Aliya\\AppData /storage/emulated/0/Download/Отчёт Иванова.pdf\n'
          '_ChatMediaAutoDownloadNotifierStateImplementation.build';
      final out = ErrorScrubber.scrub(input);
      for (final leak in [
        'alia.nurlanova',
        'kaztbu',
        'abcDEF1234567890abcdef',
        's3cr3t-value',
        'hunter2',
        'eyJhbGciOiJIUzI1NiJ9',
        'Zk9vQmFyQmF6MTIzNDU2Nzg5MGFiY2RlZmdoaWo',
        'aliya',
        'Aliya',
        'Иванова',
      ]) {
        expect(out, isNot(contains(leak)), reason: leak);
      }
      expect(out, contains('<email>'));
      expect(out, contains('_ChatMediaAutoDownloadNotifierStateImplementation'));
    });

    test('messages drop parsed sources and long quoted user content', () {
      final format = ErrorScrubber.message(
        const FormatException('Unexpected character', '{"body":"секретный текст"}'),
      );
      expect(format, 'FormatException: Unexpected character');
      final quoted = ErrorScrubber.message(
        StateError('Could not send "Привет, это очень личное сообщение коллеге по работе"'),
      );
      expect(quoted, isNot(contains('личное')));
      expect(ErrorScrubber.message(StateError('x' * 5000)).length, ErrorScrubber.maxMessage);
    });

    test('route loses ids and query', () {
      expect(
        ErrorScrubber.route('/chat/c/6f1c2a9e-1111-4111-8111-111111111111?x=1'),
        '/chat/c/:id',
      );
      expect(ErrorScrubber.route('/calendar/event/12345'), '/calendar/event/:id');
      expect(ErrorScrubber.route('/settings/notifications'), '/settings/notifications');
    });

    test('fingerprint ignores line numbers but not the error type', () {
      const a =
          '#0      ChatRepository.send (package:xatbox_mobile/a.dart:120:7)\n'
          '<asynchronous suspension>\n'
          '#1      Outbox.flush (package:xatbox_mobile/b.dart:44:5)';
      const b =
          '#0      ChatRepository.send (package:xatbox_mobile/a.dart:131:9)\n'
          '#1      Outbox.flush (package:xatbox_mobile/b.dart:48:5)';
      expect(ErrorScrubber.fingerprint('StateError', a), ErrorScrubber.fingerprint('StateError', b));
      expect(ErrorScrubber.fingerprint('StateError', a), isNot(ErrorScrubber.fingerprint('TypeError', a)));
    });
  });

  group('ErrorReportQueue', () {
    late AppDatabase db;
    setUp(() async => db = await AppDatabase.inMemory());
    tearDown(() => db.close());

    test('dedupes within 10 minutes and bounds the queue', () async {
      final q = ErrorReportQueue(db);
      final t0 = DateTime.utc(2026, 9, 15, 10);
      await q.add(_report('a', t0));
      await q.add(_report('a', t0.add(const Duration(minutes: 9))));
      await q.add(_report('a', t0.add(const Duration(minutes: 30))));
      final items = await q.peek(10);
      expect(items.map((r) => r.count), [2, 1]);

      for (var i = 0; i < 60; i++) {
        await q.add(_report('f$i', t0.add(Duration(hours: 1, seconds: i))));
      }
      expect(await q.length(), 50);
      expect((await q.peek(1)).single.fingerprint, 'f10');
    });

    test('acknowledge keeps counts that grew while sending', () async {
      final q = ErrorReportQueue(db);
      final t0 = DateTime.utc(2026, 9, 15, 10);
      await q.add(_report('a', t0));
      await q.add(_report('b', t0));
      final sent = await q.peek(50);
      await q.add(_report('a', t0.add(const Duration(minutes: 1))));
      await q.acknowledge({for (final r in sent) r.id: r.count});
      final left = await q.peek(50);
      expect(left.map((r) => (r.fingerprint, r.count)), [('a', 1)]);
    });
  });

  group('ErrorReporter', () {
    late AppDatabase db;
    setUp(() async => db = await AppDatabase.inMemory());
    tearDown(() => db.close());

    test('captures, queues and sends scrubbed batches when allowed', () async {
      final reporter = ErrorReporter(clock: () => DateTime.utc(2026, 9, 15, 12))
        ..device = const DeviceSnapshot(
          appVersion: '0.1.0',
          appBuild: '1',
          flavor: 'prod',
          platform: 'android',
          osVersion: 'Android 15 (SDK 35)',
          deviceModel: 'Google Pixel 8',
          locale: 'ru',
        )
        ..routeName = () => '/chat/c/6f1c2a9e-1111-4111-8111-111111111111';
      // Captured before the queue exists (start-up) → kept in memory.
      reporter.record(ArgumentError('early for bob@x.kz'), StackTrace.current);
      final queue = ErrorReportQueue(db);
      reporter.attach(queue);
      reporter.record(StateError('boom'), StackTrace.current, context: 'test');
      reporter.record(StateError('boom'), StackTrace.current, context: 'test');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final batches = <List<Map<String, Object?>>>[];
      reporter.sender = (items) async => batches.add(items);
      reporter.canSend = () => false;
      expect(await reporter.flush(), 0);

      reporter.canSend = () => true;
      expect(await reporter.flush(), greaterThan(0));
      final payload = batches.expand((b) => b).toList();
      expect(payload.every((p) => p['route'] == '/chat/c/:id'), isTrue);
      expect(payload.any((p) => (p['message']! as String).contains('bob@')), isFalse);
      final boom = payload.where((p) => (p['message']! as String).contains('boom'));
      expect(boom.fold<int>(0, (s, p) => s + (p['count']! as int)), 2);
      expect(payload.first.keys, containsAll(<String>[
        'platform', 'os_version', 'device_model', 'app_version', 'app_build', 'flavor',
        'locale', 'route', 'error_type', 'message', 'stack', 'context', 'timestamp', 'count',
      ]));
      expect(await queue.length(), 0);
    });

    test('unsupported camera focus/zoom calls are not crash reports', () async {
      final reporter = ErrorReporter();
      final queue = ErrorReportQueue(db);
      reporter.attach(queue);
      reporter.record(PlatformException(code: 'setFocusMode', message: 'Video capturer not compatible'), StackTrace.current);
      reporter.record(PlatformException(code: 'setZoom'), StackTrace.current);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(await queue.length(), 0);
      reporter.record(PlatformException(code: 'error', message: 'real'), StackTrace.current);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(await queue.length(), 1);
    });

    test('a failed send keeps the queue; disabled captures nothing', () async {
      final reporter = ErrorReporter();
      final queue = ErrorReportQueue(db);
      reporter
        ..attach(queue)
        ..canSend = (() => true)
        ..sender = (_) async => throw Exception('offline');
      reporter.record(StateError('x'), StackTrace.current);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(await reporter.flush(), 0);
      expect(await queue.length(), 1);

      reporter.enabled = false;
      reporter.record(ArgumentError('y'), StackTrace.current);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(await queue.length(), 1);
    });
  });
}
