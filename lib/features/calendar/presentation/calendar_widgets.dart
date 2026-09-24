import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/permissions.dart';
import '../../../core/platform/desktop_layout.dart';
import '../../../core/localization/localization.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../data/calendar_models.dart';
import '../data/calendar_ops.dart';
import 'calendar_format.dart';
import 'calendar_providers.dart';
import 'event_edit_screen.dart';
import '../../../shared/widgets/app_sheet.dart';

/// Desktop: the occurrence shown in the calendar's side panel (null = none).
class DesktopCalendarDetail extends Notifier<CalendarOccurrence?> {
  @override
  CalendarOccurrence? build() => null;
  void show(CalendarOccurrence? o) => state = o;
}

final desktopCalendarDetailProvider = NotifierProvider<DesktopCalendarDetail, CalendarOccurrence?>(DesktopCalendarDetail.new);

/// Opens the event screen for an occurrence: the side panel of the calendar
/// on desktop (the grid stays in view, as the web's drawer), a page on phones.
void openOccurrence(BuildContext context, CalendarOccurrence o) {
  final container = ProviderScope.containerOf(context, listen: false);
  if (container.read(desktopLayoutProvider)) {
    // From the search or invitations dialog: the panel is behind it.
    if (ModalRoute.of(context) is PopupRoute) Navigator.of(context).pop();
    container.read(desktopCalendarDetailProvider.notifier).show(o);
    final router = GoRouter.of(context);
    if (!router.routeInformationProvider.value.uri.path.startsWith(Routes.calendar)) router.go(Routes.calendar);
    return;
  }
  context.push(
    Routes.calendarEventPath(o.event.id, o.event.occurrenceStartRaw),
    extra: o,
  );
}

/// The new-event / edit form: a dialog over the calendar on desktop (the
/// web's modal), a page on phones.
Future<void> openEventEditor(BuildContext context, EventEditArgs args) async {
  final container = ProviderScope.containerOf(context, listen: false);
  if (!container.read(desktopLayoutProvider)) {
    await context.push(args.isCreate ? Routes.calendarNew : Routes.calendarEdit, extra: args);
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (dialog) => Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
        // Esc closes it, also from a text field.
        child: CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(dialog).maybePop()},
          child: EventEditScreen(args: args, onDone: () => Navigator.of(dialog).pop()),
        ),
      ),
    ),
  );
}

/// Whether the person may change [o] (edit, delete, drag to another time).
bool canEditOccurrence(WidgetRef ref, CalendarOccurrence o) {
  final e = o.event;
  final isOrganizer = e.organizerId == ref.read(calendarRepositoryProvider).selfId;
  final canManageOrg = ref.watch(hasPermissionProvider(Permissions.calendarManageOrg));
  return !e.isCancelled &&
      ((isOrganizer && ref.watch(hasPermissionProvider(Permissions.calendarManageOwn)) && !e.isMandatory) || canManageOrg);
}

/// List row of an occurrence (month day list, agenda, search, invitations).
class OccurrenceTile extends ConsumerWidget {
  const OccurrenceTile({
    super.key,
    required this.occurrence,
    this.showDate = false,
    this.trailing,
  });

  final CalendarOccurrence occurrence;
  final bool showDate;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final zone = ref.watch(deviceLocationProvider);
    final o = occurrence;
    final e = o.event;
    final color = CalendarFormat.color(context, e);
    final declined = e.responseStatus == RsvpStatus.declined;
    final pendingAnswer = e.responseStatus == RsvpStatus.pending &&
        e.organizerId != ref.read(calendarRepositoryProvider).selfId;
    final when = showDate
        ? CalendarFormat.when(context, o, zone)
        : CalendarFormat.timeRange(context, o, zone);
    final subtitle = [
      when,
      if (e.location.isNotEmpty) e.location,
    ].join(' · ');

