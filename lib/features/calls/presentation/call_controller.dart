import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/platform/desktop.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../data/call_chat.dart';
import '../data/call_media.dart';
import '../data/call_models.dart';
import '../data/call_native.dart';
import '../data/call_sounds.dart';
import '../data/calls_api.dart';
import '../data/meetings.dart';

enum CallPhase { idle, outgoing, incoming, connecting, active, reconnecting, ended }

/// Why the call screen shows "ended".
abstract final class CallEndReasons {
  static const hangup = 'hangup';
  static const declined = 'declined';
  static const busy = 'busy';
  static const missed = 'missed';
  static const cancelled = 'cancelled';
  static const failed = 'failed';
  static const network = 'network';
  static const permission = 'permission';
  static const answeredElsewhere = 'answered_elsewhere';
  static const removed = 'removed';
}

class CallSessionState {
  const CallSessionState({
    this.phase = CallPhase.idle,
    this.call,
    this.outgoing = false,
    this.video = false,
    this.micOn = true,
    this.cameraOn = false,
    this.frontCamera = true,
    this.speakerOn = false,
    this.screenSharing = false,
    this.participants = const [],
    this.quality = LinkQuality.unknown,
    this.connectedAt,
    this.endReason,
    this.error,
    this.permissionPermanentlyDenied = false,
    this.raisedHands = const {},
    this.handRaised = false,
    this.chat = const [],
    this.chatUnread = 0,
    this.recording = CallRecordingState.none,
    this.recordingBusy = false,
    this.lobby = CallLobby.empty,
  });

  /// People waiting to be let in and guests in the room (moderators only).
  final CallLobby lobby;

  /// In-call chat of this session, oldest first.
  final List<CallChatMessage> chat;

  /// Messages of others received while the chat panel was closed.
  final int chatUnread;

  /// The recording capturing the call now (server state; «REC» for everyone).
  final CallRecordingState recording;

  /// A start/stop recording request is in flight.
  final bool recordingBusy;

  /// Identities of remote participants with a raised hand (data channel).
  final Set<String> raisedHands;

  /// This device raised its hand.
  final bool handRaised;

  final CallPhase phase;
  final CallInfo? call;
  final bool outgoing;
  final bool video;
  final bool micOn;
  final bool cameraOn;
  final bool frontCamera;
  final bool speakerOn;
  final bool screenSharing;
  final List<MediaParticipant> participants;
  final LinkQuality quality;

  /// First moment another participant was in the room (duration counter).
  final DateTime? connectedAt;
  final String? endReason;
  final Object? error;
  final bool permissionPermanentlyDenied;

  bool get inCall => phase != CallPhase.idle && phase != CallPhase.ended;
  String? get callId => call?.id;

  CallSessionState copyWith({
    CallPhase? phase,
    CallInfo? call,
    bool? outgoing,
    bool? video,
    bool? micOn,
    bool? cameraOn,
    bool? frontCamera,
    bool? speakerOn,
    bool? screenSharing,
    List<MediaParticipant>? participants,
    LinkQuality? quality,
    DateTime? connectedAt,
    String? endReason,
    Object? error,
    Set<String>? raisedHands,
    bool? handRaised,
    List<CallChatMessage>? chat,
    int? chatUnread,
    CallRecordingState? recording,
    bool? recordingBusy,
    CallLobby? lobby,
  }) => CallSessionState(
    lobby: lobby ?? this.lobby,
    chat: chat ?? this.chat,
    chatUnread: chatUnread ?? this.chatUnread,
    recording: recording ?? this.recording,
    recordingBusy: recordingBusy ?? this.recordingBusy,
    raisedHands: raisedHands ?? this.raisedHands,
    handRaised: handRaised ?? this.handRaised,
    phase: phase ?? this.phase,
    call: call ?? this.call,
    outgoing: outgoing ?? this.outgoing,
    video: video ?? this.video,
    micOn: micOn ?? this.micOn,
    cameraOn: cameraOn ?? this.cameraOn,
    frontCamera: frontCamera ?? this.frontCamera,
    speakerOn: speakerOn ?? this.speakerOn,
    screenSharing: screenSharing ?? this.screenSharing,
    participants: participants ?? this.participants,
    quality: quality ?? this.quality,
    connectedAt: connectedAt ?? this.connectedAt,
    endReason: endReason ?? this.endReason,
    error: error ?? this.error,
    permissionPermanentlyDenied: permissionPermanentlyDenied,
  );
}

/// Dependencies of [CallController] (overridable in tests).
class CallDeps {
  const CallDeps({
    required this.api,
    required this.native,
    required this.mediaFactory,
    required this.deviceId,
    required this.selfId,
    required this.socketConnected,
    this.clock = DateTime.now,
    this.newId,
    this.sounds = const SilentCallSounds(),
    this.ringInApp = _never,
    this.selfName,
    this.sendToConversation,
    this.conversationMessages,
    this.qualitySettings,
  });

  /// Microphone processing and traffic saving chosen on this device.
  final CallQualitySettings Function()? qualitySettings;

  /// Display name of this user (sender name of in-call chat messages).
  final String Function()? selfName;

  /// Posts a text into a conversation through the chat module and returns
  /// its client message id (calls linked to a conversation keep their chat
  /// there). Null: not available.
  final Future<String> Function(String conversationId, String body)? sendToConversation;

  /// Live text messages of a conversation (shown in the panel of its call).
  final Stream<CallChatMessage> Function(String conversationId)? conversationMessages;

  final CallsApi api;
  final CallNative native;
  final CallMediaSession Function() mediaFactory;
  final Future<String> Function() deviceId;
  final String Function() selfId;
  final bool Function() socketConnected;
  final DateTime Function() clock;
  final String Function()? newId;

  /// Ringback / in-app ringtone.
  final CallSounds sounds;

  /// Whether this device rings an incoming call itself (Android, app in the
  /// foreground); otherwise the system call UI rings.
  final bool Function() ringInApp;
}

bool _never() => false;

/// A quick emoji reaction shown floating over the stage for a moment.
class CallReaction {
  const CallReaction({required this.identity, required this.emoji, required this.local});
  final String identity;
  final String emoji;
  final bool local;
}

