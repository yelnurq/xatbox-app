import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/localization/localization.dart';
import '../../core/preferences/app_preferences.dart';
import '../../core/theme/skin_backdrop.dart';
import '../../core/theme/tokens.dart';
import '../chat/presentation/chat_providers.dart';
import '../../core/platform/desktop_layout.dart';
import '../../core/platform/desktop_settings.dart';
import '../../core/platform/desktop_zoom.dart';
import '../../core/platform/desktop_keys.dart';

/// Appearance (the web's settings "Appearance" section + the topbar theme
/// switcher): light/dark mode, the skin grid, text size and list density.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final prefs = ref.watch(appPreferencesProvider);
    final notifier = ref.read(appPreferencesProvider.notifier);
    final desktop = ref.watch(desktopLayoutProvider);
    // Desktop: small cards across the panel (the web's style grid).
    final columns = context.isCompact ? 2 : 3;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAppearanceSection)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xl),
        children: [
          _SectionLabel(l10n.settingsTheme),
          const SizedBox(height: Space.sm),
          // Picking a mode returns to the standard skin, as on the web: a
          // committed skin would otherwise ignore the choice.
          SegmentedButton<AppThemePreference>(
            key: const Key('appearance_mode'),
            segments: [
              ButtonSegment(value: AppThemePreference.system, icon: const Icon(LucideIcons.monitor), label: Text(l10n.settingsThemeSystem)),
              ButtonSegment(value: AppThemePreference.light, icon: const Icon(LucideIcons.sun), label: Text(l10n.settingsThemeLight)),
              ButtonSegment(value: AppThemePreference.dark, icon: const Icon(LucideIcons.moon), label: Text(l10n.settingsThemeDark)),
            ],
            selected: {prefs.theme},
            showSelectedIcon: false,
            onSelectionChanged: (s) => notifier.update((p) => p.copyWith(theme: s.first, skin: AppSkin.standard)),
          ),
          const SizedBox(height: Space.lg),
          _SectionLabel(l10n.settingsStyle),
          const SizedBox(height: Space.xs),
          Text(l10n.settingsStyleHint, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: Space.smd),
          // Desktop: as many ~180px cards as the panel (not the window) fits.
          LayoutBuilder(
            builder: (context, box) => GridView.count(
            crossAxisCount: desktop ? (box.maxWidth / 180).floor().clamp(3, 6) : columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: Space.sm,
            crossAxisSpacing: Space.sm,
            childAspectRatio: 0.98,
            children: [
              for (final skin in AppSkin.offered(desktop: desktop))
                SkinTile(
                  key: Key('skin_${skin.name}'),
                  skin: skin,
                  selected: prefs.skin == skin,
                  custom: skin == AppSkin.glassCustom
                      ? ref.watch(desktopSettingsProvider.select((s) => s.backdrop))
                      : null,
                  onTap: () {
                    notifier.update((p) => p.copyWith(skin: skin));
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(l10n.settingsStyleApplied)));
                  },
                ),
            ],
          ),
          ),
          // «Свой фон»: the picture and its dim and blur, right under the
          // grid, so the change is visible behind the settings page itself.
          if (prefs.skin == AppSkin.glassCustom) ...[
            const SizedBox(height: Space.smd),
            const _CustomBackdropEditor(),
          ],
          // The two photographed backdrops carry their authors.
          ...[
            const SizedBox(height: Space.smd),
            Text(
              l10n.settingsBackdropCredits,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: t.textTertiary),
            ),
            const SizedBox(height: Space.xxs),
            Text(l10n.settingsBackdropCreditAstana, key: const Key('credit_astana'), style: Theme.of(context).textTheme.labelSmall),
            Text(l10n.settingsBackdropCreditSemey, key: const Key('credit_semey'), style: Theme.of(context).textTheme.labelSmall),
          ],
          const SizedBox(height: Space.lg),
          _SectionLabel(l10n.settingsTextSize),
          const SizedBox(height: Space.sm),
          SegmentedButton<FontScale>(
            key: const Key('appearance_font_scale'),
            segments: [
              ButtonSegment(value: FontScale.s, label: Text(l10n.settingsTextSizeSmall, style: TextStyle(fontSize: 14 * FontScale.s.factor / t.display.scale))),
              ButtonSegment(value: FontScale.m, label: Text(l10n.settingsTextSizeMedium, style: TextStyle(fontSize: 15 * FontScale.m.factor / t.display.scale))),
              ButtonSegment(value: FontScale.l, label: Text(l10n.settingsTextSizeLarge, style: TextStyle(fontSize: 17 * FontScale.l.factor / t.display.scale))),
            ],
            selected: {prefs.fontScale},
            showSelectedIcon: false,
            onSelectionChanged: (s) => notifier.update((p) => p.copyWith(fontScale: s.first)),
          ),
          const SizedBox(height: Space.lg),
          _SectionLabel(l10n.settingsListDensity),
          const SizedBox(height: Space.sm),
          SegmentedButton<ListDensity>(
            key: const Key('appearance_density'),
            segments: [
              ButtonSegment(value: ListDensity.compact, label: Text(l10n.settingsDensityCompact)),
              ButtonSegment(value: ListDensity.normal, label: Text(l10n.settingsDensityNormal)),
              ButtonSegment(value: ListDensity.spacious, label: Text(l10n.settingsDensitySpacious)),
            ],
            selected: {prefs.density},
            showSelectedIcon: false,
            onSelectionChanged: (s) => notifier.update((p) => p.copyWith(density: s.first)),
          ),
          const SizedBox(height: Space.xs),
          Text(l10n.settingsAppearanceHint, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: Space.lg),
          _SectionLabel(l10n.todayStartScreen),
          const SizedBox(height: Space.sm),
          SegmentedButton<StartScreen>(
            key: const Key('appearance_start_screen'),
            segments: [
              // Desktop has no «Сегодня» (the web shell opens on mail).
              if (!desktop)
                ButtonSegment(value: StartScreen.today, icon: const Icon(LucideIcons.sunrise), label: Text(l10n.todayTab)),
              ButtonSegment(value: StartScreen.mail, icon: const Icon(LucideIcons.mail), label: Text(l10n.tabMail)),
              if (ref.watch(chatEnabledProvider) || prefs.startScreen == StartScreen.chat)
                ButtonSegment(value: StartScreen.chat, icon: const Icon(LucideIcons.messageCircle), label: Text(l10n.tabChat)),
            ],
            selected: {desktop && prefs.startScreen == StartScreen.today ? StartScreen.mail : prefs.startScreen},
            showSelectedIcon: false,
            onSelectionChanged: (s) => notifier.update((p) => p.copyWith(startScreen: s.first)),
          ),
          const SizedBox(height: Space.xs),
          Text(l10n.todayStartScreenHint, style: Theme.of(context).textTheme.bodySmall),
          if (desktop) ...[
            const SizedBox(height: Space.lg),
            _SectionLabel(l10n.desktopZoom),
            const SizedBox(height: Space.sm),
            const _ZoomControl(),
            const SizedBox(height: Space.xs),
            Text(l10n.desktopZoomHint, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Desktop «Масштаб»: − 100% + and «Сбросить» (also Ctrl+- / Ctrl+= / Ctrl+0).
class _ZoomControl extends ConsumerWidget {
  const _ZoomControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final zoom = ref.watch(desktopZoomProvider);
    final notifier = ref.read(desktopZoomProvider.notifier);
    return Row(
      children: [
        IconButton.outlined(
          key: const Key('zoom_out'),
          tooltip: '$commandKeyLabel −',
          onPressed: zoom <= DesktopZoom.steps.first ? null : notifier.zoomOut,
          icon: const Icon(LucideIcons.minus, size: 16),
        ),
        SizedBox(
          width: 72,
          child: Text(
            DesktopZoom.label(zoom),
            key: const Key('zoom_value'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        IconButton.outlined(
          key: const Key('zoom_in'),
          tooltip: '$commandKeyLabel +',
          onPressed: zoom >= DesktopZoom.steps.last ? null : notifier.zoomIn,
          icon: const Icon(LucideIcons.plus, size: 16),
        ),
        const SizedBox(width: Space.sm),
        TextButton(
          onPressed: zoom == DesktopZoom.normal ? null : notifier.reset,
          child: Text(l10n.desktopZoomReset),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: Theme.of(context).textTheme.titleSmall);
}

/// Localised skin name and hint (`skin*` / `skin*Hint` keys of the web).
extension AppSkinLabels on AppSkin {
  String label(AppLocalizations l10n) => switch (this) {
    AppSkin.standard => l10n.skinStandard,
    AppSkin.steppe => l10n.skinSteppe,
    AppSkin.paper => l10n.skinPaper,
    AppSkin.graphite => l10n.skinGraphite,
    AppSkin.kok => l10n.skinKok,
    AppSkin.midnight => l10n.skinMidnight,
    AppSkin.terminal => l10n.skinTerminal,
    AppSkin.lilac => l10n.skinLilac,
    AppSkin.contrast => l10n.skinContrast,
    AppSkin.forest => l10n.skinForest,
    AppSkin.glassForest => l10n.skinGlassForest,
    AppSkin.glassSpace => l10n.skinGlassSpace,
    AppSkin.glassAstana => l10n.skinGlassAstana,
    AppSkin.glassSemey => l10n.skinGlassSemey,
    AppSkin.glassCustom => l10n.skinGlassCustom,
  };

  String hint(AppLocalizations l10n) => switch (this) {
    AppSkin.standard => l10n.skinStandardHint,
    AppSkin.steppe => l10n.skinSteppeHint,
    AppSkin.paper => l10n.skinPaperHint,
    AppSkin.graphite => l10n.skinGraphiteHint,
    AppSkin.kok => l10n.skinKokHint,
    AppSkin.midnight => l10n.skinMidnightHint,
    AppSkin.terminal => l10n.skinTerminalHint,
    AppSkin.lilac => l10n.skinLilacHint,
    AppSkin.contrast => l10n.skinContrastHint,
    AppSkin.forest => l10n.skinForestHint,
    AppSkin.glassForest => l10n.skinGlassForestHint,
    AppSkin.glassSpace => l10n.skinGlassSpaceHint,
    AppSkin.glassAstana => l10n.skinGlassAstanaHint,
    AppSkin.glassSemey => l10n.skinGlassSemeyHint,
    AppSkin.glassCustom => l10n.skinGlassCustomHint,
  };
}

/// «Свой фон» (desktop): choose a picture, darken it and blur it. The page
/// itself sits on the backdrop, so every change is visible behind it.
class _CustomBackdropEditor extends ConsumerStatefulWidget {
  const _CustomBackdropEditor();

  @override
  ConsumerState<_CustomBackdropEditor> createState() => _CustomBackdropEditorState();
}

class _CustomBackdropEditorState extends ConsumerState<_CustomBackdropEditor> {
  bool _busy = false;

  Future<void> _pick() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.pickFiles(type: FileType.image);
      final path = picked.firstOrNull?.path;
      if (path == null) return;
      final ok = await ref.read(desktopSettingsProvider.notifier).setBackdrop(path);
      if (!ok) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.settingsBackdropFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final settings = ref.watch(desktopSettingsProvider);
    final notifier = ref.read(desktopSettingsProvider.notifier);
    final chosen = settings.backdropPath != null;
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settingsBackdropOwn, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: Space.xxs),
          Text(
            chosen ? l10n.settingsBackdropOwnHint : l10n.settingsBackdropNone,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.textTertiary),
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              FilledButton.icon(
                key: const Key('backdrop_pick'),
                onPressed: _busy ? null : _pick,
                icon: const Icon(LucideIcons.image, size: 18),
                label: Text(chosen ? l10n.settingsBackdropReplace : l10n.settingsBackdropPick),
              ),
              if (chosen) ...[
                const SizedBox(width: Space.sm),
                TextButton(
                  key: const Key('backdrop_remove'),
                  onPressed: _busy ? null : notifier.clearBackdrop,
                  child: Text(l10n.settingsBackdropRemove),
                ),
              ],
            ],
          ),
          const SizedBox(height: Space.sm),
          _BackdropSlider(
            sliderKey: const Key('backdrop_dim'),
            label: l10n.settingsBackdropDim,
            value: settings.backdropDim,
            max: 1,
            enabled: chosen,
            // Percent, because «затемнение 0,45» means nothing to a reader.
            display: '${(settings.backdropDim * 100).round()}%',
            onChanged: (v) => notifier.update((s) => s.copyWith(backdropDim: v)),
          ),
          _BackdropSlider(
            sliderKey: const Key('backdrop_blur'),
            label: l10n.settingsBackdropBlur,
            value: settings.backdropBlur,
            max: 30,
            enabled: chosen,
            display: '${(settings.backdropBlur / 30 * 100).round()}%',
            onChanged: (v) => notifier.update((s) => s.copyWith(backdropBlur: v)),
          ),
        ],
      ),
    );
  }
}

