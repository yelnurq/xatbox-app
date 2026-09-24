import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/utils/diagnostic_log.dart';
import 'desktop_crash.dart';
import 'desktop_shell.dart';
import 'mac_sandbox_migration.dart';

/// Windows / macOS / Linux build of the app (the same code base as the phone
/// app; only the platform integrations differ).
///
/// `flutter test` runs on a desktop host but the suite describes the phone
/// app, so tests see a phone unless they set [debugDesktopOverride].
bool get isDesktop =>
    debugDesktopOverride ??
    (!kIsWeb && !_underFlutterTest && (Platform.isWindows || Platform.isMacOS || Platform.isLinux));

/// Test hook: forces [isDesktop] (null = detect).
@visibleForTesting
bool? debugDesktopOverride;

final bool _underFlutterTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// Background work of the real desktop app (polling, idle watch): not in
/// widget tests, even when they lay the app out as a desktop.
bool get desktopBackgroundWork => isDesktop && !_underFlutterTest;

/// Android / iOS: FCM, CallKit, launcher widgets and the other phone-only
/// integrations are available.
bool get isMobileOs => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// Smallest window the two-pane layouts still fit in.
const desktopMinWindowSize = Size(1024, 680);
const _initialWindowSize = Size(1280, 820);

/// Desktop setup before the first frame: media backends and the window.
/// No-op on phones; never throws.
Future<void> initDesktop() async {
  if (!isDesktop) return;
  // Before anything opens the app's files (the log is the first).
  await migrateMacSandboxData();
  // Reads how the last run ended before this run's log begins.
  await DesktopCrashWatch.start();
  await _startFileLog();
  // just_audio / video_player have no Windows and Linux implementations of
  // their own: route both through libmpv (media_kit). macOS keeps AVFoundation.
  if (Platform.isWindows || Platform.isLinux) {
    try {
      JustAudioMediaKit.ensureInitialized();
      VideoPlayerMediaKit.ensureInitialized(windows: true, linux: true);
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'media backend unavailable', error: e);
    }
  }
  // Started at sign-in («Запускать при входе»): the window waits in the tray.
  final hidden = (await DesktopShell.start()).any((a) => a.contains('--hidden'));
  try {
    await windowManager.ensureInitialized();
    final saved = await _WindowPlacement.restore();
    final options = WindowOptions(
      title: 'XatBox',
      size: saved?.bounds.size ?? _initialWindowSize,
      minimumSize: desktopMinWindowSize,
      center: saved == null,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      if (saved != null) {
        await windowManager.setBounds(saved.bounds);
        if (saved.maximized && !hidden) await windowManager.maximize();
      }
      if (hidden) {
        await windowManager.hide();
        return;
      }
      await windowManager.show();
      await windowManager.focus();
    });
    windowManager.addListener(_WindowPlacement());
  } on Object catch (e) {
    DiagnosticLog.warn('desktop', 'window setup failed', error: e);
  }
}

/// The saved window of the last run (`window.json` in the app support
/// folder), or null when it would not be fully usable now.
@immutable
class WindowPlacement {
  const WindowPlacement(this.bounds, {this.maximized = false});
  final Rect bounds;
  final bool maximized;

  Map<String, Object> toJson() => {
    'x': bounds.left,
    'y': bounds.top,
    'width': bounds.width,
    'height': bounds.height,
    'maximized': maximized,
  };

  static WindowPlacement? fromJson(Object? json) {
    if (json is! Map) return null;
    double? n(String k) => (json[k] as num?)?.toDouble();
    final x = n('x'), y = n('y'), w = n('width'), h = n('height');
    if (x == null || y == null || w == null || h == null) return null;
    return WindowPlacement(Rect.fromLTWH(x, y, w, h), maximized: json['maximized'] == true);
  }

