import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../domain/calendar_time.dart';
import 'calendar_models.dart';

/// REST client of the calendar part of the Mail API (`/calendar/*`). Same
/// [ApiClient] (token, global 401 → sign-out) as the mail module.
class CalendarApi {
  CalendarApi(this._client);
  final ApiClient _client;

  static String _id(String id) => Uri.encodeComponent(id);

  /// `GET /calendar/events`: events overlapping `[start, end)` with series
  /// expanded. There is no pagination; callers ask for bounded windows.
  Future<List<CalendarEvent>> list({
    required DateTime start,
    required DateTime end,
  }) async {
    final json = await _client.getJson(
      '/calendar/events',
      query: {'start': EventTime.encode(start), 'end': EventTime.encode(end)},
    );
    return ((json['events'] as List?) ?? const [])
        .map((e) => CalendarEvent.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<CalendarEventDetail> get(String id) async =>
      CalendarEventDetail.fromJson(
        await _client.getJson('/calendar/events/${_id(id)}'),
      );

  /// `POST /calendar/events` → new event id.
  Future<String> create(Map<String, dynamic> body) async {
    final json = await _client.postJson(
      '/calendar/events',
      body: body,
      expectedStatuses: const {201},
    );
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const UnexpectedApiException('create event without id');
    }
    return id;
  }

  /// `PATCH /calendar/events/{id}` (title, description, starts_at, ends_at,
  /// location, meeting_link, status only).
  Future<void> patch(String id, Map<String, dynamic> body) async {
    await _client.patchJson('/calendar/events/${_id(id)}', body: body);
  }

  /// `POST /calendar/events/{id}/exceptions`: cancel or move one occurrence.
  Future<void> exception(
    String seriesId, {
    required String occurrenceStart,
    bool cancelled = false,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    await _client.postJson(
      '/calendar/events/${_id(seriesId)}/exceptions',
      body: {
        'occurrence_start': occurrenceStart,
        if (cancelled) 'cancelled': true,
        if (!cancelled && startsAt != null)
          'starts_at': EventTime.encode(startsAt),
        if (!cancelled && endsAt != null) 'ends_at': EventTime.encode(endsAt),
      },
      expectedStatuses: const {200},
    );
  }

  Future<RsvpStatus> rsvp(String id, RsvpStatus status) async {
    final json = await _client.postJson(
      '/calendar/events/${_id(id)}/rsvp',
      body: {'status': status.name},
      expectedStatuses: const {200},
    );
    return RsvpStatus.fromApi(json['status'] as String?) ?? status;
  }

  /// `GET /calendar/events/{id}/ics` as text.
  Future<String> ics(String id) async {
    final res = await _client.send(
      () => _client.dio.get<String>(
        '/calendar/events/${_id(id)}/ics',
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Accept': 'text/calendar, application/json'},
        ),
      ),
    );
    return res.data ?? '';
  }

  /// Longest window free-busy and find-time accept.
  static const maxSchedulingWindow = Duration(days: 62);

  /// Body of `POST /calendar/free-busy` (`CalendarFreeBusyRequest`, strict):
  /// distinct user ids (the caller is not added by the server, so callers
  /// include themselves), the window, and an optional room.
  static Map<String, dynamic> freeBusyBody({
    required List<String> userIds,
    required DateTime start,
    required DateTime end,
    String? resourceId,
  }) {
    final (s, e) = _window(start, end);
    return {
      'user_ids': userIds.toSet().toList(),
      'start': EventTime.encode(s),
      'end': EventTime.encode(e),
      if (resourceId != null && resourceId.isNotEmpty) 'resource_id': resourceId,
    };
  }

  /// Body of `POST /calendar/find-time` (same schema; `resource_id` and
  /// `timezone` are ignored there, so they are not sent).
  static Map<String, dynamic> findTimeBody({
    required List<String> userIds,
    required DateTime start,
    required DateTime end,
    int? durationMinutes,
  }) {
    final (s, e) = _window(start, end);
    return {
      'user_ids': userIds.toSet().toList(),
      'start': EventTime.encode(s),
      'end': EventTime.encode(e),
      if (durationMinutes != null && durationMinutes > 0)
        'duration_minutes': durationMinutes,
    };
  }

  static (DateTime, DateTime) _window(DateTime start, DateTime end) {
    final limit = start.add(maxSchedulingWindow);
    return (start, end.isAfter(limit) ? limit : end);
  }

  /// `POST /calendar/free-busy`: busy intervals per user and for the room.
  Future<FreeBusyResult> freeBusy({
    required List<String> userIds,
    required DateTime start,
    required DateTime end,
    String? resourceId,
  }) async => FreeBusyResult.fromJson(
    await _client.postJson(
      '/calendar/free-busy',
      body: freeBusyBody(
        userIds: userIds,
        start: start,
        end: end,
        resourceId: resourceId,
      ),
      expectedStatuses: const {200},
    ),
  );

  /// `POST /calendar/find-time`: up to 5 free slots, chronological.
  Future<List<CalendarInterval>> findTime({
    required List<String> userIds,
    required DateTime start,
    required DateTime end,
    int? durationMinutes,
  }) async {
    final json = await _client.postJson(
      '/calendar/find-time',
      body: findTimeBody(
        userIds: userIds,
        start: start,
        end: end,
        durationMinutes: durationMinutes,
      ),
      expectedStatuses: const {200},
    );
    return CalendarInterval.listFrom(json['suggestions']).take(5).toList();
  }

  /// `GET /calendar/resources`: all rooms, including disabled ones.
  Future<List<CalendarResource>> resources() async {
    final json = await _client.getJson('/calendar/resources');
    return ((json['resources'] as List?) ?? const [])
        .map((e) => CalendarResource.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// `GET /calendar/settings`; organizations without a settings row answer
  /// 500, which is documented, so defaults are used then.
  Future<OrgCalendarSettings> settings() async {
    try {
      return OrgCalendarSettings.fromJson(
        await _client.getJson('/calendar/settings'),
      );
    } on ApiException catch (e) {
      if (e.statusCode == 500) return const OrgCalendarSettings();
      rethrow;
    }
  }
}

/// Best-effort signal to colleagues through the Chat Service relay
/// (`POST /calendar/events/{id}/notify`, docs/CALLS-API.md §6): realtime
/// refresh on their devices and a push when they are offline. The server
/// re-checks everything with the Mail API, so nothing here is trusted.
class CalendarRelay {
  CalendarRelay(this._client);
  final ApiClient? _client;

  Future<void> notify(String eventId, String kind) async {
    final client = _client;
    if (client == null) return;
    await client.postJson(
      '/calendar/events/${Uri.encodeComponent(eventId)}/notify',
      body: {'kind': kind},
      expectedStatuses: const {204},
    );
  }
}
