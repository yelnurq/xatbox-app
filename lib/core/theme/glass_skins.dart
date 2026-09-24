part of 'skins.dart';

/// The picture behind a glass skin (`skin_backdrop.dart`): painted by the
/// app ([photo] null), a photograph from the app's assets, or — for
/// [SkinBackdrop.custom] — the picture the user chose ([CustomBackdrop]).
enum SkinBackdrop {
  forest,
  space,
  astana('assets/backdrops/astana.jpg'),
  semey('assets/backdrops/semey.jpg'),

  /// The user's own picture, kept in the app's data directory
  /// (`desktop_settings.json`, «Свой фон»).
  custom;

  const SkinBackdrop([this.photo]);

  final String? photo;
}

/// The picture behind [SkinBackdrop.custom] and how it is toned down so the
/// text over it stays readable: [dim] darkens it, [blur] softens it. A null
/// or missing [path] leaves the skin on its plain dark surface, which is
/// what a fresh «Свой фон» looks like until a picture is chosen.
@immutable
class CustomBackdrop {
  const CustomBackdrop({this.path, this.dim = 0.45, this.blur = 0});

  final String? path;

  /// 0…1 of black over the picture.
  final double dim;

  /// Gaussian sigma in logical pixels, 0…30.
  final double blur;

  @override
  bool operator ==(Object other) =>
      other is CustomBackdrop && other.path == path && other.dim == dim && other.blur == blur;

  @override
  int get hashCode => Object.hash(path, dim, blur);
}

/// What makes a skin «glass»: the backdrop under the app, the opaque
/// surface of dialogs and menus (text over a picture needs a solid sheet),
/// and how much the rail and the top bar blur what is behind them.
@immutable
class GlassStyle {
  const GlassStyle({required this.backdrop, required this.solidSurface, this.blur = 18});

  final SkinBackdrop backdrop;
  final Color solidSurface;
  final double blur;
}

/// Desktop-only skins: translucent surfaces, borders and buttons over a
/// painted forest or starry sky. Dark, so the white text stays readable
/// over any part of the picture.
abstract final class GlassPalettes {
  static const forest = SkinPalette(
    id: AppSkin.glassForest,
    brightness: Brightness.dark,
    fontDisplay: 'Golos Text',
    fontText: 'Golos Text',
    monospace: false,
    appBg: Color(0x00000000),
    surface: Color(0xA60C1A15),
    surfaceSubtle: Color(0x1AFFFFFF),
    surfaceMuted: Color(0x8C0B1713),
    surfaceHover: Color(0x24FFFFFF),
    surfaceSelected: Color(0x3D8BD89E),
    textPrimary: Color(0xFFF3F8F2),
    textSecondary: Color(0xFFD3E0D5),
    textTertiary: Color(0xFFA7B9AB),
    textDisabled: Color(0xFF6E8173),
    textInverse: Color(0xFF0B1A12),
    border: Color(0x2EFFFFFF),
    borderStrong: Color(0x4DFFFFFF),
    divider: Color(0x1FFFFFFF),
    primary: Color(0xFF8BD89E),
    primaryHover: Color(0xFFA5E6B5),
    primaryActive: Color(0xFF70C286),
    primarySoft: Color(0x3D8BD89E),
    focus: Color(0xFFB8F1C6),
    info: Color(0xFF8FCBF2),
    infoSoft: Color(0x338FCBF2),
    success: Color(0xFF82D99C),
    successSoft: Color(0x3382D99C),
    warning: Color(0xFFF3C66D),
    warningSoft: Color(0x33F3C66D),
    danger: Color(0xFFFF8F85),
    dangerSoft: Color(0x33FF8F85),
    labelBlue: Color(0x338FCBF2),
    labelBlueText: Color(0xFFBCDEF6),
    labelPurple: Color(0x33BAA0F2),
    labelPurpleText: Color(0xFFD9CBFA),
    labelGreen: Color(0x3382D99C),
    labelGreenText: Color(0xFFC0ECCB),
    labelYellow: Color(0x33F3C66D),
    labelYellowText: Color(0xFFF7DEA6),
    unreadPip: Color(0xFFF3C66D),
    selection: Color(0x668BD89E),
    mark: Color(0xFFA5E6B5),
    loginField: Color(0xFF0C1A15),
    loginInk: Color(0xFFFFFFFF),
    folderColorStrength: 0.22,
    folderBorderStrength: 0.34,
    folderTextStrength: 0.6,
    radiusXs: 6, radiusSm: 10, radiusMd: 14, radiusLg: 18, radiusXl: 22,
    shadows: true,
    borderWidth: 1,
    navRadius: 12,
    navActive: NavActiveStyle.tint,
    titleWeight: FontWeight.w600,
    titleUppercase: false,
    titlePrefix: '',
    sectionPrefix: '',
    sidebar: null,
    glass: GlassStyle(backdrop: SkinBackdrop.forest, solidSurface: Color(0xFF13241D)),
  );

