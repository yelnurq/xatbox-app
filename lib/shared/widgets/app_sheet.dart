import 'package:flutter/material.dart';

import '../../core/platform/desktop.dart';
import '../../core/theme/tokens.dart';

/// The app's modal sheet: a bottom sheet on phones, a centred dialog on the
/// desktop (a sheet rising from the bottom edge of a wide window is a phone
/// habit). Takes the [showModalBottomSheet] arguments the app uses; the
/// builder's content is the same in both, and `Navigator.pop(context, value)`
/// closes either.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool? showDragHandle,
  Color? backgroundColor,
  Color? barrierColor,
  ShapeBorder? shape,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
  BoxConstraints? constraints,
}) {
  if (!isDesktop) {
    return showModalBottomSheet<T>(
      context: context,
      builder: builder,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      showDragHandle: showDragHandle,
      backgroundColor: backgroundColor,
      barrierColor: barrierColor,
      shape: shape,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useRootNavigator: useRootNavigator,
      constraints: constraints,
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    barrierColor: barrierColor,
    useRootNavigator: useRootNavigator,
    builder: (ctx) => DesktopSheetDialog(
      backgroundColor: backgroundColor,
      maxWidth: constraints?.maxWidth,
      child: Builder(builder: builder),
    ),
  );
}

/// The dialog frame of [showAppSheet] on the desktop.
class DesktopSheetDialog extends StatelessWidget {
  const DesktopSheetDialog({super.key, required this.child, this.backgroundColor, this.maxWidth});

  final Widget child;
  final Color? backgroundColor;
  final double? maxWidth;

  static const defaultMaxWidth = 560.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final size = MediaQuery.sizeOf(context);
    final width = maxWidth == null || maxWidth == double.infinity ? defaultMaxWidth : maxWidth!;
    return Dialog(
      backgroundColor: backgroundColor ?? t.overlaySurface,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.lg),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: size.height * 0.85),
        child: Padding(
          padding: const EdgeInsets.only(top: Space.sm),
          // Sheet contents pad themselves for the keyboard and the
          // gesture bar; neither exists inside a dialog.
          child: MediaQuery.removeViewInsets(
            context: context,
            removeBottom: true,
            child: MediaQuery.removePadding(context: context, removeBottom: true, child: child),
          ),
        ),
      ),
    );
  }
}
