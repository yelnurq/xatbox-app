import '../domain/calendar_time.dart';
import '../domain/recurrence.dart';
import 'calendar_models.dart';

enum OpStatus { queued, failed, conflict }

/// One queued change (persistent outbox). The API has no idempotency key and
/// no way to edit an RRULE, participants or a single occurrence directly, so
/// an edit is planned as a small sequence of these operations.
class CalendarOp {
  const CalendarOp({
    required this.id,
    required this.kind,
    required this.payload,
    required this.createdAt,
    this.seq = 0,
    this.status = OpStatus.queued,
    this.attempts = 0,
    this.errorCode,
  });

  /// `POST /calendar/events` with a client id; reconciled before a retry.
  static const create = 'create';

  /// `PATCH /calendar/events/{id}` guarded by the base `sequence`.
  static const patch = 'patch';

  /// `POST /calendar/events/{series}/exceptions` (cancel or move).
  static const exception = 'exception';

  /// Edit text fields of one occurrence: exception → find override → PATCH.
  static const overridePatch = 'override_patch';

  /// "This and following": cancel every server occurrence from a key on.
  static const cancelFollowing = 'cancel_following';

  static const rsvp = 'rsvp';

  /// Change that PATCH cannot express (participants, all-day, rule…):
  /// cancel the old event, create the new one.
  static const recreate = 'recreate';

  final String id;
  final String kind;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  /// Tie-breaker for ops planned together.
  final int seq;
  final OpStatus status;
  final int attempts;
  final String? errorCode;

  bool get isQueued => status == OpStatus.queued;
  String? get clientEventId => payload['client_event_id'] as String?;
  String? get eventId => payload['event_id'] as String?;

  factory CalendarOp.fromJson(Map<String, dynamic> j) => CalendarOp(
    id: j['id'] as String,
    kind: j['kind'] as String,
    payload: Map<String, dynamic>.from(j['payload'] as Map),
    createdAt: DateTime.parse(j['created_at'] as String),
    seq: (j['seq'] as num?)?.toInt() ?? 0,
    status: OpStatus.values.byName((j['status'] as String?) ?? 'queued'),
    attempts: (j['attempts'] as num?)?.toInt() ?? 0,
    errorCode: j['error_code'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'payload': payload,
    'created_at': createdAt.toUtc().toIso8601String(),
    'seq': seq,
    'status': status.name,
    'attempts': attempts,
    'error_code': ?errorCode,
  };

  CalendarOp copyWith({
    Map<String, dynamic>? payload,
    OpStatus? status,
    int? attempts,
    String? errorCode,
    bool clearError = false,
  }) => CalendarOp(
    id: id,
    kind: kind,
    payload: payload ?? this.payload,
    createdAt: createdAt,
    seq: seq,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    errorCode: clearError ? null : (errorCode ?? this.errorCode),
  );
}

/// What an edit changes compared with the stored event.
class DraftDiff {
  const DraftDiff({
    required this.text,
    required this.timeChanged,
    required this.structural,
  });

  /// Changed PATCH-able text fields (`title`, `description`, `location`,
  /// `meeting_link`) with their new values.
  final Map<String, String> text;
  final bool timeChanged;

  /// Needs cancel + create: participants, all-day, zone or rule.
  final bool structural;

  bool get isEmpty => text.isEmpty && !timeChanged && !structural;
}

class PlanError implements Exception {
  const PlanError(this.code);

  /// `MASTER_UNAVAILABLE` (series master unknown while offline),
  /// `SCOPE_UNSUPPORTED`.
  final String code;
  @override
  String toString() => 'PlanError($code)';
}

/// Pure planning of outbox operations for create / edit / delete / RSVP.
abstract final class CalendarPlanner {
  static CalendarOp _op(
    String kind,
    Map<String, dynamic> payload,
    DateTime now,
    String id, [
    int seq = 0,
  ]) => CalendarOp(
    id: id,
    kind: kind,
    payload: payload,
    createdAt: now,
    seq: seq,
  );

  static bool _sameInstant(DateTime? a, DateTime? b) =>
      a != null && b != null && a.isAtSameMomentAs(b);