  static const space = SkinPalette(
    id: AppSkin.glassSpace,
    brightness: Brightness.dark,
    fontDisplay: 'Golos Text',
    fontText: 'Golos Text',
    monospace: false,
    appBg: Color(0x00000000),
    surface: Color(0xA60A0D24),
    surfaceSubtle: Color(0x1AFFFFFF),
    surfaceMuted: Color(0x8C090B20),
    surfaceHover: Color(0x24FFFFFF),
    surfaceSelected: Color(0x40A3B3FF),
    textPrimary: Color(0xFFF2F3FF),
    textSecondary: Color(0xFFD2D6F2),
    textTertiary: Color(0xFFA2A8CF),
    textDisabled: Color(0xFF6B7098),
    textInverse: Color(0xFF0A0D26),
    border: Color(0x2EFFFFFF),
    borderStrong: Color(0x4DFFFFFF),
    divider: Color(0x1FFFFFFF),
    primary: Color(0xFFA3B3FF),
    primaryHover: Color(0xFFBBC7FF),
    primaryActive: Color(0xFF8A9CF5),
    primarySoft: Color(0x40A3B3FF),
    focus: Color(0xFFC6D0FF),
    info: Color(0xFF86D3F5),
    infoSoft: Color(0x3386D3F5),
    success: Color(0xFF7FDDB0),
    successSoft: Color(0x337FDDB0),
    warning: Color(0xFFF5C977),
    warningSoft: Color(0x33F5C977),
    danger: Color(0xFFFF8FA3),
    dangerSoft: Color(0x33FF8FA3),
    labelBlue: Color(0x3386D3F5),
    labelBlueText: Color(0xFFBDE6F8),
    labelPurple: Color(0x33D29BF5),
    labelPurpleText: Color(0xFFE6CCFA),
    labelGreen: Color(0x337FDDB0),
    labelGreenText: Color(0xFFBDEFD6),
    labelYellow: Color(0x33F5C977),
    labelYellowText: Color(0xFFF8E0AA),
    unreadPip: Color(0xFFF5C977),
    selection: Color(0x66A3B3FF),
    mark: Color(0xFFBBC7FF),
    loginField: Color(0xFF0A0D24),
    loginInk: Color(0xFFFFFFFF),
    folderColorStrength: 0.22,
    folderBorderStrength: 0.34,
    folderTextStrength: 0.6,
    radiusXs: 6, radiusSm: 10, radiusMd: 14, radiusLg: 18, radiusXl: 22,
    shadows: true,
    borderWidth: 1,
    navRadius: 12,
    navActive: NavActiveStyle.tint,
    titleWeight: FontWeight.w600,
    titleUppercase: false,
    titlePrefix: '',
    sectionPrefix: '',
    sidebar: null,
    glass: GlassStyle(backdrop: SkinBackdrop.space, solidSurface: Color(0xFF141836)),
  );

