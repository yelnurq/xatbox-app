import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../shared/utils/error_text.dart';
import '../data/task_models.dart';

/// Texts of the tasks screens (dates, priorities, task error codes).
abstract final class TasksFormat {
  /// "14 сент., 18:00" (year added when it is not the current one).
  static String when(DateTime at, String locale, {DateTime? now}) {
    final local = at.toLocal();
    final today = (now ?? DateTime.now()).toLocal();
    final date = local.year == today.year
        ? DateFormat.MMMd(locale)
        : DateFormat.yMMMd(locale);
    return date.add_Hm().format(local);
  }

  static String time(DateTime at, String locale) =>
      DateFormat.Hm(locale).format(at.toLocal());

  static String priority(AppLocalizations l10n, String priority) =>
      switch (priority) {
        TaskPriority.low => l10n.tasksPriorityLow,
        TaskPriority.high => l10n.tasksPriorityHigh,
        TaskPriority.urgent => l10n.tasksPriorityUrgent,
        _ => l10n.tasksPriorityNormal,
      };

  /// [assigning]: a 403 means the colleague cannot be assigned to.
  static String error(
    AppLocalizations l10n,
    Object error, {
    bool assigning = false,
  }) {
    if (error is ApiException) {
      switch (error.code) {
        case 'TASK_NOT_FOUND':
          return l10n.tasksNotFound;
        case 'INVALID_TASK':
          return l10n.tasksErrInvalid;
        case 'INVALID_OWNER':
          return l10n.tasksErrOwner;
        case 'INVALID_REMINDER':
          return l10n.tasksErrReminder;
        case 'BOARD_NOT_FOUND':
          return l10n.taskBoardErrNotFound;
        case 'INVALID_BOARD':
          return l10n.taskBoardErrName;
        case 'INVALID_MEMBER':
        case 'INVALID_ROLE':
          return l10n.taskBoardErrMember;
        case 'FORBIDDEN' when assigning:
          return l10n.tasksErrForbidden;
      }
    }
    return ErrorText.describe(l10n, error);
  }
}
