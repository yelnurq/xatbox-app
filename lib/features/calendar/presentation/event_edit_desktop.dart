part of 'event_edit_screen.dart';

/// Desktop: the new / edit event dialog, laid out to be understood at a
/// glance — a big title, one line «when» with time menus and duration
/// chips, people found as you type, then place, reminder and text. The
/// rarely used settings (link, room, find a time, privacy) wait under
/// «Ещё». The state, checks and saving are [_EventEditScreenState]'s.
class _DesktopEventForm extends ConsumerStatefulWidget {
  const _DesktopEventForm({required this.s});

  final _EventEditScreenState s;

  @override
  ConsumerState<_DesktopEventForm> createState() => _DesktopEventFormState();
}

class _DesktopEventFormState extends ConsumerState<_DesktopEventForm> {
  bool _more = false;

  _EventEditScreenState get s => widget.s;

  @override
  void initState() {
    super.initState();
    final s = widget.s;
    _more = s._link.text.trim().isNotEmpty || s._timezone != ref.read(deviceZoneProvider);
  }

  int get _startMinutes => s._startTime.hour * 60 + s._startTime.minute;
  int get _endMinutes => s._endTime.hour * 60 + s._endTime.minute;
  bool get _sameDay => s._endDate == s._startDate;

  /// Minutes between start and end (both on the form's wall clock).
  int get _duration => s._startDate.daysUntil(s._endDate) * 24 * 60 + _endMinutes - _startMinutes;

  void _setDuration(int minutes) {
    final end = _startMinutes + minutes;
    s._set(() {
      s._timeError = null;
      s._endDate = s._startDate.addDays(end ~/ (24 * 60));
      final m = end % (24 * 60);
      s._endTime = TimeOfDay(hour: m ~/ 60, minute: m % 60);
    });
  }

  void _setStart(TimeOfDay t) {
    final keep = _duration > 0 ? _duration : 30;
    s._set(() {
      s._timeError = null;
      s._startTime = t;
    });
    _setDuration(keep);
  }

  void _setEnd(TimeOfDay t) => s._set(() {
    s._timeError = null;
    s._endTime = t;
  });

  void _setStartDate(CalendarDate d) {
    final shift = s._startDate.daysUntil(d);
    s._set(() {
      s._startDate = d;
      s._endDate = s._endDate.addDays(shift);
    });
  }

  void _setEndDate(CalendarDate d) => s._set(() {
    s._timeError = null;
    s._endDate = d.isBefore(s._startDate) ? s._startDate : d;
  });

