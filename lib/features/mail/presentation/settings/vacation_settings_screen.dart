import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/utils/diagnostic_log.dart';
import '../../../../shared/utils/error_text.dart';
import '../../../../shared/widgets/state_view.dart';
import '../../../calendar/domain/calendar_time.dart';
import '../../data/mail_settings_models.dart';
import '../mail_error_text.dart';
import '../mail_providers.dart';
import 'mail_settings_widgets.dart';

/// Client-side checks in the server's order (unit-testable).
enum VacationProblem { subjectTooLong, bodyTooLong, bodyRequired, dates, zone }

VacationProblem? validateVacation(MailVacationUpdate u) {
  if (u.subject.trim().runes.length > MailVacationUpdate.maxSubjectChars) {
    return VacationProblem.subjectTooLong;
  }
  final body = u.body.trim();
  if (body.runes.length > MailVacationUpdate.maxBodyChars) {
    return VacationProblem.bodyTooLong;
  }
  if (u.enabled && body.isEmpty) return VacationProblem.bodyRequired;
  final dateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  for (final d in [u.startsOn, u.endsOn]) {
    if (d.isNotEmpty && !dateRe.hasMatch(d)) return VacationProblem.dates;
  }
  if (u.startsOn.isNotEmpty &&
      u.endsOn.isNotEmpty &&
      u.endsOn.compareTo(u.startsOn) < 0) {
    return VacationProblem.dates;
  }
  final zone = u.timeZone.trim();
  if (zone.isNotEmpty && !CalendarZones.isKnown(zone)) {
    return VacationProblem.zone;
  }
  return null;
}

/// `GET/PUT /mail/vacation`.
class VacationSettingsScreen extends ConsumerStatefulWidget {
  const VacationSettingsScreen({super.key});

  @override
  ConsumerState<VacationSettingsScreen> createState() =>
      _VacationSettingsScreenState();
}

