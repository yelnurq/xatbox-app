import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/utils/diagnostic_log.dart';
import '../errors/error_scrubber.dart';

/// The previous run of the desktop app ended without quitting: a crash of the
/// app or of a native plugin, or the process was killed.
@immutable
class UncleanExit {
  const UncleanExit({required this.startedAt, required this.version, required this.log});

  /// When that run started.
  final DateTime startedAt;

  /// Its version ("1.4.0+118").
  final String version;

  /// The end of its log (`xatbox.log`), redacted.
  final String log;
}

/// Notices that the desktop app ended the last time without quitting, so it
/// can offer to send that run's log (Windows and Linux).
///
/// At start a marker file is written and it is removed by a proper quit
/// (DesktopTray.quit, also the one before an update). A marker found at the
/// next start is an unclean exit, except when the computer has restarted
/// since (a shutdown ends the app in the tray without a quit) or the version
/// changed (an installer run by hand closes the app). macOS is left out: its
/// app can quit through the system (⌘Q, log out) without the app hearing of it.
class DesktopCrashWatch {
  DesktopCrashWatch._();

  /// Found at start, until the offer is answered.
  static UncleanExit? pending;

  static File? _marker;

  static const maxLogBytes = 8000;

  static bool get supported => Platform.isWindows || Platform.isLinux;

  /// Reads what the last run left and marks this one as running. Call before
  /// the file log starts writing this run.
  static Future<void> start() async {
    if (!supported) return;
    try {
      final dir = (await getApplicationSupportDirectory()).path;
      final marker = File(p.join(dir, 'running.json'));
      _marker = marker;
      final info = await PackageInfo.fromPlatform();
      final version = '${info.version}+${info.buildNumber}';
      if (await marker.exists()) {
        pending = decide(
          marker: await marker.readAsString(),
          version: version,
          bootedAt: _bootTime(),
          log: await _lastLog(File(p.join(dir, 'logs', 'xatbox.log'))),
        );
        if (pending != null) DiagnosticLog.warn('desktop', 'previous run ended without quitting (${pending!.version})');
      }
      await marker.writeAsString(jsonEncode({'started_at': DateTime.now().toUtc().toIso8601String(), 'version': version}));
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'crash watch unavailable', error: e);
    }
  }

  /// A proper quit: the next start finds no marker.
  static void quitting() {
    try {
      _marker?.deleteSync();
    } on Object {
      // Already gone, or the disk is not there: nothing to report either way.
    }
  }

  /// The unclean exit a [marker] left, or null when it was not one.
  @visibleForTesting
  static UncleanExit? decide({required String marker, required String version, required DateTime? bootedAt, required String log}) {
    try {
      final json = jsonDecode(marker) as Map<String, Object?>;
      final started = DateTime.parse(json['started_at']! as String);
      final was = (json['version'] as String?) ?? '';
      if (was != version) return null; // reinstalled or updated by hand
      if (bootedAt != null && bootedAt.isAfter(started)) return null; // shut down with the computer
      return UncleanExit(startedAt: started, version: was, log: log);
    } on Object {
      return null;
    }
  }

  /// The previous run's lines: the log up to this run's start, its end only.
  @visibleForTesting
  static String lastRun(String log) {
    final start = log.lastIndexOf('\n--- ');
    final run = start >= 0 ? log.substring(start + 1) : log;
    final scrubbed = run.split('\n').map(ErrorScrubber.scrub).join('\n').trim();
    final bytes = utf8.encode(scrubbed);
    if (bytes.length <= maxLogBytes) return scrubbed;
    return utf8.decode(bytes.sublist(bytes.length - maxLogBytes), allowMalformed: true);
  }

  static Future<String> _lastLog(File file) async {
    try {
      if (!await file.exists()) return '';
      return lastRun(await file.readAsString());
    } on Object {
      return '';
    }
  }

  /// When the computer started, or null when unknown.
  static DateTime? _bootTime() {
    try {
      Duration? up;
      if (Platform.isWindows) {
        final ticks = DynamicLibrary.open('kernel32.dll').lookupFunction<Uint64 Function(), int Function()>('GetTickCount64');
        up = Duration(milliseconds: ticks());
      } else if (Platform.isLinux) {
        final seconds = double.parse(File('/proc/uptime').readAsStringSync().split(' ').first);
        up = Duration(milliseconds: (seconds * 1000).round());
      }
      return up == null ? null : DateTime.now().toUtc().subtract(up);
    } on Object {
      return null;
    }
  }
}
