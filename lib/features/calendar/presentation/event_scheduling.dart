import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import '../data/calendar_models.dart';
import '../domain/calendar_time.dart';
import 'calendar_format.dart';
import 'calendar_providers.dart';
import '../../../shared/widgets/app_sheet.dart';

/// Form section: busy intervals of the caller and the chosen colleagues on
/// the chosen day (`POST /calendar/free-busy`), «Подобрать время»
/// (`POST /calendar/find-time`, up to 5 chips) and the room picker
/// (`GET /calendar/resources`, active rooms) with the room's bookings.
class EventSchedulingSection extends ConsumerStatefulWidget {
  const EventSchedulingSection({
    super.key,
    required this.participants,
    required this.date,
    required this.zone,
    required this.start,
    required this.end,
    required this.allDay,
    required this.resourceId,
    required this.allowRoomChange,
    required this.onRoomChanged,
    required this.onSuggestion,
  });

  final List<DraftParticipant> participants;

  /// Day shown, in [zone] (the event zone of the form).
  final CalendarDate date;
  final tz.Location zone;

  /// Currently chosen instants (for conflict highlighting and duration).
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String? resourceId;

  /// Rooms can only be booked on create (PATCH has no `resource_id`).
  final bool allowRoomChange;
  final void Function(CalendarResource? room) onRoomChanged;
  final void Function(DateTime start, DateTime end) onSuggestion;

  @override
  ConsumerState<EventSchedulingSection> createState() =>
      _EventSchedulingSectionState();
}

