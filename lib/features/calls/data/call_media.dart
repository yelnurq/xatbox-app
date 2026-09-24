import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' as lk;

import '../../../core/platform/desktop.dart';
import '../../../shared/utils/diagnostic_log.dart';
import 'call_models.dart';
import 'meetings.dart';

enum MediaConnection { disconnected, connecting, connected, reconnecting }

enum LinkQuality { unknown, lost, poor, good, excellent }

/// A person in the room as the UI needs it (no SDK types leak out).
class MediaParticipant {
  const MediaParticipant({
    required this.identity,
    required this.name,
    required this.isLocal,
    this.speaking = false,
    this.micOn = false,
    this.cameraOn = false,
    this.screenSharing = false,
    this.quality = LinkQuality.unknown,
    this.audioLevel = 0,
  });

  /// `<user_id>#<device_id>` (docs/CALLS-API.md §2.2).
  final String identity;
  final String name;
  final bool isLocal;
  final bool speaking;
  final bool micOn;
  final bool cameraOn;
  final bool screenSharing;
  final LinkQuality quality;

  /// 0..1 speaking level (voice-activity glow).
  final double audioLevel;

  String get userId => identity.split('#').first;
}

/// Topic of the in-call data messages (raise hand, reactions, chat,
/// recording state).
const callDataTopic = 'xatbox.call';

/// One JSON message received over the room data channel.
class CallDataMessage {
  const CallDataMessage({required this.identity, required this.payload});

  /// Sender identity (`<user_id>#<device_id>`); empty for packets sent by
  /// the Call Service (server API SendData).
  final String identity;
  final Map<String, Object?> payload;
}

class AudioRoute {
  const AudioRoute({required this.id, required this.label});
  final String id;
  final String label;
}

/// Media session behind an interface: LiveKit in the app, a fake in tests.
/// Reconnects, ICE restarts and adaptive quality are left to LiveKit.
abstract class CallMediaSession {
  Stream<void> get changes;
  MediaConnection get connection;

  /// Local participant first.
  List<MediaParticipant> get participants;
  LinkQuality get quality;
  bool get micOn;
  bool get cameraOn;
  bool get frontCamera;
  bool get speakerOn;
  bool get screenSharing;

  /// Set when the session ended without [disconnect] (kicked, room closed).
  String? get lostReason;

  Future<void> connect(LiveKitAccess access, {required bool video});
  Future<void> setMic(bool on);
  Future<void> setCamera(bool on);
  Future<void> switchCamera();
  Future<void> setSpeaker(bool on);

  /// Returns false when the user refused screen capture. [sourceId] is the
  /// screen or window picked on desktop (ScreenSelectDialog).
  Future<bool> setScreenShare(bool on, {String? sourceId});
  Future<List<AudioRoute>> audioRoutes();
  Future<void> selectAudioRoute(AudioRoute route);

  /// Microphones (built-in, wired or Bluetooth headset) and the chosen one.
  Future<List<AudioRoute>> audioInputs();
  Future<void> selectAudioInput(AudioRoute route);

  /// Currently selected output / input device id (null: system default).
  String? get selectedAudioRouteId;
  String? get selectedAudioInputId;

  /// Renders a participant's camera or screen share (placeholder when none).
  Widget videoView(MediaParticipant p, {bool screenShare = false});

  /// JSON messages of other participants on [callDataTopic].
  Stream<CallDataMessage> get data;

  /// Sends a JSON message to everyone in the room (reliable).
  Future<void> sendData(Map<String, Object?> payload);

  /// Microphone processing (noise suppression, echo cancellation, auto gain,
  /// music mode). Set before [connect] or at any time during the call.
  CallAudioSettings get audioSettings;
  Future<void> setAudioSettings(CallAudioSettings settings);

  /// Traffic saving: low simulcast layer or no video at all.
  CallDataSaver get dataSaver;
  Future<void> setDataSaver(CallDataSaver mode);

  /// Background blur needs a native segmentation processor; livekit_client
  /// 2.12 exposes the processor interface but ships none for Android/iOS.
  bool get backgroundBlurSupported;

  /// How the media travelled: what the selected ICE pair says about the
  /// path (direct / server-reflexive / relay, UDP or TCP), the round trip
  /// and the loss on the incoming side. Null when no connection was made.
  Future<CallNetStats?> netStats();

  Future<void> disconnect();
  Future<void> dispose();
}