  /// Astana at dusk: Baiterek, Khan Shatyr and the mosque over the steppe,
  /// gold on indigo.
  static const astana = SkinPalette(
    id: AppSkin.glassAstana,
    brightness: Brightness.dark,
    fontDisplay: 'Golos Text',
    fontText: 'Golos Text',
    monospace: false,
    appBg: Color(0x00000000),
    surface: Color(0xA60E1330),
    surfaceSubtle: Color(0x1AFFFFFF),
    surfaceMuted: Color(0x8C0C112B),
    surfaceHover: Color(0x24FFFFFF),
    surfaceSelected: Color(0x40F5C878),
    textPrimary: Color(0xFFF7F4EC),
    textSecondary: Color(0xFFDCD8E6),
    textTertiary: Color(0xFFAAA6C2),
    textDisabled: Color(0xFF706C8C),
    textInverse: Color(0xFF16112B),
    border: Color(0x2EFFFFFF),
    borderStrong: Color(0x4DFFFFFF),
    divider: Color(0x1FFFFFFF),
    primary: Color(0xFFF5C878),
    primaryHover: Color(0xFFFFD895),
    primaryActive: Color(0xFFDCAF60),
    primarySoft: Color(0x40F5C878),
    focus: Color(0xFFFFE2AE),
    info: Color(0xFF86BEF0),
    infoSoft: Color(0x3386BEF0),
    success: Color(0xFF86D9A8),
    successSoft: Color(0x3386D9A8),
    warning: Color(0xFFF5C878),
    warningSoft: Color(0x33F5C878),
    danger: Color(0xFFFF93A0),
    dangerSoft: Color(0x33FF93A0),
    labelBlue: Color(0x3386BEF0),
    labelBlueText: Color(0xFFBBDCF7),
    labelPurple: Color(0x33C49BF2),
    labelPurpleText: Color(0xFFE0CAFA),
    labelGreen: Color(0x3386D9A8),
    labelGreenText: Color(0xFFC1ECD3),
    labelYellow: Color(0x33F5C878),
    labelYellowText: Color(0xFFF9DFAE),
    unreadPip: Color(0xFFF5C878),
    selection: Color(0x66F5C878),
    mark: Color(0xFFFFD895),
    loginField: Color(0xFF0E1330),
    loginInk: Color(0xFFFFFFFF),
    folderColorStrength: 0.22,
    folderBorderStrength: 0.34,
    folderTextStrength: 0.6,
    radiusXs: 6, radiusSm: 10, radiusMd: 14, radiusLg: 18, radiusXl: 22,
    shadows: true,
    borderWidth: 1,
    navRadius: 12,
    navActive: NavActiveStyle.tint,
    titleWeight: FontWeight.w600,
    titleUppercase: false,
    titlePrefix: '',
    sectionPrefix: '',
    sidebar: null,
    glass: GlassStyle(backdrop: SkinBackdrop.astana, solidSurface: Color(0xFF161B3C)),
  );

  /// Semey: dawn over the Irtysh and the suspension bridge, warm on teal.
  static const semey = SkinPalette(
    id: AppSkin.glassSemey,
    brightness: Brightness.dark,
    fontDisplay: 'Golos Text',
    fontText: 'Golos Text',
    monospace: false,
    appBg: Color(0x00000000),
    surface: Color(0xA60A1A26),
    surfaceSubtle: Color(0x1AFFFFFF),
    surfaceMuted: Color(0x8C091722),
    surfaceHover: Color(0x24FFFFFF),
    surfaceSelected: Color(0x407FD0E6),
    textPrimary: Color(0xFFF1F7F9),
    textSecondary: Color(0xFFD2E0E6),
    textTertiary: Color(0xFFA3B6BF),
    textDisabled: Color(0xFF6C7F89),
    textInverse: Color(0xFF071720),
    border: Color(0x2EFFFFFF),
    borderStrong: Color(0x4DFFFFFF),
    divider: Color(0x1FFFFFFF),
    primary: Color(0xFF7FD0E6),
    primaryHover: Color(0xFF9CDEF0),
    primaryActive: Color(0xFF63B7CF),
    primarySoft: Color(0x407FD0E6),
    focus: Color(0xFFB2E8F6),
    info: Color(0xFF7FD0E6),
    infoSoft: Color(0x337FD0E6),
    success: Color(0xFF85D9A5),
    successSoft: Color(0x3385D9A5),
    warning: Color(0xFFF2B36E),
    warningSoft: Color(0x33F2B36E),
    danger: Color(0xFFFF8F87),
    dangerSoft: Color(0x33FF8F87),
    labelBlue: Color(0x337FD0E6),
    labelBlueText: Color(0xFFBCE6F2),
    labelPurple: Color(0x33B4A6F0),
    labelPurpleText: Color(0xFFD8CFFA),
    labelGreen: Color(0x3385D9A5),
    labelGreenText: Color(0xFFC0ECD1),
    labelYellow: Color(0x33F2B36E),
    labelYellowText: Color(0xFFF7D6A8),
    unreadPip: Color(0xFFF2B36E),
    selection: Color(0x667FD0E6),
    mark: Color(0xFF9CDEF0),
    loginField: Color(0xFF0A1A26),
    loginInk: Color(0xFFFFFFFF),
    folderColorStrength: 0.22,
    folderBorderStrength: 0.34,
    folderTextStrength: 0.6,
    radiusXs: 6, radiusSm: 10, radiusMd: 14, radiusLg: 18, radiusXl: 22,
    shadows: true,
    borderWidth: 1,
    navRadius: 12,
    navActive: NavActiveStyle.tint,
    titleWeight: FontWeight.w600,
    titleUppercase: false,
    titlePrefix: '',
    sectionPrefix: '',
    sidebar: null,
    glass: GlassStyle(backdrop: SkinBackdrop.semey, solidSurface: Color(0xFF122A38)),
  );

