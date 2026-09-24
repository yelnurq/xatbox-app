import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/auth_session.dart';
import '../../core/localization/localization.dart';
import '../../core/platform/desktop.dart';
import '../../core/platform/desktop_commands.dart';
import '../../core/platform/desktop_keys.dart';
import '../../core/platform/desktop_layout.dart';
import '../../core/platform/desktop_modal_observer.dart';
import '../../core/platform/launcher_requests.dart';
import '../../core/preferences/app_preferences.dart';
import '../../core/routing/app_router.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/skin_backdrop.dart';
import '../../core/theme/tokens.dart';
import '../../features/calendar/presentation/calendar_providers.dart';
import '../../features/calls/calls_badge.dart';
import '../../features/calls/presentation/calls_providers.dart';
import '../../features/calls/presentation/calls_screen.dart';
import '../../features/chat/chat_badge.dart';
import '../../features/chat/presentation/chat_providers.dart';
import '../../features/chat/presentation/new_chat_screen.dart';
import '../../features/mail/presentation/compose_window.dart';
import '../../features/mail/presentation/folder_drawer.dart';
import '../../features/mail/presentation/folder_names.dart';
import '../../features/mail/presentation/mail_providers.dart';
import '../../features/mail/presentation/message_window.dart';
import '../../features/notifications/presentation/notifications_providers.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/settings/appearance_screen.dart';
import '../../features/tasks/presentation/tasks_providers.dart';
import '../utils/diagnostic_log.dart';
import 'brand_logo.dart';
import 'desktop_integration.dart';
import 'desktop_command_palette.dart';
import 'desktop_shortcuts_dialog.dart';
import 'ds/x_badge.dart';
import 'initials_avatar.dart';
import 'safe_listenable_builder.dart';

/// Tray icon with «Открыть», «Новое письмо», the modules and «Выйти» in the
/// app's language; closing the window hides it there (DesktopTray). Watched
/// once from the app root.
final desktopTrayProvider = Provider<void>((ref) {
  if (!isDesktop) return;
  final l10n = desktopL10n(ref);
  final texts = DesktopTrayTexts(
    open: l10n.desktopTrayOpen,
    quit: l10n.desktopTrayQuit,
    compose: l10n.composeTitleNew,
    mail: l10n.tabMail,
    chat: ref.watch(chatEnabledProvider) ? l10n.tabChat : null,
    calendar: l10n.calendarTitle,
  );
  final tray = DesktopTray.instance;
  final runner = ref.watch(desktopCommandRunnerProvider);
  tray.onCommand = (key) => switch (key) {
    'compose' => runner.run(const DesktopCompose()),
    'mail' => runner.run(const DesktopOpen(DesktopModuleTarget.mail)),
    'chat' => runner.run(const DesktopOpen(DesktopModuleTarget.chat)),
    'calendar' => runner.run(const DesktopOpen(DesktopModuleTarget.calendar)),
    _ => null,
  };
  unawaited(tray.install(texts).then((_) => tray.setTexts(texts)));
});

/// The module a location belongs to (the top bar's section label).
enum DesktopModule { mail, chat, calls, calendar, tasks, contacts, official, search, notifications, settings, other }

abstract final class DesktopNav {
  /// The web's `--sidebar-width` and its collapsed width.
  static const sidebarWidth = 304.0;
  static const sidebarCollapsedWidth = 84.0;

  /// Ctrl+1… order.
  static const shortcutRoutes = [Routes.mail, Routes.chat, Routes.calls, Routes.calendar, Routes.contacts, Routes.tasks];

  /// The module rail (left of everything).
  static const railWidth = 76.0;

  static bool _on(String path, String route) => path == route || path.startsWith('$route/');

  /// Pure: the module of [path].
  static DesktopModule moduleOf(String path) {
    if (_on(path, Routes.mail) || _on(path, '/official')) {
      return _on(path, '/official') ? DesktopModule.official : DesktopModule.mail;
    }
    if (_on(path, Routes.chat)) return DesktopModule.chat;
    if (_on(path, Routes.calls) || _on(path, Routes.call) || _on(path, '/meet')) return DesktopModule.calls;
    if (_on(path, Routes.calendar)) return DesktopModule.calendar;
    if (_on(path, Routes.tasks)) return DesktopModule.tasks;
    if (_on(path, Routes.contacts)) return DesktopModule.contacts;
    if (_on(path, Routes.search)) return DesktopModule.search;
    if (_on(path, Routes.notifications)) return DesktopModule.notifications;
    if (_on(path, Routes.settings) || _on(path, Routes.profile)) return DesktopModule.settings;
    return DesktopModule.other;
  }

