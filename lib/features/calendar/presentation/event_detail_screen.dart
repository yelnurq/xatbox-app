import 'dart:async';

import 'package:flutter/foundation.dart' show mergeSort;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/lifecycle/app_visibility.dart';
import '../../../core/localization/localization.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/state_view.dart';
import '../../calls/data/meetings.dart';
import '../../calls/presentation/calls_providers.dart';
import '../data/calendar_models.dart';
import '../data/calendar_ops.dart';
import '../domain/calendar_time.dart';
import 'calendar_format.dart';
import 'calendar_providers.dart';
import 'calendar_widgets.dart';
import 'event_edit_screen.dart' show EventEditArgs, reminderPresets;
import '../../../shared/widgets/app_sheet.dart';
import '../../mail/presentation/mail_undo_send.dart';
import '../../mail/presentation/compose_window.dart';
import '../../mail/presentation/compose_screen.dart';

/// One event: time in the device zone (and in the event zone when they
/// differ), repeat rule, participants with their answers, the caller's RSVP,
/// local reminders, edit/delete for the organizer.
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.occurrenceStart,
    this.initial,
    this.onClose,
  });

  final String eventId;
  final String? occurrenceStart;
  final CalendarOccurrence? initial;

  /// Desktop side panel: ✕ instead of ←, and what closes it (after a delete
  /// too).
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lookup = ref.watch(calendarOccurrenceProvider((eventId, occurrenceStart)));
    final occ = lookup.value ?? initial;
    if (occ == null) {
      return Scaffold(
        appBar: AppBar(),
        body: lookup.isLoading
            ? const StateView.loading()
            : StateView.error(message: l10n.calendarEventNotFound, icon: LucideIcons.calendarX),
      );
    }
    final e = occ.event;
    final selfId = ref.read(calendarRepositoryProvider).selfId;
    final isOrganizer = e.organizerId == selfId;
    final canEdit = canEditOccurrence(ref, occ);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: onClose == null,
        leading: onClose == null
            ? null
            : IconButton(key: const Key('event_panel_close'), tooltip: l10n.close, icon: const Icon(LucideIcons.x), onPressed: onClose),
        actions: [
          if (canEdit) ...[
            IconButton(
              key: const Key('event_edit'),
              tooltip: l10n.calendarEdit,
              icon: const Icon(LucideIcons.pencil),
              onPressed: () => _edit(context, occ),
            ),
            IconButton(
              key: const Key('event_delete'),
              tooltip: l10n.calendarDelete,
              icon: const Icon(LucideIcons.trash2),
              onPressed: () => _delete(context, ref, occ),
            ),
          ],
        ],
      ),
      body: _Body(occurrence: occ, isOrganizer: isOrganizer),
    );
  }

  Future<void> _edit(BuildContext context, CalendarOccurrence occ) async {
    final e = occ.event;
    var scope = EditScope.single;
    if ((e.isRecurring || e.isOverride) && occ.localId == null) {
      final picked = await askScope(context, delete: false);
      if (picked == null) return;
      scope = picked;
    }
    if (!context.mounted) return;
    await openEventEditor(context, EventEditArgs.edit(occurrence: occ, scope: scope));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, CalendarOccurrence occ) async {
    final l10n = context.l10n;
    final e = occ.event;
    var scope = EditScope.single;
    if ((e.isRecurring || e.isOverride) && occ.localId == null) {
      final picked = await askScope(context, delete: true);
      if (picked == null) return;
      scope = picked;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(l10n.calendarDeleteConfirm),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            FilledButton(
              key: const Key('confirm_delete'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.calendarDelete),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(calendarRepositoryProvider).delete(occurrence: occ, scope: scope);
      if (context.mounted) (onClose ?? context.pop)();
    } on PlanError catch (err) {
      messenger.showSnackBar(SnackBar(content: Text(CalendarFormat.error(l10n, err))));
    } on AppException catch (err) {
      messenger.showSnackBar(SnackBar(content: Text(CalendarFormat.error(l10n, err))));
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.occurrence, required this.isOrganizer});
  final CalendarOccurrence occurrence;
  final bool isOrganizer;

  /// Desktop: the department heading of [p] (externals together).
  static String _group(AppLocalizations l10n, CalendarParticipant p) => p.isExternal
      ? l10n.desktopCalendarExternalGroup
      : (p.departmentName.isNotEmpty ? p.departmentName : l10n.desktopCalendarNoDepartment);

  /// Desktop: [people] by department name, externals last (stable).
  static List<CalendarParticipant> _byDepartment(List<CalendarParticipant> people) {
    int rank(CalendarParticipant p) => p.isExternal ? 2 : (p.departmentName.isEmpty ? 1 : 0);
    final sorted = [...people];
    mergeSort(sorted, compare: (a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.departmentName.toLowerCase().compareTo(b.departmentName.toLowerCase());
    });
    return sorted;
  }

  /// Desktop «Написать участникам»: a new letter to everyone on the event
  /// (but oneself), the event's title as the subject.
  void _emailParticipants(WidgetRef ref, CalendarEvent e, List<CalendarParticipant> people) {
    final self = ref.read(calendarRepositoryProvider).selfId;
    final to = <String>{
      for (final p in people)
        if (p.userId != self)
          if ((p.isExternal ? (p.externalEmail ?? p.email) : p.email).trim() case final a when a.isNotEmpty) a,
    };
    openCompose(
      ref,
      ComposeArgs(
        mode: ComposeMode.blank,
        restore: ComposeSnapshot(modeName: ComposeMode.blank.name, to: to.join(', '), subject: e.title),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final zone = ref.watch(deviceLocationProvider);
    final deviceZone = ref.watch(deviceZoneProvider);
    final o = occurrence;
    final e = o.event;
    final local = e.id.startsWith('local:');
    final detailAsync = local
        ? const AsyncData<CalendarEventDetail?>(null)
        : ref.watch(calendarDetailProvider(e.seriesKey));
    final detail = detailAsync.value;
    final selfId = ref.read(calendarRepositoryProvider).selfId;
    final myStatus = e.responseStatus ?? detail?.participantFor(selfId)?.responseStatus;
    final others = (detail?.participants ?? const <CalendarParticipant>[])
        .where((p) => !p.isOrganizer)
        .toList();
    // As the web: people grouped by department, externals last.
    final people = _byDepartment(others);
    final eventZone = CalendarZones.isKnown(e.timezone) ? e.timezone : null;
    final calleeIds = {
      for (final p in detail?.participants ?? const <CalendarParticipant>[])
        if (p.userId != null && p.userId!.isNotEmpty && p.userId != selfId) p.userId!,
    }.toList();
    final callsOn = ref.watch(callsEnabledProvider);
    final canJoin = callsOn && calleeIds.isNotEmpty && !e.isCancelled;
    final meetingCode = XatBoxMeetingLinks.meetingCodeIn('${e.meetingLink}\n${e.description}');

    Widget row(IconData icon, Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 20, color: tokens.textMuted)),
          const SizedBox(width: Space.md),
          Expanded(child: child),
        ],
      ),
    );

    return ListView(
      key: const Key('event_detail'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category colour: the category is named by the chip below.
              ExcludeSemantics(
                child: Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.only(top: 6, right: Space.md),
                  decoration: BoxDecoration(
                    color: CalendarFormat.color(context, e),
                    borderRadius: BorderRadius.circular(Space.xs),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title, style: theme.textTheme.headlineSmall),
                    Wrap(
                      spacing: Space.xs,
                      runSpacing: Space.xs,
                      children: [
                        Chip(label: Text(CalendarFormat.category(l10n, e.eventType)), visualDensity: VisualDensity.compact),
                        if (e.isMandatory)
                          Chip(
                            avatar: Icon(LucideIcons.circleAlert, size: 16, color: tokens.warning),
                            label: Text(l10n.calendarMandatory),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (e.isCancelled)
                          Chip(label: Text(l10n.calendarCancelled), visualDensity: VisualDensity.compact),
                        if (o.pending)
                          Chip(
                            avatar: const Icon(LucideIcons.cloudUpload, size: 16),
                            label: Text(l10n.calendarPendingSync),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        row(
          LucideIcons.clock,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(CalendarFormat.when(context, o, zone), key: const Key('event_when')),
              if (!o.allDay && eventZone != null && eventZone != deviceZone)
                Text(
                  l10n.calendarEventTimeInZone(
                    CalendarFormat.timeRange(context, o, CalendarZones.location(eventZone)),
                    CalendarFormat.zoneLabel(eventZone),
                  ),
                  style: TextStyle(color: tokens.textMuted),
                ),
            ],
          ),
        ),
        if (e.isRecurring || e.isOverride)
          row(LucideIcons.repeat, Text(CalendarFormat.recurrence(l10n, context, e.recurrence ?? detail?.event.recurrence))),
        if (e.location.isNotEmpty) row(LucideIcons.mapPin, Text(e.location)),
        if (e.meetingLink.isNotEmpty)
          row(
            LucideIcons.link,
            Semantics(
              link: true,
              child: InkWell(
                onTap: () => launchUrl(Uri.parse(e.meetingLink), mode: LaunchMode.externalApplication),
                // The underlined text stays compact; the hit area is ≥ 48 dp.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: 1,
                    child: Text(e.meetingLink, style: TextStyle(color: tokens.info, decoration: TextDecoration.underline)),
                  ),
                ),
              ),
            ),
          ),
        if (meetingCode != null && callsOn && !o.allDay && !e.isCancelled)
          _MeetingJoinCard(code: meetingCode, occurrence: o)
        else if (e.audienceType != 'only_me' || e.conferenceUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A video call with the internal participants (Call Service):
                // one colleague → direct, several → conference.
                FilledButton.tonalIcon(
                  key: const Key('event_join_call'),
                  onPressed: canJoin ? () => _joinCall(context, ref, e, calleeIds) : null,
                  icon: const Icon(LucideIcons.video),
                  label: Text(l10n.calendarJoinCall),
                ),
                if (!canJoin) ...[
                  const SizedBox(height: Space.xs),
                  Text(l10n.calendarJoinCallSoon, style: theme.textTheme.bodySmall?.copyWith(color: tokens.textMuted)),
                ],
              ],
            ),
          ),
        if (e.description.isNotEmpty) row(LucideIcons.notepadText, SelectableText(e.description)),
        if (e.organizerName.isNotEmpty) row(LucideIcons.user, Text(l10n.calendarOrganizer(e.organizerName))),
        if (!isOrganizer && myStatus != null && !e.isCancelled) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.xs),
            child: Text(l10n.calendarYourAnswer, style: theme.textTheme.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: _RsvpButtons(event: e, status: myStatus),
          ),
        ],
        if (others.isNotEmpty) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
            child: Row(
              children: [
                Expanded(child: Text(l10n.calendarFieldParticipants, style: theme.textTheme.titleSmall)),
                // As the web: a letter to everyone invited.
                TextButton.icon(
                  key: const Key('event_email_participants'),
                  onPressed: () => _emailParticipants(ref, e, detail?.participants ?? others),
                  icon: const Icon(LucideIcons.mail, size: 16),
                  label: Text(l10n.desktopCalendarEmailParticipants),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
            child: Text(
              l10n.calendarRsvpSummary(
                others.where((p) => p.responseStatus == RsvpStatus.accepted).length,
                others.where((p) => p.responseStatus == RsvpStatus.tentative).length,
                others.where((p) => p.responseStatus == RsvpStatus.declined).length,
                others.where((p) => p.responseStatus == RsvpStatus.pending).length,
              ),
              key: const Key('rsvp_summary'),
              style: TextStyle(color: tokens.textMuted),
            ),
          ),
          for (final (i, p) in people.indexed) ...[
            if (i == 0 || _group(l10n, p) != _group(l10n, people[i - 1]))
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
                child: Text(
                  _group(l10n, p).toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: tokens.textMuted),
                ),
              ),
            ListTile(
              key: ValueKey('participant_${p.userId ?? p.externalEmail}'),
              dense: true,
              leading: InitialsAvatar(label: p.label, colorKey: p.userId ?? p.externalEmail, radius: 16),
              title: Text(p.label),
              subtitle: Text(
                [
                  if (p.isExternal) l10n.calendarExternal,
                  if (p.departmentName.isNotEmpty) p.departmentName,
                ].join(' · '),
              ),
              trailing: Tooltip(
                message: CalendarFormat.rsvp(l10n, p.responseStatus),
                child: Icon(
                  CalendarFormat.rsvpIcon(p.responseStatus),
                  color: CalendarFormat.rsvpColor(tokens, p.responseStatus),
                ),
              ),
            ),
          ],
        ] else if (detailAsync.isLoading && e.audienceType != 'only_me')
          const Padding(
            padding: EdgeInsets.all(Space.md),
            child: Center(child: CircularProgressIndicator()),
          ),
        const Divider(),
        _Reminders(event: e),
        const SizedBox(height: Space.xl),
      ],
    );
  }
}

