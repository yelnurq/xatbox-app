import '../domain/calendar_time.dart';
import '../domain/recurrence.dart';

/// The caller's (or a participant's) answer to an invitation.
enum RsvpStatus {
  pending,
  accepted,
  tentative,
  declined;

  static RsvpStatus? fromApi(String? v) =>
      RsvpStatus.values.where((s) => s.name == v).firstOrNull;
}

/// `CalendarParticipant` schema.
class CalendarParticipant {
  const CalendarParticipant({
    required this.role,
    required this.responseStatus,
    this.userId,
    this.externalEmail,
    this.displayName = '',
    this.email = '',
    this.departmentName = '',
  });

  final String? userId;
  final String? externalEmail;
  final String displayName;
  final String email;
  final String departmentName;
  final String role; // organizer | required | optional
  final RsvpStatus responseStatus;

  bool get isExternal => userId == null;
  bool get isOrganizer => role == 'organizer';
  String get label => displayName.isNotEmpty
      ? displayName
      : (email.isNotEmpty ? email : (externalEmail ?? ''));

  factory CalendarParticipant.fromJson(Map<String, dynamic> j) =>
      CalendarParticipant(
        userId: j['user_id'] as String?,
        externalEmail: j['external_email'] as String?,
        displayName: (j['display_name'] as String?) ?? '',
        email: (j['email'] as String?) ?? '',
        departmentName: (j['department_name'] as String?) ?? '',
        role: (j['role'] as String?) ?? 'required',
        responseStatus:
            RsvpStatus.fromApi(j['response_status'] as String?) ??
            RsvpStatus.pending,
      );

  Map<String, dynamic> toJson() => {
    'user_id': ?userId,
    'external_email': ?externalEmail,
    'display_name': displayName,
    'email': email,
    'department_name': departmentName,
    'role': role,
    'response_status': responseStatus.name,
  };
}

/// `CalendarEvent` schema: a stored event, or one server-expanded occurrence
/// of a series. The original JSON is kept verbatim for the offline cache.
class CalendarEvent {
  CalendarEvent._(this.raw)
    : id = raw['id'] as String,
      uid = (raw['uid'] as String?) ?? '',
      sequence = (raw['sequence'] as num?)?.toInt() ?? 0,
      organizationId = (raw['organization_id'] as String?) ?? '',
      organizerId = (raw['organizer_id'] as String?) ?? '',
      organizerName = (raw['organizer_name'] as String?) ?? '',
      title = (raw['title'] as String?) ?? '',
      description = (raw['description'] as String?) ?? '',
      location = (raw['location'] as String?) ?? '',
      meetingLink = (raw['meeting_link'] as String?) ?? '',
      eventType = (raw['event_type'] as String?) ?? 'personal',
      audienceType = (raw['audience_type'] as String?) ?? 'only_me',
      visibility = (raw['visibility'] as String?) ?? 'default',
      attendance = (raw['attendance'] as String?) ?? 'invitation',
      status = (raw['status'] as String?) ?? 'confirmed',
      allDay = raw['all_day'] == true,
      startsAt =
          EventTime.parse(raw['starts_at'] as String?) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      endsAt =
          EventTime.parse(raw['ends_at'] as String?) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      timezone = (raw['timezone'] as String?) ?? 'UTC',
      rrule = (raw['rrule'] as String?) ?? '',
      reminderMinutes = (raw['reminder_minutes'] as num?)?.toInt() ?? 0,
      responseStatus = RsvpStatus.fromApi(raw['response_status'] as String?),
      managed = raw['managed'] == true,
      seriesId = raw['series_id'] as String?,
      occurrenceStartRaw = raw['occurrence_start'] as String?;

  factory CalendarEvent.fromJson(Map<String, dynamic> json) =>
      CalendarEvent._(Map<String, dynamic>.from(json));

  final Map<String, dynamic> raw;
  final String id;
  final String uid;
  final int sequence;
  final String organizationId;
  final String organizerId;
  final String organizerName;
  final String title;
  final String description;
  final String location;
  final String meetingLink;
  final String eventType;
  final String audienceType;
  final String visibility;
  final String attendance;
  final String status;
  final bool allDay;
  final DateTime startsAt;
  final DateTime endsAt;
  final String timezone;
  final String rrule;
  final int reminderMinutes;
  final RsvpStatus? responseStatus;
  final bool managed;
  final String? seriesId;