  /// [saved] when its title bar lies on one of [screens] (the work areas):
  /// a monitor that was unplugged must not strand the window off screen.
  /// The size is kept within [minimum] and the screen (pure, unit-tested).
  static WindowPlacement? usable(WindowPlacement? saved, List<Rect> screens, {Size minimum = desktopMinWindowSize}) {
    if (saved == null) return null;
    final b = saved.bounds;
    // A point in the title bar, a little in from the left edge.
    final grip = Offset(b.left + (b.width / 2).clamp(0, 120), b.top + 16);
    final screen = screens.where((s) => s.contains(grip)).firstOrNull;
    if (screen == null) return null;
    final width = b.width.clamp(minimum.width, screen.width.clamp(minimum.width, double.infinity));
    final height = b.height.clamp(minimum.height, screen.height.clamp(minimum.height, double.infinity));
    return WindowPlacement(Rect.fromLTWH(b.left, b.top, width, height), maximized: saved.maximized);
  }
}

/// Saves the window's place and size a moment after it stops moving; the
/// normal bounds survive while it is maximised.
class _WindowPlacement with WindowListener {
  Timer? _save;
  Rect? _normal;

  static Future<File> _file() async => File(p.join((await getApplicationSupportDirectory()).path, 'window.json'));

  static Future<WindowPlacement?> restore() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final saved = WindowPlacement.fromJson(jsonDecode(await file.readAsString()));
      final displays = await screenRetriever.getAllDisplays();
      final screens = [
        for (final d in displays)
          (d.visiblePosition ?? Offset.zero) & (d.visibleSize ?? d.size),
      ];
      return WindowPlacement.usable(saved, screens);
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'window placement not restored', error: e);
      return null;
    }
  }

  void _schedule() {
    _save?.cancel();
    _save = Timer(const Duration(milliseconds: 600), () => unawaited(_write()));
  }

  Future<void> _write() async {
    try {
      if (await windowManager.isMinimized() || !await windowManager.isVisible()) return;
      final maximized = await windowManager.isMaximized();
      if (!maximized) _normal = await windowManager.getBounds();
      final bounds = _normal;
      if (bounds == null) return;
      await (await _file()).writeAsString(jsonEncode(WindowPlacement(bounds, maximized: maximized).toJson()));
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'window placement not saved', error: e);
    }
  }

  @override
  void onWindowResized() => _schedule();

  @override
  void onWindowMoved() => _schedule();

  @override
  void onWindowMaximize() => _schedule();

  @override
  void onWindowUnmaximize() => _schedule();
}

/// Desktop: the diagnostics log is also appended to
/// `<app support>/logs/xatbox.log`, line by line and synchronously, so the
/// last steps before a crash of a native plugin survive it. Redacted like
/// every diagnostics record; the file restarts once it passes 1 MB.
Future<void> _startFileLog() async {
  try {
    final dir = Directory(p.join((await getApplicationSupportDirectory()).path, 'logs'));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'xatbox.log'));
    if (await file.exists() && await file.length() > 1024 * 1024) await file.writeAsString('');
    void write(String line) {
      try {
        file.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
      } on Object {
        // A full or locked disk must not break the app.
      }
    }

    write('--- ${DateTime.now().toIso8601String()} start ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    DiagnosticLog.addSink(
      (r) => write('${r.time.toIso8601String()} ${r.level.name} ${r.area}: ${r.message}${r.error == null ? '' : ' | ${r.error}'}'),
    );
  } on Object catch (e) {
    DiagnosticLog.warn('desktop', 'file log unavailable', error: e);
  }
}

/// Shows, restores and focuses the main window (incoming call, notification
/// tap, tray icon). No-op on phones; never throws.
Future<void> bringWindowToFront() async {
  if (!isDesktop) return;
  try {
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.show();
    await windowManager.focus();
  } on Object catch (e) {
    DiagnosticLog.warn('desktop', 'focus window failed', error: e);
  }
}

/// The window is visible and focused (a notification would be redundant).
/// Always true on phones: their notifications follow the lifecycle instead.
Future<bool> desktopWindowFocused() async {
  if (!isDesktop) return true;
  try {
    return await windowManager.isVisible() && await windowManager.isFocused();
  } on Object {
    return WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }
}

