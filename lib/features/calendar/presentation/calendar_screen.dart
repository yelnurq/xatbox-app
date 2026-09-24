import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/localization/localization.dart';
import '../../../core/platform/desktop_layout.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/state_view.dart';
import '../data/calendar_models.dart';
import '../data/calendar_repository.dart';
import '../domain/calendar_time.dart';
import 'calendar_desktop.dart';
import 'calendar_format.dart';
import 'calendar_providers.dart';
import 'calendar_widgets.dart';
import 'event_edit_screen.dart' show EventEditArgs;

/// Whether [o] covers any part of [day] in the device zone.
bool occursOn(CalendarOccurrence o, CalendarDate day, tz.Location zone) {
  if (o.allDay) {
    return !o.allDayStart!.isAfter(day) && o.allDayEnd!.isAfter(day);
  }
  final start = EventTime.atWall(day, 0, 0, zone);
  final end = EventTime.atWall(day.addDays(1), 0, 0, zone);
  return o.start.isBefore(end) && o.end.isAfter(start);
}

const _pageBase = 1200;

/// Calendar root: month / week / day / agenda. The mode and the selected
/// date live in [calendarViewProvider], so switching views keeps the date.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted || !ref.read(calendarEnabledProvider)) return;
      final s = ref.read(calendarSyncProvider);
      final now = ref.read(calendarClockProvider)();
      if (s.lastSync == null ||
          now.difference(s.lastSync!) > const Duration(minutes: 1)) {
        ref.read(calendarSyncProvider.notifier).sync();
      }
    });
  }

  static IconData _icon(CalendarViewMode m) => switch (m) {
    CalendarViewMode.month => LucideIcons.calendar,
    CalendarViewMode.week => LucideIcons.calendarRange,
    CalendarViewMode.day => LucideIcons.calendarDays,
    CalendarViewMode.agenda => LucideIcons.list,
  };

  static String _label(AppLocalizations l10n, CalendarViewMode m) => switch (m) {
    CalendarViewMode.month => l10n.calendarViewMonth,
    CalendarViewMode.week => l10n.calendarViewWeek,
    CalendarViewMode.day => l10n.calendarViewDay,
    CalendarViewMode.agenda => l10n.calendarViewAgenda,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    if (!ref.watch(calendarEnabledProvider)) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.calendarTitle)),
        body: StateView.error(
          message: l10n.calendarNoAccess,
          icon: LucideIcons.lock,
        ),
      );
    }
    // Desktop: the web calendar page (month grid with events + day aside).
    if (ref.watch(desktopLayoutProvider)) return const DesktopCalendar();
    final view = ref.watch(calendarViewProvider);
    final notifier = ref.read(calendarViewProvider.notifier);
    final sync = ref.watch(calendarSyncProvider);
    final invitations = ref.watch(calendarBadgeProvider);
    final desktop = ref.watch(desktopLayoutProvider);
    final canCreate = ref.watch(calendarCanCreateProvider);
    void newEvent() => context.push(Routes.calendarNew, extra: EventEditArgs.create(date: view.selected));
    final title = switch (view.mode) {
      CalendarViewMode.month => CalendarFormat.monthTitle(context, view.selected),
      CalendarViewMode.week => CalendarFormat.weekTitle(context, view.selected.startOfWeek),
      CalendarViewMode.day => CalendarFormat.dayTitle(context, view.selected),
      CalendarViewMode.agenda => l10n.calendarViewAgenda,
    };

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, key: const Key('calendar_title')),
            if (sync.syncing)
              Text(
                l10n.calendarSyncing,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.textMuted),
              ),
          ],
        ),
        actions: [
          // Desktop: sync and «Новое событие» in the header (no pull to
          // refresh with a mouse, no floating button).
          if (desktop)
            IconButton(
              key: const Key('calendar_sync'),
              tooltip: l10n.desktopRefresh,
              icon: const Icon(LucideIcons.refreshCw),
              onPressed: sync.syncing ? null : () => ref.read(calendarSyncProvider.notifier).sync(),
            ),
          // Desktop: a mouse cannot swipe the month / week / day pages.
          if (desktop && view.mode != CalendarViewMode.agenda) ...[
            IconButton(
              key: const Key('calendar_prev'),
              tooltip: l10n.desktopPrevious,
              icon: const Icon(LucideIcons.chevronLeft),
              onPressed: () => notifier.shift(-1),
            ),
            IconButton(
              key: const Key('calendar_next'),
              tooltip: l10n.desktopNext,
              icon: const Icon(LucideIcons.chevronRight),
              onPressed: () => notifier.shift(1),
            ),
          ],
          IconButton(
            key: const Key('calendar_today'),
            tooltip: l10n.calendarToday,
            icon: const Icon(LucideIcons.calendarCheck),
            onPressed: notifier.today,
          ),
          IconButton(
            tooltip: l10n.calendarSearch,
            icon: const Icon(LucideIcons.search),
            onPressed: () => context.push(Routes.calendarSearch),
          ),
          IconButton(
            key: const Key('calendar_invitations'),
            tooltip: l10n.calendarInvitations,
            icon: invitations > 0
                ? Badge(
                    label: Text('$invitations'),
                    backgroundColor: tokens.unreadBadge,
                    textColor: tokens.onUnreadBadge,
                    child: const Icon(LucideIcons.mail),
                  )
                : const Icon(LucideIcons.mailOpen),
            onPressed: () => context.push(Routes.calendarInvitations),
          ),
          PopupMenuButton<CalendarViewMode>(
            key: const Key('calendar_view_menu'),
            icon: Icon(_icon(view.mode)),
            onSelected: notifier.setMode,
            itemBuilder: (_) => [
              for (final m in CalendarViewMode.values)
                CheckedPopupMenuItem(
                  key: Key('view_${m.name}'),
                  value: m,
                  checked: m == view.mode,
                  child: Text(_label(l10n, m)),
                ),
            ],
          ),
          if (desktop && canCreate)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.sm),
              child: FilledButton.icon(
                key: const Key('calendar_new_button'),
                onPressed: newEvent,
                icon: const Icon(LucideIcons.plus, size: 18),
                label: Text(l10n.calendarNewEvent),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
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
            child: switch (view.mode) {
              CalendarViewMode.month => const MonthView(),
              CalendarViewMode.week => const TimelineView(key: ValueKey('week'), days: 7),
              CalendarViewMode.day => const TimelineView(key: ValueKey('day'), days: 1),
              CalendarViewMode.agenda => const AgendaView(),
            },
          ),
        ],
      ),
      floatingActionButton: canCreate && !desktop
          ? FloatingActionButton(
              heroTag: 'fab_calendar_new',
              key: const Key('calendar_new_fab'),
              tooltip: l10n.calendarNewEvent,
              onPressed: newEvent,
              child: const Icon(LucideIcons.plus),
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Month
// ---------------------------------------------------------------------------

/// Month cell height: up to two events (or one and «+N») under the day
/// number on a tall screen, never more than about half of it, so the day's
/// list below keeps room (and stays clear of the glass tab bar).
double _cellHeightFor(double screenHeight) => (screenHeight * 0.55 / 6).clamp(48.0, 72.0);

class MonthView extends ConsumerStatefulWidget {
  const MonthView({super.key});

  @override
  ConsumerState<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends ConsumerState<MonthView> {
  late final CalendarDate _base;
  late final PageController _pages;

  @override
  void initState() {
    super.initState();
    _base = ref.read(calendarTodayProvider).firstOfMonth;
    _pages = PageController(initialPage: _pageFor(ref.read(calendarViewProvider).selected));
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  int _pageFor(CalendarDate d) =>
      _pageBase + (d.year - _base.year) * 12 + d.month - _base.month;

  CalendarDate _monthFor(int page) => _base.addMonths(page - _pageBase);

  @override
  Widget build(BuildContext context) {
    ref.listen(calendarViewProvider, (_, next) {
      final page = _pageFor(next.selected);
      if (_pages.hasClients && _pages.page?.round() != page) _pages.jumpToPage(page);
    });
    final selected = ref.watch(calendarViewProvider.select((s) => s.selected));
    return Column(
      children: [
        const _WeekdayHeader(),
        SizedBox(
          height: 6 * _cellHeightFor(MediaQuery.sizeOf(context).height),
          child: PageView.builder(
            key: const Key('month_pages'),
            controller: _pages,
            onPageChanged: (p) {
              final month = _monthFor(p);
              final cur = ref.read(calendarViewProvider).selected;
              final delta = (month.year - cur.year) * 12 + month.month - cur.month;
              if (delta != 0) {
                ref.read(calendarViewProvider.notifier).select(cur.addMonths(delta));
              }
            },
            itemBuilder: (_, p) => _MonthGrid(month: _monthFor(p)),
          ),
        ),
        const Divider(height: 1),
        Expanded(child: DayAgenda(day: selected)),
      ],
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          for (var d = 1; d <= 7; d++)
            Expanded(
              child: Center(
                child: Text(
                  CalendarFormat.weekdayShort(context, d),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: d >= 6 ? tokens.danger : tokens.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends ConsumerStatefulWidget {
  const _MonthGrid({required this.month});
  final CalendarDate month;

  @override
  ConsumerState<_MonthGrid> createState() => _MonthGridState();
}

class _MonthGridState extends ConsumerState<_MonthGrid> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(calendarSyncProvider.notifier).ensureMonth(widget.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.month.firstOfMonth.startOfWeek;
    final data = ref.watch(calendarRangeProvider((from: start, to: start.addDays(42))));
    final zone = ref.watch(deviceLocationProvider);
    final today = ref.watch(calendarTodayProvider);
    final selected = ref.watch(calendarViewProvider.select((s) => s.selected));
    final occ = data.value ?? const <CalendarOccurrence>[];
    return Column(
      children: [
        for (var w = 0; w < 6; w++)
          Expanded(
            child: Row(
              children: [
                for (var d = 0; d < 7; d++)
                  Expanded(
                    child: () {
                      final day = start.addDays(w * 7 + d);
                      return _DayCell(
                        day: day,
                        inMonth: day.month == widget.month.month,
                        isToday: day == today,
                        isSelected: day == selected,
                        events: occ.where((o) => occursOn(o, day, zone)).toList(),
                      );
                    }(),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCell extends ConsumerWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.events,
  });

  final CalendarDate day;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final List<CalendarOccurrence> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: ValueKey('day_${day.key}'),
      borderRadius: BorderRadius.circular(Space.sm),
      onTap: () => ref.read(calendarViewProvider.notifier).select(day),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(Space.sm),
        ),
        child: Column(
          children: [
            const SizedBox(height: 2),
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: isToday
                  ? BoxDecoration(color: tokens.brand, shape: BoxShape.circle)
                  : null,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: isToday
                      ? tokens.onBrand
                      : (inMonth ? scheme.onSurface : tokens.textMuted),
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 2),
            // As the desktop month: the events themselves — a coloured strip
            // with the title — as many as fit, then «+N».
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  const chip = 15.0;
                  final fit = (box.maxHeight / chip).floor();
                  if (fit <= 0 || events.isEmpty) return const SizedBox.shrink();
                  final shown = events.length <= fit ? events.length : math.max(fit - 1, 0);
                  final rest = events.length - shown;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final o in events.take(shown)) _MonthChip(occurrence: o),
                      if (rest > 0)
                        Text(
                          '+$rest',
                          key: ValueKey('day_more_${day.key}'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, height: 1.3, color: tokens.textMuted, fontWeight: FontWeight.w600),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One event in a month cell: its colour as a soft strip with the title.
class _MonthChip extends StatelessWidget {
  const _MonthChip({required this.occurrence});
  final CalendarOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final color = CalendarFormat.color(context, occurrence.event);
    return Container(
      height: 13,
      margin: const EdgeInsets.only(bottom: 2, left: 1, right: 1),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(3),
        border: Border(left: BorderSide(color: color, width: 2)),
      ),
      child: Text(
        occurrence.event.title,
        maxLines: 1,
        overflow: TextOverflow.clip,
        softWrap: false,
        style: TextStyle(fontSize: 9, height: 1.35, color: context.tokens.textPrimary, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Events of one day under the month grid.
class DayAgenda extends ConsumerWidget {
  const DayAgenda({super.key, required this.day});
  final CalendarDate day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final data = ref.watch(calendarRangeProvider((from: day, to: day.addDays(1))));
    final sync = ref.watch(calendarSyncProvider);
    final cached = ref.watch(calendarCachedMonthsProvider).value ?? const <String>{};
    Future<void> refresh() => ref.read(calendarSyncProvider.notifier).sync(around: day);

    return data.when(
      loading: () => const StateView.loading(),
      error: (e, _) => StateView.error(message: CalendarFormat.error(l10n, e), onRetry: refresh),
      data: (list) {
        if (list.isEmpty &&
            sync.offline &&
            !cached.contains(CalendarRepository.monthKey(day.year, day.month))) {
          return StateView.offline(message: l10n.calendarOfflineEmpty, onRetry: refresh);
        }
        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            key: const Key('day_agenda'),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
                child: Text(
                  CalendarFormat.dayTitle(context, day),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: Center(
                    child: Text(l10n.calendarNoEventsDay, style: TextStyle(color: tokens.textMuted)),
                  ),
                ),
              for (final o in list) OccurrenceTile(occurrence: o),
              const SizedBox(height: 88),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Week / day timeline
// ---------------------------------------------------------------------------

const _hourHeight = 56.0;

class TimelineView extends ConsumerStatefulWidget {
  const TimelineView({super.key, required this.days});
  final int days;

  @override
  ConsumerState<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends ConsumerState<TimelineView> {
  late final CalendarDate _base;
  late final PageController _pages;

  @override
  void initState() {
    super.initState();
    final today = ref.read(calendarTodayProvider);
    _base = widget.days == 7 ? today.startOfWeek : today;
    _pages = PageController(initialPage: _pageFor(ref.read(calendarViewProvider).selected));
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  int _pageFor(CalendarDate d) => widget.days == 7
      ? _pageBase + (_base.daysUntil(d.startOfWeek) ~/ 7)
      : _pageBase + _base.daysUntil(d);

  CalendarDate _startFor(int page) => _base.addDays((page - _pageBase) * widget.days);

  @override
  Widget build(BuildContext context) {
    ref.listen(calendarViewProvider, (_, next) {
      final page = _pageFor(next.selected);
      if (_pages.hasClients && _pages.page?.round() != page) _pages.jumpToPage(page);
    });
    return PageView.builder(
      key: Key('timeline_pages_${widget.days}'),
      controller: _pages,
      onPageChanged: (p) {
        final start = _startFor(p);
        final cur = ref.read(calendarViewProvider).selected;
        if (cur.isBefore(start) || !cur.isBefore(start.addDays(widget.days))) {
          ref
              .read(calendarViewProvider.notifier)
              .select(widget.days == 7 ? start.addDays(cur.weekday - 1) : start);
        }
      },
      itemBuilder: (_, p) => _TimelinePage(start: _startFor(p), days: widget.days),
    );
  }
}

class _TimelinePage extends ConsumerStatefulWidget {
  const _TimelinePage({required this.start, required this.days});
  final CalendarDate start;
  final int days;

  @override
  ConsumerState<_TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<_TimelinePage> {
  final _scroll = ScrollController(initialScrollOffset: 7.5 * _hourHeight);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final sync = ref.read(calendarSyncProvider.notifier);
      sync.ensureMonth(widget.start);
      sync.ensureMonth(widget.start.addDays(widget.days - 1));
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    final start = widget.start;
    final data = ref.watch(calendarRangeProvider((from: start, to: start.addDays(widget.days))));
    final zone = ref.watch(deviceLocationProvider);
    final today = ref.watch(calendarTodayProvider);
    final now = ref.watch(calendarClockProvider)();
    final occ = data.value ?? const <CalendarOccurrence>[];
    final allDay = occ.where((o) => o.allDay).toList();
    final timed = occ.where((o) => !o.allDay).toList();
    final days = [for (var i = 0; i < widget.days; i++) start.addDays(i)];

    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 48),
            for (final day in days)
              Expanded(
                child: InkWell(
                  key: ValueKey('timeline_day_${day.key}'),
                  onTap: () {
                    final view = ref.read(calendarViewProvider.notifier);
                    view.select(day);
                    if (widget.days == 7) view.setMode(CalendarViewMode.day);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.xs),
                    child: Column(
                      children: [
                        Text(
                          CalendarFormat.weekdayShort(context, day.weekday),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tokens.textMuted),
                        ),
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: day == today
                              ? BoxDecoration(color: tokens.brand, shape: BoxShape.circle)
                              : null,
                          child: Text(
                            '${day.day}',
                            style: TextStyle(color: day == today ? tokens.onBrand : scheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (allDay.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 84),
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 48,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l10n.calendarAllDay,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: tokens.textMuted),
                      ),
                    ),
                  ),
                  for (final day in days)
                    Expanded(
                      child: Column(
                        children: [
                          for (final o in allDay.where((o) => occursOn(o, day, zone)))
                            _EventChip(occurrence: o),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            child: SizedBox(
              height: 24 * _hourHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 48,
                    child: Stack(
                      children: [
                        for (var h = 1; h < 24; h++)
                          Positioned(
                            top: h * _hourHeight - 7,
                            right: 6,
                            child: Text(
                              '${h.toString().padLeft(2, '0')}:00',
                              style: TextStyle(fontSize: 10, color: tokens.textMuted),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final day in days)
                    Expanded(
                      child: _DayColumn(
                        day: day,
                        zone: zone,
                        now: day == today ? now : null,
                        occurrences: timed.where((o) => occursOn(o, day, zone)).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EventChip extends StatelessWidget {
  const _EventChip({required this.occurrence});
  final CalendarOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final color = CalendarFormat.color(context, occurrence.event);
    return Padding(
      padding: const EdgeInsets.all(1),
      child: Material(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(Space.xs),
        child: InkWell(
          onTap: () => openOccurrence(context, occurrence),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: 2),
            child: Text(
              occurrence.event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
      ),
    );
  }
}

class _Block {
  _Block(this.occurrence, this.top, this.bottom);
  final CalendarOccurrence occurrence;
  final double top;
  final double bottom;
  int column = 0;
  int columns = 1;
}

class _DayColumn extends ConsumerWidget {
  const _DayColumn({
    required this.day,
    required this.zone,
    required this.occurrences,
    this.now,
  });

  final CalendarDate day;
  final tz.Location zone;
  final List<CalendarOccurrence> occurrences;
  final DateTime? now;

  double _minutes(DateTime instant, bool isEnd) {
    final dayStart = EventTime.atWall(day, 0, 0, zone);
    final dayEnd = EventTime.atWall(day.addDays(1), 0, 0, zone);
    if (!instant.isAfter(dayStart)) return 0;
    if (!instant.isBefore(dayEnd)) return 24 * 60;
    final w = EventTime.inZone(instant, zone);
    return (w.hour * 60 + w.minute).toDouble();
  }

  List<_Block> _layout() {
    final blocks = [
      for (final o in occurrences)
        () {
          final top = _minutes(o.start, false);
          final bottom = math.max(_minutes(o.end, true), top + 20);
          return _Block(o, top, bottom);
        }(),
    ]..sort((a, b) => a.top.compareTo(b.top));
    // Greedy columns inside clusters of overlapping blocks.
    var cluster = <_Block>[];
    var clusterEnd = -1.0;
    void close() {
      final cols = cluster.fold<int>(0, (m, b) => math.max(m, b.column + 1));
      for (final b in cluster) {
        b.columns = cols;
      }
      cluster = [];
    }

    for (final b in blocks) {
      if (b.top >= clusterEnd && cluster.isNotEmpty) close();
      final used = <int>{
        for (final c in cluster)
          if (c.bottom > b.top) c.column,
      };
      var col = 0;
      while (used.contains(col)) {
        col++;
      }
      b.column = col;
      cluster.add(b);
      clusterEnd = math.max(clusterEnd, b.bottom);
    }
    if (cluster.isNotEmpty) close();
    return blocks;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final blocks = _layout();
    final canCreate = ref.watch(calendarCanCreateProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          // Long press on an empty slot: a 30-minute event from that half
          // hour, as a click on the desktop grid.
          onLongPressStart: canCreate
              ? (d) {
                  unawaited(HapticFeedback.mediumImpact());
                  final start = ((d.localPosition.dy / _hourHeight * 2).floor() * 30).clamp(0, 23 * 60 + 30);
                  final end = start + 30;
                  unawaited(context.push(
                    Routes.calendarNew,
                    extra: EventEditArgs.create(
                      date: day,
                      hour: start ~/ 60,
                      minute: start % 60,
                      endHour: end ~/ 60,
                      endMinute: end % 60,
                    ),
                  ));
                }
              : null,
          // Desktop: right click on an empty slot.
          onSecondaryTapUp: canCreate
              ? (d) => context.push(
                  Routes.calendarNew,
                  extra: EventEditArgs.create(
                    date: day,
                    hour: (d.localPosition.dy / _hourHeight).floor().clamp(0, 23),
                  ),
                )
              : null,
          child: Stack(
            children: [
              for (var h = 0; h < 24; h++)
                Positioned(
                  top: h * _hourHeight,
                  left: 0,
                  right: 0,
                  child: Container(height: 0.5, color: scheme.outlineVariant),
                ),
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                child: Container(width: 0.5, color: scheme.outlineVariant),
              ),
              for (final b in blocks)
                Positioned(
                  key: ValueKey('block_${b.occurrence.key}'),
                  top: b.top * _hourHeight / 60,
                  height: (b.bottom - b.top) * _hourHeight / 60 - 1,
                  left: b.column * width / b.columns + 1,
                  width: width / b.columns - 2,
                  child: _BlockTile(occurrence: b.occurrence),
                ),
              if (now != null)
                Positioned(
                  top: _minutes(now!, false) * _hourHeight / 60,
                  left: 0,
                  right: 0,
                  child: Container(height: 2, color: tokens.danger),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BlockTile extends ConsumerWidget {
  const _BlockTile({required this.occurrence});
  final CalendarOccurrence occurrence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = CalendarFormat.color(context, occurrence.event);
    final zone = ref.watch(deviceLocationProvider);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: color.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openOccurrence(context, occurrence),
        child: Container(
          decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 3))),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                occurrence.event.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurface),
              ),
              Flexible(
                child: Text(
                  CalendarFormat.timeRange(context, occurrence, zone),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Agenda
// ---------------------------------------------------------------------------

class AgendaView extends ConsumerStatefulWidget {
  const AgendaView({super.key});

  @override
  ConsumerState<AgendaView> createState() => _AgendaViewState();
}

class _AgendaViewState extends ConsumerState<AgendaView> {
  static const _span = 60;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final from = ref.read(calendarViewProvider).selected;
      final sync = ref.read(calendarSyncProvider.notifier);
      for (var i = 0; i <= _span; i += 28) {
        sync.ensureMonth(from.addDays(i));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final from = ref.watch(calendarViewProvider.select((s) => s.selected));
    final to = from.addDays(_span);
    final data = ref.watch(calendarRangeProvider((from: from, to: to)));
    final zone = ref.watch(deviceLocationProvider);
    final sync = ref.watch(calendarSyncProvider);
    Future<void> refresh() => ref.read(calendarSyncProvider.notifier).sync(around: from);

    return data.when(
      loading: () => const StateView.loading(),
      error: (e, _) => StateView.error(message: CalendarFormat.error(l10n, e), onRetry: refresh),
      data: (list) {
        final byDay = <CalendarDate, List<CalendarOccurrence>>{};
        for (final o in list) {
          if (o.allDay) {
            var d = o.allDayStart!.isBefore(from) ? from : o.allDayStart!;
            while (d.isBefore(o.allDayEnd!) && d.isBefore(to)) {
              (byDay[d] ??= []).add(o);
              d = d.addDays(1);
            }
          } else {
            var d = EventTime.dateIn(o.start, zone);
            if (d.isBefore(from)) d = from;
            (byDay[d] ??= []).add(o);
          }
        }
        final days = byDay.keys.toList()..sort();
        if (days.isEmpty) {
          return sync.offline
              ? StateView.offline(message: l10n.calendarOfflineEmpty, onRetry: refresh)
              : RefreshIndicator(
                  onRefresh: refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: 320,
                        child: StateView.empty(title: l10n.calendarNoEvents, icon: LucideIcons.calendarCheck),
                      ),
                    ],
                  ),
                );
        }
        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView.builder(
            key: const Key('agenda_list'),
            itemCount: days.length,
            itemBuilder: (_, i) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xs),
                  child: Text(
                    CalendarFormat.dayTitle(context, days[i]),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final o in byDay[days[i]]!) OccurrenceTile(occurrence: o),
              ],
            ),
          ),
        );
      },
    );
  }
}
