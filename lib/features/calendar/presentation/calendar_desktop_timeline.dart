import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/platform/desktop.dart';
import '../../../core/theme/tokens.dart';
import '../data/calendar_models.dart';
import '../data/calendar_ops.dart';
import '../domain/calendar_time.dart';
import 'calendar_format.dart';
import 'calendar_providers.dart';
import 'calendar_screen.dart' show occursOn;
import 'calendar_widgets.dart';
import 'event_edit_screen.dart' show EventEditArgs;

/// Height of an hour on the desktop grid, the gutter with the hour labels,
/// and the step times snap to while creating, moving or resizing.
const desktopHourHeight = 48.0;
const _gutter = 56.0;
const _snap = 15;
const _workStart = 8;
const _workEnd = 18;

int _snapped(double minutes, {int step = _snap}) => ((minutes / step).floor() * step).clamp(0, 24 * 60);

/// Minutes past midnight of [day] in [zone] for [instant], clamped to the day.
double _minutesOn(CalendarDate day, DateTime instant, tz.Location zone) {
  final dayStart = EventTime.atWall(day, 0, 0, zone);
  final dayEnd = EventTime.atWall(day.addDays(1), 0, 0, zone);
  if (!instant.isAfter(dayStart)) return 0;
  if (!instant.isBefore(dayEnd)) return 24 * 60;
  final w = EventTime.inZone(instant, zone);
  return (w.hour * 60 + w.minute).toDouble();
}

/// Desktop week / day — the web's time grid: click an empty slot for a
/// 30-minute event, drag over the grid for a longer one, drag an event to
/// another time or day, pull its lower edge to change the end. The red line
/// is the current time (moves with the clock); working hours stay white.
class DesktopTimeline extends ConsumerStatefulWidget {
  const DesktopTimeline({super.key, required this.days});
  final int days;

  @override
  ConsumerState<DesktopTimeline> createState() => _DesktopTimelineState();
}

class _Create {
  _Create(this.day, this.anchor) : from = anchor, to = anchor + 30;
  final int day;
  final int anchor;
  int from;
  int to;
}

class _Move {
  _Move(this.occurrence, this.day, this.origin, {required this.resize});
  final CalendarOccurrence occurrence;
  final int day;
  final Offset origin;
  final bool resize;
  int dayDelta = 0;
  int minuteDelta = 0;
}

class _DesktopTimelineState extends ConsumerState<DesktopTimeline> {
  late final ScrollController _scroll;
  Timer? _tick;
  CalendarDate? _loaded;
  _Create? _create;
  _Move? _move;

