import '../../../shared/utils/api_date.dart';
import 'call_models.dart';

/// Links of scheduled meetings and guest links (docs/CALLS-API.md §12–§13):
/// `https://…/xatbox/calls/api/v1/meet/<code>` and `xatbox://meet/<code>`.
abstract final class XatBoxMeetingLinks {
  static final _code = RegExp(r'^[a-hjkmnp-z2-9]{3}-[a-hjkmnp-z2-9]{4}-[a-hjkmnp-z2-9]{3}$');
  static final _guest = RegExp(r'^g[a-hjkmnp-z2-9]{32}$');
  static final _inText = RegExp(r'(?:/api/v1/meet/|xatbox://meet/)([a-z0-9-]{12,33})');

  static bool isMeetingCode(String s) => _code.hasMatch(s);
  static bool isGuestToken(String s) => _guest.hasMatch(s);

  /// Meeting code or guest token of a join link; null for anything else.
  static String? codeFromUri(Uri uri) {
    String? last;
    if (uri.scheme == 'xatbox' && uri.host == 'meet') {
      last = uri.pathSegments.where((s) => s.isNotEmpty).firstOrNull;
    } else if (uri.scheme == 'https') {
      final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      final i = segs.lastIndexOf('meet');
      if (i >= 2 && i == segs.length - 2 && segs[i - 1] == 'v1' && segs[i - 2] == 'api') last = segs.last;
    }
    if (last == null) return null;
    return isMeetingCode(last) || isGuestToken(last) ? last : null;
  }

  /// The XatBox meeting code mentioned in an event link or description.
  static String? meetingCodeIn(String text) {
    for (final m in _inText.allMatches(text)) {
      final code = m.group(1)!;
      if (isMeetingCode(code)) return code;
    }
    return null;
  }
}

/// `GET /meetings/{code}` status.
enum MeetingStatus {
  scheduled,
  open,
  live,
  ended,
  cancelled,
  unknown;

  static MeetingStatus parse(String? v) => MeetingStatus.values.where((s) => s.name == v).firstOrNull ?? MeetingStatus.unknown;
}

/// A scheduled meeting as the viewer sees it.
class Meeting {
  const Meeting({
    required this.id,
    required this.code,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.opensAt,
    required this.status,
    this.organizerId = '',
    this.organizerName = '',
    this.inviteeIds = const [],
    this.lobbyEnabled = true,
    this.calendarEventId = '',
    this.callId,
    this.joinUrl = '',
    this.appUrl = '',
    this.myRole = 'none',
    this.canJoin = false,
  });

  final String id;
  final String code;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;

  /// Joining opens here (start − 10 minutes by default).
  final DateTime opensAt;
  final MeetingStatus status;
  final String organizerId;
  final String organizerName;
  final List<String> inviteeIds;
  final bool lobbyEnabled;
  final String calendarEventId;
  final String? callId;
  final String joinUrl;
  final String appUrl;

  /// organizer | invitee | none
  final String myRole;
  final bool canJoin;

  bool get isOrganizer => myRole == 'organizer';
  bool get isLive => status == MeetingStatus.live;

  factory Meeting.fromJson(Map<String, dynamic> j) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final starts = parseApiDate(j['starts_at'] as String?) ?? epoch;
    return Meeting(
      id: (j['id'] as String?) ?? '',
      code: (j['code'] as String?) ?? '',
      title: (j['title'] as String?) ?? '',
      startsAt: starts,
      endsAt: parseApiDate(j['ends_at'] as String?) ?? starts,
      opensAt: parseApiDate(j['opens_at'] as String?) ?? starts.subtract(const Duration(minutes: 10)),
      status: MeetingStatus.parse(j['status'] as String?),
      organizerId: (j['organizer_id'] as String?) ?? '',
      organizerName: (j['organizer_name'] as String?) ?? '',
      inviteeIds: ((j['invitee_ids'] as List?) ?? const []).whereType<String>().toList(),
      lobbyEnabled: j['lobby_enabled'] != false,
      calendarEventId: (j['calendar_event_id'] as String?) ?? '',
      callId: j['call_id'] as String?,
      joinUrl: (j['join_url'] as String?) ?? '',
      appUrl: (j['app_url'] as String?) ?? '',
      myRole: (j['my_role'] as String?) ?? 'none',
      canJoin: j['can_join'] == true,
    );
  }
}

/// A place in a meeting lobby (a colleague who was not invited).
class LobbyTicket {
  const LobbyTicket({required this.id, required this.status});
  final String id;

  /// waiting | admitted | denied
  final String status;

  bool get denied => status == 'denied';

  factory LobbyTicket.fromJson(Map<String, dynamic> j) =>
      LobbyTicket(id: (j['id'] as String?) ?? '', status: (j['status'] as String?) ?? 'waiting');
}

