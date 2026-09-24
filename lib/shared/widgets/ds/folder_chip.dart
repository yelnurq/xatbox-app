import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/tokens.dart';

/// A smart-folder chip as the web draws it in a message row: folder icon +
/// name in the folder's own pastel (`folderColor()`), pill, 11px semibold.
class FolderChip extends StatelessWidget {
  const FolderChip({super.key, required this.name, this.color, this.icon = LucideIcons.folder, this.maxWidth = 140});

  final String name;

  /// Palette name from the server (`sky`, `mint`, …).
  final String? color;
  final IconData icon;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.folderColors(color);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(XatBoxTokens.radiusPill),
          border: Border.all(color: c.border, width: t.borderWidth),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: c.foreground),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium!.copyWith(
                  color: c.foreground,
                  fontSize: 11 * t.display.scale,
                  fontWeight: FontWeight.w600,
                  height: 16 / 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 24px folder icon tile of the sidebar tree, in the folder's colours.
class FolderIconTile extends StatelessWidget {
  const FolderIconTile({super.key, this.color, this.icon = LucideIcons.folder, this.size = 24, this.dashed = false});

  final String? color;
  final IconData icon;
  final double size;

  /// The "create folder" row: dashed strong border, no fill.
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.folderColors(color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dashed ? Colors.transparent : c.background,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: dashed ? t.borderStrong : c.border, width: t.borderWidth),
      ),
      child: Icon(icon, size: size * 0.58, color: dashed ? t.textTertiary : c.foreground),
    );
  }
}
