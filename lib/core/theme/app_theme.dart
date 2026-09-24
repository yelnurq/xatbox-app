import 'package:flutter/material.dart';

import 'tokens.dart';

/// Builds the Material theme from the web design system: one [SkinPalette]
/// plus the display settings (text size, density). Component themes carry the
/// values of `DESIGN.MD` (controls 34/40px, radius 8–12, 1px borders, no
/// heavy shadows) so feature code can use plain Material widgets and still
/// look like the web client.
abstract final class AppTheme {
  /// Web default (kok, light) / standard dark — used by tests and the config
  /// error screen.
  static ThemeData light() => build(XatBoxTokens.light);
  static ThemeData dark() => build(XatBoxTokens.dark);

  static ThemeData build(XatBoxTokens t) {
    final p = t.palette;
    final d = t.display;
    final dark = p.isDark;
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.primary,
      onPrimary: p.textInverse,
      primaryContainer: p.primarySoft,
      onPrimaryContainer: p.textPrimary,
      secondary: p.info,
      onSecondary: p.textInverse,
      secondaryContainer: p.surfaceSelected,
      onSecondaryContainer: p.textPrimary,
      tertiary: p.warning,
      onTertiary: p.textInverse,
      tertiaryContainer: p.warningSoft,
      onTertiaryContainer: p.warning,
      error: p.danger,
      onError: p.textInverse,
      errorContainer: p.dangerSoft,
      onErrorContainer: p.danger,
      surface: p.surface,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      surfaceDim: p.appBg,
      surfaceBright: p.surface,
      surfaceContainerLowest: p.surface,
      surfaceContainerLow: p.surfaceSubtle,
      surfaceContainer: p.surfaceSubtle,
      surfaceContainerHigh: p.surfaceHover,
      surfaceContainerHighest: p.surfaceHover,
      outline: p.border,
      outlineVariant: p.divider,
      inverseSurface: p.textPrimary,
      onInverseSurface: p.surface,
      inversePrimary: p.primarySoft,
      surfaceTint: Colors.transparent,
      shadow: Colors.black,
      scrim: const Color(0xFF0F172A),
    );

