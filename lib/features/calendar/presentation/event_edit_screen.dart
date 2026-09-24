import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:uuid/uuid.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/platform/desktop.dart';
import '../../../core/platform/desktop_keys.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../calls/data/meetings.dart';
import '../../calls/presentation/calls_providers.dart';
import '../../chat/presentation/chat_providers.dart';
import '../data/calendar_models.dart';
import '../data/calendar_ops.dart';
import '../domain/calendar_time.dart';
import '../domain/ics_invite.dart';
import '../domain/recurrence.dart';
import 'calendar_format.dart';
import 'calendar_providers.dart';
import 'event_scheduling.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/initials_avatar.dart';

part 'event_edit_desktop.dart';

/// Reminder offsets offered in the UI (minutes before start).
const reminderPresets = [0, 5, 10, 15, 30, 60, 120, 1440];

class EventEditArgs {
  const EventEditArgs.create({
    this.date,
    this.hour,
    this.minute = 0,
    this.endDate,
    this.endHour,
    this.endMinute = 0,
    this.allDay = false,
    this.title = '',
    this.participants = const [],
  }) : occurrence = null,
       invite = null,
       scope = EditScope.single;

  const EventEditArgs.edit({
    required CalendarOccurrence this.occurrence,
    required this.scope,
  }) : date = null,
       hour = null,
       minute = 0,
       endDate = null,
       endHour = null,
       endMinute = 0,
       allDay = false,
       title = '',
       participants = const [],
       invite = null;

  /// Desktop: a new event filled from a `.ics` opened with XatBox.
  const EventEditArgs.invite(IcsInvite this.invite)
    : date = null,
      hour = null,
      minute = 0,
      endDate = null,
      endHour = null,
      endMinute = 0,
      allDay = false,
      title = '',
      participants = const [],
      occurrence = null,
      scope = EditScope.single;

  final CalendarDate? date;
  final int? hour;

  /// Desktop «Назначить встречу» (a contact, a letter): the title and the
  /// people invited to start with.
  final String title;
  final List<DraftParticipant> participants;

  /// Desktop: the start minute and the end of a slot picked on the grid
  /// ([endHour] null = one hour after the start), or an all-day event.
  final int minute;
  final CalendarDate? endDate;
  final int? endHour;
  final int endMinute;
  final bool allDay;
  final CalendarOccurrence? occurrence;
  final IcsInvite? invite;
  final EditScope scope;

  bool get isCreate => occurrence == null;
}

/// Create / edit form. Times are entered in the event's zone (the device
/// zone by default); the repository plans the API calls.
class EventEditScreen extends ConsumerStatefulWidget {
  const EventEditScreen({super.key, required this.args, this.onDone});
  final EventEditArgs args;

  /// Desktop dialog: closes it after saving (instead of popping the route).
  final VoidCallback? onDone;

  @override
  ConsumerState<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends ConsumerState<EventEditScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _link = TextEditingController();
  final _description = TextEditingController();
  final _external = TextEditingController();

  late String _timezone;
  bool _allDay = false;
  late CalendarDate _startDate;
  late CalendarDate _endDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  RecurrenceSpec? _recurrence;
  List<int> _reminders = const [15];
  List<DraftParticipant> _participants = const [];
  String _category = 'personal';
  bool _private = false;
  bool _saving = false;
  bool _participantsKnown = true;
  String? _timeError;
  CalendarEventDetail? _detail;

  /// Room to book (create only).
  String? _resourceId;

  /// «Добавить видеовстречу XatBox»; the code once the event has a meeting.
  bool _xatboxMeeting = false;
  String? _meetingCode;

  /// One id per form: a retried save never creates a second meeting.
  final String _meetingClientId = const Uuid().v4();

  EventEditArgs get _args => widget.args;

  /// For the desktop form (a separate widget sharing this state).
  void _set(VoidCallback fn) => setState(fn);
  bool get _singleOccurrence => _args.scope == EditScope.thisOccurrence;