  static DraftDiff diff({
    required CalendarOccurrence occurrence,
    required CalendarEvent stored,
    required List<CalendarParticipant> participants,
    required EventDraft draft,
    required String selfId,
  }) {
    final text = <String, String>{};
    void cmp(String key, String before, String after) {
      if (before != after) text[key] = after;
    }

    cmp('title', stored.title, draft.title.trim());
    cmp('description', stored.description, draft.description);
    cmp('location', stored.location, draft.location);
    cmp('meeting_link', stored.meetingLink, draft.meetingLink);

    final timeChanged =
        !_sameInstant(occurrence.start, draft.start) ||
        !_sameInstant(occurrence.end, draft.end);

    final before = participants
        .where((p) => !p.isOrganizer && p.userId != selfId)
        .map((p) => p.userId ?? 'ext:${p.externalEmail}')
        .toSet();
    final after = draft.participants.map((p) => p.key).toSet();
    final ruleBefore = stored.rrule;
    final ruleAfter = draft.recurrence?.toRRule() ?? '';
    final structural =
        stored.allDay != draft.allDay ||
        // The zone drives all-day dates and series wall-clock times; PATCH
        // cannot change it.
        ((stored.allDay || stored.isRecurring) &&
            stored.timezone != draft.timezone) ||
        ruleBefore != ruleAfter ||
        before.length != after.length ||
        !before.containsAll(after);

    return DraftDiff(
      text: text,
      timeChanged: timeChanged,
      structural: structural,
    );
  }

  static CalendarOp planCreate(
    EventDraft draft, {
    required String clientEventId,
    required String opId,
    required DateTime now,
  }) => _op(CalendarOp.create, {
    'client_event_id': clientEventId,
    'body': draft.toCreateBody(),
  }, now, opId);

  static bool _hasGuests(EventDraft d) => d.participants.isNotEmpty;

  /// [master] is required for recurring events (series start and rule).
  static List<CalendarOp> planEdit({
    required CalendarOccurrence occurrence,
    required CalendarEventDetail? master,
    required EventDraft draft,
    required EditScope scope,
    required DraftDiff diff,
    required String selfId,
    required DateTime now,
    required String Function() newId,
  }) {
    final e = occurrence.event;
    if (diff.isEmpty) return const [];
    final hadGuests = e.audienceType != 'only_me';

    Map<String, dynamic> textAndTime({
      required DateTime start,
      required DateTime end,
    }) => {
      ...diff.text,
      if (diff.timeChanged) ...{
        'starts_at': EventTime.encode(start),
        'ends_at': EventTime.encode(end),
      },
    };

    switch (scope) {
      case EditScope.single:
        if (diff.structural) {
          return [
            _op(CalendarOp.recreate, {
              'event_id': e.id,
              'base_sequence': e.sequence,
              'client_event_id': newId(),
              'body': draft.toCreateBody(),
              'notify_old': hadGuests,
            }, now, newId()),
          ];
        }
        return [
          _op(CalendarOp.patch, {
            'event_id': e.id,
            'base_sequence': e.sequence,
            'body': textAndTime(start: draft.start, end: draft.end),
            if (hadGuests) 'notify': 'updated',
          }, now, newId()),
        ];

      case EditScope.thisOccurrence:
        if (diff.structural) throw const PlanError('SCOPE_UNSUPPORTED');
        if (e.isOverride) {
          return [
            _op(CalendarOp.patch, {
              'event_id': e.id,
              'base_sequence': e.sequence,
              'body': textAndTime(start: draft.start, end: draft.end),
              if (hadGuests) 'notify': 'updated',
              'notify_event_id': e.seriesKey,
            }, now, newId()),
          ];
        }
        final key = e.occurrenceStartRaw;
        if (key == null) throw const PlanError('SCOPE_UNSUPPORTED');
        if (diff.text.isEmpty) {
          return [
            _op(CalendarOp.exception, {
              'series_id': e.id,
              'occurrence_start': key,
              'cancelled': false,
              'starts_at': EventTime.encode(draft.start),
              'ends_at': EventTime.encode(draft.end),
              if (hadGuests) 'notify': 'updated',
            }, now, newId()),
          ];
        }
        return [
          _op(CalendarOp.overridePatch, {
            'series_id': e.id,
            'occurrence_start': key,
            'starts_at': EventTime.encode(draft.start),
            'ends_at': EventTime.encode(draft.end),
            'body': diff.text,
            if (hadGuests) 'notify': 'updated',
          }, now, newId()),
        ];

      case EditScope.following:
        if (master == null) throw const PlanError('MASTER_UNAVAILABLE');
        final spec = master.event.recurrence;
        final zone = CalendarZones.location(master.event.timezone);
        final before = spec == null
            ? 0
            : RecurrenceEngine.countBefore(
                spec: spec,
                masterUtc: master.event.startsAt,
                zone: zone,
                displayStartUtc: occurrence.start,
              );
        if (before == 0 || e.occurrenceStartRaw == null) {
          return planEdit(
            occurrence: occurrence,
            master: master,
            draft: draft,
            scope: EditScope.all,
            diff: diff,
            selfId: selfId,
            now: now,
            newId: newId,
          );
        }
        final last = spec == null
            ? null
            : RecurrenceEngine.lastStart(
                spec: spec,
                masterUtc: master.event.startsAt,
                zone: zone,
              );
        var rule = draft.recurrence;
        if (rule != null && rule.count != null && spec?.count == rule.count) {
          final remaining = rule.count! - before;
          rule = remaining > 0 ? rule.copyWith(count: remaining) : null;
        }
        final tail = draft.copyWith(
          recurrence: rule,
          clearRecurrence: rule == null,
        );
        return [
          _op(CalendarOp.cancelFollowing, {
            'series_id': e.id,
            'from': e.occurrenceStartRaw,
            'until': ?(last == null ? null : EventTime.encode(last)),
            if (hadGuests) 'notify': 'updated',
          }, now, newId(), 0),
          _op(CalendarOp.create, {
            'client_event_id': newId(),
            'body': tail.toCreateBody(),
          }, now, newId(), 1),
        ];

      case EditScope.all:
        final target = master?.event ?? e;
        if (e.isRecurring && master == null) {
          throw const PlanError('MASTER_UNAVAILABLE');
        }
        // Occurrence display → series start: shift by the same delta.
        final shift = draft.start.difference(occurrence.start);
        final newStart = target.startsAt.add(shift);
        final newEnd = newStart.add(draft.end.difference(draft.start));
        if (diff.structural) {
          return [
            _op(CalendarOp.recreate, {
              'event_id': target.id,
              'base_sequence': target.sequence,
              'client_event_id': newId(),
              'body': draft.copyWith(start: newStart, end: newEnd).toCreateBody(),
              'notify_old': hadGuests || _hasGuests(draft),
            }, now, newId()),
          ];
        }
        return [
          _op(CalendarOp.patch, {
            'event_id': target.id,
            'base_sequence': target.sequence,
            'body': textAndTime(start: newStart, end: newEnd),
            'shift_ms': shift.inMilliseconds,
            'duration_ms': draft.end.difference(draft.start).inMilliseconds,
            if (hadGuests) 'notify': 'updated',
          }, now, newId()),
        ];
    }
  }

