import 'dart:io';

import 'fake_http.dart';

class FakeCalendarUser {
  const FakeCalendarUser({
    required this.id,
    required this.token,
    required this.name,
    required this.org,
  });
  final String id;
  final String token;
  final String name;
  final String org;
}

/// In-memory stand-in for the `/calendar/*` part of the Mail API, following
/// the documented behaviour of openapi.yaml: strict bodies, PostgreSQL text
/// timestamps for stored events, RFC 3339 for expanded occurrences, series
/// expanded in UTC honouring only FREQ/INTERVAL, exceptions with override
/// events (returned twice to the organizer), sequence bumps, tenant scoping.
class FakeCalendarServer {
  FakeCalendarServer(this.http, this.users) {
    _routes();
  }

  final FakeHttpAdapter http;
  final List<FakeCalendarUser> users;

  final Map<String, Map<String, dynamic>> events = {};
  final Map<String, List<Map<String, dynamic>>> participants = {};
  final List<Map<String, dynamic>> exceptions = [];

  bool offline = false;
  bool dropNextCreateResponse = false;
  int createCalls = 0;
  int patchCalls = 0;
  int _seq = 0;

  /// Rooms (`CalendarResource` JSON) and their confirmed bookings.
  final List<Map<String, dynamic>> resources = [];
  final Map<String, List<(DateTime, DateTime)>> roomBookings = {};

  /// What `POST /calendar/find-time` answers (at most 5 are returned).
  List<(DateTime, DateTime)> suggestions = const [];

  static const _schedulingKeys = {
    'user_ids', 'start', 'end', 'duration_minutes', 'timezone', 'resource_id',
  };

  static const _createKeys = {
    'organization_id', 'title', 'description', 'starts_at', 'ends_at',
    'all_day', 'location', 'meeting_link', 'event_type', 'audience_type',
    'visibility', 'attendance', 'timezone', 'rrule', 'reminder_minutes',
    'user_ids', 'department_ids', 'external_emails', 'resource_id',
  };
  static const _patchKeys = {
    'title', 'description', 'starts_at', 'ends_at', 'location',
    'meeting_link', 'status',
  };
  static const _exceptionKeys = {
    'occurrence_start', 'starts_at', 'ends_at', 'cancelled',
  };

  FakeCalendarUser? _user(RecordedRequest r) {
    final auth = (r.headers['Authorization'] ?? r.headers['authorization'])
        ?.toString();
    final token = auth?.replaceFirst('Bearer ', '');
    return users.where((u) => u.token == token).firstOrNull;
  }

  static String pgText(DateTime t) {
    final u = t.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${u.year}-${two(u.month)}-${two(u.day)} ${two(u.hour)}:${two(u.minute)}:${two(u.second)}+00';
  }

  static String rfc(DateTime t) {
    final u = t.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${u.year}-${two(u.month)}-${two(u.day)}T${two(u.hour)}:${two(u.minute)}:${two(u.second)}Z';
  }

  static DateTime parse(String s) {
    final norm = s.contains('T') ? s : '${s.replaceFirst(' ', 'T')}:00';
    return DateTime.parse(norm).toUtc();
  }

  FakeResponse _err(int status, String code) =>
      FakeResponse.error(status, code);

  Map<String, dynamic> _public(Map<String, dynamic> row) => {
    for (final e in row.entries)
      if (!e.key.startsWith('_')) e.key: e.value,
  };

  bool _visible(Map<String, dynamic> row, FakeCalendarUser u) {
    if (row['organization_id'] != u.org) return false;
    final id = row['_series_id'] as String? ?? row['id'] as String;
    return row['organizer_id'] == u.id ||
        (participants[id] ?? const []).any((p) => p['user_id'] == u.id);
  }

  String? _rsvp(String seriesId, FakeCalendarUser u) =>
      (participants[seriesId] ?? const [])
              .where((p) => p['user_id'] == u.id)
              .firstOrNull?['response_status']
          as String?;

