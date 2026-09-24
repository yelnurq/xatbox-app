/// Parses the two timestamp formats the API emits:
/// * RFC 3339 (`2026-08-20T08:49:50Z`) from the mail store;
/// * PostgreSQL text form (`2026-08-20 08:49:50.801968+00`) in
///   `bookmark:<id>` listings, notifications and delivery events.
DateTime? parseApiDate(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;
  final direct = DateTime.tryParse(s);
  if (direct != null) return direct;

  var normalized = s;
  // "YYYY-MM-DD HH:MM:SS" → "YYYY-MM-DDTHH:MM:SS"
  if (normalized.length > 10 && normalized[10] == ' ') {
    normalized = '${normalized.substring(0, 10)}T${normalized.substring(11)}';
  }
  // Trailing "+00" / "-05" (no minutes) → "+00:00".
  final tz = RegExp(r'([+-]\d{2})$').firstMatch(normalized);
  if (tz != null) normalized = '$normalized:00';
  // Trailing "+0500" → "+05:00".
  final tz4 = RegExp(r'([+-]\d{2})(\d{2})$').firstMatch(normalized);
  if (tz4 != null && !normalized.contains(RegExp(r'[+-]\d{2}:\d{2}$'))) {
    normalized = normalized.replaceRange(
      tz4.start,
      tz4.end,
      '${tz4[1]}:${tz4[2]}',
    );
  }
  // Dart accepts at most 6 fractional digits.
  normalized = normalized.replaceFirstMapped(
    RegExp(r'\.(\d{7,})'),
    (m) => '.${m[1]!.substring(0, 6)}',
  );
  return DateTime.tryParse(normalized);
}
