import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/localization/localization.dart';
import '../../../core/platform/desktop_keys.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/state_view.dart';
import '../data/calendar_models.dart';
import '../domain/calendar_time.dart';
import 'calendar_desktop_timeline.dart';
import 'calendar_format.dart';
import 'calendar_lists_screens.dart';
import 'calendar_providers.dart';
import 'calendar_screen.dart';
import 'calendar_widgets.dart';
import 'event_detail_screen.dart';
import 'event_edit_screen.dart' show EventEditArgs;

/// New event on [day] (desktop: the editor dialog).
void _newEvent(BuildContext context, CalendarDate day) =>
    unawaited(openEventEditor(context, EventEditArgs.create(date: day)));

/// A calendar list page (search, invitations) as a dialog over the grid.
Future<void> _listDialog(BuildContext context, Widget page) => showDialog<void>(
  context: context,
  builder: (_) => Dialog(
    clipBehavior: Clip.antiAlias,
    insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
      // Esc closes it, also from the search field.
      child: Builder(
        builder: (dialog) => CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(dialog).maybePop()},
          child: page,
        ),
      ),
    ),
  ),
);

/// The desktop calendar — the web's calendar page: a toolbar (today, ‹ ›,
/// the month — click it to jump to a date —, the view switch, invitations,
/// new event), a month grid whose days list their events (time · title,
/// «+N») with the selected day on the right, and the week / day time grid
/// where events are created and moved with the mouse. An opened event shows
/// in a panel on the right, the grid stays in view.
///
/// Keys (outside text fields): T today, ← → (or J K) previous / next,
/// M W D A the view, N or C new event, Esc closes the event panel.
class DesktopCalendar extends ConsumerWidget {
  const DesktopCalendar({super.key});

