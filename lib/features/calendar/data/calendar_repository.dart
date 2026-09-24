import 'dart:async';

import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../../../core/api/api_exception.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../domain/calendar_time.dart';
import 'calendar_api.dart';
import 'calendar_cache.dart';
import 'calendar_models.dart';
import 'calendar_occurrences.dart';
import 'calendar_ops.dart';

enum _Step { next, stop }

/// Cache-first calendar over the Mail API calendar endpoints:
/// * month windows (date-range pagination, never "all events");
/// * a persistent outbox, flushed in order, with create reconciliation
///   (the API has no idempotency key) and `sequence` conflict detection;
/// * recurring edits/deletes for "this / following / all".
class CalendarRepository {
  CalendarRepository({
    required CalendarApi api,
    required CalendarCache cache,
    required String Function() selfId,
    CalendarRelay? relay,
    DateTime Function()? clock,
    String Function()? newId,
  }) : _api = api, // ignore: prefer_initializing_formals
       _cache = cache, // ignore: prefer_initializing_formals
       _selfId = selfId, // ignore: prefer_initializing_formals
       _relay = relay, // ignore: prefer_initializing_formals
       _clock = clock ?? DateTime.now,
       _newId = newId ?? const Uuid().v4;

  final CalendarApi _api;
  final CalendarCache _cache;
  final String Function() _selfId;
  final CalendarRelay? _relay;
  final DateTime Function() _clock;
  final String Function() _newId;

  final _changes = StreamController<void>.broadcast();
  Future<void>? _flushing;

  /// "This and following" cancels occurrences one by one (no API to end a
  /// series); above this many the operation is refused.
  static const followingCap = 600;

  /// The server stops expanding a series ~3660 days after its start.
  static const serverSeriesHorizon = Duration(days: 3660);

  Stream<void> get changes => _changes.stream;
  CalendarCache get cache => _cache;
  String get selfId => _selfId();
  DateTime get now => _clock().toUtc();

  Future<void> dispose() => _changes.close();

  // ---- windows -------------------------------------------------------------

  static String monthKey(int year, int month) =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  /// A month plus a margin wide enough for any device zone (−12…+14 h).
  static (DateTime, DateTime) monthWindow(int year, int month) => (
    DateTime.utc(year, month, 1).subtract(const Duration(hours: 15)),
    DateTime.utc(year, month + 1, 1).add(const Duration(hours: 15)),
  );

  static List<(int, int)> monthsCovering(CalendarDate from, CalendarDate to) {
    final out = <(int, int)>[];
    var d = from.firstOfMonth;
    while (d.isBefore(to)) {
      out.add((d.year, d.month));
      d = d.addMonths(1);
    }
    if (out.isEmpty) out.add((from.year, from.month));
    return out;
  }

  Future<bool> hasMonth(int year, int month) async =>
      (await _cache.window(monthKey(year, month))) != null;

  Future<void> refreshMonth(int year, int month) async {
    final (start, end) = monthWindow(year, month);
    final events = await _api.list(start: start, end: end);
    await _cache.putWindow(monthKey(year, month), events, now);
    await _ensureMasters(events);
    _emit();
  }

  /// Series masters (start + rule + zone) are needed for wall-clock display
  /// and for series ends; cached for 12 h.
  Future<void> _ensureMasters(List<CalendarEvent> events) async {
    final ids = events
        .where((e) => e.isRecurring && !e.isOverride)
        .map((e) => e.id)
        .toSet();
    for (final id in ids) {
      final fetched = await _cache.detailFetchedAt(id);
      if (fetched != null && now.difference(fetched) < const Duration(hours: 12)) {
        continue;
      }
      try {
        await _cache.putDetail(await _api.get(id), now);
      } on AppException catch (e) {
        DiagnosticLog.warn('calendar', 'series master fetch failed', error: e);
      }
    }
  }

  Future<CalendarEventDetail?> detail(String id, {bool refresh = false}) async {
    if (id.startsWith('local:')) return null;
    final cached = await _cache.detail(id);
    if (!refresh && cached != null) return cached;
    try {
      final d = await _api.get(id);
      await _cache.putDetail(d, now);
      return d;
    } on NetworkException {
      return cached;
    }
  }

  // ---- reading -------------------------------------------------------------

