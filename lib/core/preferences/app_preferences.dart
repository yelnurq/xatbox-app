import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import '../../shared/utils/diagnostic_log.dart';
import '../auth/auth_providers.dart';
import '../storage/app_database.dart';
import '../theme/tokens.dart';

enum AppThemePreference {
  system,
  light,
  dark;

  ThemeMode get mode => switch (this) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };
}

/// «Оставаться на связи в фоне»: how long the chat WebSocket stays open after
/// the app is hidden. [auto] resolves to 15 minutes without push and to
/// 1 minute once an FCM/APNs token is registered (see
/// core/lifecycle/background_connection.dart).
enum BackgroundConnection { auto, oneMinute, fifteenMinutes, always }

/// Настройки → Оформление → «Начальный экран»: the tab opened after sign-in
/// and on a cold start. [today] adds the «Сегодня» tab to the bottom bar;
/// [chat] falls back to mail when the messenger is unavailable.
enum StartScreen { mail, today, chat }

/// Device-level preferences (ТЗ п.24.15): appearance, language and the local
/// app lock. They are not account data and survive sign-out, except the lock,
/// which is reset together with the PIN.
@immutable
class AppPreferences {
  const AppPreferences({
    this.theme = AppThemePreference.system,
    this.skin = AppSkin.defaultSkin,
    this.fontScale = FontScale.m,
    this.density = ListDensity.normal,
    this.languageCode,
    this.lockEnabled = false,
    this.biometricEnabled = false,
    this.lockTimeout = const Duration(minutes: 1),
    this.hideInSwitcher = false,
    this.lockOnClose = false,
    this.tasksRailHidden = false,
    this.sendErrorReports = true,
    this.backgroundConnection = BackgroundConnection.auto,
    this.startScreen = StartScreen.mail,
  });

  /// Настройки → Оформление → «Начальный экран».
  final StartScreen startScreen;

  /// Settings → Уведомления → «Оставаться на связи в фоне».
  final BackgroundConnection backgroundConnection;

  /// Light / dark / system. A skin committed to one brightness overrides it,
  /// as on the web (`applyTheme` in providers.tsx).
  final AppThemePreference theme;

  /// The web's `xatbox-skin`, `xatbox-font-scale`, `xatbox-density`.
  final AppSkin skin;
  final FontScale fontScale;
  final ListDensity density;

  /// The palette in effect for [platformBrightness] (system mode).
  SkinPalette palette(Brightness platformBrightness) => skin.palette(theme.mode, platformBrightness);

  Display get display => Display(fontScale: fontScale, density: density);

  /// `null` follows the device language.
  final String? languageCode;
  final bool lockEnabled;
  final bool biometricEnabled;

  /// Time in background after which the lock screen is shown again.
  final Duration lockTimeout;

  /// Covers the UI in the app switcher (Android: also blocks screenshots).
  final bool hideInSwitcher;

  /// Desktop: closing the window (the «X») hides XatBox to the tray and
  /// locks it at once, so opening it again asks for the PIN.
  final bool lockOnClose;

  /// Desktop «Задачи»: the boards rail on the left is folded away.
  final bool tasksRailHidden;

  /// Crash/error reports to the XatBox server (lib/core/errors); on by default.
  final bool sendErrorReports;

