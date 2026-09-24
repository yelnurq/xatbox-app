import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/lifecycle/background_connection.dart';
import '../../core/platform/desktop.dart';
import '../chat/data/desktop_notifications.dart';
import '../chat/data/push_notifications.dart' show showTestNotification;
import '../../core/localization/localization.dart';
import '../../core/preferences/app_preferences.dart';
import '../../core/theme/tokens.dart';
import '../../shared/utils/diagnostic_log.dart';
import '../calendar/presentation/calendar_providers.dart';
import '../calls/presentation/calls_providers.dart';
import '../../core/permissions/device_permissions.dart';
import 'background_help_screen.dart';
import 'data/notification_preferences.dart';
import '../../shared/widgets/app_sheet.dart';

/// Settings → «Уведомления»: server-side push toggles and quiet hours
/// (`/me/notification-settings`). Changes apply at once and are synced in
/// the background; offline edits are kept and sent later.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    String current,
    QuietHoursPrefs Function(QuietHoursPrefs, String) apply,
  ) async {
    final minutes = QuietHoursPrefs.parseClock(current) ?? 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null) return;
    final value = QuietHoursPrefs.formatClock(picked.hour, picked.minute);
    await ref
        .read(notificationPreferencesProvider.notifier)
        .update((p) => p.copyWith(quietHours: apply(p.quietHours, value)));
  }

  static String _backgroundLabel(
    BuildContext context,
    BackgroundConnection b, {
    required bool pushReady,
  }) {
    final l10n = context.l10n;
    String concrete(BackgroundConnection c) => switch (c) {
      BackgroundConnection.oneMinute => l10n.notifBackgroundOneMinute,
      BackgroundConnection.always => l10n.notifBackgroundAlways,
      _ => l10n.notifBackgroundFifteenMinutes,
    };
    return b == BackgroundConnection.auto
        ? l10n.notifBackgroundAuto(
            concrete(effectiveBackgroundConnection(b, pushReady: pushReady)),
          )
        : concrete(b);
  }

  /// «Оставаться на связи в фоне»: default / 1 min / 15 min / always.
  Future<void> _pickBackground(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final current = ref.read(appPreferencesProvider).backgroundConnection;
    final pushReady = ref.read(pushRegisteredProvider);
    final picked = await showAppSheet<BackgroundConnection>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: RadioGroup<BackgroundConnection>(
            groupValue: current,
            onChanged: (v) => Navigator.of(context).pop(v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.xs),
                  child: Text(
                    l10n.notifBackgroundTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.sm),
                  child: Text(
                    l10n.notifBackgroundHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                for (final option in BackgroundConnection.values)
                  RadioListTile<BackgroundConnection>(
                    key: Key('notif_background_${option.name}'),
                    value: option,
                    title: Text(_backgroundLabel(context, option, pushReady: pushReady)),
                    subtitle: option == BackgroundConnection.always
                        ? Text(l10n.notifBackgroundAlwaysWarning)
                        : null,
                  ),
                if (!pushReady)
                  Padding(
                    padding: const EdgeInsets.all(Space.md),
                    child: Text(
                      l10n.notifBackgroundNoPush,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked == null || picked == current) return;
    await ref
        .read(appPreferencesProvider.notifier)
        .update((p) => p.copyWith(backgroundConnection: picked));
  }

  Future<void> _openSystemSettings() async {
    try {
      await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.openAppNotificationSettings();
    } on Object catch (e) {
      DiagnosticLog.warn('notifications', 'system settings not opened', error: e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final state = ref.watch(notificationPreferencesProvider);
    final notifier = ref.read(notificationPreferencesProvider.notifier);
    final p = state.prefs;
    final q = p.quietHours;
    final zone = ref.watch(deviceZoneProvider);
    final background = ref.watch(
      appPreferencesProvider.select((p) => p.backgroundConnection),
    );
    final pushReady = ref.watch(pushRegisteredProvider);
    String backgroundLabel(BackgroundConnection b) =>
        _backgroundLabel(context, b, pushReady: pushReady);

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xs),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
    void save(NotificationPreferences Function(NotificationPreferences) f) =>
        notifier.update(f);

    final Widget body;
    if (!state.hasData) {
      body = state.status == NotificationSyncStatus.failed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.bellOff, color: t.textMuted, size: 32),
                    const SizedBox(height: Space.md),
                    Text(l10n.notifPrefsLoadFailed, textAlign: TextAlign.center),
                    const SizedBox(height: Space.md),
                    OutlinedButton(
                      key: const Key('notif_retry'),
                      onPressed: notifier.sync,
                      child: Text(l10n.notifPrefsRetry),
                    ),
                  ],
                ),
              ),
            )
          : const Center(child: CircularProgressIndicator());
    } else {
      body = ListView(
        children: [
          if (state.status == NotificationSyncStatus.pending)
            ListTile(
              key: const Key('notif_pending'),
              dense: true,
              leading: Icon(LucideIcons.cloudOff, color: t.warning),
              title: Text(l10n.notifPrefsPending),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
            child: Text(
              l10n.notifPrefsServerHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          header(l10n.notifPrefsTypesSection),
          SwitchListTile(
            key: const Key('notif_direct'),
            secondary: const Icon(LucideIcons.messageCircle),
            title: Text(l10n.notifPrefsDirect),
            value: p.directMessages,
            onChanged: (v) => save((p) => p.copyWith(directMessages: v)),
          ),
          SwitchListTile(
            key: const Key('notif_groups'),
            secondary: const Icon(LucideIcons.users),
            title: Text(l10n.notifPrefsGroups),
            value: p.groupMessages,
            onChanged: (v) => save((p) => p.copyWith(groupMessages: v)),
          ),
          SwitchListTile(
            key: const Key('notif_mentions_only'),
            secondary: const Icon(LucideIcons.atSign),
            title: Text(l10n.notifPrefsMentionsOnly),
            value: p.groupMentionsOnly,
            onChanged: p.groupMessages
                ? (v) => save((p) => p.copyWith(groupMentionsOnly: v))
                : null,
          ),
          SwitchListTile(
            key: const Key('notif_channels'),
            secondary: const Icon(LucideIcons.megaphone),
            title: Text(l10n.notifPrefsChannels),
            value: p.channels,
            onChanged: (v) => save((p) => p.copyWith(channels: v)),
          ),
          SwitchListTile(
            key: const Key('notif_calls'),
            secondary: const Icon(LucideIcons.phone),
            title: Text(l10n.notifPrefsCalls),
            value: p.calls,
            onChanged: (v) => save((p) => p.copyWith(calls: v)),
          ),
          const Divider(),
          header(l10n.notifPrefsQuietSection),
          SwitchListTile(
            key: const Key('notif_quiet'),
            secondary: const Icon(LucideIcons.moon),
            title: Text(l10n.notifPrefsQuietEnabled),
            subtitle: Text(l10n.notifPrefsQuietHint(zone)),
            value: q.enabled,
            onChanged: (v) =>
                save((p) => p.copyWith(quietHours: p.quietHours.copyWith(enabled: v))),
          ),
          ListTile(
            key: const Key('notif_quiet_start'),
            enabled: q.enabled,
            leading: const Icon(LucideIcons.sunset),
            title: Text(l10n.notifPrefsQuietStart),
            trailing: Text(q.start, style: Theme.of(context).textTheme.titleMedium),
            onTap: () => _pickTime(context, ref, q.start, (q, v) => q.copyWith(start: v)),
          ),
          ListTile(
            key: const Key('notif_quiet_end'),
            enabled: q.enabled,
            leading: const Icon(LucideIcons.sunrise),
            title: Text(l10n.notifPrefsQuietEnd),
            trailing: Text(q.end, style: Theme.of(context).textTheme.titleMedium),
            onTap: () => _pickTime(context, ref, q.end, (q, v) => q.copyWith(end: v)),
          ),
          SwitchListTile(
            key: const Key('notif_quiet_calls'),
            secondary: const Icon(LucideIcons.phoneIncoming),
            title: Text(l10n.notifPrefsQuietAllowCalls),
            subtitle: Text(l10n.notifPrefsQuietAllowCallsHint),
            value: q.allowCalls,
            onChanged: q.enabled
                ? (v) => save(
                    (p) => p.copyWith(quietHours: p.quietHours.copyWith(allowCalls: v)),
                  )
                : null,
          ),
          // A test notification, with the system's reason when it fails:
          // a toast on desktop, a message notification on the phone.
          ...[
            const Divider(),
            ListTile(
              key: const Key('notif_desktop_test'),
              leading: const Icon(LucideIcons.bellRing),
              title: Text(l10n.desktopNotifTest),
              subtitle: Text(isDesktop ? l10n.desktopNotifTestHint : l10n.notifTestHintPhone),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final error = isDesktop
                    ? await showDesktopToast(id: 1, title: l10n.appTitle, body: l10n.desktopNotifTestBody)
                    : await showTestNotification(title: l10n.appTitle, body: l10n.desktopNotifTestBody);
                messenger.showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 8),
                    content: Text(error == null ? l10n.desktopNotifTestSent : l10n.desktopNotifTestFailed(error)),
                  ),
                );
              },
            ),
          ],
          // Desktop keeps the socket open while the app runs (no battery
          // budget, no push): nothing to choose.
          if (!isDesktop) ...[
            const Divider(),
            header(l10n.notifBackgroundSection),
            ListTile(
              key: const Key('notif_background'),
              leading: const Icon(LucideIcons.batteryMedium),
              title: Text(l10n.notifBackgroundTitle),
              subtitle: Text(
                [
                  backgroundLabel(background),
                  if (!pushReady) l10n.notifBackgroundNoPush,
                ].join('\n'),
              ),
              onTap: () => _pickBackground(context, ref),
            ),
          ],
          // Runtime grants of this phone (Android): notifications,
          // full-screen calls, battery optimisation, vendor autostart help.
          DevicePermissionsSection(pushReady: pushReady),
          if (defaultTargetPlatform == TargetPlatform.android) ...[
            const Divider(),
            ListTile(
              key: const Key('notif_system'),
              leading: const Icon(LucideIcons.settings2),
              title: Text(l10n.notifPrefsSystemSettings),
              subtitle: Text(l10n.notifPrefsSystemSettingsHint),
              trailing: const Icon(LucideIcons.externalLink, size: 16),
              onTap: _openSystemSettings,
            ),
          ],
          const SizedBox(height: Space.lg),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsNotifications)),
      body: body,
    );
  }
}