  static List<CalendarOp> planDelete({
    required CalendarOccurrence occurrence,
    required CalendarEventDetail? master,
    required EditScope scope,
    required DateTime now,
    required String Function() newId,
  }) {
    final e = occurrence.event;
    final hadGuests = e.audienceType != 'only_me';
    CalendarOp cancel(String id, int sequence) =>
        _op(CalendarOp.patch, {
          'event_id': id,
          'base_sequence': sequence,
          'body': {'status': 'cancelled'},
          if (hadGuests) 'notify': 'cancelled',
        }, now, newId());

    switch (scope) {
      case EditScope.single:
        return [cancel(e.id, e.sequence)];
      case EditScope.thisOccurrence:
        if (e.isOverride) return [cancel(e.id, e.sequence)];
        return [
          _op(CalendarOp.exception, {
            'series_id': e.id,
            'occurrence_start': e.occurrenceStartRaw,
            'cancelled': true,
            if (hadGuests) 'notify': 'updated',
          }, now, newId()),
        ];
      case EditScope.following:
        if (master == null) throw const PlanError('MASTER_UNAVAILABLE');
        final spec = master.event.recurrence;
        final zone = CalendarZones.location(master.event.timezone);
        final before = spec == null
            ? 0
            : RecurrenceEngine.countBefore(
                spec: spec,
                masterUtc: master.event.startsAt,
                zone: zone,
                displayStartUtc: occurrence.start,
              );
        if (before == 0) {
          return [cancel(master.event.id, master.event.sequence)];
        }
        final last = spec == null
            ? null
            : RecurrenceEngine.lastStart(
                spec: spec,
                masterUtc: master.event.startsAt,
                zone: zone,
              );
        return [
          _op(CalendarOp.cancelFollowing, {
            'series_id': e.seriesKey,
            'from': e.occurrenceStartRaw,
            'until': ?(last == null ? null : EventTime.encode(last)),
            if (hadGuests) 'notify': 'updated',
          }, now, newId()),
        ];
      case EditScope.all:
        final target = master?.event ?? e;
        return [cancel(target.seriesKey, target.sequence)];
    }
  }

  static CalendarOp planRsvp({
    required CalendarEvent event,
    required RsvpStatus status,
    required DateTime now,
    required String opId,
  }) => _op(CalendarOp.rsvp, {
    'event_id': event.seriesKey,
    'status': status.name,
  }, now, opId);
}
