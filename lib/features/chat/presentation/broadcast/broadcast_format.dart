import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/localization/localization.dart';
import '../chat_formatters.dart';

/// Error text of the channel / poll / scheduling / reminder calls.
String broadcastErrorText(AppLocalizations l10n, Object e) {
  if (e is ApiException) {
    switch (e.code) {
      case 'POLL_CLOSED':
        return l10n.pollClosed;
      case 'CHANNEL_READ_ONLY':
        return l10n.channelReadOnly;
      case 'INVALID_SEND_AT':
        return l10n.scheduleTooEarly;
      case 'INVALID_POLL':
        return l10n.pollErrorOptions;
      case 'WHEN_ONLINE_UNAVAILABLE':
        return l10n.scheduleWhenOnlineUnavailable;
    }
  }
  return ChatFormat.error(l10n, e);
}

/// «сегодня в 19:00» / «завтра в 09:00» / «18 сентября в 10:30».
String formatWhen(BuildContext context, DateTime at, {DateTime? now}) {
  final l10n = context.l10n;
  final locale = Localizations.localeOf(context).toString();
  final local = at.toLocal();
  final n = (now ?? DateTime.now()).toLocal();
  final time = DateFormat.Hm(locale).format(local);
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(local.year, local.month, local.day);
  if (day == today) return l10n.chatWhenToday(time);
  if (day == DateTime(n.year, n.month, n.day + 1)) {
    return l10n.chatWhenTomorrow(time);
  }
  final date = local.year == n.year
      ? DateFormat.MMMMd(locale).format(local)
      : DateFormat.yMMMd(locale).format(local);
  return l10n.chatWhenDate(date, time);
}
