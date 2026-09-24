import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:sembast/sembast.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/auth/auth_providers.dart';
import '../../core/auth/auth_session.dart';
import '../../core/lifecycle/app_visibility.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../core/preferences/app_preferences.dart';
import '../../core/routing/deep_links.dart';
import '../../core/routing/link_router.dart';
import '../../core/theme/tokens.dart';
import '../../shared/utils/diagnostic_log.dart';
import '../calendar/data/calendar_models.dart';
import '../calendar/domain/calendar_time.dart';
import '../calendar/presentation/calendar_providers.dart';
import '../chat/data/chat_models.dart';
import '../chat/presentation/chat_providers.dart';
import 'app_shortcuts.dart';
import 'home_widget_snapshot.dart';

// ---------------------------------------------------------------------------
// Platform bridges (fakes in tests)
// ---------------------------------------------------------------------------

/// Writes the widget snapshot and asks the launcher to redraw.
abstract class HomeWidgetBridge {
  Future<void> save(String snapshot);
}

class PluginHomeWidgetBridge implements HomeWidgetBridge {
  const PluginHomeWidgetBridge();

  /// SharedPreferences key read by XatBoxWidgetProvider.DATA_KEY (Android)
  /// and by ios/XatBoxWidget/XatBoxWidget.swift (App Group UserDefaults).
  static const dataKey = 'xatbox.widget';
  static const androidProvider = 'kz.xatbox.xatbox_mobile.XatBoxWidgetProvider';

  /// WidgetKit kind of ios/XatBoxWidget and the App Group it reads.
  static const iosWidgetKind = 'XatBoxWidget';
  static const iosAppGroup = 'group.kz.xatbox.xatboxMobile';

  @override
  Future<void> save(String snapshot) async {
    if (Platform.isIOS) await HomeWidget.setAppGroupId(iosAppGroup);
    await HomeWidget.saveWidgetData<String>(dataKey, snapshot);
    await HomeWidget.updateWidget(
      qualifiedAndroidName: androidProvider,
      iOSName: iosWidgetKind,
    );
  }
}

final homeWidgetBridgeProvider = Provider<HomeWidgetBridge>(
  (_) => const PluginHomeWidgetBridge(),
);

final launcherShortcutsBridgeProvider = Provider<LauncherShortcutsBridge>(
  (_) => const QuickActionsBridge(),
);

/// App shortcuts exist on Android and iOS; off on the host (tests, desktop).
final launcherIntegrationEnabledProvider = Provider<bool>(
  (_) => !kIsWeb && (Platform.isAndroid || Platform.isIOS),
);

/// Android widget and iOS WidgetKit extension (ios/XatBoxWidget, docs/IOS.md).
final homeWidgetSupportedProvider = Provider<bool>(
  (_) => !kIsWeb && (Platform.isAndroid || Platform.isIOS),
);

/// iOS publishes the four fixed Quick Actions instead of recent chats.
final launcherIsIosProvider = Provider<bool>((_) => !kIsWeb && Platform.isIOS);

// ---------------------------------------------------------------------------
// «Текст сообщений в виджете» (device setting, default off)
// ---------------------------------------------------------------------------

final _store = StoreRef<String, Object?>('home_widget');
const _previewKey = 'show_preview';

class HomeWidgetPreviewNotifier extends Notifier<bool> {
  @override
  bool build() {
    unawaited(_load());
    return false;
  }

  Future<void> _load() async {
    try {
      final v = await _store
          .record(_previewKey)
          .get(ref.read(appDatabaseProvider).db);
      if (ref.mounted && v is bool) state = v;
    } on Object catch (e) {
      DiagnosticLog.warn('launcher', 'widget setting unreadable', error: e);
    }
  }

  Future<void> set(bool value) async {
    state = value;
    await _store
        .record(_previewKey)
        .put(ref.read(appDatabaseProvider).db, value);
  }
}

final homeWidgetPreviewProvider =
    NotifierProvider<HomeWidgetPreviewNotifier, bool>(
      HomeWidgetPreviewNotifier.new,
    );

// ---------------------------------------------------------------------------
// Integration
// ---------------------------------------------------------------------------