  /// Screens drawn without the shell: before sign-in.
  static bool hiddenOn(String path) => path == Routes.splash || path == Routes.login;
}

/// The desktop app's shell — the web's mail layout for every module: the
/// sidebar on the left (full height, collapsible), the top bar over the
/// workspace, the page below, the floating composer over everything.
/// Phones get [child] unchanged.
class DesktopFrame extends ConsumerStatefulWidget {
  const DesktopFrame({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<DesktopFrame> createState() => _DesktopFrameState();
}

class _DesktopFrameState extends ConsumerState<DesktopFrame> {
  final _searchFocus = FocusNode(debugLabel: 'desktop_search');
  bool _logged = false;

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(desktopLayoutProvider)) return widget.child;
    final signedIn = ref.watch(authStateProvider.select((s) => s.status)) == AuthStatus.authenticated;
    if (!signedIn) return widget.child;
    final router = widget.router;
    // The router announces its first route while the shell is still being
    // built (a locked start): SafeListenableBuilder takes that after the
    // frame instead of failing the build.
    return SafeListenableBuilder(
      listenable: router.routerDelegate,
      builder: (context, _) {
        final path = router.routerDelegate.currentConfiguration.uri.path;
        if (DesktopNav.hiddenOn(path)) return widget.child;
        final collapsed = ref.watch(desktopSidebarCollapsedProvider);
        if (!_logged) {
          _logged = true;
          DiagnosticLog.info('desktop', 'shell shown at $path');
        }
        // The web's folder sidebar belongs to mail; the other modules get
        // the width (kept mounted at 0 so the open folders survive).
        final onMail = DesktopNav.moduleOf(path) == DesktopModule.mail;
        final module = DesktopNav.moduleOf(path);
        final onCalendar = module == DesktopModule.calendar;
        // C / Ctrl+N make something new in the open module, as the web's
        // «new» button there: a chat in the messenger, a call in calls (a
        // dialog; nothing during a call, whose screen has keys of its own),
        // a letter elsewhere (the calendar handles its own).
        void newCall() {
          final c = rootNavigatorKey.currentContext;
          if (ref.read(callScreenPresenceProvider) == 0 && c != null) unawaited(showNewCallDialog(c));
        }

        void newItem() => switch (module) {
          // The web's «Новый чат» modal over the messenger.
          DesktopModule.chat => switch (rootNavigatorKey.currentContext) {
            final c? => unawaited(openNewChat(c)),
            null => null,
          },
          DesktopModule.calls => newCall(),
          _ => openCompose(ref),
        };
        final folderWidth = collapsed ? DesktopNav.sidebarCollapsedWidth : DesktopNav.sidebarWidth;
        final sidebarWidth = onMail ? folderWidth : 0.0;
        void go(String route) {
          if (path == route) return;
          router.go(route);
        }

        final mq = MediaQuery.of(context);
        void shortcuts() {
          final c = rootNavigatorKey.currentContext;
          if (c != null) unawaited(showDesktopShortcuts(c));
        }

        // The web's single-key shortcuts outside text fields: / search,
        // C new message (chat, call), ? the list of keys.
        return DesktopKeyBindings(
          bindings: {
            const CharacterActivator('/'): _searchFocus.requestFocus,
            // The calendar has its own «new» (a new event).
            if (!onCalendar) const SingleActivator(LogicalKeyboardKey.keyC): newItem,
            const CharacterActivator('?'): shortcuts,
          },
          child: CallbackShortcuts(
            bindings: {
              for (var i = 0; i < DesktopNav.shortcutRoutes.length; i++)
                commandShortcut(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i)): () =>
                    go(DesktopNav.shortcutRoutes[i]),
              // The web's command palette (the search field keeps «/»).
              commandShortcut(LogicalKeyboardKey.keyK): () {
                final c = rootNavigatorKey.currentContext;
                if (c != null) unawaited(showCommandPalette(c, ref, router));
              },
              commandShortcut(LogicalKeyboardKey.comma): () => go(Routes.settings),
              if (!onCalendar) commandShortcut(LogicalKeyboardKey.keyN): newItem,
            },
            // Tooltips, menus and the composer live above the router's overlay;
            // they navigate with the same router as the pages.
            child: InheritedGoRouter(
              goRouter: router,
              child: Overlay.wrap(
                // The composer floats above the separate message windows.
                child: ComposeWindowHost(
                  child: MessageWindowHost(
                    child: Row(
                      textDirection: TextDirection.ltr,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Dialogs and viewers shade the shell too (it sits
                        // above the router's navigator).
                        DesktopShellShade(
                          child: GlassBlur(child: _ModuleRail(path: path, go: go)),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          width: sidebarWidth,
                          decoration: BoxDecoration(
                            border: onMail
                                ? Border(
                                    right: BorderSide(
                                      color: context.tokens.sidebarBorder,
                                      width: context.tokens.borderWidth,
                                    ),
                                  )
                                : null,
                          ),
                          child: GlassBlur(
                            child: DesktopShellShade(
                              child: OverflowBox(
                                alignment: Alignment.topLeft,
                                minWidth: folderWidth,
                                maxWidth: folderWidth,
                                child: FolderDrawer.desktop(
                                  desktop: DesktopSidebarHost(
                                    path: path,
                                    navigate: go,
                                    collapsed: collapsed,
                                    onToggleCollapsed: () =>
                                        ref.read(desktopSidebarCollapsedProvider.notifier).toggle(),
                                    dialogContext: () => rootNavigatorKey.currentContext,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DesktopShellShade(
                                child: GlassBlur(
                                  child: _TopBar(path: path, go: go, searchFocus: _searchFocus),
                                ),
                              ),
                              // Layouts pick their panes by MediaQuery width
                              // (Breakpoints.lg): give them the space they get.
                              Expanded(
                                child: MediaQuery(
                                  data: mq.copyWith(
                                    size: Size(
                                      (mq.size.width - DesktopNav.railWidth - sidebarWidth).clamp(0, double.infinity),
                                      (mq.size.height - Space.topbarHeight).clamp(0, double.infinity),
                                    ),
                                  ),
                                  child: widget.child,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The module rail: the logo, then Почта · Чат · Звонки · Календарь ·
/// Контакты as round buttons with their unread counts, Настройки at the
/// bottom. The web folder sidebar sits to its right while mail is open.
class _ModuleRail extends ConsumerWidget {
  const _ModuleRail({required this.path, required this.go});

  final String path;
  final void Function(String route) go;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l10n = context.l10n;
    final module = DesktopNav.moduleOf(path);
    Widget item(DesktopModule m, String route, IconData icon, String label, {int badge = 0}) => _RailButton(
      key: Key('desktop_rail_${route.substring(1)}'),
      icon: icon,
      label: label,
      badge: badge,
      active: module == m,
      onTap: () => go(route),
    );
    return Material(
      color: t.sidebarSurface,
      child: Container(
        width: DesktopNav.railWidth,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: t.sidebarBorder, width: t.borderWidth),
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: Space.topbarHeight,
              child: Center(child: BrandMark(size: 30, color: t.sidebarMark)),
            ),
            const SizedBox(height: Space.sm),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    item(
                      DesktopModule.mail,
                      Routes.mail,
                      LucideIcons.mail,
                      l10n.tabMail,
                      badge: ref.watch(mailUnreadBadgeProvider),
                    ),
                    if (ref.watch(chatEnabledProvider))
                      item(
                        DesktopModule.chat,
                        Routes.chat,
                        LucideIcons.messageCircle,
                        l10n.tabChat,
                        badge: ref.watch(chatBadgeProvider),
                      ),
                    if (ref.watch(callsEnabledProvider))
                      item(
                        DesktopModule.calls,
                        Routes.calls,
                        LucideIcons.phone,
                        l10n.tabCalls,
                        badge: ref.watch(callsBadgeProvider),
                      ),
                    item(
                      DesktopModule.calendar,
                      Routes.calendar,
                      LucideIcons.calendarDays,
                      l10n.calendarTitle,
                      badge: ref.watch(calendarBadgeProvider),
                    ),
                    if (ref.watch(tasksEnabledProvider))
                      item(
                        DesktopModule.tasks,
                        Routes.tasks,
                        LucideIcons.squareKanban,
                        l10n.tasksTitle,
                        badge: ref.watch(tasksBadgeProvider),
                      ),
                    item(DesktopModule.contacts, Routes.contacts, LucideIcons.users, l10n.contactsTab),
                  ],
                ),
              ),
            ),
            item(DesktopModule.settings, Routes.settings, LucideIcons.settings, l10n.settingsTitle),
            const SizedBox(height: Space.sm),
          ],
        ),
      ),
    );
  }
}

/// A rail destination: only the round icon reacts (hover tint, press
/// shade, the selected fill); the label under it never gets painted over.
class _RailButton extends StatefulWidget {
  const _RailButton({
    super.key,
    required this.icon,
    required this.label,
    required this.badge,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int badge;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_RailButton> createState() => _RailButtonState();
}

class _RailButtonState extends State<_RailButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final active = widget.active;
    final fill = active
        ? t.sidebarSelected
        : _pressed
        ? t.sidebarSelected.withValues(alpha: 0.7)
        : _hover
        ? t.sidebarHover
        : Colors.transparent;
    Widget glyph = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: active ? t.sidebarBorder : Colors.transparent, width: t.borderWidth),
      ),
      child: Icon(
        widget.icon,
        size: 20,
        color: active || _hover ? t.sidebarPrimary : t.sidebarTextSecondary,
      ),
    );
    if (widget.badge > 0) {
      glyph = Badge(
        label: Text(CountPill.format(widget.badge)),
        backgroundColor: t.danger,
        textColor: t.textInverse,
        offset: const Offset(2, -2),
        child: glyph,
      );
    }
    return Tooltip(
      message: widget.label,
      waitDuration: const Duration(milliseconds: 500),
      preferBelow: false,
      child: Semantics(
        button: true,
        selected: active,
        label: widget.label,
        excludeSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() {
            _hover = false;
            _pressed = false;
          }),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  glyph,
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: t.fontDisplay,
                          fontSize: 11,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                          color: active ? t.sidebarText : t.sidebarTextSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The web `Topbar`: section label on the left, the search field in the
/// middle, notifications · appearance · language · account on the right.
class _TopBar extends ConsumerStatefulWidget {
  const _TopBar({required this.path, required this.go, required this.searchFocus});

  final String path;
  final void Function(String route) go;
  final FocusNode searchFocus;

  @override
  ConsumerState<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<_TopBar> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final q = value.trim();
    ref.read(unifiedSearchRequestProvider.notifier).request(q);
    widget.go(Routes.search);
    widget.searchFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final module = DesktopNav.moduleOf(widget.path);
    final (IconData icon, String section) = switch (module) {
      DesktopModule.mail => (LucideIcons.mail, l10n.tabMail),
      DesktopModule.chat => (LucideIcons.messageCircle, l10n.tabChat),
      DesktopModule.calls => (LucideIcons.phone, l10n.tabCalls),
      DesktopModule.calendar => (LucideIcons.calendarDays, l10n.calendarTitle),
      DesktopModule.tasks => (LucideIcons.listTodo, l10n.tasksTitle),
      DesktopModule.contacts => (LucideIcons.users, l10n.contactsTitle),
      DesktopModule.official => (LucideIcons.megaphone, l10n.officialTitle),
      DesktopModule.search => (LucideIcons.search, l10n.desktopSearch),
      DesktopModule.notifications => (LucideIcons.bell, l10n.notificationsTitle),
      DesktopModule.settings => (LucideIcons.settings, l10n.settingsTitle),
      DesktopModule.other => (LucideIcons.layoutGrid, l10n.appTitle),
    };
    final String page;
    if (module == DesktopModule.mail) {
      final type = ref.watch(selectedFolderProvider);
      final folder = ref.watch(mailSummaryProvider.select((s) => s.summary?.folderByType(type)));
      page = folderDisplayName(l10n, type, serverName: folder?.name);
    } else if (module == DesktopModule.settings && widget.path.startsWith(Routes.profile)) {
      page = l10n.profileTitle;
    } else {
      page = section;
    }

    return Material(
      color: t.surface,
      child: Container(
        height: Space.topbarHeight,
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: t.border, width: t.borderWidth),
          ),
        ),
        child: Row(
          children: [
            // Section: icon tile + small caps module + page.
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: t.surfaceSubtle,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: t.border, width: t.borderWidth),
              ),
              child: Icon(icon, size: 16, color: t.primary),
            ),
            const SizedBox(width: Space.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 176),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: t.fontDisplay,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: t.textTertiary,
                    ),
                  ),
                  Text(
                    page,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: t.fontDisplay,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.smd),
            // Search: grows up to 672px, centred in the free space.
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 672),
                  child: _SearchField(controller: _search, focusNode: widget.searchFocus, onSubmitted: _submit),
                ),
              ),
            ),
            const SizedBox(width: Space.smd),
            const _Bell(),
            const SizedBox(width: Space.xs),
            const _ThemeSwitcher(),
            const SizedBox(width: Space.xs),
            const _LocaleSwitcher(),
            const SizedBox(width: Space.xs),
            _AccountMenu(go: widget.go),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.focusNode, required this.onSubmitted});

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(10);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: c, width: t.borderWidth),
    );
    return SizedBox(
      height: 40,
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (context, _) => TextField(
          key: const Key('desktop_search'),
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onSubmitted: onSubmitted,
          style: TextStyle(fontSize: 13, color: t.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: focusNode.hasFocus ? t.surface : t.surfaceSubtle,
            hintText: context.l10n.searchHint,
            hintStyle: TextStyle(fontSize: 13, color: t.textTertiary),
            prefixIcon: Icon(LucideIcons.search, size: 14, color: t.textTertiary),
            prefixIconConstraints: const BoxConstraints(minWidth: 36),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(widthFactor: 1, child: _Kbd('$commandKeyLabel K')),
            ),
            suffixIconConstraints: const BoxConstraints(minHeight: 20),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: border(t.border),
            enabledBorder: border(t.border),
            focusedBorder: border(t.focus),
          ),
        ),
      ),
    );
  }
}

