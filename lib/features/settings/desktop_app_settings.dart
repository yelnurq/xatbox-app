import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/localization.dart';
import '../../core/platform/desktop.dart';
import '../../core/platform/desktop_settings.dart';
import '../../core/platform/desktop_shell.dart';
import '../../core/platform/desktop_sounds.dart';
import '../../shared/utils/diagnostic_log.dart';
import '../../shared/widgets/desktop_shortcuts_dialog.dart';
import '../calls/data/call_sounds.dart';
import '../update/data/update_models.dart';
import '../update/presentation/update_controller.dart';

/// «Приложение для компьютера» in the general settings of the desktop app:
/// start at sign-in, new mail toasts, global hotkeys, auto away, spelling,
/// the mini call window, beta updates, the keyboard shortcuts, the default
/// email app. Nothing on phones.
class DesktopAppSettingsSection extends ConsumerStatefulWidget {
  const DesktopAppSettingsSection({super.key});

  /// Windows: Settings → Apps → Default apps → XatBox (the installer
  /// registers it for the user, or for the computer with /ALLUSERS).
  /// macOS: the system asks to confirm XatBox for mailto: links.
  static Future<void> openDefaultApps(BuildContext context) async {
    if (Platform.isMacOS) {
      final messenger = ScaffoldMessenger.of(context);
      final done = context.l10n.desktopDefaultMailAppDone;
      if (await DesktopShell.setDefaultMailApp()) messenger.showSnackBar(SnackBar(content: Text(done)));
      return;
    }
    final machine = isMachineWideInstall(Platform.resolvedExecutable, Platform.environment);
    final uri = Uri.parse('ms-settings:defaultapps?${machine ? 'registeredAppMachine' : 'registeredAppUser'}=XatBox');
    try {
      await launchUrl(uri);
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'default apps page not opened', error: e);
    }
  }

  @override
  ConsumerState<DesktopAppSettingsSection> createState() => _DesktopAppSettingsSectionState();
}

class _DesktopAppSettingsSectionState extends ConsumerState<DesktopAppSettingsSection> {
  LaunchAtLogin? _login;

  @override
  void initState() {
    super.initState();
    if (DesktopShell.available) {
      unawaited(DesktopShell.getLaunchAtLogin().then((v) {
        if (mounted) setState(() => _login = v);
      }));
    }
  }

