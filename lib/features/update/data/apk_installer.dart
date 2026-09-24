import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../shared/utils/diagnostic_log.dart';

enum InstallStart {
  /// The system package installer is on screen.
  started,

  /// Android 8+: «Install unknown apps» is off for XatBox.
  needsPermission,
  failed,
}

/// The Android package installer behind an interface (fake in tests).
abstract class ApkInstaller {
  Future<bool> canRequestInstalls();
  Future<void> openInstallSettings();
  Future<InstallStart> install(String path);
}

/// Desktop installers that can also run once the app has quit
/// («Обновить при выходе»).
abstract interface class QuitInstaller {
  Future<void> installAfterQuit(String path);
}

/// Windows: runs the downloaded Inno Setup installer silently and quits,
/// so the installer can replace the files; it starts the new build when it
/// is done (windows/installer/xatbox.iss, `[Run]` for silent installs).
class WindowsSetupInstaller implements ApkInstaller, QuitInstaller {
  const WindowsSetupInstaller({this.quit});

  /// Leaves the app once the installer runs (the tray-aware quit).
  final Future<void> Function()? quit;

  @override
  Future<bool> canRequestInstalls() async => Platform.isWindows;

  @override
  Future<void> openInstallSettings() async {}

  /// Why the last start failed (shown under «Не удалось запустить…»).
  static String? lastError;

  /// Starts the installer: CreateProcess, retried while an antivirus still
  /// holds the fresh file (error 32), then ShellExecute through PowerShell
  /// `Start-Process`, which also shows the UAC prompt Windows may demand for
  /// a program called «Setup» (error 740). With [windowsSetupArgs] passing
  /// `/CURRENTUSER` the elevated path should no longer be reached; it stays
  /// as a fallback. Returns false with [lastError].
  static Future<bool> launch(String path, List<String> args) async {
    Object? last;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await Process.start(path, args, mode: ProcessStartMode.detached);
        lastError = null;
        return true;
      } on ProcessException catch (e) {
        last = e;
        DiagnosticLog.warn('update', 'installer start attempt ${attempt + 1} failed (${e.errorCode})', error: e);
        if (e.errorCode == 740) break; // needs elevation: only ShellExecute helps
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    try {
      String quote(String v) => "'${v.replaceAll("'", "''")}'";
      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'Start-Process -FilePath ${quote(path)} -ArgumentList ${args.map(quote).join(',')}',
      ]);
      if (result.exitCode == 0) {
        DiagnosticLog.info('update', 'installer started through Start-Process');
        lastError = null;
        return true;
      }
      last = '${result.stderr}'.trim().isEmpty ? 'Start-Process exit ${result.exitCode}' : '${result.stderr}'.trim();
    } on Object catch (e) {
      last = e;
    }
    lastError = last is ProcessException ? '${last.message} (${last.errorCode})' : '$last';
    DiagnosticLog.warn('update', 'installer not started: $lastError');
    return false;
  }

  /// «Обновить при выходе»: the installer runs hidden while the app quits
  /// and does not start XatBox again (`/NOLAUNCH`, windows/installer/xatbox.iss).
  @override
  Future<void> installAfterQuit(String path) async {
    if (await launch(path, windowsSetupArgs(silent: true, launchAfter: false))) {
      DiagnosticLog.info('update', 'installer started on quit');
    }
  }

  @override
  Future<InstallStart> install(String path) async {
    if (!await launch(path, windowsSetupArgs(silent: false, launchAfter: true))) {
      return InstallStart.failed;
    }
    DiagnosticLog.info('update', 'installer started');
    await quit?.call();
    return InstallStart.started;
  }
}

/// Arguments for the Inno Setup installer of an update.
///
/// `/CURRENTUSER` is the important one. XatBox only updates itself when it
/// lives in the user's own profile ([isMachineWideInstall] gates that), and
/// then the installer needs no administrator rights at all. Left to itself
/// Inno Setup may still decide to restart elevated — it remembers how the
/// app was installed the first time — and an elevated restart runs a copy of
/// Setup in %TEMP% named `<installer>.tmp`. Windows then asks the user to
/// vouch for that copy's publisher. Saying «this is a per-user install»
/// removes the restart, and with it the question.
///
/// Pure, unit-tested; [perUser] is false only for a machine-wide install,
/// which does not reach this code.
List<String> windowsSetupArgs({
  required bool silent,
  required bool launchAfter,
  bool perUser = true,
}) => [
  silent ? '/VERYSILENT' : '/SILENT',
  '/SUPPRESSMSGBOXES',
  '/NORESTART',
  '/CLOSEAPPLICATIONS',
  if (perUser) '/CURRENTUSER',
  if (!launchAfter) '/NOLAUNCH',
];

/// macOS: the downloaded zip holds the new XatBox.app. It is unpacked next
/// to the running app's temporary files; a small detached shell script
/// waits for XatBox to quit, swaps the bundle in place (the old one is kept
/// until the new one is in, and put back if the move fails), clears the
/// quarantine flag and starts the new build (not after «Обновить при
/// выходе»). The app is not sandboxed, so it may replace its own bundle.
class MacAppInstaller implements ApkInstaller, QuitInstaller {
  const MacAppInstaller({this.quit});

  final Future<void> Function()? quit;

  @override
  Future<bool> canRequestInstalls() async => Platform.isMacOS;

  @override
  Future<void> openInstallSettings() async {}

  @override
  Future<InstallStart> install(String path) async {
    if (!await _start(path, relaunch: true)) return InstallStart.failed;
    await quit?.call();
    return InstallStart.started;
  }

  @override
  Future<void> installAfterQuit(String path) async {
    await _start(path, relaunch: false);
  }

