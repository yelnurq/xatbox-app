import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/initials_avatar.dart';
import '../../../../shared/widgets/state_view.dart';
import '../../data/chat_models.dart';
import '../broadcast/broadcast_format.dart';
import '../broadcast/broadcast_providers.dart';
import '../chat_formatters.dart';
import '../chat_providers.dart';
import '../../../../shared/widgets/app_sheet.dart';

/// A poll inside a message bubble: choices before voting, animated results
/// after voting or closing, voters of public polls, retract and close.
class PollCard extends ConsumerStatefulWidget {
  const PollCard({super.key, required this.message, required this.selfId});
  final ChatMessage message;
  final String selfId;

  @override
  ConsumerState<PollCard> createState() => _PollCardState();
}

class _PollCardState extends ConsumerState<PollCard> {
  /// Answer of the last vote/retract/close call, until the realtime update
  /// replaces the message.
  ChatPoll? _local;
  final Set<int> _picked = {};
  bool _busy = false;

  @override
  void didUpdateWidget(covariant PollCard old) {
    super.didUpdateWidget(old);
    if (!identical(old.message.poll, widget.message.poll)) _local = null;
  }

  Future<void> _run(Future<ChatPoll> Function() call) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final poll = await call();
      if (mounted) {
        setState(() {
          _local = (widget.message.poll ?? poll).mergeUpdate(poll);
          _picked.clear();
        });
      }
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(broadcastErrorText(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _vote(List<int> options) {
    unawaited(HapticFeedback.selectionClick());
    final sorted = [...options]..sort();
    _run(() => ref.read(chatBroadcastApiProvider).vote(widget.message.id, sorted));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final m = widget.message;
    final poll = _local ?? m.poll!;
    final closed = poll.isClosedAt(DateTime.now());
    final showResults = closed || poll.voted;
    final isAdmin = ref.watch(
      conversationProvider(m.conversationId).select((s) => s.conversation?.isAdmin ?? false),
    );
    final canClose = !closed && m.seq > 0 && (m.senderId == widget.selfId || isAdmin);
    final canRetract = !closed && poll.voted && !poll.quiz;
    final width = (math.min(MediaQuery.sizeOf(context).width * 0.8, 520.0) - 36).clamp(200.0, 340.0);
    final kind = poll.quiz
        ? l10n.pollKindQuiz
        : (poll.anonymous ? l10n.pollKindAnonymous : l10n.pollKindPublic);
    final subtitle = closed
        ? l10n.pollClosed
        : (poll.closeAt == null ? kind : '$kind · ${l10n.pollEndsAt(formatWhen(context, poll.closeAt!))}');
    // Narrow padding, but a full 48 dp touch target (ТЗ п.24.22).
    final compact = TextButton.styleFrom(
      visualDensity: VisualDensity.standard,
      padding: const EdgeInsets.symmetric(horizontal: Space.sm),
      minimumSize: const Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.padded,
    );

    return SizedBox(
      key: ValueKey('poll_${m.id}'),
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            poll.question,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: t.textPrimary),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  closed ? LucideIcons.lock : (poll.quiz ? LucideIcons.graduationCap : LucideIcons.listChecks),
                  size: 13,
                  color: t.textTertiary,
                ),
              ),
              const SizedBox(width: Space.xs),
              Flexible(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: t.textTertiary),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          for (var i = 0; i < poll.options.length; i++)
            showResults ? _result(context, poll, i) : _choice(context, poll, i),
          if (!showResults && poll.multiple)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  key: ValueKey('poll_vote_${m.id}'),
                  onPressed: _picked.isEmpty || _busy ? null : () => _vote(_picked.toList()),
                  child: Text(l10n.pollVote),
                ),
              ),
            ),
          const SizedBox(height: Space.xs),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Space.xs,
            children: [
              Text(
                l10n.pollVotes(poll.totalVoters),
                key: ValueKey('poll_total_${m.id}'),
                style: theme.textTheme.labelSmall?.copyWith(color: t.textTertiary),
              ),
              if (canRetract)
                TextButton(
                  key: ValueKey('poll_retract_${m.id}'),
                  style: compact,
                  onPressed: _busy
                      ? null
                      : () => _run(() => ref.read(chatBroadcastApiProvider).retractVote(m.id)),
                  child: Text(l10n.pollRetract),
                ),
              if (canClose)
                TextButton(
                  key: ValueKey('poll_close_${m.id}'),
                  style: compact,
                  onPressed: _busy
                      ? null
                      : () => _run(() => ref.read(chatBroadcastApiProvider).closePoll(m.id)),
                  child: Text(l10n.pollCloseNow),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _choice(BuildContext context, ChatPoll poll, int i) {
    final t = context.tokens;
    final picked = _picked.contains(i);
    final icon = poll.multiple
        ? (picked ? LucideIcons.squareCheck : LucideIcons.square)
        : LucideIcons.circle;
    final enabled = !_busy && widget.message.seq > 0;
    // A checkbox (multiple answers) or a radio button (one answer).
    return Semantics(
      container: true,
      checked: picked,
      inMutuallyExclusiveGroup: !poll.multiple,
      enabled: enabled,
      label: poll.options[i].text,
      child: InkWell(
        key: ValueKey('poll_opt_${widget.message.id}_$i'),
        borderRadius: BorderRadius.circular(t.radiusSm),
        onTap: !enabled
            ? null
            : () {
                if (!poll.multiple) {
                  _vote([i]);
                  return;
                }
                setState(() => picked ? _picked.remove(i) : _picked.add(i));
              },
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: picked ? t.primary : t.textTertiary),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      poll.options[i].text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _result(BuildContext context, ChatPoll poll, int i) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final option = poll.options[i];
    final mine = poll.myVotes?.contains(i) ?? false;
    final correct = poll.quiz && poll.correctOption == i;
    final wrong = poll.quiz && mine && poll.correctOption != null && poll.correctOption != i;
    final color = correct ? t.success : (wrong ? t.danger : t.primary);
    final pct = poll.percentOf(i);
    final canOpen = !poll.anonymous && option.votes > 0;
    final l10n = context.l10n;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final label = [
      option.text,
      '$pct%',
      if (mine) l10n.a11ySelected,
      if (correct) l10n.pollCorrect,
    ].join(', ');
    return Semantics(
      container: true,
      button: canOpen,
      label: label,
      child: InkWell(
      key: ValueKey('poll_result_${widget.message.id}_$i'),
      borderRadius: BorderRadius.circular(t.radiusSm),
      onTap: canOpen
          ? () => PollVotersSheet.show(context, messageId: widget.message.id, option: i, optionText: option.text)
          : null,
      child: ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
        child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 40,
                  // «100%» never wraps at large text sizes.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$pct%',
                      maxLines: 1,
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: t.textPrimary),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    option.text,
                    style: theme.textTheme.bodyMedium?.copyWith(color: t.textPrimary),
                  ),
                ),
                if (mine || correct)
                  Padding(
                    padding: const EdgeInsets.only(left: Space.xs),
                    child: Icon(
                      correct ? LucideIcons.circleCheck : (wrong ? LucideIcons.circleX : LucideIcons.check),
                      size: 16,
                      color: color,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(XatBoxTokens.radiusPill),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: pct / 100),
                  duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 5,
                    color: color,
                    backgroundColor: t.surfaceMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
      ),
      ),
    );
  }
}

