import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/utils/diagnostic_log.dart';
import '../theme/skins.dart';
import 'desktop.dart';
import 'desktop_sounds.dart';

/// Switches of the desktop app that live on this computer only
/// (`desktop_settings.json` in the app support folder, next to window.json).
@immutable
class DesktopSettings {
  const DesktopSettings({
    this.mailNotifications = true,
    this.globalHotkeys = true,
    this.autoAway = true,
    this.miniCallWindow = true,
    this.spellCheck = true,
    this.betaUpdates = false,
    this.backdropPath,
    this.backdropDim = 0.45,
    this.backdropBlur = 0,
    this.notificationSound = DesktopNotificationSound.xatbox,
    this.ringtone = DesktopRingtone.xatbox,
  });

  /// A toast for each new message in the inbox.
  final bool mailNotifications;

  /// Ctrl+Alt+M / ⌃⌥M new message and Ctrl+Alt+X / ⌃⌥X show XatBox, from
  /// any program.
  final bool globalHotkeys;

  /// «Отошёл» in chat while the computer is locked or idle.
  final bool autoAway;

  /// A small always-on-top window with the call when XatBox loses focus.
  final bool miniCallWindow;

  /// Misspelled words underlined in the composer.
  final bool spellCheck;

  /// «Получать бета-версии»: updates from the beta channel, a day before
  /// everybody else (backend/deploy/promote-desktop.sh).
  final bool betaUpdates;

  /// «Свой фон» (skin `glassCustom`): the copy of the picture the user chose,
  /// inside the app support folder. Null until they choose one.
  final String? backdropPath;

  /// How far [backdropPath] is darkened, 0…1.
  final double backdropDim;

  /// How far [backdropPath] is blurred, 0…30 logical pixels.
  final double backdropBlur;

  /// What a new message or letter sounds like.
  final DesktopNotificationSound notificationSound;

  /// The melody of an incoming call.
  final DesktopRingtone ringtone;

  /// The backdrop as the theme layer wants it.
  CustomBackdrop get backdrop =>
      CustomBackdrop(path: backdropPath, dim: backdropDim, blur: backdropBlur);

  /// [clearBackdropPath] removes the picture: passing `backdropPath: null`
  /// cannot say «none» apart from «unchanged».
  DesktopSettings copyWith({
    bool? mailNotifications,
    bool? globalHotkeys,
    bool? autoAway,
    bool? miniCallWindow,
    bool? spellCheck,
    bool? betaUpdates,
    String? backdropPath,
    bool clearBackdropPath = false,
    double? backdropDim,
    double? backdropBlur,
    DesktopNotificationSound? notificationSound,
    DesktopRingtone? ringtone,
  }) => DesktopSettings(
    mailNotifications: mailNotifications ?? this.mailNotifications,
    globalHotkeys: globalHotkeys ?? this.globalHotkeys,
    autoAway: autoAway ?? this.autoAway,
    miniCallWindow: miniCallWindow ?? this.miniCallWindow,
    spellCheck: spellCheck ?? this.spellCheck,
    betaUpdates: betaUpdates ?? this.betaUpdates,
    backdropPath: clearBackdropPath ? null : (backdropPath ?? this.backdropPath),
    backdropDim: backdropDim ?? this.backdropDim,
    backdropBlur: backdropBlur ?? this.backdropBlur,
    notificationSound: notificationSound ?? this.notificationSound,
    ringtone: ringtone ?? this.ringtone,
  );

  Map<String, Object> toJson() => {
    'mail_notifications': mailNotifications,
    'global_hotkeys': globalHotkeys,
    'auto_away': autoAway,
    'mini_call_window': miniCallWindow,
    'spell_check': spellCheck,
    'beta_updates': betaUpdates,
    'backdrop_path': ?backdropPath,
    'backdrop_dim': backdropDim,
    'backdrop_blur': backdropBlur,
    'notification_sound': notificationSound.name,
    'ringtone': ringtone.name,
  };

