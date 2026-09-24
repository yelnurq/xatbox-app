import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/localization/localization.dart';
import '../../../core/platform/desktop_layout.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import 'compose_screen.dart';

/// The open composer of the desktop app (the web's floating compose window):
/// null when closed.
@immutable
class ComposeWindowState {
  const ComposeWindowState({
    required this.args,
    required this.generation,
    this.minimized = false,
    this.expanded = false,
    this.closeRequest = 0,
  });

  final ComposeArgs args;

  /// Bumped on every open: a new composer replaces the old one's state.
  final int generation;
  final bool minimized;
  final bool expanded;

  /// Bumped by the minimised bar's ✕: the composer saves the draft and
  /// closes itself (as its own ✕ does).
  final int closeRequest;

  ComposeWindowState copyWith({bool? minimized, bool? expanded, int? closeRequest}) => ComposeWindowState(
    args: args,
    generation: generation,
    minimized: minimized ?? this.minimized,
    expanded: expanded ?? this.expanded,
    closeRequest: closeRequest ?? this.closeRequest,
  );
}

class ComposeWindowNotifier extends Notifier<ComposeWindowState?> {
  int _generation = 0;

  @override
  ComposeWindowState? build() => null;

  void open(ComposeArgs args) => state = ComposeWindowState(args: args, generation: ++_generation);
  void close() => state = null;

  /// «Save and close» from outside the composer (the minimised bar).
  void requestClose() {
    final s = state;
    if (s != null) state = s.copyWith(closeRequest: s.closeRequest + 1);
  }

  void setMinimized(bool value) {
    final s = state;
    if (s != null) state = s.copyWith(minimized: value);
  }

  void toggleExpanded() {
    final s = state;
    if (s != null) state = s.copyWith(expanded: !s.expanded, minimized: false);
  }
}

final composeWindowProvider = NotifierProvider<ComposeWindowNotifier, ComposeWindowState?>(ComposeWindowNotifier.new);

/// The subject typed in the open composer, for the minimised bar's title.
class ComposeWindowSubject extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
}

final composeWindowSubjectProvider = NotifierProvider<ComposeWindowSubject, String>(ComposeWindowSubject.new);

/// Opens the composer: the floating window on desktop (the page stays usable
/// behind it, as on the web), the full-screen page on phones.
void openCompose(WidgetRef ref, [ComposeArgs args = const ComposeArgs.blank()]) {
  if (ref.read(desktopLayoutProvider)) {
    ref.read(composeWindowProvider.notifier).open(args);
  } else {
    ref.read(appRouterProvider).push(Routes.mailCompose, extra: args);
  }
}

/// Paints the floating composer over [child] (desktop shell): 580×520 at
/// the bottom right, a title bar when minimised, most of the window when
/// expanded — `.compose-window` of the web.
class ComposeWindowHost extends ConsumerWidget {
  const ComposeWindowHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(composeWindowProvider);
    // Always a Stack with [child] first: opening the composer must not
    // re-parent (and so rebuild) the pages underneath.
    if (state == null) return Stack(fit: StackFit.expand, children: [child]);
    final t = context.tokens;
    final notifier = ref.read(composeWindowProvider.notifier);
    final size = MediaQuery.sizeOf(context);
    final radius = BorderRadius.circular(state.expanded ? 12 : 14);
    final shadow = [
      BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.16), blurRadius: 42, offset: const Offset(0, 18)),
      BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6)),
    ];

    final composer = ComposeScreen(
      key: ValueKey('compose_window_${state.generation}'),
      args: state.args,
      window: ComposeWindowChrome(
        expanded: state.expanded,
        onClose: notifier.close,
        onMinimize: () => notifier.setMinimized(true),
        onToggleExpanded: notifier.toggleExpanded,
        closeRequest: state.closeRequest,
      ),
    );

    final normalWidth = 580.0.clamp(0.0, size.width - 48);
    final normalHeight = 520.0.clamp(0.0, size.height - 80);
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        // One slot for the composer in every state, so minimising or
        // expanding never rebuilds it (typed text and uploads survive).
        Positioned(
          left: state.expanded ? 32 : null,
          top: state.expanded ? 32 : null,
          right: state.expanded ? 32 : 20,
          bottom: state.expanded ? 32 : 20,
          width: state.expanded ? null : normalWidth,
          height: state.expanded ? null : normalHeight,
          child: Offstage(
            offstage: state.minimized,
            child: _Frame(radius: radius, shadow: shadow, border: t.border, child: composer),
          ),
        ),
        if (state.minimized)
          Positioned(
            right: 20,
            bottom: 0,
            width: 320,
            child: Consumer(
              builder: (context, ref, _) {
                final subject = ref.watch(composeWindowSubjectProvider).trim();
                return _MinimizedBar(
                  title: subject.isEmpty ? context.l10n.composeTitleNew : subject,
                  onOpen: () => notifier.setMinimized(false),
                  // Saves the draft first, like the window's own ✕.
                  onClose: notifier.requestClose,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.radius, required this.shadow, required this.border, required this.child});
  final BorderRadius radius;
  final List<BoxShadow> shadow;
  final Color border;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(borderRadius: radius, boxShadow: shadow),
    child: ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: border),
        ),
        // The window sits above the router's navigator: its own navigator
        // hosts the composer's dialogs and menus (inside the window, as on
        // the web). Page-based, so a rebuilt composer reaches the page.
        child: HeroControllerScope.none(
          child: Navigator(
            pages: [MaterialPage<void>(key: const ValueKey('composer'), child: child)],
            onDidRemovePage: (_) {},
          ),
        ),
      ),
    ),
  );
}

class _MinimizedBar extends StatelessWidget {
  const _MinimizedBar({required this.title, required this.onOpen, required this.onClose});
  final String title;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: t.border),
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusLg)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.smd, vertical: Space.sm),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                key: const Key('compose_window_restore'),
                borderRadius: BorderRadius.circular(t.radiusSm),
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 6),
                  child: Row(
                    children: [
                      Icon(LucideIcons.pencil, size: 16, color: t.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              key: const Key('compose_window_bar_close'),
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              tooltip: context.l10n.close,
              icon: const Icon(LucideIcons.x),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}