class _Kbd extends StatelessWidget {
  const _Kbd(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: t.surfaceSubtle,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: t.border, width: t.borderWidth),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: t.textTertiary,
        ),
      ),
    );
  }
}

/// `.topbar-control`: 40×40, radius 12, hover fill.
class _TopbarControl extends StatelessWidget {
  const _TopbarControl({super.key, required this.tooltip, required this.onPressed, required this.child});
  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          hoverColor: t.surfaceHover,
          child: SizedBox(width: 40, height: 40, child: Center(child: child)),
        ),
      ),
    );
  }
}

/// The web `NotificationsBell`: the list opens in a panel under the bell
/// (400×560), not as a page.
class _Bell extends ConsumerStatefulWidget {
  const _Bell();

  @override
  ConsumerState<_Bell> createState() => _BellState();
}

class _BellState extends ConsumerState<_Bell> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final unread = ref.watch(notificationsUnreadBadgeProvider);
    Widget glyph = Icon(LucideIcons.bell, size: 18, color: unread > 0 ? t.primary : t.textSecondary);
    if (unread > 0) {
      glyph = Badge(
        label: Text(CountPill.format(unread)),
        backgroundColor: t.danger,
        textColor: t.textInverse,
        child: glyph,
      );
    }
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _portal.hide),
            ),
            CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 8),
              child: SizedBox(
                width: 400,
                height: 560,
                child: Material(
                  color: t.overlaySurface,
                  elevation: 8,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(t.radiusLg),
                    side: BorderSide(color: t.border),
                  ),
                  child: HeroControllerScope.none(
                    child: Navigator(
                      pages: [
                        MaterialPage<void>(
                          key: const ValueKey('bell'),
                          child: NotificationsScreen(key: const Key('bell_panel'), onOpened: _portal.hide),
                        ),
                      ],
                      onDidRemovePage: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        child: _TopbarControl(
          key: const Key('topbar_notifications'),
          tooltip: context.l10n.notificationsTitle,
          onPressed: _portal.toggle,
          child: glyph,
        ),
      ),
    );
  }
}