/// Emojis offered (and accepted from the data channel) as reactions.
const callReactionEmojis = ['👍', '👏', '😂', '❤️', '🎉', '🤔'];

/// How long the link stays poor before the app offers to save traffic.
const callPoorNetworkPromptDelay = Duration(seconds: 8);

/// «Записать» is offered: recording is enabled on the server, the call is
/// active and not recorded yet; group calls need a host/moderator, in a 1:1
/// call either side may record. The server re-checks.
bool callCanStartRecording(CallSessionState s, {required bool enabled}) {
  final call = s.call;
  if (!enabled || call == null || s.phase != CallPhase.active || s.recording.active) return false;
  return !call.isGroup || call.isModerator;
}

/// «Остановить запись»: the starter, a moderator, or either side of a 1:1 call.
bool callCanStopRecording(CallSessionState s, String selfId) {
  final call = s.call;
  if (call == null || !s.inCall || !s.recording.active) return false;
  return !call.isGroup || call.isModerator || (s.recording.startedBy ?? '') == selfId;
}

/// Client side of one call. The server owns the call state machine; this
/// class only sends user actions, reacts to `call.*` signals (chat socket or
/// push) and drives the media session and the system call UI.
class CallController extends Notifier<CallSessionState> {
  CallController(this._depsReader);

  final CallDeps Function(Ref ref) _depsReader;
  late CallDeps _deps;
  CallMediaSession? _media;
  StreamSubscription<void>? _mediaSub;
  StreamSubscription<CallDataMessage>? _dataSub;
  final _reactions = StreamController<CallReaction>.broadcast();
  final _chatToasts = StreamController<CallChatMessage>.broadcast();
  final _recordingNotices = StreamController<CallRecordingState>.broadcast();
  StreamSubscription<CallChatMessage>? _conversationSub;
  String? _conversationSubCall;
  bool _chatOpen = false;
  final _qualityPrompts = StreamController<void>.broadcast();
  final _lobbyKnocks = StreamController<int>.broadcast();
  Timer? _poorNetworkTimer;
  bool _qualityPrompted = false;

  /// Recordings already announced with the one-time banner.
  final Set<String> _announcedRecordings = {};
  int _remoteCount = 0;
  Timer? _watchdog;
  Timer? _resetTimer;
  bool _starting = false;
  bool _accepting = false;
  int _rejoinAttempts = 0;
  bool _cameraPausedInBackground = false;

  /// Calls this device already showed (WS + push de-duplication).
  final Set<String> _shown = {};

  /// Tone currently requested from [CallDeps.sounds].
  CallTone? _tone;

  /// The user already acted on this call (accept / decline / hang up): it
  /// never rings again here, whatever state updates arrive meanwhile.
  String? _silencedCallId;

  @override
  CallSessionState build() {
    _deps = _depsReader(ref);
    listenSelf((_, next) => _syncSounds(next));
    ref.onDispose(() {
      _watchdog?.cancel();
      _resetTimer?.cancel();
      _stopSounds();
      unawaited(_teardownMedia());
      unawaited(_reactions.close());
      unawaited(_chatToasts.close());
      unawaited(_recordingNotices.close());
      unawaited(_conversationSub?.cancel());
      _poorNetworkTimer?.cancel();
      unawaited(_qualityPrompts.close());
      unawaited(_lobbyKnocks.close());
    });
    return const CallSessionState();
  }

  // ---- sounds ----------------------------------------------------------------

  /// Tones follow the phase: ringback while an outgoing call rings (until
  /// someone joins), in-app ringtone for an incoming call when this device
  /// rings itself. Anything else is silence.
  void _syncSounds(CallSessionState s) {
    final silenced = s.callId != null && s.callId == _silencedCallId;
    final want = switch (s.phase) {
      CallPhase.outgoing when s.outgoing && !silenced => CallTone.ringback,
      CallPhase.incoming when !silenced && _deps.ringInApp() => CallTone.ringtone,
      _ => null,
    };
    if (want == _tone) return;
    _tone = want;
    unawaited(want == null ? _deps.sounds.stop() : _deps.sounds.play(want));
  }

  void _stopSounds() {
    if (_tone == null) return;
    _tone = null;
    unawaited(_deps.sounds.stop());
  }

  /// The currently requested tone (diagnostics / tests).
  CallTone? get tone => _tone;

  CallsApi get _api => _deps.api;
  CallNative get _native => _deps.native;

  // ---- outgoing ------------------------------------------------------------

  /// Starts a call. A second tap while the first request is in flight (or a
  /// call is already running) does nothing, and a retry after a network error
  /// reuses the same `client_call_id`, so no duplicate calls are created.
  Future<void> startCall({
    required List<String> calleeIds,
    required bool video,
    String? conversationId,
    String? mode,
    String? title,
  }) async {
    if (_starting || state.inCall) return;
    _starting = true;
    _resetTimer?.cancel();
    try {
      final permission = await _native.ensurePermissions(video: video);
      if (!ref.mounted) return;
      if (permission != MediaPermission.granted) {
        state = CallSessionState(
          phase: CallPhase.ended,
          endReason: CallEndReasons.permission,
          video: video,
          permissionPermanentlyDenied: permission == MediaPermission.permanentlyDenied,
        );
        return;
      }
      state = CallSessionState(phase: CallPhase.outgoing, outgoing: true, video: video, cameraOn: video, speakerOn: video);
      final clientId = (_deps.newId ?? const Uuid().v4)();
      CallInfo call;
      try {
        call = await _createWithRetry(
          () => _api.create(
            clientCallId: clientId,
            type: video ? 'video' : 'audio',
            calleeIds: calleeIds,
            mode: mode,
            conversationId: conversationId,
            title: title,
          ),
        );
      } on AppException catch (e) {
        _finishLocal(e is NetworkException ? CallEndReasons.network : CallEndReasons.failed, error: e);
        return;
      }
      if (!ref.mounted) return;
      _shown.add(call.id);
      state = state.copyWith(call: call);
      if (call.status.isTerminal) {
        _finishLocal(_reasonFor(call), keepCall: call);
        return;
      }
      await _native.startOutgoing(callId: call.id, title: call.displayTitle(_deps.selfId()), video: video);
      await _native.keepScreenOn(video);
      // Hung up (or signed out) while the system UI was being set up.
      if (!ref.mounted || state.callId != call.id || !state.inCall) return;
      _startWatchdog();
      // Pre-join the room while it rings: media flows the moment they answer.
      unawaited(_join(call, video: video));
    } finally {
      _starting = false;
    }
  }

