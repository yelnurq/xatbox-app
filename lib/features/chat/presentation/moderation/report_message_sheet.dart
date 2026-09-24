import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../../data/chat_messenger2.dart';
import '../../data/chat_models.dart';
import '../chat_formatters.dart';
import '../messenger2_providers.dart';
import '../../../../shared/widgets/app_sheet.dart';

String reportReasonLabel(AppLocalizations l10n, ChatReportReason r) =>
    switch (r) {
      ChatReportReason.spam => l10n.chatReportReasonSpam,
      ChatReportReason.abuse => l10n.chatReportReasonAbuse,
      ChatReportReason.confidential => l10n.chatReportReasonConfidential,
      ChatReportReason.other => l10n.chatReportReasonOther,
    };

IconData reportReasonIcon(ChatReportReason r) => switch (r) {
  ChatReportReason.spam => LucideIcons.megaphone,
  ChatReportReason.abuse => LucideIcons.messageSquareWarning,
  ChatReportReason.confidential => LucideIcons.lock,
  ChatReportReason.other => LucideIcons.circleHelp,
};

/// «Пожаловаться»: reason, optional comment, send. Pops true when sent.
class ReportMessageSheet extends ConsumerStatefulWidget {
  const ReportMessageSheet({super.key, required this.message});
  final ChatMessage message;

  static Future<bool?> show(BuildContext context, ChatMessage message) =>
      showAppSheet<bool>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => ReportMessageSheet(message: message),
      );

  @override
  ConsumerState<ReportMessageSheet> createState() => _ReportMessageSheetState();
}

class _ReportMessageSheetState extends ConsumerState<ReportMessageSheet> {
  ChatReportReason? _reason;
  final _comment = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null || _busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    try {
      await ref
          .read(chatMessenger2ApiProvider)
          .report(widget.message.id, reason: reason, comment: _comment.text.trim());
      messenger?.showSnackBar(SnackBar(content: Text(l10n.chatReportSent)));
      if (mounted) Navigator.pop(context, true);
    } on AppException catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(ChatFormat.error(l10n, e))));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          key: const Key('report_sheet'),
          padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.flag, color: t.danger),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      l10n.chatReportTitle,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.xs),
              Container(
                padding: const EdgeInsets.all(Space.sm),
                decoration: BoxDecoration(
                  color: t.surfaceSubtle,
                  borderRadius: BorderRadius.circular(t.radiusSm),
                  border: Border(left: BorderSide(color: t.borderStrong, width: 2)),
                ),
                child: Text(
                  ChatFormat.preview(l10n, widget.message),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: t.textSecondary),
                ),
              ),
              const SizedBox(height: Space.sm),
              for (final r in ChatReportReason.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.xs),
                  child: Material(
                    color: _reason == r ? t.dangerSoft : t.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(t.radiusMd),
                      side: BorderSide(
                        color: _reason == r ? t.danger : t.border,
                        width: t.borderWidth,
                      ),
                    ),
                    child: InkWell(
                      key: ValueKey('report_reason_${r.apiName}'),
                      borderRadius: BorderRadius.circular(t.radiusMd),
                      onTap: _busy ? null : () => setState(() => _reason = r),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.smd,
                          vertical: Space.smd,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              reportReasonIcon(r),
                              size: 20,
                              color: _reason == r ? t.danger : t.textSecondary,
                            ),
                            const SizedBox(width: Space.smd),
                            Expanded(child: Text(reportReasonLabel(l10n, r))),
                            if (_reason == r)
                              Icon(LucideIcons.circleCheck, size: 20, color: t.danger),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: Space.xs),
              TextField(
                key: const Key('report_comment'),
                controller: _comment,
                minLines: 1,
                maxLines: 4,
                maxLength: 1000,
                enabled: !_busy,
                decoration: InputDecoration(labelText: l10n.chatReportComment),
              ),
              const SizedBox(height: Space.sm),
              FilledButton.icon(
                key: const Key('report_send'),
                style: FilledButton.styleFrom(
                  backgroundColor: t.danger,
                  foregroundColor: t.textInverse,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: _reason == null || _busy ? null : _send,
                icon: _busy
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: t.textInverse),
                      )
                    : const Icon(LucideIcons.send, size: 18),
                label: Text(l10n.chatReportSend),
              ),
              const SizedBox(height: Space.xs),
              Text(
                l10n.chatReportPrivacyHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: t.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