  void _routes() {
    http.on('GET', '/calendar/events', (r) {
      if (offline) throw const SocketException('offline');
      final u = _user(r);
      if (u == null) return _err(401, 'UNAUTHENTICATED');
      final ws = parse(r.query['start'] as String);
      final we = parse(r.query['end'] as String);
      final out = <Map<String, dynamic>>[];
      for (final row in events.values) {
        if (!_visible(row, u) || row['status'] == 'cancelled') continue;
        final start = parse(row['starts_at'] as String);
        final end = parse(row['ends_at'] as String);
        final rule = (row['rrule'] as String?) ?? '';
        if (rule.isEmpty) {
          if (start.isBefore(we) && end.isAfter(ws)) {
            final isOverride = row['_series_id'] != null;
            out.add({
              ..._public(row),
              if (!isOverride) ...{
                'response_status': ?_rsvp(row['id'] as String, u),
              },
              'managed': false,
            });
          }
          continue;
        }
        final parts = {
          for (final p in rule.split(';'))
            if (p.contains('=')) p.split('=')[0]: p.split('=')[1],
        };
        final interval = int.tryParse(parts['INTERVAL'] ?? '1') ?? 1;
        final duration = end.difference(start);
        var emitted = 0;
        for (var k = 0; k < 3700 && emitted < 370; k++) {
          final n = k * interval;
          final occ = switch (parts['FREQ']) {
            'DAILY' => start.add(Duration(days: n)),
            'WEEKLY' => start.add(Duration(days: 7 * n)),
            'MONTHLY' => DateTime.utc(start.year, start.month + n, start.day, start.hour, start.minute, start.second),
            _ => DateTime.utc(start.year + n, start.month, start.day, start.hour, start.minute, start.second),
          };
          if (!occ.isBefore(we)) break;
          if (!occ.add(duration).isAfter(ws)) continue;
          final exc = exceptions.where(
            (x) =>
                x['series_id'] == row['id'] &&
                (x['occurrence_start'] as DateTime).isAtSameMomentAs(occ),
          );
          if (exc.any((x) => x['cancelled'] == true)) continue;
          final moved = exc.where((x) => x['override_id'] != null).firstOrNull;
          emitted++;
          if (moved != null) {
            final ovr = events[moved['override_id']]!;
            if (ovr['status'] == 'cancelled') continue;
            out.add({
              ..._public(ovr),
              'series_id': row['id'],
              'occurrence_start': rfc(occ),
              'managed': false,
            });
            continue;
          }
          out.add({
            ..._public(row),
            'starts_at': rfc(occ),
            'ends_at': rfc(occ.add(duration)),
            'series_id': row['id'],
            'occurrence_start': rfc(occ),
            'response_status': ?_rsvp(row['id'] as String, u),
            'managed': false,
          });
        }
      }
      out.sort((a, b) => parse(a['starts_at'] as String).compareTo(parse(b['starts_at'] as String)));
      return FakeResponse(200, json: {'events': out});
    });

    http.on('POST', '/calendar/events', (r) {
      if (offline) throw const SocketException('offline');
      final u = _user(r);
      if (u == null) return _err(401, 'UNAUTHENTICATED');
      final body = r.json;
      if (body.keys.any((k) => !_createKeys.contains(k))) {
        return _err(400, 'INVALID_BODY');
      }
      if (((body['title'] as String?) ?? '').trim().isEmpty) {
        return _err(400, 'INVALID_TITLE');
      }
      final start = DateTime.tryParse((body['starts_at'] as String?) ?? '');
      final end = DateTime.tryParse((body['ends_at'] as String?) ?? '');
      if (start == null) return _err(400, 'INVALID_START');
      if (end == null || !end.isAfter(start)) return _err(400, 'INVALID_END');
      final room = (body['resource_id'] as String?) ?? '';
      if (room.isNotEmpty) {
        if (!resources.any((x) => x['id'] == room && x['status'] == 'active')) {
          return _err(400, 'INVALID_RESOURCE');
        }
        final taken = (roomBookings[room] ?? const [])
            .any((b) => b.$1.isBefore(end) && b.$2.isAfter(start));
        if (taken) return _err(409, 'ROOM_UNAVAILABLE');
        roomBookings.putIfAbsent(room, () => []).add((start.toUtc(), end.toUtc()));
      }
      createCalls++;
      final id = '00000000-0000-4000-8000-${(++_seq).toString().padLeft(12, '0')}';
      final audience = (body['audience_type'] as String?) ?? 'only_me';
      events[id] = {
        'id': id,
        'uid': '$id@calendar.xatbox',
        'sequence': 0,
        'organization_id': u.org,
        'organizer_id': u.id,
        'organizer_name': u.name,
        'title': (body['title'] as String).trim(),
        if ((body['description'] as String?)?.isNotEmpty ?? false)
          'description': body['description'],
        'location': body['location'] ?? '',
        'meeting_link': body['meeting_link'] ?? '',
        'event_type': body['event_type'] ?? (audience == 'only_me' ? 'personal' : 'meeting'),
        'audience_type': audience,
        'visibility': body['visibility'] ?? 'default',
        'attendance': body['attendance'] ?? 'invitation',
        'status': 'confirmed',
        'all_day': body['all_day'] == true,
        'starts_at': pgText(start),
        'ends_at': pgText(end),
        'timezone': body['timezone'] ?? 'UTC',
        if ((body['rrule'] as String?)?.isNotEmpty ?? false) 'rrule': body['rrule'],
        'reminder_minutes': body['reminder_minutes'] ?? 0,
      };
      participants[id] = [
        {
          'user_id': u.id,
          'display_name': u.name,
          'role': 'organizer',
          'response_status': 'accepted',
        },
        for (final uid in (body['user_ids'] as List?) ?? const [])
          {
            'user_id': uid,
            'display_name': users.firstWhere((x) => x.id == uid).name,
            'role': 'required',
            'response_status': 'pending',
          },
        for (final mail in (body['external_emails'] as List?) ?? const [])
          {'external_email': mail, 'role': 'required', 'response_status': 'pending'},
      ];
      if (dropNextCreateResponse) {
        dropNextCreateResponse = false;
        throw const SocketException('connection reset after commit');
      }
      return FakeResponse(201, json: {'id': id, 'uid': '$id@calendar.xatbox'});
    });

    FakeResponse? detailOr404(RecordedRequest r, String id) {
      final u = _user(r);
      if (u == null) return _err(401, 'UNAUTHENTICATED');
      final row = events[id];
      if (row == null || !_visible(row, u)) return _err(404, 'EVENT_NOT_FOUND');
      return null;
    }

    http.onPattern('GET', r'^/calendar/events/[^/]+$', (r) {
      if (offline) throw const SocketException('offline');
      final id = r.path.split('/').last;
      final e = detailOr404(r, id);
      if (e != null) return e;
      return FakeResponse(200, json: {
        'event': {..._public(events[id]!), 'managed': false},
        'participants': participants[id] ?? const [],
      });
    });

    http.onPattern('PATCH', r'^/calendar/events/[^/]+$', (r) {
      if (offline) throw const SocketException('offline');
      final id = r.path.split('/').last;
      final e = detailOr404(r, id);
      if (e != null) return e;
      final body = r.json;
      if (body.keys.any((k) => !_patchKeys.contains(k))) {
        return _err(400, 'INVALID_BODY');
      }
      patchCalls++;
      patchDirect(id, body);
      return const FakeResponse(200, json: {'status': 'ok'});
    });

    http.onPattern('POST', r'^/calendar/events/[^/]+/exceptions$', (r) {
      if (offline) throw const SocketException('offline');
      final id = r.path.split('/')[3];
      final row = events[id];
      if (row == null) return _err(404, 'EVENT_NOT_FOUND');
      if (((row['rrule'] as String?) ?? '').isEmpty) {
        return _err(400, 'NOT_RECURRING');
      }
      final e = detailOr404(r, id);
      if (e != null) return e;
      final body = r.json;
      if (body.keys.any((k) => !_exceptionKeys.contains(k))) {
        return _err(400, 'INVALID_BODY');
      }
      final occ = DateTime.parse(body['occurrence_start'] as String).toUtc();
      if (body['cancelled'] == true) {
        exceptions.add({'series_id': id, 'occurrence_start': occ, 'cancelled': true});
      } else {
        final ovrId = '00000000-0000-4000-9000-${(++_seq).toString().padLeft(12, '0')}';
        events[ovrId] = {
          ...row,
          'id': ovrId,
          'uid': '${row['uid']}#occ-${rfc(occ)}',
          'sequence': (row['sequence'] as int) + 1,
          'starts_at': pgText(DateTime.parse(body['starts_at'] as String)),
          'ends_at': pgText(DateTime.parse(body['ends_at'] as String)),
          '_series_id': id,
        }..remove('rrule');
        exceptions.add({
          'series_id': id,
          'occurrence_start': occ,
          'cancelled': false,
          'override_id': ovrId,
        });
      }
      return const FakeResponse(200, json: {'status': 'ok'});
    });

    /// Shared validation of `CalendarFreeBusyRequest` (strict keys, window,
    /// distinct users of the caller's organization).
    (FakeResponse?, FakeCalendarUser?, List<String>, DateTime, DateTime) scheduling(
      RecordedRequest r,
    ) {
      final epoch = DateTime.utc(1970);
      final u = _user(r);
      if (u == null) return (_err(401, 'UNAUTHENTICATED'), null, const [], epoch, epoch);
      final body = r.json;
      if (body.keys.any((k) => !_schedulingKeys.contains(k))) {
        return (_err(400, 'INVALID_BODY'), u, const [], epoch, epoch);
      }
      final start = DateTime.tryParse((body['start'] as String?) ?? '');
      if (start == null) return (_err(400, 'INVALID_START'), u, const [], epoch, epoch);
      final end = DateTime.tryParse((body['end'] as String?) ?? '');
      if (end == null || !end.isAfter(start) || end.difference(start) > const Duration(days: 62)) {
        return (_err(400, 'INVALID_END'), u, const [], epoch, epoch);
      }
      final ids = ((body['user_ids'] as List?) ?? const []).cast<String>();
      if (ids.toSet().length != ids.length ||
          ids.any((id) => !users.any((x) => x.id == id && x.org == u.org))) {
        return (_err(403, 'FORBIDDEN'), u, const [], epoch, epoch);
      }
      return (null, u, ids, start.toUtc(), end.toUtc());
    }

    http.on('POST', '/calendar/free-busy', (r) {
      if (offline) throw const SocketException('offline');
      final (error, u, ids, ws, we) = scheduling(r);
      if (error != null) return error;
      final busy = <String, List<Map<String, String>>>{};
      for (final id in ids) {
        final list = <(DateTime, DateTime)>[];
        for (final row in events.values) {
          if (row['organization_id'] != u!.org || row['status'] != 'confirmed') continue;
          if (((row['rrule'] as String?) ?? '').isNotEmpty || row['_series_id'] != null) continue;
          final involved = row['organizer_id'] == id ||
              (participants[row['id']] ?? const [])
                  .any((p) => p['user_id'] == id && p['response_status'] != 'declined');
          if (!involved) continue;
          final s = parse(row['starts_at'] as String);
          final e = parse(row['ends_at'] as String);
          if (s.isBefore(we) && e.isAfter(ws)) list.add((s, e));
        }
        list.sort((a, b) => a.$1.compareTo(b.$1));
        busy[id] = [for (final b in list) {'start': rfc(b.$1), 'end': rfc(b.$2)}];
      }
      final room = (r.json['resource_id'] as String?) ?? '';
      final roomBusy = [
        for (final b in roomBookings[room] ?? const <(DateTime, DateTime)>[])
          if (b.$1.isBefore(we) && b.$2.isAfter(ws)) {'start': pgText(b.$1), 'end': pgText(b.$2)},
      ];
      return FakeResponse(200, json: {'busy': busy, 'resource_busy': roomBusy});
    });

    http.on('POST', '/calendar/find-time', (r) {
      if (offline) throw const SocketException('offline');
      final (error, _, _, ws, we) = scheduling(r);
      if (error != null) return error;
      final slots = suggestions
          .where((s) => !s.$1.isBefore(ws) && !s.$2.isAfter(we))
          .take(5)
          .map((s) => {'start': rfc(s.$1), 'end': rfc(s.$2)})
          .toList();
      return FakeResponse(200, json: {'suggestions': slots});
    });

    http.on('GET', '/calendar/resources', (r) {
      if (offline) throw const SocketException('offline');
      if (_user(r) == null) return _err(401, 'UNAUTHENTICATED');
      return FakeResponse(200, json: {'resources': resources});
    });

    http.onPattern('POST', r'^/calendar/events/[^/]+/rsvp$', (r) {
      if (offline) throw const SocketException('offline');
      final u = _user(r);
      if (u == null) return _err(401, 'UNAUTHENTICATED');
      final id = r.path.split('/')[3];
      final p = (participants[id] ?? const [])
          .where((x) => x['user_id'] == u.id)
          .firstOrNull;
      if (p == null || events[id]?['organization_id'] != u.org) {
        return _err(404, 'EVENT_NOT_FOUND');
      }
      final status = r.json['status'] as String;
      if (!{'accepted', 'tentative', 'declined'}.contains(status)) {
        return _err(400, 'INVALID_RSVP');
      }
      p['response_status'] = status;
      return FakeResponse(200, json: {'status': status});
    });
  }