  String _durationLabel(AppLocalizations l10n, int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return l10n.desktopEventDurationMinutes(m);
    if (m == 0) return l10n.desktopEventDurationHours(h);
    return l10n.desktopEventDurationHoursMinutes(h, m);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final isCreate = s._args.isCreate;
    final single = s._singleOccurrence;
    final calls = ref.watch(callsEnabledProvider);

    return CallbackShortcuts(
      bindings: {
        commandShortcut(LogicalKeyboardKey.enter): () {
          if (!s._saving) unawaited(s._save());
        },
      },
      child: Material(
        color: t.overlaySurface,
        child: Form(
          key: s._form,
          child: Column(
            // Dialog: as tall as its content; phone page: the whole screen,
            // the buttons at the bottom.
            mainAxisSize: isDesktop ? MainAxisSize.min : MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context, isCreate),
              Divider(height: 1, color: t.divider),
              Flexible(
                fit: isDesktop ? FlexFit.loose : FlexFit.tight,
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.lg),
                  children: [
                    _Row(icon: LucideIcons.clock, child: _when(context, single)),
                    if (!single)
                      _Row(
                        icon: LucideIcons.users,
                        child: _DesktopPeopleField(
                          participants: s._participants,
                          known: s._participantsKnown,
                          onAdd: (p) => s._set(() => s._participants = [...s._participants, p]),
                          onRemove: (p) => s._set(() => s._participants = [...s._participants]..remove(p)),
                        ),
                      ),
                    if (calls) _Row(icon: LucideIcons.video, child: _meeting(context, single)),
                    _Row(
                      icon: LucideIcons.mapPin,
                      child: _Field(controller: s._location, hint: l10n.desktopEventLocationHint, fieldKey: const Key('event_location')),
                    ),
                    _Row(icon: LucideIcons.bell, child: _reminders(context)),
                    _Row(
                      icon: LucideIcons.alignLeft,
                      alignTop: true,
                      child: _Field(
                        controller: s._description,
                        hint: l10n.desktopEventDescriptionHint,
                        fieldKey: const Key('event_description'),
                        minLines: 3,
                        maxLines: 10,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    _moreToggle(context),
                    if (_more) ..._moreSection(context, isCreate, single),
                  ],
                ),
              ),
              Divider(height: 1, color: t.divider),
              _footer(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, bool isCreate) {
    final l10n = context.l10n;
    final t = context.tokens;
    final meeting = s._participants.isNotEmpty ? 'meeting' : s._category;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.sm, Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('event_title'),
                  controller: s._title,
                  autofocus: isCreate,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(fontFamily: t.fontDisplay, fontSize: 22, fontWeight: FontWeight.w600, color: t.textPrimary),
                  decoration: InputDecoration(
                    hintText: l10n.desktopEventTitleHint,
                    hintStyle: TextStyle(fontFamily: t.fontDisplay, fontSize: 22, fontWeight: FontWeight.w500, color: t.textTertiary),
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.primary, width: 2)),
                    errorBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.danger)),
                    focusedErrorBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.danger, width: 2)),
                  ),
                  validator: (v) {
                    final text = (v ?? '').trim();
                    if (text.isEmpty) return l10n.calendarFieldTitleRequired;
                    if (utf8.encode(text).length > 300) return l10n.calendarFieldTitleTooLong;
                    return null;
                  },
                ),
              ),
              const SizedBox(width: Space.sm),
              IconButton(
                key: const Key('event_edit_close'),
                tooltip: l10n.close,
                icon: const Icon(LucideIcons.x),
                onPressed: s._close,
              ),
            ],
          ),
          if (isCreate) ...[
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              children: [
                _Pill(
                  key: const Key('event_category_personal'),
                  icon: LucideIcons.user,
                  label: l10n.calendarCategoryPersonal,
                  selected: meeting == 'personal',
                  onTap: s._participants.isEmpty ? () => s._set(() => s._category = 'personal') : null,
                ),
                _Pill(
                  key: const Key('event_category_meeting'),
                  icon: LucideIcons.users,
                  label: l10n.calendarCategoryMeeting,
                  selected: meeting == 'meeting',
                  onTap: s._participants.isEmpty ? () => s._set(() => s._category = 'meeting') : null,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _when(BuildContext context, bool single) {
    final l10n = context.l10n;
    final t = context.tokens;
    final allDay = s._allDay;
    final multiDay = !_sameDay;
    const presets = [15, 30, 45, 60, 90, 120];
    final duration = _duration;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _DateMenu(
              key: const Key('event_start_date'),
              date: s._startDate,
              onPicked: _setStartDate,
            ),
            if (!allDay) ...[
              _TimeMenu(
                key: const Key('event_start_time'),
                value: s._startTime,
                options: [for (var m = 0; m < 24 * 60; m += 15) TimeOfDay(hour: m ~/ 60, minute: m % 60)],
                onPicked: _setStart,
                onOther: () => unawaited(s._pickTime(true)),
              ),
              Text('–', style: TextStyle(color: t.textTertiary, fontSize: 16)),
              _TimeMenu(
                key: const Key('event_end_time'),
                value: s._endTime,
                options: [
                  for (var m = multiDay ? 0 : _startMinutes + 15; m < 24 * 60; m += 15) TimeOfDay(hour: m ~/ 60, minute: m % 60),
                  if (!multiDay) const TimeOfDay(hour: 23, minute: 59),
                ],
                describe: multiDay ? null : (o) => _durationLabel(l10n, o.hour * 60 + o.minute - _startMinutes),
                onPicked: _setEnd,
                onOther: () => unawaited(s._pickTime(false)),
              ),
            ],
            if (allDay || multiDay) ...[
              if (allDay) Text('–', style: TextStyle(color: t.textTertiary, fontSize: 16)),
              _DateMenu(
                key: const Key('event_end_date'),
                date: s._endDate,
                first: s._startDate,
                onPicked: _setEndDate,
              ),
            ],
          ],
        ),
        if (!allDay) ...[
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in presets)
                _Pill(
                  key: Key('event_duration_$m'),
                  label: _durationLabel(l10n, m),
                  selected: duration == m,
                  dense: true,
                  onTap: () => _setDuration(m),
                ),
            ],
          ),
        ],
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Pill(
              key: const Key('event_all_day'),
              icon: allDay ? LucideIcons.squareCheck : LucideIcons.square,
              label: l10n.calendarAllDay,
              selected: allDay,
              dense: true,
              onTap: single ? null : () => s._set(() => s._allDay = !s._allDay),
            ),
            _RepeatMenu(
              spec: s._recurrence,
              enabled: !single,
              onPicked: (spec) => s._set(() => s._recurrence = spec),
              onCustom: () => unawaited(s._pickRepeat()),
            ),
          ],
        ),
        if (s._timeError != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: Text(s._timeError!, key: const Key('event_time_error'), style: TextStyle(color: t.danger)),
          ),
      ],
    );
  }

  Widget _meeting(BuildContext context, bool single) {
    final l10n = context.l10n;
    final t = context.tokens;
    if (s._meetingCode != null) {
      return Text(
        l10n.calendarXatBoxMeetingAdded,
        key: const Key('event_xatbox_meeting_added'),
        style: TextStyle(color: t.primary, fontWeight: FontWeight.w600),
      );
    }
    final on = s._xatboxMeeting && !s._allDay;
    return InkWell(
      key: const Key('event_xatbox_meeting'),
      borderRadius: BorderRadius.circular(t.radiusMd),
      onTap: s._allDay || single ? null : () => s._set(() => s._xatboxMeeting = !s._xatboxMeeting),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.smd, vertical: Space.sm),
        decoration: BoxDecoration(
          color: on ? t.primarySoft : t.surfaceSubtle,
          borderRadius: BorderRadius.circular(t.radiusMd),
          border: Border.all(color: on ? t.primary.withValues(alpha: 0.6) : t.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.calendarXatBoxMeeting, style: TextStyle(fontWeight: FontWeight.w600, color: t.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    s._allDay ? l10n.calendarXatBoxMeetingAllDay : l10n.calendarXatBoxMeetingHint,
                    style: TextStyle(fontSize: 12, color: t.textTertiary),
                  ),
                ],
              ),
            ),
            Switch(
              value: on,
              onChanged: s._allDay || single ? null : (v) => s._set(() => s._xatboxMeeting = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reminders(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final left = reminderPresets.where((p) => !s._reminders.contains(p)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final m in s._reminders)
              _Pill(
                label: CalendarFormat.reminder(l10n, m),
                selected: true,
                dense: true,
                onDelete: () => s._set(() => s._reminders = [...s._reminders]..remove(m)),
              ),
            if (s._reminders.isEmpty)
              Text(l10n.desktopEventNoReminders, style: TextStyle(color: t.textTertiary)),
            if (left.isNotEmpty)
              MenuAnchor(
                menuChildren: [
                  for (final p in left)
                    MenuItemButton(
                      onPressed: () => s._set(() => s._reminders = [...s._reminders, p]..sort()),
                      child: Text(CalendarFormat.reminder(l10n, p)),
                    ),
                ],
                builder: (context, controller, _) => _Pill(
                  key: const Key('event_add_reminder'),
                  icon: LucideIcons.plus,
                  label: l10n.desktopEventReminder,
                  dense: true,
                  onTap: () => controller.isOpen ? controller.close() : controller.open(),
                ),
              ),
          ],
        ),
        if (s._reminders.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l10n.calendarReminderLocalNote, style: TextStyle(fontSize: 12, color: t.textTertiary)),
          ),
      ],
    );
  }

  Widget _moreToggle(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const Key('event_more'),
        onPressed: () => setState(() => _more = !_more),
        icon: Icon(_more ? LucideIcons.chevronUp : LucideIcons.slidersHorizontal, size: 16, color: t.textSecondary),
        label: Text(_more ? l10n.desktopEventLess : l10n.desktopEventMore, style: TextStyle(color: t.textSecondary)),
      ),
    );
  }

  List<Widget> _moreSection(BuildContext context, bool isCreate, bool single) {
    final l10n = context.l10n;
    final t = context.tokens;
    final (start, end) = s._instants();
    return [
      const SizedBox(height: Space.sm),
      _Row(
        icon: LucideIcons.link,
        child: _Field(
          controller: s._link,
          hint: l10n.calendarFieldLink,
          fieldKey: const Key('event_link'),
          keyboardType: TextInputType.url,
          validator: (v) {
            final text = (v ?? '').trim();
            if (text.isEmpty) return null;
            final uri = Uri.tryParse(text);
            return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty ? null : l10n.calendarFieldLinkInvalid;
          },
        ),
      ),
      _Row(
        icon: LucideIcons.globe,
        child: Align(
          alignment: Alignment.centerLeft,
          child: _Pill(
            key: const Key('event_timezone'),
            label: '${l10n.calendarFieldTimezone}: ${CalendarFormat.zoneLabel(s._timezone)}',
            dense: true,
            onTap: single ? null : () => unawaited(s._pickZone()),
          ),
        ),
      ),
      if (isCreate)
        _Row(
          icon: LucideIcons.lock,
          child: Row(
            children: [
              Expanded(child: Text(l10n.calendarFieldPrivate, style: TextStyle(color: t.textPrimary))),
              Switch(
                key: const Key('event_private'),
                value: s._private,
                onChanged: (v) => s._set(() => s._private = v),
              ),
            ],
          ),
        ),
      _Row(
        icon: LucideIcons.calendarSearch,
        alignTop: true,
        child: EventSchedulingSection(
          participants: s._participants,
          date: s._startDate,
          zone: s._zone,
          start: start,
          end: end,
          allDay: s._allDay,
          resourceId: isCreate ? s._resourceId : null,
          allowRoomChange: isCreate,
          onRoomChanged: (room) => s._set(() => s._resourceId = room?.id),
          onSuggestion: s._applySuggestion,
        ),
      ),
    ];
  }

  Widget _footer(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.smd),
      child: Row(
        children: [
          Expanded(
            // Phone: no keyboard shortcut to tell about.
            child: isDesktop
                ? Text(
                    l10n.desktopEventSaveHint('$commandKeyLabel+Enter'),
                    style: TextStyle(fontSize: 12, color: t.textTertiary),
                  )
                : const SizedBox.shrink(),
          ),
          TextButton(onPressed: s._close, child: Text(l10n.cancel)),
          const SizedBox(width: Space.sm),
          FilledButton(
            key: const Key('event_save'),
            style: FilledButton.styleFrom(minimumSize: const Size(120, 40)),
            onPressed: s._saving ? null : s._save,
            child: s._saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.calendarSave),
          ),
        ],
      ),
    );
  }
}

