import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:xatbox_mobile/features/calls/data/call_media.dart';
import 'package:xatbox_mobile/features/calls/data/call_models.dart';
import 'package:xatbox_mobile/features/calls/data/call_native.dart';
import 'package:xatbox_mobile/features/calls/data/call_pip.dart';
import 'package:xatbox_mobile/features/calls/data/call_preview.dart';
import 'package:xatbox_mobile/features/calls/data/call_sounds.dart';
import 'package:xatbox_mobile/features/calls/data/meetings.dart';

import 'fake_http.dart';

/// Camera preview of the pre-join screen without a camera.
class FakeCameraPreview implements CallCameraPreview {
  bool running = false;
  int starts = 0;
  bool available = true;

  /// `start` / `stop` in order (diagnostics).
  final List<String> events = [];

  @override
  Future<bool> start() async {
    starts++;
    events.add('start');
    running = available;
    return available;
  }

  @override
  Future<void> stop() async {
    events.add('stop');
    running = false;
  }

  @override
  Widget view() => const SizedBox.expand(key: ValueKey('fake_camera_preview'));

  @override
  Future<String?> microphoneLabel() async => 'Встроенный микрофон';

  @override
  Future<String?> cameraLabel() async => 'Фронтальная камера';
}

/// Records tone requests (`play:ringback`, `stop`, …).
class FakeCallSounds implements CallSounds {
  final List<String> events = [];
  CallTone? playing;

  @override
  Future<void> play(CallTone tone) async {
    events.add('play:${tone.name}');
    playing = tone;
  }

  @override
  Future<void> stop() async {
    events.add('stop');
    playing = null;
  }

  @override
  Future<void> dispose() async => playing = null;
}

/// PiP stand-in: records auto-enter requests; the test drives mode changes.
class FakeCallPip implements CallPip {
  final modes = StreamController<bool>.broadcast();
  final List<bool> autoEnter = [];
  bool supported = true;
  int enterCalls = 0;

  @override
  Future<bool> isSupported() async => supported;
  @override
  Future<bool> enter() async {
    enterCalls++;
    return supported;
  }

  @override
  Future<void> setAutoEnter(bool enabled) async => autoEnter.add(enabled);
  @override
  Stream<bool> get modeChanges => modes.stream;
}

/// System call UI stand-in: records what the app asked the OS to show.
class FakeCallNative implements CallNative {
  final actionsController = StreamController<NativeCallAction>.broadcast();
  final List<String> shownIncoming = [];
  final List<String> outgoing = [];
  final List<String> connectedIds = [];
  final List<String> hiddenIncoming = [];
  final List<String> ended = [];
  final List<String> accepted = [];
  MediaPermission permission = MediaPermission.granted;
  bool screenOn = false;

  @override
  Stream<NativeCallAction> get actions => actionsController.stream;
  @override
  Stream<void> get voipTokenUpdates => const Stream.empty();
  @override
  Future<String?> voipToken() async => null;

  @override
  Future<void> showIncoming({required String callId, required String callerName, required bool video, required Duration ringFor}) async =>
      shownIncoming.add(callId);
  @override
  Future<void> startOutgoing({required String callId, required String title, required bool video}) async => outgoing.add(callId);
  @override
  Future<void> connected(String callId) async => connectedIds.add(callId);
  @override
  Future<void> hideIncoming(String callId) async => hiddenIncoming.add(callId);
  @override
  Future<void> end(String callId) async => ended.add(callId);
  @override
  Future<List<String>> acceptedCallIds() async => List.of(accepted);
  @override
  Future<MediaPermission> ensurePermissions({required bool video}) async => permission;
  @override
  Future<void> requestIncomingCallPermissions() async {}
  @override
  Future<void> openSettings() async {}
  @override
  Future<void> keepScreenOn(bool on) async => screenOn = on;
}

/// Media session stand-in the test drives (remote joins, reconnects…).
class FakeCallMedia implements CallMediaSession {
  final _changes = StreamController<void>.broadcast();
  LiveKitAccess? connectedWith;
  bool connectedVideo = false;
  bool disconnected = false;
  final List<MediaParticipant> remote = [];
  @override
  Future<CallNetStats?> netStats() async => null;

  @override
  MediaConnection connection = MediaConnection.disconnected;
  @override
  bool micOn = true;
  @override
  bool cameraOn = false;
  @override
  bool frontCamera = true;
  @override
  bool speakerOn = false;
  @override
  bool screenSharing = false;
  @override
  String? lostReason;
  @override
  LinkQuality quality = LinkQuality.good;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  List<MediaParticipant> get participants => [
    MediaParticipant(identity: 'me#dev', name: 'me', isLocal: true, micOn: micOn, cameraOn: cameraOn),
    ...remote,
  ];

