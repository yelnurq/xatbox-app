import 'dart:async';
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/platform/desktop.dart';
import '../../core/platform/desktop_keys.dart';
import '../../core/platform/desktop_shell.dart';
import '../utils/diagnostic_log.dart';

/// Where files go on the desktop app: dropped from Explorer on this area, or
/// pasted with Ctrl+V while the focus is inside it (files copied in
/// Explorer, a screenshot). The deepest target under the drop point wins, so
/// the composer window takes files dropped on it and the page behind takes
/// the rest. Phones get [child] unchanged.
class DesktopDropTarget extends StatefulWidget {
  const DesktopDropTarget({super.key, required this.onFiles, required this.child, this.enabled = true});

  /// Local paths, in the order Windows gave them.
  final void Function(List<String> paths) onFiles;
  final bool enabled;
  final Widget child;

  @override
  State<DesktopDropTarget> createState() => _DesktopDropTargetState();
}

class _DesktopDropTargetState extends State<DesktopDropTarget> {
  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return widget.child;
    // MetaData marks this area in hit tests (see DesktopFileRouter.drop).
    return MetaData(metaData: this, behavior: HitTestBehavior.translucent, child: widget.child);
  }
}

/// Routes dropped and pasted files to the [DesktopDropTarget]s. Started
/// once by the desktop integration.
abstract final class DesktopFileRouter {
  static StreamSubscription<DroppedFiles>? _drops;
  static bool _pasteListening = false;

  /// Takes files dropped where no target is (the whole window otherwise).
  static void Function(List<String> paths)? _fallback;

  static void start({void Function(List<String> paths)? fallback}) {
    if (!DesktopShell.available) return;
    _fallback = fallback;
    _drops ??= DesktopShell.drops.listen((d) {
      if (!drop(d.paths, d.position)) _fallback?.call(d.paths);
    });
    if (!_pasteListening) {
      _pasteListening = true;
      HardwareKeyboard.instance.addHandler(_onKey);
    }
  }

  /// Hands [paths] to the deepest enabled target under [position] (logical
  /// pixels of the window); false when no target is there.
  static bool drop(List<String> paths, Offset position) {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null || paths.isEmpty) return false;
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, position, view.viewId);
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData) {
        final state = target.metaData;
        if (state is _DesktopDropTargetState && state.mounted && state.widget.enabled) {
          state.widget.onFiles(paths);
          return true;
        }
      }
    }
    return false;
  }

  /// Ctrl+V (⌘V): the key still reaches the text field (text is pasted as
  /// usual); files or a picture on the clipboard go to the target around
  /// the focus.
  static bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.keyV) return false;
    final keys = HardwareKeyboard.instance;
    final command = usesCommandKey ? keys.isMetaPressed : keys.isControlPressed;
    if (!command || keys.isAltPressed || keys.isShiftPressed) return false;
    final focus = FocusManager.instance.primaryFocus?.context;
    final state = focus?.findAncestorStateOfType<_DesktopDropTargetState>();
    if (state == null || !state.widget.enabled) return false;
    unawaited(_paste(state));
    return false;
  }

  static Future<void> _paste(_DesktopDropTargetState target) async {
    try {
      final dir = Directory(p.join((await getTemporaryDirectory()).path, 'clipboard'));
      await dir.create(recursive: true);
      final files = await DesktopShell.readClipboardFiles(dir.path);
      if (files.isEmpty || !target.mounted) return;
      target.widget.onFiles([for (final f in files) await _friendlyName(f, dir.path)]);
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'paste files failed', error: e);
    }
  }

  /// `clipboard-<ms>.png` from the runner → `image-2026-09-18-140305.png`,
  /// the name the recipient sees. Files copied in Explorer keep theirs.
  static Future<String> _friendlyName(String path, String clipboardDir) async {
    if (p.dirname(path) != clipboardDir) return path;
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${now.year}-${two(now.month)}-${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}';
    try {
      return (await File(path).rename(p.join(clipboardDir, 'image-$stamp${p.extension(path)}'))).path;
    } on FileSystemException {
      return path;
    }
  }
}