  Future<void> _setLogin(bool on) async {
    await DesktopShell.setLaunchAtLogin(on);
    final now = await DesktopShell.getLaunchAtLogin();
    if (mounted) setState(() => _login = now);
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return const SizedBox.shrink();
    final l10n = context.l10n;
    final settings = ref.watch(desktopSettingsProvider);
    final notifier = ref.read(desktopSettingsProvider.notifier);
    final login = _login;
    final mod = Platform.isMacOS ? '⌃⌥' : 'Ctrl+Alt+';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        ListTile(
          dense: true,
          title: Text(l10n.desktopAppSection, style: Theme.of(context).textTheme.titleSmall),
        ),
        if (login != null)
          SwitchListTile(
            key: const Key('settings_launch_at_login'),
            secondary: const Icon(LucideIcons.power),
            title: Text(l10n.desktopLaunchAtLogin),
            subtitle: Text(login.managed ? l10n.desktopLaunchAtLoginManaged : l10n.desktopLaunchAtLoginHint),
            value: login.enabled,
            onChanged: login.managed ? null : (v) => unawaited(_setLogin(v)),
          ),
        SwitchListTile(
          key: const Key('settings_mail_notifications'),
          secondary: const Icon(LucideIcons.mail),
          title: Text(l10n.desktopMailNotifications),
          subtitle: Text(l10n.desktopMailNotificationsHint),
          value: settings.mailNotifications,
          onChanged: (v) => notifier.update((s) => s.copyWith(mailNotifications: v)),
        ),
        if (DesktopShell.available) ...[
          SwitchListTile(
            key: const Key('settings_global_hotkeys'),
            secondary: const Icon(LucideIcons.command),
            title: Text(l10n.desktopGlobalHotkeys),
            subtitle: Text(l10n.desktopGlobalHotkeysHint('${mod}M', '${mod}X')),
            value: settings.globalHotkeys,
            onChanged: (v) => notifier.update((s) => s.copyWith(globalHotkeys: v)),
          ),
          SwitchListTile(
            key: const Key('settings_auto_away'),
            secondary: const Icon(LucideIcons.moon),
            title: Text(l10n.desktopAutoAway),
            subtitle: Text(l10n.desktopAutoAwayHint),
            value: settings.autoAway,
            onChanged: (v) => notifier.update((s) => s.copyWith(autoAway: v)),
          ),
          SwitchListTile(
            key: const Key('settings_spell_check'),
            secondary: const Icon(LucideIcons.spellCheck),
            title: Text(l10n.desktopSpellCheck),
            subtitle: Text(l10n.desktopSpellCheckHint),
            value: settings.spellCheck,
            onChanged: (v) => notifier.update((s) => s.copyWith(spellCheck: v)),
          ),
        ],
        _SoundTile<DesktopNotificationSound>(
          key: const Key('settings_notification_sound'),
          icon: LucideIcons.bellRing,
          title: l10n.desktopNotificationSound,
          subtitle: l10n.desktopNotificationSoundHint,
          value: settings.notificationSound,
          options: {
            DesktopNotificationSound.xatbox: l10n.desktopSoundXatbox,
            DesktopNotificationSound.system: l10n.desktopSoundSystem,
            DesktopNotificationSound.none: l10n.desktopSoundNone,
          },
          onChanged: (v) {
            unawaited(notifier.update((s) => s.copyWith(notificationSound: v)));
            if (v == DesktopNotificationSound.xatbox) unawaited(DesktopSounds.playChime());
          },
          onPreview: settings.notificationSound == DesktopNotificationSound.xatbox ? DesktopSounds.playChime : null,
        ),
        _SoundTile<DesktopRingtone>(
          key: const Key('settings_ringtone'),
          icon: LucideIcons.phoneIncoming,
          title: l10n.desktopRingtone,
          subtitle: l10n.desktopRingtoneHint,
          value: settings.ringtone,
          options: {
            DesktopRingtone.xatbox: l10n.desktopSoundXatbox,
            DesktopRingtone.classic: l10n.desktopRingtoneClassic,
          },
          onChanged: (v) {
            unawaited(notifier.update((s) => s.copyWith(ringtone: v)));
            unawaited(DesktopSounds.previewRingtone(v, JustAudioCallSounds.ringtoneFile));
          },
          onPreview: () => DesktopSounds.previewRingtone(settings.ringtone, JustAudioCallSounds.ringtoneFile),
        ),
        SwitchListTile(
          key: const Key('settings_mini_call'),
          secondary: const Icon(LucideIcons.pictureInPicture2),
          title: Text(l10n.desktopMiniCall),
          subtitle: Text(l10n.desktopMiniCallHint),
          value: settings.miniCallWindow,
          onChanged: (v) => notifier.update((s) => s.copyWith(miniCallWindow: v)),
        ),
        if (ref.watch(appUpdatesSupportedProvider))
          SwitchListTile(
            key: const Key('settings_beta_updates'),
            secondary: const Icon(LucideIcons.flaskConical),
            title: Text(l10n.desktopBetaUpdates),
            subtitle: Text(l10n.desktopBetaUpdatesHint),
            value: settings.betaUpdates,
            onChanged: (v) async {
              await notifier.update((s) => s.copyWith(betaUpdates: v));
              // Ask the chosen channel now, not in up to 6 hours.
              unawaited(ref.read(updateControllerProvider.notifier).check());
            },
          ),
        ListTile(
          key: const Key('settings_shortcuts'),
          leading: const Icon(LucideIcons.keyboard),
          title: Text(l10n.desktopShortcutsTitle),
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () => showDesktopShortcuts(context),
        ),
        if (Platform.isWindows || Platform.isMacOS)
          ListTile(
            key: const Key('settings_default_mail_app'),
            leading: const Icon(LucideIcons.mailPlus),
            title: Text(l10n.desktopDefaultMailApp),
            subtitle: Text(Platform.isMacOS ? l10n.desktopDefaultMailAppHintMac : l10n.desktopDefaultMailAppHint),
            trailing: Platform.isWindows ? const Icon(LucideIcons.externalLink) : null,
            onTap: () => DesktopAppSettingsSection.openDefaultApps(context),
          ),
      ],
    );
  }
}

/// A sound setting: a drop-down of the choices and «Прослушать».
class _SoundTile<T> extends StatelessWidget {
  const _SoundTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
    required this.onChanged,
    this.onPreview,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final Future<void> Function()? onPreview;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButton<T>(
            value: value,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(10),
            items: [
              for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) {
              if (v != null && v != value) onChanged(v);
            },
          ),
          IconButton(
            tooltip: context.l10n.desktopSoundPreview,
            onPressed: onPreview == null ? null : () => unawaited(onPreview!()),
            icon: const Icon(LucideIcons.play),
          ),
        ],
      ),
    );
  }
}