  void emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void join(String userId, {bool speaking = false, LinkQuality quality = LinkQuality.good, bool cameraOn = false}) {
    remote.add(
      MediaParticipant(
        identity: '$userId#d1',
        name: userId,
        isLocal: false,
        micOn: true,
        speaking: speaking,
        quality: quality,
        cameraOn: cameraOn,
      ),
    );
    emit();
  }

  void setConnection(MediaConnection c) {
    connection = c;
    emit();
  }

  @override
  Future<void> connect(LiveKitAccess access, {required bool video}) async {
    connectedWith = access;
    connectedVideo = video;
    cameraOn = video;
    connection = MediaConnection.connected;
    emit();
  }

  @override
  Future<void> setMic(bool on) async {
    micOn = on;
    emit();
  }

  /// Thrown when the camera is turned on (no camera / capturer failure).
  Object? cameraError;

  @override
  Future<void> setCamera(bool on) async {
    if (on && cameraError != null) throw cameraError!;
    cameraOn = on;
    emit();
  }

  @override
  Future<void> switchCamera() async => frontCamera = !frontCamera;
  @override
  Future<void> setSpeaker(bool on) async => speakerOn = on;
  @override
  Future<bool> setScreenShare(bool on, {String? sourceId}) async => screenSharing = on;
  List<AudioRoute> outputs = const [];
  List<AudioRoute> inputs = const [];
  @override
  String? selectedAudioRouteId;
  @override
  String? selectedAudioInputId;
  @override
  Future<List<AudioRoute>> audioRoutes() async => outputs;
  @override
  Future<void> selectAudioRoute(AudioRoute route) async => selectedAudioRouteId = route.id;
  @override
  Future<List<AudioRoute>> audioInputs() async => inputs;
  @override
  Future<void> selectAudioInput(AudioRoute route) async => selectedAudioInputId = route.id;
  @override
  Widget videoView(MediaParticipant p, {bool screenShare = false}) =>
      SizedBox(key: ValueKey('video_${p.identity}'));

  final _data = StreamController<CallDataMessage>.broadcast();

  /// Data messages this session sent (raise hand, reactions).
  final List<Map<String, Object?>> sentData = [];

  @override
  Stream<CallDataMessage> get data => _data.stream;

  @override
  Future<void> sendData(Map<String, Object?> payload) async => sentData.add(payload);

  @override
  CallAudioSettings audioSettings = const CallAudioSettings();
  @override
  Future<void> setAudioSettings(CallAudioSettings settings) async {
    audioSettings = settings;
    emit();
  }

  @override
  CallDataSaver dataSaver = CallDataSaver.off;
  @override
  Future<void> setDataSaver(CallDataSaver mode) async {
    dataSaver = mode;
    if (mode == CallDataSaver.audioOnly) cameraOn = false;
    emit();
  }

  @override
  bool get backgroundBlurSupported => false;

  /// The network got worse / better.
  void setQuality(LinkQuality q) {
    quality = q;
    emit();
  }

  /// A remote participant sends a data message.
  void receive(String identity, Map<String, Object?> payload) {
    if (!_data.isClosed) _data.add(CallDataMessage(identity: identity, payload: payload));
  }

  /// Updates a remote participant (speaking, camera, …).
  void update(String identity, MediaParticipant Function(MediaParticipant p) change) {
    final i = remote.indexWhere((p) => p.identity == identity);
    if (i < 0) return;
    remote[i] = change(remote[i]);
    emit();
  }

  @override
  Future<void> disconnect() async {
    disconnected = true;
    connection = MediaConnection.disconnected;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    unawaited(_changes.close());
    unawaited(_data.close());
  }

  bool disposed = false;
}

/// In-memory Call Service following docs/CALLS-API.md: idempotent create by
/// client_call_id, ringing ack, accept/token with a livekit object, reject /
/// cancel / end, history and missed count.
class FakeCallServer {
  FakeCallServer(this.http, {required this.selfId, required this.selfName}) {
    _routes();
  }

  final FakeHttpAdapter http;
  final String selfId;
  final String selfName;
  final Map<String, Map<String, dynamic>> calls = {};
  final Map<String, String> byClientId = {};
  int createPosts = 0;
  int offlineCreates = 0;
  int missed = 0;
  final List<String> ringingDevices = [];

