import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/desktop_layout.dart';
import '../../core/theme/skin_backdrop.dart';
import '../../core/theme/tokens.dart';

/// Desktop: a page (settings, moderation, forms, lists…) laid out like the
/// web's `.app-content`: it fills the workspace with 24px page margins, on a
/// bordered card, up to the web's 1440px — not a narrow column floating in
/// the middle of an empty window. Phones get [child] unchanged.
///
/// [maxWidth] is kept for callers; the web's content width wins on desktop.
class DesktopPage extends ConsumerWidget {
  const DesktopPage({super.key, required this.child, this.maxWidth = 860});

  final Widget child;
  final double maxWidth;

  /// `.app-content { max-width: 1440px }`.
  static const contentMaxWidth = 1440.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(desktopLayoutProvider)) return child;
    final t = context.tokens;
    final size = MediaQuery.sizeOf(context);
    const margin = Space.lg;
    final width = (size.width - margin * 2).clamp(0.0, contentMaxWidth);
    final radius = BorderRadius.circular(14);
    return ColoredBox(
      color: t.appBg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(margin, margin, margin, margin),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            // Glass skins: the card frosts the picture behind it.
            child: GlassBlur(
              borderRadius: radius,
              child: DecoratedBox(
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: radius,
                border: Border.all(color: t.border, width: t.borderWidth),
              ),
              child: ClipRRect(
                borderRadius: radius,
                // Pane layouts inside (e.g. `isExpanded`) see the card's width.
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(size: Size(width, size.height - margin * 2)),
                  child: child,
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
