import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../shared/utils/diagnostic_log.dart';
import 'desktop.dart';

/// Files dropped on the window from Explorer or Finder, at [position] in
/// logical pixels of the window.
@immutable
class DroppedFiles {
  const DroppedFiles(this.paths, this.position);
  final List<String> paths;
  final ui.Offset position;
}

/// A misspelled word: [start] and [length] in UTF-16 code units (Dart string
/// indexes), with up to five suggestions.
@immutable
class SpellingIssue {
  const SpellingIssue(this.start, this.length, this.suggestions);
  final int start;
  final int length;
  final List<String> suggestions;
  int get end => start + length;
}

/// «Запускать при входе»: on, and whether the administrator set it for all
/// users (then the user cannot switch it off).
typedef LaunchAtLogin = ({bool enabled, bool managed});

/// A jump list task (Windows: right click on the taskbar button starts
/// `XatBox.exe [arguments]`) or a Dock menu item (macOS: right click on the
/// Dock icon); the running window receives [arguments].
@immutable
class JumpListTask {
  const JumpListTask(this.title, this.arguments);
  final String title;
  final String arguments;
}

/// The `xatbox/desktop` channel of the Windows and macOS runners
/// (windows/runner/windows_shell.cpp, macos/Runner/MainFlutterWindow.swift):
/// the unread badge (taskbar overlay / Dock badge) and attention (flashing
/// button / bouncing icon), the jump list or Dock menu, files dropped on the
/// window and copied to the clipboard, and the command line of a second
/// launch on Windows (a mailto: link, a jump list task).
///
/// Every call is a no-op anywhere else (phones, Linux) and never throws.
abstract final class DesktopShell {
  static const _channel = MethodChannel('xatbox/desktop');

  static bool get available => isDesktop && !kIsWeb && (Platform.isWindows || Platform.isMacOS);

  static final _arguments = StreamController<List<String>>.broadcast();
  static final _drops = StreamController<DroppedFiles>.broadcast();
  static final _sessions = StreamController<bool>.broadcast();
  static Future<List<List<String>>>? _started;

  /// The command line of a later launch, without the program name.
  static Stream<List<String>> get arguments => _arguments.stream;

  /// Files dropped on the window.
  static Stream<DroppedFiles> get drops => _drops.stream;

  /// The screen was locked (true) or unlocked (false).
  static Stream<bool> get sessionLocks => _sessions.stream;

  /// Starts listening; returns the command lines received before (this
  /// launch's own and any that arrived while the app started). Once.
  static Future<List<List<String>>> start() => _started ??= _start();