  /// `GET /calls/config` body; null answers 404 (older server).
  Map<String, dynamic>? config;

  /// Error code (and status) for `POST /calls/{id}/invite`; null = success.
  String? inviteError;
  int inviteErrorStatus = 403;
  var _n = 0;

  /// In-call chat of ad-hoc calls: `GET/POST /calls/{id}/messages`.
  final Map<String, List<Map<String, dynamic>>> messages = {};

  /// `GET /calls/{id}/recordings` items per call.
  final Map<String, List<Map<String, dynamic>>> recordings = {};

  /// Body of `GET /recordings/{id}/download`.
  final Map<String, String> downloads = {};

  /// Error code for recording start/stop (503 by default); null = success.
  String? recordingError;
  int recordingErrorStatus = 503;

  static Map<String, dynamic> recordingItem(String id, String callId, {String status = 'complete', String type = 'video'}) => {
    'id': id,
    'call_id': callId,
    'status': status,
    'type': type,
    'started_by': 'u-bob',
    'started_by_name': 'Болат',
    'started_at': '2026-09-15T10:30:00Z',
    'ended_at': status == 'complete' ? '2026-09-15T10:35:42Z' : null,
    'duration_sec': status == 'complete' ? 342 : 0,
    'size_bytes': status == 'complete' ? 13 * 1024 * 1024 : 0,
    'content_type': type == 'audio' ? 'audio/ogg' : 'video/mp4',
    'filename': 'call-2026-09-15-1030.${type == 'audio' ? 'ogg' : 'mp4'}',
    'download_path': '/recordings/$id/download',
  };

  static Map<String, dynamic> livekit(String id) => {
    'url': 'wss://rtc.test',
    'token': 'lk-jwt-$id',
    'room': 'org:$id',
    'identity': 'me#dev',
    'expires_at': '2030-01-01T00:00:00Z',
  };

  Map<String, dynamic> callJson({
    required String id,
    required String callerId,
    required List<(String, String)> others,
    String status = 'ringing',
    String type = 'audio',
    String mode = 'direct',
    String direction = '',
    String outcome = '',
  }) => {
    'id': id,
    'client_call_id': 'c-$id',
    'type': type,
    'mode': mode,
    'status': status,
    'end_reason': '',
    'title': '',
    'caller_id': callerId,
    'created_at': '2026-09-14T06:00:00Z',
    'ring_deadline': DateTime.now().toUtc().add(const Duration(seconds: 45)).toIso8601String(),
    'my_role': callerId == selfId ? 'host' : 'participant',
    'my_status': callerId == selfId ? 'accepted' : 'invited',
    'duration_sec': 0,
    'direction': ?(direction.isEmpty ? null : direction),
    'outcome': ?(outcome.isEmpty ? null : outcome),
    'participants': [
      {'user_id': selfId, 'display_name': selfName, 'role': callerId == selfId ? 'host' : 'participant', 'status': callerId == selfId ? 'accepted' : 'invited'},
      for (final (uid, name) in others)
        {'user_id': uid, 'display_name': name, 'role': uid == callerId ? 'host' : 'participant', 'status': uid == callerId ? 'accepted' : 'invited'},
    ],
  };

  String addIncoming({required String callerId, required String callerName, String type = 'audio'}) {
    final id = 'call-in-${++_n}';
    calls[id] = callJson(id: id, callerId: callerId, others: [(callerId, callerName)], type: type);
    return id;
  }

  void setStatus(String id, String status) => calls[id]!['status'] = status;

  // ---- meetings, lobby, guest links, transcripts (docs/CALLS-API.md §12–§14) ----

  /// Meetings by code.
  final Map<String, Map<String, dynamic>> meetings = {};

  /// Bodies of `POST /meetings`.
  final List<Map<String, dynamic>> createdMeetings = [];

  /// `POST /meetings/{code}/join` answers 202 (lobby) this many times first.
  int meetingLobbyPolls = 0;

  /// Error code for joins; null = success.
  String? meetingJoinError;
  int meetingJoinErrorStatus = 409;

  /// `GET /calls/{id}/lobby` bodies.
  final Map<String, Map<String, dynamic>> lobbies = {};
  final List<String> lobbyDecisions = [];
  final List<Map<String, dynamic>> guestLinkBodies = [];

  /// `GET /recordings/{id}/transcript` bodies.
  final Map<String, Map<String, dynamic>> transcripts = {};