  static const languages = <String>['ru', 'kk', 'en'];
  static const lockTimeoutPresets = <Duration>[
    Duration.zero,
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  Locale? get locale => languageCode == null ? null : Locale(languageCode!);

  AppPreferences copyWith({
    AppThemePreference? theme,
    AppSkin? skin,
    FontScale? fontScale,
    ListDensity? density,
    String? languageCode,
    bool clearLanguage = false,
    bool? lockEnabled,
    bool? biometricEnabled,
    Duration? lockTimeout,
    bool? hideInSwitcher,
    bool? lockOnClose,
    bool? tasksRailHidden,
    bool? sendErrorReports,
    BackgroundConnection? backgroundConnection,
    StartScreen? startScreen,
  }) => AppPreferences(
    startScreen: startScreen ?? this.startScreen,
    backgroundConnection: backgroundConnection ?? this.backgroundConnection,
    theme: theme ?? this.theme,
    skin: skin ?? this.skin,
    fontScale: fontScale ?? this.fontScale,
    density: density ?? this.density,
    languageCode: clearLanguage ? null : (languageCode ?? this.languageCode),
    lockEnabled: lockEnabled ?? this.lockEnabled,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    lockTimeout: lockTimeout ?? this.lockTimeout,
    hideInSwitcher: hideInSwitcher ?? this.hideInSwitcher,
    lockOnClose: lockOnClose ?? this.lockOnClose,
    tasksRailHidden: tasksRailHidden ?? this.tasksRailHidden,
    sendErrorReports: sendErrorReports ?? this.sendErrorReports,
  );

  Map<String, Object?> toJson() => {
    'theme': theme.name,
    'skin': skin.name,
    'font_scale': fontScale.name,
    'density': density.name,
    'language': languageCode,
    'lock_enabled': lockEnabled,
    'biometric_enabled': biometricEnabled,
    'lock_timeout_sec': lockTimeout.inSeconds,
    'hide_in_switcher': hideInSwitcher,
    'lock_on_close': lockOnClose,
    'tasks_rail_hidden': tasksRailHidden,
    'send_error_reports': sendErrorReports,
    'background_connection': backgroundConnection.name,
    'start_screen': startScreen.name,
  };

  factory AppPreferences.fromJson(Map<String, Object?> json) {
    final theme = AppThemePreference.values
        .where((t) => t.name == json['theme'])
        .firstOrNull;
    final skin = AppSkin.values.where((s) => s.name == json['skin']).firstOrNull;
    final fontScale = FontScale.values.where((s) => s.name == json['font_scale']).firstOrNull;
    final density = ListDensity.values.where((s) => s.name == json['density']).firstOrNull;
    final language = json['language'];
    final timeout = json['lock_timeout_sec'];
    return AppPreferences(
      theme: theme ?? AppThemePreference.system,
      skin: skin ?? AppSkin.defaultSkin,
      fontScale: fontScale ?? FontScale.m,
      density: density ?? ListDensity.normal,
      languageCode: language is String && languages.contains(language)
          ? language
          : null,
      lockEnabled: json['lock_enabled'] == true,
      biometricEnabled: json['biometric_enabled'] == true,
      lockTimeout: timeout is int && timeout >= 0
          ? Duration(seconds: timeout)
          : const Duration(minutes: 1),
      hideInSwitcher: json['hide_in_switcher'] == true,
      lockOnClose: json['lock_on_close'] == true,
      tasksRailHidden: json['tasks_rail_hidden'] == true,
      sendErrorReports: json['send_error_reports'] != false,
      backgroundConnection:
          BackgroundConnection.values
              .where((b) => b.name == json['background_connection'])
              .firstOrNull ??
          BackgroundConnection.auto,
      startScreen:
          StartScreen.values
              .where((v) => v.name == json['start_screen'])
              .firstOrNull ??
          StartScreen.mail,
    );
  }
}

class AppPreferencesStore {
  AppPreferencesStore(this._db);

  final AppDatabase _db;
  static final _store = stringMapStoreFactory.store('settings');
  static const _key = 'app';

  Future<AppPreferences> read() async {
    final json = await _store.record(_key).get(_db.db);
    return json == null
        ? const AppPreferences()
        : AppPreferences.fromJson(Map<String, Object?>.from(json));
  }

  Future<void> write(AppPreferences prefs) =>
      _store.record(_key).put(_db.db, prefs.toJson());
}

final appPreferencesStoreProvider = Provider<AppPreferencesStore>(
  (ref) => AppPreferencesStore(ref.watch(appDatabaseProvider)),
);

/// Read in `main.dart` before the first frame (no theme/language flash).
final initialAppPreferencesProvider = Provider<AppPreferences>(
  (_) => const AppPreferences(),
);

class AppPreferencesNotifier extends Notifier<AppPreferences> {
  @override
  AppPreferences build() => ref.read(initialAppPreferencesProvider);

  Future<void> update(AppPreferences Function(AppPreferences) change) async {
    final next = change(state);
    state = next;
    try {
      await ref.read(appPreferencesStoreProvider).write(next);
    } on Object catch (e) {
      DiagnosticLog.warn('prefs', 'preferences not saved', error: e);
    }
  }
}

final appPreferencesProvider =
    NotifierProvider<AppPreferencesNotifier, AppPreferences>(
      AppPreferencesNotifier.new,
    );