/// A XatBox video meeting: a big «Подключиться» from 10 minutes before the
/// start until an hour after the end; it opens the pre-join screen.
class _MeetingJoinCard extends ConsumerStatefulWidget {
  const _MeetingJoinCard({required this.code, required this.occurrence});
  final String code;
  final CalendarOccurrence occurrence;

  @override
  ConsumerState<_MeetingJoinCard> createState() => _MeetingJoinCardState();
}

class _MeetingJoinCardState extends ConsumerState<_MeetingJoinCard> {
  ForegroundPeriodic? _tick;

  @override
  void initState() {
    super.initState();
    // Re-checks the join window; paused while the app is hidden and caught
    // up on return.
    _tick = ForegroundPeriodic(ref.read(appVisibilityProvider), const Duration(seconds: 30), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final o = widget.occurrence;
    final now = ref.watch(calendarClockProvider)();
    final opens = o.start.subtract(const Duration(minutes: 10));
    final canJoin = !now.isBefore(opens) && now.isBefore(o.end.add(const Duration(hours: 1)));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            key: const Key('event_meeting_join'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: canJoin ? () => context.push(Routes.meetPath(widget.code)) : null,
            icon: const Icon(LucideIcons.video),
            label: Text(l10n.meetingJoin),
          ),
          if (now.isBefore(opens)) ...[
            const SizedBox(height: Space.xs),
            Text(
              l10n.meetingOpensSoonHint,
              key: const Key('event_meeting_hint'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Starts a video call with the event's internal participants and opens the
/// call screen (the controller shows progress and errors there).
Future<void> _joinCall(BuildContext context, WidgetRef ref, CalendarEvent e, List<String> ids) async {
  if (!ref.read(callsEnabledProvider) || ids.isEmpty) return;
  final router = GoRouter.of(context);
  final future = ref.read(callControllerProvider.notifier).startCall(
    calleeIds: ids,
    video: true,
    mode: ids.length > 1 ? 'conference' : 'direct',
    title: e.title,
  );
  unawaited(router.push(Routes.call));
  await future;
}

class _RsvpButtons extends ConsumerWidget {
  const _RsvpButtons({required this.event, required this.status});
  final CalendarEvent event;
  final RsvpStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SegmentedButton<RsvpStatus>(
      key: const Key('rsvp_buttons'),
      emptySelectionAllowed: true,
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: RsvpStatus.accepted, label: Text(l10n.calendarRsvpAccept), icon: const Icon(LucideIcons.check)),
        ButtonSegment(value: RsvpStatus.tentative, label: Text(l10n.calendarRsvpTentative)),
        ButtonSegment(
          value: RsvpStatus.declined,
          label: Text(l10n.calendarRsvpDecline),
          enabled: !event.isMandatory,
          tooltip: event.isMandatory ? l10n.calendarMandatoryCannotDecline : null,
        ),
      ],
      selected: status == RsvpStatus.pending ? const {} : {status},
      onSelectionChanged: (s) {
        if (s.isEmpty) return;
        ref.read(calendarRepositoryProvider).respond(event, s.first);
      },
    );
  }
}

class _Reminders extends ConsumerWidget {
  const _Reminders({required this.event});
  final CalendarEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final key = event.seriesKey;
    final stored = ref.watch(calendarLocalRemindersProvider(key));
    final minutes = stored.value ?? [event.reminderMinutes];
    Future<void> save(List<int> next) async {
      await ref.read(calendarRepositoryProvider).setLocalReminders(key, next..sort());
      ref.invalidate(calendarLocalRemindersProvider(key));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(child: Icon(LucideIcons.bell, size: 20, color: tokens.textMuted)),
              const SizedBox(width: Space.md),
              Text(l10n.calendarFieldReminders, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: Space.xs),
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              for (final m in minutes)
                InputChip(
                  label: Text(CalendarFormat.reminder(l10n, m)),
                  onDeleted: () => save([...minutes]..remove(m)),
                ),
              ActionChip(
                key: const Key('add_reminder'),
                avatar: const Icon(LucideIcons.plus, size: 18),
                label: Text(l10n.calendarAddReminder),
                onPressed: () async {
                  final picked = await showAppSheet<int>(
                    context: context,
                    showDragHandle: true,
                    builder: (ctx) => SafeArea(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final p in reminderPresets.where((p) => !minutes.contains(p)))
                            ListTile(
                              title: Text(CalendarFormat.reminder(l10n, p)),
                              onTap: () => Navigator.pop(ctx, p),
                            ),
                        ],
                      ),
                    ),
                  );
                  if (picked != null) await save([...minutes, picked]);
                },
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(l10n.calendarReminderLocalNote, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.textMuted)),
        ],
      ),
    );
  }
}