    final text = _textTheme(t);
    final display = TextStyle(fontFamily: p.fontDisplay);
    final control = BorderRadius.circular(p.radiusSm);
    final controlLabel = text.labelLarge!.copyWith(fontFamily: p.fontDisplay, fontWeight: FontWeight.w500);
    final side = BorderSide(color: p.border, width: t.borderWidth);
    // Glass skins: pages are translucent, what floats over them is not.
    final overlay = t.overlaySurface;

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      fontFamily: p.fontText,
      textTheme: text,
      primaryTextTheme: text,
      scaffoldBackgroundColor: p.appBg,
      canvasColor: overlay,
      cardColor: p.surface,
      dividerColor: p.divider,
      splashColor: p.surfaceHover.withValues(alpha: 0.6),
      highlightColor: p.surfaceHover,
      hoverColor: p.surfaceHover,
      focusColor: p.focus.withValues(alpha: 0.18),
      disabledColor: p.textDisabled,
      hintColor: p.textTertiary,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      extensions: [t],
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: Space.topbarHeight,
        shape: Border(bottom: side),
        centerTitle: false,
        titleTextStyle: text.titleMedium!.copyWith(fontFamily: p.fontDisplay, fontWeight: FontWeight.w600),
        iconTheme: IconThemeData(color: p.textSecondary, size: 20),
        actionsIconTheme: IconThemeData(color: p.textSecondary, size: 20),
      ),
      iconTheme: IconThemeData(color: p.textSecondary, size: 20),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.primarySoft,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(p.navRadius)),
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelMedium!.copyWith(
            fontFamily: p.fontDisplay,
            color: s.contains(WidgetState.selected) ? p.textPrimary : p.textTertiary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(size: 20, color: s.contains(WidgetState.selected) ? p.primary : p.textSecondary),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: t.sidebarSurface,
        indicatorColor: t.sidebarSelected,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(p.navRadius)),
        selectedIconTheme: IconThemeData(color: t.sidebarPrimary, size: 20),
        unselectedIconTheme: IconThemeData(color: t.sidebarTextSecondary, size: 20),
        selectedLabelTextStyle: text.labelMedium!.copyWith(color: t.sidebarText, fontFamily: p.fontDisplay),
        unselectedLabelTextStyle: text.labelMedium!.copyWith(color: t.sidebarTextTertiary, fontFamily: p.fontDisplay),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: t.sidebarSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        width: Space.sidebarWidth,
        shape: const RoundedRectangleBorder(),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.textInverse,
        elevation: p.shadows ? 2 : 0,
        highlightElevation: p.shadows ? 4 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(p.radiusMd)),
        extendedTextStyle: controlLabel,
        iconSize: 20,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, Space.controlMd)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: Space.smd)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: control)),
          textStyle: WidgetStatePropertyAll(controlLabel),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? p.primary.withValues(alpha: 0.45)
                : (s.contains(WidgetState.pressed) ? p.primaryActive : (s.contains(WidgetState.hovered) ? p.primaryHover : p.primary)),
          ),
          foregroundColor: WidgetStatePropertyAll(p.textInverse),
          iconColor: WidgetStatePropertyAll(p.textInverse),
          iconSize: const WidgetStatePropertyAll(16),
          elevation: const WidgetStatePropertyAll(0),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, Space.controlMd)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: Space.smd)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: control)),
          textStyle: WidgetStatePropertyAll(controlLabel),
          backgroundColor: WidgetStatePropertyAll(p.primary),
          foregroundColor: WidgetStatePropertyAll(p.textInverse),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, Space.controlMd)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: Space.smd)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: control)),
          side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(color: s.contains(WidgetState.hovered) ? p.borderStrong : p.border, width: t.borderWidth),
          ),
          textStyle: WidgetStatePropertyAll(controlLabel),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.hovered) || s.contains(WidgetState.pressed) ? p.surfaceHover : p.surface,
          ),
          foregroundColor: WidgetStatePropertyAll(p.textPrimary),
          iconColor: WidgetStatePropertyAll(p.textSecondary),
          iconSize: const WidgetStatePropertyAll(16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, Space.controlMd)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: Space.smd)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: control)),
          textStyle: WidgetStatePropertyAll(controlLabel),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? p.textDisabled : p.textPrimary,
          ),
          overlayColor: WidgetStatePropertyAll(p.surfaceHover),
          iconColor: WidgetStatePropertyAll(p.textSecondary),
          iconSize: const WidgetStatePropertyAll(16),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(Space.tapTarget, Space.tapTarget)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: control)),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? p.textDisabled : p.textSecondary,
          ),
          overlayColor: WidgetStatePropertyAll(p.surfaceHover),
          iconSize: const WidgetStatePropertyAll(20),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, Space.controlMd)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: control)),
          side: WidgetStatePropertyAll(side),
          textStyle: WidgetStatePropertyAll(controlLabel),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.surfaceSelected : p.surface,
          ),
          foregroundColor: WidgetStatePropertyAll(p.textPrimary),
          iconSize: const WidgetStatePropertyAll(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.smd, vertical: 10),
        constraints: const BoxConstraints(minHeight: Space.controlLg),
        border: OutlineInputBorder(borderRadius: control, borderSide: BorderSide(color: p.borderStrong, width: t.borderWidth)),
        enabledBorder: OutlineInputBorder(borderRadius: control, borderSide: BorderSide(color: p.borderStrong, width: t.borderWidth)),
        focusedBorder: OutlineInputBorder(borderRadius: control, borderSide: BorderSide(color: p.focus, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: control, borderSide: BorderSide(color: p.danger, width: t.borderWidth)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: control, borderSide: BorderSide(color: p.danger, width: 2)),
        disabledBorder: OutlineInputBorder(borderRadius: control, borderSide: BorderSide(color: p.border, width: t.borderWidth)),
        hintStyle: text.bodyMedium!.copyWith(color: p.textTertiary),
        labelStyle: text.labelMedium!.copyWith(color: p.textSecondary),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        errorStyle: text.labelMedium!.copyWith(color: p.danger, fontWeight: FontWeight.w400),
        prefixIconColor: p.textTertiary,
        suffixIconColor: p.textTertiary,
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: d.rowPaddingY,
        minTileHeight: d.rowMinHeight,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.md),
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
        selectedTileColor: p.surfaceSelected,
        selectedColor: p.textPrimary,
        titleTextStyle: text.bodyMedium,
        subtitleTextStyle: text.bodySmall!.copyWith(color: p.textTertiary),
        leadingAndTrailingTextStyle: text.labelMedium!.copyWith(color: p.textTertiary),
        shape: const RoundedRectangleBorder(),
      ),
      dividerTheme: DividerThemeData(color: p.divider, thickness: t.borderWidth, space: t.borderWidth),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(p.radiusMd), side: side),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceSubtle,
        selectedColor: p.primarySoft,
        disabledColor: p.surfaceSubtle,
        side: side,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(p.radiusXs + 1)),
        labelStyle: text.labelMedium!.copyWith(color: p.textSecondary),
        secondaryLabelStyle: text.labelMedium!.copyWith(color: p.textPrimary),
        padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        iconTheme: IconThemeData(size: 14, color: p.textSecondary),
        showCheckmark: false,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: overlay,
        contentTextStyle: text.bodyMedium!.copyWith(color: p.textPrimary),
        actionTextColor: p.info,
        closeIconColor: p.textSecondary,
        elevation: p.shadows ? 6 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(p.radiusMd), side: side),
        insetPadding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: overlay,
        surfaceTintColor: Colors.transparent,
        elevation: p.shadows ? 12 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(p.radiusLg), side: p.shadows ? BorderSide.none : side),
        titleTextStyle: text.titleLarge!.copyWith(fontFamily: p.fontDisplay),
        contentTextStyle: text.bodyMedium!.copyWith(color: p.textSecondary),
        insetPadding: const EdgeInsets.all(Space.md),
        actionsPadding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: overlay,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: overlay,
        dragHandleColor: p.borderStrong,
        showDragHandle: true,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(p.radiusXl))),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: overlay,
        surfaceTintColor: Colors.transparent,
        elevation: p.shadows ? 6 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(p.radiusMd), side: side),
        textStyle: text.bodyMedium,
        labelTextStyle: WidgetStatePropertyAll(text.bodyMedium),
        iconColor: p.textSecondary,
        menuPadding: const EdgeInsets.all(6),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(overlay),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: WidgetStatePropertyAll(p.shadows ? 6 : 0),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(p.radiusMd), side: side)),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(p.radiusXs)),
        side: BorderSide(color: p.borderStrong, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : Colors.transparent),
        checkColor: WidgetStatePropertyAll(p.textInverse),
        visualDensity: VisualDensity.compact,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : p.borderStrong),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.textInverse : p.surface),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : p.borderStrong),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.textPrimary,
        unselectedLabelColor: p.textTertiary,
        indicatorColor: p.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: p.divider,
        labelStyle: controlLabel,
        unselectedLabelStyle: controlLabel,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: p.danger,
        textColor: p.textInverse,
        textStyle: text.labelSmall!.copyWith(fontWeight: FontWeight.w600),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary, linearTrackColor: p.surfaceHover),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: p.textPrimary, borderRadius: BorderRadius.circular(p.radiusXs)),
        textStyle: text.labelMedium!.copyWith(color: overlay),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(p.borderStrong),
        radius: Radius.circular(p.radiusXs),
        thickness: const WidgetStatePropertyAll(6),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: p.textSecondary,
        collapsedIconColor: p.textSecondary,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: overlay,
        surfaceTintColor: Colors.transparent,
        headerHeadlineStyle: display.merge(text.headlineSmall),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(p.radiusLg)),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: overlay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(p.radiusLg)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(textStyle: text.bodyMedium),
    ).copyWith(
      // Message bodies and the login use the app's own ink, whatever the platform.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.primary,
        selectionColor: p.selection,
        selectionHandleColor: p.primary,
      ),
      // Dark skins: repaint the system UI to the surface.
      brightness: dark ? Brightness.dark : Brightness.light,
    );
  }

  /// The typographic scale of `DESIGN.MD` §5 (sizes × `--font-scale`), on the
  /// skin's text face; headings, buttons and navigation take the display face.
  static TextTheme _textTheme(XatBoxTokens t) {
    final p = t.palette;
    final s = t.display.scale;
    TextStyle style(double size, double height, FontWeight weight, {bool display = false, Color? color}) => TextStyle(
      fontFamily: display ? p.fontDisplay : p.fontText,
      fontSize: size * s,
      height: height / size,
      fontWeight: weight,
      color: color ?? p.textPrimary,
      letterSpacing: 0,
    );
    return TextTheme(
      // Display 28/36 600, page title 24/32 600.
      displayLarge: style(28, 36, FontWeight.w600, display: true),
      displayMedium: style(28, 36, FontWeight.w600, display: true),
      displaySmall: style(24, 32, FontWeight.w600, display: true),
      headlineLarge: style(28, 36, FontWeight.w600, display: true),
      headlineMedium: style(24, 32, FontWeight.w600, display: true),
      headlineSmall: style(24, 32, p.titleWeight, display: true),
      // Section title 18/24 500, card title 16/22 500, list title 14/20 500.
      titleLarge: style(18, 24, FontWeight.w500, display: true),
      titleMedium: style(16, 22, FontWeight.w500, display: true),
      titleSmall: style(14, 20, FontWeight.w500, display: true),
      // Body 15 (base) / 14 (lists) / 13 (compact).
      bodyLarge: style(15, 22, FontWeight.w400),
      bodyMedium: style(14, 20, FontWeight.w400),
      bodySmall: style(13, 18, FontWeight.w400, color: p.textSecondary),
      // Buttons 13/500 (display face), label 12/16 500, caption 11/16.
      labelLarge: style(13, 18, FontWeight.w500, display: true),
      labelMedium: style(12, 16, FontWeight.w500, display: true, color: p.textSecondary),
      labelSmall: style(11, 16, FontWeight.w400, color: p.textTertiary),
    );
  }
}