  static const asideWidth = 300.0;
  static const panelWidth = 400.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l10n = context.l10n;
    final view = ref.watch(calendarViewProvider);
    final notifier = ref.read(calendarViewProvider.notifier);
    final sync = ref.watch(calendarSyncProvider);
    final invitations = ref.watch(calendarBadgeProvider);
    final canCreate = ref.watch(calendarCanCreateProvider);
    final opened = ref.watch(desktopCalendarDetailProvider);
    final title = switch (view.mode) {
      CalendarViewMode.month => CalendarFormat.monthTitle(context, view.selected),
      CalendarViewMode.week => CalendarFormat.weekTitle(context, view.selected.startOfWeek),
      CalendarViewMode.day => CalendarFormat.dayTitle(context, view.selected),
      CalendarViewMode.agenda => l10n.calendarViewAgenda,
    };
    Widget iconButton(IconData icon, String tooltip, VoidCallback? onPressed, {Key? key, Widget? badge}) => IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        foregroundColor: t.textSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusMd)),
      ),
      icon: badge ?? Icon(icon, size: 18),
    );

    final toolbar = Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.smd),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(
          bottom: BorderSide(color: t.border, width: t.borderWidth),
        ),
      ),
      child: Row(
        children: [
          OutlinedButton(
            key: const Key('calendar_today'),
            onPressed: notifier.today,
            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
            child: Text(l10n.calendarToday),
          ),
          const SizedBox(width: Space.sm),
          if (view.mode != CalendarViewMode.agenda) ...[
            iconButton(
              LucideIcons.chevronLeft,
              l10n.desktopPrevious,
              () => notifier.shift(-1),
              key: const Key('calendar_prev'),
            ),
            iconButton(
              LucideIcons.chevronRight,
              l10n.desktopNext,
              () => notifier.shift(1),
              key: const Key('calendar_next'),
            ),
          ],
          const SizedBox(width: Space.sm),
          Flexible(
            child: Tooltip(
              message: l10n.desktopCalendarGoToDate,
              child: InkWell(
                key: const Key('calendar_title_button'),
                borderRadius: BorderRadius.circular(t.radiusMd),
                onTap: () => _goToDate(context, ref),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          key: const Key('calendar_title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: t.fontDisplay,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: t.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(LucideIcons.chevronDown, size: 16, color: t.textTertiary),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (view.mode == CalendarViewMode.week) ...[
            const SizedBox(width: Space.sm),
            Text(
              l10n.desktopCalendarWeekNumber(_isoWeek(view.selected)),
              style: TextStyle(fontSize: 12, color: t.textTertiary),
            ),
          ],
          if (sync.syncing) ...[
            const SizedBox(width: Space.sm),
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: t.textTertiary)),
          ],
          const Spacer(),
          SegmentedButton<CalendarViewMode>(
            key: const Key('calendar_view_switch'),
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              ButtonSegment(value: CalendarViewMode.month, label: Text(l10n.calendarViewMonth)),
              ButtonSegment(value: CalendarViewMode.week, label: Text(l10n.calendarViewWeek)),
              ButtonSegment(value: CalendarViewMode.day, label: Text(l10n.calendarViewDay)),
              ButtonSegment(value: CalendarViewMode.agenda, label: Text(l10n.calendarViewAgenda)),
            ],
            selected: {view.mode},
            onSelectionChanged: (s) => notifier.setMode(s.first),
          ),
          const SizedBox(width: Space.sm),
          iconButton(LucideIcons.search, l10n.calendarSearch, () => _listDialog(context, const CalendarSearchScreen())),
          iconButton(
            LucideIcons.mail,
            l10n.calendarInvitations,
            () => _listDialog(context, const CalendarInvitationsScreen()),
            key: const Key('calendar_invitations'),
            badge: invitations > 0
                ? Badge(
                    label: Text('$invitations'),
                    backgroundColor: t.unreadBadge,
                    textColor: t.onUnreadBadge,
                    child: const Icon(LucideIcons.mail, size: 18),
                  )
                : null,
          ),
          iconButton(
            LucideIcons.refreshCw,
            l10n.desktopRefresh,
            sync.syncing ? null : () => ref.read(calendarSyncProvider.notifier).sync(),
            key: const Key('calendar_sync'),
          ),
          if (canCreate) ...[
            const SizedBox(width: Space.sm),
            FilledButton.icon(
              key: const Key('calendar_new_button'),
              onPressed: () => _newEvent(context, view.selected),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: Text(l10n.calendarNewEvent),
            ),
          ],
        ],
      ),
    );

    final keys = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyT): notifier.today,
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () => notifier.shift(-1),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () => notifier.shift(1),
      const SingleActivator(LogicalKeyboardKey.keyK): () => notifier.shift(-1),
      const SingleActivator(LogicalKeyboardKey.keyJ): () => notifier.shift(1),
      const SingleActivator(LogicalKeyboardKey.keyM): () => notifier.setMode(CalendarViewMode.month),
      const SingleActivator(LogicalKeyboardKey.keyW): () => notifier.setMode(CalendarViewMode.week),
      const SingleActivator(LogicalKeyboardKey.keyD): () => notifier.setMode(CalendarViewMode.day),
      const SingleActivator(LogicalKeyboardKey.keyA): () => notifier.setMode(CalendarViewMode.agenda),
      if (opened != null)
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            ref.read(desktopCalendarDetailProvider.notifier).show(null),
      if (canCreate) ...{
        const SingleActivator(LogicalKeyboardKey.keyN): () => _newEvent(context, view.selected),
        const SingleActivator(LogicalKeyboardKey.keyC): () => _newEvent(context, view.selected),
        commandShortcut(LogicalKeyboardKey.keyN): () => _newEvent(context, view.selected),
      },
    };

    final content = switch (view.mode) {
      CalendarViewMode.month => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _MonthBoard(month: view.selected.firstOfMonth)),
          if (opened == null)
            SizedBox(
              width: asideWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.surface,
                  border: Border(
                    left: BorderSide(color: t.border, width: t.borderWidth),
                  ),
                ),
                child: _DayAside(day: view.selected),
              ),
            ),
        ],
      ),
      CalendarViewMode.week => const DesktopTimeline(key: ValueKey('week'), days: 7),
      // The day's list beside its grid, as in month.
      CalendarViewMode.day => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(child: DesktopTimeline(key: ValueKey('day'), days: 1)),
          if (opened == null)
            SizedBox(
              width: asideWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.surface,
                  border: Border(left: BorderSide(color: t.border, width: t.borderWidth)),
                ),
                child: _DayAside(day: view.selected, miniMonth: true),
              ),
            ),
        ],
      ),
      CalendarViewMode.agenda => Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: const AgendaView()),
      ),
    };

    return DesktopKeyBindings(
      bindings: keys,
      child: Scaffold(
        backgroundColor: t.surface,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            toolbar,
            if (sync.offline)
              OfflineBanner(
                text: l10n.calendarOfflineCached,
                onRetry: () => ref.read(calendarSyncProvider.notifier).sync(),
              )
            else if (sync.error != null && !sync.syncing)
              Padding(
                padding: const EdgeInsets.all(Space.sm),
                child: ErrorMessage(CalendarFormat.error(l10n, sync.error!)),
              ),
            const CalendarProblemsBanner(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: content),
                  if (opened != null)
                    Container(
                      key: const Key('calendar_event_panel'),
                      width: panelWidth,
                      decoration: BoxDecoration(
                        color: t.surface,
                        border: Border(
                          left: BorderSide(color: t.border, width: t.borderWidth),
                        ),
                      ),
                      child: EventDetailScreen(
                        key: ValueKey(opened.key),
                        eventId: opened.event.id,
                        occurrenceStart: opened.event.occurrenceStartRaw,
                        initial: opened,
                        onClose: () => ref.read(desktopCalendarDetailProvider.notifier).show(null),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _goToDate(BuildContext context, WidgetRef ref) async {
    final selected = ref.read(calendarViewProvider).selected;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(selected.year, selected.month, selected.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) ref.read(calendarViewProvider.notifier).select(CalendarDate.of(picked));
  }
}

/// ISO 8601 week number of [d].
int _isoWeek(CalendarDate d) {
  final thursday = d.addDays(4 - d.weekday);
  final jan1 = CalendarDate(thursday.year, 1, 1);
  return jan1.daysUntil(thursday) ~/ 7 + 1;
}

/// The month: weekday header and 6 weeks of day cells (min 112px high).
class _MonthBoard extends ConsumerStatefulWidget {
  const _MonthBoard({required this.month});
  final CalendarDate month;

  @override
  ConsumerState<_MonthBoard> createState() => _MonthBoardState();
}

class _MonthBoardState extends ConsumerState<_MonthBoard> {
  @override
  void initState() {
    super.initState();
    _ensure();
  }

  @override
  void didUpdateWidget(covariant _MonthBoard old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month) _ensure();
  }

  void _ensure() => Future.microtask(() {
    if (mounted) ref.read(calendarSyncProvider.notifier).ensureMonth(widget.month);
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final start = widget.month.startOfWeek;
    final data = ref.watch(calendarRangeProvider((from: start, to: start.addDays(42))));
    final zone = ref.watch(deviceLocationProvider);
    final today = ref.watch(calendarTodayProvider);
    final selected = ref.watch(calendarViewProvider.select((s) => s.selected));
    final occ = data.value ?? const <CalendarOccurrence>[];
    final hairline = BorderSide(color: t.border, width: t.borderWidth);
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: t.surfaceSubtle,
            border: Border(bottom: hairline),
          ),
          child: Row(
            children: [
              for (var d = 1; d <= 7; d++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.sm),
                    child: Text(
                      CalendarFormat.weekdayShort(context, d).toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.9,
                        color: t.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final rowHeight = (c.maxHeight / 6).clamp(112.0, double.infinity);
              final grid = Column(
                children: [
                  for (var w = 0; w < 6; w++)
                    SizedBox(
                      height: rowHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var d = 0; d < 7; d++)
                            Expanded(
                              child: () {
                                final day = start.addDays(w * 7 + d);
                                return _DayBox(
                                  day: day,
                                  inMonth: day.month == widget.month.month,
                                  isToday: day == today,
                                  isSelected: day == selected,
                                  isPast: day.isBefore(today),
                                  events: occ.where((o) => occursOn(o, day, zone)).toList(),
                                  lastColumn: d == 6,
                                );
                              }(),
                            ),
                        ],
                      ),
                    ),
                ],
              );
              return rowHeight * 6 > c.maxHeight + 0.5 ? SingleChildScrollView(child: grid) : grid;
            },
          ),
        ),
      ],
    );
  }
}

