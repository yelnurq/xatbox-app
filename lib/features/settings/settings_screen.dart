import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/localization/localization.dart';
import '../../core/platform/desktop.dart';
import '../../core/platform/desktop_layout.dart';
import '../../core/preferences/app_preferences.dart';
import '../../core/routing/routes.dart';
import '../../core/security/app_lock.dart';
import '../../core/security/lock_screen.dart';
import '../../core/storage/cache_policy.dart';
import '../../core/storage/storage_usage.dart';
import '../../core/theme/tokens.dart';
import '../../shared/utils/diagnostic_log.dart';
import '../calendar/presentation/calendar_providers.dart';
import '../chat/data/chat_cache.dart';
import '../chat/presentation/chat_providers.dart';
import '../chat/presentation/chat_storage_settings.dart';
import '../chat/presentation/messenger2_providers.dart';
import '../chat/presentation/translation/translation_settings.dart';
import '../home_widget/home_widget_settings.dart';
import '../mail/data/mail_cache.dart';
import '../mail/presentation/mail_providers.dart';
import '../about/presentation/app_settings_tiles.dart';
import 'appearance_screen.dart';
import 'desktop_app_settings.dart';
import 'desktop_settings_screen.dart';
import 'my_status_sheet.dart';

final _cacheStatsProvider = FutureProvider.autoDispose<MailCacheStats>(
  (ref) => ref.watch(mailRepositoryProvider).cacheStats(),
);

final _chatCacheStatsProvider = FutureProvider.autoDispose<ChatCacheStats>(
  (ref) => ref.watch(chatCacheProvider).stats(),
);

final _versionProvider = FutureProvider<String>((_) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
});