    return ListTile(
      key: ValueKey('occ_${o.key}'),
      onTap: () => openOccurrence(context, o),
      leading: Container(
        width: 6,
        height: 40,
        decoration: BoxDecoration(
          color: pendingAnswer ? null : color,
          border: pendingAnswer ? Border.all(color: color, width: 2) : null,
          borderRadius: BorderRadius.circular(Space.xs),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              e.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                decoration: declined ? TextDecoration.lineThrough : null,
                color: declined ? tokens.textMuted : null,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (e.isRecurring || e.isOverride)
            Padding(
              padding: const EdgeInsets.only(left: Space.xs),
              child: Icon(LucideIcons.repeat, size: 16, color: tokens.textMuted),
            ),
          if (e.isMandatory)
            Padding(
              padding: const EdgeInsets.only(left: Space.xs),
              child: Icon(LucideIcons.circleAlert, size: 16, color: tokens.warning),
            ),
          if (o.pending)
            Padding(
              padding: const EdgeInsets.only(left: Space.xs),
              child: Tooltip(
                message: l10n.calendarPendingSync,
                child: Icon(LucideIcons.cloudUpload, size: 16, color: tokens.textMuted),
              ),
            ),
        ],
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(color: tokens.textMuted),
      ),
      trailing: trailing,
    );
  }
}

/// Banner for changes the server rejected or that conflict with another
/// device; each can be retried, overwritten or discarded.
class CalendarProblemsBanner extends ConsumerWidget {
  const CalendarProblemsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final problems = ref.watch(calendarProblemsProvider).value ?? const [];
    if (problems.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final tokens = context.tokens;
    return Material(
      color: tokens.danger.withValues(alpha: 0.1),
      child: ListTile(
        key: const Key('calendar_problems'),
        dense: true,
        leading: Icon(LucideIcons.refreshCwOff, color: tokens.danger),
        title: Text(
          l10n.calendarProblemsBanner(problems.length),
          style: TextStyle(color: tokens.danger),
        ),
        trailing: const Icon(LucideIcons.chevronRight),
        onTap: () => showAppSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (_) => const _ProblemsSheet(),
        ),
      ),
    );
  }
}

class _ProblemsSheet extends ConsumerWidget {
  const _ProblemsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final problems = ref.watch(calendarProblemsProvider).value ?? const [];
    final repo = ref.read(calendarRepositoryProvider);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final op in problems)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    op.status == OpStatus.conflict
                        ? l10n.calendarConflictTitle
                        : l10n.calendarProblemFailed(
                            CalendarFormat.error(l10n, PlanError(op.errorCode ?? 'UNKNOWN')),
                          ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (_title(op) case final t?) Text(t),
                  if (op.status == OpStatus.conflict) Text(l10n.calendarConflictBody),
                  Wrap(
                    spacing: Space.sm,
                    children: [
                      if (op.status == OpStatus.conflict)
                        FilledButton(
                          onPressed: () => repo.retry(op.id, overwrite: true),
                          child: Text(l10n.calendarConflictOverwrite),
                        )
                      else
                        FilledButton.tonal(
                          onPressed: () => repo.retry(op.id),
                          child: Text(l10n.retry),
                        ),
                      TextButton(
                        onPressed: () => repo.discard(op.id),
                        child: Text(l10n.calendarDiscard),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String? _title(CalendarOp op) {
    final body = op.payload['body'];
    if (body is Map && body['title'] is String) return body['title'] as String;
    return null;
  }
}

/// "This / this and following / all" for recurring events.
Future<EditScope?> askScope(
  BuildContext context, {
  required bool delete,
  bool allowThis = true,
}) {
  final l10n = context.l10n;
  return showDialog<EditScope>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(delete ? l10n.calendarScopeTitleDelete : l10n.calendarScopeTitleEdit),
      children: [
        if (allowThis)
          SimpleDialogOption(
            key: const Key('scope_this'),
            onPressed: () => Navigator.pop(ctx, EditScope.thisOccurrence),
            child: Text(l10n.calendarScopeThis),
          ),
        SimpleDialogOption(
          key: const Key('scope_following'),
          onPressed: () => Navigator.pop(ctx, EditScope.following),
          child: Text(l10n.calendarScopeFollowing),
        ),
        SimpleDialogOption(
          key: const Key('scope_all'),
          onPressed: () => Navigator.pop(ctx, EditScope.all),
          child: Text(l10n.calendarScopeAll),
        ),
      ],
    ),
  );
}