class _BackdropSlider extends StatelessWidget {
  const _BackdropSlider({
    required this.sliderKey,
    required this.label,
    required this.value,
    required this.max,
    required this.enabled,
    required this.display,
    required this.onChanged,
  });

  final Key sliderKey;
  final String label;
  final double value;
  final double max;
  final bool enabled;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        SizedBox(width: 108, child: Text(label, style: Theme.of(context).textTheme.labelMedium)),
        Expanded(
          child: Slider(
            key: sliderKey,
            value: value.clamp(0, max),
            max: max,
            divisions: 20,
            label: display,
            onChanged: enabled ? onChanged : null,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            display,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: t.textTertiary),
          ),
        ),
      ],
    );
  }
}

/// One tile of the skin grid: the web's `SkinSwatch` (a miniature sidebar +
/// message list drawn in the skin's own colours and face) with name and hint.
class SkinTile extends StatelessWidget {
  const SkinTile({super.key, required this.skin, required this.selected, required this.onTap, this.custom});

  final AppSkin skin;
  final bool selected;
  final VoidCallback onTap;

  /// «Свой фон»: the picture the user chose, shown in the miniature.
  final CustomBackdrop? custom;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    // The standard swatch previews the brightness the mode would give.
    final p = skin == AppSkin.standard
        ? (t.palette.isDark ? SkinPalettes.standardDark : SkinPalettes.standardLight)
        : skin.palette(ThemeMode.light, Brightness.light);
    final preview = XatBoxTokens(p);
    return Material(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusMd),
        side: BorderSide(color: selected ? t.primary : t.border, width: selected ? 2 : t.borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: SkinSwatch(tokens: preview, custom: custom)),
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      skin.label(l10n),
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selected) Icon(LucideIcons.check, size: 16, color: t.primary),
                ],
              ),
              Text(
                skin.hint(l10n),
                style: Theme.of(context).textTheme.labelSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The miniature: a sidebar strip (accent bar + two lines) beside a three-row
/// message list, all in the previewed skin's colours and typeface.
class SkinSwatch extends StatelessWidget {
  const SkinSwatch({super.key, required this.tokens, this.custom});
  final XatBoxTokens tokens;

  /// «Свой фон»: the miniature shows the user's own picture too.
  final CustomBackdrop? custom;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final line = t.palette.sidebar != null ? t.sidebarTextSecondary : t.textTertiary;
    Widget bar(double widthFactor, double opacity) => FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 4,
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(color: line.withValues(alpha: opacity), borderRadius: BorderRadius.circular(2)),
      ),
    );
    TextStyle row(Color color, {FontWeight weight = FontWeight.w400}) =>
        TextStyle(fontFamily: t.fontText, fontSize: 10, height: 1.3, color: color, fontWeight: weight);
    Widget cell(Widget child, {bool last = false, Color? background, bool rail = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        border: Border(
          bottom: last ? BorderSide.none : BorderSide(color: t.border),
          left: rail ? BorderSide(color: t.primary, width: 2) : BorderSide.none,
        ),
      ),
      child: child,
    );
    final swatch = Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: t.appBg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: t.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 34,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: t.sidebarSurface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: t.sidebarBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    decoration: BoxDecoration(color: t.sidebarPrimary, borderRadius: BorderRadius.circular(3)),
                  ),
                  bar(0.8, 0.55),
                  bar(0.6, 0.4),
                  bar(0.66, 0.4),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 66,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: t.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  cell(
                    Row(
                      children: [
                        Container(width: 5, height: 5, decoration: BoxDecoration(color: t.unreadPip, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Expanded(child: Text(context.l10n.folderInbox, maxLines: 1, overflow: TextOverflow.ellipsis, style: row(t.textPrimary, weight: FontWeight.w600))),
                      ],
                    ),
                    background: t.primarySoft,
                    rail: true,
                  ),
                  cell(Text('Аа Әә Ққ Ңң', maxLines: 1, overflow: TextOverflow.ellipsis, style: row(t.textSecondary))),
                  cell(Text('12:05', maxLines: 1, style: row(t.textTertiary)), last: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    final glass = t.glass;
    if (glass == null) return swatch;
    // Glass skins: the miniature floats over its own picture.
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: Stack(
        fit: StackFit.expand,
        children: [SkinBackdropView(backdrop: glass.backdrop, custom: custom), swatch],
      ),
    );
  }
}