  /// One transparent retry with the same client id (idempotent on the server).
  Future<CallInfo> _createWithRetry(Future<CallInfo> Function() create) async {
    try {
      return await create();
    } on NetworkException {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      return create();
    }
  }

  // ---- incoming ------------------------------------------------------------

  /// `call.incoming` from the socket, a foreground push, or recovery.
  Future<void> onIncoming(CallInfo call) async {
    if (call.status.isTerminal) return;
    final self = _deps.selfId();
    final me = call.participant(self);
    if (call.callerId == self) return;
    if (me != null && !const {ParticipantStatus.invited, ParticipantStatus.ringing}.contains(me.status)) return;
    final already = !_shown.add(call.id);
    if (state.callId == call.id) return;
    final remaining = (call.ringDeadline ?? _deps.clock().add(const Duration(seconds: 45))).difference(_deps.clock());
    if (!already) {
      // Once per call: the same call can arrive from the socket, recovery
      // and a push at nearly the same time.
      unawaited(_ackRinging(call.id));
      final caller = call.participant(call.callerId);
      await _native.showIncoming(
        callId: call.id,
        callerName: call.isGroup ? call.displayTitle(self) : (caller?.label ?? call.displayTitle(self)),
        video: call.isVideo,
        ringFor: remaining,
      );
    }
    if (!ref.mounted || state.inCall) return; // call waiting: the system UI handles it
    _resetTimer?.cancel();
    state = CallSessionState(phase: CallPhase.incoming, call: call, video: call.isVideo, cameraOn: call.isVideo, speakerOn: call.isVideo);
    _startWatchdog();
  }

  /// Tells the server this device rings (its push is then skipped). 409
  /// means the call is already over: stop ringing here too.
  Future<void> _ackRinging(String id) async {
    try {
      await _api.ringing(id, await _deps.deviceId());
    } on ApiException catch (e) {
      if (e.code != 'CALL_NOT_RINGING') {
        DiagnosticLog.warn('calls', 'ringing ack failed', error: e);
        return;
      }
      await _native.end(id);
      if (ref.mounted && state.callId == id) await refresh();
    } on AppException catch (e) {
      DiagnosticLog.warn('calls', 'ringing ack failed', error: e);
    }
  }

  /// Push data (`call_id`, …) without the call object: load it first.
  Future<void> onPushSignal(Map<String, dynamic> data) async {
    final id = data['call_id'] as String?;
    if (id == null || id.isEmpty) return;
    if (data['type'] != 'call.incoming') {
      if (state.callId == id) await refresh();
      await _native.end(id);
      return;
    }
    if (state.callId == id) return;
    try {
      await onIncoming(await _api.get(id));
    } on AppException catch (e) {
      DiagnosticLog.warn('calls', 'push call load failed', error: e);
    }
  }

  Future<void> accept([String? callId]) async {
    final call = state.call;
    if (_accepting) return;
    if (call == null || (callId != null && callId != call.id) || state.phase != CallPhase.incoming) {
      if (callId != null && !state.inCall) {
        // Accepted in the system UI before the app knew about the call.
        try {
          final loaded = await _api.get(callId);
          _shown.add(loaded.id);
          state = CallSessionState(phase: CallPhase.incoming, call: loaded, video: loaded.isVideo, cameraOn: loaded.isVideo);
          await accept();
          return;
        } on AppException catch (e) {
          await _native.end(callId);
          _finishLocal(CallEndReasons.failed, error: e);
        }
      }
      return;
    }
    _accepting = true;
    _silencedCallId = call.id;
    _stopSounds();
    // Answered in the app: silence the system incoming UI as well.
    await _native.hideIncoming(call.id);
    try {
      final permission = await _native.ensurePermissions(video: call.isVideo);
      if (!ref.mounted) return;
      if (permission != MediaPermission.granted) {
        await decline();
        state = state.copyWith(endReason: CallEndReasons.permission);
        return;
      }
      state = state.copyWith(phase: CallPhase.connecting);
      final result = await _api.accept(call.id, await _deps.deviceId());
      if (!ref.mounted) return;
      state = state.copyWith(call: result.call);
      await _native.connected(call.id);
      await _native.keepScreenOn(call.isVideo);
      await _connectMedia(result.livekit, video: call.isVideo);
    } on ApiException catch (e) {
      final latest = await _tryGet(call.id);
      await _native.end(call.id);
      _finishLocal(latest != null ? _reasonFor(latest) : CallEndReasons.failed, error: e, keepCall: latest);
    } on AppException catch (e) {
      await _native.end(call.id);
      _finishLocal(CallEndReasons.network, error: e);
    } finally {
      _accepting = false;
    }
  }

  Future<void> decline([String? callId]) async {
    final id = callId ?? state.callId;
    if (id == null) return;
    _silencedCallId = id;
    if (state.callId == id) _stopSounds();
    await _native.end(id);
    try {
      await _api.reject(id);
    } on AppException catch (e) {
      DiagnosticLog.warn('calls', 'reject failed', error: e);
    }
    if (state.callId == id) _finishLocal(CallEndReasons.declined);
  }

  // ---- in call ---------------------------------------------------------------

  /// Hang up: cancel while unanswered, otherwise leave (or end for all).
  Future<void> hangUp({bool forAll = false}) async {
    final call = state.call;
    _silencedCallId = call?.id;
    _stopSounds();
    if (call == null) {
      _finishLocal(CallEndReasons.hangup);
      return;
    }
    final unanswered = state.outgoing && state.connectedAt == null && call.status.isRinging;
    // The network picture goes to the server before the media is torn
    // down; it never delays the hang-up itself.
    final stats = unanswered ? null : await _media?.netStats();
    if (stats != null) {
      unawaited(
        _api.stats(call.id, stats).catchError(
          (Object e) => DiagnosticLog.warn('calls', 'net stats not sent', error: e),
        ),
      );
    }
    await _teardownMedia();
    await _native.end(call.id);
    try {
      final updated = unanswered ? await _api.cancel(call.id) : await _api.end(call.id, forAll: forAll);
      _finishLocal(unanswered ? CallEndReasons.cancelled : CallEndReasons.hangup, keepCall: updated);
    } on AppException catch (e) {
      DiagnosticLog.warn('calls', 'hang up request failed', error: e);
      _finishLocal(CallEndReasons.hangup);
    }
  }