class _EventSchedulingSectionState
    extends ConsumerState<EventSchedulingSection> {
  static const findTimeHorizon = Duration(days: 7);

  Timer? _debounce;
  String? _loadedKey;
  FreeBusyResult? _busy;
  Object? _busyError;
  bool _busyLoading = false;
  int _busyGeneration = 0;

  List<CalendarInterval>? _suggestions;
  Object? _findError;
  bool _finding = false;

  String get _selfId => ref.read(calendarRepositoryProvider).selfId;

  List<String> get _userIds {
    final ids = <String>{
      if (_selfId.isNotEmpty) _selfId,
      for (final p in widget.participants)
        if (p.userId != null) p.userId!,
    };
    return ids.toList();
  }

  String get _key =>
      '${_userIds.join(',')}|${widget.date}|${widget.zone.name}|${widget.resourceId ?? ''}';

  @override
  void initState() {
    super.initState();
    _schedule(immediate: true);
  }

  @override
  void didUpdateWidget(covariant EventSchedulingSection old) {
    super.didUpdateWidget(old);
    final participantsChanged =
        old.participants.map((p) => p.key).join(',') !=
        widget.participants.map((p) => p.key).join(',');
    if (participantsChanged || old.date != widget.date) _suggestions = null;
    if (_key != _loadedKey) _schedule();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _schedule({bool immediate = false}) {
    _debounce?.cancel();
    if (immediate) {
      Future.microtask(_loadBusy);
    } else {
      _debounce = Timer(const Duration(milliseconds: 400), _loadBusy);
    }
  }

  (DateTime, DateTime) get _dayWindow => (
    EventTime.atWall(widget.date, 0, 0, widget.zone),
    EventTime.atWall(widget.date.addDays(1), 0, 0, widget.zone),
  );

  Future<void> _loadBusy() async {
    if (!mounted) return;
    final key = _key;
    final ids = _userIds;
    _loadedKey = key;
    if (ids.isEmpty && (widget.resourceId ?? '').isEmpty) {
      setState(() {
        _busy = null;
        _busyError = null;
      });
      return;
    }
    final generation = ++_busyGeneration;
    setState(() {
      _busyLoading = true;
      _busyError = null;
    });
    final (from, to) = _dayWindow;
    try {
      final result = await ref
          .read(calendarApiProvider)
          .freeBusy(
            userIds: ids,
            start: from,
            end: to,
            resourceId: widget.resourceId,
          );
      if (!mounted || generation != _busyGeneration) return;
      setState(() => _busy = result);
    } on AppException catch (e) {
      if (!mounted || generation != _busyGeneration) return;
      setState(() => _busyError = e);
    } finally {
      if (mounted && generation == _busyGeneration) {
        setState(() => _busyLoading = false);
      }
    }
  }

  Future<void> _findTime() async {
    if (_finding) return;
    final ids = _userIds;
    if (ids.isEmpty) return;
    final (dayStart, _) = _dayWindow;
    final now = ref.read(calendarClockProvider)().toUtc();
    final from = dayStart.isAfter(now) ? dayStart : now;
    final to = dayStart.add(findTimeHorizon);
    final minutes = widget.allDay
        ? 0
        : widget.end.difference(widget.start).inMinutes;
    setState(() {
      _finding = true;
      _findError = null;
    });
    try {
      final slots = to.isAfter(from)
          ? await ref
                .read(calendarApiProvider)
                .findTime(
                  userIds: ids,
                  start: from,
                  end: to,
                  durationMinutes: minutes,
                )
          : const <CalendarInterval>[];
      if (mounted) setState(() => _suggestions = slots);
    } on AppException catch (e) {
      if (mounted) setState(() => _findError = e);
    } finally {
      if (mounted) setState(() => _finding = false);
    }
  }

  Future<void> _pickRoom() async {
    final picked = await showAppSheet<_RoomChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _RoomPicker(selectedId: widget.resourceId),
    );
    if (picked != null) widget.onRoomChanged(picked.room);
  }

  String _range(CalendarInterval i) =>
      '${CalendarFormat.hm(context, i.start, widget.zone)}–${CalendarFormat.hm(context, i.end, widget.zone)}';

  String _participantLabel(String id) {
    if (id == _selfId) return context.l10n.calendarBusyYou;
    return widget.participants
            .where((p) => p.userId == id)
            .map((p) => p.label)
            .firstOrNull ??
        id;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final busy = _busy;
    final ids = _userIds;
    final rooms = widget.allowRoomChange || widget.resourceId != null
        ? ref.watch(calendarResourcesProvider)
        : null;
    final room = rooms?.value
        ?.where((r) => r.id == widget.resourceId)
        .firstOrNull;
    final roomConflict =
        !widget.allDay &&
        widget.resourceId != null &&
        (busy?.resourceBusy.any((i) => i.overlaps(widget.start, widget.end)) ??
            false);

    Widget intervals(List<CalendarInterval> list, {Key? key}) {
      if (list.isEmpty) {
        return Text(l10n.calendarBusyFree, key: key, style: TextStyle(color: tokens.success));
      }
      return Wrap(
        key: key,
        spacing: Space.xs,
        runSpacing: Space.xs,
        children: [
          for (final i in list)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
              decoration: BoxDecoration(
                color: (!widget.allDay && i.overlaps(widget.start, widget.end)
                        ? tokens.danger
                        : tokens.textMuted)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(Space.sm),
              ),
              child: Text(
                _range(i),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: !widget.allDay && i.overlaps(widget.start, widget.end)
                      ? tokens.danger
                      : null,
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      key: const Key('event_scheduling'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Row(
          children: [
            Expanded(
              child: Text(
                '${l10n.calendarBusyTitle} · ${CalendarFormat.shortDate(context, widget.date)}',
                style: theme.textTheme.titleSmall,
              ),
            ),
            if (_busyLoading)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        const SizedBox(height: Space.xs),
        if (_busyError != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.calendarBusyUnavailable,
                  key: const Key('busy_error'),
                  style: TextStyle(color: tokens.textMuted),
                ),
              ),
              IconButton(
                tooltip: l10n.retry,
                icon: const Icon(LucideIcons.refreshCw),
                onPressed: _loadBusy,
              ),
            ],
          )
        else if (busy != null)
          for (final id in ids)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      _participantLabel(id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: intervals(
                      busy.busy[id] ?? const [],
                      key: ValueKey('busy_$id'),
                    ),
                  ),
                ],
              ),
            ),
        if (widget.allowRoomChange)
          ListTile(
            key: const Key('event_room'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(LucideIcons.doorOpen),
            title: Text(l10n.calendarRoom),
            subtitle: Text(
              widget.resourceId == null
                  ? l10n.calendarRoomNone
                  : (room?.name ?? l10n.loading),
            ),
            onTap: _pickRoom,
          ),
        if (widget.resourceId != null && busy != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 112, child: Text(l10n.calendarRoomBusy)),
              Expanded(
                child: intervals(
                  busy.resourceBusy,
                  key: const Key('room_busy'),
                ),
              ),
            ],
          ),
          if (roomConflict)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(
                l10n.calendarRoomBusyWarning,
                key: const Key('room_busy_warning'),
                style: TextStyle(color: tokens.danger),
              ),
            ),
        ],
        const SizedBox(height: Space.sm),
        Row(
          children: [
            OutlinedButton.icon(
              key: const Key('calendar_find_time'),
              onPressed: _finding || ids.isEmpty ? null : _findTime,
              icon: _finding
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.sparkles),
              label: Text(l10n.calendarFindTime),
            ),
          ],
        ),
        Text(
          l10n.calendarFindTimeHint,
          style: theme.textTheme.bodySmall?.copyWith(color: tokens.textMuted),
        ),
        if (_findError != null)
          Text(
            CalendarFormat.error(l10n, _findError!),
            key: const Key('find_time_error'),
            style: TextStyle(color: tokens.danger),
          )
        else if (_suggestions != null && _suggestions!.isEmpty)
          Text(
            l10n.calendarFindTimeEmpty,
            key: const Key('find_time_empty'),
            style: TextStyle(color: tokens.textMuted),
          )
        else if (_suggestions != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                for (final (i, s) in _suggestions!.indexed)
                  ActionChip(
                    key: ValueKey('time_suggestion_$i'),
                    avatar: const Icon(LucideIcons.clock, size: 18),
                    label: Text(
                      '${DateFormat.MMMEd(Localizations.localeOf(context).toString()).format(CalendarDate.of(EventTime.inZone(s.start, widget.zone)).forFormatting)}, ${_range(s)}',
                    ),
                    onPressed: () => widget.onSuggestion(s.start, s.end),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RoomChoice {
  const _RoomChoice(this.room);
  final CalendarResource? room;
}

class _RoomPicker extends ConsumerWidget {
  const _RoomPicker({required this.selectedId});
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final rooms = ref.watch(calendarResourcesProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: rooms.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Space.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Text(CalendarFormat.error(l10n, e)),
          ),
          data: (list) => ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                key: const Key('room_none'),
                leading: const Icon(LucideIcons.ban),
                title: Text(l10n.calendarRoomNone),
                selected: selectedId == null,
                onTap: () => Navigator.pop(context, const _RoomChoice(null)),
              ),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Text(l10n.calendarRoomsEmpty, style: TextStyle(color: tokens.textMuted)),
                ),
              for (final r in list)
                ListTile(
                  key: ValueKey('room_${r.id}'),
                  leading: const Icon(LucideIcons.doorOpen),
                  title: Text(r.name),
                  subtitle: Text(
                    [
                      if (r.location.isNotEmpty) r.location,
                      if (r.capacity > 0) l10n.calendarRoomSeats(r.capacity),
                      if (r.equipment.isNotEmpty) r.equipment,
                    ].join(' · '),
                  ),
                  selected: r.id == selectedId,
                  onTap: () => Navigator.pop(context, _RoomChoice(r)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
