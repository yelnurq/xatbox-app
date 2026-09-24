import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/localization/localization.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/ds/x_badge.dart';
import '../data/meetings.dart';
import 'calls_format.dart';
import 'calls_providers.dart';

/// «Встречи» on the calls tab: today's and upcoming meetings, with
/// «Подключиться» once a meeting opens. Hidden when there are none.
class CallsMeetingsSection extends ConsumerWidget {
  const CallsMeetingsSection({super.key});

  static const maxShown = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetings = ref.watch(meetingsProvider).value ?? const <Meeting>[];
    if (meetings.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final t = context.tokens;
    final now = ref.watch(callClockProvider)();
    final shown = meetings.take(maxShown).toList();
    return Padding(
      key: const Key('calls_meetings'),
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: Space.xs, bottom: Space.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.meetingsSection,
                    style: TextStyle(color: t.textTertiary, fontSize: t.display.fontSizeMeta, fontWeight: FontWeight.w600, letterSpacing: 0.2),
                  ),
                ),
                if (meetings.length > maxShown) CountPill(meetings.length, accent: false),
              ],
            ),
          ),
          for (final m in shown) _MeetingCard(meeting: m, now: now),
        ],
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({required this.meeting, required this.now});
  final Meeting meeting;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final m = meeting;
    final joinable = meetingJoinableAt(m, now);
    final local = m.startsAt.toLocal();
    final today = DateUtils.isSameDay(local, now.toLocal());
    final when = '${today ? l10n.meetingsToday : CallsFormat.day(context, local)}, '
        '${CallsFormat.time(context, m.startsAt)}–${CallsFormat.time(context, m.endsAt)}';
    final radius = t.cardRadius;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs + 2),
      child: Material(
        color: m.isLive ? t.successSoft : t.surfaceSubtle,
        borderRadius: radius,
        child: InkWell(
          key: ValueKey('meeting_${m.code}'),
          borderRadius: radius,
          onTap: () => context.push(Routes.meetPath(m.code)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.smd, Space.sm, Space.sm, Space.sm),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: m.isLive ? t.success : t.primarySoft, borderRadius: t.controlRadius),
                  child: Icon(LucideIcons.video, size: 18, color: m.isLive ? t.onBrand : t.primary),
                ),
                const SizedBox(width: Space.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600, fontSize: t.display.fontSizeBase),
                      ),
                      const SizedBox(height: Space.xxs),
                      Text(
                        when,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: t.textSecondary, fontSize: t.display.fontSizeMeta + 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.sm),
                if (joinable)
                  FilledButton.tonal(
                    key: ValueKey('meeting_join_${m.code}'),
                    style: FilledButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: Space.smd)),
                    onPressed: () => context.push(Routes.meetPath(m.code)),
                    child: Text(l10n.meetingJoin),
                  )
                else
                  XBadge(m.isLive ? l10n.meetingLive : CallsFormat.time(context, m.opensAt), tone: BadgeTone.neutral, icon: LucideIcons.clock, small: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
