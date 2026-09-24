import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/error_text.dart';
import '../data/calendar_models.dart';
import '../data/calendar_ops.dart';
import '../domain/calendar_time.dart';
import '../domain/recurrence.dart';

/// Text and colour helpers for the calendar UI. Times are always rendered in
/// the device zone passed in (never `DateTime.toLocal`).
abstract final class CalendarFormat {
  static String _locale(BuildContext context) =>
      Localizations.localeOf(context).toString();

  static String hm(BuildContext context, DateTime instant, tz.Location zone) =>
      DateFormat.Hm(_locale(context)).format(_wall(instant, zone));

  /// Wall time as a plain DateTime for `intl` (which knows no zones).
  static DateTime _wall(DateTime instant, tz.Location zone) {
    final w = EventTime.inZone(instant, zone);
    return DateTime(w.year, w.month, w.day, w.hour, w.minute);
  }

  static String monthTitle(BuildContext context, CalendarDate d) =>
      toBeginningOfSentenceCase(
        DateFormat.yMMMM(_locale(context)).format(d.forFormatting),
      );

  static String dayTitle(BuildContext context, CalendarDate d) =>
      toBeginningOfSentenceCase(
        DateFormat.MMMMEEEEd(_locale(context)).format(d.forFormatting),
      );

  static String shortDate(BuildContext context, CalendarDate d) =>
      DateFormat.yMMMd(_locale(context)).format(d.forFormatting);

  static String weekdayShort(BuildContext context, int isoWeekday) =>
      DateFormat.E(_locale(context)).format(
        CalendarDate(2026, 9, 14).addDays(isoWeekday - 1).forFormatting,
      );

  static String weekTitle(BuildContext context, CalendarDate monday) {
    final end = monday.addDays(6);
    final f = DateFormat.MMMd(_locale(context));
    return '${f.format(monday.forFormatting)} – ${f.format(end.forFormatting)}';
  }

  /// "09:00–10:00", "Весь день", or a multi-day span.
  static String timeRange(
    BuildContext context,
    CalendarOccurrence o,
    tz.Location zone,
  ) {
    final l10n = context.l10n;
    if (o.allDay) {
      final last = o.allDayEnd!.addDays(-1);
      if (last == o.allDayStart) return l10n.calendarAllDay;
      return '${shortDate(context, o.allDayStart!)} – ${shortDate(context, last)}';
    }
    final sameDay =
        EventTime.dateIn(o.start, zone) ==
        EventTime.dateIn(o.end.subtract(const Duration(seconds: 1)), zone);
    if (sameDay) return '${hm(context, o.start, zone)}–${hm(context, o.end, zone)}';
    final f = DateFormat.MMMd(_locale(context)).add_Hm();
    return '${f.format(_wall(o.start, zone))} – ${f.format(_wall(o.end, zone))}';
  }

  /// Full date line for the detail screen.
  static String when(
    BuildContext context,
    CalendarOccurrence o,
    tz.Location zone,
  ) {
    if (o.allDay) {
      return '${dayTitle(context, o.allDayStart!)} · ${timeRange(context, o, zone)}';
    }
    return '${dayTitle(context, EventTime.dateIn(o.start, zone))} · ${timeRange(context, o, zone)}';
  }

  static String recurrence(AppLocalizations l10n, BuildContext context, RecurrenceSpec? spec) {
    if (spec == null) return l10n.calendarRepeatNone;
    if (spec.hasUnsupportedParts) return l10n.calendarRepeatCustom;
    final base = switch (spec.frequency) {
      _ when spec.interval <= 1 => switch (spec.frequency) {
        RepeatFrequency.daily => l10n.calendarRepeatDaily,
        RepeatFrequency.weekly => l10n.calendarRepeatWeekly,
        RepeatFrequency.monthly => l10n.calendarRepeatMonthly,
        RepeatFrequency.yearly => l10n.calendarRepeatYearly,
      },
      RepeatFrequency.daily => l10n.calendarRepeatEveryDays(spec.interval),
      RepeatFrequency.weekly => l10n.calendarRepeatEveryWeeks(spec.interval),
      RepeatFrequency.monthly => l10n.calendarRepeatEveryMonths(spec.interval),
      RepeatFrequency.yearly => l10n.calendarRepeatEveryYears(spec.interval),
    };
    if (spec.count != null) return '$base, ${l10n.calendarRepeatTimes(spec.count!)}';
    if (spec.until != null) {
      return '$base, ${l10n.calendarRepeatUntil(shortDate(context, CalendarDate.of(spec.until!)))}';
    }
    return base;
  }

