import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/initials_avatar.dart';
import '../../../../shared/widgets/state_view.dart';
import '../../data/chat_messenger2.dart';
import '../../data/chat_models.dart';
import '../chat_formatters.dart';
import '../chat_providers.dart';
import '../messenger2_providers.dart';
import 'report_message_sheet.dart';

String moderationActionLabel(AppLocalizations l10n, ModerationAction a) =>
    switch (a) {
      ModerationAction.deleteMessage => l10n.moderationDeleteMessage,
      ModerationAction.warn => l10n.moderationWarn,
      ModerationAction.removeMember => l10n.moderationRemove,
      ModerationAction.mute => l10n.moderationMute,
      ModerationAction.dismiss => l10n.moderationDismiss,
    };

IconData moderationActionIcon(ModerationAction a) => switch (a) {
  ModerationAction.deleteMessage => LucideIcons.trash2,
  ModerationAction.warn => LucideIcons.triangleAlert,
  ModerationAction.removeMember => LucideIcons.userMinus,
  ModerationAction.mute => LucideIcons.messageSquareOff,
  ModerationAction.dismiss => LucideIcons.circleX,
};

String _when(BuildContext context, DateTime? t) {
  if (t == null) return '';
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.yMMMd(locale).add_Hm().format(t.toLocal());
}

/// Settings → «Модерация»: reports of the organization (moderators) or of
/// the caller's groups (group admins), by status.
class ModerationQueueScreen extends ConsumerStatefulWidget {
  const ModerationQueueScreen({super.key});

  @override
  ConsumerState<ModerationQueueScreen> createState() => _ModerationQueueScreenState();
}

class _ModerationQueueScreenState extends ConsumerState<ModerationQueueScreen> {
  static const _statuses = ['open', 'resolved', 'dismissed'];
  final Map<String, ChatReportsPage?> _pages = {};
  final Map<String, Object?> _errors = {};
  StreamSubscription<ChatEvent>? _sub;