  Future<List<CalendarOccurrence>> occurrences({
    required CalendarDate from,
    required CalendarDate to,
    required tz.Location device,
  }) async {
    final events = <CalendarEvent>[];
    for (final (y, m) in monthsCovering(from.addDays(-1), to.addDays(1))) {
      final w = await _cache.window(monthKey(y, m));
      if (w != null) events.addAll(w.events);
    }
    final masters = <String, CalendarEvent>{};
    for (final id in events
        .where((e) => e.isRecurring && !e.isOverride)
        .map((e) => e.id)
        .toSet()) {
      final d = await _cache.detail(id);
      if (d != null) masters[id] = d.event;
    }
    return OccurrenceBuilder.build(
      events: events,
      masters: masters,
      ops: await _cache.ops(),
      from: from,
      to: to,
      device: device,
      selfId: _selfId(),
    );
  }

  /// Pending invitations from colleagues (one entry per series).
  Future<List<CalendarOccurrence>> invitations({
    required tz.Location device,
  }) async {
    final today = EventTime.dateIn(now, device);
    final list = await occurrences(
      from: today,
      to: today.addDays(92),
      device: device,
    );
    final self = _selfId();
    final seen = <String>{};
    return [
      for (final o in list)
        if (o.event.responseStatus == RsvpStatus.pending &&
            o.event.organizerId != self &&
            o.end.isAfter(now) &&
            seen.add(o.event.seriesKey))
          o,
    ];
  }

