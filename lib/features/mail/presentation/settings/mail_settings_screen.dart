import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/auth/permissions.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/routing/routes.dart';
import '../../../../shared/widgets/state_view.dart';
import '../../../settings/desktop_settings_screen.dart';
import 'mail_ux_settings_section.dart';

export 'blocked_senders_screen.dart';
export 'bookmark_folders_screen.dart';
export 'mail_import_screen.dart';
export 'signature_settings_screen.dart';
export 'vacation_settings_screen.dart';

/// `/settings/mail`: personal mail settings (all need `mail.read`).
class MailSettingsScreen extends ConsumerWidget {
  const MailSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final canRead = ref.watch(hasPermissionProvider(Permissions.mailRead));

    Widget entry(
      String key,
      IconData icon,
      String title,
      String subtitle,
      String route,
    ) => ListTile(
      key: Key(key),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(LucideIcons.chevronRight, size: 16),
      // Desktop: the page is a section of the settings layout, switched
      // in place; phones push it as before.
      onTap: () => openSettingsPage(context, route),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mailSettingsTitle)),
      body: !canRead
          ? StateView.error(
              message: l10n.mailNoPermission,
              icon: LucideIcons.lock,
            )
          : ListView(
              children: [
                entry(
                  'mail_settings_signature',
                  LucideIcons.pen,
                  l10n.mailSettingsSignature,
                  l10n.mailSettingsSignatureSubtitle,
                  Routes.settingsMailSignature,
                ),
                entry(
                  'mail_settings_vacation',
                  LucideIcons.calendar,
                  l10n.mailSettingsVacation,
                  l10n.mailSettingsVacationSubtitle,
                  Routes.settingsMailVacation,
                ),
                entry(
                  'mail_settings_blocked',
                  LucideIcons.octagonAlert,
                  l10n.mailSettingsBlocked,
                  l10n.mailSettingsBlockedSubtitle,
                  Routes.settingsMailBlockedSenders,
                ),
                entry(
                  'mail_settings_clients',
                  LucideIcons.server,
                  l10n.mailSettingsClients,
                  l10n.mailSettingsClientsSubtitle,
                  Routes.settingsMailClients,
                ),
                // Web: Mail → Settings → «Импорт почты».
                entry(
                  'mail_settings_import',
                  LucideIcons.import,
                  l10n.mailSettingsImport,
                  l10n.mailSettingsImportSubtitle,
                  Routes.settingsMailImport,
                ),
                entry(
                  'mail_settings_bookmark_folders',
                  LucideIcons.bookmark,
                  l10n.mailSettingsBookmarkFolders,
                  l10n.mailSettingsBookmarkFoldersSubtitle,
                  Routes.settingsMailBookmarkFolders,
                ),
                const MailUxSettingsSection(),
              ],
            ),
    );
  }
}
