import '../../../shared/utils/api_date.dart';
import 'meetings.dart';

/// Server-side call status (docs/CALLS-API.md §1.1). The server is the only
/// source of truth; the client never sets a status.
enum CallStatus {
  initiating,
  ringing,
  active,
  ended,
  declined,
  missed,
  cancelled,
  busy,
  failed,
  unknown;

  static CallStatus parse(String? v) =>
      CallStatus.values.where((s) => s.name == v).firstOrNull ?? CallStatus.unknown;

  bool get isTerminal => const {ended, declined, missed, cancelled, busy, failed}.contains(this);
  bool get isRinging => this == initiating || this == ringing;
}

/// Per-participant status (§1.2).
enum ParticipantStatus {
  invited,
  ringing,
  accepted,
  joined,
  left,
  declined,
  missed,
  busy,
  removed,
  unknown;

  static ParticipantStatus parse(String? v) =>
      ParticipantStatus.values.where((s) => s.name == v).firstOrNull ??
      ParticipantStatus.unknown;

  bool get isInCall => this == accepted || this == joined;
}

enum CallOutcome {
  answered,
  missed,
  declined,
  cancelled,
  busy,
  failed,
  unknown;

  static CallOutcome parse(String? v) =>
      CallOutcome.values.where((s) => s.name == v).firstOrNull ?? CallOutcome.unknown;
}

class CallParticipantInfo {
  const CallParticipantInfo({
    required this.userId,
    required this.role,
    required this.status,
    this.displayName = '',
    this.email = '',
    this.joinedAt,
    this.leftAt,
  });

  final String userId;
  final String displayName;
  final String email;
  final String role; // host | moderator | participant
  final ParticipantStatus status;
  final DateTime? joinedAt;
  final DateTime? leftAt;

  String get label => displayName.isNotEmpty ? displayName : email;
  bool get isModerator => role == 'host' || role == 'moderator';

  factory CallParticipantInfo.fromJson(Map<String, dynamic> j) => CallParticipantInfo(
    userId: (j['user_id'] as String?) ?? '',
    displayName: (j['display_name'] as String?) ?? '',
    email: (j['email'] as String?) ?? '',
    role: (j['role'] as String?) ?? 'participant',
    status: ParticipantStatus.parse(j['status'] as String?),
    joinedAt: parseApiDate(j['joined_at'] as String?),
    leftAt: parseApiDate(j['left_at'] as String?),
  );
}

/// `recording` of the call JSON (docs/CALLS-API.md §10): the recording that
/// captures the call right now. Every participant sees it (the red «REC»).
class CallRecordingState {
  const CallRecordingState({this.status = 'none', this.enabled = false, this.recordingId, this.startedBy, this.startedAt});

  /// none | starting | active
  final String status;

  /// The call has been recorded at least once.
  final bool enabled;
  final String? recordingId;
  final String? startedBy;
  final DateTime? startedAt;

  static const none = CallRecordingState();

  bool get active => status == 'starting' || status == 'active';

