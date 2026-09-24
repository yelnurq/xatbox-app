import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../broadcast/broadcast_format.dart';
import '../../../../shared/widgets/app_sheet.dart';

/// Presets of «Отправить позже» and «Напомнить».
enum WhenPreset { inOneHour, tonight, tomorrowMorning }

abstract final class WhenPresets {
  static const eveningHour = 19;
  static const morningHour = 9;

  /// Presets available at [now]: «сегодня вечером» only until 18:30.
  static List<(WhenPreset, DateTime)> forNow(DateTime now) {
    final tonight = DateTime(now.year, now.month, now.day, eveningHour);
    return [
      (WhenPreset.inOneHour, now.add(const Duration(hours: 1))),
      if (now.isBefore(tonight.subtract(const Duration(minutes: 30))))
        (WhenPreset.tonight, tonight),
      (
        WhenPreset.tomorrowMorning,
        DateTime(now.year, now.month, now.day + 1, morningHour),
      ),
    ];
  }

  /// A picked time must be ahead and at most a year away (server rule).
  static bool isValid(DateTime at, DateTime now) =>
      at.isAfter(now) && at.isBefore(now.add(const Duration(days: 365)));
}

/// «Отправить, когда появится в сети» picked in the send-later sheet.
class WhenOnlineChoice {
  const WhenOnlineChoice();
}

const whenOnlineChoice = WhenOnlineChoice();

/// Bottom sheet with the presets and «Выбрать дату и время».
Future<DateTime?> showWhenPicker(
  BuildContext context, {
  required String title,
  DateTime Function()? now,
}) async {
  final picked = await showAppSheet<Object>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => WhenPickerSheet(title: title, now: now ?? DateTime.now),
  );
  return picked is DateTime ? picked : null;
}

/// «Отправить позже»: a [DateTime], or [whenOnlineChoice] when [whenOnline]
/// is offered (1:1 chats with a peer that shows its online status).
Future<Object?> showSendLaterPicker(
  BuildContext context, {
  required String title,
  bool whenOnline = false,
  DateTime Function()? now,
}) => showAppSheet<Object>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => WhenPickerSheet(
    title: title,
    now: now ?? DateTime.now,
    whenOnline: whenOnline,
  ),
);

class WhenPickerSheet extends StatelessWidget {
  const WhenPickerSheet({
    super.key,
    required this.title,
    required this.now,
    this.whenOnline = false,
  });
  final String title;
  final DateTime Function() now;

  /// Offer «Когда появится в сети».
  final bool whenOnline;

  Future<void> _pick(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final start = now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(start.year, start.month, start.day),
      lastDate: start.add(const Duration(days: 364)),
      initialDate: start,
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start.add(const Duration(hours: 1))),
    );
    if (time == null || !context.mounted) return;
    final at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!WhenPresets.isValid(at, now())) {
      messenger?.showSnackBar(SnackBar(content: Text(l10n.scheduleTooEarly)));
      return;
    }
    Navigator.pop(context, at);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final current = now();
    String label(WhenPreset p) => switch (p) {
      WhenPreset.inOneHour => l10n.scheduleIn1h,
      WhenPreset.tonight => l10n.scheduleTonight,
      WhenPreset.tomorrowMorning => l10n.scheduleTomorrowMorning,
    };
    IconData icon(WhenPreset p) => switch (p) {
      WhenPreset.inOneHour => LucideIcons.clock,
      WhenPreset.tonight => LucideIcons.moon,
      WhenPreset.tomorrowMorning => LucideIcons.sunrise,
    };
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.sm),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (whenOnline)
            ListTile(
              key: const Key('when_online'),
              leading: Icon(LucideIcons.wifi, color: t.primary),
              title: Text(
                l10n.scheduleWhenOnline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                l10n.scheduleWhenOnlineHint,
                style: theme.textTheme.bodySmall?.copyWith(color: t.textTertiary),
              ),
              onTap: () => Navigator.pop(context, whenOnlineChoice),
            ),
          for (final (preset, at) in WhenPresets.forNow(current))
            ListTile(
              key: Key('when_${preset.name}'),
              leading: Icon(icon(preset), color: t.primary),
              title: Text(label(preset), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text(
                formatWhen(context, at, now: current),
                style: theme.textTheme.bodySmall?.copyWith(color: t.textTertiary),
              ),
              onTap: () => Navigator.pop(context, at),
            ),
          ListTile(
            key: const Key('when_pick'),
            leading: Icon(LucideIcons.calendarClock, color: t.primary),
            title: Text(l10n.schedulePick),
            trailing: Icon(LucideIcons.chevronRight, color: t.textTertiary),
            onTap: () => _pick(context),
          ),
          const SizedBox(height: Space.sm),
        ],
      ),
    );
  }
}