/// `POST /meetings/{code}/join`: the call and a token (200) or a lobby place (202).
class MeetingJoinResult {
  const MeetingJoinResult({required this.meeting, this.call, this.livekit, this.lobby});
  final Meeting meeting;
  final CallInfo? call;
  final LiveKitAccess? livekit;
  final LobbyTicket? lobby;

  bool get joined => call != null && livekit != null;

  factory MeetingJoinResult.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic>? map(String k) => j[k] is Map ? (j[k] as Map).cast<String, dynamic>() : null;
    final call = map('call');
    final lk = map('livekit');
    final lobby = map('lobby');
    return MeetingJoinResult(
      meeting: Meeting.fromJson(map('meeting') ?? const {}),
      call: call == null ? null : CallInfo.fromJson(call),
      livekit: lk == null ? null : LiveKitAccess.fromJson(lk),
      lobby: lobby == null ? null : LobbyTicket.fromJson(lobby),
    );
  }
}

/// A guest link (its URL is returned only when created).
class CallGuestLink {
  const CallGuestLink({
    required this.id,
    required this.url,
    required this.expiresAt,
    this.maxUses = 1,
    this.uses = 0,
    this.requireLobby = true,
    this.allowVideo = true,
    this.allowScreenShare = false,
    this.active = true,
  });

  final String id;
  final String url;
  final DateTime? expiresAt;
  final int maxUses;
  final int uses;
  final bool requireLobby;
  final bool allowVideo;
  final bool allowScreenShare;
  final bool active;

  factory CallGuestLink.fromJson(Map<String, dynamic> j) => CallGuestLink(
    id: (j['id'] as String?) ?? '',
    url: (j['url'] as String?) ?? '',
    expiresAt: parseApiDate(j['expires_at'] as String?),
    maxUses: (j['max_uses'] as num?)?.toInt() ?? 1,
    uses: (j['uses'] as num?)?.toInt() ?? 0,
    requireLobby: j['require_lobby'] != false,
    allowVideo: j['allow_video'] != false,
    allowScreenShare: j['allow_screen_share'] == true,
    active: j['active'] != false,
  );
}

/// LiveKit identity of a guest admitted from the lobby: `guest_<id>#web`.
bool isGuestIdentity(String identity) => identity.startsWith('guest_');

/// Somebody waiting in the lobby, or an admitted guest.
class CallLobbyEntry {
  const CallLobbyEntry({
    required this.id,
    required this.name,
    this.kind = 'guest',
    this.userId,
    this.status = 'waiting',
    this.identity = '',
    this.createdAt,
    this.joinedAt,
  });

  final String id;
  final String name;

  /// guest | staff
  final String kind;
  final String? userId;
  final String status;
  final String identity;
  final DateTime? createdAt;
  final DateTime? joinedAt;

  bool get isGuest => kind == 'guest';

  factory CallLobbyEntry.fromJson(Map<String, dynamic> j) => CallLobbyEntry(
    id: (j['id'] as String?) ?? '',
    name: (j['name'] as String?) ?? '',
    kind: (j['kind'] as String?) ?? 'guest',
    userId: j['user_id'] as String?,
    status: (j['status'] as String?) ?? 'waiting',
    identity: (j['identity'] as String?) ?? '',
    createdAt: parseApiDate(j['created_at'] as String?),
    joinedAt: parseApiDate(j['joined_at'] as String?),
  );
}

/// `GET /calls/{id}/lobby` (also the `call.lobby` socket frame).
class CallLobby {
  const CallLobby({this.waiting = const [], this.guests = const []});
  final List<CallLobbyEntry> waiting;
  final List<CallLobbyEntry> guests;

  static const empty = CallLobby();

  factory CallLobby.fromJson(Map<String, dynamic> j) {
    List<CallLobbyEntry> list(String k) =>
        ((j[k] as List?) ?? const []).whereType<Map>().map((e) => CallLobbyEntry.fromJson(e.cast<String, dynamic>())).toList();
    return CallLobby(waiting: list('waiting'), guests: list('guests'));
  }
}

/// One timed piece of a transcript.
class TranscriptSegment {
  const TranscriptSegment({required this.index, required this.startSec, required this.endSec, required this.text});
  final int index;
  final int startSec;
  final int endSec;
  final String text;

  factory TranscriptSegment.fromJson(Map<String, dynamic> j) => TranscriptSegment(
    index: (j['index'] as num?)?.toInt() ?? 0,
    startSec: (j['start_sec'] as num?)?.toInt() ?? 0,
    endSec: (j['end_sec'] as num?)?.toInt() ?? 0,
    text: (j['text'] as String?) ?? '',
  );
}

/// A sentence picked automatically (keyword frequency), not a summary.
class TranscriptKeyPhrase {
  const TranscriptKeyPhrase({required this.text, required this.startSec});
  final String text;
  final int startSec;