  @override
  void initState() {
    super.initState();
    final device = ref.read(deviceZoneProvider);
    final o = _args.occurrence;
    if (o == null) {
      _timezone = device;
      final now = EventTime.inZone(ref.read(calendarClockProvider)(), CalendarZones.location(device));
      _startDate = _args.date ?? CalendarDate.of(now);
      final hour = _args.hour ?? math.min(now.hour + 1, 22);
      _startTime = TimeOfDay(hour: hour, minute: 0);
      _endDate = _startDate;
      _endTime = TimeOfDay(hour: hour + 1, minute: 0);
      _desktopSlot(now);
      if (_args.title.isNotEmpty) _title.text = _args.title;
      if (_args.participants.isNotEmpty) _participants = [..._args.participants];
      final invite = _args.invite;
      if (invite != null) _fillFromInvite(invite);
      return;
    }
    final e = o.event;
    _timezone = CalendarZones.isKnown(e.timezone) ? e.timezone : device;
    final zone = CalendarZones.location(_timezone);
    _title.text = e.title;
    _location.text = e.location;
    _link.text = e.meetingLink;
    _description.text = e.description;
    _meetingCode = XatBoxMeetingLinks.meetingCodeIn('${e.meetingLink}\n${e.description}');
    _allDay = o.allDay;
    if (o.allDay) {
      _startDate = o.allDayStart!;
      _endDate = o.allDayEnd!.addDays(-1);
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endTime = const TimeOfDay(hour: 10, minute: 0);
    } else {
      final s = EventTime.inZone(o.start, zone);
      final en = EventTime.inZone(o.end, zone);
      _startDate = CalendarDate.of(s);
      _endDate = CalendarDate.of(en);
      _startTime = TimeOfDay(hour: s.hour, minute: s.minute);
      _endTime = TimeOfDay(hour: en.hour, minute: en.minute);
    }
    _recurrence = e.recurrence;
    _category = e.eventType;
    _private = e.isPrivate;
    _reminders = [e.reminderMinutes];
    _participantsKnown = e.audienceType == 'only_me' || e.id.startsWith('local:');
    unawaited(_loadExisting(o));
  }

  /// The slot picked on the grid, or — like the web — the next half hour
  /// for 30 minutes.
  void _desktopSlot(DateTime now) {
    _allDay = _args.allDay;
    if (_args.hour != null) {
      _startTime = TimeOfDay(hour: _args.hour!, minute: _args.minute);
      final endHour = _args.endHour;
      if (endHour != null) {
        _endDate = _args.endDate ?? _startDate;
        _endTime = endHour >= 24 ? const TimeOfDay(hour: 23, minute: 59) : TimeOfDay(hour: endHour, minute: _args.endMinute);
      }
      return;
    }
    final today = CalendarDate.of(now);
    final base = _startDate == today ? now.hour * 60 + now.minute : 9 * 60;
    final start = math.min(((base ~/ 30) + (_startDate == today ? 1 : 0)) * 30, 23 * 60);
    final end = start + 30;
    _startTime = TimeOfDay(hour: start ~/ 60, minute: start % 60);
    _endTime = TimeOfDay(hour: end ~/ 60, minute: end % 60);
  }

  /// A `.ics` opened with XatBox: its title, place, text and times (in its
  /// own zone when the calendar knows it).
  void _fillFromInvite(IcsInvite invite) {
    _title.text = invite.title;
    _location.text = invite.location;
    _description.text = invite.description;
    _allDay = invite.allDay;
    final zone = invite.zone;
    if (zone != null && CalendarZones.isKnown(zone)) _timezone = zone;
    final s = invite.start;
    final e = invite.end;
    _startDate = CalendarDate.of(s);
    _startTime = TimeOfDay(hour: s.hour, minute: s.minute);
    // All-day ends are exclusive in iCalendar, inclusive in the form.
    _endDate = invite.allDay ? CalendarDate.of(e).addDays(-1) : CalendarDate.of(e);
    _endTime = TimeOfDay(hour: e.hour, minute: e.minute);
  }

