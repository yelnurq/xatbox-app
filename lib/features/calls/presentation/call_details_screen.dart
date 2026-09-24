import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/localization/localization.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/error_text.dart';
import '../../../shared/widgets/ds/x_badge.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/state_view.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../chat/presentation/chat_providers.dart';
import '../data/call_models.dart';
import 'calls_format.dart';
import 'calls_providers.dart';
import 'calls_screen.dart';
import 'widgets/call_recording.dart';

/// Call card (ТЗ п.24.9 «нажатие на запись — карточка звонка»): type,
/// direction and result, start, duration, participants with status and role;
/// call again (audio / video, same participants) and «Написать» for 1:1.
class CallDetailsScreen extends ConsumerStatefulWidget {
  const CallDetailsScreen({super.key, required this.callId, this.initial});

  final String callId;

  /// The history row, shown at once while the call is reloaded.
  final CallInfo? initial;

  @override
  ConsumerState<CallDetailsScreen> createState() => _CallDetailsScreenState();
}

class _CallDetailsScreenState extends ConsumerState<CallDetailsScreen> {
  CallInfo? _call;
  Object? _error;
  bool _loading = true;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _call = widget.initial;
    Future.microtask(_load);
  }

  /// `GET /calls/{id}` has no `direction`/`outcome` (history-only fields):
  /// keep them from the history row.
  static CallInfo _merge(CallInfo fresh, CallInfo? known) {
    if (known == null) return fresh;
    return CallInfo.fromJson({
      ...fresh.raw,
      if (fresh.direction.isEmpty && known.direction.isNotEmpty) 'direction': known.direction,
      if (fresh.raw['outcome'] == null && known.raw['outcome'] != null) 'outcome': known.raw['outcome'],
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final fresh = await ref.read(callsApiProvider).get(widget.callId);
      if (!mounted) return;
      setState(() {
        _call = _merge(fresh, _call);
        _error = null;
        _loading = false;
      });
    } on AppException catch (e) {
      var fallback = _call;
      if (fallback == null) {
        try {
          fallback = await ref.read(callsCacheProvider).findCall(widget.callId);
        } on Object {
          fallback = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _call = fallback;
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _message(String userId) async {
    if (_opening) return;
    setState(() => _opening = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final conv = await ref.read(chatRepositoryProvider).createDirect(userId);
      if (!mounted) return;
      unawaited(router.push(Routes.chatConversationPath(conv.id)));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(CallsFormat.error(l10n, e))));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final call = _call;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.callsDetailsTitle)),
      body: call == null
          ? (_loading || _error == null
                ? const StateView.loading()
                : ErrorText.isOffline(_error)
                ? StateView.offline(message: ErrorText.describe(l10n, _error!), onRetry: _load)
                : StateView.error(message: CallsFormat.error(l10n, _error!), onRetry: _load))
          : Column(
              children: [
                if (_error != null && ErrorText.isOffline(_error)) OfflineBanner(text: l10n.offlineBanner, onRetry: _load),
                Expanded(
                  child: RefreshIndicator(onRefresh: _load, child: _details(context, call)),
                ),
              ],
            ),
    );
  }

  Widget _details(BuildContext context, CallInfo call) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final selfId = ref.watch(currentUserProvider)?.id ?? '';
    final others = call.others(selfId);
    final title = call.displayTitle(selfId);
    final direct = !call.isGroup && others.length == 1;
    final enabled = ref.watch(callsEnabledProvider);
    final missed = call.outcome == CallOutcome.missed;
    final outgoing = call.isOutgoingFor(selfId);
    final answered = call.outcome == CallOutcome.answered || call.durationSec > 0;
    final result = [
      CallsFormat.direction(l10n, call, selfId),
      CallsFormat.result(l10n, call),
    ].where((s) => s.isNotEmpty).toSet().join(' · ');

    void redial(bool video) => startCallFromUi(
      context,
      ref,
      calleeIds: others.map((p) => p.userId).toList(),
      video: video,
      conversationId: call.conversationId,
      mode: call.mode,
      title: call.title.isEmpty ? null : call.title,
    );

    Widget info(String key, IconData icon, String label, String value, {Color? color}) => ListTile(
      key: Key(key),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: color == null ? tokens.surfaceSubtle : tokens.dangerSoft, borderRadius: tokens.controlRadius),
        child: Icon(icon, size: 18, color: color ?? tokens.textSecondary),
      ),
      title: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: tokens.textTertiary)),
      subtitle: Text(value, style: theme.textTheme.bodyLarge?.copyWith(color: color ?? tokens.textPrimary)),
    );

    final other = others.firstOrNull;
    final Widget avatar = call.isGroup
        ? Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: tokens.primarySoft, shape: BoxShape.circle),
            child: Icon(LucideIcons.users, size: 40, color: tokens.primary),
          )
        : (direct && other != null && other.email.isNotEmpty
              ? UserAvatar(email: other.email, label: title, radius: 44)
              : InitialsAvatar(label: title, colorKey: other?.userId ?? call.id, radius: 44));

    return ListView(
      key: const Key('call_details'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Space.md, Space.lg, Space.md, Space.xl),
      children: [
        Center(child: avatar),
        const SizedBox(height: Space.smd),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(color: tokens.textPrimary, fontWeight: tokens.titleWeight),
        ),
        const SizedBox(height: Space.sm),
        Center(
          child: XBadge(
            CallsFormat.outcome(l10n, call, selfId),
            tone: missed ? BadgeTone.danger : (answered ? BadgeTone.success : BadgeTone.neutral),
            icon: missed ? LucideIcons.phoneMissed : (outgoing ? LucideIcons.phoneOutgoing : LucideIcons.phoneIncoming),
          ),
        ),
        const SizedBox(height: Space.lg),
        // Wraps on narrow phones (long labels in ru/kk at 360 px).
        Wrap(
          alignment: WrapAlignment.center,
          spacing: Space.lg,
          runSpacing: Space.md,
          children: [
            _RoundAction(
              key: const Key('call_details_audio'),
              icon: LucideIcons.phone,
              label: l10n.callsAudio,
              onPressed: enabled && others.isNotEmpty ? () => redial(false) : null,
            ),
            _RoundAction(
              key: const Key('call_details_video'),
              icon: LucideIcons.video,
              label: l10n.callsVideo,
              onPressed: enabled && others.isNotEmpty ? () => redial(true) : null,
            ),
            if (direct)
              _RoundAction(
                key: const Key('call_details_message'),
                icon: LucideIcons.messageCircle,
                label: l10n.callsDetailsMessage,
                onPressed: _opening ? null : () => _message(others.single.userId),
              ),
          ],
        ),
        const SizedBox(height: Space.lg),
        _Card(
          children: [
            info(
              'call_details_type',
              call.isVideo ? LucideIcons.video : LucideIcons.phone,
              l10n.callsDetailsType,
              '${call.isVideo ? l10n.callsVideo : l10n.callsAudio} · ${CallsFormat.mode(l10n, call.mode)}',
            ),
            info(
              'call_details_result',
              missed ? LucideIcons.phoneMissed : (outgoing ? LucideIcons.phoneOutgoing : LucideIcons.phoneIncoming),
              l10n.callsDetailsResult,
              result,
              color: missed ? tokens.danger : null,
            ),
            info('call_details_started', LucideIcons.clock, l10n.callsDetailsStarted, CallsFormat.dateTime(context, call.createdAt)),
            info(
              'call_details_duration',
              LucideIcons.timer,
              l10n.callsDetailsDuration,
              call.durationSec > 0 ? CallsFormat.duration(Duration(seconds: call.durationSec)) : l10n.callsDetailsNoConversation,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.xs, Space.lg, Space.xs, Space.sm),
          child: Text(
            l10n.callsParticipantsCount(call.participants.length),
            style: TextStyle(color: tokens.textTertiary, fontSize: tokens.display.fontSizeMeta + 1, fontWeight: FontWeight.w600),
          ),
        ),
        _Card(
          children: [
            for (final p in call.participants)
              ListTile(
                key: ValueKey('call_details_participant_${p.userId}'),
                leading: p.email.isNotEmpty
                    ? UserAvatar(email: p.email, label: p.label, radius: 20)
                    : InitialsAvatar(label: p.label, colorKey: p.userId),
                title: Text(
                  p.userId == selfId ? '${p.label} (${l10n.callsYou})' : p.label,
                  style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  [CallsFormat.role(l10n, p.role), CallsFormat.participantStatus(l10n, p.status)].where((s) => s.isNotEmpty).join(' · '),
                  style: TextStyle(color: tokens.textSecondary),
                ),
              ),
          ],
        ),
        // Recordings (download / open), when recording is enabled and the call has any.
        CallRecordingsSection(key: ValueKey('call_recordings_${call.id}'), callId: call.id),
      ],
    );
  }
}

/// Surface card with hairline dividers between rows.
class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Shadow outside, surface as a Material so row ink stays visible.
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: t.cardRadius, boxShadow: t.shadowSm),
      child: Material(
        color: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: t.cardRadius,
          side: BorderSide(color: t.border, width: t.borderWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final (i, c) in children.indexed) ...[
              if (i > 0) Divider(height: 1, indent: 68, color: t.divider),
              c,
            ],
          ],
        ),
      ),
    );
  }
}

/// Big round quick action with a label (call again, message).
class _RoundAction extends StatelessWidget {
  const _RoundAction({super.key, required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onPressed == null ? 0.45 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: t.primarySoft,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: SizedBox.square(dimension: 56, child: Icon(icon, color: t.primary)),
              ),
            ),
            const SizedBox(height: Space.xs + 2),
            Text(label, style: TextStyle(color: t.textSecondary, fontSize: t.display.fontSizeMeta + 1, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