class _DayBox extends ConsumerStatefulWidget {
  const _DayBox({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.isPast,
    required this.events,
    required this.lastColumn,
  });

  final CalendarDate day;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final bool isPast;
  final List<CalendarOccurrence> events;
  final bool lastColumn;

  @override
  ConsumerState<_DayBox> createState() => _DayBoxState();
}

class _DayBoxState extends ConsumerState<_DayBox> {
  bool _hover = false;

  Future<void> _menu(BuildContext context, Offset at) async {
    final l10n = context.l10n;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final picked = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(at & const Size(1, 1), Offset.zero & overlay.size),
      items: [
        PopupMenuItem(
          value: 0,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(LucideIcons.calendarPlus, size: 18),
            title: Text(l10n.calendarNewEvent),
          ),
        ),
        PopupMenuItem(
          value: 1,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(LucideIcons.calendarDays, size: 18),
            title: Text(l10n.calendarViewDay),
          ),
        ),
      ],
    );
    if (!context.mounted) return;
    final view = ref.read(calendarViewProvider.notifier);
    if (picked == 0) _newEvent(context, widget.day);
    if (picked == 1) {
      view.select(widget.day);
      view.setMode(CalendarViewMode.day);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final zone = ref.watch(deviceLocationProvider);
    final canCreate = ref.watch(calendarCanCreateProvider);
    final hairline = BorderSide(color: t.border, width: t.borderWidth);
    final day = widget.day;
    const maxChips = 3;
    // Month chips dropped here move to this day.
    return DragTarget<_ChipDrag>(
      onWillAcceptWithDetails: (d) => d.data.day != day,
      onAcceptWithDetails: (d) =>
          unawaited(moveOccurrenceByDays(context, ref, d.data.occurrence, d.data.day.daysUntil(day))),
      builder: (context, candidates, _) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: candidates.isEmpty ? null : Border.all(color: t.primary, width: 2),
        ),
        child: _box(context, t, l10n, zone, canCreate, hairline, day, maxChips),
      ),
    );
  }

  Widget _box(
    BuildContext context,
    XatBoxTokens t,
    AppLocalizations l10n,
    tz.Location zone,
    bool canCreate,
    BorderSide hairline,
    CalendarDate day,
    int maxChips,
  ) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: widget.isSelected
            ? t.primarySoft.withValues(alpha: 0.35)
            : (widget.inMonth ? t.surface : t.surfaceSubtle),
        child: InkWell(
          key: ValueKey('day_${day.key}'),
          onTap: () => ref.read(calendarViewProvider.notifier).select(day),
          onSecondaryTapUp: canCreate ? (d) => _menu(context, d.globalPosition) : null,
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: hairline, right: widget.lastColumn ? BorderSide.none : hairline),
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: widget.isToday ? BoxDecoration(color: t.primary, shape: BoxShape.circle) : null,
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: widget.isToday || widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: widget.isToday
                              ? t.textInverse
                              : (widget.inMonth && !widget.isPast ? t.textPrimary : t.textTertiary),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (canCreate && _hover)
                      Tooltip(
                        message: l10n.calendarNewEvent,
                        child: InkWell(
                          key: ValueKey('day_add_${day.key}'),
                          borderRadius: BorderRadius.circular(t.radiusSm),
                          onTap: () => _newEvent(context, day),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(LucideIcons.plus, size: 16, color: t.primary),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final o in widget.events.take(maxChips))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: _EventChip(occurrence: o, zone: zone, day: day),
                  ),
                if (widget.events.length > maxChips)
                  InkWell(
                    onTap: () => ref.read(calendarViewProvider.notifier).select(day),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        l10n.desktopCalendarMore(widget.events.length - maxChips),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: t.textSecondary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A day's event: a soft pill with a dot, the start time and the title.
/// A chip dragged from [day] to another day of the month.
class _ChipDrag {
  const _ChipDrag(this.occurrence, this.day);
  final CalendarOccurrence occurrence;
  final CalendarDate day;
}

class _EventChip extends ConsumerWidget {
  const _EventChip({required this.occurrence, required this.zone, required this.day});
  final CalendarOccurrence occurrence;
  final tz.Location zone;
  final CalendarDate day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final o = occurrence;
    final color = CalendarFormat.color(context, o.event);
    final allDay = o.allDayStart != null;
    final chip = _chip(context, t, o, color, allDay);
    // Drag to another day: same time, another date.
    if (o.pending || !canEditOccurrence(ref, o)) return chip;
    return Draggable<_ChipDrag>(
      data: _ChipDrag(o, day),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 160, child: Opacity(opacity: 0.9, child: _chip(context, t, o, color, allDay))),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: chip),
      child: MouseRegion(cursor: SystemMouseCursors.grab, child: chip),
    );
  }

  Widget _chip(BuildContext context, XatBoxTokens t, CalendarOccurrence o, Color color, bool allDay) {
    return Material(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(t.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(t.radiusSm),
        onTap: () => openOccurrence(context, o),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              if (!allDay) ...[
                Text(
                  CalendarFormat.hm(context, o.start, zone),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  o.event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: t.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The web's «Выбранный день» aside: the day, «+», and its events as
/// time · (bar) title / end · place rows.
class _DayAside extends ConsumerWidget {
  const _DayAside({required this.day, this.miniMonth = false});
  final CalendarDate day;

  /// Day view: a small month on top to jump to another date.
  final bool miniMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l10n = context.l10n;
    final zone = ref.watch(deviceLocationProvider);
    final data = ref.watch(calendarRangeProvider((from: day, to: day.addDays(1))));
    final canCreate = ref.watch(calendarCanCreateProvider);
    return Padding(
      padding: const EdgeInsets.all(Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (miniMonth) ...[
            SizedBox(
              height: 300,
              child: CalendarDatePicker(
                key: ValueKey('mini_month_${day.key}'),
                initialDate: DateTime(day.year, day.month, day.day),
                currentDate: () {
                  final today = ref.watch(calendarTodayProvider);
                  return DateTime(today.year, today.month, today.day);
                }(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                onDateChanged: (d) => ref.read(calendarViewProvider.notifier).select(CalendarDate.of(d)),
              ),
            ),
            Divider(height: Space.lg, color: t.divider),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.desktopCalendarSelectedDay.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.9,
                        color: t.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CalendarFormat.dayTitle(context, day),
                      style: TextStyle(
                        fontFamily: t.fontDisplay,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: t.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (canCreate)
                IconButton.filledTonal(
                  key: const Key('calendar_aside_add'),
                  tooltip: l10n.calendarNewEvent,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _newEvent(context, day),
                  icon: const Icon(LucideIcons.plus, size: 16),
                ),
            ],
          ),
          const SizedBox(height: Space.md),
          Expanded(
            child: data.when(
              loading: () => const StateView.loading(),
              error: (e, _) => StateView.error(message: CalendarFormat.error(l10n, e)),
              data: (list) => list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: Space.lg),
                      child: Text(
                        l10n.calendarNoEventsDay,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: t.textTertiary),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final o in list)
                          InkWell(
                            borderRadius: BorderRadius.circular(t.radiusLg),
                            onTap: () => openOccurrence(context, o),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.smd),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 48,
                                    child: Text(
                                      o.allDayStart != null
                                          ? l10n.calendarAllDay
                                          : CalendarFormat.hm(context, o.start, zone),
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.primary),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.only(left: Space.smd),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          left: BorderSide(color: CalendarFormat.color(context, o.event), width: 2),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            o.event.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: t.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            [
                                              CalendarFormat.timeRange(context, o, zone),
                                              if (o.event.location.isNotEmpty) o.event.location,
                                            ].join(' · '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 11, color: t.textTertiary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