  /// Client-side search over cached windows (the API has no search).
  Future<List<CalendarOccurrence>> search(
    String query, {
    required tz.Location device,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return const [];
    final keys = await _cache.windowKeys();
    if (keys.isEmpty) return const [];
    final first = CalendarDate.parse('${keys.first}-01');
    final last = CalendarDate.parse('${keys.last}-01').addMonths(1);
    final list = await occurrences(from: first, to: last, device: device);
    bool hit(CalendarEvent e) =>
        e.title.toLowerCase().contains(q) ||
        e.location.toLowerCase().contains(q) ||
        e.description.toLowerCase().contains(q) ||
        e.organizerName.toLowerCase().contains(q);
    final upcoming = list.where((o) => o.end.isAfter(now));
    final past = list.where((o) => !o.end.isAfter(now)).toList().reversed;
    final seen = <String>{};
    return [
      for (final o in [...upcoming, ...past])
        if (hit(o.event) &&
            seen.add(o.event.isRecurring ? o.event.seriesKey : o.key))
          o,
    ].take(100).toList();
  }

  /// Flushes the outbox, then refreshes the months around [around] and the
  /// next weeks (offline reading of the coming month). Network errors
  /// propagate so the UI can show "offline"; cached data stays.
  Future<void> sync({
    required CalendarDate around,
    required tz.Location device,
  }) async {
    await flush();
    final today = EventTime.dateIn(now, device);
    final months = <(int, int)>{
      for (final d in [
        around.addMonths(-1),
        around,
        around.addMonths(1),
        today,
        today.addMonths(1),
        today.addMonths(2),
      ])
        (d.year, d.month),
    };
    for (final (y, m) in months) {
      await refreshMonth(y, m);
    }
    final keep = {
      for (final (y, m) in months) monthKey(y, m),
      for (var i = -6; i <= 6; i++)
        monthKey(today.addMonths(i).year, today.addMonths(i).month),
    };
    await _cache.dropWindowsExcept(keep);
  }

  // ---- writing -------------------------------------------------------------

  Future<String> create(EventDraft draft) async {
    final cid = _newId();
    await _cache.putOp(
      CalendarPlanner.planCreate(
        draft,
        clientEventId: cid,
        opId: _newId(),
        now: now,
      ),
    );
    await _cache.putReminders('local:$cid', draft.reminders);
    _emit();
    unawaited(flush());
    return cid;
  }

  Future<void> edit({
    required CalendarOccurrence occurrence,
    required EventDraft draft,
    required EditScope scope,
  }) async {
    final e = occurrence.event;
    if (e.id.startsWith('local:')) {
      await _editQueued(e.id.substring(6), draft);
      return;
    }
    final series = e.isRecurring || e.isOverride;
    final master = series ? await detail(e.seriesKey) : null;
    final own = series ? master : await detail(e.id);
    final stored = scope == EditScope.all && master != null ? master.event : e;
    final participants = (master ?? own)?.participants;
    final diff = CalendarPlanner.diff(
      occurrence: occurrence,
      stored: stored,
      // Unknown participants (offline, never opened) count as unchanged.
      participants:
          participants ??
          [
            for (final p in draft.participants)
              CalendarParticipant(
                role: 'required',
                responseStatus: RsvpStatus.pending,
                userId: p.userId,
                externalEmail: p.externalEmail,
              ),
          ],
      draft: draft,
      selfId: _selfId(),
    );
    final ops = CalendarPlanner.planEdit(
      occurrence: occurrence,
      master: master,
      draft: draft,
      scope: scope,
      diff: diff,
      selfId: _selfId(),
      now: now,
      newId: _newId,
    );
    for (final op in ops) {
      await _cache.putOp(op);
      final cid = op.clientEventId;
      if (cid != null) await _cache.putReminders('local:$cid', draft.reminders);
    }
    if (scope != EditScope.thisOccurrence) {
      await _cache.putReminders(e.seriesKey, draft.reminders);
    }
    _emit();
    unawaited(flush());
  }

  Future<void> _editQueued(String cid, EventDraft draft) async {
    for (final op in await _cache.ops()) {
      if (op.clientEventId != cid) continue;
      if (op.payload['maybe_sent'] == true) {
        throw const PlanError('QUEUED_ITEM_SENDING');
      }
      await _cache.putOp(
        op.copyWith(
          payload: {...op.payload, 'body': draft.toCreateBody()},
          status: OpStatus.queued,
          clearError: true,
        ),
      );
      await _cache.putReminders('local:$cid', draft.reminders);
      _emit();
      unawaited(flush());
      return;
    }
  }

  Future<void> delete({
    required CalendarOccurrence occurrence,
    required EditScope scope,
  }) async {
    final e = occurrence.event;
    if (e.id.startsWith('local:')) {
      final cid = e.id.substring(6);
      for (final op in await _cache.ops()) {
        if (op.clientEventId != cid) continue;
        if (op.payload['maybe_sent'] == true) {
          throw const PlanError('QUEUED_ITEM_SENDING');
        }
        await _cache.removeOp(op.id);
      }
      _emit();
      return;
    }
    final master = e.isRecurring || e.isOverride
        ? await detail(e.seriesKey)
        : null;
    for (final op in CalendarPlanner.planDelete(
      occurrence: occurrence,
      master: master,
      scope: scope,
      now: now,
      newId: _newId,
    )) {
      await _cache.putOp(op);
    }
    _emit();
    unawaited(flush());
  }

  Future<void> respond(CalendarEvent event, RsvpStatus status) async {
    for (final op in await _cache.ops()) {
      if (op.kind == CalendarOp.rsvp &&
          op.eventId == event.seriesKey &&
          op.isQueued) {
        await _cache.removeOp(op.id);
      }
    }
    await _cache.putOp(
      CalendarPlanner.planRsvp(
        event: event,
        status: status,
        now: now,
        opId: _newId(),
      ),
    );
    _emit();
    unawaited(flush());
  }

  Future<void> setLocalReminders(String eventKey, List<int> minutes) async {
    await _cache.putReminders(eventKey, minutes);
    _emit();
  }

  // ---- outbox --------------------------------------------------------------

  /// Failed or conflicting operations the user has to decide on.
  Future<List<CalendarOp>> problems() async =>
      (await _cache.ops()).where((o) => !o.isQueued).toList();

  Future<int> queuedCount() async => (await _cache.ops()).length;

  Future<void> discard(String opId) async {
    await _cache.removeOp(opId);
    _emit();
  }

  /// Re-queues a failed op; for a conflict, [overwrite] applies the local
  /// change on top of the newer server version.
  Future<void> retry(String opId, {bool overwrite = false}) async {
    final op = await _cache.op(opId);
    if (op == null) return;
    final payload = Map<String, dynamic>.from(op.payload);
    if (op.status == OpStatus.conflict && overwrite) {
      payload['base_sequence'] = payload.remove('server_sequence');
    }
    await _cache.putOp(
      op.copyWith(payload: payload, status: OpStatus.queued, clearError: true),
    );
    _emit();
    await flush();
  }

  /// Sends queued operations in order. Offline / 5xx keeps the queue; 4xx
  /// marks the op failed; a changed `sequence` marks it as a conflict.
  Future<void> flush() => _flushing ??= _flush().whenComplete(() {
    _flushing = null;
  });

  Future<void> _flush() async {
    var ran = false;
    try {
      while (true) {
        final op = (await _cache.ops()).where((o) => o.isQueued).firstOrNull;
        if (op == null) break;
        ran = true;
        if (await _run(op) == _Step.stop) break;
      }
    } finally {
      if (ran) _emit();
    }
  }

  Future<_Step> _run(CalendarOp op) async {
    try {
      switch (op.kind) {
        case CalendarOp.create:
          await _runCreate(op, Map<String, dynamic>.from(op.payload));
        case CalendarOp.patch:
          await _runPatch(op);
        case CalendarOp.exception:
          await _runException(op);
        case CalendarOp.overridePatch:
          await _runOverridePatch(op);
        case CalendarOp.cancelFollowing:
          await _runCancelFollowing(op);
        case CalendarOp.rsvp:
          await _runRsvp(op);
        case CalendarOp.recreate:
          await _runRecreate(op);
        default:
          await _cache.removeOp(op.id);
      }
      return _Step.next;
    } on NetworkException {
      return _Step.stop;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 429 || e.statusCode >= 500) {
        return _Step.stop;
      }
      DiagnosticLog.warn('calendar', 'op ${op.kind} rejected', error: e);
      await _fail(op, e.code);
      return _Step.next;
    } on PlanError catch (e) {
      await _fail(op, e.code);
      return _Step.next;
    } on AppException catch (e) {
      DiagnosticLog.warn('calendar', 'op ${op.kind} failed', error: e);
      return _Step.stop;
    }
  }

