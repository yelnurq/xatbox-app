import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/localization/localization.dart';
import '../../../core/platform/desktop.dart';
import '../../../core/platform/desktop_settings.dart';
import '../../../core/websocket/realtime_client.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../chat/presentation/chat_providers.dart';
import '../data/call_chat.dart';
import '../data/desktop_call_native.dart';
import '../data/call_media.dart';
import '../data/call_models.dart';
import '../data/call_native.dart';
import '../data/call_pip.dart';
import '../data/call_preview.dart';
import '../data/meetings.dart';
import '../data/call_push.dart';
import '../data/call_sounds.dart';
import '../data/calls_api.dart';
import '../data/calls_cache.dart';
import '../data/calls_config.dart';
import 'call_controller.dart';

/// Calls need the Call Service and the chat socket (signalling, §3).
final callsEnabledProvider = Provider<bool>(
  (ref) => ref.watch(appEnvProvider).callsEnabled && ref.watch(chatEnabledProvider),
);

final callsApiClientProvider = Provider<ApiClient>((ref) {
  final env = ref.watch(appEnvProvider);
  return ApiClient(
    baseUrl: env.callsBaseUrl,
    userAgent: ref.watch(userAgentProvider),
    tokenReader: () => ref.read(authSessionProvider).currentToken(),
    onUnauthenticated: () => ref.read(authSessionProvider).expire(),
  );
});

final callsApiProvider = Provider<CallsApi>((ref) => CallsApi(ref.watch(callsApiClientProvider)));

final callsCacheProvider = Provider<CallsCache>((ref) => CallsCache(ref.watch(appDatabaseProvider)));

final callNativeProvider = Provider<CallNative>((_) {
  if (isDesktop) {
    final l10n = _l10n();
    return DesktopCallNative(
      DesktopCallTexts(
        incoming: l10n.callsIncoming,
        incomingVideo: l10n.callsIncomingVideo,
        accept: l10n.callsAccept,
        decline: l10n.callsDecline,
      ),
    );
  }
  return PluginCallNative(systemCallTexts());
});

final callSoundsProvider = Provider<CallSounds>((ref) {
  final sounds = JustAudioCallSounds(ringtone: () => ref.read(desktopSettingsProvider).ringtone);
  ref.onDispose(() => unawaited(sounds.dispose()));
  return sounds;
});

final callPipProvider = Provider<CallPip>((_) => MethodChannelCallPip());

AppLocalizations _l10n() {
  final code = Platform.localeName.split(RegExp('[_-]')).first;
  final supported = AppLocalization.supportedLocales.map((l) => l.languageCode);
  return lookupAppLocalizations(Locale(supported.contains(code) ? code : 'ru'));
}

final callMediaFactoryProvider = Provider<CallMediaSession Function()>((_) {
  final l10n = _l10n();
  return () => LiveKitCallMedia(
    screenShareNotificationTitle: l10n.appTitle,
    screenShareNotificationText: l10n.callsScreenShareNotification,
  );
});

final callClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// Camera preview of the pre-join screen (a fake in tests).
final callCameraPreviewFactoryProvider = Provider<CallCameraPreview Function()>((_) => LiveKitCameraPreview.new);

// ---------------------------------------------------------------------------
// Audio processing and traffic saving (per device)
// ---------------------------------------------------------------------------

class CallQualitySettingsNotifier extends Notifier<CallQualitySettings> {
  @override
  CallQualitySettings build() {
    Future.microtask(_load);
    return const CallQualitySettings();
  }

  Future<void> _load() async {
    try {
      final saved = await ref.read(callsCacheProvider).audioSettings();
      if (saved != null && ref.mounted) state = CallQualitySettings(audio: saved.audio, dataSaver: saved.dataSaver);
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'quality settings read failed', error: e);
    }
  }

  /// Applies to the running call at once and remembers for the next calls.
  Future<void> set(CallQualitySettings next) async {
    if (next == state) return;
    state = next;
    unawaited(ref.read(callControllerProvider.notifier).applyQuality(next));
    try {
      await ref.read(callsCacheProvider).putAudioSettings(next.audio, next.dataSaver);
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'quality settings write failed', error: e);
    }
  }
}

