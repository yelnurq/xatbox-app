import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/localization/localization.dart';
import '../../core/platform/desktop_layout.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/desktop_shortcuts_dialog.dart';
import '../../shared/widgets/ds/sidebar_nav_item.dart';
import '../about/presentation/about_screen.dart';
import '../mail/presentation/settings/mail_clients_screen.dart';
import '../mail/presentation/settings/mail_settings_screen.dart';
import '../profile/profile_screen.dart';
import '../sessions/sessions_screen.dart';
import 'appearance_screen.dart';
import 'notification_settings_screen.dart';
import 'security_screen.dart';
import 'settings_screen.dart';

/// A section of the desktop settings page (pure data).
/// A settings page opened from a row: on desktop the section replaces the
/// panel (no pages stacked inside the settings layout), phones push it.
void openSettingsPage(BuildContext context, String route) {
  if (ProviderScope.containerOf(context, listen: false).read(desktopLayoutProvider)) {
    context.go(route);
  } else {
    unawaited(context.push(route));
  }
}

enum DesktopSettingsSection {
  general(Routes.settings, LucideIcons.slidersHorizontal),
  profile(Routes.profile, LucideIcons.user),
  appearance(Routes.settingsAppearance, LucideIcons.palette),
  notifications(Routes.settingsNotifications, LucideIcons.bell),
  security(Routes.settingsSecurity, LucideIcons.shieldCheck),
  mail(Routes.settingsMail, LucideIcons.mail),
  // The mail settings' own pages are sections too (web: signature,
  // out of office, blocked senders are topics of the settings page).
  mailSignature(Routes.settingsMailSignature, LucideIcons.pen),
  mailVacation(Routes.settingsMailVacation, LucideIcons.calendar),
  mailBlocked(Routes.settingsMailBlockedSenders, LucideIcons.octagonAlert),
  mailBookmarkFolders(Routes.settingsMailBookmarkFolders, LucideIcons.bookmark),
  mailClients(Routes.settingsMailClients, LucideIcons.monitorSmartphone),
  mailImport(Routes.settingsMailImport, LucideIcons.import),
  sessions(Routes.settingsSessions, LucideIcons.laptop),
  shortcuts(Routes.settingsShortcuts, LucideIcons.command),
  about(Routes.settingsAbout, LucideIcons.info);

  const DesktopSettingsSection(this.route, this.icon);
  final String route;
  final IconData icon;

  /// The page draws its own web-style panels (no card or title around it).
  bool get ownPanels => this == profile || this == security;
}

/// The web settings page on desktop: the page title, the section list on
/// the left (the sidebar's width and rows), the chosen section on the right
/// as a panel. Each section is the phone's own settings screen, so nothing
/// is duplicated; its app bar is the panel's header.
class DesktopSettingsScreen extends StatelessWidget {
  const DesktopSettingsScreen({super.key, required this.section});

  final DesktopSettingsSection section;

  static const navWidth = 304.0;

  String _label(AppLocalizations l10n, DesktopSettingsSection s) => switch (s) {
    DesktopSettingsSection.general => l10n.settingsTitle,
    DesktopSettingsSection.profile => l10n.profileTitle,
    DesktopSettingsSection.appearance => l10n.settingsAppearanceSection,
    DesktopSettingsSection.notifications => l10n.settingsNotifications,
    DesktopSettingsSection.security => l10n.settingsSecuritySection,
    DesktopSettingsSection.mail => l10n.mailSettingsTitle,
    DesktopSettingsSection.mailSignature => l10n.mailSettingsSignature,
    DesktopSettingsSection.mailVacation => l10n.mailSettingsVacation,
    DesktopSettingsSection.mailBlocked => l10n.mailSettingsBlocked,
    DesktopSettingsSection.mailBookmarkFolders => l10n.mailSettingsBookmarkFolders,
    DesktopSettingsSection.mailClients => l10n.mailSettingsClients,
    DesktopSettingsSection.mailImport => l10n.mailSettingsImport,
    DesktopSettingsSection.sessions => l10n.sessionsTitle,
    DesktopSettingsSection.shortcuts => l10n.desktopMailSettingsShortcuts,
    DesktopSettingsSection.about => l10n.aboutTitle,
  };

  Widget _page() => switch (section) {
    DesktopSettingsSection.general => const SettingsScreen(),
    DesktopSettingsSection.profile => const ProfileScreen(),
    DesktopSettingsSection.appearance => const AppearanceScreen(),
    DesktopSettingsSection.notifications => const NotificationSettingsScreen(),
    DesktopSettingsSection.security => const SecurityScreen(),
    DesktopSettingsSection.mail => const MailSettingsScreen(),
    DesktopSettingsSection.mailSignature => const SignatureSettingsScreen(),
    DesktopSettingsSection.mailVacation => const VacationSettingsScreen(),
    DesktopSettingsSection.mailBlocked => const BlockedSendersScreen(),
    DesktopSettingsSection.mailBookmarkFolders => const BookmarkFoldersScreen(),
    DesktopSettingsSection.mailClients => const MailClientsScreen(),
    DesktopSettingsSection.mailImport => const MailImportScreen(),
    DesktopSettingsSection.sessions => const SessionsScreen(),
    DesktopSettingsSection.shortcuts => const DesktopShortcutsScreen(),
    DesktopSettingsSection.about => const AboutScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: t.appBg,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // `.page-title` + intro.
            Text(
              l10n.settingsTitle,
              style: TextStyle(fontFamily: t.fontDisplay, fontSize: 28, height: 36 / 28, fontWeight: FontWeight.w600, color: t.textPrimary),
            ),
            const SizedBox(height: Space.xs),
            Text(l10n.desktopSettingsIntro, style: theme.textTheme.bodyMedium?.copyWith(color: t.textSecondary)),
            const SizedBox(height: Space.mlg),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: navWidth,
                    child: ListView(
                      children: [
                        for (final s in DesktopSettingsSection.values)
                          SidebarNavItem(
                            semanticKey: Key('settings_section_${s.name}'),
                            icon: s.icon,
                            label: _label(l10n, s),
                            active: s == section,
                            round: true,
                            onPage: true,
                            onTap: () => context.go(s.route),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.lg),
                  // `.xatbox-panel`: the section page on a bordered card.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: Space.lg),
                      child: DecoratedBox(
                        // Profile and security draw their own panels: those
                        // sit on the page, with no card around them.
                        decoration: section.ownPanels
                            ? const BoxDecoration()
                            : BoxDecoration(
                                color: t.surface,
                                borderRadius: BorderRadius.circular(t.radiusLg),
                                border: Border.all(color: t.border, width: t.borderWidth),
                              ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(t.radiusLg),
                          child: KeyedSubtree(key: ValueKey(section), child: _page()),
                        ),
                      ),
                    ),
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

/// «Клавиши» (web settings «shortcuts»): every key of the desktop app —
/// mail, calendar, messenger and the ones that work everywhere.
class DesktopShortcutsScreen extends StatelessWidget {
  const DesktopShortcutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.desktopMailSettingsShortcuts)),
      body: ListView(
        key: const Key('settings_shortcuts'),
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.lg),
        children: [
          Text(l10n.desktopMailSettingsShortcutsHint, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.textSecondary)),
          DesktopShortcutsGroups(groups: desktopShortcutGroups(l10n, modules: true)),
        ],
      ),
    );
  }
}