  Future<void> _fail(CalendarOp op, String code) async {
    final current = await _cache.op(op.id) ?? op;
    await _cache.putOp(
      current.copyWith(
        status: OpStatus.failed,
        errorCode: code,
        attempts: current.attempts + 1,
      ),
    );
  }

  /// Create without an idempotency key: the op is marked `maybe_sent`
  /// *before* the request, so after a timeout, a dropped connection or an
  /// app kill the next attempt first looks for the event on the server.
  Future<void> _runCreate(CalendarOp op, Map<String, dynamic> p) async {
    final body = Map<String, dynamic>.from(p['body'] as Map);
    final cid = p['client_event_id'] as String;
    var id = p['server_id'] as String?;
    if (id == null && p['maybe_sent'] == true) {
      id = await _reconcileCreate(body);
    }
    if (id == null) {
      p['maybe_sent'] = true;
      await _cache.putOp(op.copyWith(payload: p, attempts: op.attempts + 1));
      id = await _api.create(body);
    }
    await _cache.writeMeta('cid:$cid', id);
    await _cache.moveReminders('local:$cid', id);
    await _cache.removeOp(op.id);
    if (body['audience_type'] == 'selected_users') _notify(id, 'invited');
    await _refreshAfterWrite(
      id,
      EventTime.parse(body['starts_at'] as String?),
      series: (body['rrule'] as String?)?.isNotEmpty ?? false,
    );
  }

  Future<String?> _reconcileCreate(Map<String, dynamic> body) async {
    final start = EventTime.parse(body['starts_at'] as String?);
    final end = EventTime.parse(body['ends_at'] as String?);
    if (start == null || end == null) return null;
    final events = await _api.list(
      start: start.subtract(const Duration(minutes: 1)),
      end: end.add(const Duration(minutes: 1)),
    );
    final self = _selfId();
    final title = (body['title'] as String? ?? '').trim();
    final rule = (body['rrule'] as String?) ?? '';
    for (final e in events) {
      if (e.organizerId == self &&
          !e.isOverride &&
          !e.isCancelled &&
          e.title == title &&
          e.rrule == rule &&
          e.allDay == (body['all_day'] == true) &&
          e.startsAt.isAtSameMomentAs(start) &&
          e.endsAt.isAtSameMomentAs(end)) {
        DiagnosticLog.info('calendar', 'create reconciled with existing event');
        return e.id;
      }
    }
    return null;
  }

  /// Returns false when a conflict was recorded.
  Future<bool> _checkBase(CalendarOp op, String id) async {
    final base = (op.payload['base_sequence'] as num?)?.toInt();
    if (base == null) return true;
    final d = await _api.get(id);
    await _cache.putDetail(d, now);
    if (d.event.sequence == base) return true;
    await _cache.putOp(
      op.copyWith(
        status: OpStatus.conflict,
        errorCode: 'CONFLICT',
        payload: {...op.payload, 'server_sequence': d.event.sequence},
      ),
    );
    return false;
  }

