import 'package:flutter/material.dart';

import '../platform/desktop.dart';
import 'skins.dart';

export 'skins.dart';

/// Design tokens (ТЗ п.24.22), the same set the web client's `globals.css`
/// declares: surfaces, text, borders, primary, semantic colours, label
/// colours, radii and the skin's structural habits. Every colour used by
/// feature code must come from here or from [ColorScheme]; no hard-coded
/// colours in widgets.
///
/// The token values are one [SkinPalette] (see `skins.dart`); the
/// [Display] settings (text size, list density) sit on top of it.
@immutable
class XatBoxTokens extends ThemeExtension<XatBoxTokens> {
  const XatBoxTokens(this.palette, {this.display = const Display()});

  final SkinPalette palette;
  final Display display;

  /// The web default: kok skin, light. Kept as `light` / `dark` for tests and
  /// the few places that need a palette without a theme.
  static const light = XatBoxTokens(SkinPalettes.kok);
  static const dark = XatBoxTokens(SkinPalettes.standardDark);

  /// Brand blue of the mark (`--color-logo-ink`), independent of any skin.
  static const brandSeed = Color(0xFF2868B4);

  // ---- surfaces -----------------------------------------------------------------
  Color get appBg => palette.appBg;
  Color get surface => palette.surface;
  Color get surfaceSubtle => palette.surfaceSubtle;
  Color get surfaceMuted => palette.surfaceMuted;
  Color get surfaceHover => palette.surfaceHover;
  Color get surfaceSelected => palette.surfaceSelected;

  /// Glass skins: the picture behind the app (null for the web's skins).
  GlassStyle? get glass => palette.glass;

  /// Dialogs, menus and panels over the page: the surface, made opaque on
  /// glass skins (text over a translucent sheet over a picture is unreadable).
  Color get overlaySurface => palette.glass?.solidSurface ?? surface;

  // ---- text ----------------------------------------------------------------------
  Color get textPrimary => palette.textPrimary;
  Color get textSecondary => palette.textSecondary;
  Color get textTertiary => palette.textTertiary;
  Color get textDisabled => palette.textDisabled;
  Color get textInverse => palette.textInverse;

  // ---- borders -------------------------------------------------------------------
  Color get border => palette.border;
  Color get borderStrong => palette.borderStrong;
  Color get divider => palette.divider;
  double get borderWidth => palette.borderWidth.toDouble();

  // ---- brand / actions -----------------------------------------------------------
  Color get primary => palette.primary;
  Color get primaryHover => palette.primaryHover;
  Color get primaryActive => palette.primaryActive;
  Color get primarySoft => palette.primarySoft;
  Color get focus => palette.focus;
  Color get mark => palette.mark;
  Color get loginField => palette.loginField;
  Color get loginInk => palette.loginInk;

  // ---- semantic ------------------------------------------------------------------
  Color get info => palette.info;
  Color get infoSoft => palette.infoSoft;
  Color get success => palette.success;
  Color get successSoft => palette.successSoft;
  Color get warning => palette.warning;
  Color get warningSoft => palette.warningSoft;
  Color get danger => palette.danger;
  Color get dangerSoft => palette.dangerSoft;

  // ---- labels ----------------------------------------------------------------------
  Color get labelBlue => palette.labelBlue;
  Color get labelBlueText => palette.labelBlueText;
  Color get labelPurple => palette.labelPurple;
  Color get labelPurpleText => palette.labelPurpleText;
  Color get labelGreen => palette.labelGreen;
  Color get labelGreenText => palette.labelGreenText;
  Color get labelYellow => palette.labelYellow;
  Color get labelYellowText => palette.labelYellowText;
  Color get unreadPip => palette.unreadPip;
  Color get selection => palette.selection;

  // ---- radii (`--radius-*`) -------------------------------------------------------
  double get radiusXs => palette.radiusXs;
  double get radiusSm => palette.radiusSm;
  double get radiusMd => palette.radiusMd;
  double get radiusLg => palette.radiusLg;
  double get radiusXl => palette.radiusXl;
  static const radiusPill = 999.0;

  BorderRadius get controlRadius => BorderRadius.circular(radiusSm);
  BorderRadius get cardRadius => BorderRadius.circular(radiusMd);
  BorderRadius get dialogRadius => BorderRadius.circular(radiusLg);

  /// `--shadow-sm` / `--shadow-md`; empty for the flat skins.
  List<BoxShadow> get shadowSm => palette.shadows
      ? [
          BoxShadow(color: _shadowInk.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: _shadowInk.withValues(alpha: 0.06), blurRadius: 3, offset: const Offset(0, 1)),
        ]
      : const [];
  List<BoxShadow> get shadowMd => palette.shadows
      ? [
          BoxShadow(color: _shadowInk.withValues(alpha: 0.14), blurRadius: 28, offset: const Offset(0, 12)),
          BoxShadow(color: _shadowInk.withValues(alpha: 0.07), blurRadius: 10, offset: const Offset(0, 4)),
        ]
      : const [];
  Color get _shadowInk => palette.isDark ? Colors.black : const Color(0xFF0F172A);