  /// «Свой фон»: the user's own picture. Deliberately neutral — a slate
  /// grey with one soft blue accent — because it has to sit on a photograph
  /// nobody has seen. The dim slider, not the palette, keeps text readable.
  static const custom = SkinPalette(
    id: AppSkin.glassCustom,
    brightness: Brightness.dark,
    fontDisplay: 'Golos Text',
    fontText: 'Golos Text',
    monospace: false,
    appBg: Color(0x00000000),
    surface: Color(0xA6141619),
    surfaceSubtle: Color(0x1AFFFFFF),
    surfaceMuted: Color(0x8C121417),
    surfaceHover: Color(0x24FFFFFF),
    surfaceSelected: Color(0x408FBDF2),
    textPrimary: Color(0xFFF4F5F7),
    textSecondary: Color(0xFFD8DBE0),
    textTertiary: Color(0xFFAAAEB6),
    textDisabled: Color(0xFF71757D),
    textInverse: Color(0xFF14171C),
    border: Color(0x2EFFFFFF),
    borderStrong: Color(0x4DFFFFFF),
    divider: Color(0x1FFFFFFF),
    primary: Color(0xFF8FBDF2),
    primaryHover: Color(0xFFAECFF7),
    primaryActive: Color(0xFF6FA3DE),
    primarySoft: Color(0x408FBDF2),
    focus: Color(0xFFBCDCFA),
    info: Color(0xFF8FBDF2),
    infoSoft: Color(0x338FBDF2),
    success: Color(0xFF85D9A5),
    successSoft: Color(0x3385D9A5),
    warning: Color(0xFFF2C46E),
    warningSoft: Color(0x33F2C46E),
    danger: Color(0xFFFF8F87),
    dangerSoft: Color(0x33FF8F87),
    labelBlue: Color(0x338FBDF2),
    labelBlueText: Color(0xFFC6DDF7),
    labelPurple: Color(0x33B4A6F0),
    labelPurpleText: Color(0xFFD8CFFA),
    labelGreen: Color(0x3385D9A5),
    labelGreenText: Color(0xFFC0ECD1),
    labelYellow: Color(0x33F2C46E),
    labelYellowText: Color(0xFFF7DEA8),
    unreadPip: Color(0xFFF2C46E),
    selection: Color(0x668FBDF2),
    mark: Color(0xFFAECFF7),
    loginField: Color(0xFF141619),
    loginInk: Color(0xFFFFFFFF),
    folderColorStrength: 0.22,
    folderBorderStrength: 0.34,
    folderTextStrength: 0.6,
    radiusXs: 6, radiusSm: 10, radiusMd: 14, radiusLg: 18, radiusXl: 22,
    shadows: true,
    borderWidth: 1,
    navRadius: 12,
    navActive: NavActiveStyle.tint,
    titleWeight: FontWeight.w600,
    titleUppercase: false,
    titlePrefix: '',
    sectionPrefix: '',
    sidebar: null,
    glass: GlassStyle(backdrop: SkinBackdrop.custom, solidSurface: Color(0xFF16181C)),
  );
}