final callQualitySettingsProvider = NotifierProvider<CallQualitySettingsNotifier, CallQualitySettings>(CallQualitySettingsNotifier.new);

// ---------------------------------------------------------------------------
// Scheduled meetings (today / upcoming on the calls tab)
// ---------------------------------------------------------------------------

/// A meeting can be joined now: live, or inside its window (opens 10 minutes
/// before the start, a new conference can start until an hour after the end).
bool meetingJoinableAt(Meeting m, DateTime now) {
  switch (m.status) {
    case MeetingStatus.live:
      return true;
    case MeetingStatus.cancelled:
    case MeetingStatus.ended:
      return false;
    default:
      return !now.isBefore(m.opensAt) && now.isBefore(m.endsAt.add(const Duration(hours: 1)));
  }
}

class MeetingsNotifier extends Notifier<AsyncValue<List<Meeting>>> {
  @override
  AsyncValue<List<Meeting>> build() {
    ref.listen<int>(callsReconnectTickProvider, (_, _) => unawaited(refresh()));
    Future.microtask(refresh);
    return const AsyncLoading();
  }

  Future<void> refresh() async {
    if (!ref.mounted) return;
    if (!ref.read(callsEnabledProvider)) {
      state = const AsyncData([]);
      return;
    }
    try {
      final now = ref.read(callClockProvider)();
      final list = await ref.read(callsApiProvider).meetings(from: now.subtract(const Duration(hours: 2)), to: now.add(const Duration(days: 7)));
      if (!ref.mounted) return;
      final visible = list.where((m) => m.status != MeetingStatus.cancelled && m.status != MeetingStatus.ended).toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      state = AsyncData(visible);
    } on AppException catch (e, st) {
      DiagnosticLog.warn('calls', 'meetings load failed', error: e);
      if (ref.mounted && !state.hasValue) state = AsyncError(e, st);
    }
  }
}

final meetingsProvider = NotifierProvider<MeetingsNotifier, AsyncValue<List<Meeting>>>(MeetingsNotifier.new);

/// Android rings an incoming call in the app only while it is in the
/// foreground; otherwise (and always on iOS) the system call UI rings.
/// Desktop has no system call UI: the app always rings itself.
bool _ringsInApp() =>
    isDesktop ||
    Platform.isAndroid && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

final callControllerProvider = NotifierProvider<CallController, CallSessionState>(
  () => CallController(
    (ref) => CallDeps(
      api: ref.read(callsApiProvider),
      native: ref.read(callNativeProvider),
      mediaFactory: ref.read(callMediaFactoryProvider),
      deviceId: () => ref.read(chatRepositoryProvider).deviceId(),
      selfId: () => ref.read(currentUserProvider)?.id ?? '',
      socketConnected: () => ref.read(chatRepositoryProvider).connectionStatus == RealtimeStatus.connected,
      clock: ref.read(callClockProvider),
      sounds: ref.read(callSoundsProvider),
      ringInApp: _ringsInApp,
      selfName: () => ref.read(currentUserProvider)?.displayName ?? '',
      qualitySettings: () => ref.read(callQualitySettingsProvider),
      // Calls of a conversation keep their chat in it (public chat API only).
      sendToConversation: (conversationId, body) async =>
          (await ref.read(chatRepositoryProvider).sendText(conversationId, body)).clientMessageId,
      conversationMessages: (conversationId) => ref.read(chatRepositoryProvider).events.expand((ev) {
        final m = ev.type == 'message.created' ? ev.message : null;
        if (m == null || m.conversationId != conversationId || m.type != 'text' || m.isDeleted || m.body.trim().isEmpty) {
          return const <CallChatMessage>[];
        }
        return [
          CallChatMessage(
            id: m.clientMessageId.isNotEmpty ? m.clientMessageId : m.id,
            senderId: m.senderId,
            body: m.body.trim(),
            createdAt: m.createdAt.toLocal(),
          ),
        ];
      }),
    ),
  ),
);

