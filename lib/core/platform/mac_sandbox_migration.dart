import 'dart:io';

import 'package:path/path.dart' as p;

import '../../shared/utils/diagnostic_log.dart';

/// The macOS app's bundle identifier (macos/Runner/Configs/AppInfo.xcconfig).
const macBundleId = 'kz.xatbox.xatboxMobile';

/// Where the sandboxed builds kept their data and where the unsandboxed ones
/// keep it (pure, unit-tested): `(from, to)` for Application Support.
(String, String) macSandboxMove(String home) => (
  p.join(home, 'Library', 'Containers', macBundleId, 'Data', 'Library', 'Application Support', macBundleId),
  p.join(home, 'Library', 'Application Support', macBundleId),
);

/// macOS builds up to 0.2.0 ran in the App Sandbox; later ones do not (so
/// the app can replace itself when it updates). Their data — the mail and
/// chat cache, the desktop settings, the window — moves once from the
/// sandbox container to ~/Library/Application Support, before anything
/// opens it. Never throws; a failure only means a fresh cache.
Future<void> migrateMacSandboxData() async {
  if (!Platform.isMacOS) return;
  final home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) return;
  final (from, to) = macSandboxMove(home);
  // Still sandboxed (a debug build), already moved, or nothing to move.
  if (Platform.environment['APP_SANDBOX_CONTAINER_ID'] != null) return;
  if (Directory(to).existsSync() || !Directory(from).existsSync()) return;
  try {
    Directory(p.dirname(to)).createSync(recursive: true);
    final r = await Process.run('/bin/cp', ['-Rp', from, to]);
    if (r.exitCode != 0) throw StateError('cp: ${r.stderr}');
    DiagnosticLog.info('desktop', 'sandbox data moved to Application Support');
  } on Object catch (e) {
    DiagnosticLog.warn('desktop', 'sandbox data not moved', error: e);
  }
}