  static const meetingCodes = ['abc-defg-hjk', 'bcd-efgh-jkm', 'cde-fghj-kmn', 'def-ghjk-mnp'];

  static Map<String, dynamic> meetingJson({
    required String code,
    String title = 'Учёный совет',
    required DateTime startsAt,
    Duration length = const Duration(hours: 1),
    String status = 'open',
    bool canJoin = true,
    String myRole = 'invitee',
    String? callId,
  }) => {
    'id': 'm-$code',
    'code': code,
    'title': title,
    'starts_at': startsAt.toUtc().toIso8601String(),
    'ends_at': startsAt.add(length).toUtc().toIso8601String(),
    'opens_at': startsAt.subtract(const Duration(minutes: 10)).toUtc().toIso8601String(),
    'organizer_id': 'u-org',
    'organizer_name': 'Айгерим Садыкова',
    'invitee_ids': <String>[],
    'lobby_enabled': true,
    'calendar_event_id': '',
    'status': status,
    'call_id': callId,
    'join_url': 'https://mail.test/xatbox/calls/api/v1/meet/$code',
    'app_url': 'xatbox://meet/$code',
    'my_role': myRole,
    'can_join': canJoin,
    'created_at': '2026-09-15T08:00:00Z',
  };

  static Map<String, dynamic> transcriptJson(String recordingId, String callId) => {
    'recording_id': recordingId,
    'call_id': callId,
    'status': 'complete',
    'language': 'auto',
    'error': '',
    'created_at': '2026-09-15T10:40:00Z',
    'completed_at': '2026-09-15T10:45:00Z',
    'duration_sec': 912,
    'segments': [
      {'index': 0, 'start_sec': 0, 'end_sec': 600, 'text': 'Коллеги, обсуждаем бюджет кафедры на весну. Бюджет кафедры нужно согласовать.'},
      {'index': 1, 'start_sec': 600, 'end_sec': 912, 'text': 'Расписание экзаменов пришлём отдельно. Протокол будет вечером.'},
    ],
    'key_phrases': [
      {'text': 'Бюджет кафедры нужно согласовать.', 'start_sec': 0, 'score': 1.2},
    ],
    'key_phrases_method': 'extractive-keyword-frequency',
  };