// ---------------------------------------------------------------------------
// Server config (grid size and limits without a new build)
// ---------------------------------------------------------------------------

/// Last known `GET /calls/config`: defaults, then the cached value, then the
/// server's.
class CallsConfigNotifier extends Notifier<CallsConfig> {
  @override
  CallsConfig build() {
    // Every (re)build — first read, or invalidation on sign-out — reloads.
    Future.microtask(_load);
    return const CallsConfig();
  }

  Future<void> _load() async {
    if (!ref.mounted) return;
    try {
      final cached = await ref.read(callsCacheProvider).config();
      if (cached != null && ref.mounted) state = cached;
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'config cache read failed', error: e);
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (!ref.mounted || !ref.read(appEnvProvider).callsEnabled) return;
    try {
      final config = await ref.read(callsApiProvider).config();
      if (!ref.mounted) return;
      state = config;
      await ref.read(callsCacheProvider).putConfig(config);
    } on AppException catch (e) {
      DiagnosticLog.warn('calls', 'config load failed', error: e);
    }
  }
}

final callsConfigProvider = NotifierProvider<CallsConfigNotifier, CallsConfig>(CallsConfigNotifier.new);

// ---------------------------------------------------------------------------
// History and missed badge
// ---------------------------------------------------------------------------

/// Bumped when the chat socket (re)connects: the network is back.
class CallsReconnectTick extends Notifier<int> {
  @override
  int build() => 0;

  void bump() {
    if (ref.mounted) state++;
  }
}

final callsReconnectTickProvider = NotifierProvider<CallsReconnectTick, int>(CallsReconnectTick.new);

class CallsHistoryState {
  const CallsHistoryState({
    this.calls = const [],
    this.loading = false,
    this.error,
    this.nextCursor = '',
    this.loaded = false,
    this.fromCache = false,
  });
  final List<CallInfo> calls;
  final bool loading;
  final Object? error;
  final String nextCursor;
  final bool loaded;

  /// [calls] come from the local cache, not (yet) from the server.
  final bool fromCache;
}

class CallsHistoryNotifier extends Notifier<CallsHistoryState> {
  CallsHistoryNotifier(this.missedOnly);
  final bool missedOnly;

  @override
  CallsHistoryState build() {
    // Back online: reload what failed.
    ref.listen<int>(callsReconnectTickProvider, (_, _) {
      if (state.error != null || state.fromCache) unawaited(refresh());
    });
    Future.microtask(refresh);
    return const CallsHistoryState(loading: true);
  }

  CallsCache get _cache => ref.read(callsCacheProvider);

  Future<void> refresh() async {
    if (!ref.mounted) return;
    if (!state.loaded) {
      // First page from the cache at once; the server answer replaces it.
      try {
        final cached = await _cache.history(missedOnly: missedOnly);
        if (!ref.mounted) return;
        if (cached != null && !state.loaded) {
          state = CallsHistoryState(calls: cached.calls, loading: true, loaded: true, fromCache: true);
        }
      } on Object catch (e) {
        DiagnosticLog.warn('calls', 'history cache read failed', error: e);
      }
    }
    state = CallsHistoryState(calls: state.calls, loading: true, loaded: state.loaded, fromCache: state.fromCache);
    try {
      final page = await ref.read(callsApiProvider).history(missedOnly: missedOnly);
      if (!ref.mounted) return;
      state = CallsHistoryState(calls: page.calls, nextCursor: page.nextCursor, loaded: true);
      try {
        await _cache.putHistory(missedOnly: missedOnly, calls: page.calls, fetchedAt: DateTime.now());
      } on Object catch (e) {
        DiagnosticLog.warn('calls', 'history cache write failed', error: e);
      }
    } on AppException catch (e) {
      if (ref.mounted) {
        state = CallsHistoryState(calls: state.calls, error: e, loaded: true, fromCache: state.fromCache);
      }
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.nextCursor.isEmpty || state.fromCache) return;
    final current = state;
    state = CallsHistoryState(calls: current.calls, loading: true, nextCursor: current.nextCursor, loaded: true);
    try {
      final page = await ref.read(callsApiProvider).history(missedOnly: missedOnly, cursor: current.nextCursor);
      if (ref.mounted) {
        state = CallsHistoryState(calls: [...current.calls, ...page.calls], nextCursor: page.nextCursor, loaded: true);
      }
    } on AppException catch (e) {
      if (ref.mounted) state = CallsHistoryState(calls: current.calls, nextCursor: current.nextCursor, error: e, loaded: true);
    }
  }
}

