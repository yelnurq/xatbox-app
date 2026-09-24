import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/localization/localization.dart';
import '../../core/preferences/app_preferences.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/tokens.dart';
import '../../features/calendar/presentation/calendar_widgets.dart';
import '../../features/calendar/presentation/event_edit_screen.dart' show EventEditArgs;
import '../../features/calls/presentation/calls_screen.dart' show showNewCallDialog;
import '../../features/chat/presentation/new_chat_screen.dart' show openNewChat;
import '../../features/mail/presentation/compose_window.dart';
import '../../core/platform/launcher_requests.dart';
import 'desktop_shortcuts_dialog.dart';

/// One line of the palette.
@immutable
class PaletteCommand {
  const PaletteCommand({
    required this.id,
    required this.icon,
    required this.label,
    required this.group,
    required this.run,
  });
  final String id;
  final IconData icon;
  final String label;
  final String group;
  final VoidCallback run;
}

/// Commands whose label contains every word of [query] (pure, unit-tested).
List<PaletteCommand> filterCommands(List<PaletteCommand> all, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return all;
  return [
    for (final c in all)
      if (words.every((w) => c.label.toLowerCase().contains(w) || c.group.toLowerCase().contains(w))) c,
  ];
}

/// Ctrl/⌘+K — the web's command palette: new letter, chat, event or call,
/// the modules and settings sections, the theme, the keys, and «search
/// everywhere» for anything else. ↑/↓ choose, Enter runs, Esc closes.
Future<void> showCommandPalette(BuildContext context, WidgetRef ref, GoRouter router) {
  final l10n = context.l10n;
  final create = l10n.desktopPaletteCreate;
  final goTo = l10n.desktopPaletteGoTo;
  void go(String route) => router.go(route);
  final commands = <PaletteCommand>[
    PaletteCommand(
      id: 'new_mail',
      icon: LucideIcons.pencil,
      label: l10n.composeTitleNew,
      group: create,
      run: () => openCompose(ref),
    ),
    PaletteCommand(
      id: 'new_chat',
      icon: LucideIcons.messageCirclePlus,
      label: l10n.chatNew,
      group: create,
      run: () {
        final c = router.routerDelegate.navigatorKey.currentContext;
        if (c != null) unawaited(openNewChat(c));
      },
    ),
    PaletteCommand(
      id: 'new_event',
      icon: LucideIcons.calendarPlus,
      label: l10n.calendarNewEvent,
      group: create,
      run: () {
        go(Routes.calendar);
        final c = router.routerDelegate.navigatorKey.currentContext;
        if (c != null) unawaited(openEventEditor(c, const EventEditArgs.create()));
      },
    ),
    PaletteCommand(
      id: 'new_call',
      icon: LucideIcons.phoneCall,
      label: l10n.callsNew,
      group: create,
      run: () {
        final c = router.routerDelegate.navigatorKey.currentContext;
        if (c != null) unawaited(showNewCallDialog(c));
      },
    ),
    PaletteCommand(id: 'go_mail', icon: LucideIcons.mail, label: l10n.tabMail, group: goTo, run: () => go(Routes.mail)),
    PaletteCommand(
      id: 'go_chat',
      icon: LucideIcons.messageCircle,
      label: l10n.tabChat,
      group: goTo,
      run: () => go(Routes.chat),
    ),
    PaletteCommand(
      id: 'go_calendar',
      icon: LucideIcons.calendarDays,
      label: l10n.calendarTitle,
      group: goTo,
      run: () => go(Routes.calendar),
    ),
    PaletteCommand(
      id: 'go_calls',
      icon: LucideIcons.phone,
      label: l10n.tabCalls,
      group: goTo,
      run: () => go(Routes.calls),
    ),
    PaletteCommand(
      id: 'go_contacts',
      icon: LucideIcons.contactRound,
      label: l10n.contactsTitle,
      group: goTo,
      run: () => go(Routes.contacts),
    ),
    PaletteCommand(
      id: 'go_settings',
      icon: LucideIcons.settings,
      label: l10n.settingsTitle,
      group: goTo,
      run: () => go(Routes.settings),
    ),
    PaletteCommand(
      id: 'go_profile',
      icon: LucideIcons.user,
      label: l10n.profileTitle,
      group: goTo,
      run: () => go(Routes.profile),
    ),
    PaletteCommand(
      id: 'go_appearance',
      icon: LucideIcons.palette,
      label: l10n.settingsAppearanceSection,
      group: goTo,
      run: () => go(Routes.settingsAppearance),
    ),
    PaletteCommand(
      id: 'go_notifications',
      icon: LucideIcons.bell,
      label: l10n.settingsNotifications,
      group: goTo,
      run: () => go(Routes.settingsNotifications),
    ),
    PaletteCommand(
      id: 'go_security',
      icon: LucideIcons.shieldCheck,
      label: l10n.settingsSecuritySection,
      group: goTo,
      run: () => go(Routes.settingsSecurity),
    ),
    PaletteCommand(
      id: 'go_mail_settings',
      icon: LucideIcons.mailCheck,
      label: l10n.mailSettingsTitle,
      group: goTo,
      run: () => go(Routes.settingsMail),
    ),
    PaletteCommand(
      id: 'go_sessions',
      icon: LucideIcons.laptop,
      label: l10n.sessionsTitle,
      group: goTo,
      run: () => go(Routes.settingsSessions),
    ),
    PaletteCommand(
      id: 'theme',
      icon: LucideIcons.sunMoon,
      label: l10n.desktopPaletteToggleTheme,
      group: l10n.settingsAppearanceSection,
      run: () {
        final dark = Theme.of(context).brightness == Brightness.dark;
        unawaited(
          ref
              .read(appPreferencesProvider.notifier)
              .update(
                (p) => p.copyWith(
                  theme: dark ? AppThemePreference.light : AppThemePreference.dark,
                  skin: AppSkin.standard,
                ),
              ),
        );
      },
    ),
    PaletteCommand(
      id: 'keys',
      icon: LucideIcons.keyboard,
      label: l10n.desktopShortcutsTitle,
      group: l10n.settingsTitle,
      run: () {
        final c = router.routerDelegate.navigatorKey.currentContext;
        if (c != null) unawaited(showDesktopShortcuts(c));
      },
    ),
  ];
  void searchEverywhere(String q) {
    ref.read(unifiedSearchRequestProvider.notifier).request(q);
    go(Routes.search);
  }

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black26,
    builder: (dialog) => Align(
      alignment: const Alignment(0, -0.6),
      child: _Palette(commands: commands, onSearch: searchEverywhere),
    ),
  );
}

