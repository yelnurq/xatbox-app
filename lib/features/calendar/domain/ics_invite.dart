import 'package:flutter/foundation.dart';

/// The first event of an iCalendar file (a `.ics` opened with XatBox), as
/// wall-clock times: [zone] is the TZID, `UTC` for `…Z` times, null for
/// floating ones (pure, unit-tested).
@immutable
class IcsInvite {
  const IcsInvite({
    required this.title,
    required this.start,
    required this.end,
    this.location = '',
    this.description = '',
    this.allDay = false,
    this.zone,
  });

  final String title;
  final String location;
  final String description;

  /// Wall-clock start and end in [zone] (dates only when [allDay]; the end
  /// is exclusive, as in iCalendar).
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String? zone;

  static IcsInvite? parse(String text) {
    // Unfold: a line that starts with a space or tab continues the previous.
    final lines = text.replaceAll('\r\n', '\n').replaceAll(RegExp('\n[ \t]'), '').split('\n');
    var inEvent = false;
    final props = <String, ({Map<String, String> params, String value})>{};
    for (final line in lines) {
      if (line.toUpperCase() == 'BEGIN:VEVENT') {
        inEvent = true;
        continue;
      }
      if (line.toUpperCase() == 'END:VEVENT') break;
      if (!inEvent) continue;
      final colon = _valueColon(line);
      if (colon < 0) continue;
      final head = line.substring(0, colon).split(';');
      final name = head.first.toUpperCase();
      final params = <String, String>{
        for (final p in head.skip(1))
          if (p.contains('=')) p.substring(0, p.indexOf('=')).toUpperCase(): p.substring(p.indexOf('=') + 1).replaceAll('"', ''),
      };
      props.putIfAbsent(name, () => (params: params, value: line.substring(colon + 1)));
    }
    final dtStart = props['DTSTART'];
    if (dtStart == null) return null;
    final start = _time(dtStart.value);
    if (start == null) return null;
    final allDay = dtStart.params['VALUE']?.toUpperCase() == 'DATE' || dtStart.value.trim().length == 8;
    final dtEnd = props['DTEND'];
    var end = dtEnd == null ? null : _time(dtEnd.value);
    end ??= allDay ? start.add(const Duration(days: 1)) : start.add(_duration(props['DURATION']?.value) ?? const Duration(hours: 1));
    final utc = dtStart.value.trim().toUpperCase().endsWith('Z');
    return IcsInvite(
      title: _text(props['SUMMARY']?.value ?? ''),
      location: _text(props['LOCATION']?.value ?? ''),
      description: _text(props['DESCRIPTION']?.value ?? ''),
      start: start,
      end: end.isAfter(start) ? end : start.add(allDay ? const Duration(days: 1) : const Duration(hours: 1)),
      allDay: allDay,
      zone: utc ? 'UTC' : dtStart.params['TZID'],
    );
  }

  /// The colon between the name and the value (a quoted parameter may hold one).
  static int _valueColon(String line) {
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      if (line[i] == '"') quoted = !quoted;
      if (line[i] == ':' && !quoted) return i;
    }
    return -1;
  }

  /// `20260918T140000Z`, `20260918T140000`, `20260918` → wall-clock time.
  static DateTime? _time(String raw) {
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?)?').firstMatch(raw.trim());
    if (m == null) return null;
    int g(int i) => int.parse(m.group(i) ?? '0');
    return DateTime(g(1), g(2), g(3), g(4), g(5), g(6));
  }

  /// `PT1H30M`, `P1D`.
  static Duration? _duration(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'^P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$').firstMatch(raw.trim());
    if (m == null) return null;
    int g(int i) => int.tryParse(m.group(i) ?? '') ?? 0;
    return Duration(days: g(1) * 7 + g(2), hours: g(3), minutes: g(4), seconds: g(5));
  }

  /// TEXT values: `\n`, `\,`, `\;`, `\\` unescaped.
  static String _text(String raw) => raw
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\N', '\n')
      .replaceAll(r'\,', ',')
      .replaceAll(r'\;', ';')
      .replaceAll(r'\\', r'\')
      .trim();
}