  /// Our own PATCH increments `sequence`; later queued ops on the same event
  /// must not see that as someone else's change.
  Future<void> _bumpBase(String id, int? base) async {
    if (base == null) return;
    for (final other in await _cache.ops()) {
      if ((other.kind == CalendarOp.patch || other.kind == CalendarOp.recreate) &&
          other.eventId == id &&
          (other.payload['base_sequence'] as num?)?.toInt() == base) {
        await _cache.putOp(
          other.copyWith(payload: {...other.payload, 'base_sequence': base + 1}),
        );
      }
    }
  }

  Future<void> _runPatch(CalendarOp op) async {
    final p = op.payload;
    final id = p['event_id'] as String;
    if (!await _checkBase(op, id)) return;
    final body = Map<String, dynamic>.from(p['body'] as Map);
    await _api.patch(id, body);
    await _cache.removeOp(op.id);
    await _bumpBase(id, (p['base_sequence'] as num?)?.toInt());
    final kind = p['notify'] as String?;
    if (kind != null) _notify((p['notify_event_id'] as String?) ?? id, kind);
    await _refreshAfterWrite(id, EventTime.parse(body['starts_at'] as String?));
  }

  Future<void> _runException(CalendarOp op) async {
    final p = op.payload;
    final series = p['series_id'] as String;
    await _api.exception(
      series,
      occurrenceStart: p['occurrence_start'] as String,
      cancelled: p['cancelled'] == true,
      startsAt: EventTime.parse(p['starts_at'] as String?),
      endsAt: EventTime.parse(p['ends_at'] as String?),
    );
    await _cache.removeOp(op.id);
    final kind = p['notify'] as String?;
    if (kind != null) _notify(series, kind);
    await _refreshAfterWrite(series, EventTime.parse(p['starts_at'] as String?));
  }

  /// Text edit of one occurrence: the API can only move/cancel occurrences,
  /// so the occurrence is "moved" (creating an override event), the override
  /// is found in the listing and patched.
  Future<void> _runOverridePatch(CalendarOp op) async {
    final p = Map<String, dynamic>.from(op.payload);
    final series = p['series_id'] as String;
    final key = p['occurrence_start'] as String;
    final start = EventTime.parse(p['starts_at'] as String?)!;
    final end = EventTime.parse(p['ends_at'] as String?)!;
    var overrideId = p['override_id'] as String?;
    if (overrideId == null) {
      if (p['exception_done'] != true) {
        await _api.exception(
          series,
          occurrenceStart: key,
          startsAt: start,
          endsAt: end,
        );
        p['exception_done'] = true;
        await _cache.putOp(op.copyWith(payload: p));
      }
      final keyInstant = EventTime.parse(key)!;
      final events = await _api.list(
        start: start.subtract(const Duration(days: 1)),
        end: end.add(const Duration(days: 1)),
      );
      overrideId = events
          .where(
            (e) =>
                e.seriesId == series &&
                e.id != series &&
                (e.occurrenceStart?.isAtSameMomentAs(keyInstant) ?? false),
          )
          .map((e) => e.id)
          .firstOrNull;
      if (overrideId == null) throw const PlanError('OVERRIDE_NOT_FOUND');
      p['override_id'] = overrideId;
      await _cache.putOp(op.copyWith(payload: p));
    }
    final body = Map<String, dynamic>.from(p['body'] as Map);
    if (body.isNotEmpty) await _api.patch(overrideId, body);
    await _cache.removeOp(op.id);
    final kind = p['notify'] as String?;
    if (kind != null) _notify(series, kind);
    await _refreshAfterWrite(series, start);
  }

