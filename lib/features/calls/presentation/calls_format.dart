import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../shared/utils/error_text.dart';
import '../data/call_models.dart';
import 'call_controller.dart';

abstract final class CallsFormat {
  static String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  static String endReason(AppLocalizations l10n, String? reason) => switch (reason) {
    CallEndReasons.declined => l10n.callsEndedDeclined,
    CallEndReasons.busy => l10n.callsEndedBusy,
    CallEndReasons.missed => l10n.callsEndedMissed,
    CallEndReasons.cancelled => l10n.callsEndedCancelled,
    CallEndReasons.failed => l10n.callsEndedFailed,
    CallEndReasons.network => l10n.callsEndedNetwork,
    CallEndReasons.answeredElsewhere => l10n.callsEndedElsewhere,
    CallEndReasons.removed => l10n.callsEndedRemoved,
    CallEndReasons.permission => l10n.callsPermissionNeeded,
    _ => l10n.callsEndedHangup,
  };

  static String outcome(AppLocalizations l10n, CallInfo c, String selfId) => switch (c.outcome) {
    CallOutcome.missed => l10n.callsOutcomeMissed,
    CallOutcome.declined => l10n.callsOutcomeDeclined,
    CallOutcome.cancelled => l10n.callsOutcomeCancelled,
    CallOutcome.busy => l10n.callsOutcomeBusy,
    CallOutcome.failed => l10n.callsOutcomeFailed,
    _ => c.isOutgoingFor(selfId) ? l10n.callsOutgoing : l10n.callsIncomingShort,
  };

  /// Result for the call card: «Состоялся» instead of the direction.
  static String result(AppLocalizations l10n, CallInfo c) => switch (c.outcome) {
    CallOutcome.answered => l10n.callsOutcomeAnswered,
    CallOutcome.unknown => c.durationSec > 0 ? l10n.callsOutcomeAnswered : '',
    _ => outcome(l10n, c, ''),
  };

  static String direction(AppLocalizations l10n, CallInfo c, String selfId) =>
      c.isOutgoingFor(selfId) ? l10n.callsOutgoing : l10n.callsIncomingShort;

  static String mode(AppLocalizations l10n, String mode) => switch (mode) {
    'group' => l10n.callsModeGroup,
    'conference' => l10n.callsModeConference,
    _ => l10n.callsModeDirect,
  };

  static String role(AppLocalizations l10n, String role) => switch (role) {
    'host' => l10n.callsHost,
    'moderator' => l10n.callsModerator,
    _ => l10n.callsRoleParticipant,
  };

  static String participantStatus(AppLocalizations l10n, ParticipantStatus s) => switch (s) {
    ParticipantStatus.invited => l10n.callsPStatusInvited,
    ParticipantStatus.ringing => l10n.callsPStatusRinging,
    ParticipantStatus.accepted => l10n.callsPStatusAccepted,
    ParticipantStatus.joined => l10n.callsPStatusJoined,
    ParticipantStatus.left => l10n.callsPStatusLeft,
    ParticipantStatus.declined => l10n.callsPStatusDeclined,
    ParticipantStatus.missed => l10n.callsPStatusMissed,
    ParticipantStatus.busy => l10n.callsPStatusBusy,
    ParticipantStatus.removed => l10n.callsPStatusRemoved,
    ParticipantStatus.unknown => '',
  };

  /// Full date and time for the call card.
  static String dateTime(BuildContext context, DateTime? t) {
    if (t == null) return '';
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMd(locale).add_Hm().format(t.toLocal());
  }

  /// Day header of the history: «Сегодня», «Вчера», «14 сентября», or with
  /// the year for older calls.
  static String day(BuildContext context, DateTime day) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final d = DateTime(day.year, day.month, day.day);
    if (d == DateTime(now.year, now.month, now.day)) return l10n.chatToday;
    if (d == DateTime(now.year, now.month, now.day - 1)) return l10n.chatYesterday;
    final locale = Localizations.localeOf(context).toString();
    return (d.year == now.year ? DateFormat.MMMMd(locale) : DateFormat.yMMMMd(locale)).format(d);
  }

  /// Time of day only (rows under a day header).
  static String time(BuildContext context, DateTime? t) {
    if (t == null) return '';
    return DateFormat.Hm(Localizations.localeOf(context).toString()).format(t.toLocal());
  }

  static String when(BuildContext context, DateTime? t) {
    if (t == null) return '';
    final local = t.toLocal();
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).toString();
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      return DateFormat.Hm(locale).format(local);
    }
    return DateFormat.MMMd(locale).add_Hm().format(local);
  }

  static String error(AppLocalizations l10n, Object e) {
    if (e is ApiException) {
      switch (e.code) {
        case 'NOT_MODERATOR':
        case 'NOT_HOST':
          return l10n.callsErrNotModerator;
        case 'ALREADY_IN_CALL':
          return l10n.callsErrAlreadyInCall;
        case 'TOO_MANY_PARTICIPANTS':
          return l10n.callsErrTooMany;
        case 'INVALID_PARTICIPANTS':
          return l10n.callsErrInvalidParticipants;
        case 'RATE_LIMITED':
          return l10n.callsErrRateLimited;
        case 'CALL_NOT_FOUND':
          return l10n.callsErrNotFound;
        case 'FEATURE_DISABLED':
          return l10n.callsErrRecordingDisabled;
        case 'RECORDING_ALREADY_ACTIVE':
          return l10n.callsErrRecordingActive;
        case 'RECORDING_UNAVAILABLE':
        case 'RECORDING_NOT_READY':
        case 'RECORDING_NOT_ACTIVE':
        case 'CALL_NOT_ACTIVE':
          return l10n.callsErrRecordingUnavailable;
        case 'MEETING_NOT_FOUND':
          return l10n.meetingNotFound;
        case 'MEETING_NOT_STARTED':
          return l10n.meetingNotStarted;
        case 'MEETING_ENDED':
          return l10n.meetingEnded;
        case 'MEETING_CANCELLED':
          return l10n.meetingCancelled;
        case 'NOT_ORGANIZER':
          return l10n.callsErrNotOrganizer;
        case 'LOBBY_ALREADY_DECIDED':
        case 'GUEST_NOT_FOUND':
          return l10n.callsErrLobbyDecided;
        case 'GUESTS_NOT_ALLOWED':
        case 'GUEST_LINK_EXPIRED':
          return l10n.callsErrGuests;
        case 'TRANSCRIPTION_BUSY':
          return l10n.callsErrTranscriptBusy;
        case 'TRANSCRIPT_NOT_FOUND':
          return l10n.callsTranscriptFailed;
      }
    }
    return ErrorText.describe(l10n, e);
  }

  /// `12,4 МБ` / `12.4 MB`.
  static String fileSize(BuildContext context, int bytes) {
    final ru = const {'ru', 'kk'}.contains(Localizations.localeOf(context).languageCode);
    final units = ru ? const ['Б', 'КБ', 'МБ', 'ГБ'] : const ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final fixed = value.toStringAsFixed(1);
    final text = unit == 0 || value >= 100 || fixed.endsWith('.0') ? value.round().toString() : fixed;
    return '${ru ? text.replaceAll('.', ',') : text} ${units[unit]}';
  }
}