  void _meetingRoutes() {
    http.on('POST', '/meetings', (r) {
      final body = r.json;
      createdMeetings.add(body);
      final code = meetingCodes[createdMeetings.length % meetingCodes.length];
      meetings[code] = meetingJson(
        code: code,
        title: body['title'] as String,
        startsAt: DateTime.parse(body['starts_at'] as String),
        length: DateTime.parse(body['ends_at'] as String).difference(DateTime.parse(body['starts_at'] as String)),
        status: 'scheduled',
        canJoin: false,
        myRole: 'organizer',
      )..['invitee_ids'] = body['invitee_ids'];
      return FakeResponse(201, json: {'meeting': meetings[code]});
    });
    http.on('GET', '/meetings', (_) => FakeResponse(200, json: {'meetings': meetings.values.toList()}));
    http.onPattern('GET', r'^/meetings/[^/]+$', (r) {
      final m = meetings[r.path.split('/').last];
      return m == null ? FakeResponse.error(404, 'MEETING_NOT_FOUND') : FakeResponse(200, json: {'meeting': m});
    });
    http.onPattern('PATCH', r'^/meetings/[^/]+$', (r) {
      final m = meetings[r.path.split('/').last];
      if (m == null) return FakeResponse.error(404, 'MEETING_NOT_FOUND');
      m.addAll(r.json);
      return FakeResponse(200, json: {'meeting': m});
    });
    http.onPattern('POST', r'^/meetings/[^/]+/join$', (r) {
      final code = r.path.split('/')[2];
      final m = meetings[code];
      if (m == null) return FakeResponse.error(404, 'MEETING_NOT_FOUND');
      if (meetingJoinError != null) return FakeResponse.error(meetingJoinErrorStatus, meetingJoinError!);
      if (meetingLobbyPolls > 0) {
        meetingLobbyPolls--;
        return FakeResponse(202, json: {'meeting': m, 'lobby': {'id': 'lobby-1', 'status': 'waiting'}});
      }
      final id = (m['call_id'] as String?) ?? 'call-meet-${++_n}';
      calls[id] ??= callJson(id: id, callerId: selfId, others: const [], type: 'video', mode: 'conference', status: 'active')
        ..['title'] = m['title']
        ..['meeting_id'] = m['id']
        ..['my_role'] = 'moderator';
      m['call_id'] = id;
      m['status'] = 'live';
      return FakeResponse(200, json: {'meeting': m, 'call': calls[id], 'livekit': livekit(id)});
    });
    http.onPattern('GET', r'^/calls/[^/]+/lobby$', (r) {
      final id = r.path.split('/')[2];
      return FakeResponse(200, json: lobbies[id] ?? {'waiting': <Object>[], 'guests': <Object>[]});
    });
    http.onPattern('POST', r'^/calls/[^/]+/lobby/[^/]+/(admit|deny)$', (r) {
      final parts = r.path.split('/');
      final id = parts[2];
      final entry = parts[4];
      final admit = parts[5] == 'admit';
      lobbyDecisions.add('${parts[5]}:$entry');
      final lobby = lobbies[id];
      if (lobby != null) {
        final waiting = List<Map<String, dynamic>>.from((lobby['waiting'] as List).cast<Map<String, dynamic>>());
        final hit = waiting.where((e) => e['id'] == entry).firstOrNull;
        waiting.removeWhere((e) => e['id'] == entry);
        lobby['waiting'] = waiting;
        if (admit && hit != null) {
          lobby['guests'] = [...(lobby['guests'] as List), {...hit, 'status': 'admitted'}];
        }
      }
      return FakeResponse(200, json: {'entry': {'id': entry, 'status': admit ? 'admitted' : 'denied'}});
    });
    http.onPattern('POST', r'^/calls/[^/]+/guests/[^/]+/remove$', (r) {
      lobbyDecisions.add('remove:${r.path.split('/')[4]}');
      return const FakeResponse(204);
    });
    http.onPattern('POST', r'^/calls/[^/]+/guest-links$', (r) {
      guestLinkBodies.add(r.json);
      return FakeResponse(201, json: {
        'link': {
          'id': 'link-${guestLinkBodies.length}',
          'url': 'https://mail.test/xatbox/calls/api/v1/meet/g${'k' * 32}',
          'expires_at': DateTime.now().toUtc().add(Duration(minutes: r.json['expires_in_minutes'] as int)).toIso8601String(),
          'max_uses': r.json['max_uses'],
          'uses': 0,
          'require_lobby': r.json['require_lobby'],
          'allow_video': true,
          'allow_screen_share': r.json['allow_screen_share'],
          'active': true,
        },
      });
    });
    http.onPattern('GET', r'^/recordings/[^/]+/transcript$', (r) {
      final t = transcripts[r.path.split('/')[2]];
      return t == null ? FakeResponse.error(404, 'TRANSCRIPT_NOT_FOUND') : FakeResponse(200, json: {'transcript': t});
    });
    http.onPattern('POST', r'^/recordings/[^/]+/transcript/retry$', (r) {
      final t = transcripts[r.path.split('/')[2]];
      if (t == null) return FakeResponse.error(404, 'TRANSCRIPT_NOT_FOUND');
      t['status'] = 'queued';
      return FakeResponse(202, json: {'transcript': t});
    });
  }

