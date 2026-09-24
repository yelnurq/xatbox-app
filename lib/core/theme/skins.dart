import 'package:flutter/material.dart';

part 'glass_skins.dart';
part 'skins.g.dart';

/// The visual "worlds" of the web client (`apps/web/src/components/providers.tsx`
/// `SKINS`). `standard` follows the light/dark mode switch; every other skin
/// commits to one brightness, exactly as on the web.
enum AppSkin {
  standard,
  steppe,
  paper,
  graphite,
  kok,
  midnight,
  terminal,
  lilac,
  contrast,
  forest,

  /// Desktop only: translucent glass over a painted backdrop.
  glassForest,
  glassSpace,
  glassAstana,
  glassSemey,

  /// Desktop only: the same glass over a picture the user chose.
  glassCustom;

  /// The web default (`DEFAULT_SKIN`).
  static const AppSkin defaultSkin = AppSkin.kok;

  /// `null` means the skin follows the light/dark preference.
  Brightness? get fixedBrightness => switch (this) {
    AppSkin.standard => null,
    AppSkin.steppe || AppSkin.paper || AppSkin.kok || AppSkin.lilac || AppSkin.contrast => Brightness.light,
    AppSkin.graphite ||
    AppSkin.midnight ||
    AppSkin.terminal ||
    AppSkin.forest ||
    AppSkin.glassForest ||
    AppSkin.glassSpace ||
    AppSkin.glassAstana ||
    AppSkin.glassSemey ||
    AppSkin.glassCustom => Brightness.dark,
  };

  /// The glass skins (a picture behind frosted pages). Offered on every
  /// platform since the phone got the desktop's design.
  bool get desktopOnly => switch (this) {
    AppSkin.glassForest ||
    AppSkin.glassSpace ||
    AppSkin.glassAstana ||
    AppSkin.glassSemey ||
    AppSkin.glassCustom => true,
    _ => false,
  };

  /// The skins a picker offers: the desktop gets the glass ones too.
  static List<AppSkin> offered({bool desktop = true}) => values;

  /// Resolves the palette for this skin under [mode] (system → [platform]).
  SkinPalette palette(ThemeMode mode, Brightness platform) {
    if (this == AppSkin.standard) {
      final dark = switch (mode) {
        ThemeMode.system => platform == Brightness.dark,
        ThemeMode.dark => true,
        ThemeMode.light => false,
      };
      return dark ? SkinPalettes.standardDark : SkinPalettes.standardLight;
    }
    return switch (this) {
      AppSkin.steppe => SkinPalettes.steppe,
      AppSkin.paper => SkinPalettes.paper,
      AppSkin.graphite => SkinPalettes.graphite,
      AppSkin.kok => SkinPalettes.kok,
      AppSkin.midnight => SkinPalettes.midnight,
      AppSkin.terminal => SkinPalettes.terminal,
      AppSkin.lilac => SkinPalettes.lilac,
      AppSkin.contrast => SkinPalettes.contrast,
      AppSkin.forest => SkinPalettes.forest,
      AppSkin.glassForest => GlassPalettes.forest,
      AppSkin.glassSpace => GlassPalettes.space,
      AppSkin.glassAstana => GlassPalettes.astana,
      AppSkin.glassSemey => GlassPalettes.semey,
      AppSkin.glassCustom => GlassPalettes.custom,
      AppSkin.standard => SkinPalettes.standardLight,
    };
  }
}

/// How the active navigation item is drawn (globals.css "Skin signatures").
enum NavActiveStyle {
  /// Selected surface + 3px primary rail on the left (standard, graphite).
  rail,

  /// Selected surface, no rail (steppe, midnight, lilac, forest).
  tint,

  /// Rail in the sidebar's accent over the subtle surface (kok, terminal).
  railTint,

  /// Transparent background, label underlined in the info colour (paper).
  underline,

  /// Black background, white text (high contrast).
  inverse,
}

/// The sidebar of a skin can repaint itself (kok goes deep teal, steppe warm
/// sand) while the page stays as the palette says.
@immutable
class SidebarOverride {
  const SidebarOverride({
    this.surface,
    this.surfaceSubtle,
    this.surfaceHover,
    this.surfaceSelected,
    this.border,
    this.borderStrong,
    this.divider,
    this.textPrimary,
    this.textSecondary,
    this.textTertiary,
    this.textDisabled,
    this.textInverse,
    this.primary,
    this.primaryHover,
    this.primaryActive,
    this.primarySoft,
    this.mark,
  });

