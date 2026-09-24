import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import 'state_view.dart';

/// List on the left, the opened item on the right: the wide layout of the
/// Contacts and Calls tabs (mail and chat build theirs with extra panes).
/// Callers switch to it on `context.isExpanded`; below that the list alone
/// pushes the item as a page.
class SplitPane extends StatelessWidget {
  const SplitPane({
    super.key,
    required this.list,
    required this.detail,
    required this.placeholderTitle,
    required this.placeholderIcon,
    this.listWidth = 380,
  });

  final Widget list;

  /// The opened item (its own Scaffold), or null for the placeholder.
  final Widget? detail;
  final String placeholderTitle;
  final IconData placeholderIcon;
  final double listWidth;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: math.min(listWidth, MediaQuery.sizeOf(context).width * 0.4),
          child: list,
        ),
        VerticalDivider(width: t.borderWidth, thickness: t.borderWidth, color: t.divider),
        Expanded(
          child:
              detail ??
              Scaffold(
                body: StateView.empty(title: placeholderTitle, icon: placeholderIcon),
              ),
        ),
      ],
    );
  }
}