  void _routes() {
    _meetingRoutes();
    http.on('POST', '/calls', (r) {
      if (offlineCreates > 0) {
        offlineCreates--;
        throw const SocketException('offline');
      }
      final body = r.json;
      createPosts++;
      final existing = byClientId[body['client_call_id']];
      if (existing != null) return FakeResponse(200, json: calls[existing]);
      final id = 'call-out-${++_n}';
      byClientId[body['client_call_id'] as String] = id;
      final callees = (body['callee_ids'] as List).cast<String>();
      calls[id] = callJson(
        id: id,
        callerId: selfId,
        others: [for (final c in callees) (c, 'User $c')],
        type: body['type'] as String,
        mode: (body['mode'] as String?) ?? (callees.length == 1 ? 'direct' : 'group'),
      );
      calls[id]!['conversation_id'] = body['conversation_id'];
      return FakeResponse(201, json: calls[id]);
    });
    http.onPattern('GET', r'^/calls/[^/]+/messages$', (r) {
      final id = r.path.split('/')[2];
      return FakeResponse(200, json: {'messages': messages[id] ?? const [], 'next_cursor': ''});
    });
    http.onPattern('GET', r'^/calls/[^/]+/recordings$', (r) {
      final id = r.path.split('/')[2];
      if (calls[id] == null) return FakeResponse.error(404, 'CALL_NOT_FOUND');
      return FakeResponse(200, json: {'recordings': recordings[id] ?? const []});
    });
    http.onPattern('POST', r'^/calls/[^/]+/recording/(start|stop)$', (r) {
      final parts = r.path.split('/');
      final id = parts[2];
      final c = calls[id];
      if (c == null) return FakeResponse.error(404, 'CALL_NOT_FOUND');
      if (recordingError != null) return FakeResponse.error(recordingErrorStatus, recordingError!);
      final start = parts[4] == 'start';
      final recId = 'rec-${++_n}';
      c['recording'] = start
          ? {'enabled': true, 'status': 'active', 'recording_id': recId, 'started_by': selfId, 'started_at': DateTime.now().toUtc().toIso8601String()}
          : {'enabled': true, 'status': 'none', 'recording_id': null, 'started_by': null, 'started_at': null};
      return FakeResponse(start ? 201 : 200, json: {'recording': recordingItem(recId, id, status: start ? 'starting' : 'active'), 'call': c});
    });
    http.onPattern('GET', r'^/recordings/[^/]+/download$', (r) {
      final body = downloads[r.path.split('/')[2]];
      return body == null ? FakeResponse.error(404, 'RECORDING_NOT_FOUND') : FakeResponse(200, text: body, contentType: 'video/mp4');
    });
    http.onJson('GET', '/calls/active', {'calls': <Object>[]});
    http.on(
      'GET',
      '/calls/config',
      (_) => config == null ? FakeResponse.error(404, 'NOT_FOUND') : FakeResponse(200, json: config),
    );
    http.on('GET', '/calls/missed/count', (_) => FakeResponse(200, json: {'count': missed}));
    http.on('POST', '/calls/missed/seen', (_) {
      missed = 0;
      return const FakeResponse(204);
    });
    http.on('GET', '/calls', (r) {
      final onlyMissed = r.query['filter'] == 'missed';
      final list = calls.values.where((c) => !onlyMissed || c['outcome'] == 'missed').toList();
      return FakeResponse(200, json: {'calls': list, 'next_cursor': ''});
    });
    http.onPattern('GET', r'^/calls/[^/]+$', (r) {
      final c = calls[r.path.split('/').last];
      return c == null ? FakeResponse.error(404, 'CALL_NOT_FOUND') : FakeResponse(200, json: c);
    });
    http.onPattern('POST', r'^/calls/[^/]+/[a-z]+$', (r) {
      final parts = r.path.split('/');
      final id = parts[2];
      final action = parts[3];
      final c = calls[id];
      if (c == null) return FakeResponse.error(404, 'CALL_NOT_FOUND');
      switch (action) {
        case 'ringing':
          ringingDevices.add(r.json['device_id'] as String);
          return const FakeResponse(204);
        case 'accept':
          if (c['status'] != 'ringing') return FakeResponse.error(409, 'CALL_NOT_RINGING');
          c['my_status'] = 'accepted';
          return FakeResponse(200, json: {'call': c, 'livekit': livekit(id)});
        case 'token':
          return FakeResponse(200, json: {'livekit': livekit(id)});
        case 'reject':
          c['status'] = 'declined';
          return FakeResponse(200, json: {'call': c});
        case 'cancel':
          c['status'] = 'cancelled';
          return FakeResponse(200, json: {'call': c});
        case 'end':
          c['status'] = 'ended';
          return FakeResponse(200, json: {'call': c});
        case 'messages':
          final body = r.json;
          final list = messages.putIfAbsent(id, () => []);
          final existing = list.where((m) => m['client_message_id'] == body['client_message_id']).firstOrNull;
          if (existing != null) return FakeResponse(200, json: {'message': existing});
          final message = {
            'id': 'srv-${++_n}',
            'call_id': id,
            'client_message_id': body['client_message_id'],
            'sender_id': selfId,
            'sender_name': selfName,
            'body': (body['body'] as String).trim(),
            'created_at': DateTime.now().toUtc().toIso8601String(),
          };
          list.add(message);
          return FakeResponse(201, json: {'message': message});
        case 'invite':
          if (inviteError != null) return FakeResponse.error(inviteErrorStatus, inviteError!);
          final participants = List<Object?>.of(c['participants'] as List);
          for (final uid in (r.json['user_ids'] as List).cast<String>()) {
            if (participants.any((p) => (p as Map)['user_id'] == uid)) continue;
            participants.add(<String, Object?>{'user_id': uid, 'display_name': 'User $uid', 'role': 'participant', 'status': 'invited'});
          }
          c['participants'] = participants;
          return FakeResponse(200, json: {'call': c});
      }
      return FakeResponse.error(404, 'NOT_FOUND');
    });
  }
}