  /// "Delete this and following": there is no API to end a series (RRULE
  /// is read-only after creation), so every server occurrence from the key
  /// to the series end is cancelled individually (moved ones via their
  /// override event). Progress is persisted, so a retry continues.
  Future<void> _runCancelFollowing(CalendarOp op) async {
    final p = Map<String, dynamic>.from(op.payload);
    final series = p['series_id'] as String;
    final from = EventTime.parse(p['from'] as String?)!;
    var keys = (p['keys'] as List?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (keys == null) {
      final master = await _api.get(series);
      await _cache.putDetail(master, now);
      final end =
          EventTime.parse(p['until'] as String?) ??
          master.event.startsAt.add(serverSeriesHorizon);
      final found = <String, Map<String, dynamic>>{};
      for (var s = from; !s.isAfter(end); s = s.add(const Duration(days: 180))) {
        var e = s.add(const Duration(days: 180));
        if (e.isAfter(end)) e = end.add(const Duration(days: 1));
        for (final item in await _api.list(start: s, end: e)) {
          final inSeries = item.id == series || item.seriesId == series;
          final occ = item.occurrenceStart;
          if (!inSeries || occ == null || occ.isBefore(from) || occ.isAfter(end)) {
            continue;
          }
          final override = item.id != series;
          found[override ? 'ovr:${item.id}' : item.occurrenceStartRaw!] = {
            'occurrence_start': item.occurrenceStartRaw,
            if (override) 'override_id': item.id,
          };
        }
        if (found.length > followingCap) break;
      }
      if (found.length > followingCap) {
        throw const PlanError('TOO_MANY_OCCURRENCES');
      }
      keys = found.values.toList();
      p['keys'] = keys;
      await _cache.putOp(op.copyWith(payload: p));
    }
    while (keys.isNotEmpty) {
      final k = keys.first;
      final overrideId = k['override_id'] as String?;
      if (overrideId != null) {
        await _api.patch(overrideId, {'status': 'cancelled'});
      } else {
        await _api.exception(
          series,
          occurrenceStart: k['occurrence_start'] as String,
          cancelled: true,
        );
      }
      keys.removeAt(0);
      p['keys'] = keys;
      await _cache.putOp(op.copyWith(payload: p));
    }
    await _cache.removeOp(op.id);
    final kind = p['notify'] as String?;
    if (kind != null) _notify(series, kind);
    await _refreshAfterWrite(series, from);
  }

  Future<void> _runRsvp(CalendarOp op) async {
    final id = op.payload['event_id'] as String;
    final status = RsvpStatus.values.byName(op.payload['status'] as String);
    await _api.rsvp(id, status);
    await _cache.updateEvents(
      (e) => e.seriesKey == id && !e.isOverride,
      {'response_status': status.name},
    );
    await _cache.removeOp(op.id);
    _notify(id, 'rsvp');
    try {
      await _cache.putDetail(await _api.get(id), now);
    } on AppException {
      // the detail refreshes next time it is opened
    }
  }

  Future<void> _runRecreate(CalendarOp op) async {
    final p = Map<String, dynamic>.from(op.payload);
    final old = p['event_id'] as String;
    if (p['old_cancelled'] != true) {
      if (!await _checkBase(op, old)) return;
      await _api.patch(old, {'status': 'cancelled'});
      p['old_cancelled'] = true;
      await _cache.putOp(op.copyWith(payload: p));
      if (p['notify_old'] == true) _notify(old, 'cancelled');
    }
    await _runCreate(op, p);
  }

  void _notify(String eventId, String kind) {
    final relay = _relay;
    if (relay == null) return;
    unawaited(
      relay
          .notify(eventId, kind)
          .catchError(
            (Object e) =>
                DiagnosticLog.warn('calendar', 'relay notify failed', error: e),
          ),
    );
  }

  /// After a successful write: refresh the nearest cached months that show
  /// the event (and the month of its new start) so the view reflects the
  /// server, not the removed optimistic overlay.
  Future<void> _refreshAfterWrite(
    String id,
    DateTime? newStart, {
    bool series = false,
  }) async {
    final months = <(int, int)>{};
    final today = CalendarDate.of(now);
    final startMonth = newStart == null
        ? null
        : CalendarDate(newStart.year, newStart.month, 1);
    for (final key in await _cache.windowKeys()) {
      final d = CalendarDate.parse('$key-01');
      if (today.firstOfMonth.daysUntil(d).abs() > 62) continue;
      // A new series appears in every month from its start on.
      if (series && startMonth != null && !d.isBefore(startMonth)) {
        months.add((d.year, d.month));
        continue;
      }
      final w = await _cache.window(key);
      if (w != null && w.events.any((e) => e.id == id || e.seriesId == id)) {
        months.add((d.year, d.month));
      }
    }
    if (newStart != null) months.add((newStart.year, newStart.month));
    for (final (y, m) in months) {
      try {
        await refreshMonth(y, m);
      } on AppException catch (e) {
        DiagnosticLog.warn('calendar', 'refresh after write failed', error: e);
        return;
      }
    }
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> clear() async {
    await _cache.clear();
    _emit();
  }
}
