import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'desktop.dart';

/// The platform's command key: ⌘ on macOS, Ctrl elsewhere.
bool get usesCommandKey => defaultTargetPlatform == TargetPlatform.macOS;

/// [key] with the command key (Ctrl+N on Windows, ⌘N on the Mac).
SingleActivator commandShortcut(LogicalKeyboardKey key, {bool shift = false}) =>
    SingleActivator(key, control: !usesCommandKey, meta: usesCommandKey, shift: shift);

/// How the command key is written in hints: `Ctrl` or `⌘`.
String get commandKeyLabel => usesCommandKey ? '⌘' : 'Ctrl';

/// Keyboard shortcuts of the web client (`J`, `R`, `/`, `Delete`…) on the
/// desktop app, handled like the web's document-level listener: they work
/// wherever the focus is, not only inside the widget.
///
/// A binding fires while [enabled], the widget's route is on top (no dialog
/// over it) and its page is not an offstage tab. Plain keys are skipped while
/// a text field has the focus, so typing never triggers them; bindings with
/// Ctrl, Alt or Meta work in text fields too. Phones get [child] unchanged.
class DesktopKeyBindings extends StatefulWidget {
  const DesktopKeyBindings({super.key, required this.bindings, required this.child, this.enabled = true});

  final Map<ShortcutActivator, VoidCallback> bindings;
  final bool enabled;
  final Widget child;

  /// A text field (or any editable text) has the keyboard focus.
  static bool get editingText {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.widget is EditableText || context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  /// Whether [activator] needs Ctrl, Alt or Meta (pure, unit-tested).
  static bool hasModifier(ShortcutActivator activator) => switch (activator) {
    SingleActivator(:final control, :final alt, :final meta) => control || alt || meta,
    CharacterActivator(:final control, :final alt, :final meta) => control || alt || meta,
    _ => false,
  };

  @override
  State<DesktopKeyBindings> createState() => _DesktopKeyBindingsState();
}

class _DesktopKeyBindingsState extends State<DesktopKeyBindings> {
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    if (isDesktop) {
      HardwareKeyboard.instance.addHandler(_onKey);
      _listening = true;
    }
  }

  @override
  void dispose() {
    if (_listening) HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (!mounted || !widget.enabled || event is KeyUpEvent) return false;
    final route = ModalRoute.of(context);
    if (!(route?.isCurrent ?? true)) return false;
    if (!TickerMode.valuesOf(context).enabled) return false;
    // A dialog or popup menu has the focus (also over the shell, which sits
    // above the navigator and has no route of its own).
    final focus = FocusManager.instance.primaryFocus?.context;
    final focusRoute = focus == null ? null : ModalRoute.of(focus);
    if (focusRoute is PopupRoute && focusRoute != route) return false;
    final editing = DesktopKeyBindings.editingText;
    for (final MapEntry(key: activator, value: action) in widget.bindings.entries) {
      if (editing && !DesktopKeyBindings.hasModifier(activator)) continue;
      if (activator.accepts(event, HardwareKeyboard.instance)) {
        action();
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