/// Conversations the launcher may use: none while signed out or without chat.
final launcherChatsProvider = Provider<List<ChatConversation>>((ref) {
  if (!ref.watch(chatEnabledProvider)) return const [];
  if (ref.watch(authStateProvider).status != AuthStatus.authenticated) {
    return const [];
  }
  return ref.watch(conversationsProvider).items;
});

/// Ticks when the calendar cache changes (only when signed in with access).
final _launcherCalendarTickProvider = Provider<int>((ref) {
  if (ref.watch(authStateProvider).status != AuthStatus.authenticated ||
      !ref.watch(calendarEnabledProvider)) {
    return 0;
  }
  return ref.watch(calendarChangesProvider).value ?? 0;
});

/// Keeps app shortcuts and the widget in sync; watched by XatBoxApp.
final launcherIntegrationProvider = Provider<LauncherIntegration?>((ref) {
  if (!ref.watch(launcherIntegrationEnabledProvider)) return null;
  final integration = LauncherIntegration(
    ref,
    widgetBridge: ref.watch(homeWidgetBridgeProvider),
    shortcuts: ref.watch(launcherShortcutsBridgeProvider),
    widgetSupported: ref.watch(homeWidgetSupportedProvider),
    ios: ref.watch(launcherIsIosProvider),
  );
  ref.onDispose(integration.dispose);
  integration.start();
  return integration;
});

/// Updates are throttled ([throttle] after the first change of a burst) and
/// skipped when nothing visible changed; the snapshot is also refreshed
/// every [refreshEvery] while the app runs and when it returns to the
/// foreground. Sign-out replaces the snapshot with a content-free one and
/// removes the recent-chat shortcuts ([clearLauncherData]).
class LauncherIntegration {
  LauncherIntegration(
    this._ref, {
    required this.widgetBridge,
    required this.shortcuts,
    required this.widgetSupported,
    required this.ios,
    this.throttle = const Duration(seconds: 3),
    this.refreshEvery = const Duration(minutes: 30),
  });

  final Ref _ref;
  final HomeWidgetBridge widgetBridge;
  final LauncherShortcutsBridge shortcuts;
  final bool widgetSupported;
  final bool ios;
  final Duration throttle;
  final Duration refreshEvery;

  Timer? _pending;
  ForegroundPeriodic? _periodic;
  AppLifecycleListener? _lifecycle;
  String? _lastSnapshot;
  List<LauncherShortcut>? _lastShortcuts;
  bool _disposed = false;

  void start() {
    unawaited(_guard('shortcuts init', () => shortcuts.initialize(_onAction)));
    _ref.listen<AuthStatus>(
      authStateProvider.select((s) => s.status),
      (_, status) {
        if (status == AuthStatus.authenticated) {
          schedule();
        } else if (status == AuthStatus.unauthenticated) {
          unawaited(clear());
        }
      },
      fireImmediately: true,
    );
    _ref.listen(launcherChatsProvider, (_, _) => schedule());
    _ref.listen(_launcherCalendarTickProvider, (_, _) => schedule());
    _ref.listen(appPreferencesProvider, (_, _) => schedule());
    _ref.listen(homeWidgetPreviewProvider, (_, _) => schedule());
    // Foreground only: in background nothing new arrives to show, and resume
    // refreshes anyway (onResume below).
    _periodic = ForegroundPeriodic(
      _ref.read(appVisibilityProvider),
      refreshEvery,
      schedule,
      catchUpOnResume: false,
    );
    _lifecycle = AppLifecycleListener(onResume: schedule);
    if (ios) schedule();
  }

  void dispose() {
    _disposed = true;
    _pending?.cancel();
    _periodic?.dispose();
    _lifecycle?.dispose();
  }

  /// A shortcut (Quick Action / dynamic shortcut) was tapped: open it like a
  /// deep link, i.e. once signed in and unlocked.
  void _onAction(String type) {
    final link = shortcutLink(type);
    final location = link == null ? null : DeepLinks.toRoute(link);
    if (location == null || _disposed) return;
    _ref.read(pendingNavigationProvider.notifier).request(location);
  }