  /// Inserts an event as if created earlier (e.g. from webmail).
  String seedEvent({
    required FakeCalendarUser organizer,
    required String title,
    required DateTime start,
    required DateTime end,
    bool allDay = false,
    String timezone = 'Asia/Almaty',
    String? rrule,
    String location = '',
    String attendance = 'invitation',
    List<FakeCalendarUser> guests = const [],
  }) {
    final id = '00000000-0000-4000-7000-${(++_seq).toString().padLeft(12, '0')}';
    events[id] = {
      'id': id,
      'uid': '$id@calendar.xatbox',
      'sequence': 0,
      'organization_id': organizer.org,
      'organizer_id': organizer.id,
      'organizer_name': organizer.name,
      'title': title,
      'location': location,
      'meeting_link': '',
      'event_type': guests.isEmpty ? 'personal' : 'meeting',
      'audience_type': guests.isEmpty ? 'only_me' : 'selected_users',
      'visibility': 'default',
      'attendance': attendance,
      'status': 'confirmed',
      'all_day': allDay,
      'starts_at': pgText(start),
      'ends_at': pgText(end),
      'timezone': timezone,
      'rrule': ?rrule,
      'reminder_minutes': 15,
    };
    participants[id] = [
      {'user_id': organizer.id, 'display_name': organizer.name, 'role': 'organizer', 'response_status': 'accepted'},
      for (final g in guests)
        {'user_id': g.id, 'display_name': g.name, 'role': 'required', 'response_status': 'pending'},
    ];
    return id;
  }

  /// A change made "from another device" (or through the PATCH route).
  void patchDirect(String id, Map<String, dynamic> body) {
    final row = events[id]!;
    for (final e in body.entries) {
      if (e.value == null) continue;
      if (e.key == 'title' && (e.value as String).trim().isEmpty) continue;
      if (e.key == 'starts_at' || e.key == 'ends_at') {
        row[e.key] = pgText(DateTime.parse(e.value as String));
      } else {
        row[e.key] = e.value;
      }
    }
    row['sequence'] = (row['sequence'] as int) + 1;
  }
}