  @override
  void initState() {
    super.initState();
    for (final s in _statuses) {
      unawaited(_load(s));
    }
    _sub = ref.read(chatRepositoryProvider).events.listen((e) {
      if (e.type == 'moderation.report_created') unawaited(_load('open'));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load(String status) async {
    try {
      final page = await ref.read(chatMessenger2ApiProvider).reports(status: status);
      if (!mounted) return;
      setState(() {
        _pages[status] = page;
        _errors.remove(status);
      });
    } on AppException catch (e) {
      if (mounted) setState(() => _errors[status] = e);
    }
  }

  Future<void> _open(ChatReport r) async {
    final changed = await context.push<bool>(Routes.chatModerationReportPath(r.id));
    if (changed == true) {
      for (final s in _statuses) {
        unawaited(_load(s));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final open = _pages['open'];
    return DefaultTabController(
      length: _statuses.length,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.moderationTitle),
              if (open != null)
                Text(
                  open.global ? l10n.moderationGlobalScope : l10n.moderationGroupScope,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.textTertiary),
                ),
            ],
          ),
          bottom: TabBar(
            // Tabs size to their labels (the open tab carries a counter).
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: t.primary,
            unselectedLabelColor: t.textTertiary,
            indicatorColor: t.primary,
            tabs: [
              Tab(
                key: const Key('moderation_tab_open'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.moderationTabOpen),
                    if ((open?.openCount ?? 0) > 0) ...[
                      const SizedBox(width: Space.xs),
                      _CountPill(count: open!.openCount),
                    ],
                  ],
                ),
              ),
              Tab(text: l10n.moderationTabResolved),
              Tab(text: l10n.moderationTabDismissed),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final s in _statuses)
              RefreshIndicator(
                onRefresh: () => _load(s),
                child: _list(context, s),
              ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, String status) {
    final l10n = context.l10n;
    final page = _pages[status];
    final error = _errors[status];
    if (page == null && error != null) {
      return StateView.error(
        message: ChatFormat.error(l10n, error),
        onRetry: () => _load(status),
      );
    }
    if (page == null) return const StateView.loading();
    if (page.reports.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: 360,
            child: StateView.empty(
              title: l10n.moderationEmpty,
              subtitle: l10n.moderationEmptyHint,
              icon: LucideIcons.shieldCheck,
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      key: ValueKey('moderation_list_$status'),
      padding: const EdgeInsets.all(Space.sm),
      itemCount: page.reports.length,
      separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
      itemBuilder: (context, i) => _ReportCard(
        report: page.reports[i],
        onTap: () => _open(page.reports[i]),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: t.danger,
        borderRadius: BorderRadius.circular(XatBoxTokens.radiusPill),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: t.textInverse,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.reason});
  final ChatReportReason reason;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (bg, fg) = switch (reason) {
      ChatReportReason.confidential => (t.warningSoft, t.warning),
      ChatReportReason.abuse => (t.dangerSoft, t.danger),
      ChatReportReason.spam => (t.infoSoft, t.info),
      ChatReportReason.other => (t.surfaceSubtle, t.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(XatBoxTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(reportReasonIcon(reason), size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            reportReasonLabel(context.l10n, reason),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap});
  final ChatReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final r = report;
    return Material(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: t.cardRadius,
        side: BorderSide(color: t.border, width: t.borderWidth),
      ),
      child: InkWell(
        key: ValueKey('moderation_report_${r.id}'),
        borderRadius: t.cardRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.smd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Space.sm,
                runSpacing: Space.xs,
                children: [
                  _ReasonChip(reason: r.reason),
                  Text(
                    _when(context, r.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(color: t.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  InitialsAvatar(
                    label: r.reportedUserName.isEmpty ? '?' : r.reportedUserName,
                    colorKey: r.reportedUserId,
                    radius: InitialsAvatar.radiusSm,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.reportedUserName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          r.conversationTitle.isEmpty ? l10n.moderationDirectChat : r.conversationTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(color: t.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(
                r.snapshotBody.isEmpty ? l10n.moderationDeletedContent : r.snapshotBody,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: r.snapshotBody.isEmpty ? t.textTertiary : t.textPrimary,
                  fontStyle: r.snapshotBody.isEmpty ? FontStyle.italic : null,
                ),
              ),
              const SizedBox(height: Space.xs),
              Text(
                r.resolution != null
                    ? l10n.moderationResolution(moderationActionLabel(l10n, r.resolution!))
                    : l10n.moderationReportFrom(r.reporterName),
                style: theme.textTheme.labelSmall?.copyWith(color: t.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One report: the reported message, ±5 messages of context, the author's
/// state and the actions. Pops true when an action was applied.
class ModerationReportScreen extends ConsumerStatefulWidget {
  const ModerationReportScreen({super.key, required this.reportId});
  final String reportId;

  @override
  ConsumerState<ModerationReportScreen> createState() => _ModerationReportScreenState();
}

class _ModerationReportScreenState extends ConsumerState<ModerationReportScreen> {
  ChatReport? _report;
  Object? _error;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(chatMessenger2ApiProvider).reportDetails(widget.reportId);
      if (mounted) setState(() => _report = r);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _act(ModerationAction action) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    int? hours;
    if (action == ModerationAction.mute) {
      hours = await showDialog<int>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(l10n.moderationMute),
          children: [
            for (final h in const [1, 3, 24, 72, 168])
              SimpleDialogOption(
                key: ValueKey('mute_hours_$h'),
                onPressed: () => Navigator.pop(ctx, h),
                child: Text(l10n.moderationMuteHours(h)),
              ),
          ],
        ),
      );
      if (hours == null) return;
    }
    if (!mounted) return;
    // null = cancelled; the dialog owns its text controller (it is still
    // built during the closing animation).
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _ConfirmActionDialog(action: action),
    );
    if (text == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(chatMessenger2ApiProvider)
          .moderate(widget.reportId, action, hours: hours, note: text);
      _changed = true;
      messenger.showSnackBar(SnackBar(content: Text(l10n.moderationDone)));
      await _load();
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ChatFormat.error(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final r = _report;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.moderationReport)),
        body: r == null
            ? (_error != null
                  ? StateView.error(message: ChatFormat.error(l10n, _error!), onRetry: _load)
                  : const StateView.loading())
            : _details(context, r),
      ),
    );
  }

  Widget _details(BuildContext context, ChatReport r) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final actions = [
      if (r.snapshotBody.isNotEmpty || r.snapshotAttachments.isNotEmpty) ModerationAction.deleteMessage,
      ModerationAction.warn,
      if (r.isGroupLike && r.reportedIsMember) ModerationAction.removeMember,
      if (r.isGroupLike && r.reportedIsMember) ModerationAction.mute,
      ModerationAction.dismiss,
    ];
    return ListView(
      key: const Key('moderation_report_details'),
      padding: const EdgeInsets.all(Space.md),
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            _ReasonChip(reason: r.reason),
            Text(
              _when(context, r.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(color: t.textTertiary),
            ),
            if (!r.isOpen)
              Text(
                r.resolution == null ? '' : moderationActionLabel(l10n, r.resolution!),
                style: theme.textTheme.labelMedium?.copyWith(color: t.success),
              ),
          ],
        ),
        const SizedBox(height: Space.md),
        Text(l10n.moderationReportFrom(r.reporterName), style: theme.textTheme.bodySmall?.copyWith(color: t.textSecondary)),
        Text(
          '${l10n.moderationAuthor(r.reportedUserName)} · ${r.conversationTitle.isEmpty ? l10n.moderationDirectChat : r.conversationTitle}',
          style: theme.textTheme.bodySmall?.copyWith(color: t.textSecondary),
        ),
        if (r.restrictedUntil != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text(
              l10n.moderationRestrictedUntil(_when(context, r.restrictedUntil)),
              style: theme.textTheme.bodySmall?.copyWith(color: t.warning),
            ),
          )
        else if (r.isGroupLike && !r.reportedIsMember)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text(l10n.moderationNotMember, style: theme.textTheme.bodySmall?.copyWith(color: t.textTertiary)),
          ),
        if (r.comment.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          Text(l10n.moderationComment, style: theme.textTheme.titleSmall),
          const SizedBox(height: Space.xs),
          Text(r.comment),
        ],
        const SizedBox(height: Space.md),
        Text(l10n.moderationContext, style: theme.textTheme.titleSmall),
        const SizedBox(height: Space.sm),
        if (r.context.isEmpty)
          _ContextTile(
            name: r.reportedUserName,
            senderId: r.reportedUserId,
            body: r.snapshotBody.isEmpty ? l10n.moderationDeletedContent : r.snapshotBody,
            highlighted: true,
          )
        else
          for (final raw in r.context)
            Builder(
              builder: (context) {
                final m = ChatMessage.fromJson(raw);
                final reported = m.id == r.messageId;
                final body = m.isDeleted
                    ? l10n.moderationDeletedContent
                    : (m.isSystem
                          ? ChatFormat.systemText(l10n, m, names: const {})
                          : ChatFormat.preview(l10n, m));
                return _ContextTile(
                  key: ValueKey('moderation_context_${m.id}'),
                  name: m.senderId == r.reportedUserId
                      ? r.reportedUserName
                      : (m.senderId == r.reporterId ? r.reporterName : l10n.moderationMember),
                  senderId: m.senderId,
                  body: reported && r.snapshotBody.isNotEmpty && m.isDeleted ? r.snapshotBody : body,
                  highlighted: reported,
                  system: m.isSystem,
                );
              },
            ),
        if (r.isOpen) ...[
          const SizedBox(height: Space.lg),
          Text(l10n.moderationActions, style: theme.textTheme.titleSmall),
          const SizedBox(height: Space.xs),
          for (final a in actions)
            ListTile(
              key: ValueKey('moderation_action_${a.apiName}'),
              contentPadding: EdgeInsets.zero,
              enabled: !_busy,
              leading: Icon(
                moderationActionIcon(a),
                color: a == ModerationAction.dismiss ? t.textSecondary : t.danger,
              ),
              title: Text(
                moderationActionLabel(l10n, a),
                style: TextStyle(color: a == ModerationAction.dismiss ? null : t.danger),
              ),
              onTap: () => _act(a),
            ),
        ],
      ],
    );
  }
}

/// Confirms a moderation action with an optional note for the audit log;
/// pops the trimmed note ('' = none) or null when cancelled.
class _ConfirmActionDialog extends StatefulWidget {
  const _ConfirmActionDialog({required this.action});
  final ModerationAction action;

  @override
  State<_ConfirmActionDialog> createState() => _ConfirmActionDialogState();
}

class _ConfirmActionDialogState extends State<_ConfirmActionDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(moderationActionLabel(l10n, widget.action)),
      content: TextField(
        key: const Key('moderation_note'),
        controller: _note,
        maxLength: 500,
        decoration: InputDecoration(labelText: l10n.moderationNote),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('moderation_confirm'),
          style: widget.action == ModerationAction.dismiss
              ? null
              : FilledButton.styleFrom(backgroundColor: context.tokens.danger),
          onPressed: () => Navigator.pop(context, _note.text.trim()),
          child: Text(l10n.moderationConfirm),
        ),
      ],
    );
  }
}

class _ContextTile extends StatelessWidget {
  const _ContextTile({
    super.key,
    required this.name,
    required this.senderId,
    required this.body,
    this.highlighted = false,
    this.system = false,
  });
  final String name;
  final String senderId;
  final String body;
  final bool highlighted;
  final bool system;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    if (system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Center(
          child: Text(body, style: theme.textTheme.labelSmall?.copyWith(color: t.textTertiary)),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: Space.xs),
      padding: const EdgeInsets.all(Space.sm),
      decoration: BoxDecoration(
        color: highlighted ? t.dangerSoft : t.surfaceSubtle,
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: highlighted ? Border.all(color: t.danger, width: 1.2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: theme.textTheme.labelMedium?.copyWith(
              color: t.avatarTextColorFor(senderId),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