/// A form line: a muted icon in a fixed column, the control beside it.
class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.child, this.alignTop = false});

  final IconData icon;
  final Widget child;
  final bool alignTop;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Padding(
              padding: EdgeInsets.only(top: alignTop ? 12 : 9),
              child: Icon(icon, size: 18, color: t.textTertiary),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// A soft filled field without a heavy outline (place, text, link).
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.fieldKey,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final Key fieldKey;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(t.radiusMd),
      borderSide: BorderSide(color: c, width: w),
    );
    return TextFormField(
      key: fieldKey,
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType ?? (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: t.surfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.smd, vertical: 11),
        border: border(Colors.transparent),
        enabledBorder: border(Colors.transparent),
        focusedBorder: border(t.focus, 2),
      ),
    );
  }
}

/// A rounded chip-button: toggles, presets, menus. [onDelete] adds an ✕.
class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.dense = false,
    this.onTap,
    this.onDelete,
    this.trailing,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final bool dense;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final disabled = onTap == null && onDelete == null;
    final fg = disabled ? t.textDisabled : (selected ? t.primary : t.textSecondary);
    final radius = BorderRadius.circular(999);
    return Material(
      color: selected ? t.primarySoft : t.surfaceSubtle,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: selected ? t.primary.withValues(alpha: 0.55) : t.border),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 14, vertical: dense ? 5 : 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 15, color: fg), const SizedBox(width: 6)],
              Text(
                label,
                style: TextStyle(
                  fontFamily: t.fontDisplay,
                  fontSize: dense ? 12.5 : 13.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? t.textPrimary : (disabled ? t.textDisabled : t.textSecondary),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 4), Icon(trailing, size: 14, color: fg)],
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: radius,
                  onTap: onDelete,
                  child: Icon(LucideIcons.x, size: 14, color: t.textTertiary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A big date button («Ср, 16 сентября») opening a month picker under it.
class _DateMenu extends StatelessWidget {
  const _DateMenu({super.key, required this.date, required this.onPicked, this.first});

  final CalendarDate date;
  final CalendarDate? first;
  final ValueChanged<CalendarDate> onPicked;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final text = DateFormat('EEE, d MMMM', locale).format(date.forFormatting);
    final label = text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
    return MenuAnchor(
      menuChildren: [
        SizedBox(
          width: 320,
          height: 340,
          child: Builder(
            builder: (menu) => CalendarDatePicker(
              initialDate: date.forFormatting,
              firstDate: first?.forFormatting ?? DateTime(2000),
              lastDate: DateTime(2100),
              onDateChanged: (d) {
                MenuController.maybeOf(menu)?.close();
                onPicked(CalendarDate.of(d));
              },
            ),
          ),
        ),
      ],
      builder: (context, controller, _) => _BigButton(
        icon: LucideIcons.calendarDays,
        label: label,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        accent: t.primary,
      ),
    );
  }
}

