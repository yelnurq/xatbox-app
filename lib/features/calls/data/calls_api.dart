import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import 'call_chat.dart';
import 'call_media.dart';
import 'call_models.dart';
import 'calls_config.dart';
import 'meetings.dart';

/// REST client of the Call Service (docs/CALLS-API.md §2). Same bearer token
/// and the same global 401 → sign-out as every other module.
class CallsApi {
  CallsApi(this._client);
  final ApiClient _client;

  static String _id(String id) => Uri.encodeComponent(id);

  CallInfo _call(Map<String, dynamic> json) => CallInfo.fromJson(
    json['call'] is Map ? (json['call'] as Map).cast<String, dynamic>() : json,
  );

  /// 201 new / 200 idempotent replay of the same [clientCallId].
  Future<CallInfo> create({
    required String clientCallId,
    required String type,
    required List<String> calleeIds,
    String? mode,
    String? conversationId,
    String? title,
  }) async => _call(
    await _client.postJson(
      '/calls',
      body: {
        'client_call_id': clientCallId,
        'type': type,
        'mode': ?mode,
        'callee_ids': calleeIds,
        'conversation_id': ?conversationId,
        if (title != null && title.isNotEmpty) 'title': title,
      },
      expectedStatuses: const {200, 201},
    ),
  );