  /// Missing or broken values keep their defaults (pure, unit-tested).
  static DesktopSettings fromJson(Object? json) {
    if (json is! Map) return const DesktopSettings();
    bool flag(String key, bool fallback) => json[key] is bool ? json[key] as bool : fallback;
    double number(String key, double fallback, double max) {
      final v = json[key];
      if (v is! num || !v.isFinite) return fallback;
      return v.toDouble().clamp(0.0, max);
    }

    const d = DesktopSettings();
    final path = json['backdrop_path'];
    return DesktopSettings(
      mailNotifications: flag('mail_notifications', d.mailNotifications),
      globalHotkeys: flag('global_hotkeys', d.globalHotkeys),
      autoAway: flag('auto_away', d.autoAway),
      miniCallWindow: flag('mini_call_window', d.miniCallWindow),
      spellCheck: flag('spell_check', d.spellCheck),
      betaUpdates: flag('beta_updates', d.betaUpdates),
      backdropPath: path is String && path.isNotEmpty ? path : null,
      backdropDim: number('backdrop_dim', d.backdropDim, 1),
      backdropBlur: number('backdrop_blur', d.backdropBlur, 30),
      notificationSound: DesktopNotificationSound.parse(json['notification_sound']),
      ringtone: DesktopRingtone.parse(json['ringtone']),
    );
  }
}

/// Where the settings file is kept: the desktop app and, for «Свой фон»
/// of the glass skins, the phone app (never under `flutter test`).
bool get _stored => isDesktop || (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

class DesktopSettingsNotifier extends Notifier<DesktopSettings> {
  @override
  DesktopSettings build() {
    if (_stored) unawaited(_load());
    return const DesktopSettings();
  }

  static Future<File> _file() async =>
      File(p.join((await getApplicationSupportDirectory()).path, 'desktop_settings.json'));

  Future<void> _load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final loaded = DesktopSettings.fromJson(jsonDecode(await file.readAsString()));
      if (ref.mounted) state = loaded;
      DesktopSounds.notification = loaded.notificationSound;
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'desktop settings not read', error: e);
    }
  }

  /// «Свой фон»: copies [source] into the app support folder and points the
  /// settings at the copy, so the backdrop survives the original being moved
  /// or deleted. The previous copy is removed. Returns false if the picture
  /// could not be copied; the old one then stays.
  Future<bool> setBackdrop(String source) async {
    if (!_stored) return false;
    try {
      final dir = await getApplicationSupportDirectory();
      // A fresh name every time: Flutter caches decoded images by path, so
      // reusing one would keep showing the previous picture.
      final name = 'backdrop_${DateTime.now().millisecondsSinceEpoch}${p.extension(source)}';
      final copy = await File(source).copy(p.join(dir.path, name));
      final previous = state.backdropPath;
      await update((s) => s.copyWith(backdropPath: copy.path));
      if (previous != null && previous != copy.path) await _deleteQuietly(previous);
      return true;
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'backdrop not copied', error: e);
      return false;
    }
  }

  /// Forgets the chosen picture and deletes the copy.
  Future<void> clearBackdrop() async {
    final previous = state.backdropPath;
    await update((s) => s.copyWith(clearBackdropPath: true));
    if (previous != null) await _deleteQuietly(previous);
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'old backdrop not deleted', error: e);
    }
  }

  Future<void> update(DesktopSettings Function(DesktopSettings s) change) async {
    state = change(state);
    DesktopSounds.notification = state.notificationSound;
    if (!_stored) return;
    try {
      await (await _file()).writeAsString(jsonEncode(state.toJson()));
    } on Object catch (e) {
      DiagnosticLog.warn('desktop', 'desktop settings not saved', error: e);
    }
  }
}

final desktopSettingsProvider = NotifierProvider<DesktopSettingsNotifier, DesktopSettings>(DesktopSettingsNotifier.new);