final callsHistoryProvider = NotifierProvider.autoDispose.family<CallsHistoryNotifier, CallsHistoryState, bool>(
  CallsHistoryNotifier.new,
);

class MissedCallsNotifier extends Notifier<int> {
  @override
  int build() => 0;

  Future<void> refresh() async {
    try {
      final n = await ref.read(callsApiProvider).missedCount();
      if (ref.mounted) state = n;
    } on AppException catch (e) {
      DiagnosticLog.warn('calls', 'missed count failed', error: e);
    }
  }

  Future<void> markSeen() async {
    if (state == 0) return;
    state = 0;
    try {
      await ref.read(callsApiProvider).markMissedSeen();
    } on AppException catch (e) {
      DiagnosticLog.warn('calls', 'mark missed seen failed', error: e);
    }
  }
}

final missedCallsProvider = NotifierProvider<MissedCallsNotifier, int>(MissedCallsNotifier.new);

// ---------------------------------------------------------------------------
// Picture-in-Picture (Android)
// ---------------------------------------------------------------------------

/// The activity is in PiP mode: the call screen shows only the remote video.
class CallPipMode extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    if (ref.mounted) state = value;
  }
}

final callPipModeProvider = NotifierProvider<CallPipMode, bool>(CallPipMode.new);

/// How many call screens are mounted (PiP is offered only from the call
/// screen, so the PiP window never shows another page).
class CallScreenPresence extends Notifier<int> {
  @override
  int build() => 0;

  void enter() {
    if (ref.mounted) state++;
  }

  void leave() {
    if (ref.mounted) state = math.max(0, state - 1);
  }
}

final callScreenPresenceProvider = NotifierProvider<CallScreenPresence, int>(CallScreenPresence.new);

/// Active video call on the call screen: the app may go to PiP.
bool callPipEligible(CallSessionState s, {required bool onCallScreen}) =>
    onCallScreen && s.video && (s.phase == CallPhase.active || s.phase == CallPhase.reconnecting);

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

