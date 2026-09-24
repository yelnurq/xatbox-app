import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/localization/localization.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/ds/x_badge.dart';
import '../../chat/presentation/chat_providers.dart';
import '../../settings/desktop_settings_screen.dart';
import '../../update/presentation/update_controller.dart';

/// Settings → Security: «Мои устройства и сеансы».
class SessionsSettingsTile extends StatelessWidget {
  const SessionsSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      key: const Key('settings_sessions'),
      leading: const Icon(LucideIcons.monitorSmartphone),
      title: Text(l10n.sessionsTitle),
      subtitle: Text(l10n.sessionsSettingsHint),
      trailing: const Icon(LucideIcons.chevronRight),
      onTap: () => openSettingsPage(context, Routes.settingsSessions),
    );
  }
}

/// Settings → «Приложение»: update (with a badge when one is waiting),
/// about, problem report.
class AppSettingsSection extends ConsumerWidget {
  const AppSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final update = ref.watch(updateControllerProvider);
    final installed = update.installed ?? ref.watch(installedAppProvider).value;
    final release = update.release;
    final String subtitle;
    if (update.hasUpdate && release != null) {
      subtitle = l10n.updateSettingsAvailable(release.versionName);
    } else if (installed != null) {
      subtitle = l10n.updateCurrentVersion(installed.label);
    } else {
      subtitle = l10n.updateCheck;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
          child: Text(l10n.aboutAppSection, style: Theme.of(context).textTheme.titleSmall),
        ),
        if (ref.watch(appUpdatesSupportedProvider))
          ListTile(
            key: const Key('settings_update'),
            leading: const Icon(LucideIcons.download),
            title: Text(l10n.updateTitle),
            subtitle: Text(subtitle, style: update.hasUpdate ? TextStyle(color: t.primary) : null),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (update.hasUpdate) XBadge(l10n.updateBadgeNew, tone: BadgeTone.primary, small: true),
                const SizedBox(width: Space.xs),
                const Icon(LucideIcons.chevronRight),
              ],
            ),
            onTap: () => context.push(Routes.settingsUpdate),
          ),
        ListTile(
          key: const Key('settings_about'),
          leading: const Icon(LucideIcons.info),
          title: Text(l10n.aboutTitle),
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () => context.push(Routes.settingsAbout),
        ),
        if (ref.watch(chatEnabledProvider))
          ListTile(
            key: const Key('settings_report'),
            leading: const Icon(LucideIcons.messageSquareWarning),
            title: Text(l10n.reportTitle),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: () => context.push(Routes.reportProblem),
          ),
      ],
    );
  }
}
