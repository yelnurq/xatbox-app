import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import 'package:path/path.dart' as p;

import 'eml_view.dart';
import 'message_detail_screen.dart';

/// A message opened in its own window over the desktop app («Открыть в
/// отдельном окне»): to read one message while answering or reading another.
@immutable
class MessageWindow {
  const MessageWindow({required this.id, required this.messageId, required this.offset, required this.size, this.emlPath});

  final int id;
  final String messageId;

  /// A saved message (.eml) opened with XatBox instead of one of the mailbox.
  final String? emlPath;

  /// Top left corner in the shell, and the size.
  final Offset offset;
  final Size size;

  MessageWindow copyWith({String? messageId, Offset? offset, Size? size}) => MessageWindow(
    id: id,
    messageId: messageId ?? this.messageId,
    offset: offset ?? this.offset,
    size: size ?? this.size,
    emlPath: emlPath,
  );
}

/// The open message windows, back to front.
class MessageWindowsNotifier extends Notifier<List<MessageWindow>> {
  static const defaultSize = Size(760, 640);
  static const minSize = Size(480, 360);
  static const _cascade = Offset(32, 32);
  static const _origin = Offset(140, 72);

  int _next = 0;

  @override
  List<MessageWindow> build() => const [];

  /// Opens [messageId], or brings its window to the front.
  void open(String messageId) {
    final existing = state.where((w) => w.messageId == messageId).firstOrNull;
    if (existing != null) {
      front(existing.id);
      return;
    }
    final offset = _origin + _cascade * (state.length % 8).toDouble();
    state = [...state, MessageWindow(id: ++_next, messageId: messageId, offset: offset, size: defaultSize)];
  }

  /// A saved message (.eml), or its window brought to the front.
  void openEml(String path) {
    final existing = state.where((w) => w.emlPath == path).firstOrNull;
    if (existing != null) {
      front(existing.id);
      return;
    }
    final offset = _origin + _cascade * (state.length % 8).toDouble();
    state = [...state, MessageWindow(id: ++_next, messageId: '', offset: offset, size: defaultSize, emlPath: path)];
  }

  void close(int id) => state = [for (final w in state) if (w.id != id) w];

  void front(int id) {
    final w = state.where((w) => w.id == id).firstOrNull;
    if (w == null || state.last.id == id) return;
    state = [for (final o in state) if (o.id != id) o, w];
  }

  /// Another message of the conversation in the same window.
  void show(int id, String messageId) => _update(id, (w) => w.copyWith(messageId: messageId));

  /// Dragged by the title bar, kept within [bounds] so it can be grabbed.
  void move(int id, Offset delta, Size bounds) => _update(id, (w) {
    final o = w.offset + delta;
    return w.copyWith(
      offset: Offset(
        o.dx.clamp(-w.size.width + 120, (bounds.width - 120).clamp(0, double.infinity)),
        o.dy.clamp(0, (bounds.height - 40).clamp(0, double.infinity)),
      ),
    );
  });

  /// Dragged by the corner.
  void resize(int id, Offset delta) => _update(
    id,
    (w) => w.copyWith(
      size: Size(
        (w.size.width + delta.dx).clamp(minSize.width, double.infinity),
        (w.size.height + delta.dy).clamp(minSize.height, double.infinity),
      ),
    ),
  );

  void _update(int id, MessageWindow Function(MessageWindow w) change) =>
      state = [for (final w in state) w.id == id ? change(w) : w];
}

final messageWindowsProvider = NotifierProvider<MessageWindowsNotifier, List<MessageWindow>>(MessageWindowsNotifier.new);

/// Paints the message windows over [child] (the desktop shell).
class MessageWindowHost extends ConsumerWidget {
  const MessageWindowHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windows = ref.watch(messageWindowsProvider);
    // Always a Stack with [child] first, so opening a window never
    // re-parents the pages underneath.
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          child,
          for (final w in windows)
            Positioned(
              key: ValueKey('message_window_${w.id}'),
              left: w.offset.dx,
              top: w.offset.dy,
              width: w.size.width.clamp(0, constraints.maxWidth),
              height: w.size.height.clamp(0, constraints.maxHeight),
              child: _MessageWindowFrame(window: w, bounds: constraints.biggest),
            ),
        ],
      ),
    );
  }
}

class _MessageWindowFrame extends ConsumerWidget {
  const _MessageWindowFrame({required this.window, required this.bounds});

  final MessageWindow window;
  final Size bounds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final notifier = ref.read(messageWindowsProvider.notifier);
    final radius = BorderRadius.circular(12);
    void close() => notifier.close(window.id);
    return Listener(
      onPointerDown: (_) => notifier.front(window.id),
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): close},
        child: FocusScope(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.18), blurRadius: 42, offset: const Offset(0, 18)),
                BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(borderRadius: radius, border: Border.all(color: t.border)),
                child: Material(
                  color: t.surface,
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Title bar: drag to move.
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanUpdate: (d) => notifier.move(window.id, d.delta, bounds),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.move,
                              child: Container(
                                height: 32,
                                padding: const EdgeInsets.only(left: Space.smd),
                                decoration: BoxDecoration(
                                  color: t.surfaceMuted,
                                  border: Border(bottom: BorderSide(color: t.border, width: t.borderWidth)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(LucideIcons.mail, size: 14, color: t.textTertiary),
                                    const SizedBox(width: Space.sm),
                                    Expanded(
                                      child: Text(
                                        window.emlPath == null ? context.l10n.tabMail : p.basename(window.emlPath!),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.textSecondary),
                                      ),
                                    ),
                                    IconButton(
                                      key: Key('message_window_close_${window.id}'),
                                      iconSize: 14,
                                      visualDensity: VisualDensity.compact,
                                      tooltip: context.l10n.close,
                                      icon: const Icon(LucideIcons.x),
                                      onPressed: close,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            // Its own navigator: the message's dialogs and
                            // menus open inside the window.
                            child: HeroControllerScope.none(
                              child: Navigator(
                                pages: [
                                  MaterialPage<void>(
                                    key: const ValueKey('message'),
                                    child: window.emlPath != null
                                        ? Material(
                                            color: t.surface,
                                            child: EmlView(path: window.emlPath!, onClose: close),
                                          )
                                        : MessageDetailScreen(
                                      key: ValueKey(window.messageId),
                                      messageId: window.messageId,
                                      embedded: true,
                                      keyboard: false,
                                      onClose: close,
                                      onOpenMessage: (id) => notifier.show(window.id, id),
                                    ),
                                  ),
                                ],
                                onDidRemovePage: (_) {},
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Resize grip in the bottom right corner.
                      Positioned(
                        right: 0,
                        bottom: 0,
                        width: 18,
                        height: 18,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeDownRight,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanUpdate: (d) => notifier.resize(window.id, d.delta),
                            child: Icon(LucideIcons.gripHorizontal, size: 12, color: t.textTertiary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