  factory TranscriptKeyPhrase.fromJson(Map<String, dynamic> j) =>
      TranscriptKeyPhrase(text: (j['text'] as String?) ?? '', startSec: (j['start_sec'] as num?)?.toInt() ?? 0);
}

/// `GET /recordings/{id}/transcript`.
class CallTranscript {
  const CallTranscript({
    required this.recordingId,
    required this.status,
    this.callId = '',
    this.language = '',
    this.error = '',
    this.durationSec = 0,
    this.segments = const [],
    this.keyPhrases = const [],
    this.completedAt,
  });

  final String recordingId;
  final String callId;

  /// queued | processing | complete | failed
  final String status;
  final String language;
  final String error;
  final int durationSec;
  final List<TranscriptSegment> segments;
  final List<TranscriptKeyPhrase> keyPhrases;
  final DateTime? completedAt;

  bool get ready => status == 'complete';
  bool get failed => status == 'failed';
  bool get pending => status == 'queued' || status == 'processing';

  String get plainText => segments.map((s) => s.text.trim()).where((t) => t.isNotEmpty).join('\n\n');

  factory CallTranscript.fromJson(Map<String, dynamic> j) => CallTranscript(
    recordingId: (j['recording_id'] as String?) ?? '',
    callId: (j['call_id'] as String?) ?? '',
    status: (j['status'] as String?) ?? '',
    language: (j['language'] as String?) ?? '',
    error: (j['error'] as String?) ?? '',
    durationSec: (j['duration_sec'] as num?)?.toInt() ?? 0,
    completedAt: parseApiDate(j['completed_at'] as String?),
    segments: ((j['segments'] as List?) ?? const []).whereType<Map>().map((e) => TranscriptSegment.fromJson(e.cast<String, dynamic>())).toList(),
    keyPhrases:
        ((j['key_phrases'] as List?) ?? const []).whereType<Map>().map((e) => TranscriptKeyPhrase.fromJson(e.cast<String, dynamic>())).toList(),
  );
}

/// Traffic saving during a call.
enum CallDataSaver {
  /// Full quality.
  off,

  /// Receive the lowest simulcast layer of other people's video.
  lowVideo,

  /// No video received or sent: audio only.
  audioOnly;

  static CallDataSaver parse(String? v) => CallDataSaver.values.where((s) => s.name == v).firstOrNull ?? CallDataSaver.off;
}

/// Audio processing and traffic saving together (persisted per device).
class CallQualitySettings {
  const CallQualitySettings({this.audio = const CallAudioSettings(), this.dataSaver = CallDataSaver.off});
  final CallAudioSettings audio;
  final CallDataSaver dataSaver;

  CallQualitySettings copyWith({CallAudioSettings? audio, CallDataSaver? dataSaver}) =>
      CallQualitySettings(audio: audio ?? this.audio, dataSaver: dataSaver ?? this.dataSaver);

  @override
  bool operator ==(Object other) => other is CallQualitySettings && other.audio == audio && other.dataSaver == dataSaver;

  @override
  int get hashCode => Object.hash(audio, dataSaver);
}

/// Microphone processing (livekit AudioCaptureOptions). Music mode switches
/// every voice filter off and sends high-bitrate audio.
class CallAudioSettings {
  const CallAudioSettings({
    this.noiseSuppression = true,
    this.echoCancellation = true,
    this.autoGain = true,
    this.musicMode = false,
  });

  final bool noiseSuppression;
  final bool echoCancellation;
  final bool autoGain;
  final bool musicMode;

  CallAudioSettings copyWith({bool? noiseSuppression, bool? echoCancellation, bool? autoGain, bool? musicMode}) => CallAudioSettings(
    noiseSuppression: noiseSuppression ?? this.noiseSuppression,
    echoCancellation: echoCancellation ?? this.echoCancellation,
    autoGain: autoGain ?? this.autoGain,
    musicMode: musicMode ?? this.musicMode,
  );

  Map<String, Object?> toJson() => {
    'noise_suppression': noiseSuppression,
    'echo_cancellation': echoCancellation,
    'auto_gain': autoGain,
    'music_mode': musicMode,
  };

  factory CallAudioSettings.fromJson(Map<String, dynamic> j) => CallAudioSettings(
    noiseSuppression: j['noise_suppression'] != false,
    echoCancellation: j['echo_cancellation'] != false,
    autoGain: j['auto_gain'] != false,
    musicMode: j['music_mode'] == true,
  );

  @override
  bool operator ==(Object other) =>
      other is CallAudioSettings &&
      other.noiseSuppression == noiseSuppression &&
      other.echoCancellation == echoCancellation &&
      other.autoGain == autoGain &&
      other.musicMode == musicMode;

  @override
  int get hashCode => Object.hash(noiseSuppression, echoCancellation, autoGain, musicMode);
}