class _Palette extends StatefulWidget {
  const _Palette({required this.commands, required this.onSearch});
  final List<PaletteCommand> commands;
  final ValueChanged<String> onSearch;

  @override
  State<_Palette> createState() => _PaletteState();
}

class _PaletteState extends State<_Palette> {
  final _query = TextEditingController();
  int _index = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<PaletteCommand> get _shown => filterCommands(widget.commands, _query.text);

  /// The shown commands, plus «search everywhere» when something is typed.
  int get _count => _shown.length + (_query.text.trim().isEmpty ? 0 : 1);

  void _run(int i) {
    final shown = _shown;
    final q = _query.text.trim();
    Navigator.of(context).pop();
    if (i < shown.length) {
      shown[i].run();
    } else if (q.isNotEmpty) {
      widget.onSearch(q);
    }
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent || _count == 0) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _index = (_index + 1) % _count);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _index = (_index - 1 + _count) % _count);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _run(_index);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final shown = _shown;
    final q = _query.text.trim();
    Widget row(int i, IconData icon, String label, {String? group, Key? key}) {
      final active = i == _index;
      return Material(
        color: active ? t.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(t.radiusMd),
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(t.radiusMd),
          onTap: () => _run(i),
          onHover: (h) {
            if (h && _index != i) setState(() => _index = i);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.smd, vertical: 9),
            child: Row(
              children: [
                Icon(icon, size: 16, color: active ? t.primary : t.textSecondary),
                const SizedBox(width: Space.smd),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: t.textPrimary),
                  ),
                ),
                if (group != null) Text(group, style: TextStyle(fontSize: 12, color: t.textTertiary)),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      key: const Key('command_palette'),
      color: t.surface,
      elevation: 16,
      borderRadius: BorderRadius.circular(t.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Focus(
              onKeyEvent: _key,
              child: TextField(
                key: const Key('command_palette_field'),
                controller: _query,
                autofocus: true,
                onChanged: (_) => setState(() => _index = 0),
                onSubmitted: (_) => _run(_index),
                decoration: InputDecoration(
                  hintText: l10n.desktopPaletteHint,
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            Divider(height: 1, color: t.divider),
            Flexible(
              child: _count == 0
                  ? Padding(
                      padding: const EdgeInsets.all(Space.lg),
                      child: Text(
                        l10n.desktopPaletteNothing,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: t.textTertiary),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(Space.sm),
                      children: [
                        for (final (i, c) in shown.indexed)
                          row(i, c.icon, c.label, group: c.group, key: Key('palette_${c.id}')),
                        if (q.isNotEmpty)
                          row(
                            shown.length,
                            LucideIcons.search,
                            l10n.desktopPaletteSearch(q),
                            key: const Key('palette_search'),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