/// A time button with a scrolling list of quarter hours (the end list says
/// how long the event lasts) and «Другое время…» for any minute.
class _TimeMenu extends StatelessWidget {
  const _TimeMenu({
    super.key,
    required this.value,
    required this.options,
    required this.onPicked,
    required this.onOther,
    this.describe,
  });

  final TimeOfDay value;
  final List<TimeOfDay> options;
  final ValueChanged<TimeOfDay> onPicked;
  final VoidCallback onOther;
  final String Function(TimeOfDay)? describe;

  static const _rowHeight = 36.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    String fmt(TimeOfDay v) => MaterialLocalizations.of(context).formatTimeOfDay(v, alwaysUse24HourFormat: true);
    final minutes = value.hour * 60 + value.minute;
    final index = options.indexWhere((o) => o.hour * 60 + o.minute >= minutes);
    return MenuAnchor(
      menuChildren: [
        SizedBox(
          width: describe == null ? 140 : 200,
          height: 288,
          child: Builder(
            builder: (menu) => ListView.builder(
              controller: ScrollController(initialScrollOffset: math.max(0, (index < 0 ? 0 : index) - 3) * _rowHeight),
              itemExtent: _rowHeight,
              itemCount: options.length + 1,
              itemBuilder: (_, i) {
                if (i == options.length) {
                  return MenuItemButton(
                    onPressed: () {
                      MenuController.maybeOf(menu)?.close();
                      onOther();
                    },
                    child: Text(l10n.desktopEventOtherTime, style: TextStyle(color: t.textTertiary)),
                  );
                }
                final o = options[i];
                final on = o.hour == value.hour && o.minute == value.minute;
                return MenuItemButton(
                  style: on ? MenuItemButton.styleFrom(backgroundColor: t.primarySoft) : null,
                  onPressed: () => onPicked(o),
                  child: Text.rich(
                    TextSpan(
                      text: fmt(o),
                      style: TextStyle(fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: t.textPrimary),
                      children: [
                        if (describe != null)
                          TextSpan(text: '  (${describe!(o)})', style: TextStyle(fontWeight: FontWeight.w400, color: t.textTertiary)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
      builder: (context, controller, _) => _BigButton(
        label: fmt(value),
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// «Не повторять ▾»: the common rules in one click, «Настроить…» for the rest.
class _RepeatMenu extends StatelessWidget {
  const _RepeatMenu({required this.spec, required this.enabled, required this.onPicked, required this.onCustom});

  final RecurrenceSpec? spec;
  final bool enabled;
  final ValueChanged<RecurrenceSpec?> onPicked;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = <(String, RecurrenceSpec?)>[
      (l10n.calendarRepeatNone, null),
      (l10n.calendarRepeatDaily, const RecurrenceSpec(frequency: RepeatFrequency.daily)),
      (l10n.calendarRepeatWeekly, const RecurrenceSpec(frequency: RepeatFrequency.weekly)),
      (l10n.calendarRepeatMonthly, const RecurrenceSpec(frequency: RepeatFrequency.monthly)),
      (l10n.calendarRepeatYearly, const RecurrenceSpec(frequency: RepeatFrequency.yearly)),
    ];
    return MenuAnchor(
      menuChildren: [
        for (final (label, value) in options)
          MenuItemButton(
            key: Key('repeat_quick_${value?.frequency.name ?? 'none'}'),
            onPressed: () => onPicked(value),
            child: Text(label),
          ),
        const Divider(height: 8),
        MenuItemButton(key: const Key('repeat_custom'), onPressed: onCustom, child: Text(l10n.desktopEventRepeatCustom)),
      ],
      builder: (context, controller, _) => _Pill(
        key: const Key('event_repeat'),
        icon: LucideIcons.repeat,
        label: CalendarFormat.recurrence(l10n, context, spec),
        selected: spec != null,
        dense: true,
        trailing: LucideIcons.chevronDown,
        onTap: enabled ? () => controller.isOpen ? controller.close() : controller.open() : null,
      ),
    );
  }
}

/// The large tappable value of the «when» line (date, times).
class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.onTap, this.icon, this.accent});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(t.radiusMd);
    return Material(
      color: t.surfaceSubtle,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: t.border)),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.smd, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: accent ?? t.textSecondary), const SizedBox(width: Space.sm)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: t.fontDisplay, fontSize: 15, fontWeight: FontWeight.w600, color: t.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Participants: chips with avatars, and one field that finds colleagues as
/// you type and takes a typed email as an outside guest (Enter).
class _DesktopPeopleField extends ConsumerStatefulWidget {
  const _DesktopPeopleField({required this.participants, required this.known, required this.onAdd, required this.onRemove});

  final List<DraftParticipant> participants;
  final bool known;
  final ValueChanged<DraftParticipant> onAdd;
  final ValueChanged<DraftParticipant> onRemove;

  @override
  ConsumerState<_DesktopPeopleField> createState() => _DesktopPeopleFieldState();
}

class _DesktopPeopleFieldState extends ConsumerState<_DesktopPeopleField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<Iterable<DraftParticipant>> _options(TextEditingValue value) async {
    final q = value.text.trim();
    if (q.length < 2) return const [];
    final taken = {for (final p in widget.participants) p.key};
    final results = <DraftParticipant>[];
    if (ref.read(chatEnabledProvider)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted || _controller.text.trim() != q) return const [];
      try {
        final selfId = ref.read(calendarRepositoryProvider).selfId;
        final users = await ref.read(chatUserSearchProvider(q).future);
        for (final u in users) {
          if (u.userId == selfId || taken.contains(u.userId)) continue;
          results.add(DraftParticipant.internal(userId: u.userId, label: u.label, email: u.email));
          if (results.length >= 8) break;
        }
      } on Object catch (e) {
        DiagnosticLog.warn('calendar', 'people search failed', error: e);
      }
    }
    final lower = q.toLowerCase();
    if (_email.hasMatch(lower) && !taken.contains('ext:$lower') && !results.any((r) => r.email.toLowerCase() == lower)) {
      results.add(DraftParticipant.external(lower));
    }
    return results;
  }

  void _submit() {
    final v = _controller.text.trim().toLowerCase();
    if (!_email.hasMatch(v)) return;
    if (!widget.participants.any((p) => p.key == 'ext:$v' || p.email.toLowerCase() == v)) {
      widget.onAdd(DraftParticipant.external(v));
    }
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    if (!widget.known) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(l10n.calendarParticipantsOffline, style: TextStyle(color: t.textTertiary)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RawAutocomplete<DraftParticipant>(
          textEditingController: _controller,
          focusNode: _focus,
          displayStringForOption: (p) => p.label,
          optionsBuilder: _options,
          onSelected: (p) {
            widget.onAdd(p);
            _controller.clear();
            _focus.requestFocus();
          },
          fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
            key: const Key('event_participant_search'),
            controller: controller,
            focusNode: focus,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: l10n.desktopEventParticipantsHint,
              filled: true,
              fillColor: t.surfaceSubtle,
              prefixIcon: Icon(LucideIcons.userPlus, size: 16, color: t.textTertiary),
              contentPadding: const EdgeInsets.symmetric(horizontal: Space.smd, vertical: 11),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(t.radiusMd), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(t.radiusMd), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.radiusMd),
                borderSide: BorderSide(color: t.focus, width: 2),
              ),
            ),
          ),
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: t.overlaySurface,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(t.radiusMd),
                side: BorderSide(color: t.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460, maxHeight: 320),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shrinkWrap: true,
                  children: [
                    for (final p in options)
                      InkWell(
                        key: ValueKey('pick_${p.key}'),
                        onTap: () => onSelected(p),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Space.smd, vertical: Space.sm),
                          child: Row(
                            children: [
                              p.userId == null
                                  ? CircleAvatar(
                                      radius: 16,
                                      backgroundColor: t.warningSoft,
                                      child: Icon(LucideIcons.atSign, size: 16, color: t.warning),
                                    )
                                  : InitialsAvatar(label: p.label, colorKey: p.email, radius: 16),
                              const SizedBox(width: Space.smd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.userId == null ? l10n.desktopEventInviteEmail(p.email) : p.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontWeight: FontWeight.w600, color: t.textPrimary),
                                    ),
                                    if (p.userId != null && p.email.isNotEmpty)
                                      Text(
                                        p.email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, color: t.textTertiary),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(LucideIcons.plus, size: 16, color: t.textTertiary),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.participants.isNotEmpty) ...[
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in widget.participants)
                Container(
                  key: ValueKey('draft_participant_${p.key}'),
                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                  decoration: BoxDecoration(
                    color: p.userId == null ? t.warningSoft : t.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: t.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      p.userId == null
                          ? Icon(LucideIcons.atSign, size: 16, color: t.warning)
                          : InitialsAvatar(label: p.label, colorKey: p.email, radius: 11),
                      const SizedBox(width: 6),
                      Text(p.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: t.textPrimary)),
                      const SizedBox(width: 4),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => widget.onRemove(p),
                        child: Icon(LucideIcons.x, size: 14, color: t.textTertiary),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