/// Who chose one option of a public poll.
class PollVotersSheet extends ConsumerWidget {
  const PollVotersSheet({
    super.key,
    required this.messageId,
    required this.option,
    required this.optionText,
  });
  final String messageId;
  final int option;
  final String optionText;

  static Future<void> show(
    BuildContext context, {
    required String messageId,
    required int option,
    required String optionText,
  }) => showAppSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => PollVotersSheet(messageId: messageId, option: option, optionText: optionText),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final voters = ref.watch(pollVotersProvider((messageId: messageId, option: option)));
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          key: const Key('poll_voters_sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    optionText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(l10n.pollVotersTitle, style: theme.textTheme.bodySmall?.copyWith(color: t.textTertiary)),
                ],
              ),
            ),
            Flexible(
              child: voters.when(
                loading: () => const SizedBox(height: 120, child: StateView.loading()),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: Text(broadcastErrorText(l10n, e), textAlign: TextAlign.center),
                ),
                data: (list) => list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(Space.lg),
                        child: Text(l10n.pollNoVoters, textAlign: TextAlign.center),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final v = list[i];
                          final name = v.displayName.isEmpty ? '…' : v.displayName;
                          return ListTile(
                            key: ValueKey('poll_voter_${v.userId}'),
                            leading: InitialsAvatar(label: name, colorKey: v.userId),
                            title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: v.votedAt == null
                                ? null
                                : Text(
                                    ChatFormat.listTime(context, v.votedAt),
                                    style: theme.textTheme.bodySmall?.copyWith(color: t.textTertiary),
                                  ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