  factory CallRecordingState.fromJson(Object? json) {
    if (json is! Map) return none;
    final j = json.cast<String, dynamic>();
    return CallRecordingState(
      status: (j['status'] as String?) ?? 'none',
      enabled: j['enabled'] == true,
      recordingId: j['recording_id'] as String?,
      startedBy: j['started_by'] as String?,
      startedAt: parseApiDate(j['started_at'] as String?),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CallRecordingState &&
      other.status == status &&
      other.enabled == enabled &&
      other.recordingId == recordingId &&
      other.startedBy == startedBy &&
      other.startedAt == startedAt;

  @override
  int get hashCode => Object.hash(status, enabled, recordingId, startedBy, startedAt);
}

/// Call JSON (§1.4); history rows add `direction` and `outcome`.
class CallInfo {
  CallInfo._(this.raw)
    : id = (raw['id'] as String?) ?? '',
      clientCallId = (raw['client_call_id'] as String?) ?? '',
      type = (raw['type'] as String?) ?? 'audio',
      mode = (raw['mode'] as String?) ?? 'direct',
      status = CallStatus.parse(raw['status'] as String?),
      endReason = (raw['end_reason'] as String?) ?? '',
      conversationId = raw['conversation_id'] as String?,
      title = (raw['title'] as String?) ?? '',
      callerId = (raw['caller_id'] as String?) ?? '',
      createdAt = parseApiDate(raw['created_at'] as String?),
      answeredAt = parseApiDate(raw['answered_at'] as String?),
      endedAt = parseApiDate(raw['ended_at'] as String?),
      durationSec = (raw['duration_sec'] as num?)?.toInt() ?? 0,
      ringDeadline = parseApiDate(raw['ring_deadline'] as String?),
      myRole = (raw['my_role'] as String?) ?? 'participant',
      myStatus = ParticipantStatus.parse(raw['my_status'] as String?),
      direction = (raw['direction'] as String?) ?? '',
      outcome = CallOutcome.parse(raw['outcome'] as String?),
      recording = CallRecordingState.fromJson(raw['recording']),
      meetingId = (raw['meeting_id'] as String?) ?? '',
      participants =((raw['participants'] as List?) ?? const [])
          .map((e) => CallParticipantInfo.fromJson((e as Map).cast<String, dynamic>()))
          .toList();

  factory CallInfo.fromJson(Map<String, dynamic> json) =>
      CallInfo._(Map<String, dynamic>.from(json));

  final Map<String, dynamic> raw;
  final String id;
  final String clientCallId;
  final String type; // audio | video
  final String mode; // direct | group | conference
  final CallStatus status;
  final String endReason;
  final String? conversationId;
  final String title;
  final String callerId;
  final DateTime? createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final int durationSec;
  final DateTime? ringDeadline;
  final String myRole;
  final ParticipantStatus myStatus;
  final String direction; // outgoing | incoming
  final CallOutcome outcome;
  final CallRecordingState recording;

  /// Set for the conference of a scheduled meeting (§12).
  final String meetingId;
  final List<CallParticipantInfo> participants;

  Map<String, dynamic> toJson() => raw;

  bool get isVideo => type == 'video';
  bool get isGroup => mode != 'direct';
  bool get isModerator => myRole == 'host' || myRole == 'moderator';
  bool get isHost => myRole == 'host';

  bool isOutgoingFor(String selfId) =>
      direction.isNotEmpty ? direction == 'outgoing' : callerId == selfId;

  CallParticipantInfo? participant(String userId) =>
      participants.where((p) => p.userId == userId).firstOrNull;

  List<CallParticipantInfo> others(String selfId) =>
      participants.where((p) => p.userId != selfId).toList();

  /// Title for lists and the call screen: group title, or the other side.
  String displayTitle(String selfId) {
    if (title.isNotEmpty) return title;
    final names = others(selfId).map((p) => p.label).where((n) => n.isNotEmpty);
    return names.join(', ');
  }
}

/// `livekit` object of accept/token (§2.2). The JWT is only kept in memory.
class LiveKitAccess {
  const LiveKitAccess({
    required this.url,
    required this.token,
    required this.room,
    required this.identity,
    this.expiresAt,
  });

  final String url;
  final String token;
  final String room;
  final String identity;
  final DateTime? expiresAt;

  factory LiveKitAccess.fromJson(Map<String, dynamic> j) => LiveKitAccess(
    url: (j['url'] as String?) ?? '',
    token: (j['token'] as String?) ?? '',
    room: (j['room'] as String?) ?? '',
    identity: (j['identity'] as String?) ?? '',
    expiresAt: parseApiDate(j['expires_at'] as String?),
  );

  @override
  String toString() => 'LiveKitAccess(room: $room)'; // never the token
}

/// `call.incoming` / `call.status_changed` frame from the chat socket (§3),
/// or the equivalent push data.
class CallSignal {
  const CallSignal({
    required this.type,
    required this.callId,
    this.call,
    this.participantUserId,
    this.participantStatus,
    this.participantDeviceId,
    this.lobby,
  });

  /// `call.lobby` frames: who waits and which guests are in (moderators).
  final CallLobby? lobby;

  final String type;
  final String callId;
  final CallInfo? call;
  final String? participantUserId;
  final ParticipantStatus? participantStatus;
  final String? participantDeviceId;

  bool get isIncoming => type == 'call.incoming';

  static CallSignal? fromFrame(Map<String, dynamic> f) {
    final type = f['type'];
    if (type is! String || !type.startsWith('call.')) return null;
    final callJson = f['call'] is Map ? (f['call'] as Map).cast<String, dynamic>() : null;
    final call = callJson == null ? null : CallInfo.fromJson(callJson);
    final id = (f['call_id'] as String?) ?? call?.id ?? '';
    if (id.isEmpty) return null;
    final p = f['participant'] is Map ? (f['participant'] as Map).cast<String, dynamic>() : null;
    return CallSignal(
      type: type,
      callId: id,
      call: call,
      participantUserId: p?['user_id'] as String?,
      participantStatus: p == null ? null : ParticipantStatus.parse(p['status'] as String?),
      participantDeviceId: p?['device_id'] as String?,
      lobby: type == 'call.lobby' ? CallLobby.fromJson(f) : null,
    );
  }
}