  // ---- sidebar (drawer) ---------------------------------------------------------------
  /// Sidebar colours: the palette's, unless the skin repaints its sidebar.
  Color get sidebarSurface => palette.sidebar?.surface ?? surface;
  Color get sidebarSubtle => palette.sidebar?.surfaceSubtle ?? surfaceSubtle;
  Color get sidebarHover => palette.sidebar?.surfaceHover ?? surfaceHover;
  Color get sidebarSelected => palette.sidebar?.surfaceSelected ?? surfaceSelected;
  Color get sidebarBorder => palette.sidebar?.border ?? border;
  Color get sidebarDivider => palette.sidebar?.divider ?? divider;
  Color get sidebarText => palette.sidebar?.textPrimary ?? textPrimary;
  Color get sidebarTextSecondary => palette.sidebar?.textSecondary ?? textSecondary;
  Color get sidebarTextTertiary => palette.sidebar?.textTertiary ?? textTertiary;
  Color get sidebarPrimary => palette.sidebar?.primary ?? primary;
  Color get sidebarPrimarySoft => palette.sidebar?.primarySoft ?? primarySoft;
  Color get sidebarTextInverse => palette.sidebar?.textInverse ?? textInverse;
  Color get sidebarMark => palette.sidebar?.mark ?? mark;
  double get navRadius => palette.navRadius;
  NavActiveStyle get navActive => palette.navActive;

  // ---- typography habits -----------------------------------------------------------
  String get fontDisplay => palette.fontDisplay;
  String get fontText => palette.fontText;
  FontWeight get titleWeight => palette.titleWeight;
  bool get titleUppercase => palette.titleUppercase;
  String get titlePrefix => palette.titlePrefix;
  String get sectionPrefix => palette.sectionPrefix;

  /// Page / section title text as the skin wants it (`.page-title`).
  String pageTitle(String text) => '$titlePrefix${titleUppercase ? text.toUpperCase() : text}';
  String sectionLabel(String text) => '$sectionPrefix${text.toUpperCase()}';

  // ---- legacy names (kept so feature code keeps compiling) ----------------------------
  /// The action colour. On the web the "brand" of buttons is `--color-primary`.
  Color get brand => primary;
  Color get onBrand => textInverse;
  Color get textMuted => textTertiary;
  Color get unreadBadge => danger;
  Color get onUnreadBadge => textInverse;
  Color get offlineBanner => warningSoft;
  Color get onOfflineBanner => warning;

  /// Initials avatars use the five web tones (`AVATAR_TONES` in ui.tsx):
  /// primary-soft, then the four label colours. [avatarColorFor] returns the
  /// background; [avatarTextColorFor] the matching ink.
  List<(Color, Color)> get avatarTones => [
    (primarySoft, primary),
    (labelBlue, labelBlueText),
    (labelPurple, labelPurpleText),
    (labelGreen, labelGreenText),
    (labelYellow, labelYellowText),
  ];

  /// Same hash as the web (`hash * 31 + charCode`, 32-bit wrap), so a person
  /// gets the same tone in both clients.
  static int avatarToneIndex(String key, int tones) {
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0xFFFFFFFF;
    }
    if (hash >= 0x80000000) hash -= 0x100000000;
    return hash.abs() % tones;
  }

  Color avatarColorFor(String key) => avatarTones[avatarToneIndex(key, avatarTones.length)].$1;
  Color avatarTextColorFor(String key) => avatarTones[avatarToneIndex(key, avatarTones.length)].$2;

  /// Folder colours: the web's 12 named pastels (`lib/folder-colors.ts`),
  /// mixed against the surface by the skin's `--folder-*-strength`, so dark
  /// skins keep them muted exactly like the web does with `color-mix`.
  FolderColors folderColors(String? name) {
    final base = _folderPalette[name ?? 'sky'] ?? _folderPalette['sky']!;
    return FolderColors(
      background: Color.lerp(surface, base.$1, palette.folderColorStrength)!,
      foreground: Color.lerp(textPrimary, base.$2, palette.folderTextStrength)!,
      border: Color.lerp(border, base.$3, palette.folderBorderStrength)!,
    );
  }

  /// The folder's ink colour (icon / counter tint) for the given palette name.
  Color folderColor(String? name, {required Color fallback}) =>
      name == null ? fallback : (_folderPalette.containsKey(name) ? folderColors(name).foreground : fallback);

  /// `colorForValue` on the web: a stable colour for an arbitrary string.
  FolderColors folderColorsForValue(String value) {
    var hash = 0;
    for (final unit in value.codeUnits) {
      hash = (((hash << 5) - hash + unit) & 0xFFFFFFFF);
    }
    if (hash >= 0x80000000) hash -= 0x100000000;
    final names = _folderPalette.keys.toList();
    return folderColors(names[hash.abs() % names.length]);
  }

  static const _folderPalette = <String, (Color, Color, Color)>{
    'sky': (Color(0xFFE8F3FF), Color(0xFF356F9F), Color(0xFFCFE3F7)),
    'mint': (Color(0xFFE8F7EF), Color(0xFF347653), Color(0xFFCCE9D9)),
    'amber': (Color(0xFFFFF4D8), Color(0xFF8B651C), Color(0xFFF1DFB2)),
    'rose': (Color(0xFFFDECEF), Color(0xFF9B5060), Color(0xFFF2D2D9)),
    'cyan': (Color(0xFFE7F7F8), Color(0xFF34777D), Color(0xFFC9E9EB)),
    'violet': (Color(0xFFF0EAFF), Color(0xFF6E58A3), Color(0xFFDED3F5)),
    'peach': (Color(0xFFFFF0E7), Color(0xFF9A603E), Color(0xFFF2D9CA)),
    'lime': (Color(0xFFEFF7DF), Color(0xFF607B31), Color(0xFFDCEABD)),
    'indigo': (Color(0xFFE9EDFF), Color(0xFF52649B), Color(0xFFD3DAF5)),
    'teal': (Color(0xFFE5F5F1), Color(0xFF34766B), Color(0xFFC8E5DE)),
    'sand': (Color(0xFFF7F0E4), Color(0xFF826A43), Color(0xFFEADCC5)),
    'slate': (Color(0xFFEDF1F5), Color(0xFF5D6D7D), Color(0xFFD9E0E7)),
  };

  static List<String> get folderPaletteNames => _folderPalette.keys.toList();

  @override
  XatBoxTokens copyWith({SkinPalette? palette, Display? display}) =>
      XatBoxTokens(palette ?? this.palette, display: display ?? this.display);

  /// Skins are discrete worlds; the theme switch is not animated between them.
  @override
  XatBoxTokens lerp(ThemeExtension<XatBoxTokens>? other, double t) =>
      other is XatBoxTokens && t >= 0.5 ? other : this;
}