  @override
  void initState() {
    super.initState();
    final zone = ref.read(deviceLocationProvider);
    final now = EventTime.inZone(ref.read(calendarClockProvider)(), zone);
    final start = _start(ref.read(calendarViewProvider).selected);
    final today = ref.read(calendarTodayProvider);
    final showsToday = !today.isBefore(start) && today.isBefore(start.addDays(widget.days));
    final hour = showsToday ? math.max(0.0, now.hour + now.minute / 60 - 1.5) : _workStart - 0.5;
    // A little above the hour, so its label is not cut.
    _scroll = ScrollController(initialScrollOffset: math.max(0.0, hour * desktopHourHeight - 12));
    // The now line follows the clock (not under widget tests: no timers).
    if (desktopBackgroundWork) {
      _tick = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  CalendarDate _start(CalendarDate selected) => widget.days == 7 ? selected.startOfWeek : selected;

  void _ensure(CalendarDate start) {
    if (_loaded == start) return;
    _loaded = start;
    Future.microtask(() {
      if (!mounted) return;
      final sync = ref.read(calendarSyncProvider.notifier);
      sync.ensureMonth(start);
      sync.ensureMonth(start.addDays(widget.days - 1));
    });
  }

  Future<void> _createAt(CalendarDate day, int from, int to, {bool allDay = false}) async {
    if (!ref.read(calendarCanCreateProvider)) return;
    final end = to >= 24 * 60 ? day.addDays(1) : day;
    await openEventEditor(
      context,
      allDay
          ? EventEditArgs.create(date: day, allDay: true)
          : EventEditArgs.create(
              date: day,
              hour: from ~/ 60,
              minute: from % 60,
              endDate: to >= 24 * 60 ? day : end,
              endHour: to ~/ 60,
              endMinute: to % 60,
            ),
    );
    if (mounted) setState(() => _create = null);
  }

  Future<void> _finishMove(CalendarDate day, tz.Location zone) async {
    final m = _move;
    if (m == null) return;
    if (m.dayDelta == 0 && m.minuteDelta == 0) {
      setState(() => _move = null);
      return;
    }
    final o = m.occurrence;
    final length = o.end.difference(o.start);
    final DateTime start;
    final DateTime end;
    if (m.resize) {
      start = o.start;
      final e = o.end.add(Duration(minutes: m.minuteDelta));
      end = e.difference(start).inMinutes < _snap ? start.add(const Duration(minutes: _snap)) : e;
    } else {
      final w = EventTime.inZone(o.start, zone);
      start = EventTime.atWall(
        CalendarDate.of(w).addDays(m.dayDelta),
        0,
        0,
        zone,
      ).add(Duration(minutes: w.hour * 60 + w.minute + m.minuteDelta));
      end = start.add(length);
    }
    await rescheduleOccurrence(context, ref, o, start, end);
    if (mounted) setState(() => _move = null);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final start = _start(ref.watch(calendarViewProvider.select((s) => s.selected)));
    _ensure(start);
    final data = ref.watch(calendarRangeProvider((from: start, to: start.addDays(widget.days))));
    final zone = ref.watch(deviceLocationProvider);
    final today = ref.watch(calendarTodayProvider);
    final now = ref.watch(calendarClockProvider)();
    final canCreate = ref.watch(calendarCanCreateProvider);
    final occ = data.value ?? const <CalendarOccurrence>[];
    final allDay = occ.where((o) => o.allDay).toList();
    final timed = occ.where((o) => !o.allDay).toList();
    final days = [for (var i = 0; i < widget.days; i++) start.addDays(i)];
    final hairline = BorderSide(color: t.border, width: t.borderWidth);

    final header = DecoratedBox(
      decoration: BoxDecoration(color: t.surface, border: Border(bottom: hairline)),
      child: Row(
        children: [
          const SizedBox(width: _gutter),
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
                  padding: const EdgeInsets.symmetric(vertical: Space.sm),
                  child: Column(
                    children: [
                      Text(
                        CalendarFormat.weekdayShort(context, day.weekday).toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.9,
                          color: day == today ? t.primary : t.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: day == today ? BoxDecoration(color: t.primary, shape: BoxShape.circle) : null,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontFamily: t.fontDisplay,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: day == today ? t.textInverse : (day.isBefore(today) ? t.textTertiary : t.textPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // Always there, as the web's «Весь день» row: click an empty cell for an
    // all-day event.
    final allDayRow = DecoratedBox(
      decoration: BoxDecoration(color: t.surface, border: Border(bottom: hairline)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 34, maxHeight: 96),
        child: SingleChildScrollView(
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _gutter,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, right: 8),
                    child: Center(
                      child: Text(
                        l10n.calendarAllDay,
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        style: TextStyle(fontSize: 10, height: 1.1, color: t.textTertiary),
                      ),
                    ),
                  ),
                ),
                for (final day in days)
                  Expanded(
                    child: GestureDetector(
                      key: ValueKey('allday_${day.key}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: canCreate ? () => _createAt(day, 0, 0, allDay: true) : null,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 34),
                        decoration: BoxDecoration(border: Border(left: hairline)),
                        padding: const EdgeInsets.all(2),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final o in allDay.where((o) => occursOn(o, day, zone)))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: _AllDayChip(occurrence: o),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final grid = SingleChildScrollView(
      key: Key('desktop_timeline_${widget.days}'),
      controller: _scroll,
      child: SizedBox(
        height: 24 * desktopHourHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _gutter,
              child: Stack(
                children: [
                  for (var h = 1; h < 24; h++)
                    Positioned(
                      top: h * desktopHourHeight - 7,
                      right: 8,
                      child: Text(
                        '${h.toString().padLeft(2, '0')}:00',
                        style: TextStyle(fontSize: 10, color: t.textTertiary, fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final columnWidth = c.maxWidth / widget.days;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < days.length; i++)
                        Expanded(
                          child: _column(
                            context,
                            index: i,
                            day: days[i],
                            zone: zone,
                            now: days[i] == today ? now : null,
                            isPast: days[i].isBefore(today),
                            columnWidth: columnWidth,
                            occurrences: timed.where((o) => occursOn(o, days[i], zone)).toList(),
                            canCreate: canCreate,
                          ),
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

    return ColoredBox(
      color: t.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, allDayRow, Expanded(child: grid)],
      ),
    );
  }

  Widget _column(
    BuildContext context, {
    required int index,
    required CalendarDate day,
    required tz.Location zone,
    required DateTime? now,
    required bool isPast,
    required double columnWidth,
    required List<CalendarOccurrence> occurrences,
    required bool canCreate,
  }) {
    final t = context.tokens;
    final l10n = context.l10n;
    final weekend = day.weekday >= 6;
    final blocks = _layout(day, zone, occurrences);
    final create = _create?.day == index ? _create : null;
    final move = _move;
    // The event being dragged, where it would land in this column.
    Widget? ghost;
    if (move != null && move.day + (move.resize ? 0 : move.dayDelta) == index) {
      final o = move.occurrence;
      final top = _minutesOn(day.addDays(move.resize ? 0 : -move.dayDelta), o.start, zone) +
          (move.resize ? 0 : move.minuteDelta);
      final length = o.end.difference(o.start).inMinutes;
      final bottom = move.resize
          ? math.max(top + _snap, _minutesOn(day, o.end, zone) + move.minuteDelta)
          : top + length;
      ghost = Positioned(
        key: const ValueKey('timeline_ghost'),
        top: top.clamp(0, 24 * 60) * desktopHourHeight / 60,
        height: math.max(12.0, (bottom.clamp(0, 24 * 60) - top.clamp(0, 24 * 60)) * desktopHourHeight / 60 - 1),
        left: 2,
        right: 6,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CalendarFormat.color(context, o.event).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(t.radiusSm),
              border: Border.all(color: CalendarFormat.color(context, o.event), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                _rangeLabel(context, day, top.round(), bottom.round()),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.textPrimary),
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth - 6; // room on the right to click the slot
        return GestureDetector(
          key: ValueKey('timeline_column_${day.key}'),
          behavior: HitTestBehavior.opaque,
          // Measured from where the button went down, not where the drag
          // was recognised.
          dragStartBehavior: DragStartBehavior.down,
          onTapUp: canCreate
              ? (d) {
                  final from = _snapped(d.localPosition.dy / desktopHourHeight * 60, step: 30);
                  setState(() => _create = _Create(index, from));
                  unawaited(_createAt(day, from, math.min(from + 30, 24 * 60)));
                }
              : null,
          onPanStart: canCreate
              ? (d) => setState(() => _create = _Create(index, _snapped(d.localPosition.dy / desktopHourHeight * 60)))
              : null,
          onPanUpdate: canCreate
              ? (d) {
                  final c = _create;
                  if (c == null) return;
                  final at = _snapped(d.localPosition.dy / desktopHourHeight * 60 + _snap);
                  setState(() {
                    c.from = math.min(c.anchor, at - _snap);
                    c.to = math.max(c.anchor + _snap, at);
                  });
                }
              : null,
          onPanEnd: canCreate
              ? (_) {
                  final c = _create;
                  if (c != null) unawaited(_createAt(day, c.from, c.to));
                }
              : null,
          onPanCancel: () => setState(() => _create = null),
          onSecondaryTapUp: canCreate
              ? (d) => _slotMenu(context, d.globalPosition, () {
                  final from = _snapped(d.localPosition.dy / desktopHourHeight * 60, step: 30);
                  setState(() => _create = _Create(index, from));
                  unawaited(_createAt(day, from, math.min(from + 30, 24 * 60)));
                }, l10n)
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Off hours and weekends are shaded, as in the web grid.
              Positioned.fill(child: ColoredBox(color: weekend ? t.surfaceSubtle : t.surface)),
              if (!weekend) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _workStart * desktopHourHeight,
                  child: ColoredBox(color: t.surfaceSubtle),
                ),
                Positioned(
                  top: _workEnd * desktopHourHeight,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ColoredBox(color: t.surfaceSubtle),
                ),
              ],
              for (var h = 0; h < 24; h++) ...[
                Positioned(
                  top: h * desktopHourHeight,
                  left: 0,
                  right: 0,
                  child: Container(height: t.borderWidth, color: t.border),
                ),
                Positioned(
                  top: (h + 0.5) * desktopHourHeight,
                  left: 0,
                  right: 0,
                  child: Container(height: 0.5, color: t.border.withValues(alpha: 0.45)),
                ),
              ],
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                child: Container(width: t.borderWidth, color: t.border),
              ),
              if (create != null)
                Positioned(
                  key: const ValueKey('timeline_new_slot'),
                  top: create.from * desktopHourHeight / 60,
                  height: (create.to - create.from) * desktopHourHeight / 60 - 1,
                  left: 2,
                  right: 6,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: t.primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(t.radiusSm),
                        border: Border.all(color: t.primary, width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          _rangeLabel(context, day, create.from, create.to),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.primary),
                        ),
                      ),
                    ),
                  ),
                ),
              for (final b in blocks)
                Positioned(
                  key: ValueKey('block_${b.occurrence.key}'),
                  top: b.top * desktopHourHeight / 60,
                  height: math.max(14.0, (b.bottom - b.top) * desktopHourHeight / 60 - 1),
                  left: b.column * width / b.columns + 1,
                  width: width / b.columns - 2,
                  child: Opacity(
                    opacity: move?.occurrence.key == b.occurrence.key ? 0.35 : 1,
                    child: _Block(
                      occurrence: b.occurrence,
                      zone: zone,
                      isPast: isPast || (now != null && !b.occurrence.end.isAfter(now)),
                      onMoveStart: (origin, resize) =>
                          setState(() => _move = _Move(b.occurrence, index, origin, resize: resize)),
                      onMoveUpdate: (global) {
                        final m = _move;
                        if (m == null) return;
                        final delta = global - m.origin;
                        final minutes = (delta.dy / desktopHourHeight * 60 / _snap).round() * _snap;
                        final dayDelta = m.resize
                            ? 0
                            : (delta.dx / columnWidth).round().clamp(-m.day, widget.days - 1 - m.day);
                        if (minutes != m.minuteDelta || dayDelta != m.dayDelta) {
                          setState(() {
                            m.minuteDelta = minutes;
                            m.dayDelta = dayDelta;
                          });
                        }
                      },
                      onMoveEnd: () => _finishMove(day, zone),
                    ),
                  ),
                ),
              ?ghost,
              if (now != null) ...[
                Positioned(
                  key: const ValueKey('timeline_now'),
                  top: _minutesOn(day, now, zone) * desktopHourHeight / 60 - 1,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(child: Container(height: 2, color: t.danger)),
                ),
                Positioned(
                  top: _minutesOn(day, now, zone) * desktopHourHeight / 60 - 5,
                  left: -5,
                  child: IgnorePointer(
                    child: Container(width: 10, height: 10, decoration: BoxDecoration(color: t.danger, shape: BoxShape.circle)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _rangeLabel(BuildContext context, CalendarDate day, int from, int to) {
    String hm(int m) => '${(m ~/ 60).clamp(0, 24).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
    return '${hm(from)}–${hm(to)}';
  }

  Future<void> _slotMenu(BuildContext context, Offset at, VoidCallback create, AppLocalizations l10n) async {
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
            title: Text(l10n.desktopCalendarNewHere),
          ),
        ),
      ],
    );
    if (picked == 0) create();
  }
}

class _Slot {
  _Slot(this.occurrence, this.top, this.bottom);
  final CalendarOccurrence occurrence;
  final double top;
  final double bottom;
  int column = 0;
  int columns = 1;
}

/// Side-by-side columns inside clusters of overlapping events.
List<_Slot> _layout(CalendarDate day, tz.Location zone, List<CalendarOccurrence> occurrences) {
  final slots = [
    for (final o in occurrences)
      () {
        final top = _minutesOn(day, o.start, zone);
        return _Slot(o, top, math.max(_minutesOn(day, o.end, zone), top + 20));
      }(),
  ]..sort((a, b) => a.top != b.top ? a.top.compareTo(b.top) : b.bottom.compareTo(a.bottom));
  var cluster = <_Slot>[];
  var clusterEnd = -1.0;
  void close() {
    final cols = cluster.fold<int>(0, (m, b) => math.max(m, b.column + 1));
    for (final b in cluster) {
      b.columns = cols;
    }
    cluster = [];
  }

  for (final b in slots) {
    if (b.top >= clusterEnd && cluster.isNotEmpty) close();
    final used = {
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
  return slots;
}

/// A timed event on the grid: the web's soft block with a coloured edge,
/// title and time (one line when short). Click opens it, drag moves it,
/// the lower edge changes the end, right click has the menu.
class _Block extends ConsumerStatefulWidget {
  const _Block({
    required this.occurrence,
    required this.zone,
    required this.isPast,
    required this.onMoveStart,
    required this.onMoveUpdate,
    required this.onMoveEnd,
  });

  final CalendarOccurrence occurrence;
  final tz.Location zone;
  final bool isPast;
  final void Function(Offset origin, bool resize) onMoveStart;
  final ValueChanged<Offset> onMoveUpdate;
  final VoidCallback onMoveEnd;

  @override
  ConsumerState<_Block> createState() => _BlockState();
}

class _BlockState extends ConsumerState<_Block> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final o = widget.occurrence;
    final e = o.event;
    final color = CalendarFormat.color(context, e);
    final canEdit = !o.pending && canEditOccurrence(ref, o);
    final declined = e.responseStatus == RsvpStatus.declined;
    final pendingAnswer = e.responseStatus == RsvpStatus.pending && e.organizerId != ref.read(calendarRepositoryProvider).selfId;
    final selected = ref.watch(desktopCalendarDetailProvider)?.key == o.key;
    final time = CalendarFormat.timeRange(context, o, widget.zone);
    final titleStyle = TextStyle(
      fontSize: 12,
      height: 1.25,
      fontWeight: FontWeight.w600,
      color: t.textPrimary,
      decoration: declined ? TextDecoration.lineThrough : null,
    );
    final timeStyle = TextStyle(fontSize: 11, height: 1.25, color: t.textSecondary);
    final body = LayoutBuilder(
      builder: (context, c) {
        final short = c.maxHeight < 34;
        return Padding(
          padding: EdgeInsets.fromLTRB(6, short ? 0 : 3, 4, 0),
          child: short
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: e.title, style: titleStyle),
                      TextSpan(text: ', ${CalendarFormat.hm(context, o.start, widget.zone)}', style: timeStyle),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title, maxLines: c.maxHeight > 60 ? 2 : 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                    Text(time, maxLines: 1, overflow: TextOverflow.clip, style: timeStyle),
                    if (e.location.isNotEmpty && c.maxHeight > 64)
                      Text(e.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: timeStyle),
                  ],
                ),
        );
      },
    );

    Widget tile = Container(
      decoration: BoxDecoration(
        color: pendingAnswer
            ? t.surface
            : Color.alphaBlend(color.withValues(alpha: selected || _hover ? 0.26 : 0.16), t.surface),
        borderRadius: BorderRadius.circular(t.radiusSm),
        border: pendingAnswer || selected
            ? Border.all(color: color, width: selected ? 1.5 : 1)
            : Border.all(color: t.surface, width: 0.5),
        boxShadow: _hover ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))] : null,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusSm),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Opacity(opacity: widget.isPast && !selected ? 0.7 : 1, child: body),
    );

    tile = GestureDetector(
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onTap: () => openOccurrence(context, o),
      onSecondaryTapUp: (d) => _menu(context, d.globalPosition, canEdit),
      onPanStart: canEdit ? (d) => widget.onMoveStart(d.globalPosition, false) : null,
      onPanUpdate: canEdit ? (d) => widget.onMoveUpdate(d.globalPosition) : null,
      onPanEnd: canEdit ? (_) => widget.onMoveEnd() : null,
      child: MouseRegion(
        cursor: canEdit ? SystemMouseCursors.grab : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: tile,
      ),
    );

    return Tooltip(
      waitDuration: const Duration(milliseconds: 600),
      message: [e.title, time, if (e.location.isNotEmpty) e.location].join('\n'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          tile,
          if (canEdit)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 6,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeRow,
                child: GestureDetector(
                  key: ValueKey('block_resize_${o.key}'),
                  behavior: HitTestBehavior.opaque,
                  dragStartBehavior: DragStartBehavior.down,
                  onVerticalDragStart: (d) => widget.onMoveStart(d.globalPosition, true),
                  onVerticalDragUpdate: (d) => widget.onMoveUpdate(d.globalPosition),
                  onVerticalDragEnd: (_) => widget.onMoveEnd(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _menu(BuildContext context, Offset at, bool canEdit) async {
    final l10n = context.l10n;
    final o = widget.occurrence;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    PopupMenuItem<int> item(int value, IconData icon, String label) => PopupMenuItem(
      value: value,
      child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(icon, size: 18), title: Text(label)),
    );
    final picked = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(at & const Size(1, 1), Offset.zero & overlay.size),
      items: [
        item(0, LucideIcons.panelRightOpen, l10n.desktopCalendarOpen),
        if (canEdit) ...[
          item(1, LucideIcons.pencil, l10n.calendarEdit),
          item(2, LucideIcons.trash2, l10n.calendarDelete),
        ],
      ],
    );
    if (!context.mounted || picked == null) return;
    switch (picked) {
      case 0:
        openOccurrence(context, o);
      case 1:
        await editOccurrence(context, o);
      case 2:
        await deleteOccurrence(context, ref, o);
    }
  }
}

class _AllDayChip extends ConsumerWidget {
  const _AllDayChip({required this.occurrence});
  final CalendarOccurrence occurrence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final color = CalendarFormat.color(context, occurrence.event);
    final selected = ref.watch(desktopCalendarDetailProvider)?.key == occurrence.key;
    return Material(
      color: Color.alphaBlend(color.withValues(alpha: selected ? 0.3 : 0.18), t.surface),
      borderRadius: BorderRadius.circular(t.radiusSm),
      child: InkWell(
        key: ValueKey('allday_chip_${occurrence.key}'),
        borderRadius: BorderRadius.circular(t.radiusSm),
        onTap: () => openOccurrence(context, occurrence),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 3))),
          child: Text(
            occurrence.event.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// «Изменить» outside the event screen: which occurrences for a series, then
/// the editor.
Future<void> editOccurrence(BuildContext context, CalendarOccurrence o) async {
  final e = o.event;
  var scope = EditScope.single;
  if ((e.isRecurring || e.isOverride) && o.localId == null) {
    final picked = await askScope(context, delete: false);
    if (picked == null) return;
    scope = picked;
  }
  if (!context.mounted) return;
  await openEventEditor(context, EventEditArgs.edit(occurrence: o, scope: scope));
}

/// «Удалить» outside the event screen, as the event screen asks it.
Future<void> deleteOccurrence(BuildContext context, WidgetRef ref, CalendarOccurrence o) async {
  final l10n = context.l10n;
  final e = o.event;
  var scope = EditScope.single;
  if ((e.isRecurring || e.isOverride) && o.localId == null) {
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
    await ref.read(calendarRepositoryProvider).delete(occurrence: o, scope: scope);
    final panel = ref.read(desktopCalendarDetailProvider.notifier);
    if (ref.read(desktopCalendarDetailProvider)?.key == o.key) panel.show(null);
  } on PlanError catch (err) {
    messenger.showSnackBar(SnackBar(content: Text(CalendarFormat.error(l10n, err))));
  } on AppException catch (err) {
    messenger.showSnackBar(SnackBar(content: Text(CalendarFormat.error(l10n, err))));
  }
}

/// An event dragged [days] days on the month grid: same time (all-day
/// events keep their length).
Future<void> moveOccurrenceByDays(BuildContext context, WidgetRef ref, CalendarOccurrence o, int days) async {
  if (days == 0) return;
  if (o.allDay) {
    final tzName = CalendarZones.isKnown(o.event.timezone) ? o.event.timezone : ref.read(deviceZoneProvider);
    final (start, end) = EventTime.encodeAllDay(
      o.allDayStart!.addDays(days),
      o.allDayEnd!.addDays(days - 1),
      CalendarZones.location(tzName),
    );
    return rescheduleOccurrence(context, ref, o, start, end, allDay: true);
  }
  final zone = ref.read(deviceLocationProvider);
  final w = EventTime.inZone(o.start, zone);
  final start = EventTime.atWall(CalendarDate.of(w).addDays(days), w.hour, w.minute, zone);
  return rescheduleOccurrence(context, ref, o, start, start.add(o.end.difference(o.start)));
}

/// An event dragged to [start]–[end] on the grid: everything else as it is
/// (the stored reminders, participants, repeat); a series asks which
/// occurrences first, like «Изменить».
Future<void> rescheduleOccurrence(
  BuildContext context,
  WidgetRef ref,
  CalendarOccurrence o,
  DateTime start,
  DateTime end, {
  bool allDay = false,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final e = o.event;
  var scope = EditScope.single;
  if ((e.isRecurring || e.isOverride) && o.localId == null) {
    final picked = await askScope(context, delete: false);
    if (picked == null) return;
    scope = picked;
  }
  final repo = ref.read(calendarRepositoryProvider);
  try {
    final reminders = await repo.cache.reminders(e.seriesKey);
    CalendarEventDetail? detail;
    if (!e.id.startsWith('local:')) {
      try {
        detail = await repo.detail(e.seriesKey);
      } on AppException {
        detail = null;
      }
    }
    final selfId = repo.selfId;
    final draft = EventDraft(
      title: e.title,
      description: e.description,
      location: e.location,
      meetingLink: e.meetingLink,
      allDay: allDay,
      start: start,
      end: end,
      timezone: e.timezone.isEmpty ? ref.read(deviceZoneProvider) : e.timezone,
      recurrence: e.recurrence ?? detail?.event.recurrence,
      reminders: reminders ?? [e.reminderMinutes],
      participants: [
        for (final p in detail?.participants ?? const <CalendarParticipant>[])
          if (!p.isOrganizer && p.userId != selfId)
            p.isExternal
                ? DraftParticipant.external(p.externalEmail ?? p.email)
                : DraftParticipant.internal(userId: p.userId!, label: p.label, email: p.email),
      ],
      eventType: e.eventType,
      visibility: e.isPrivate ? 'private' : 'default',
    );
    await repo.edit(occurrence: o, draft: draft, scope: scope);
    // The panel showed the old time.
    if (ref.read(desktopCalendarDetailProvider)?.key == o.key) {
      ref.read(desktopCalendarDetailProvider.notifier).show(null);
    }
  } on PlanError catch (err) {
    messenger.showSnackBar(SnackBar(content: Text(CalendarFormat.error(l10n, err))));
  } on AppException catch (err) {
    messenger.showSnackBar(SnackBar(content: Text(CalendarFormat.error(l10n, err))));
  }
}