  /// Server key of an expanded occurrence, exactly as received (used for
  /// `POST /calendar/events/{id}/exceptions`).
  final String? occurrenceStartRaw;

  Map<String, dynamic> toJson() => raw;

  DateTime? get occurrenceStart => EventTime.parse(occurrenceStartRaw);

  bool get isRecurring => rrule.isNotEmpty;
  bool get isCancelled => status == 'cancelled';
  bool get isMandatory => attendance == 'mandatory';
  bool get isPrivate => visibility == 'private';

  /// Replacement of one moved occurrence (own id, `series_id` set), or its
  /// standalone copy (`uid` = `<series uid>#occ-…`).
  bool get isOverride =>
      (seriesId != null && seriesId != id) || uid.contains('#occ-');

  /// Id RSVP / whole-series operations use.
  String get seriesKey => isOverride ? (seriesId ?? id) : id;

  /// Unique within a listing (series ids repeat for every occurrence).
  String get occurrenceKey => '$id|${occurrenceStartRaw ?? ''}';

  /// Reserved for group calls (next stage): the meeting URL doubles as the
  /// conference URL; a XatBox join link `…/join/<room>` carries the room id.
  /// Stored in `meeting_link`, so no API/DB change is needed later.
  String get conferenceUrl => meetingLink;
  String? get conferenceRoomId {
    final uri = Uri.tryParse(meetingLink);
    if (uri == null) return null;
    final seg = uri.pathSegments;
    final i = seg.indexOf('join');
    return i >= 0 && i + 1 < seg.length ? seg[i + 1] : null;
  }

  RecurrenceSpec? get recurrence => RecurrenceSpec.parse(rrule);

  bool isOrganizer(String userId) => organizerId == userId;

  CalendarEvent copyWithRaw(Map<String, dynamic> changes) =>
      CalendarEvent._({...raw, ...changes});
}

/// `GET /calendar/events/{id}`: the stored event (series master, not
/// expanded) with its participants.
class CalendarEventDetail {
  const CalendarEventDetail({required this.event, required this.participants});

  final CalendarEvent event;
  final List<CalendarParticipant> participants;

  factory CalendarEventDetail.fromJson(Map<String, dynamic> j) =>
      CalendarEventDetail(
        event: CalendarEvent.fromJson(
          (j['event'] as Map).cast<String, dynamic>(),
        ),
        participants: ((j['participants'] as List?) ?? const [])
            .map(
              (e) => CalendarParticipant.fromJson(
                (e as Map).cast<String, dynamic>(),
              ),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'event': event.toJson(),
    'participants': participants.map((p) => p.toJson()).toList(),
  };

  CalendarParticipant? participantFor(String userId) =>
      participants.where((p) => p.userId == userId).firstOrNull;
}

/// One entry on screen: an occurrence with display times resolved.
class CalendarOccurrence {
  const CalendarOccurrence({
    required this.event,
    required this.start,
    required this.end,
    this.allDayStart,
    this.allDayEnd,
    this.pending = false,
    this.localId,
  });

  final CalendarEvent event;

  /// Display instants (UTC). For recurring events already corrected to the
  /// wall-clock time of the event zone.
  final DateTime start;
  final DateTime end;

  /// All-day range `[allDayStart, allDayEnd)`, set only for all-day events.
  final CalendarDate? allDayStart;
  final CalendarDate? allDayEnd;

  /// Not yet confirmed by the server (queued in the outbox).
  final bool pending;

  /// Client id of a queued create.
  final String? localId;

  bool get allDay => allDayStart != null;
  String get key => localId ?? event.occurrenceKey;

  CalendarOccurrence copyWith({
    CalendarEvent? event,
    DateTime? start,
    DateTime? end,
    bool? pending,
  }) => CalendarOccurrence(
    event: event ?? this.event,
    start: start ?? this.start,
    end: end ?? this.end,
    allDayStart: allDayStart,
    allDayEnd: allDayEnd,
    pending: pending ?? this.pending,
    localId: localId,
  );
}

/// A colleague picked in the form (internal) or a free e-mail (external).
class DraftParticipant {
  const DraftParticipant.internal({
    required String this.userId,
    required this.label,
    this.email = '',
  }) : externalEmail = null;