@immutable
class FolderColors {
  const FolderColors({required this.background, required this.foreground, required this.border});
  final Color background;
  final Color foreground;
  final Color border;
}

/// `data-font-scale` and `data-density` of the web: text size S/M/L and list
/// density, applied on top of the skin.
enum FontScale {
  s(0.933),
  m(1),
  l(1.133);

  const FontScale(this.factor);
  final double factor;
}

enum ListDensity {
  compact(rowMinHeight: 44, rowPaddingY: 6),
  normal(rowMinHeight: 56, rowPaddingY: 10),
  spacious(rowMinHeight: 68, rowPaddingY: 15);

  const ListDensity({required this.rowMinHeight, required this.rowPaddingY});
  final double rowMinHeight;
  final double rowPaddingY;
}

@immutable
class Display {
  const Display({this.fontScale = FontScale.m, this.density = ListDensity.normal});
  final FontScale fontScale;
  final ListDensity density;

  double get scale => fontScale.factor;

  /// `--font-size-base` 15px, `--font-size-list` 14px, `--font-size-meta` 12px.
  double get fontSizeBase => 15 * scale;
  double get fontSizeList => 14 * scale;
  double get fontSizeMeta => 12 * scale;
  double get rowMinHeight => density.rowMinHeight;
  double get rowPaddingY => density.rowPaddingY;
}

extension XatBoxTokensContext on BuildContext {
  XatBoxTokens get tokens => Theme.of(this).extension<XatBoxTokens>() ?? XatBoxTokens.light;
}

/// Spacing tokens (`--space-*`) and the fixed sizes of the shell.
abstract final class Space {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const smd = 12.0;
  static const md = 16.0;
  static const mlg = 20.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 40.0;
  static const xxxl = 48.0;

  /// Legacy: the old single radius. Prefer `context.tokens.radius*`.
  static const radius = 12.0;

  /// `--control-sm/md/lg`.
  static const controlSm = 28.0;
  static const controlMd = 34.0;
  static const controlLg = 40.0;

  /// `--sidebar-width`, `--topbar-height`, `--mail-bar-height`.
  static const sidebarWidth = 304.0;
  static const sidebarCollapsedWidth = 84.0;
  static const topbarHeight = 56.0;
  static const mailBarHeight = 48.0;

  /// Minimum tap target on touch devices.
  static const tapTarget = 40.0;
}

/// Responsive breakpoints of the web (Tailwind defaults used there): `sm`
/// 640 — one-line message rows, floating composer; `lg` 1024 — static
/// sidebar and list + reading pane side by side.
abstract final class Breakpoints {
  static const sm = 640.0;
  static const md = 768.0;
  static const lg = 1024.0;
  static const xl = 1440.0;
}

extension LayoutContext on BuildContext {
  double get _width => MediaQuery.sizeOf(this).width;

  /// Phone: below `sm`.
  bool get isCompact => _width < Breakpoints.sm;

  /// `lg` and up: two panes + static sidebar, as on the web. The desktop app
  /// is always a windowed app with a mouse: its panes stay side by side down
  /// to the smallest window (`md` after the module rail).
  bool get isExpanded => _width >= (isDesktop ? Breakpoints.md : Breakpoints.lg);
}