/// The web `ThemeSwitcher`: a half-filled disc; the panel has the three
/// modes and the skin grid.
class _ThemeSwitcher extends ConsumerWidget {
  const _ThemeSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l10n = context.l10n;
    return MenuAnchor(
      alignmentOffset: const Offset(-300, 8),
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.all(12)),
        backgroundColor: WidgetStatePropertyAll(t.overlaySurface),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: t.border),
          ),
        ),
      ),
      menuChildren: const [_AppearancePanel()],
      builder: (context, controller, _) => _TopbarControl(
        key: const Key('topbar_theme'),
        tooltip: l10n.settingsAppearanceSection,
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: t.borderStrong),
            gradient: SweepGradient(
              startAngle: 0,
              endAngle: 6.2832,
              transform: const GradientRotation(3.665),
              stops: const [0.5, 0.5],
              colors: [t.primary, t.appBg],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppearancePanel extends ConsumerWidget {
  const _AppearancePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l10n = context.l10n;
    final prefs = ref.watch(appPreferencesProvider);
    final notifier = ref.read(appPreferencesProvider.notifier);
    Widget mode(AppThemePreference value, IconData icon, String label) {
      final on = prefs.skin == AppSkin.standard && prefs.theme == value;
      return Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => notifier.update((p) => p.copyWith(theme: value, skin: AppSkin.standard)),
          child: Container(
            width: 32,
            height: 28,
            decoration: BoxDecoration(
              color: on ? t.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              boxShadow: on
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 2, offset: const Offset(0, 1))]
                  : null,
            ),
            child: Icon(icon, size: 14, color: on ? t.textPrimary : t.textSecondary),
          ),
        ),
      );
    }

    return SizedBox(
      width: 340,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.settingsAppearanceSection,
                  style: TextStyle(
                    fontFamily: t.fontDisplay,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: t.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: t.border),
                ),
                child: Row(
                  children: [
                    mode(AppThemePreference.system, LucideIcons.monitor, l10n.settingsThemeSystem),
                    mode(AppThemePreference.light, LucideIcons.sun, l10n.settingsThemeLight),
                    mode(AppThemePreference.dark, LucideIcons.moon, l10n.settingsThemeDark),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          // A Wrap, not a GridView: menus measure their content.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final skin in AppSkin.offered(desktop: true))
                SizedBox(
                  width: 109,
                  height: 156,
                  child: SkinTile(
                    key: Key('topbar_skin_${skin.name}'),
                    skin: skin,
                    selected: prefs.skin == skin,
                    onTap: () => notifier.update((p) => p.copyWith(skin: skin)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The web `LocaleSwitcher`: the language code; the menu lists the three.
class _LocaleSwitcher extends ConsumerWidget {
  const _LocaleSwitcher();

  static const _names = {'ru': 'Русский', 'kk': 'Қазақша', 'en': 'English'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final current = Localizations.localeOf(context).languageCode;
    final notifier = ref.read(appPreferencesProvider.notifier);
    return MenuAnchor(
      alignmentOffset: const Offset(-100, 8),
      menuChildren: [
        for (final code in AppPreferences.languages)
          MenuItemButton(
            key: Key('topbar_language_$code'),
            leadingIcon: SizedBox(
              width: 16,
              child: code == current ? Icon(LucideIcons.check, size: 14, color: t.primary) : null,
            ),
            onPressed: () => notifier.update((p) => p.copyWith(languageCode: code)),
            child: Text(_names[code] ?? code),
          ),
      ],
      builder: (context, controller, _) => _TopbarControl(
        key: const Key('topbar_language'),
        tooltip: context.l10n.settingsLanguage,
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: t.borderStrong),
          ),
          child: Text(
            (current == 'kk' ? 'KZ' : current).toUpperCase(),
            style: TextStyle(
              fontFamily: t.fontDisplay,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: t.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The web account menu: name · Профиль · Настройки · Выйти.
class _AccountMenu extends ConsumerWidget {
  const _AccountMenu({required this.go});
  final void Function(String route) go;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l10n = context.l10n;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    return MenuAnchor(
      alignmentOffset: const Offset(-180, 8),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.smd, Space.sm, Space.smd, Space.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.textPrimary),
              ),
              Text(user.email, style: TextStyle(fontSize: 12, color: t.textTertiary)),
            ],
          ),
        ),
        const Divider(height: 8),
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.user, size: 16),
          onPressed: () => go(Routes.profile),
          child: Text(l10n.profileTitle),
        ),
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.settings, size: 16),
          onPressed: () => go(Routes.settings),
          child: Text(l10n.settingsTitle),
        ),
        const Divider(height: 8),
        MenuItemButton(
          key: const Key('topbar_sign_out'),
          leadingIcon: Icon(LucideIcons.logOut, size: 16, color: t.danger),
          onPressed: () => _signOut(context, ref),
          child: Text(l10n.settingsLogout, style: TextStyle(color: t.danger)),
        ),
      ],
      builder: (context, controller, _) => _TopbarControl(
        key: const Key('topbar_account'),
        tooltip: user.displayName,
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        child: InitialsAvatar(label: user.displayName, colorKey: user.email, radius: 15),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final dialogContext = rootNavigatorKey.currentContext;
    if (dialogContext == null) return;
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsLogout),
        content: Text(l10n.settingsLogoutConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.settingsLogout)),
        ],
      ),
    );
    if (ok == true) await ref.read(authSessionProvider).logout();
  }
}