  const DraftParticipant.external(String this.externalEmail)
    : userId = null,
      label = externalEmail,
      email = externalEmail;

  final String? userId;
  final String? externalEmail;
  final String label;
  final String email;

  String get key => userId ?? 'ext:$externalEmail';

  Map<String, dynamic> toJson() => {
    'user_id': ?userId,
    'external_email': ?externalEmail,
    'label': label,
    'email': email,
  };

  factory DraftParticipant.fromJson(Map<String, dynamic> j) =>
      j['user_id'] != null
      ? DraftParticipant.internal(
          userId: j['user_id'] as String,
          label: (j['label'] as String?) ?? '',
          email: (j['email'] as String?) ?? '',
        )
      : DraftParticipant.external(j['external_email'] as String);
}

/// What the edit form produces. [toCreateBody] sends only fields documented
/// in `CalendarEventCreateRequest` (the API rejects unknown ones).
class EventDraft {
  const EventDraft({
    required this.title,
    required this.start,
    required this.end,
    required this.timezone,
    this.description = '',
    this.location = '',
    this.meetingLink = '',
    this.allDay = false,
    this.recurrence,
    this.reminders = const [15],
    this.participants = const [],
    this.eventType = 'personal',
    this.visibility = 'default',
    this.resourceId,
  });

  /// Room to book (`resource_id`); only honoured on create.
  final String? resourceId;

  final String title;
  final String description;
  final String location;
  final String meetingLink;
  final bool allDay;

  /// Instants. For all-day drafts: midnight of the first day and midnight
  /// after the last day in [timezone] (see [EventTime.encodeAllDay]).
  final DateTime start;
  final DateTime end;
  final String timezone;
  final RecurrenceSpec? recurrence;

  /// Minutes before start. The server keeps one value per event (the first);
  /// the rest are local reminders on this device.
  final List<int> reminders;
  final List<DraftParticipant> participants;

  /// Category (`event_type`); drives the colour.
  final String eventType;
  final String visibility;

  int get serverReminder => reminders.isEmpty ? 0 : reminders.first;

  String get audienceType =>
      participants.isEmpty ? 'only_me' : 'selected_users';

  List<String> get userIds =>
      participants.map((p) => p.userId).whereType<String>().toList();
  List<String> get externalEmails =>
      participants.map((p) => p.externalEmail).whereType<String>().toList();

  Map<String, dynamic> toCreateBody() => {
    'title': title.trim(),
    if (description.isNotEmpty) 'description': description,
    'starts_at': EventTime.encode(start),
    'ends_at': EventTime.encode(end),
    'all_day': allDay,
    if (location.isNotEmpty) 'location': location,
    if (meetingLink.isNotEmpty) 'meeting_link': meetingLink,
    'event_type': participants.isEmpty ? eventType : 'meeting',
    'audience_type': audienceType,
    'visibility': visibility,
    'timezone': timezone,
    if (recurrence != null) 'rrule': recurrence!.toRRule(),
    'reminder_minutes': serverReminder,
    if (userIds.isNotEmpty) 'user_ids': userIds,
    if (externalEmails.isNotEmpty) 'external_emails': externalEmails,
    if (resourceId != null && resourceId!.isNotEmpty) 'resource_id': resourceId,
  };

  EventDraft copyWith({
    String? title,
    String? description,
    String? location,
    String? meetingLink,
    bool? allDay,
    DateTime? start,
    DateTime? end,
    String? timezone,
    RecurrenceSpec? recurrence,
    bool clearRecurrence = false,
    List<int>? reminders,
    List<DraftParticipant>? participants,
    String? eventType,
    String? visibility,
    String? resourceId,
  }) => EventDraft(
    resourceId: resourceId ?? this.resourceId,
    title: title ?? this.title,
    description: description ?? this.description,
    location: location ?? this.location,
    meetingLink: meetingLink ?? this.meetingLink,
    allDay: allDay ?? this.allDay,
    start: start ?? this.start,
    end: end ?? this.end,
    timezone: timezone ?? this.timezone,
    recurrence: clearRecurrence ? null : (recurrence ?? this.recurrence),
    reminders: reminders ?? this.reminders,
    participants: participants ?? this.participants,
    eventType: eventType ?? this.eventType,
    visibility: visibility ?? this.visibility,
  );
}

/// `CalendarInterval` (RFC 3339) or `CalendarResourceBusyInterval`
/// (PostgreSQL text); both formats are parsed.
class CalendarInterval {
  const CalendarInterval(this.start, this.end);

