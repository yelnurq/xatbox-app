/// Recipient handling for `POST /mail/send`: the server accepts only bare
/// `local@domain` addresses (no display-name form), trims and lowercases.
abstract final class EmailAddress {
  static final _bare = RegExp(
    r'^[^\s@<>"(),;:]+@[^\s@<>"(),;:]+\.[^\s@<>"(),;:]+$',
  );

  static bool isBare(String value) => _bare.hasMatch(value.trim());

  /// Splits comma/semicolon/whitespace separated input into trimmed,
  /// lowercased addresses (empty entries dropped). Does NOT validate.
  static List<String> split(String input) => input
      .split(RegExp(r'[,;\s]+'))
      .map((s) => s.trim().toLowerCase())
      .where((s) => s.isNotEmpty)
      .toList();

  /// Returns the first invalid address in [addresses], or null.
  static String? firstInvalid(Iterable<String> addresses) {
    for (final a in addresses) {
      if (!isBare(a)) return a;
    }
    return null;
  }

  /// Distinct addresses, preserving order and case-insensitively.
  static List<String> dedupe(Iterable<String> addresses) {
    final seen = <String>{};
    final out = <String>[];
    for (final a in addresses) {
      final key = a.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) continue;
      out.add(key);
    }
    return out;
  }
}