  Future<void> setMic(bool on) async {
    state = state.copyWith(micOn: on);
    await _media?.setMic(on);
  }

  /// False when the camera could not be turned on (no camera, busy, denied):
  /// the button goes back to «off» and the screen says so.
  Future<bool> setCamera(bool on) async {
    if (on && await _native.ensurePermissions(video: true) != MediaPermission.granted) return false;
    state = state.copyWith(cameraOn: on);
    try {
      await _media?.setCamera(on);
      return true;
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'camera toggle failed', error: e);
      if (ref.mounted) state = state.copyWith(cameraOn: false);
      if (on) {
        try {
          await _media?.setCamera(false);
        } on Object {
          // Already off.
        }
      }
      return !on;
    }
  }

  Future<void> switchCamera() async {
    await _media?.switchCamera();
    state = state.copyWith(frontCamera: _media?.frontCamera ?? !state.frontCamera);
  }

  Future<void> setSpeaker(bool on) async {
    state = state.copyWith(speakerOn: on);
    await _media?.setSpeaker(on);
  }

  Future<bool> setScreenShare(bool on, {String? sourceId}) async {
    final ok = await _media?.setScreenShare(on, sourceId: sourceId) ?? false;
    state = state.copyWith(screenSharing: _media?.screenSharing ?? false);
    return ok;
  }

  Future<List<AudioRoute>> audioRoutes() async => await _media?.audioRoutes() ?? const [];
  Future<void> selectAudioRoute(AudioRoute r) async => _media?.selectAudioRoute(r);
  Future<List<AudioRoute>> audioInputs() async => await _media?.audioInputs() ?? const [];
  Future<void> selectAudioInput(AudioRoute r) async => _media?.selectAudioInput(r);

  CallMediaSession? get media => _media;

  // ---- raise hand / reactions (room data channel) ----------------------------------

  /// Reactions of everyone (mine included), for the floating overlay.
  Stream<CallReaction> get reactions => _reactions.stream;

  Future<void> toggleHand() async {
    if (!state.inCall) return;
    final up = !state.handRaised;
    state = state.copyWith(handRaised: up);
    await _media?.sendData({'type': 'hand', 'up': up});
  }

  Future<void> sendReaction(String emoji) async {
    if (!state.inCall || !callReactionEmojis.contains(emoji)) return;
    if (!_reactions.isClosed) _reactions.add(CallReaction(identity: '', emoji: emoji, local: true));
    await _media?.sendData({'type': 'reaction', 'emoji': emoji});
  }

  void _onData(CallMediaSession media, CallDataMessage m) {
    if (!ref.mounted || !identical(media, _media) || !state.inCall) return;
    final fromServer = m.identity.isEmpty;
    switch (m.payload['type']) {
      case 'hand' when !fromServer:
        final up = m.payload['up'] == true;
        final hands = {...state.raisedHands};
        up ? hands.add(m.identity) : hands.remove(m.identity);
        state = state.copyWith(raisedHands: hands);
      case 'reaction' when !fromServer:
        final emoji = m.payload['emoji'];
        if (emoji is String && callReactionEmojis.contains(emoji) && !_reactions.isClosed) {
          _reactions.add(CallReaction(identity: m.identity, emoji: emoji, local: false));
        }
      case 'chat':
        final msg = CallChatMessage.fromData(m.identity, m.payload);
        if (msg != null) _addChat(msg);
      // Only the Call Service announces recording state: a participant must
      // not be able to hide the «REC» indicator.
      // The lobby changed (server packet): moderators reload it.
      case 'lobby' when fromServer:
        if (m.payload['call_id'] == state.callId) unawaited(refreshLobby());
      case 'recording' when fromServer:
        final status = m.payload['status'];
        if (status is! String || m.payload['call_id'] != state.callId) return;
        final active = status == 'starting' || status == 'active';
        _setRecording(
          active
              ? CallRecordingState(
                  status: status,
                  enabled: true,
                  recordingId: m.payload['recording_id'] as String?,
                  startedBy: m.payload['started_by'] as String?,
                  startedAt: DateTime.tryParse((m.payload['started_at'] as String?) ?? ''),
                )
              : const CallRecordingState(enabled: true),
        );
    }
  }

  // ---- in-call chat ---------------------------------------------------------------------

  /// New messages of others while the panel is closed (toast bubbles).
  Stream<CallChatMessage> get chatToasts => _chatToasts.stream;

  /// The panel is visible: unread messages are read.
  void setChatOpen(bool open) {
    _chatOpen = open;
    if (open && ref.mounted && state.chatUnread > 0) state = state.copyWith(chatUnread: 0);
  }

  bool get chatOpen => _chatOpen;

  bool get _linkedChat {
    final conv = state.call?.conversationId;
    return conv != null && conv.isNotEmpty && _deps.sendToConversation != null;
  }

  /// Sends a text to everyone in the call: at once over the data channel,
  /// and persisted — into the conversation of the call, or in the Call
  /// Service for ad-hoc calls (late joiners load it). Returns false when
  /// there is nothing to send.
  Future<bool> sendChatMessage(String text) async {
    final call = state.call;
    final body = text.trim();
    if (call == null || !state.inCall || body.isEmpty || body.length > callChatMaxLength) return false;
    final linked = _linkedChat;
    var id = (_deps.newId ?? const Uuid().v4)();
    var status = linked ? CallChatStatus.sent : CallChatStatus.sending;
    if (linked) {
      try {
        id = await _deps.sendToConversation!(call.conversationId!, body);
      } on Object catch (e) {
        DiagnosticLog.warn('calls', 'chat send to conversation failed', error: e);
        status = CallChatStatus.failed;
      }
    }
    if (!ref.mounted || state.callId != call.id) return false;
    final msg = CallChatMessage(
      id: id,
      senderId: _deps.selfId(),
      senderName: _deps.selfName?.call() ?? '',
      body: body,
      createdAt: _deps.clock(),
      local: true,
      status: status,
    );
    _addChat(msg);
    if (status != CallChatStatus.failed) unawaited(_media?.sendData(msg.toData()));
    if (!linked) await _persistChat(call.id, msg);
    return true;
  }

  /// Sends a failed message again (same id: the server de-duplicates).
  Future<void> retryChatMessage(String id) async {
    final call = state.call;
    final msg = state.chat.where((m) => m.id == id && m.local && m.status == CallChatStatus.failed).firstOrNull;
    if (call == null || msg == null || !state.inCall) return;
    _updateChat(id, CallChatStatus.sending);
    if (_linkedChat) {
      try {
        await _deps.sendToConversation!(call.conversationId!, msg.body);
        _updateChat(id, CallChatStatus.sent);
        unawaited(_media?.sendData(msg.toData()));
      } on Object catch (e) {
        DiagnosticLog.warn('calls', 'chat retry failed', error: e);
        _updateChat(id, CallChatStatus.failed);
      }
      return;
    }
    unawaited(_media?.sendData(msg.toData()));
    await _persistChat(call.id, msg);
  }

  Future<void> _persistChat(String callId, CallChatMessage msg) async {
    try {
      await _api.postMessage(callId, clientMessageId: msg.id, body: msg.body);
      _updateChat(msg.id, CallChatStatus.sent);
    } on AppException catch (e) {
      DiagnosticLog.warn('calls', 'chat persist failed', error: e);
      _updateChat(msg.id, CallChatStatus.failed);
    }
  }

  void _updateChat(String id, CallChatStatus status) {
    if (!ref.mounted) return;
    final i = state.chat.indexWhere((m) => m.id == id);
    if (i < 0 || state.chat[i].status == status) return;
    state = state.copyWith(chat: [...state.chat]..[i] = state.chat[i].copyWith(status: status));
  }

  /// Adds a message once (every copy shares the client message id).
  void _addChat(CallChatMessage msg, {bool history = false}) {
    if (!ref.mounted || !state.inCall || msg.id.isEmpty) return;
    if (state.chat.any((m) => m.id == msg.id)) return;
    final mine = msg.local || msg.senderId == _deps.selfId();
    final name = msg.senderName.isNotEmpty ? msg.senderName : (state.call?.participant(msg.senderId)?.label ?? '');
    final named = name == msg.senderName
        ? msg
        : CallChatMessage(
            id: msg.id,
            senderId: msg.senderId,
            senderName: name,
            body: msg.body,
            createdAt: msg.createdAt,
            local: msg.local,
            status: msg.status,
          );
    var list = [...state.chat, named];
    if (history) list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (list.length > 500) list = list.sublist(list.length - 500);
    final unread = !mine && !history && !_chatOpen;
    state = state.copyWith(chat: list, chatUnread: unread ? state.chatUnread + 1 : null);
    if (unread && !_chatToasts.isClosed) _chatToasts.add(named);
  }

  /// Late joiners: history of an ad-hoc call from the Call Service; live
  /// messages of the conversation of a linked call.
  Future<void> _loadChat(CallInfo call) async {
    final conv = call.conversationId;
    if (conv != null && conv.isNotEmpty) {
      final source = _deps.conversationMessages;
      if (source == null || _conversationSubCall == call.id) return;
      await _conversationSub?.cancel();
      _conversationSubCall = call.id;
      _conversationSub = source(conv).listen((m) {
        if (ref.mounted && state.callId == call.id) _addChat(m);
      });
      return;
    }
    try {
      final page = await _api.messages(call.id);
      if (!ref.mounted || state.callId != call.id) return;
      for (final m in page.messages) {
        _addChat(m, history: true);
      }
    } on AppException catch (e) {
      DiagnosticLog.warn('calls', 'chat history failed', error: e);
    }
  }

  // ---- recording -------------------------------------------------------------------------

  /// A recording started (once per recording): the «Звонок записывается» banner.
  Stream<CallRecordingState> get recordingNotices => _recordingNotices.stream;

  void _setRecording(CallRecordingState r) {
    if (!ref.mounted || r == state.recording) return;
    state = state.copyWith(recording: r);
    final id = r.recordingId;
    if (r.active && id != null && _announcedRecordings.add(id) && !_recordingNotices.isClosed) {
      _recordingNotices.add(r);
    }
  }

  /// The server's call object changed: adopt its recording state.
  void _syncRecording(CallInfo call) {
    if (state.callId == call.id && state.inCall) _setRecording(call.recording);
  }

  /// Starts recording the call (`POST /calls/{id}/recording/start`). Throws
  /// [AppException] for the UI (`NOT_MODERATOR`, `RECORDING_UNAVAILABLE`…).
  Future<void> startRecording({bool audioOnly = false}) async {
    final call = state.call;
    if (call == null || !state.inCall || state.recordingBusy) return;
    state = state.copyWith(recordingBusy: true);
    try {
      final res = await _api.startRecording(call.id, audioOnly: audioOnly);
      if (!ref.mounted || state.callId != call.id) return;
      state = state.copyWith(call: res.call, recordingBusy: false);
      _syncRecording(res.call);
    } finally {
      if (ref.mounted && state.recordingBusy) state = state.copyWith(recordingBusy: false);
    }
  }

  /// Stops the recording (`POST /calls/{id}/recording/stop`).
  Future<void> stopRecording() async {
    final call = state.call;
    if (call == null || !state.inCall || state.recordingBusy) return;
    state = state.copyWith(recordingBusy: true);
    try {
      final res = await _api.stopRecording(call.id);
      if (!ref.mounted || state.callId != call.id) return;
      state = state.copyWith(call: res.call, recordingBusy: false);
      _syncRecording(res.call);
    } finally {
      if (ref.mounted && state.recordingBusy) state = state.copyWith(recordingBusy: false);
    }
  }

  // ---- moderation -----------------------------------------------------------------------

  /// Moderator mutes a source of a participant: `microphone`, `camera`,
  /// `screen_share`. Throws [AppException] for the UI.
  Future<void> muteParticipant(String userId, String source) async {
    final id = state.callId;
    if (id != null) await _api.muteParticipant(id, userId, source);
  }

  Future<void> removeParticipant(String userId) async {
    final id = state.callId;
    if (id != null) await _api.removeParticipant(id, userId);
  }

  /// Host promotes (`moderator`) or demotes (`participant`).
  Future<void> setParticipantRole(String userId, String role) async {
    final id = state.callId;
    if (id != null) await _api.setRole(id, userId, role);
  }

  /// Rings a participant who declined, missed or left again (the server
  /// re-invites people not pending and not in the call).
  Future<void> ringAgain(String userId) => invite([userId]);

  /// The user interacts with the "ended" summary: keep it open.
  void keepEnded() {
    if (state.phase == CallPhase.ended) _resetTimer?.cancel();
  }

  /// Moderator adds colleagues to a group/conference call
  /// (`POST /calls/{id}/invite`). Throws [AppException] for the UI
  /// (`NOT_MODERATOR`, `TOO_MANY_PARTICIPANTS`, …); the server re-checks.
  Future<void> invite(List<String> userIds) async {
    final call = state.call;
    if (call == null || userIds.isEmpty) return;
    final updated = await _api.invite(call.id, userIds);
    if (ref.mounted && state.callId == updated.id && state.inCall) state = state.copyWith(call: updated);
  }

  /// App went to background: stop sending video, keep audio (ТЗ п.24.12).
  /// The in-app ringtone stops (the system call UI keeps ringing).
  Future<void> onBackground() async {
    _syncSounds(state);
    // The phones' background-camera rule; a minimized desktop window keeps
    // its camera, as in desktop meeting apps.
    if (state.inCall && state.cameraOn && !isDesktop) {
      _cameraPausedInBackground = true;
      try {
        await _media?.setCamera(false);
      } on Object catch (e) {
        DiagnosticLog.warn('calls', 'camera pause failed', error: e);
      }
    }
  }

  Future<void> onForeground() async {
    _syncSounds(state);
    if (_cameraPausedInBackground) {
      _cameraPausedInBackground = false;
      try {
        await _media?.setCamera(true);
      } on Object catch (e) {
        // Camera taken by another app meanwhile: continue with audio only.
        DiagnosticLog.warn('calls', 'camera resume failed', error: e);
        if (ref.mounted) state = state.copyWith(cameraOn: false);
      }
    }
    if (state.inCall) await refresh();
  }

  // ---- signals -----------------------------------------------------------------

  Future<void> onSignal(CallSignal s) async {
    if (s.type == 'call.lobby') {
      final lobby = s.lobby;
      if (lobby != null && state.callId == s.callId && state.inCall) _setLobby(lobby);
      return;
    }
    if (s.isIncoming) {
      if (s.call != null) await onIncoming(s.call!);
      return;
    }
    final call = s.call;
    final current = state.call;
    final self = _deps.selfId();
    if (current == null || current.id != s.callId) {
      if (s.type == 'call.recording') return; // about a call this device is not in
      // A call rung through push/another device ended: drop its system UI.
      if (call != null && (call.status.isTerminal || call.participant(self)?.status.isInCall == true)) {
        await _native.end(s.callId);
      } else if (call != null && !state.inCall) {
        await onIncoming(call);
      }
      return;
    }
    if (call != null) {
      state = state.copyWith(call: call);
      _syncRecording(call);
    }
    // Accepted / declined on another device of mine.
    if (s.participantUserId == self && state.phase == CallPhase.incoming) {
      final mine = await _deps.deviceId();
      if (s.participantDeviceId != null && s.participantDeviceId != mine && s.participantStatus?.isInCall == true) {
        await _native.end(current.id);
        _finishLocal(CallEndReasons.answeredElsewhere);
        return;
      }
      if (s.participantStatus == ParticipantStatus.declined) {
        await _native.end(current.id);
        _finishLocal(CallEndReasons.declined);
        return;
      }
    }
    if (s.participantUserId == self && s.participantStatus == ParticipantStatus.removed) {
      await _teardownMedia();
      await _native.end(current.id);
      _finishLocal(CallEndReasons.removed);
      return;
    }
    final status = call?.status;
    if (status != null && status.isTerminal) {
      await _teardownMedia();
      await _native.end(current.id);
      _finishLocal(_reasonFor(call!), keepCall: call);
    }
  }

  /// Reload the call (socket down while ringing, app resumed).
  Future<void> refresh() async {
    final id = state.callId;
    if (id == null) return;
    final call = await _tryGet(id);
    if (call == null || !ref.mounted) return;
    await onSignal(CallSignal(type: 'call.status_changed', callId: id, call: call));
  }

  /// After (re)connecting the socket or at start: ringing calls for me and
  /// calls accepted in the system UI while the app was not running.
  Future<void> recover() async {
    try {
      for (final id in await _native.acceptedCallIds()) {
        if (!state.inCall) await accept(id);
      }
      if (state.inCall) {
        await refresh();
        return;
      }
      for (final call in await _api.active()) {
        if (call.status.isRinging && call.callerId != _deps.selfId()) {
          await onIncoming(call);
          break;
        }
      }
    } on AppException catch (e) {
      DiagnosticLog.warn('calls', 'recover failed', error: e);
    }
  }

  Future<void> onNativeAction(NativeCallAction a) async {
    switch (a.type) {
      case NativeActionType.accept:
        if (state.inCall && state.callId != a.callId) await hangUp();
        await accept(a.callId);
      case NativeActionType.decline:
        await decline(a.callId);
      case NativeActionType.end:
        if (state.callId == a.callId && state.inCall) {
          state.phase == CallPhase.incoming ? await decline(a.callId) : await hangUp();
        }
      case NativeActionType.timeout:
        if (state.callId == a.callId && state.phase == CallPhase.incoming) await refresh();
      case NativeActionType.mute:
        if (state.callId == a.callId) await setMic(false);
      case NativeActionType.unmute:
        if (state.callId == a.callId) await setMic(true);
      case NativeActionType.callback:
        break;
    }
  }

  /// Close the "ended" screen and return to idle.
  void dismiss() {
    _resetTimer?.cancel();
    if (ref.mounted && !state.inCall) state = const CallSessionState();
  }

  // ---- media -----------------------------------------------------------------

  Future<void> _join(CallInfo call, {required bool video}) async {
    try {
      final access = await _api.token(call.id, await _deps.deviceId());
      if (!ref.mounted || state.callId != call.id || !state.inCall) return;
      await _connectMedia(access, video: video);
    } on AppException catch (e) {
      DiagnosticLog.warn('calls', 'pre-join failed', error: e);
    }
  }

  Future<void> _connectMedia(LiveKitAccess access, {required bool video}) async {
    await _teardownMedia();
    if (!ref.mounted) return;
    final media = _deps.mediaFactory();
    _media = media;
    _remoteCount = 0;
    // Decided before the saved quality settings touch the session: their
    // change notifications must not reset the camera state of the call.
    final quality = _deps.qualitySettings?.call();
    final wantVideo = video && state.cameraOn && quality?.dataSaver != CallDataSaver.audioOnly;
    // The connect notification reports the SDK default (mic on): remember the choice.
    final wantMic = state.micOn;
    try {
      if (quality != null) {
        await media.setAudioSettings(quality.audio);
        await media.setDataSaver(quality.dataSaver);
      }
      if (!identical(_media, media)) return; // torn down meanwhile
      _mediaSub = media.changes.listen((_) => _onMedia(media));
      _dataSub = media.data.listen((m) => _onData(media, m));
      await media.connect(access, video: wantVideo);
      if (!ref.mounted) {
        await _teardownMedia();
        return;
      }
      if (!wantMic) await media.setMic(false);
      _rejoinAttempts = 0;
      _onMedia(media);
      final call = state.call;
      if (call != null) {
        _syncRecording(call);
        unawaited(_loadChat(call));
        unawaited(refreshLobby());
      }
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'media connect failed', error: e);
      if (identical(_media, media)) await _rejoin();
    }
  }

  void _onMedia(CallMediaSession media) {
    if (!ref.mounted || !identical(media, _media) || state.phase == CallPhase.ended) return;
    final others = media.participants.where((p) => !p.isLocal).toList();
    var phase = state.phase;
    DateTime? connectedAt = state.connectedAt;
    switch (media.connection) {
      case MediaConnection.connected:
        if (others.isNotEmpty) {
          connectedAt ??= _deps.clock();
          phase = CallPhase.active;
        } else if ((state.call?.meetingId ?? '').isNotEmpty && (phase == CallPhase.connecting || phase == CallPhase.reconnecting)) {
          // A meeting is on as soon as I am in the room, even alone.
          connectedAt ??= _deps.clock();
          phase = CallPhase.active;
        } else if (phase == CallPhase.reconnecting) {
          phase = connectedAt != null ? CallPhase.active : (state.outgoing ? CallPhase.outgoing : CallPhase.connecting);
        }
      case MediaConnection.reconnecting:
        if (phase != CallPhase.outgoing) phase = CallPhase.reconnecting;
      case MediaConnection.disconnected:
        if (media.lostReason != null) unawaited(_rejoin());
      case MediaConnection.connecting:
        break;
    }
    // Hands of people who left are dropped; a newcomer learns my raised hand.
    final identities = {for (final p in others) p.identity};
    final hands = state.raisedHands.where(identities.contains).toSet();
    if (others.length > _remoteCount && state.handRaised) {
      unawaited(media.sendData({'type': 'hand', 'up': true}));
    }
    _remoteCount = others.length;
    state = state.copyWith(
      phase: phase,
      raisedHands: hands.length == state.raisedHands.length ? state.raisedHands : hands,
      participants: media.participants,
      quality: media.quality,
      micOn: media.micOn,
      cameraOn: media.cameraOn || _cameraPausedInBackground,
      screenSharing: media.screenSharing,
      connectedAt: connectedAt,
    );
    if (phase == CallPhase.active) _watchdog?.cancel();
    _watchQuality(media, phase);
  }

  // ---- network quality ---------------------------------------------------------------------

  /// Offers traffic saving once per call when the link stays poor for
  /// [callPoorNetworkPromptDelay] and no saving is on yet.
  Stream<void> get qualityPrompts => _qualityPrompts.stream;

  void _watchQuality(CallMediaSession media, CallPhase phase) {
    final poor = media.quality == LinkQuality.poor || media.quality == LinkQuality.lost;
    if (!poor || phase != CallPhase.active || _qualityPrompted || media.dataSaver != CallDataSaver.off) {
      if (!poor) {
        _poorNetworkTimer?.cancel();
        _poorNetworkTimer = null;
      }
      return;
    }
    _poorNetworkTimer ??= Timer(callPoorNetworkPromptDelay, () {
      _poorNetworkTimer = null;
      final m = _media;
      if (!ref.mounted || m == null || _qualityPrompted || m.dataSaver != CallDataSaver.off) return;
      if (m.quality != LinkQuality.poor && m.quality != LinkQuality.lost) return;
      _qualityPrompted = true;
      if (!_qualityPrompts.isClosed) _qualityPrompts.add(null);
    });
  }

  /// The user changed microphone processing or traffic saving (applied now).
  Future<void> applyQuality(CallQualitySettings q) async {
    final media = _media;
    if (media == null) return;
    await media.setAudioSettings(q.audio);
    await media.setDataSaver(q.dataSaver);
    if (q.dataSaver != CallDataSaver.off) _poorNetworkTimer?.cancel();
    if (ref.mounted) state = state.copyWith(cameraOn: media.cameraOn);
  }

  // ---- scheduled meetings ----------------------------------------------------------------

  /// Joins a meeting from the pre-join screen with the chosen microphone and
  /// camera. Returns the server answer (a lobby place while the organizer has
  /// not admitted this user), or null when permissions were refused or a call
  /// is already running here.
  Future<MeetingJoinResult?> joinMeeting(String code, {required bool micOn, required bool cameraOn}) async {
    if (_starting || state.inCall) return null;
    _starting = true;
    _resetTimer?.cancel();
    try {
      final permission = await _native.ensurePermissions(video: cameraOn);
      if (!ref.mounted || permission != MediaPermission.granted) return null;
      final result = await _api.joinMeeting(code, await _deps.deviceId());
      final call = result.call;
      final access = result.livekit;
      if (!ref.mounted || call == null || access == null) return result;
      _shown.add(call.id);
      state = CallSessionState(phase: CallPhase.connecting, call: call, video: true, micOn: micOn, cameraOn: cameraOn, speakerOn: true);
      await _native.startOutgoing(callId: call.id, title: call.displayTitle(_deps.selfId()), video: true);
      await _native.connected(call.id);
      await _native.keepScreenOn(cameraOn);
      if (!ref.mounted || state.callId != call.id) return result;
      await _connectMedia(access, video: true);
      return result;
    } finally {
      _starting = false;
    }
  }

  // ---- lobby and guests -----------------------------------------------------------------

  /// The number of people waiting grew (moderators): the in-call banner.
  Stream<int> get lobbyKnocks => _lobbyKnocks.stream;

  bool get _moderatesGroup {
    final call = state.call;
    return call != null && call.isGroup && call.isModerator;
  }

  void _setLobby(CallLobby lobby) {
    if (!ref.mounted) return;
    final before = state.lobby.waiting.length;
    state = state.copyWith(lobby: lobby);
    if (lobby.waiting.length > before && !_lobbyKnocks.isClosed) _lobbyKnocks.add(lobby.waiting.length);
  }

  /// Reloads the lobby of the current call (moderators of group calls).
  Future<void> refreshLobby() async {
    final id = state.callId;
    if (id == null || !state.inCall || !_moderatesGroup) return;
    try {
      final lobby = await _api.lobby(id);
      if (ref.mounted && state.callId == id) _setLobby(lobby);
    } on AppException catch (e) {
      DiagnosticLog.warn('calls', 'lobby load failed', error: e);
    }
  }

  /// Admits (or denies) somebody waiting. Throws [AppException] for the UI.
  Future<void> decideLobby(String entryId, {required bool admit}) async {
    final id = state.callId;
    if (id == null) return;
    if (admit) {
      await _api.admitFromLobby(id, entryId);
    } else {
      await _api.denyFromLobby(id, entryId);
    }
    if (ref.mounted && state.callId == id) {
      state = state.copyWith(
        lobby: CallLobby(waiting: state.lobby.waiting.where((e) => e.id != entryId).toList(), guests: state.lobby.guests),
      );
    }
    await refreshLobby();
  }

  /// Removes a guest from the room. Throws [AppException] for the UI.
  Future<void> removeGuest(String entryId) async {
    final id = state.callId;
    if (id == null) return;
    await _api.removeGuest(id, entryId);
    await refreshLobby();
  }

  /// A link people without an account open in a browser. Throws [AppException].
  Future<CallGuestLink?> createGuestLink({required int expiresInMinutes, required int maxUses, required bool requireLobby, required bool allowScreenShare}) async {
    final id = state.callId;
    if (id == null) return null;
    return _api.createGuestLink(id, expiresInMinutes: expiresInMinutes, maxUses: maxUses, requireLobby: requireLobby, allowScreenShare: allowScreenShare);
  }

  /// The room dropped for good (not a LiveKit auto-reconnect): if the server
  /// still has the call, get a fresh token and join again (max 3 times).
  Future<void> _rejoin() async {
    final call = state.call;
    if (call == null || !state.inCall) return;
    if (_rejoinAttempts >= 3) {
      await _teardownMedia();
      await _native.end(call.id);
      _finishLocal(CallEndReasons.failed);
      return;
    }
    _rejoinAttempts++;
    state = state.copyWith(phase: CallPhase.reconnecting);
    await Future<void>.delayed(Duration(seconds: _rejoinAttempts));
    if (!ref.mounted) return;
    final latest = await _tryGet(call.id);
    if (!ref.mounted) return;
    if (latest == null || latest.status.isTerminal) {
      await _teardownMedia();
      await _native.end(call.id);
      _finishLocal(latest == null ? CallEndReasons.network : _reasonFor(latest), keepCall: latest);
      return;
    }
    try {
      await _connectMedia(await _api.token(call.id, await _deps.deviceId()), video: state.video);
    } on AppException {
      await _rejoin();
    }
  }

  /// Leaves the room without blocking the call flow: signalling the server
  /// (end / cancel) must never wait for media resources to be released.
  Future<void> _teardownMedia() async {
    final media = _media;
    _media = null;
    final sub = _mediaSub;
    _mediaSub = null;
    unawaited(sub?.cancel());
    final dataSub = _dataSub;
    _dataSub = null;
    unawaited(dataSub?.cancel());
    if (media == null) return;
    try {
      await media.disconnect().timeout(const Duration(seconds: 3));
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'media disconnect slow or failed', error: e);
    }
    unawaited(media.dispose().catchError((Object e) {
      DiagnosticLog.warn('calls', 'media dispose failed', error: e);
    }));
  }

  // ---- helpers ---------------------------------------------------------------------

  /// While ringing without a live socket, poll the call so a cancelled or
  /// timed-out call never keeps ringing locally.
  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!ref.mounted || !state.inCall || state.phase == CallPhase.active) {
        _watchdog?.cancel();
        return;
      }
      if (!_deps.socketConnected()) unawaited(refresh());
    });
  }

  Future<CallInfo?> _tryGet(String id) async {
    try {
      return await _api.get(id);
    } on AppException {
      return null;
    }
  }

  static String _reasonFor(CallInfo call) => switch (call.status) {
    CallStatus.declined => CallEndReasons.declined,
    CallStatus.busy => CallEndReasons.busy,
    CallStatus.missed => CallEndReasons.missed,
    CallStatus.cancelled => CallEndReasons.cancelled,
    CallStatus.failed => CallEndReasons.failed,
    _ => CallEndReasons.hangup,
  };

  void _finishLocal(String reason, {Object? error, CallInfo? keepCall}) {
    _watchdog?.cancel();
    _poorNetworkTimer?.cancel();
    _poorNetworkTimer = null;
    _qualityPrompted = false;
    unawaited(_conversationSub?.cancel());
    _conversationSub = null;
    _conversationSubCall = null;
    _chatOpen = false;
    unawaited(_teardownMedia());
    unawaited(_native.keepScreenOn(false));
    _cameraPausedInBackground = false;
    if (!ref.mounted) return;
    state = CallSessionState(
      phase: CallPhase.ended,
      call: keepCall ?? state.call,
      outgoing: state.outgoing,
      video: state.video,
      connectedAt: state.connectedAt,
      endReason: reason,
      error: error,
    );
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 3), dismiss);
  }
}