class _VacationSettingsScreenState
    extends ConsumerState<VacationSettingsScreen> {
  final _subject = TextEditingController();
  final _body = TextEditingController();
  final _zone = TextEditingController();
  MailVacation? _vacation;
  bool _enabled = false;
  String _startsOn = '';
  String _endsOn = '';
  Object? _loadError;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    _zone.dispose();
    super.dispose();
  }

  void _apply(MailVacation v) {
    _vacation = v;
    _enabled = v.enabled;
    _subject.text = v.subject;
    _body.text = v.body;
    _startsOn = v.startsOn;
    _endsOn = v.endsOn;
    _zone.text = v.timeZone;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final v = await ref.read(mailApiProvider).vacation();
      if (!mounted) return;
      setState(() {
        _apply(v);
        _loading = false;
      });
    } on AppException catch (e) {
      DiagnosticLog.warn('mail', 'vacation load failed', error: e);
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  String _problemText(AppLocalizations l10n, VacationProblem p) =>
      switch (p) {
        VacationProblem.subjectTooLong => l10n.mailVacationSubjectTooLong,
        VacationProblem.bodyTooLong => l10n.mailVacationBodyTooLong,
        VacationProblem.bodyRequired => l10n.mailVacationBodyRequired,
        VacationProblem.dates => l10n.mailVacationDatesInvalid,
        VacationProblem.zone => l10n.mailVacationTimeZoneInvalid,
      };

  Future<void> _save() async {
    if (_saving) return;
    final l10n = context.l10n;
    final update = MailVacationUpdate(
      enabled: _enabled,
      subject: _subject.text,
      body: _body.text,
      startsOn: _startsOn,
      endsOn: _endsOn,
      timeZone: _zone.text.trim().isEmpty
          ? MailVacation.defaultTimeZone
          : _zone.text.trim(),
    );
    final problem = validateVacation(update);
    if (problem != null) {
      setState(() => _error = _problemText(l10n, problem));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await ref.read(mailApiProvider).updateVacation(update);
      if (!mounted) return;
      setState(() => _apply(saved));
      messenger.showSnackBar(SnackBar(content: Text(l10n.mailSettingsSaved)));
    } on AppException catch (e) {
      DiagnosticLog.warn('mail', 'vacation save failed', error: e);
      if (!mounted) return;
      setState(() => _error = MailErrorText.describe(l10n, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final current = start ? _startsOn : _endsOn;
    final initial = _parse(current)?.forFormatting ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final key = CalendarDate.of(picked).key;
      if (start) {
        _startsOn = key;
      } else {
        _endsOn = key;
      }
    });
  }

  static CalendarDate? _parse(String key) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) return null;
    return CalendarDate.parse(key);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final v = _vacation;
    final locale = Localizations.localeOf(context).toString();
    final muted = theme.textTheme.bodySmall?.copyWith(color: tokens.textMuted);

    String dateLabel(String key) {
      final d = _parse(key);
      return d == null
          ? l10n.mailVacationNoDate
          : DateFormat.yMMMd(locale).format(d.forFormatting);
    }

    Widget dateTile({required bool start}) {
      final value = start ? _startsOn : _endsOn;
      return ListTile(
        key: Key(start ? 'vacation_starts_on' : 'vacation_ends_on'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(LucideIcons.calendar),
        title: Text(
          start ? l10n.mailVacationStartsOn : l10n.mailVacationEndsOn,
        ),
        subtitle: Text(dateLabel(value)),
        enabled: !_saving,
        onTap: () => _pickDate(start: start),
        trailing: value.isEmpty
            ? null
            : IconButton(
                tooltip: l10n.mailVacationClearDate,
                icon: const Icon(LucideIcons.x),
                onPressed: _saving
                    ? null
                    : () => setState(() {
                        if (start) {
                          _startsOn = '';
                        } else {
                          _endsOn = '';
                        }
                      }),
              ),
      );
    }

    Widget body;
    if (_loading && v == null) {
      body = const StateView.loading();
    } else if (v == null) {
      final err = _loadError!;
      body = ErrorText.isOffline(err)
          ? StateView.offline(
              message: ErrorText.describe(l10n, err),
              onRetry: _load,
            )
          : StateView.error(
              message: ErrorText.describe(l10n, err),
              onRetry: _load,
            );
    } else {
      final (statusText, statusColor) = v.activeNow
          ? (l10n.mailVacationActiveNow, tokens.success)
          : v.pending
          ? (l10n.mailVacationPending, tokens.info)
          : (l10n.mailVacationInactive, tokens.textMuted);
      body = ListView(
        padding: const EdgeInsets.all(Space.md),
        children: [
          if (_error != null) ...[
            ErrorMessage(_error!),
            const SizedBox(height: Space.md),
          ],
          Text(
            statusText,
            key: const Key('vacation_status'),
            style: theme.textTheme.bodyMedium?.copyWith(color: statusColor),
          ),
          MailSyncNotice(v.sync),
          SwitchListTile(
            key: const Key('vacation_enabled'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.mailVacationEnabled),
            value: _enabled,
            onChanged: _saving ? null : (x) => setState(() => _enabled = x),
          ),
          TextField(
            key: const Key('vacation_subject'),
            controller: _subject,
            enabled: !_saving,
            decoration: InputDecoration(labelText: l10n.mailVacationSubject),
          ),
          const SizedBox(height: Space.sm),
          TextField(
            key: const Key('vacation_body'),
            controller: _body,
            enabled: !_saving,
            minLines: 4,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              labelText: l10n.mailVacationBody,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: Space.sm),
          dateTile(start: true),
          dateTile(start: false),
          TextField(
            key: const Key('vacation_zone'),
            controller: _zone,
            enabled: !_saving,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.mailVacationTimeZone,
              hintText: MailVacation.defaultTimeZone,
            ),
          ),
          const SizedBox(height: Space.sm),
          Text(l10n.mailVacationNote, style: muted),
          const SizedBox(height: Space.lg),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mailSettingsVacation),
        // In the app bar so it stays reachable above a long reply text.
        actions: [
          if (v != null)
            TextButton(
              key: const Key('vacation_save'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.save),
            ),
        ],
      ),
      body: body,
    );
  }
}