  Future<({List<CallInfo> calls, String nextCursor})> history({
    bool missedOnly = false,
    String? cursor,
    int limit = 50,
  }) async {
    final json = await _client.getJson(
      '/calls',
      query: {
        'filter': missedOnly ? 'missed' : 'all',
        'cursor': ?cursor,
        'limit': limit,
      },
    );
    return (
      calls: ((json['calls'] as List?) ?? const [])
          .map((e) => CallInfo.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      nextCursor: (json['next_cursor'] as String?) ?? '',
    );
  }

  Future<List<CallInfo>> active() async {
    final json = await _client.getJson('/calls/active');
    return ((json['calls'] as List?) ?? const [])
        .map((e) => CallInfo.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Server limits (`max_video_tiles`, ring timeout, participant limits).
  Future<CallsConfig> config() async => CallsConfig.fromJson(await _client.getJson('/calls/config'));

  Future<int> missedCount() async =>
      ((await _client.getJson('/calls/missed/count'))['count'] as num?)?.toInt() ?? 0;

  Future<void> markMissedSeen() async {
    await _client.postJson('/calls/missed/seen', expectedStatuses: const {204});
  }

  Future<CallInfo> get(String id) async =>
      _call(await _client.getJson('/calls/${_id(id)}'));

  /// This device received the invitation (suppresses its push, §4.2).
  Future<void> ringing(String id, String deviceId) async {
    await _client.postJson(
      '/calls/${_id(id)}/ringing',
      body: {'device_id': deviceId},
      expectedStatuses: const {204},
    );
  }

  Future<({CallInfo call, LiveKitAccess livekit})> accept(String id, String deviceId) async {
    final json = await _client.postJson(
      '/calls/${_id(id)}/accept',
      body: {'device_id': deviceId},
      expectedStatuses: const {200},
    );
    return (
      call: _call(json),
      livekit: LiveKitAccess.fromJson((json['livekit'] as Map).cast<String, dynamic>()),
    );
  }

  Future<LiveKitAccess> token(String id, String deviceId) async {
    final json = await _client.postJson(
      '/calls/${_id(id)}/token',
      body: {'device_id': deviceId},
      expectedStatuses: const {200},
    );
    return LiveKitAccess.fromJson(
      (json['livekit'] is Map ? json['livekit'] as Map : json).cast<String, dynamic>(),
    );
  }

  Future<CallInfo> reject(String id) async => _call(
    await _client.postJson('/calls/${_id(id)}/reject', expectedStatuses: const {200}),
  );

  Future<CallInfo> cancel(String id) async => _call(
    await _client.postJson('/calls/${_id(id)}/cancel', expectedStatuses: const {200}),
  );

  /// `POST /calls/{id}/stats` → 204: how the media travelled from this
  /// device, kept for the administrators' picture of call problems.
  Future<void> stats(String id, CallNetStats stats) async {
    await _client.postJson(
      '/calls/${_id(id)}/stats',
      body: stats.toJson(),
      expectedStatuses: const {204},
    );
  }

  Future<CallInfo> end(String id, {bool forAll = false}) async => _call(
    await _client.postJson(
      '/calls/${_id(id)}/end',
      body: {if (forAll) 'for_all': true},
      expectedStatuses: const {200},
    ),
  );

  Future<CallInfo> invite(String id, List<String> userIds) async => _call(
    await _client.postJson(
      '/calls/${_id(id)}/invite',
      body: {'user_ids': userIds},
      expectedStatuses: const {200},
    ),
  );

  Future<void> muteParticipant(String id, String userId, String source) async {
    await _client.postJson(
      '/calls/${_id(id)}/participants/${_id(userId)}/mute',
      body: {'source': source},
      expectedStatuses: const {204},
    );
  }

  Future<void> removeParticipant(String id, String userId) async {
    await _client.postJson(
      '/calls/${_id(id)}/participants/${_id(userId)}/remove',
      expectedStatuses: const {204},
    );
  }

  Future<void> setRole(String id, String userId, String role) async {
    await _client.postJson(
      '/calls/${_id(id)}/participants/${_id(userId)}/role',
      body: {'role': role},
      expectedStatuses: const {204},
    );
  }

  // ---- in-call chat of calls without a conversation (§11) ----------------------------

  /// History for late joiners, oldest first.
  Future<({List<CallChatMessage> messages, String nextCursor})> messages(String id, {String? cursor, int limit = 200}) async {
    final json = await _client.getJson('/calls/${_id(id)}/messages', query: {'cursor': ?cursor, 'limit': limit});
    return (
      messages: ((json['messages'] as List?) ?? const [])
          .map((e) => CallChatMessage.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      nextCursor: (json['next_cursor'] as String?) ?? '',
    );
  }

  /// 201 stored / 200 retry of the same [clientMessageId].
  Future<CallChatMessage> postMessage(String id, {required String clientMessageId, required String body}) async {
    final json = await _client.postJson(
      '/calls/${_id(id)}/messages',
      body: {'client_message_id': clientMessageId, 'body': body},
      expectedStatuses: const {200, 201},
    );
    return CallChatMessage.fromJson(((json['message'] as Map?) ?? json).cast<String, dynamic>());
  }

  // ---- recording (§10) ------------------------------------------------------------------

  ({CallRecordingItem recording, CallInfo call}) _recording(Map<String, dynamic> json) => (
    recording: CallRecordingItem.fromJson(((json['recording'] as Map?) ?? const {}).cast<String, dynamic>()),
    call: _call(json),
  );

  Future<({CallRecordingItem recording, CallInfo call})> startRecording(String id, {bool audioOnly = false}) async => _recording(
    await _client.postJson(
      '/calls/${_id(id)}/recording/start',
      body: {if (audioOnly) 'audio_only': true},
      expectedStatuses: const {201},
    ),
  );

  Future<({CallRecordingItem recording, CallInfo call})> stopRecording(String id) async =>
      _recording(await _client.postJson('/calls/${_id(id)}/recording/stop', expectedStatuses: const {200}));

  Future<List<CallRecordingItem>> recordings(String id) async {
    final json = await _client.getJson('/calls/${_id(id)}/recordings');
    return ((json['recordings'] as List?) ?? const [])
        .map((e) => CallRecordingItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // ---- scheduled meetings (§12) ----------------------------------------------------------

  Meeting _meeting(Map<String, dynamic> json) =>
      Meeting.fromJson(((json['meeting'] as Map?) ?? json).cast<String, dynamic>());

  /// 201 new / 200 replay of the same [clientMeetingId].
  Future<Meeting> createMeeting({
    required String clientMeetingId,
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
    List<String> inviteeIds = const [],
    bool lobbyEnabled = true,
    String? calendarEventId,
  }) async => _meeting(
    await _client.postJson(
      '/meetings',
      body: {
        'client_meeting_id': clientMeetingId,
        'title': title,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt.toUtc().toIso8601String(),
        'invitee_ids': inviteeIds,
        'lobby_enabled': lobbyEnabled,
        'calendar_event_id': ?calendarEventId,
      },
      expectedStatuses: const {200, 201},
    ),
  );

  /// Meetings I organize or am invited to, overlapping [from]..[to].
  Future<List<Meeting>> meetings({DateTime? from, DateTime? to}) async {
    final json = await _client.getJson(
      '/meetings',
      query: {'from': ?from?.toUtc().toIso8601String(), 'to': ?to?.toUtc().toIso8601String()},
    );
    return ((json['meetings'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Meeting.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<Meeting> meeting(String code) async => _meeting(await _client.getJson('/meetings/${_id(code)}'));

  /// Organizer: the calendar event moved or was renamed.
  Future<Meeting> updateMeeting(String code, {String? title, DateTime? startsAt, DateTime? endsAt}) async => _meeting(
    await _client.patchJson(
      '/meetings/${_id(code)}',
      body: {
        'title': ?title,
        'starts_at': ?startsAt?.toUtc().toIso8601String(),
        'ends_at': ?endsAt?.toUtc().toIso8601String(),
      },
    ),
  );

  /// 200 with the call and a token, or 202 with a lobby place.
  Future<MeetingJoinResult> joinMeeting(String code, String deviceId) async => MeetingJoinResult.fromJson(
    await _client.postJson('/meetings/${_id(code)}/join', body: {'device_id': deviceId}, expectedStatuses: const {200, 202}),
  );

  // ---- guests and the lobby (§13) ------------------------------------------------------

  Future<CallGuestLink> createGuestLink(
    String callId, {
    int expiresInMinutes = 120,
    int maxUses = 10,
    bool requireLobby = true,
    bool allowScreenShare = false,
  }) async {
    final json = await _client.postJson(
      '/calls/${_id(callId)}/guest-links',
      body: {
        'expires_in_minutes': expiresInMinutes,
        'max_uses': maxUses,
        'require_lobby': requireLobby,
        'allow_screen_share': allowScreenShare,
      },
      expectedStatuses: const {201},
    );
    return CallGuestLink.fromJson(((json['link'] as Map?) ?? json).cast<String, dynamic>());
  }

  Future<CallLobby> lobby(String callId) async => CallLobby.fromJson(await _client.getJson('/calls/${_id(callId)}/lobby'));

  Future<void> admitFromLobby(String callId, String entryId) async {
    await _client.postJson('/calls/${_id(callId)}/lobby/${_id(entryId)}/admit', expectedStatuses: const {200});
  }

  Future<void> denyFromLobby(String callId, String entryId) async {
    await _client.postJson('/calls/${_id(callId)}/lobby/${_id(entryId)}/deny', expectedStatuses: const {200});
  }

  Future<void> removeGuest(String callId, String entryId) async {
    await _client.postJson('/calls/${_id(callId)}/guests/${_id(entryId)}/remove', expectedStatuses: const {204});
  }

  // ---- transcripts (§14) -----------------------------------------------------------------

  Future<CallTranscript> transcript(String recordingId) async {
    final json = await _client.getJson('/recordings/${_id(recordingId)}/transcript');
    return CallTranscript.fromJson(((json['transcript'] as Map?) ?? json).cast<String, dynamic>());
  }

  Future<CallTranscript> retryTranscript(String recordingId) async {
    final json = await _client.postJson('/recordings/${_id(recordingId)}/transcript/retry', expectedStatuses: const {202});
    return CallTranscript.fromJson(((json['transcript'] as Map?) ?? json).cast<String, dynamic>());
  }

  /// Streams the file through the Call Service (auth header, MinIO stays
  /// private) into [savePath]. A failed download leaves no partial file.
  Future<void> downloadRecording(
    CallRecordingItem recording,
    String savePath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final file = File(savePath);
    Future<void> discard() async {
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // Already gone.
      }
    }

    final Response<dynamic> res;
    try {
      res = await _client.dio.download(
        recording.downloadPath,
        savePath,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
        options: Options(receiveTimeout: const Duration(minutes: 10)),
      );
    } on DioException catch (e) {
      await discard();
      throw ApiClient.mapDioException(e);
    }
    if (res.statusCode == 200) return;
    var text = '';
    try {
      text = await file.readAsString();
    } on Object {
      text = '';
    }
    await discard();
    throw ApiClient.decodeError(Response<dynamic>(requestOptions: res.requestOptions, statusCode: res.statusCode, data: text));
  }
}
