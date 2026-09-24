import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/platform/desktop_crash.dart';

/// DesktopCrashWatch: a run that did not quit is offered as a problem
/// report, except after a restart of the computer or a change of version.
void main() {
  final started = DateTime.utc(2026, 9, 19, 9);
  String marker(String version) => jsonEncode({'started_at': started.toIso8601String(), 'version': version});

  test('a marker from this version, no restart since: an unclean exit', () {
    final crash = DesktopCrashWatch.decide(
      marker: marker('1.0.0+115'),
      version: '1.0.0+115',
      bootedAt: started.subtract(const Duration(hours: 3)),
      log: 'last lines',
    );
    expect(crash, isNotNull);
    expect(crash!.version, '1.0.0+115');
    expect(crash.startedAt, started);
    expect(crash.log, 'last lines');
  });

  test('the computer restarted since: a shutdown, not a crash', () {
    expect(
      DesktopCrashWatch.decide(marker: marker('1.0.0+115'), version: '1.0.0+115', bootedAt: started.add(const Duration(hours: 1)), log: ''),
      isNull,
    );
  });

  test('another version now: installed over it, not a crash', () {
    expect(DesktopCrashWatch.decide(marker: marker('1.0.0+114'), version: '1.0.0+115', bootedAt: null, log: ''), isNull);
  });

  test('a broken marker is ignored', () {
    expect(DesktopCrashWatch.decide(marker: '{', version: '1.0.0+115', bootedAt: null, log: ''), isNull);
  });

  test('the log of the previous run only, its end', () {
    const log = '--- 2026-09-18 start windows\nold run\n--- 2026-09-19 start windows\nopened chat\nplugin failed';
    expect(DesktopCrashWatch.lastRun(log), '--- 2026-09-19 start windows\nopened chat\nplugin failed');
    final long = '--- start\n${List.filled(3000, 'line of the log').join('\n')}';
    expect(utf8.encode(DesktopCrashWatch.lastRun(long)).length, lessThanOrEqualTo(DesktopCrashWatch.maxLogBytes));
    expect(DesktopCrashWatch.lastRun(long), endsWith('line of the log'));
  });
}
