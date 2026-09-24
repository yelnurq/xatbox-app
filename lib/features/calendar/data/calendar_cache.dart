import 'package:sembast/sembast.dart';

import '../../../core/storage/app_database.dart';
import 'calendar_models.dart';
import 'calendar_ops.dart';

/// Local calendar data (ТЗ п.24.16/24.17): server windows per month (for
/// offline reading), event details, the outbox of queued changes, local
/// reminder settings and the ids of scheduled notifications.
class CalendarCache {
  CalendarCache(this._db);
  final AppDatabase _db;

  static final _windows = stringMapStoreFactory.store('calendar_windows');
  static final _details = stringMapStoreFactory.store('calendar_details');
  static final _outbox = stringMapStoreFactory.store('calendar_outbox');
  static final _reminders = stringMapStoreFactory.store('calendar_reminders');
  static final _meta = stringMapStoreFactory.store('calendar_meta');

  // ---- windows -------------------------------------------------------------

  Future<CachedWindow?> window(String monthKey) async {
    final row = await _windows.record(monthKey).get(_db.db);
    if (row == null) return null;
    return CachedWindow(
      fetchedAt: DateTime.parse(row['fetched_at']! as String),
      events: ((row['events'] as List?) ?? const [])
          .map(
            (e) => CalendarEvent.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }

  Future<void> putWindow(
    String monthKey,
    List<CalendarEvent> events,
    DateTime fetchedAt,
  ) => _windows.record(monthKey).put(_db.db, {
    'fetched_at': fetchedAt.toUtc().toIso8601String(),
    'events': events.map((e) => e.toJson()).toList(),
  });

  Future<List<String>> windowKeys() async =>
      (await _windows.findKeys(_db.db)).toList()..sort();

  /// Rewrites cached copies of a series/event (e.g. after an RSVP) so the
  /// offline view stays consistent until the next refresh.
  Future<void> updateEvents(
    bool Function(CalendarEvent e) match,
    Map<String, dynamic> changes,
  ) async {
    for (final key in await windowKeys()) {
      final w = await window(key);
      if (w == null) continue;
      if (!w.events.any(match)) continue;
      final events = [
        for (final e in w.events) match(e) ? e.copyWithRaw(changes) : e,
      ];
      await putWindow(key, events, w.fetchedAt);
    }
  }

  Future<void> dropWindowsExcept(Set<String> keep) async {
    for (final key in await windowKeys()) {
      if (!keep.contains(key)) await _windows.record(key).delete(_db.db);
    }
  }

  // ---- details -------------------------------------------------------------

  Future<CalendarEventDetail?> detail(String id) async {
    final row = await _details.record(id).get(_db.db);
    return row == null
        ? null
        : CalendarEventDetail.fromJson(
            Map<String, dynamic>.from(row['detail']! as Map),
          );
  }

  Future<DateTime?> detailFetchedAt(String id) async {
    final row = await _details.record(id).get(_db.db);
    final raw = row?['fetched_at'] as String?;
    return raw == null ? null : DateTime.parse(raw);
  }

  Future<void> putDetail(CalendarEventDetail d, DateTime fetchedAt) =>
      _details.record(d.event.id).put(_db.db, {
        'fetched_at': fetchedAt.toUtc().toIso8601String(),
        'detail': d.toJson(),
      });

  // ---- outbox --------------------------------------------------------------

  Future<List<CalendarOp>> ops() async {
    final rows = await _outbox.find(
      _db.db,
      finder: Finder(sortOrders: [SortOrder('created_at'), SortOrder('seq')]),
    );
    return rows
        .map((r) => CalendarOp.fromJson(Map<String, dynamic>.from(r.value)))
        .toList();
  }

  Future<CalendarOp?> op(String id) async {
    final row = await _outbox.record(id).get(_db.db);
    return row == null
        ? null
        : CalendarOp.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> putOp(CalendarOp op) =>
      _outbox.record(op.id).put(_db.db, op.toJson());

  Future<void> removeOp(String id) => _outbox.record(id).delete(_db.db);

  // ---- local reminders (minutes before start, per event/series) -----------

  Future<List<int>?> reminders(String eventKey) async {
    final row = await _reminders.record(eventKey).get(_db.db);
    return (row?['minutes'] as List?)?.map((e) => (e as num).toInt()).toList();
  }

  Future<Map<String, List<int>>> allReminders() async {
    final rows = await _reminders.find(_db.db);
    return {
      for (final r in rows)
        r.key: ((r.value['minutes'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
    };
  }

  Future<void> putReminders(String eventKey, List<int> minutes) =>
      _reminders.record(eventKey).put(_db.db, {'minutes': minutes});

  Future<void> moveReminders(String from, String to) async {
    final m = await reminders(from);
    if (m == null) return;
    await putReminders(to, m);
    await _reminders.record(from).delete(_db.db);
  }

  // ---- meta ----------------------------------------------------------------

  Future<String?> readMeta(String key) async =>
      (await _meta.record(key).get(_db.db))?['value'] as String?;

  Future<void> writeMeta(String key, String value) =>
      _meta.record(key).put(_db.db, {'value': value});

  Future<Set<int>> scheduledReminderIds() async {
    final row = await _meta.record('scheduled_ids').get(_db.db);
    return ((row?['ids'] as List?) ?? const [])
        .map((e) => (e as num).toInt())
        .toSet();
  }

  Future<void> putScheduledReminderIds(Set<int> ids) =>
      _meta.record('scheduled_ids').put(_db.db, {'ids': ids.toList()});

  Future<CalendarCacheStats> stats() async => CalendarCacheStats(
    windows: await _windows.count(_db.db),
    details: await _details.count(_db.db),
    queued: await _outbox.count(_db.db),
  );

  /// Settings → clear cache: drops server copies only; queued changes and
  /// local reminders survive (they are not on the server yet / device-only).
  Future<void> clearServerCopies() async {
    await _windows.delete(_db.db);
    await _details.delete(_db.db);
  }

  /// Sign-out: wipes everything (queued changes included).
  Future<void> clear() async {
    await _windows.delete(_db.db);
    await _details.delete(_db.db);
    await _outbox.delete(_db.db);
    await _reminders.delete(_db.db);
    await _meta.delete(_db.db);
  }
}

class CachedWindow {
  const CachedWindow({required this.fetchedAt, required this.events});
  final DateTime fetchedAt;
  final List<CalendarEvent> events;
}

class CalendarCacheStats {
  const CalendarCacheStats({
    required this.windows,
    required this.details,
    required this.queued,
  });
  final int windows;
  final int details;
  final int queued;
}