  static String reminder(AppLocalizations l10n, int minutes) {
    if (minutes == 0) return l10n.calendarReminderAtStart;
    if (minutes % 1440 == 0) return l10n.calendarReminderDays(minutes ~/ 1440);
    if (minutes % 60 == 0) return l10n.calendarReminderHours(minutes ~/ 60);
    return l10n.calendarReminderMinutes(minutes);
  }

  static String rsvp(AppLocalizations l10n, RsvpStatus s) => switch (s) {
    RsvpStatus.pending => l10n.calendarRsvpPending,
    RsvpStatus.accepted => l10n.calendarRsvpAccepted,
    RsvpStatus.tentative => l10n.calendarRsvpTentativeStatus,
    RsvpStatus.declined => l10n.calendarRsvpDeclined,
  };

  static IconData rsvpIcon(RsvpStatus s) => switch (s) {
    RsvpStatus.pending => LucideIcons.circleHelp,
    RsvpStatus.accepted => LucideIcons.circleCheck,
    RsvpStatus.tentative => LucideIcons.circleHelp,
    RsvpStatus.declined => LucideIcons.circleX,
  };

  static Color rsvpColor(XatBoxTokens t, RsvpStatus s) => switch (s) {
    RsvpStatus.pending => t.textMuted,
    RsvpStatus.accepted => t.success,
    RsvpStatus.tentative => t.warning,
    RsvpStatus.declined => t.danger,
  };

  static String category(AppLocalizations l10n, String type) => switch (type) {
    'meeting' => l10n.calendarCategoryMeeting,
    'department' => l10n.calendarCategoryDepartment,
    'organization' => l10n.calendarCategoryOrganization,
    _ => l10n.calendarCategoryPersonal,
  };

  /// Category colour from the design tokens' palette (the API has no colour
  /// field; `event_type` is the category).
  static Color color(BuildContext context, CalendarEvent e) {
    final t = context.tokens;
    final name = switch (e.eventType) {
      'meeting' => 'violet',
      'department' => 'amber',
      'organization' => 'teal',
      _ => 'sky',
    };
    return t.folderColor(name, fallback: t.brand);
  }

  static String zoneLabel(String zone) => zone.replaceAll('_', ' ');

  /// Calendar error codes (Mail API + planner) on top of the shared mapping.
  static String error(AppLocalizations l10n, Object e) {
    final code = switch (e) {
      ApiException(:final code) => code,
      PlanError(:final code) => code,
      _ => null,
    };
    switch (code) {
      case 'INVALID_TITLE':
        return l10n.calendarErrTitle;
      case 'INVALID_START':
      case 'INVALID_END':
      case 'INVALID_TIME':
      case 'INVALID_EVENT':
        return l10n.calendarErrTime;
      case 'INVALID_LINK':
        return l10n.calendarErrLink;
      case 'INVALID_TIMEZONE':
        return l10n.calendarErrTimezone;
      case 'INVALID_AUDIENCE':
      case 'INVALID_PARTICIPANTS':
        return l10n.calendarErrAudience;
      case 'ROOM_UNAVAILABLE':
        return l10n.calendarErrRoom;
      case 'USER_MEETINGS_DISABLED':
        return l10n.calendarErrMeetingsDisabled;
      case 'MANDATORY_EVENT':
        return l10n.calendarMandatoryCannotDecline;
      case 'EVENT_NOT_FOUND':
        return l10n.calendarEventNotFound;
      case 'FORBIDDEN':
        return l10n.calendarNotOrganizer;
      case 'TOO_MANY_OCCURRENCES':
        return l10n.calendarErrTooManyOccurrences;
      case 'MASTER_UNAVAILABLE':
        return l10n.calendarErrOffline;
      case 'QUEUED_ITEM_SENDING':
        return l10n.calendarErrSending;
      case 'SCOPE_UNSUPPORTED':
        return l10n.calendarErrScope;
      case 'OVERRIDE_NOT_FOUND':
        return l10n.calendarErrOverride;
      case 'CONFLICT':
        return l10n.calendarConflictTitle;
    }
    if (e is PlanError) return l10n.errUnknown(e.code);
    return ErrorText.describe(l10n, e);
  }
}