  Future<void> _loadExisting(CalendarOccurrence o) async {
    final repo = ref.read(calendarRepositoryProvider);
    final e = o.event;
    final reminders = await repo.cache.reminders(e.seriesKey);
    CalendarEventDetail? detail;
    if (!e.id.startsWith('local:')) {
      try {
        detail = await repo.detail(e.seriesKey);
      } on AppException {
        detail = null;
      }
    }
    if (!mounted) return;
    final selfId = repo.selfId;
    setState(() {
      if (reminders != null) _reminders = reminders;
      _detail = detail;
      if (detail != null) {
        _participantsKnown = true;
        _recurrence ??= detail.event.recurrence;
        _participants = [
          for (final p in detail.participants)
            if (!p.isOrganizer && p.userId != selfId)
              p.isExternal
                  ? DraftParticipant.external(p.externalEmail ?? p.email)
                  : DraftParticipant.internal(userId: p.userId!, label: p.label, email: p.email),
        ];
      }
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _link.dispose();
    _description.dispose();
    _external.dispose();
    super.dispose();
  }

  tz.Location get _zone => CalendarZones.location(_timezone);

  (DateTime, DateTime) _instants() {
    if (_allDay) return EventTime.encodeAllDay(_startDate, _endDate, _zone);
    return (
      EventTime.atWall(_startDate, _startTime.hour, _startTime.minute, _zone),
      EventTime.atWall(_endDate, _endTime.hour, _endTime.minute, _zone),
    );
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    setState(() => _timeError = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    final (start, end) = _instants();
    if (_allDay ? _endDate.isBefore(_startDate) : !end.isAfter(start)) {
      setState(() => _timeError = l10n.calendarFieldEndBeforeStart);
      return;
    }
    if (_xatboxMeeting && !_allDay && _meetingCode == null && ref.read(callsEnabledProvider)) {
      // The Call Service meeting first: its link goes into the event.
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _saving = true);
      try {
        final meeting = await ref.read(callsApiProvider).createMeeting(
          clientMeetingId: _meetingClientId,
          title: _title.text.trim(),
          startsAt: start,
          endsAt: end,
          inviteeIds: [for (final p in _participants) ?p.userId],
        );
        if (!mounted) return;
        final line = l10n.calendarXatBoxMeetingDescription(meeting.joinUrl);
        final text = _description.text.trimRight();
        _link.text = meeting.joinUrl;
        _description.text = text.isEmpty ? line : '$text\n\n$line';
        _meetingCode = meeting.code;
      } on AppException catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('${l10n.calendarXatBoxMeetingFailed}: ${CalendarFormat.error(l10n, e)}')));
        if (mounted) setState(() => _saving = false);
        return;
      }
    }
    final draft = EventDraft(
      title: _title.text.trim(),
      description: _description.text,
      location: _location.text.trim(),
      meetingLink: _link.text.trim(),
      allDay: _allDay,
      start: start,
      end: end,
      timezone: _timezone,
      recurrence: _recurrence,
      reminders: _reminders,
      participants: _participants,
      eventType: _category,
      visibility: _private ? 'private' : 'default',
      resourceId: _args.isCreate ? _resourceId : null,
    );
    final repo = ref.read(calendarRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final o = _args.occurrence;
      if (o == null) {
        await repo.create(draft);
      } else {
        if (!_singleOccurrence && o.localId == null && !await _confirmRecreate(o, draft)) {
          return;
        }
        await repo.edit(occurrence: o, draft: draft, scope: _args.scope);
        final code = _meetingCode;
        if (code != null &&
            !_allDay &&
            o.event.organizerId == repo.selfId &&
            ref.read(callsEnabledProvider) &&
            (!start.isAtSameMomentAs(o.start) || !end.isAtSameMomentAs(o.end) || draft.title != o.event.title)) {
          // Best effort: the meeting follows the event (join window, reminder).
          unawaited(
            ref.read(callsApiProvider).updateMeeting(code, title: draft.title, startsAt: start, endsAt: end).then<void>(
              (_) {},
              onError: (Object e) => DiagnosticLog.warn('calendar', 'meeting update failed', error: e),
            ),
          );
        }
      }
      if (mounted) (widget.onDone ?? context.pop)();
    } on PlanError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(CalendarFormat.error(l10n, e))));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(CalendarFormat.error(l10n, e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Warn before a change that cancels and re-creates the event.
  Future<bool> _confirmRecreate(CalendarOccurrence o, EventDraft draft) async {
    final stored = _args.scope == EditScope.all && _detail != null ? _detail!.event : o.event;
    final diff = CalendarPlanner.diff(
      occurrence: o,
      stored: stored,
      participants: _detail?.participants ??
          [
            for (final p in draft.participants)
              CalendarParticipant(role: 'required', responseStatus: RsvpStatus.pending, userId: p.userId, externalEmail: p.externalEmail),
          ],
      draft: draft,
      selfId: ref.read(calendarRepositoryProvider).selfId,
    );
    final splitsSeries = _args.scope == EditScope.following;
    if (!diff.structural || splitsSeries || !mounted) return true;
    final l10n = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(l10n.calendarRecreateWarning),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
              FilledButton(
                key: const Key('confirm_recreate'),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.calendarContinue),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _startTime : _endTime,
      // Desktop: typed hours and minutes, not the clock dial.
      initialEntryMode: isDesktop ? TimePickerEntryMode.input : TimePickerEntryMode.dial,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        final before = _startTime.hour * 60 + _startTime.minute;
        final after = picked.hour * 60 + picked.minute;
        final endMinutes = _endTime.hour * 60 + _endTime.minute + (after - before);
        _startTime = picked;
        if (_endDate == _startDate && endMinutes < 24 * 60 && endMinutes > after) {
          _endTime = TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);
        }
      } else {
        _endTime = picked;
      }
    });
  }

  /// A find-time chip: take its instants as the new start and end.
  void _applySuggestion(DateTime start, DateTime end) {
    final s = EventTime.inZone(start, _zone);
    final e = EventTime.inZone(end, _zone);
    setState(() {
      _allDay = false;
      _timeError = null;
      _startDate = CalendarDate.of(s);
      _endDate = CalendarDate.of(e);
      _startTime = TimeOfDay(hour: s.hour, minute: s.minute);
      _endTime = TimeOfDay(hour: e.hour, minute: e.minute);
    });
  }

  Future<void> _pickZone() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _ZonePicker(current: _timezone),
    );
    if (picked != null) setState(() => _timezone = picked);
  }

  Future<void> _pickRepeat() async {
    final result = await showAppSheet<_RepeatResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RepeatSheet(initial: _recurrence, start: _startDate),
    );
    if (result != null) setState(() => _recurrence = result.spec);
  }

  /// ✕ / «Отмена»: closes the desktop dialog, or the phone page.
  void _close() => (widget.onDone ?? () => Navigator.of(context).maybePop())();

  @override
  Widget build(BuildContext context) {
    // One form everywhere, laid out to be understood at a glance: the
    // desktop dialog, or the phone page around it.
    final form = _DesktopEventForm(s: this);
    if (widget.onDone != null) return form;
    return Scaffold(
      backgroundColor: context.tokens.overlaySurface,
      body: SafeArea(child: form),
    );
  }
}