  void schedule() {
    if (_disposed || _pending != null) return;
    _pending = Timer(throttle, () {
      _pending = null;
      unawaited(flush());
    });
  }

  /// Writes the current state now (tests call it directly).
  Future<void> flush() async {
    if (_disposed) return;
    final prefs = _ref.read(appPreferencesProvider);
    final l10n = _l10n(prefs);
    final signedIn =
        _ref.read(authStateProvider).status == AuthStatus.authenticated;
    final hide = prefs.lockEnabled || prefs.hideInSwitcher;
    final chats = signedIn
        ? _ref.read(launcherChatsProvider)
        : const <ChatConversation>[];

    if (ios || signedIn) {
      await _publishShortcuts(
        runtimeShortcuts(
          ios: ios,
          labels: (
            newMessage: l10n.shortcutNewMessage,
            call: l10n.shortcutCall,
            saved: l10n.chatSaved,
            search: l10n.shortcutSearch,
          ),
          recentChats: hide
              ? const []
              : [
                  for (final c in chats.where(
                    (c) => !c.isSaved && !c.settings.archived,
                  ))
                    (id: c.id, title: c.title),
                ],
        ),
      );
    }
    if (!widgetSupported || !signedIn) return;

    final location = _ref.read(deviceLocationProvider);
    final now = DateTime.now();
    final light = XatBoxTokens(
      prefs.palette(Brightness.light),
      display: prefs.display,
    );
    final dark = XatBoxTokens(
      prefs.palette(Brightness.dark),
      display: prefs.display,
    );
    final snapshot = buildHomeWidgetSnapshot(
      conversations: chats,
      unreadTotal: ConversationsState(items: chats).unreadTotal,
      today: await _today(location, now),
      location: location,
      now: now,
      l10n: l10n,
      showPreview: _ref.read(homeWidgetPreviewProvider),
      hideContent: hide,
      accent: light.primary,
      accentDark: dark.primary,
      avatarColor: light.avatarTextColorFor,
    );
    await _saveSnapshot(snapshot);
  }

  /// Sign-out: content-free widget, no recent-chat shortcuts.
  Future<void> clear() async {
    _pending?.cancel();
    _pending = null;
    final l10n = _l10n(_ref.read(appPreferencesProvider));
    if (!ios) await _publishShortcuts(const []);
    if (widgetSupported) {
      await _saveSnapshot(signedOutHomeWidgetSnapshot(l10n));
    }
  }

  Future<void> _publishShortcuts(List<LauncherShortcut> items) async {
    if (listEquals(items, _lastShortcuts)) return;
    _lastShortcuts = items;
    await _guard('shortcuts', () => shortcuts.publish(items));
  }

  Future<void> _saveSnapshot(String snapshot) async {
    if (snapshot == _lastSnapshot) return;
    _lastSnapshot = snapshot;
    await _guard('widget', () => widgetBridge.save(snapshot));
  }

  Future<List<CalendarOccurrence>> _today(
    tz.Location location,
    DateTime now,
  ) async {
    if (!_ref.read(calendarEnabledProvider)) return const [];
    try {
      final today = EventTime.dateIn(now, location);
      return await _ref
          .read(calendarRepositoryProvider)
          .occurrences(from: today, to: today.addDays(1), device: location);
    } on Object catch (e) {
      DiagnosticLog.warn('launcher', 'calendar unavailable', error: e);
      return const [];
    }
  }

  AppLocalizations _l10n(AppPreferences prefs) {
    final locale = prefs.locale ?? PlatformDispatcher.instance.locale;
    try {
      return lookupAppLocalizations(Locale(locale.languageCode));
    } on FlutterError {
      return lookupAppLocalizations(const Locale('ru'));
    }
  }

  Future<void> _guard(String what, Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      // Missing plugin (host, old launcher) must never break the app.
      DiagnosticLog.warn('launcher', '$what failed', error: e);
    }
  }
}

/// Sign-out hook (lib/features/sessions/sign_out_wipe.dart).
Future<void> clearLauncherData(ProviderContainer container) async {
  await container.read(launcherIntegrationProvider)?.clear();
}