  final DateTime start;
  final DateTime end;

  static CalendarInterval? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final s = EventTime.parse(raw['start'] as String?);
    final e = EventTime.parse(raw['end'] as String?);
    if (s == null || e == null) return null;
    return CalendarInterval(s, e);
  }

  static List<CalendarInterval> listFrom(Object? raw) => [
    for (final item in (raw as List?) ?? const [])
      ?CalendarInterval.fromJson(item),
  ];

  /// Overlap with `[from, to)`.
  bool overlaps(DateTime from, DateTime to) =>
      start.isBefore(to) && end.isAfter(from);
}

/// `CalendarResource`: a bookable room.
class CalendarResource {
  const CalendarResource({
    required this.id,
    required this.name,
    this.location = '',
    this.capacity = 0,
    this.equipment = '',
    this.status = 'active',
  });

  final String id;
  final String name;
  final String location;
  final int capacity;
  final String equipment;
  final String status; // active | disabled

  bool get isActive => status == 'active';

  factory CalendarResource.fromJson(Map<String, dynamic> j) => CalendarResource(
    id: j['id'] as String,
    name: (j['name'] as String?) ?? '',
    location: (j['location'] as String?) ?? '',
    capacity: (j['capacity'] as num?)?.toInt() ?? 0,
    equipment: (j['equipment'] as String?) ?? '',
    status: (j['status'] as String?) ?? 'active',
  );
}

/// `CalendarFreeBusyResponse`.
class FreeBusyResult {
  const FreeBusyResult({this.busy = const {}, this.resourceBusy = const []});

  /// User id → busy intervals (empty list = free).
  final Map<String, List<CalendarInterval>> busy;
  final List<CalendarInterval> resourceBusy;

  factory FreeBusyResult.fromJson(Map<String, dynamic> j) => FreeBusyResult(
    busy: {
      for (final e in ((j['busy'] as Map?) ?? const {}).entries)
        e.key as String: CalendarInterval.listFrom(e.value),
    },
    resourceBusy: CalendarInterval.listFrom(j['resource_busy']),
  );
}

/// `CalendarSettings` of the organization, with local defaults when the
/// server has no row (it answers 500 then).
class OrgCalendarSettings {
  const OrgCalendarSettings({
    this.timezone = 'UTC',
    this.workingDays = const [1, 2, 3, 4, 5],
    this.workStartHour = 9,
    this.workEndHour = 18,
    this.defaultDurationMinutes = 30,
    this.defaultReminderMinutes = 15,
    this.allowUserMeetings = true,
  });

  final String timezone;
  final List<int> workingDays;
  final int workStartHour;
  final int workEndHour;
  final int defaultDurationMinutes;
  final int defaultReminderMinutes;
  final bool allowUserMeetings;

  static int _hour(String? v, int def) =>
      int.tryParse((v ?? '').split(':').first) ?? def;

  factory OrgCalendarSettings.fromJson(Map<String, dynamic> j) =>
      OrgCalendarSettings(
        timezone: (j['timezone'] as String?) ?? 'UTC',
        workingDays: ((j['working_days'] as List?) ?? const [1, 2, 3, 4, 5])
            .map((e) => (e as num).toInt())
            .toList(),
        workStartHour: _hour(j['work_start'] as String?, 9),
        workEndHour: _hour(j['work_end'] as String?, 18),
        defaultDurationMinutes:
            (j['default_duration_minutes'] as num?)?.toInt() ?? 30,
        defaultReminderMinutes:
            (j['default_reminder_minutes'] as num?)?.toInt() ?? 15,
        allowUserMeetings: j['allow_user_meetings'] != false,
      );
}

/// Edit/delete scope for recurring events.
enum EditScope { single, thisOccurrence, following, all }