  Future<bool> _start(String zip, {required bool relaunch}) async {
    try {
      final bundle = macAppBundle(Platform.resolvedExecutable);
      if (bundle == null) throw StateError('not inside an .app: ${Platform.resolvedExecutable}');
      final staging = await Directory(File(zip).parent.path).createTemp('xatbox-app-');
      final unzip = await Process.run('/usr/bin/ditto', ['-x', '-k', zip, staging.path]);
      if (unzip.exitCode != 0) throw StateError('ditto: ${unzip.stderr}');
      final fresh = '${staging.path}/XatBox.app';
      if (!Directory(fresh).existsSync()) throw StateError('no XatBox.app in $zip');
      final script = File('${staging.path}/install.sh')
        ..writeAsStringSync(macSwapScript(pid: pid, bundle: bundle, fresh: fresh, relaunch: relaunch));
      await Process.start('/bin/sh', [script.path], mode: ProcessStartMode.detached);
      DiagnosticLog.info('update', 'macOS update scheduled for $bundle');
      return true;
    } on Object catch (e) {
      DiagnosticLog.warn('update', 'macOS update not started', error: e);
      return false;
    }
  }
}

/// The .app bundle of [executable] (…/XatBox.app/Contents/MacOS/XatBox), or
/// null (pure, unit-tested).
String? macAppBundle(String executable) {
  const marker = '.app/Contents/MacOS/';
  final i = executable.lastIndexOf(marker);
  return i < 0 ? null : executable.substring(0, i + 4);
}

/// The swap script of [MacAppInstaller] (pure, unit-tested).
String macSwapScript({required int pid, required String bundle, required String fresh, required bool relaunch}) {
  String q(String s) => "'${s.replaceAll("'", r"'\''")}'";
  return [
    '#!/bin/sh',
    '# XatBox update: wait for the app to quit, then swap the bundle.',
    'while kill -0 $pid 2>/dev/null; do sleep 0.5; done',
    'OLD=${q('$bundle.old')}',
    'rm -rf "\$OLD"',
    'if mv ${q(bundle)} "\$OLD"; then',
    '  if mv ${q(fresh)} ${q(bundle)}; then',
    '    rm -rf "\$OLD"',
    '  else',
    '    mv "\$OLD" ${q(bundle)}',
    '  fi',
    'fi',
    '/usr/bin/xattr -dr com.apple.quarantine ${q(bundle)} 2>/dev/null',
    if (relaunch) '/usr/bin/open ${q(bundle)}',
    '',
  ].join('\n');
}

/// Linux: no silent install. The downloaded .deb is copied to the user's
/// «Загрузки» and opened with the system's package installer (xdg-open:
/// GNOME Software, Discover, gdebi…), which asks for the administrator
/// password. The user restarts XatBox afterwards.
class LinuxPackageInstaller implements ApkInstaller {
  LinuxPackageInstaller({required this.downloads, this.open = _xdgOpen});

  /// The folder the package is saved to (null: it is opened where it is).
  final Future<Directory?> Function() downloads;

  /// Opens a file with the desktop's default program; false when it failed.
  final Future<bool> Function(String path) open;

  /// Where the last package was saved.
  String? lastPath;

  static Future<bool> _xdgOpen(String path) async {
    try {
      await Process.start('xdg-open', [path], mode: ProcessStartMode.detached);
      return true;
    } on Object catch (e) {
      DiagnosticLog.warn('update', 'xdg-open failed', error: e);
      return false;
    }
  }

  @override
  Future<bool> canRequestInstalls() async => true;

  @override
  Future<void> openInstallSettings() async {}

  @override
  Future<InstallStart> install(String path) async {
    var target = path;
    try {
      final dir = await downloads();
      if (dir != null) {
        await dir.create(recursive: true);
        target = '${dir.path}/${linuxPackageName(path)}';
        await File(path).copy(target);
      }
    } on Object catch (e) {
      DiagnosticLog.warn('update', 'package not copied to Downloads', error: e);
      target = path;
    }
    lastPath = target;
    if (!await open(target)) return InstallStart.failed;
    DiagnosticLog.info('update', 'package opened: $target');
    return InstallStart.started;
  }
}

/// `XatBox-<code>.deb` for the downloader's `xatbox-<code>-<abi>-<sha8>.deb`
/// (pure, unit-tested).
String linuxPackageName(String downloaded) {
  final name = downloaded.split('/').last;
  final code = RegExp(r'^xatbox-(\d+)-').firstMatch(name)?.group(1);
  return code == null ? name : 'XatBox-$code.deb';
}

/// `xatbox/installer` channel in MainActivity: FileProvider content URI +
/// `ACTION_VIEW` (REQUEST_INSTALL_PACKAGES).
class ChannelApkInstaller implements ApkInstaller {
  const ChannelApkInstaller();

  static const _channel = MethodChannel('xatbox/installer');

  bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> canRequestInstalls() async {
    if (!_android) return false;
    try {
      return await _channel.invokeMethod<bool>('canRequestInstalls') ?? false;
    } on Object catch (e) {
      DiagnosticLog.warn('update', 'install permission unknown', error: e);
      return false;
    }
  }

  @override
  Future<void> openInstallSettings() async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>('openInstallSettings');
    } on Object catch (e) {
      DiagnosticLog.warn('update', 'install settings not opened', error: e);
    }
  }

  @override
  Future<InstallStart> install(String path) async {
    if (!_android) return InstallStart.failed;
    try {
      final result = await _channel.invokeMethod<String>('install', {'path': path});
      return switch (result) {
        'started' => InstallStart.started,
        'needs_permission' => InstallStart.needsPermission,
        _ => InstallStart.failed,
      };
    } on Object catch (e) {
      DiagnosticLog.warn('update', 'installer not started', error: e);
      return InstallStart.failed;
    }
  }
}
