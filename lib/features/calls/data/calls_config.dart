/// `GET /calls/config`: server limits the client adapts to without a new
/// build (video tiles per page, ring timeout, participant limits, whether
/// calls can be recorded).
class CallsConfig {
  const CallsConfig({
    this.maxVideoTiles = defaultMaxVideoTiles,
    this.ringTimeoutSec = defaultRingTimeoutSec,
    this.maxGroup = defaultMaxGroup,
    this.maxConference = defaultMaxConference,
    this.recordingEnabled = false,
    this.transcriptionEnabled = false,
    this.guestsEnabled = false,
    this.meetingJoinEarlySec = defaultMeetingJoinEarlySec,
  });

  static const defaultMeetingJoinEarlySec = 600;

  /// `transcription_enabled`: finished recordings get a transcript.
  final bool transcriptionEnabled;

  /// `guests_enabled`: moderators can invite people without an account.
  final bool guestsEnabled;

  /// `meeting_join_early_sec`: a meeting opens this long before its start.
  final int meetingJoinEarlySec;

  static const defaultMaxVideoTiles = 9;
  static const minVideoTiles = 4;
  static const maxVideoTilesLimit = 16;
  static const defaultRingTimeoutSec = 45;
  static const defaultMaxGroup = 50;
  static const defaultMaxConference = 150;

  final int maxVideoTiles;
  final int ringTimeoutSec;
  final int maxGroup;
  final int maxConference;

  /// `recording_enabled` (CALL_RECORDING_ENABLED): «Записать» and the call
  /// card recordings are shown only when true. Older servers: false.
  final bool recordingEnabled;

  /// Missing, mistyped or out-of-contract values fall back to the defaults
  /// (`max_video_tiles` must be 4..16).
  factory CallsConfig.fromJson(Map<String, dynamic> json) {
    int? positive(String key) {
      final v = json[key];
      if (v is! num) return null;
      final i = v.toInt();
      return i > 0 && i == v ? i : null;
    }

    final tiles = positive('max_video_tiles');
    return CallsConfig(
      maxVideoTiles: tiles != null && tiles >= minVideoTiles && tiles <= maxVideoTilesLimit ? tiles : defaultMaxVideoTiles,
      ringTimeoutSec: positive('ring_timeout_sec') ?? defaultRingTimeoutSec,
      maxGroup: positive('max_group') ?? defaultMaxGroup,
      maxConference: positive('max_conference') ?? defaultMaxConference,
      recordingEnabled: json['recording_enabled'] == true,
      transcriptionEnabled: json['transcription_enabled'] == true,
      guestsEnabled: json['guests_enabled'] == true,
      meetingJoinEarlySec: positive('meeting_join_early_sec') ?? defaultMeetingJoinEarlySec,
    );
  }

  Map<String, dynamic> toJson() => {
    'max_video_tiles': maxVideoTiles,
    'ring_timeout_sec': ringTimeoutSec,
    'max_group': maxGroup,
    'max_conference': maxConference,
    'recording_enabled': recordingEnabled,
    'transcription_enabled': transcriptionEnabled,
    'guests_enabled': guestsEnabled,
    'meeting_join_early_sec': meetingJoinEarlySec,
  };

  /// Participant limit of a call of [mode].
  int limitFor(String mode) => mode == 'conference' ? maxConference : maxGroup;
}
