import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/api/api_error_codes.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../../shared/utils/error_text.dart';
import '../../calendar/domain/calendar_time.dart';
import '../../calendar/presentation/calendar_providers.dart';
import '../data/mail_message_extras.dart';
import 'mail_error_text.dart';
import 'mail_providers.dart';

/// Card for an `.ics` / `text/calendar` attachment: parsed invitation,
/// current response and accept / maybe / decline.
class InvitationCard extends ConsumerStatefulWidget {
  const InvitationCard({
    super.key,
    required this.messageId,
    required this.blobId,
  });

  final String messageId;
  final String blobId;

  @override
  ConsumerState<InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends ConsumerState<InvitationCard> {
  MailInvitationPreview? _preview;
  Object? _error;
  bool _loading = true;
  MailRsvp? _sending;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final preview = await ref
          .read(mailApiProvider)
          .calendarInvitation(widget.messageId, blobId: widget.blobId);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _loading = false;
      });
    } on AppException catch (e) {
      DiagnosticLog.warn('mail', 'calendar invitation failed', error: e);
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _respond(MailRsvp status) async {
    final preview = _preview;
    if (preview == null || _sending != null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = status);
    try {
      final res = await ref
          .read(mailApiProvider)
          .respondToInvitation(
            widget.messageId,
            blobId: preview.blobId.isNotEmpty ? preview.blobId : widget.blobId,
            status: status,
          );
      if (!mounted) return;
      setState(
        () => _preview = preview.copyWith(
          eventId: res.eventId.isNotEmpty ? res.eventId : null,
          status: res.status.isNotEmpty ? res.status : status.name,
        ),
      );
      messenger.showSnackBar(SnackBar(content: Text(l10n.mailInviteSaved)));
    } on AppException catch (e) {
      DiagnosticLog.warn('mail', 'invitation respond failed', error: e);
      messenger.showSnackBar(
        SnackBar(content: Text(MailErrorText.describe(l10n, e))),
      );
    } finally {
      if (mounted) setState(() => _sending = null);
    }
  }

  static String statusText(AppLocalizations l10n, String? status) =>
      switch (status) {
        'accepted' => l10n.mailInviteStatusAccepted,
        'tentative' => l10n.mailInviteStatusTentative,
        'declined' => l10n.mailInviteStatusDeclined,
        _ => l10n.mailInviteStatusPending,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final preview = _preview;

    Widget frame(List<Widget> children) => Card(
      key: const Key('invitation_card'),
      margin: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.sm),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.calendar, color: tokens.brand),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    l10n.mailInviteTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            ...children,
          ],
        ),
      ),
    );

    if (_loading && preview == null) {
      return frame(const [LinearProgressIndicator(minHeight: 2)]);
    }
    if (preview == null) {
      final err = _error!;
      final code = err is ApiException ? err.code : null;
      final retryable =
          code != ApiErrorCodes.invalidIcs &&
          code != ApiErrorCodes.icsTooLarge &&
          code != ApiErrorCodes.icsNotFound;
      return frame([
        Row(
          children: [
            Icon(
              ErrorText.isOffline(err) ? LucideIcons.wifiOff : LucideIcons.circleAlert,
              size: 18,
              color: tokens.textMuted,
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                MailErrorText.describe(l10n, err),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (retryable)
              TextButton(onPressed: _load, child: Text(l10n.retry)),
          ],
        ),
      ]);
    }

    final inv = preview.invitation;
    final muted = theme.textTheme.bodySmall?.copyWith(color: tokens.textMuted);
    final busy = _sending != null;
    final canOpen =
        preview.eventId != null &&
        inv.method != MailInvitationMethod.reply;

    Widget rsvpButton(MailRsvp status, String label, IconData icon) {
      final current = preview.status == status.name;
      final child = _sending == status
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18);
      final onPressed = busy ? null : () => _respond(status);
      return current
          ? FilledButton.icon(
              key: Key('invite_${status.name}'),
              onPressed: onPressed,
              icon: child,
              label: Text(label),
            )
          : OutlinedButton.icon(
              key: Key('invite_${status.name}'),
              onPressed: onPressed,
              icon: child,
              label: Text(label),
            );
    }

    return frame([
      Wrap(
        spacing: Space.sm,
        children: [
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(switch (inv.method) {
              MailInvitationMethod.request => l10n.mailInviteMethodRequest,
              MailInvitationMethod.cancel => l10n.mailInviteMethodCancel,
              MailInvitationMethod.reply => l10n.mailInviteMethodReply,
            }),
          ),
          if (inv.rrule != null)
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(l10n.mailInviteRecurring),
            ),
        ],
      ),
      const SizedBox(height: Space.xs),
      Text(
        inv.title.isEmpty ? l10n.mailNoSubject : inv.title,
        style: theme.textTheme.titleMedium?.copyWith(
          decoration: inv.isCancelled ? TextDecoration.lineThrough : null,
        ),
      ),
      ..._timeLines(context, inv, muted),
      if (inv.location.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: Space.xs),
          child: Row(
            children: [
              Icon(LucideIcons.mapPin, size: 16, color: tokens.textMuted),
              const SizedBox(width: Space.xs),
              Expanded(child: Text(inv.location, style: muted)),
            ],
          ),
        ),
      if (inv.organizerLabel.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: Space.xs),
          child: Text(l10n.mailInviteOrganizer(inv.organizerLabel), style: muted),
        ),
      const SizedBox(height: Space.sm),
      if (inv.method == MailInvitationMethod.reply) ...[
        Text(
          l10n.mailInviteReplyFrom(
            inv.attendees.isNotEmpty ? inv.attendees.first : inv.organizerLabel,
            statusText(l10n, inv.partstat),
          ),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: Space.sm),
        OutlinedButton.icon(
          key: const Key('invite_apply_reply'),
          onPressed: busy
              ? null
              : () => _respond(MailRsvp.tryParse(inv.partstat) ?? MailRsvp.accepted),
          icon: const Icon(LucideIcons.refreshCw, size: 18),
          label: Text(l10n.mailInviteApplyReply),
        ),
      ] else if (inv.isCancelled) ...[
        Text(
          l10n.mailInviteCancelledNote,
          style: theme.textTheme.bodyMedium?.copyWith(color: tokens.danger),
        ),
        const SizedBox(height: Space.sm),
        OutlinedButton.icon(
          key: const Key('invite_apply_cancel'),
          onPressed: busy ? null : () => _respond(MailRsvp.declined),
          icon: const Icon(LucideIcons.calendarX, size: 18),
          label: Text(l10n.mailInviteApplyCancel),
        ),
      ] else ...[
        Text(
          l10n.mailInviteYourStatus(statusText(l10n, preview.status)),
          key: const Key('invite_status'),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            rsvpButton(MailRsvp.accepted, l10n.mailInviteAccept, LucideIcons.check),
            rsvpButton(
              MailRsvp.tentative,
              l10n.mailInviteMaybe,
              LucideIcons.circleHelp,
            ),
            rsvpButton(MailRsvp.declined, l10n.mailInviteDecline, LucideIcons.x),
          ],
        ),
      ],
      if (canOpen)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('invite_open_calendar'),
            onPressed: () =>
                context.push(Routes.calendarEventPath(preview.eventId!)),
            icon: const Icon(LucideIcons.calendarDays, size: 18),
            label: Text(l10n.mailInviteOpenCalendar),
          ),
        ),
    ]);
  }

  List<Widget> _timeLines(
    BuildContext context,
    MailCalendarInvitation inv,
    TextStyle? style,
  ) {
    final start = inv.startsAt;
    if (start == null) return const [];
    final l10n = context.l10n;
    final device = CalendarZones.location(ref.watch(deviceZoneProvider));
    final lines = [
      Padding(
        padding: const EdgeInsets.only(top: Space.xs),
        child: Text(
          _range(context, start, inv.endsAt, device),
          key: const Key('invite_time'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    ];
    if (CalendarZones.isKnown(inv.timezone) && inv.timezone != device.name) {
      lines.add(
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            l10n.mailInviteInZone(
              _range(
                context,
                start,
                inv.endsAt,
                CalendarZones.location(inv.timezone),
              ),
              inv.timezone.replaceAll('_', ' '),
            ),
            style: style,
          ),
        ),
      );
    }
    return lines;
  }

  static String _range(
    BuildContext context,
    DateTime start,
    DateTime? end,
    tz.Location zone,
  ) {
    final locale = Localizations.localeOf(context).toString();
    DateTime wall(DateTime i) {
      final w = EventTime.inZone(i, zone);
      return DateTime(w.year, w.month, w.day, w.hour, w.minute);
    }

    final full = DateFormat.yMMMEd(locale).add_Hm();
    final s = wall(start);
    if (end == null || !end.isAfter(start)) return full.format(s);
    final e = wall(end);
    final sameDay =
        EventTime.dateIn(start, zone) ==
        EventTime.dateIn(end.subtract(const Duration(seconds: 1)), zone);
    return sameDay
        ? '${full.format(s)}–${DateFormat.Hm(locale).format(e)}'
        : '${full.format(s)} – ${full.format(e)}';
  }
}