/// «Этот телефон»: the Android grants that decide whether anything arrives at
/// all. Re-read when the user comes back from system settings.
class DevicePermissionsSection extends ConsumerStatefulWidget {
  const DevicePermissionsSection({super.key, required this.pushReady});

  final bool pushReady;

  @override
  ConsumerState<DevicePermissionsSection> createState() => _DevicePermissionsSectionState();
}

typedef _DeviceGrants = ({GrantState notifications, bool fullScreen, bool battery});

class _DevicePermissionsSectionState extends ConsumerState<DevicePermissionsSection>
    with WidgetsBindingObserver {
  _DeviceGrants? _grants;

  DevicePermissions get _permissions => ref.read(devicePermissionsProvider);

  @override
  void initState() {
    super.initState();
    if (!_permissions.supported) return;
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final p = _permissions;
    final grants = (
      notifications: await p.notifications(),
      fullScreen: await p.canUseFullScreenIntent(),
      battery: await p.isIgnoringBatteryOptimizations(),
    );
    if (mounted) setState(() => _grants = grants);
  }

  Future<void> _after(Future<void> action) async {
    await action;
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final grants = _grants;
    if (!_permissions.supported || grants == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final t = context.tokens;
    final callsEnabled = ref.watch(callsEnabledProvider);
    final notificationsOn = grants.notifications == GrantState.granted;
    Widget status(bool ok) => Icon(
      ok ? LucideIcons.circleCheck : LucideIcons.circleAlert,
      size: 20,
      color: ok ? t.success : t.warning,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xs),
          child: Text(l10n.notifDeviceSection, style: Theme.of(context).textTheme.titleSmall),
        ),
        ListTile(
          key: const Key('notif_device_notifications'),
          leading: const Icon(LucideIcons.bellRing),
          title: Text(l10n.notifDeviceNotifications),
          subtitle: Text(notificationsOn ? l10n.notifDeviceGranted : l10n.notifDeviceNotificationsOff),
          trailing: status(notificationsOn),
          onTap: notificationsOn ? null : () => _after(_permissions.requestNotifications()),
        ),
        if (callsEnabled)
          ListTile(
            key: const Key('notif_device_fullscreen'),
            leading: const Icon(LucideIcons.phoneIncoming),
            title: Text(l10n.notifDeviceFullScreen),
            subtitle: Text(grants.fullScreen ? l10n.notifDeviceGranted : l10n.notifDeviceFullScreenOff),
            trailing: status(grants.fullScreen),
            onTap: grants.fullScreen ? null : () => _after(_permissions.openFullScreenIntentSettings()),
          ),
        ListTile(
          key: const Key('notif_device_battery'),
          leading: const Icon(LucideIcons.batteryFull),
          title: Text(l10n.notifDeviceBattery),
          subtitle: Text(
            [
              grants.battery ? l10n.notifDeviceBatteryOn : l10n.notifDeviceBatteryOff,
              if (!grants.battery && !widget.pushReady) l10n.notifDeviceBatteryNoPush,
            ].join('\n'),
          ),
          trailing: status(grants.battery),
          onTap: grants.battery ? null : () => _after(_permissions.requestIgnoreBatteryOptimizations()),
        ),
        ListTile(
          key: const Key('notif_device_help'),
          leading: const Icon(LucideIcons.circleHelp),
          title: Text(l10n.notifDeviceHelp),
          subtitle: Text(l10n.notifDeviceHelpHint),
          trailing: const Icon(LucideIcons.chevronRight, size: 16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const BackgroundHelpScreen()),
          ),
        ),
      ],
    );
  }
}
