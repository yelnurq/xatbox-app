import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/tokens.dart';
import 'ds/x_badge.dart';

/// One destination of [GlassTabBar].
class GlassTab {
  const GlassTab({
    required this.icon,
    required this.label,
    this.badge = 0,
    this.key,
  });

  final IconData icon;
  final String label;

  /// Unread count shown on the icon (0 = none).
  final int badge;
  final Key? key;
}

/// The phone's bottom navigation in the manner of iOS 26 «Liquid Glass»: a
/// floating capsule over the content that blurs and brightens what scrolls
/// under it, a light rim, and a lens that glides to the selected tab.
///
/// Put it in `Scaffold.bottomNavigationBar` with `extendBody: true`, so the
/// pages run under the glass; the Scaffold then reports the bar's height as
/// bottom padding to the body.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<GlassTab> tabs;

  /// -1 = none selected.
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const barHeight = 64.0;
  static const _radius = 32.0;
  static const _margin = 12.0;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _margin,
        0,
        _margin,
        bottomInset > 0 ? bottomInset : _margin,
      ),
      child: GlassSurface(
        radius: _radius,
        child: SizedBox(
          height: barHeight,
          child: LayoutBuilder(
            builder: (context, box) {
              final slot = box.maxWidth / tabs.length;
              return Stack(
                children: [
                  if (selectedIndex >= 0 && selectedIndex < tabs.length)
                    AnimatedPositioned(
                      key: const Key('glass_tab_lens'),
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 380),
                      curve: Curves.easeOutBack,
                      left: slot * selectedIndex + 4,
                      top: 6,
                      width: slot - 8,
                      height: barHeight - 12,
                      child: _Lens(dark: dark),
                    ),
                  Row(
                    children: [
                      for (var i = 0; i < tabs.length; i++)
                        Expanded(
                          child: _TabButton(
                            tab: tabs[i],
                            selected: i == selectedIndex,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onSelected(i);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Frosted glass: blur and saturation lift of what lies behind, a
/// see-through tint of the page surface, a light rim and a soft shadow. The
/// tab bar and the «Ещё» panel are made of it.
class GlassSurface extends StatelessWidget {
  const GlassSurface({super.key, required this.child, this.radius = 28});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = t.surface.withValues(alpha: dark ? 0.55 : 0.62);
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            // A soft lift, not a slab: iOS 26 glass barely casts a shadow.
            color: Colors.black.withValues(alpha: dark ? 0.30 : 0.07),
            blurRadius: 24,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          // Blur plus a saturation lift: colours behind the glass stay
          // vivid instead of washing out (the iOS «vibrancy»).
          filter: ImageFilter.compose(
            outer: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            inner: const ColorFilter.matrix(_saturate),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: shape,
              border: Border.all(
                color: Colors.white.withValues(alpha: dark ? 0.16 : 0.55),
                width: 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(
                    Colors.white.withValues(alpha: dark ? 0.06 : 0.22),
                    tint,
                  ),
                  tint,
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  /// Saturation 1.6 (luminance-preserving colour matrix).
  static const _saturate = <double>[
    1.4474,
    -0.4288,
    -0.0186,
    0,
    0,
    -0.1270,
    1.1998,
    -0.0728,
    0,
    0,
    -0.1270,
    -0.4288,
    1.5558,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

/// The selected tab's glass lens: a brighter, primary-tinted drop of glass.
class _Lens extends StatelessWidget {
  const _Lens({required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Color.alphaBlend(
          t.primary.withValues(alpha: dark ? 0.22 : 0.12),
          Colors.white.withValues(alpha: dark ? 0.08 : 0.45),
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0.18 : 0.7),
          width: 1,
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final GlassTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final color = selected ? t.primary : t.textSecondary;
    Widget icon = Icon(tab.icon, size: 22, color: color);
    if (tab.badge > 0) {
      icon = Badge(
        label: Text(CountPill.format(tab.badge)),
        backgroundColor: t.danger,
        textColor: t.textInverse,
        child: icon,
      );
    }
    final countLabel = tab.badge > 0 ? ', ${tab.badge}' : '';
    return Semantics(
      button: true,
      selected: selected,
      label: '${tab.label}$countLabel',
      excludeSemantics: true,
      child: InkResponse(
        key: tab.key,
        onTap: onTap,
        radius: 32,
        highlightShape: BoxShape.circle,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(height: 3),
            Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