  static Future<List<List<String>>> _start() async {
    if (!available) return const [];
    _channel.setMethodCallHandler(_onCall);
    try {
      final launches = await _channel.invokeListMethod<Object?>('ready') ?? const [];
      return [for (final l in launches) _strings(l)];
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'windows shell unavailable', error: e);
      return const [];
    }
  }

  static Future<Object?> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'arguments':
        _arguments.add(_strings(call.arguments));
      case 'drop':
        final args = call.arguments;
        if (args is! Map) return null;
        final ratio = ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1;
        final x = (args['x'] as num?)?.toDouble() ?? 0;
        final y = (args['y'] as num?)?.toDouble() ?? 0;
        final paths = _strings(args['paths']);
        if (paths.isNotEmpty) _drops.add(DroppedFiles(paths, ui.Offset(x / ratio, y / ratio)));
      case 'session':
        final args = call.arguments;
        if (args is Map && args['locked'] is bool) _sessions.add(args['locked'] as bool);
    }
    return null;
  }

  static List<String> _strings(Object? value) =>
      value is List ? [for (final v in value) if (v is String) v] : const [];

  /// The count on the taskbar button (overlay icon) or the Dock icon; 0
  /// removes it. [description] is what screen readers say for it (Windows).
  static Future<void> setBadge(int count, {String description = ''}) async {
    if (!available) return;
    try {
      if (count <= 0) {
        await _channel.invokeMethod<void>('setBadge');
        return;
      }
      if (Platform.isMacOS) {
        await _channel.invokeMethod<void>('setBadge', {'label': badgeLabel(count)});
        return;
      }
      final bgra = await _renderBadge(badgeLabel(count));
      await _channel.invokeMethod<void>('setBadge', {
        'bgra': bgra,
        'width': _badgeSize,
        'height': _badgeSize,
        'description': description,
      });
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'taskbar badge failed', error: e);
    }
  }

  /// Flashes the taskbar button (Windows) or bounces the Dock icon once
  /// (macOS) until the window is activated; nothing while it is in front.
  static Future<void> flash() => _call('flash');

  static Future<void> setJumpList(List<JumpListTask> tasks) => _call('setJumpList', {
    'tasks': [
      for (final t in tasks) {'title': t.title, 'arguments': t.arguments},
    ],
  });

  /// Files copied in Explorer or Finder, or a picture without text (a
  /// screenshot) saved as PNG into [directory]; empty otherwise (Flutter
  /// pastes text).
  static Future<List<String>> readClipboardFiles(String directory) async {
    if (!available) return const [];
    try {
      return _strings(await _channel.invokeMethod<Object?>('readClipboardFiles', {'directory': directory}));
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'clipboard read failed', error: e);
      return const [];
    }
  }

  static Future<LaunchAtLogin> getLaunchAtLogin() async {
    if (!available) return (enabled: false, managed: false);
    try {
      final r = await _channel.invokeMapMethod<String, Object?>('getLaunchAtLogin') ?? const {};
      return (enabled: r['enabled'] == true, managed: r['managed'] == true);
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'launch at login unknown', error: e);
      return (enabled: false, managed: false);
    }
  }

  /// Starts XatBox hidden in the tray / menu bar when the user signs in.
  static Future<bool> setLaunchAtLogin(bool enabled) => _bool('setLaunchAtLogin', {'enabled': enabled});

  /// Ctrl+Alt+M / ⌃⌥M new message, Ctrl+Alt+X / ⌃⌥X XatBox in front, from
  /// any program; false when another program holds a combination.
  static Future<bool> setGlobalHotkeys(bool enabled) => _bool('setGlobalHotkeys', {'enabled': enabled});

  /// Drags local files out of the window (to the desktop, Explorer, Finder)
  /// while the mouse button is down.
  static Future<bool> startFileDrag(List<String> paths) => _bool('startFileDrag', {'paths': paths});

  /// Quick Look on the Mac; Explorer's preview handler in a window on
  /// Windows. False when the system has no preview for the type.
  static Future<bool> quickLook(List<String> paths) => _bool('quickLook', {'paths': paths});

  /// The misspelled words of [text] by the system dictionaries.
  static Future<List<SpellingIssue>> spellCheck(String text) async {
    if (!available || text.trim().isEmpty) return const [];
    try {
      final list = await _channel.invokeListMethod<Object?>('spellCheck', {'text': text}) ?? const [];
      return [
        for (final e in list)
          if (e is Map && e['start'] is int && e['length'] is int)
            SpellingIssue(e['start'] as int, e['length'] as int, _strings(e['suggestions'])),
      ];
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'spell check failed', error: e);
      return const [];
    }
  }

  /// Seconds since the last keyboard or mouse input anywhere.
  static Future<double> idleSeconds() async {
    if (!available) return 0;
    try {
      return (await _channel.invokeMethod<num>('idleSeconds'))?.toDouble() ?? 0;
    } on Object {
      return 0;
    }
  }

  static Future<bool> _bool(String method, Object? arguments) async {
    if (!available) return false;
    try {
      return await _channel.invokeMethod<bool>(method, arguments) ?? false;
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'desktop shell $method failed', error: e);
      return false;
    }
  }

  /// macOS: makes XatBox the app for mailto: links (the system asks the
  /// user to confirm). False when it did not happen.
  static Future<bool> setDefaultMailApp() async {
    if (!available || !Platform.isMacOS) return false;
    try {
      return await _channel.invokeMethod<bool>('setDefaultMailApp') ?? false;
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'default mail app not set', error: e);
      return false;
    }
  }

  static Future<void> _call(String method, [Object? arguments]) async {
    if (!available) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'windows shell $method failed', error: e);
    }
  }

  static const _badgeSize = 32;

  /// The text of the badge (pure, unit-tested): up to two digits, `99+`.
  @visibleForTesting
  static String badgeLabel(int count) => count > 99 ? '99+' : '$count';

  /// A red disc with the white count, as top-down straight-alpha BGRA.
  static Future<Uint8List> _renderBadge(String label) async {
    const size = _badgeSize * 1.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawCircle(const ui.Offset(size / 2, size / 2), size / 2, ui.Paint()..color = const ui.Color(0xFFDC2626));
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: ui.TextAlign.center,
              fontSize: label.length > 2 ? 13 : (label.length > 1 ? 17 : 21),
              fontWeight: ui.FontWeight.w700,
            ),
          )
          ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFFFFFFF)))
          ..addText(label);
    final paragraph = builder.build()..layout(const ui.ParagraphConstraints(width: size));
    canvas.drawParagraph(paragraph, ui.Offset(0, (size - paragraph.height) / 2));
    final image = await recorder.endRecording().toImage(_badgeSize, _badgeSize);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      final rgba = data!.buffer.asUint8List();
      final bgra = Uint8List(rgba.length);
      for (var i = 0; i < rgba.length; i += 4) {
        bgra[i] = rgba[i + 2];
        bgra[i + 1] = rgba[i + 1];
        bgra[i + 2] = rgba[i];
        bgra[i + 3] = rgba[i + 3];
      }
      return bgra;
    } finally {
      image.dispose();
    }
  }
}