/// Storage & data, diagnostics, logout (ТЗ п.24.15, п.24.16).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _loggingOut = false;

  Future<void> _logout() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsLogout),
        content: Text(l10n.settingsLogoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.settingsLogout),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _loggingOut = true);
    // Local wipe always happens, even if the server call fails.
    await ref.read(authSessionProvider).logout();
    // Router redirect takes over from here.
  }

  Future<void> _setCacheLimit(int value) async {
    final cache = ref.read(mailCacheProvider);
    final policy = cache.policy.copyWith(maxCachedMessages: value);
    cache.policy = policy;
    await ref.read(cacheSettingsStoreProvider).write(policy);
    await cache.trimMessages();
    ref.invalidate(_cacheStatsProvider);
    setState(() {});
  }

  Future<T?> _choose<T>(
    String title,
    List<(T, String)> options,
    T current,
  ) => showDialog<T>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(title),
      children: [
        for (final (value, label) in options)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, value),
            child: Row(
              children: [
                Icon(
                  value == current
                      ? LucideIcons.circleDot
                      : LucideIcons.circle,
                  color: value == current
                      ? Theme.of(ctx).colorScheme.primary
                      : null,
                ),
                const SizedBox(width: Space.md),
                Expanded(child: Text(label)),
              ],
            ),
          ),
      ],
    ),
  );

  Future<void> _updatePrefs(AppPreferences Function(AppPreferences) change) =>
      ref.read(appPreferencesProvider.notifier).update(change);

  String _themeLabel(AppThemePreference t) => switch (t) {
    AppThemePreference.system => context.l10n.settingsThemeSystem,
    AppThemePreference.light => context.l10n.settingsThemeLight,
    AppThemePreference.dark => context.l10n.settingsThemeDark,
  };

  static const _systemLanguage = 'system';

  String _languageLabel(String? code) => switch (code) {
    'ru' => context.l10n.settingsLanguageRu,
    'kk' => context.l10n.settingsLanguageKk,
    'en' => context.l10n.settingsLanguageEn,
    _ => context.l10n.settingsLanguageSystem,
  };

  String _timeoutLabel(Duration d) => d == Duration.zero
      ? context.l10n.settingsLockTimeoutImmediately
      : context.l10n.settingsLockTimeoutMinutes(d.inMinutes);

  Future<void> _setPin() async {
    // Desktop: a dialog over the settings page, not a full window.
    if (ref.read(desktopLayoutProvider)) {
      await showDialog<bool>(
        context: context,
        builder: (_) => Dialog(
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440, maxHeight: 640),
            child: const PinSetupScreen(),
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PinSetupScreen()),
    );
  }

  Future<void> _toggleBiometric(bool enable) async {
    if (enable) {
      final ok = await ref
          .read(biometricAuthProvider)
          .authenticate(context.l10n.lockBiometricReason);
      if (!ok) return;
    }
    await _updatePrefs((p) => p.copyWith(biometricEnabled: enable));
  }

  List<Widget> _appearanceAndSecurity(AppPreferences prefs) {
    final l10n = context.l10n;
    final biometricAvailable =
        ref.watch(biometricAvailableProvider).value ?? false;
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
    return [
      header(l10n.settingsAppearanceSection),
      ListTile(
        key: const Key('settings_style'),
        leading: const Icon(LucideIcons.palette),
        title: Text(l10n.settingsStyle),
        subtitle: Text(prefs.skin.label(l10n)),
        trailing: const Icon(LucideIcons.chevronRight),
        onTap: () => openSettingsPage(context, Routes.settingsAppearance),
      ),
      ListTile(
        key: const Key('settings_theme'),
        leading: const Icon(LucideIcons.sunMoon),
        title: Text(l10n.settingsTheme),
        subtitle: Text(_themeLabel(prefs.theme)),
        onTap: () async {
          final picked = await _choose(l10n.settingsTheme, [
            for (final t in AppThemePreference.values) (t, _themeLabel(t)),
          ], prefs.theme);
          // As on the web: choosing a mode returns to the standard skin, which
          // is the one that follows it.
          if (picked != null) await _updatePrefs((p) => p.copyWith(theme: picked, skin: AppSkin.standard));
        },
      ),
      ListTile(
        key: const Key('settings_language'),
        leading: const Icon(LucideIcons.globe),
        title: Text(l10n.settingsLanguage),
        subtitle: Text(_languageLabel(prefs.languageCode)),
        onTap: () async {
          final picked = await _choose(l10n.settingsLanguage, [
            (_systemLanguage, _languageLabel(null)),
            for (final code in AppPreferences.languages)
              (code, _languageLabel(code)),
          ], prefs.languageCode ?? _systemLanguage);
          if (picked == null) return;
          await _updatePrefs(
            (p) => picked == _systemLanguage
                ? p.copyWith(clearLanguage: true)
                : p.copyWith(languageCode: picked),
          );
        },
      ),
      // «Язык перевода» (only when the chat server has a translator).
      const TranslateTargetSettingsTile(),
      const Divider(),
      header(l10n.settingsSecuritySection),
      ListTile(
        key: const Key('settings_password'),
        leading: const Icon(LucideIcons.keyRound),
        title: Text(l10n.settingsSecurityChangePassword),
        trailing: const Icon(LucideIcons.chevronRight),
        onTap: () => openSettingsPage(context, Routes.settingsSecurity),
      ),
      const SessionsSettingsTile(),
      SwitchListTile(
        key: const Key('settings_pin'),
        secondary: const Icon(LucideIcons.lockKeyhole),
        title: Text(l10n.settingsLockPin),
        subtitle: Text(l10n.settingsLockPinHint),
        value: prefs.lockEnabled,
        onChanged: (v) => v
            ? _setPin()
            : ref.read(appLockProvider.notifier).disable(),
      ),
      if (prefs.lockEnabled) ...[
        ListTile(
          leading: const Icon(LucideIcons.keyRound),
          title: Text(l10n.settingsLockChangePin),
          onTap: _setPin,
        ),
        if (biometricAvailable)
          SwitchListTile(
            secondary: const Icon(LucideIcons.fingerprint),
            title: Text(Platform.isWindows ? l10n.settingsLockWindowsHello : l10n.settingsLockBiometric),
            value: prefs.biometricEnabled,
            onChanged: _toggleBiometric,
          ),
        ListTile(
          leading: const Icon(LucideIcons.timer),
          title: Text(l10n.settingsLockTimeout),
          subtitle: Text(_timeoutLabel(prefs.lockTimeout)),
          onTap: () async {
            final picked = await _choose(l10n.settingsLockTimeout, [
              for (final d in AppPreferences.lockTimeoutPresets)
                (d, _timeoutLabel(d)),
            ], prefs.lockTimeout);
            if (picked != null) {
              await _updatePrefs((p) => p.copyWith(lockTimeout: picked));
            }
          },
        ),
        // Desktop: the «X» hides the window to the tray; with this on it
        // also locks, so the window comes back asking for the PIN.
        if (isDesktop)
          SwitchListTile(
            key: const Key('settings_lock_on_close'),
            secondary: const Icon(LucideIcons.panelTopClose),
            title: Text(l10n.settingsLockOnClose),
            subtitle: Text(l10n.settingsLockOnCloseHint),
            value: prefs.lockOnClose,
            onChanged: (v) => _updatePrefs((p) => p.copyWith(lockOnClose: v)),
          ),
      ],
      // The app switcher preview and screenshot blocking are phone features.
      if (!isDesktop)
        SwitchListTile(
          secondary: const Icon(LucideIcons.eyeOff),
          title: Text(l10n.settingsHideContent),
          subtitle: Text(l10n.settingsHideContentHint),
          value: prefs.hideInSwitcher,
          onChanged: (v) => _updatePrefs((p) => p.copyWith(hideInSwitcher: v)),
        ),
      const Divider(),
    ];
  }

  String _size(int bytes) {
    final l10n = context.l10n;
    final (value, unit) = splitBytes(bytes);
    final digits = unit == SizeUnit.b || value >= 100 ? 0 : 1;
    final text = NumberFormat.decimalPatternDigits(
      locale: l10n.localeName,
      decimalDigits: digits,
    ).format(value);
    return switch (unit) {
      SizeUnit.b => l10n.appSizeBytes(text),
      SizeUnit.kb => l10n.appSizeKb(text),
      SizeUnit.mb => l10n.appSizeMb(text),
      SizeUnit.gb => l10n.appSizeGb(text),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final stats = ref.watch(_cacheStatsProvider);
    final version = ref.watch(_versionProvider);
    final policy = ref.read(mailCacheProvider).policy;
    final user = ref.watch(currentUserProvider);
    final prefs = ref.watch(appPreferencesProvider);
    final usage = ref.watch(storageUsageProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          if (user != null)
            ListTile(
              leading: const Icon(LucideIcons.user),
              title: Text(user.displayName),
              subtitle: Text(user.email),
            ),
          // «Статус» with auto-reply (chat).
          const MyStatusSettingsTile(),
          ListTile(
            key: const Key('settings_mail'),
            leading: const Icon(LucideIcons.mail),
            title: Text(l10n.mailSettingsTitle),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: () => openSettingsPage(context, Routes.settingsMail),
          ),
          if (ref.watch(chatEnabledProvider))
            ListTile(
              key: const Key('settings_notifications'),
              leading: const Icon(LucideIcons.bell),
              title: Text(l10n.settingsNotifications),
              subtitle: Text(l10n.settingsNotificationsHint),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => openSettingsPage(context, Routes.settingsNotifications),
            ),
          // Moderation queue: organization moderators and group admins only.
          if (ref.watch(chatEnabledProvider) &&
              (ref.watch(chatFeaturesProvider).value?.moderation ?? false))
            ListTile(
              key: const Key('settings_moderation'),
              leading: const Icon(LucideIcons.gavel),
              title: Text(l10n.moderationTitle),
              subtitle: Text(l10n.moderationHint),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => GoRouter.of(context).push(Routes.chatModeration),
            ),
          if (ref.watch(chatEnabledProvider) &&
              (ref.watch(chatFeaturesProvider).value?.transcription ?? false))
            SwitchListTile(
              key: const Key('settings_auto_transcribe'),
              secondary: const Icon(LucideIcons.audioLines),
              title: Text(l10n.chatAutoTranscribe),
              subtitle: Text(l10n.chatAutoTranscribeHint),
              value: ref.watch(chatAutoTranscribeProvider),
              onChanged: (v) =>
                  ref.read(chatAutoTranscribeProvider.notifier).set(v),
            ),
          const Divider(),
          ..._appearanceAndSecurity(prefs),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
            child: Text(
              l10n.settingsCacheSection,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          ListTile(
            leading: const Icon(LucideIcons.database),
            title: Text(l10n.settingsCacheLimit),
            trailing: DropdownButton<int>(
              value: CachePolicy.presets.contains(policy.maxCachedMessages)
                  ? policy.maxCachedMessages
                  : CachePolicy.presets.first,
              items: [
                for (final p in CachePolicy.presets)
                  DropdownMenuItem(value: p, child: Text('$p')),
              ],
              onChanged: (v) => v == null ? null : _setCacheLimit(v),
            ),
          ),
          ListTile(
            key: const Key('settings_storage_used'),
            leading: const Icon(LucideIcons.hardDrive),
            title: usage.when(
              data: (u) => Text(l10n.settingsStorageUsed(_size(u.totalBytes))),
              loading: () => Text(l10n.loading),
              error: (_, _) => Text(l10n.errUnexpected),
            ),
          ),
          ListTile(
            leading: const Icon(LucideIcons.info),
            title: stats.when(
              data: (s) => Text(
                l10n.settingsCacheStats(s.cachedMessages, s.cachedLists),
              ),
              loading: () => Text(l10n.loading),
              error: (_, _) => Text(l10n.errUnexpected),
            ),
          ),
          ListTile(
            leading: Icon(
              LucideIcons.eraser,
              color: tokens.warning,
            ),
            title: Text(l10n.settingsCacheClear),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              await ref.read(mailRepositoryProvider).clearCache();
              await ref
                  .read(attachmentDownloaderProvider)
                  .clearTemporaryFiles();
              await ref.read(calendarCacheProvider).clearServerCopies();
              if (ref.read(chatEnabledProvider)) {
                await ref.read(chatCacheProvider).clear();
                await ref.read(chatRepositoryProvider).clearMedia();
                ref.invalidate(_chatCacheStatsProvider);
                ref.invalidate(chatMediaSizeProvider);
              }
              ref.invalidate(_cacheStatsProvider);
              ref.invalidate(storageUsageProvider);
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.settingsCacheCleared)),
              );
            },
          ),
          if (ref.watch(chatEnabledProvider))
            ListTile(
              leading: const Icon(LucideIcons.messageCircle),
              title: ref
                  .watch(_chatCacheStatsProvider)
                  .when(
                    data: (s) => Text(
                      l10n.chatCacheStats(
                        s.conversations,
                        s.messages,
                        s.outbox,
                      ),
                    ),
                    loading: () => Text(l10n.loading),
                    error: (_, _) => Text(l10n.errUnexpected),
                  ),
            ),
          if (ref.watch(chatEnabledProvider)) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                Space.sm,
                Space.md,
                0,
              ),
              child: Text(
                l10n.chatPrivacySection,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            ...ref
                .watch(chatSettingsProvider)
                .when(
                  loading: () => [ListTile(title: Text(l10n.loading))],
                  error: (e, _) => [ListTile(title: Text(l10n.errUnexpected))],
                  data: (s) => [
                    SwitchListTile(
                      title: Text(l10n.chatPrivacyOnline),
                      value: s.showOnline,
                      onChanged: (v) => ref
                          .read(chatSettingsProvider.notifier)
                          .save(s.copyWith(showOnline: v)),
                    ),
                    SwitchListTile(
                      title: Text(l10n.chatPrivacyLastSeen),
                      value: s.showLastSeen,
                      onChanged: (v) => ref
                          .read(chatSettingsProvider.notifier)
                          .save(s.copyWith(showLastSeen: v)),
                    ),
                    SwitchListTile(
                      title: Text(l10n.chatPrivacyReadReceipts),
                      value: s.readReceipts,
                      onChanged: (v) => ref
                          .read(chatSettingsProvider.notifier)
                          .save(s.copyWith(readReceipts: v)),
                    ),
                    SwitchListTile(
                      title: Text(l10n.chatPrivacyPushPreview),
                      value: s.pushPreview,
                      onChanged: (v) => ref
                          .read(chatSettingsProvider.notifier)
                          .save(s.copyWith(pushPreview: v)),
                    ),
                  ],
                ),
          ],
          if (ref.watch(chatEnabledProvider)) ...[
            const Divider(),
            const ChatStorageSettingsSection(),
          ],
          // Keyboard shortcuts, default email app (desktop only).
          const DesktopAppSettingsSection(),
          // «Виджет и ярлыки» (Android only).
          const HomeWidgetSettingsSection(),
          const Divider(),
          // «Обновление приложения», «О приложении», «Сообщить о проблеме».
          const AppSettingsSection(),
          const Divider(),
          SwitchListTile(
            key: const Key('settings_error_reports'),
            secondary: const Icon(LucideIcons.shieldAlert),
            title: Text(l10n.settingsSendErrorReports),
            subtitle: Text(l10n.settingsSendErrorReportsHint),
            value: prefs.sendErrorReports,
            onChanged: (v) => _updatePrefs((p) => p.copyWith(sendErrorReports: v)),
          ),
          ExpansionTile(
            leading: const Icon(LucideIcons.bug),
            title: Text(l10n.settingsDiagnostics),
            children: [
              if (DiagnosticLog.recent.isEmpty)
                ListTile(title: Text(l10n.settingsDiagnosticsEmpty))
              else
                for (final r in DiagnosticLog.recent.reversed.take(50))
                  ListTile(
                    dense: true,
                    title: Text(
                      r.message,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    subtitle: Text(
                      '${r.time.toIso8601String()} · ${r.area}${r.error != null ? ' · ${r.error}' : ''}',
                    ),
                  ),
            ],
          ),
          const Divider(),
          ListTile(
            leading: Icon(LucideIcons.logOut, color: tokens.danger),
            title: Text(
              l10n.settingsLogout,
              style: TextStyle(color: tokens.danger),
            ),
            trailing: _loggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _loggingOut ? null : _logout,
          ),
          const SizedBox(height: Space.lg),
          Center(
            child: Text(
              version.when(
                data: (v) => l10n.settingsVersion(v),
                loading: () => '',
                error: (_, _) => '',
              ),
              style: TextStyle(color: tokens.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