  final Color? surface;
  final Color? surfaceSubtle;
  final Color? surfaceHover;
  final Color? surfaceSelected;
  final Color? border;
  final Color? borderStrong;
  final Color? divider;
  final Color? textPrimary;
  final Color? textSecondary;
  final Color? textTertiary;
  final Color? textDisabled;
  final Color? textInverse;
  final Color? primary;
  final Color? primaryHover;
  final Color? primaryActive;
  final Color? primarySoft;
  final Color? mark;
}

/// One skin's complete token set: the `--color-*`, `--radius-*` and font
/// variables of globals.css plus the structural habits of its signature block.
@immutable
class SkinPalette {
  const SkinPalette({
    required this.id,
    required this.brightness,
    required this.fontDisplay,
    required this.fontText,
    required this.monospace,
    required this.appBg,
    required this.surface,
    required this.surfaceSubtle,
    required this.surfaceMuted,
    required this.surfaceHover,
    required this.surfaceSelected,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.textInverse,
    required this.border,
    required this.borderStrong,
    required this.divider,
    required this.primary,
    required this.primaryHover,
    required this.primaryActive,
    required this.primarySoft,
    required this.focus,
    required this.info,
    required this.infoSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.labelBlue,
    required this.labelBlueText,
    required this.labelPurple,
    required this.labelPurpleText,
    required this.labelGreen,
    required this.labelGreenText,
    required this.labelYellow,
    required this.labelYellowText,
    required this.unreadPip,
    required this.selection,
    required this.mark,
    required this.loginField,
    required this.loginInk,
    required this.folderColorStrength,
    required this.folderBorderStrength,
    required this.folderTextStrength,
    required this.radiusXs,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
    required this.shadows,
    required this.borderWidth,
    required this.navRadius,
    required this.navActive,
    required this.titleWeight,
    required this.titleUppercase,
    required this.titlePrefix,
    required this.sectionPrefix,
    required this.sidebar,
    this.glass,
  });

  final AppSkin id;
  final Brightness brightness;

  /// `--font-display` (headings, buttons, navigation) and `--font-text`.
  final String fontDisplay;
  final String fontText;

  /// Terminal / graphite set body text in a monospace face.
  final bool monospace;

  final Color appBg;
  final Color surface;
  final Color surfaceSubtle;
  final Color surfaceMuted;
  final Color surfaceHover;
  final Color surfaceSelected;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color textInverse;
  final Color border;
  final Color borderStrong;
  final Color divider;
  final Color primary;
  final Color primaryHover;
  final Color primaryActive;
  final Color primarySoft;
  final Color focus;
  final Color info;
  final Color infoSoft;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color labelBlue;
  final Color labelBlueText;
  final Color labelPurple;
  final Color labelPurpleText;
  final Color labelGreen;
  final Color labelGreenText;
  final Color labelYellow;
  final Color labelYellowText;

  /// The unread marker in the message list (`--unread-pip`).
  final Color unreadPip;
  final Color selection;

  /// Brand mark colour (`--color-mark`) and the login backdrop tokens.
  final Color mark;
  final Color loginField;
  final Color loginInk;

  /// `--folder-*-strength`: how much of a folder's own colour survives the
  /// `color-mix` with the surface (dark skins keep folders muted).
  final double folderColorStrength;
  final double folderBorderStrength;
  final double folderTextStrength;

  final double radiusXs;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;

  /// Paper, graphite, terminal and contrast draw no soft shadows.
  final bool shadows;

  /// 2 for the high-contrast skin, 1 otherwise.
  final int borderWidth;

  final double navRadius;
  final NavActiveStyle navActive;
  final FontWeight titleWeight;
  final bool titleUppercase;

  /// Terminal prefixes page titles with `$ ` and section labels with `> `.
  final String titlePrefix;
  final String sectionPrefix;

  final SidebarOverride? sidebar;

  /// Glass skins: the picture behind the app and the opaque surface of
  /// dialogs and menus. Null for the web's skins.
  final GlassStyle? glass;

  bool get isDark => brightness == Brightness.dark;
}