/// The network picture of one call from this device, reported to the Call
/// Service at hang-up (POST /calls/{id}/stats) so the administrators see why
/// a call was bad: a relay over TCP behind a strict firewall, or a lossy
/// Wi-Fi at 20 % packet loss.
class CallNetStats {
  const CallNetStats({
    required this.transport,
    required this.candidateType,
    required this.rttMs,
    required this.lossPercent,
    required this.quality,
  });

  /// `udp` or `tcp`; '' when unknown.
  final String transport;

  /// `host`, `srflx`, `prflx` or `relay` (TURN); '' when unknown.
  final String candidateType;
  final int rttMs;
  final double lossPercent;

  /// The connection quality LiveKit last reported for us.
  final LinkQuality quality;

  Map<String, Object?> toJson() => {
    'transport': transport,
    'candidate_type': candidateType,
    'rtt_ms': rttMs,
    'loss_percent': double.parse(lossPercent.toStringAsFixed(2)),
    'quality': quality.name,
  };
}

/// LiveKit implementation (self-hosted server; URL and token come from the
/// Call Service, never from the app config).
class LiveKitCallMedia implements CallMediaSession {
  LiveKitCallMedia({required this.screenShareNotificationTitle, required this.screenShareNotificationText});

  final String screenShareNotificationTitle;
  final String screenShareNotificationText;

  final lk.Room _room = lk.Room(
    roomOptions: const lk.RoomOptions(
      // Only visible tiles receive video; hidden ones are paused (ТЗ п.24.13).
      adaptiveStream: true,
      dynacast: true,
      // 540p at up to 24 fps and 1 Mbit/s from each camera: the university's
      // Wi-Fi carried 720p at 1.7 Mbit/s badly, with everyone's video
      // stuttering. Simulcast still gives small tiles a lighter layer.
      defaultVideoPublishOptions: lk.VideoPublishOptions(
        simulcast: true,
        videoEncoding: lk.VideoEncoding(maxBitrate: 1000 * 1000, maxFramerate: 24),
      ),
      defaultCameraCaptureOptions: lk.CameraCaptureOptions(
        cameraPosition: lk.CameraPosition.front,
        params: lk.VideoParametersPresets.h540_169,
      ),
    ),
  );
  final _changes = StreamController<void>.broadcast();
  final _data = StreamController<CallDataMessage>.broadcast();
  lk.EventsListener<lk.RoomEvent>? _listener;
  MediaConnection _connection = MediaConnection.disconnected;
  bool _front = true;
  bool _speaker = false;
  bool _leaving = false;
  String? _lostReason;

  @override
  Stream<void> get changes => _changes.stream;
  @override
  MediaConnection get connection => _connection;
  @override
  String? get lostReason => _lostReason;
  @override
  bool get frontCamera => _front;
  @override
  bool get speakerOn => _speaker;
  @override
  bool get micOn => _room.localParticipant?.isMicrophoneEnabled() ?? false;
  @override
  bool get cameraOn => _room.localParticipant?.isCameraEnabled() ?? false;
  @override
  bool get screenSharing => _room.localParticipant?.isScreenShareEnabled() ?? false;
  @override
  LinkQuality get quality => _quality(_room.localParticipant?.connectionQuality);

  static LinkQuality _quality(lk.ConnectionQuality? q) => switch (q) {
    lk.ConnectionQuality.lost => LinkQuality.lost,
    lk.ConnectionQuality.poor => LinkQuality.poor,
    lk.ConnectionQuality.good => LinkQuality.good,
    lk.ConnectionQuality.excellent => LinkQuality.excellent,
    _ => LinkQuality.unknown,
  };

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  MediaParticipant _map(lk.Participant p, bool local) => MediaParticipant(
    identity: p.identity,
    name: p.name,
    isLocal: local,
    speaking: p.isSpeaking,
    micOn: p.isMicrophoneEnabled(),
    cameraOn: p.isCameraEnabled(),
    screenSharing: p.isScreenShareEnabled(),
    quality: _quality(p.connectionQuality),
    audioLevel: p.audioLevel.clamp(0, 1).toDouble(),
  );

  @override
  Stream<CallDataMessage> get data => _data.stream;