/// Watched from the app root while signed in: `call.*` frames of the chat
/// socket, system call UI actions, recovery after reconnect, VoIP token
/// registration (iOS), video pause in background, PiP, server config.
final callsLifecycleProvider = Provider<void>((ref) {
  if (ref.watch(authStateProvider).status != AuthStatus.authenticated || !ref.watch(callsEnabledProvider)) {
    return;
  }
  final controller = ref.read(callControllerProvider.notifier);
  final chat = ref.watch(chatRepositoryProvider);
  final native = ref.read(callNativeProvider);
  final pip = ref.read(callPipProvider);

  final frames = chat.events.listen((ev) {
    // «Встреча начинается», lobby decisions: the meetings list changed.
    if (ev.type.startsWith('meeting.')) {
      unawaited(ref.read(meetingsProvider.notifier).refresh());
      return;
    }
    if (!ev.type.startsWith('call.')) return;
    final signal = CallSignal.fromFrame(ev.payload);
    if (signal == null) return;
    unawaited(controller.onSignal(signal));
    if (signal.call?.status.isTerminal ?? false) {
      unawaited(ref.read(missedCallsProvider.notifier).refresh());
    }
  });
  final connection = chat.connection.listen((s) {
    if (s != RealtimeStatus.connected) return;
    unawaited(controller.recover());
    ref.read(callsReconnectTickProvider.notifier).bump();
  });
  final actions = native.actions.listen((a) => unawaited(controller.onNativeAction(a)));

  Future<void> registerVoip() async {
    final token = await native.voipToken();
    if (token == null) return;
    try {
      await chat.api.registerDevice(platform: 'ios', token: token, deviceId: await chat.deviceId(), kind: 'voip');
    } on AppException catch (e) {
      DiagnosticLog.warn('calls', 'voip registration failed', error: e);
    }
  }

  // PiP: auto-enter while an active video call is on screen; the Dart side
  // also asks explicitly when the app is hidden (older Androids, gestures).
  bool pipEligible() => callPipEligible(
    ref.read(callControllerProvider),
    onCallScreen: ref.read(callScreenPresenceProvider) > 0,
  );
  var autoEnter = false;
  void syncAutoEnter() {
    final want = pipEligible();
    if (want == autoEnter) return;
    autoEnter = want;
    unawaited(pip.setAutoEnter(want));
  }

  ref.listen(callControllerProvider, (_, _) => syncAutoEnter());
  ref.listen(callScreenPresenceProvider, (_, _) => syncAutoEnter());
  final pipModes = pip.modeChanges.listen((inPip) => ref.read(callPipModeProvider.notifier).set(inPip));

  Future<void> onHide() async {
    if (pipEligible() && !ref.read(callPipModeProvider) && await pip.enter()) return;
    if (!ref.mounted || ref.read(callPipModeProvider)) return;
    await controller.onBackground();
  }

  final voip = native.voipTokenUpdates.listen((_) => unawaited(registerVoip()));
  final lifecycle = AppLifecycleListener(
    onHide: () => unawaited(onHide()),
    onResume: () {
      unawaited(controller.onForeground());
      unawaited(ref.read(missedCallsProvider.notifier).refresh());
    },
  );
  Future.microtask(() async {
    if (!ref.mounted) return;
    ref.read(callsConfigProvider); // loads cached, then server limits
    ref.read(callQualitySettingsProvider); // saved audio processing / traffic saving
    await registerVoip();
    if (!ref.mounted) return;
    await ref.read(missedCallsProvider.notifier).refresh();
    if (!ref.mounted) return;
    await controller.recover();
  });
  ref.onDispose(() {
    frames.cancel();
    connection.cancel();
    actions.cancel();
    voip.cancel();
    pipModes.cancel();
    if (autoEnter) unawaited(pip.setAutoEnter(false));
    lifecycle.dispose();
  });
});

/// Push tap / foreground push data for calls (from the chat push service).
void handleCallPushData(ProviderContainer container, Map<String, dynamic> data) {
  if (!isCallPush(data) || !container.read(callsEnabledProvider)) return;
  unawaited(container.read(callControllerProvider.notifier).onPushSignal(data));
}

/// Sign-out: hang up, remove the VoIP registration, wipe cached history.
Future<void> callsSignOut(ProviderContainer container) async {
  if (!container.read(callsEnabledProvider)) return;
  final controller = container.read(callControllerProvider.notifier);
  if (container.read(callControllerProvider).inCall) await controller.hangUp();
  try {
    final native = container.read(callNativeProvider);
    final token = await native.voipToken();
    if (token != null) {
      final chat = container.read(chatRepositoryProvider);
      await chat.api.unregisterDevice(platform: 'ios', token: token, deviceId: await chat.deviceId());
    }
  } on Object catch (e) {
    DiagnosticLog.warn('calls', 'voip unregister failed', error: e);
  }
  try {
    await container.read(callsCacheProvider).clear();
  } on Object catch (e) {
    DiagnosticLog.warn('calls', 'calls cache wipe failed', error: e);
  }
  container.invalidate(callsConfigProvider);
}