class _ZonePicker extends StatefulWidget {
  const _ZonePicker({required this.current});
  final String current;

  @override
  State<_ZonePicker> createState() => _ZonePickerState();
}

class _ZonePickerState extends State<_ZonePicker> {
  String _q = '';
  late final List<String> _all = () {
    CalendarZones.ensureInitialized();
    return tz.timeZoneDatabase.locations.keys.where((k) => k.contains('/') || k == 'UTC').toList()..sort();
  }();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = _all.where((z) => z.toLowerCase().contains(_q.toLowerCase())).toList();
    return AlertDialog(
      title: Text(l10n.calendarFieldTimezone),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(prefixIcon: Icon(LucideIcons.search)),
              onChanged: (v) => setState(() => _q = v),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, i) => ListTile(
                  dense: true,
                  selected: items[i] == widget.current,
                  title: Text(CalendarFormat.zoneLabel(items[i])),
                  onTap: () => Navigator.pop(context, items[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepeatResult {
  const _RepeatResult(this.spec);
  final RecurrenceSpec? spec;
}

enum _EndKind { never, until, count }

class _RepeatSheet extends StatefulWidget {
  const _RepeatSheet({required this.initial, required this.start});
  final RecurrenceSpec? initial;
  final CalendarDate start;

  @override
  State<_RepeatSheet> createState() => _RepeatSheetState();
}

class _RepeatSheetState extends State<_RepeatSheet> {
  RepeatFrequency? _freq;
  int _interval = 1;
  _EndKind _end = _EndKind.never;
  late CalendarDate _until;
  int _count = 10;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _freq = s?.frequency;
    _interval = s?.interval ?? 1;
    _until = s?.until != null ? CalendarDate.of(s!.until!) : widget.start.addMonths(3);
    if (s?.count != null) {
      _end = _EndKind.count;
      _count = s!.count!;
    } else if (s?.until != null) {
      _end = _EndKind.until;
    }
  }

  RecurrenceSpec? get _spec {
    final f = _freq;
    if (f == null) return null;
    return RecurrenceSpec(
      frequency: f,
      interval: _interval,
      // End of the chosen day, UTC (inclusive).
      until: _end == _EndKind.until ? DateTime.utc(_until.year, _until.month, _until.day, 23, 59, 59) : null,
      count: _end == _EndKind.count ? _count : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final labels = {
      null: l10n.calendarRepeatNone,
      RepeatFrequency.daily: l10n.calendarRepeatDaily,
      RepeatFrequency.weekly: l10n.calendarRepeatWeekly,
      RepeatFrequency.monthly: l10n.calendarRepeatMonthly,
      RepeatFrequency.yearly: l10n.calendarRepeatYearly,
    };
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.calendarFieldRepeat, style: Theme.of(context).textTheme.titleMedium),
            RadioGroup<RepeatFrequency?>(
              groupValue: _freq,
              onChanged: (v) => setState(() => _freq = v),
              child: Column(
                children: [
                  for (final e in labels.entries)
                    RadioListTile<RepeatFrequency?>(
                      key: Key('repeat_${e.key?.name ?? 'none'}'),
                      contentPadding: EdgeInsets.zero,
                      value: e.key,
                      title: Text(e.value),
                    ),
                ],
              ),
            ),
            if (_freq != null) ...[
              Row(
                children: [
                  Expanded(child: Text(l10n.calendarRepeatInterval)),
                  IconButton(tooltip: l10n.a11yDecrease, onPressed: _interval > 1 ? () => setState(() => _interval--) : null, icon: const Icon(LucideIcons.minus)),
                  Text('$_interval'),
                  IconButton(tooltip: l10n.a11yIncrease, onPressed: _interval < 99 ? () => setState(() => _interval++) : null, icon: const Icon(LucideIcons.plus)),
                ],
              ),
              Text(CalendarFormat.recurrence(l10n, context, _spec), style: TextStyle(color: tokens.textMuted)),
              const Divider(),
              Text(l10n.calendarRepeatEnds, style: Theme.of(context).textTheme.titleSmall),
              RadioGroup<_EndKind>(
                groupValue: _end,
                onChanged: (v) => setState(() => _end = v ?? _EndKind.never),
                child: Column(
                  children: [
                    RadioListTile<_EndKind>(contentPadding: EdgeInsets.zero, value: _EndKind.never, title: Text(l10n.calendarRepeatEndsNever)),
                    RadioListTile<_EndKind>(
                      key: const Key('repeat_end_until'),
                      contentPadding: EdgeInsets.zero,
                      value: _EndKind.until,
                      title: Text(l10n.calendarRepeatEndsOn),
                      secondary: _end == _EndKind.until
                          ? TextButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _until.forFormatting,
                                  firstDate: widget.start.forFormatting,
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) setState(() => _until = CalendarDate.of(picked));
                              },
                              child: Text(CalendarFormat.shortDate(context, _until)),
                            )
                          : null,
                    ),
                    RadioListTile<_EndKind>(
                      key: const Key('repeat_end_count'),
                      contentPadding: EdgeInsets.zero,
                      value: _EndKind.count,
                      title: Text(l10n.calendarRepeatEndsAfter),
                      secondary: _end == _EndKind.count
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(tooltip: l10n.a11yDecrease, onPressed: _count > 1 ? () => setState(() => _count--) : null, icon: const Icon(LucideIcons.minus)),
                                Text('$_count'),
                                IconButton(tooltip: l10n.a11yIncrease, onPressed: _count < 500 ? () => setState(() => _count++) : null, icon: const Icon(LucideIcons.plus)),
                              ],
                            )
                          : null,
                    ),
                  ],
                ),
              ),
              if (_end != _EndKind.never)
                Text(l10n.calendarRepeatServerNote, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.textMuted)),
            ],
            const SizedBox(height: Space.md),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('repeat_done'),
                onPressed: () => Navigator.pop(context, _RepeatResult(_spec)),
                child: Text(l10n.calendarDone),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Colleague picker: the same directory as creating a group chat
