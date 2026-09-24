import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/platform/desktop.dart';
import '../../../../core/platform/desktop_settings.dart';
import '../../../../core/platform/desktop_shell.dart';
import '../../../../shared/utils/diagnostic_log.dart';
import '../../../../shared/widgets/desktop_integration.dart';
import '../../data/chat_status.dart';
import '../chat_providers.dart';
import 'chat_status_providers.dart';

/// Whether the computer counts as away (pure, unit-tested): locked, or no
/// input for [limit]. Back is any input within [back] of now.
bool isAwayNow({required bool locked, required double idleSeconds, Duration limit = DesktopAutoAway.idleLimit}) =>
    locked || idleSeconds >= limit.inSeconds;

/// «Отошёл» in chat on the desktop app, like messengers do: set while the
/// screen is locked or nobody touched the computer for [idleLimit], cleared
/// when the person is back. A status the person set themselves is never
/// replaced or cleared; the one set here also runs out by itself after
/// [maxAway], should the app quit meanwhile.
class DesktopAutoAway {
  DesktopAutoAway(this._ref);

  static const idleLimit = Duration(minutes: 10);
  static const maxAway = Duration(hours: 8);
  static const _poll = Duration(seconds: 30);
  static const emoji = '🕒';

  final Ref _ref;
  // Taken at start: stop() runs while the provider is disposed.
  late final ChatStatusApi _api = _ref.read(chatStatusApiProvider);
  late final MyChatStatusNotifier _status = _ref.read(myChatStatusProvider.notifier);
  Timer? _timer;
  StreamSubscription<bool>? _locks;
  bool _locked = false;

  /// The status on the server is the one set here.
  ChatUserStatus? _ours;

  void start() {
    _api;
    _status;
    _timer ??= Timer.periodic(_poll, (_) => unawaited(_check()));
    _locks ??= DesktopShell.sessionLocks.listen((locked) {
      _locked = locked;
      unawaited(_check());
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _locks?.cancel();
    _locks = null;
    await _set(false);
  }

  Future<void> _check() async {
    final idle = await DesktopShell.idleSeconds();
    // Back: some input in the last poll, and the screen is not locked.
    final away = isAwayNow(locked: _locked, idleSeconds: idle);
    if (away) {
      await _set(true);
    } else if (idle < _poll.inSeconds) {
      await _set(false);
    }
  }

  Future<void> _set(bool away) async {
    try {
      final status = _status;
      if (away) {
        if (_ours != null) return;
        final current = await _api.fetch();
        if (current != null && current.isActiveAt(DateTime.now())) return; // theirs
        final text = desktopL10nOf(_ref).desktopAwayStatus;
        _ours = await status.save(
          ChatUserStatus(
            preset: ChatStatusPreset.custom,
            emoji: emoji,
            text: text,
            until: DateTime.now().add(maxAway).toUtc(),
          ),
        );
      } else {
        final ours = _ours;
        if (ours == null) return;
        _ours = null;
        final current = await _api.fetch();
        // Changed meanwhile (by the person, elsewhere): leave it.
        if (current != null && (current.text != ours.text || current.emoji != ours.emoji)) return;
        await status.clear();
      }
    } on Object catch (e) {
      DiagnosticLog.warn('chat', 'auto away failed', error: e);
    }
  }
}

/// Watched once from the app root: auto away while signed in, with chat on
/// and the switch in the desktop settings on.
final desktopAutoAwayProvider = Provider<void>((ref) {
  if (!desktopBackgroundWork) return;
  final signedIn = ref.watch(authStateProvider.select((s) => s.status)) == AuthStatus.authenticated;
  if (!signedIn || !ref.watch(chatEnabledProvider) || !ref.watch(desktopSettingsProvider.select((s) => s.autoAway))) {
    return;
  }
  final away = DesktopAutoAway(ref)..start();
  ref.onDispose(() => unawaited(away.stop()));
});