  @override
  Future<void> sendData(Map<String, Object?> payload) async {
    final local = _room.localParticipant;
    if (local == null || _connection != MediaConnection.connected) return;
    try {
      await local.publishData(utf8.encode(jsonEncode(payload)), reliable: true, topic: callDataTopic);
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'data send failed', error: e);
    }
  }

  // ---- audio processing and traffic saving ----------------------------------

  CallAudioSettings _audio = const CallAudioSettings();
  CallDataSaver _saver = CallDataSaver.off;

  @override
  CallAudioSettings get audioSettings => _audio;
  @override
  CallDataSaver get dataSaver => _saver;
  @override
  bool get backgroundBlurSupported => false;

  lk.AudioCaptureOptions get _captureOptions => _audio.musicMode
      ? const lk.AudioCaptureOptions(
          noiseSuppression: false,
          echoCancellation: false,
          autoGainControl: false,
          highPassFilter: false,
          voiceIsolation: false,
          typingNoiseDetection: false,
        )
      : lk.AudioCaptureOptions(
          noiseSuppression: _audio.noiseSuppression,
          echoCancellation: _audio.echoCancellation,
          autoGainControl: _audio.autoGain,
          voiceIsolation: _audio.noiseSuppression,
          typingNoiseDetection: _audio.noiseSuppression,
        );

  @override
  Future<void> setAudioSettings(CallAudioSettings settings) async {
    if (settings == _audio) return;
    _audio = settings;
    if (_connection == MediaConnection.connected) await _republishMicrophone();
    _emit();
  }

  /// Capture constraints are fixed when a track is created: publish a new
  /// microphone track (music mode also raises the bitrate and turns DTX off).
  Future<void> _republishMicrophone() async {
    final local = _room.localParticipant;
    if (local == null) return;
    try {
      final wasOn = local.isMicrophoneEnabled();
      for (final pub in local.audioTrackPublications.where((p) => p.source == lk.TrackSource.microphone).toList()) {
        await local.removePublishedTrack(pub.sid);
      }
      final track = await lk.LocalAudioTrack.create(_captureOptions);
      await local.publishAudioTrack(
        track,
        publishOptions: _audio.musicMode
            ? const lk.AudioPublishOptions(encoding: lk.AudioEncoding.presetMusicHighQuality, dtx: false, red: false)
            : const lk.AudioPublishOptions(),
      );
      if (!wasOn) await track.mute();
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'microphone republish failed', error: e);
    }
  }

  @override
  Future<void> setDataSaver(CallDataSaver mode) async {
    _saver = mode;
    for (final p in _room.remoteParticipants.values) {
      for (final pub in p.videoTrackPublications) {
        await _applySaver(pub);
      }
    }
    if (mode == CallDataSaver.audioOnly && cameraOn) await setCamera(false);
    _emit();
  }

  Future<void> _applySaver(lk.RemoteTrackPublication pub) async {
    try {
      switch (_saver) {
        case CallDataSaver.audioOnly:
          await pub.disable();
        case CallDataSaver.lowVideo:
          await pub.enable();
          await pub.setVideoQuality(lk.VideoQuality.LOW);
        case CallDataSaver.off:
          await pub.enable();
          await pub.setVideoQuality(lk.VideoQuality.HIGH);
      }
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'data saver apply failed', error: e);
    }
  }

  void _onData(lk.DataReceivedEvent e) {
    if (e.topic != callDataTopic || _data.isClosed) return;
    try {
      final decoded = jsonDecode(utf8.decode(e.data));
      if (decoded is Map) {
        // No participant: sent by the Call Service (chat broadcast, recording).
        _data.add(CallDataMessage(identity: e.participant?.identity ?? '', payload: decoded.cast<String, Object?>()));
      }
    } on FormatException {
      // Not ours (another client on the same topic): ignore.
    }
  }

  @override
  List<MediaParticipant> get participants => [
    if (_room.localParticipant != null) _map(_room.localParticipant!, true),
    for (final p in _room.remoteParticipants.values) _map(p, false),
  ];

  @override
  Future<void> connect(LiveKitAccess access, {required bool video}) async {
    _connection = MediaConnection.connecting;
    _emit();
    _room.addListener(_emit);
    _listener = _room.createListener()
      ..on<lk.RoomReconnectingEvent>((_) {
        _connection = MediaConnection.reconnecting;
        _emit();
      })
      ..on<lk.RoomReconnectedEvent>((_) {
        _connection = MediaConnection.connected;
        _emit();
      })
      ..on<lk.DataReceivedEvent>(_onData)
      ..on<lk.TrackPublishedEvent>((e) {
        final s = e.publication.source;
        if (_saver != CallDataSaver.off && (s == lk.TrackSource.camera || s == lk.TrackSource.screenShareVideo)) {
          unawaited(_applySaver(e.publication));
        }
      })
      ..on<lk.RoomDisconnectedEvent>((e) {
        _connection = MediaConnection.disconnected;
        if (!_leaving) _lostReason = e.reason?.name ?? 'disconnected';
        _emit();
      });
    await _room.connect(access.url, access.token, connectOptions: const lk.ConnectOptions(autoSubscribe: true));
    _connection = MediaConnection.connected;
    await _room.localParticipant?.setMicrophoneEnabled(true, audioCaptureOptions: _captureOptions);
    if (_audio.musicMode) await _republishMicrophone();
    if (_saver == CallDataSaver.audioOnly) video = false;
    if (video) {
      _speaker = true;
      await lk.AudioManager.instance.setSpeakerOutputPreferred(true);
      await _room.localParticipant?.setCameraEnabled(true);
    }
    _emit();
  }

  @override
  Future<CallNetStats?> netStats() async {
    // The subscriber connection carries everyone else's media, which is what
    // a person experiences; the publisher answers when it is the only one.
    // ignore: invalid_use_of_internal_member
    final pc = _room.engine.subscriber?.pc ?? _room.engine.publisher?.pc;
    if (pc == null) return null;
    try {
      final reports = await pc.getStats();
      var selectedPair = '';
      final pairs = <String, Map<dynamic, dynamic>>{};
      final locals = <String, Map<dynamic, dynamic>>{};
      var lost = 0.0;
      var received = 0.0;
      for (final r in reports) {
        switch (r.type) {
          case 'transport':
            selectedPair = (r.values['selectedCandidatePairId'] as String?) ?? selectedPair;
          case 'candidate-pair':
            pairs[r.id] = r.values;
            if (selectedPair.isEmpty && r.values['selected'] == true) selectedPair = r.id;
          case 'local-candidate':
            locals[r.id] = r.values;
          case 'inbound-rtp':
            lost += ((r.values['packetsLost'] as num?) ?? 0).toDouble();
            received += ((r.values['packetsReceived'] as num?) ?? 0).toDouble();
        }
      }
      final pair = pairs[selectedPair];
      final local = pair == null ? null : locals[pair['localCandidateId'] as String? ?? ''];
      final rtt = ((pair?['currentRoundTripTime'] as num?) ?? 0).toDouble() * 1000;
      final total = lost + received;
      return CallNetStats(
        transport: ((local?['protocol'] as String?) ?? '').toLowerCase(),
        candidateType: ((local?['candidateType'] as String?) ?? '').toLowerCase(),
        rttMs: rtt.round(),
        lossPercent: total > 0 ? lost * 100 / total : 0,
        quality: quality,
      );
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'net stats unavailable', error: e);
      return null;
    }
  }

  @override
  Future<void> setMic(bool on) async {
    await _room.localParticipant?.setMicrophoneEnabled(on);
    _emit();
  }

  @override
  Future<void> setCamera(bool on) async {
    await _room.localParticipant?.setCameraEnabled(on);
    _emit();
  }

  @override
  Future<void> switchCamera() async {
    final pub = _room.localParticipant?.videoTrackPublications
        .where((p) => p.source == lk.TrackSource.camera)
        .firstOrNull;
    final track = pub?.track;
    if (track is! lk.LocalVideoTrack) return;
    _front = !_front;
    await track.setCameraPosition(_front ? lk.CameraPosition.front : lk.CameraPosition.back);
    _emit();
  }

  @override
  Future<void> setSpeaker(bool on) async {
    _speaker = on;
    await lk.AudioManager.instance.setSpeakerOutputPreferred(on);
    _emit();
  }

  @override
  Future<bool> setScreenShare(bool on, {String? sourceId}) async {
    final local = _room.localParticipant;
    if (local == null) return false;
    try {
      if (on && Platform.isAndroid) {
        // MediaProjection consent first, then a foreground service of type
        // mediaProjection (Android 14 refuses the service before consent).
        // ignore: experimental_member_use
        if (!await lk.Hardware.instance.requestCapturePermission()) return false;
        final ok = await FlutterBackground.initialize(
          androidConfig: FlutterBackgroundAndroidConfig(
            notificationTitle: screenShareNotificationTitle,
            notificationText: screenShareNotificationText,
            notificationImportance: AndroidNotificationImportance.normal,
            // The plugin otherwise pops the battery-optimisation dialog in
            // the middle of screen sharing and refuses to start the
            // mediaProjection service when it is declined, and Android 14
            // then refuses the capture. The exemption is offered in
            // Settings → Уведомления instead.
            shouldRequestBatteryOptimizationsOff: false,
          ),
        );
        if (ok) await FlutterBackground.enableBackgroundExecution();
      }
      await local.setScreenShareEnabled(
        on,
        // Desktop captures the screen or window the person picked.
        screenShareCaptureOptions: on && sourceId != null
            ? lk.ScreenShareCaptureOptions(sourceId: sourceId, maxFrameRate: 15)
            : null,
      );
      if (!on && Platform.isAndroid && FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
      }
      _emit();
      return true;
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'screen share failed', error: e);
      return false;
    }
  }

  @override
  Future<List<AudioRoute>> audioRoutes() async {
    // Desktop: speakers / headsets by name, as in any conferencing app.
    if (!Platform.isAndroid && !isDesktop) return const [];
    final outputs = await lk.Hardware.instance.audioOutputs();
    return [for (final d in outputs) AudioRoute(id: d.deviceId, label: d.label)];
  }

  @override
  Future<void> selectAudioRoute(AudioRoute route) async {
    final outputs = await lk.Hardware.instance.audioOutputs();
    final device = outputs.where((d) => d.deviceId == route.id).firstOrNull;
    if (device != null) await lk.Hardware.instance.selectAudioOutput(device);
    // Android route ids: speaker / earpiece / wired-headset / bluetooth.
    _speaker = route.id == 'speaker';
    _emit();
  }

  @override
  String? get selectedAudioRouteId => lk.Hardware.instance.selectedAudioOutput?.deviceId;

  String? _inputId;
  @override
  String? get selectedAudioInputId => _inputId;

  @override
  Future<List<AudioRoute>> audioInputs() async {
    if (!Platform.isAndroid && !isDesktop) return const [];
    final inputs = await lk.Hardware.instance.audioInputs();
    return [for (final d in inputs) AudioRoute(id: d.deviceId, label: d.label)];
  }

  @override
  Future<void> selectAudioInput(AudioRoute route) async {
    if (isDesktop) {
      final inputs = await lk.Hardware.instance.audioInputs();
      final device = inputs.where((d) => d.deviceId == route.id).firstOrNull;
      if (device != null) {
        await lk.Hardware.instance.selectAudioInput(device);
        _inputId = route.id;
      }
      _emit();
      return;
    }
    if (!Platform.isAndroid) return;
    // livekit_client switches inputs on desktop only; flutter_webrtc points
    // the Android audio module at the preferred microphone directly.
    try {
      await rtc.Helper.selectAudioInput(route.id);
      _inputId = route.id;
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'select microphone failed', error: e);
    }
    _emit();
  }

  lk.VideoTrack? _track(MediaParticipant p, bool screen) {
    final source = screen ? lk.TrackSource.screenShareVideo : lk.TrackSource.camera;
    final lk.Participant? participant = p.isLocal
        ? _room.localParticipant
        : _room.remoteParticipants[p.identity];
    if (participant == null) return null;
    for (final pub in participant.videoTrackPublications) {
      final track = pub.track;
      if (pub.source == source && !pub.muted && track is lk.VideoTrack) return track;
    }
    return null;
  }

  @override
  Widget videoView(MediaParticipant p, {bool screenShare = false}) {
    final track = _track(p, screenShare);
    if (track == null) return const SizedBox.shrink();
    return lk.VideoTrackRenderer(
      track,
      fit: screenShare ? lk.VideoViewFit.contain : lk.VideoViewFit.cover,
      mirrorMode: p.isLocal && _front && !screenShare ? lk.VideoViewMirrorMode.mirror : lk.VideoViewMirrorMode.off,
    );
  }

  @override
  Future<void> disconnect() async {
    _leaving = true;
    try {
      if (screenSharing && Platform.isAndroid && FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
      }
      await _room.disconnect();
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'disconnect failed', error: e);
    }
    _connection = MediaConnection.disconnected;
    _emit();
  }

  @override
  Future<void> dispose() async {
    await _listener?.dispose();
    _room.removeListener(_emit);
    await _room.dispose();
    await _changes.close();
    await _data.close();
  }
}