/// Texts of the tray icon menu (localized by the caller). A null module
/// text leaves the module out of the menu (chat switched off).
class DesktopTrayTexts {
  const DesktopTrayTexts({
    required this.open,
    required this.quit,
    this.compose,
    this.mail,
    this.chat,
    this.calendar,
  });
  final String open;
  final String quit;
  final String? compose;
  final String? mail;
  final String? chat;
  final String? calendar;
}

/// Closing the window hides it to the tray, so chat notifications and
/// incoming calls keep arriving (the socket stays open); «Выход» in the tray
/// menu quits. Messengers on desktop behave this way.
class DesktopTray with TrayListener, WindowListener {
  DesktopTray._();

  static final instance = DesktopTray._();
  bool _installed = false;
  bool _quitting = false;

  /// «Новое письмо», «Почта», «Чат», «Календарь» of the menu: the menu item
  /// key (`compose`, `mail`, `chat`, `calendar`).
  void Function(String key)? onCommand;

  final _beforeQuit = <Future<void> Function()>[];

  /// Work done when the user quits (an update installed on quit).
  void addBeforeQuit(Future<void> Function() action) => _beforeQuit.add(action);

  /// Called when the «X» hides the window to the tray, before it hides:
  /// the lock screen locks at once when «Запрашивать PIN при закрытии
  /// окна» is on, so the window comes back asking for the PIN.
  void Function()? onClosedToTray;

  Future<void> install(DesktopTrayTexts texts) async {
    if (!isDesktop || _installed) return;
    _installed = true;
    try {
      await trayManager.setIcon(Platform.isWindows ? 'assets/brand/tray.ico' : 'assets/brand/tray.png');
      if (!Platform.isLinux) await trayManager.setToolTip('XatBox');
      await setTexts(texts);
      trayManager.addListener(this);
      windowManager.addListener(this);
      await windowManager.setPreventClose(true);
    } on Object catch (e) {
      // Without a tray icon closing the window must quit, never strand it.
      DiagnosticLog.warn('desktop', 'tray unavailable', error: e);
      await _safe(() => windowManager.setPreventClose(false));
    }
  }

  /// Rebuilds the menu (language changed).
  Future<void> setTexts(DesktopTrayTexts texts) {
    final modules = [
      if (texts.compose case final label?) MenuItem(key: 'compose', label: label),
      if (texts.mail case final label?) MenuItem(key: 'mail', label: label),
      if (texts.chat case final label?) MenuItem(key: 'chat', label: label),
      if (texts.calendar case final label?) MenuItem(key: 'calendar', label: label),
    ];
    return _safe(
      () => trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'open', label: texts.open),
            MenuItem.separator(),
            if (modules.isNotEmpty) ...[...modules, MenuItem.separator()],
            MenuItem(key: 'quit', label: texts.quit),
          ],
        ),
      ),
    );
  }

  /// The icon's hover text (the unread count); Linux trays have none.
  Future<void> setToolTip(String text) async {
    if (!_installed || Platform.isLinux) return;
    await _safe(() => trayManager.setToolTip(text));
  }

  Future<void> quit() async {
    if (_quitting) return;
    _quitting = true;
    DesktopCrashWatch.quitting();
    for (final action in List.of(_beforeQuit)) {
      try {
        await action().timeout(const Duration(seconds: 5));
      } on Object catch (e) {
        DiagnosticLog.warn('desktop', 'before quit failed', error: e);
      }
    }
    await _safe(() => trayManager.destroy());
    await _safe(() => windowManager.setPreventClose(false));
    await _safe(() => windowManager.destroy());
  }

  @override
  void onWindowClose() {
    if (_quitting) return;
    onClosedToTray?.call();
    unawaited(_safe(() => windowManager.hide()));
  }

  @override
  void onTrayIconMouseDown() => unawaited(bringWindowToFront());

  @override
  void onTrayIconRightMouseDown() => unawaited(_safe(() => trayManager.popUpContextMenu()));

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open':
        unawaited(bringWindowToFront());
      case 'quit':
        unawaited(quit());
      case final key?:
        onCommand?.call(key);
    }
  }

  static Future<void> _safe(Future<void> Function() f) async {
    try {
      await f();
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'tray/window call failed', error: e);
    }
  }
}
