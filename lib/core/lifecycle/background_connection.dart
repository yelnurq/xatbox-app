import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/desktop.dart';
import '../preferences/app_preferences.dart';

/// Grace periods of «Оставаться на связи в фоне».
const backgroundGraceShort = Duration(minutes: 1);
const backgroundGraceLong = Duration(minutes: 15);

/// True once this install has a push token registered with the chat backend
/// (FCM on Android, APNs on iOS). Set by the chat push service.
class PushRegisteredNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool registered) {
    if (state != registered) state = registered;
  }
}

final pushRegisteredProvider = NotifierProvider<PushRegisteredNotifier, bool>(
  PushRegisteredNotifier.new,
);

/// The concrete option in effect: [BackgroundConnection.auto] becomes 1 min
/// when push can deliver messages and calls, 15 min otherwise (without push
/// nothing reaches a disconnected app, so it stays reachable longer).
BackgroundConnection effectiveBackgroundConnection(
  BackgroundConnection mode, {
  required bool pushReady,
}) => mode != BackgroundConnection.auto
    ? mode
    : (pushReady ? BackgroundConnection.oneMinute : BackgroundConnection.fifteenMinutes);

/// How long the socket stays open after the app is hidden; `null` = always.
Duration? backgroundGraceFor(BackgroundConnection mode, {required bool pushReady}) =>
    switch (effectiveBackgroundConnection(mode, pushReady: pushReady)) {
      BackgroundConnection.oneMinute => backgroundGraceShort,
      BackgroundConnection.always => null,
      _ => backgroundGraceLong,
    };

final backgroundGraceProvider = Provider<Duration?>(
  // Desktop has no push: the socket is the only way messages and calls reach
  // a window hidden to the tray, and a PC has no battery budget to protect.
  (ref) => isDesktop ? null : backgroundGraceFor(
    ref.watch(appPreferencesProvider.select((p) => p.backgroundConnection)),
    pushReady: ref.watch(pushRegisteredProvider),
  ),
);
