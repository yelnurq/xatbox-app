import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/localization.dart';
import '../../core/platform/desktop.dart';
import '../../core/platform/desktop_keys.dart';
import '../../core/platform/desktop_shell.dart';
import '../../core/platform/open_file.dart';

/// Desktop gestures of a file shown in the app (a mail attachment): drag it
/// out to the desktop, Explorer or Finder, and Space for a quick look (Quick
/// Look on the Mac, Explorer's preview on Windows, else the default app).
/// The file is fetched while the pointer is over it, so a drag can start at
/// once. Phones get [child] unchanged.
class DesktopFileGestures extends StatefulWidget {
  const DesktopFileGestures({super.key, required this.resolve, required this.child});

  /// The local copy (downloaded or written once); null when unavailable.
  final Future<String?> Function() resolve;
  final Widget child;

  @override
  State<DesktopFileGestures> createState() => _DesktopFileGesturesState();
}

class _DesktopFileGesturesState extends State<DesktopFileGestures> {
  Future<String?>? _file;
  String? _path;
  bool _hover = false;

  Future<String?> _ensure() => _file ??= widget.resolve().then((p) {
    _path = p;
    return p;
  }, onError: (Object _) {
    _file = null;
    return null;
  });

  Future<void> _quickLook() async {
    final path = await _ensure();
    if (path == null) return;
    if (!await DesktopShell.quickLook([path])) await openLocalFile(path);
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return widget.child;
    return MouseRegion(
      onEnter: (_) {
        setState(() => _hover = true);
        unawaited(_ensure());
      },
      onExit: (_) => setState(() => _hover = false),
      child: DesktopKeyBindings(
        enabled: _hover,
        bindings: {const SingleActivator(LogicalKeyboardKey.space): () => unawaited(_quickLook())},
        child: Tooltip(
          message: context.l10n.desktopFileHint,
          waitDuration: const Duration(milliseconds: 800),
          child: GestureDetector(
            onPanStart: (_) {
              final path = _path;
              if (path != null) {
                unawaited(DesktopShell.startFileDrag([path]));
              } else {
                unawaited(_ensure());
              }
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
