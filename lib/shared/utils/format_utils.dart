import 'package:intl/intl.dart';

abstract final class FormatUtils {
  static String bytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Compact date for list rows: time today, day+month this year, else date.
  static String listDate(DateTime? date, String locale, {DateTime? now}) {
    if (date == null) return '';
    final local = date.toLocal();
    final today = (now ?? DateTime.now()).toLocal();
    if (local.year == today.year &&
        local.month == today.month &&
        local.day == today.day) {
      return DateFormat.Hm(locale).format(local);
    }
    // Same as the web `formatDate`: "12 Sep" this year, "12 Sep 2025" otherwise.
    if (local.year == today.year) return DateFormat.MMMd(locale).format(local);
    return DateFormat.yMMMd(locale).format(local);
  }

  static String fullDate(DateTime? date, String locale) {
    if (date == null) return '';
    return DateFormat.yMMMd(locale).add_Hm().format(date.toLocal());
  }
}