/// (Chat Service `GET /users`), no second address book.
class _ParticipantPicker extends ConsumerStatefulWidget {
  const _ParticipantPicker({required this.exclude});
  final Set<String> exclude;

  @override
  ConsumerState<_ParticipantPicker> createState() => _ParticipantPickerState();
}

class _ParticipantPickerState extends ConsumerState<_ParticipantPicker> {
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selfId = ref.read(calendarRepositoryProvider).selfId;
    final results = ref.watch(chatUserSearchProvider(_query));
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(Space.md),
              child: TextField(
                key: const Key('participant_search'),
                autofocus: true,
                decoration: InputDecoration(hintText: l10n.calendarSearchColleagues, prefixIcon: const Icon(LucideIcons.search)),
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), () {
                    if (mounted) setState(() => _query = v.trim());
                  });
                },
              ),
            ),
            Expanded(
              child: results.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(CalendarFormat.error(l10n, e))),
                data: (users) {
                  final visible = users.where((u) => u.userId != selfId && !widget.exclude.contains(u.userId)).toList();
                  if (visible.isEmpty) return Center(child: Text(l10n.chatNoUsers));
                  return ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (_, i) {
                      final u = visible[i];
                      return ListTile(
                        key: ValueKey('pick_${u.userId}'),
                        title: Text(u.label),
                        subtitle: Text(u.email),
                        onTap: () => Navigator.pop(
                          context,
                          DraftParticipant.internal(userId: u.userId, label: u.label, email: u.email),
                        ),
                      );
                    },
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
