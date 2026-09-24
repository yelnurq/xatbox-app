import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error_codes.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/utils/diagnostic_log.dart';
import '../../../../shared/utils/error_text.dart';
import '../../../../shared/widgets/state_view.dart';
import '../../data/mail_settings_models.dart';
import '../mail_error_text.dart';
import '../mail_providers.dart';
import 'mail_settings_widgets.dart';

/// `GET/POST /mail/sender-rules`, `DELETE /mail/sender-rules/{id}`.
class BlockedSendersScreen extends ConsumerStatefulWidget {
  const BlockedSendersScreen({super.key});

  @override
  ConsumerState<BlockedSendersScreen> createState() =>
      _BlockedSendersScreenState();
}

class _BlockedSendersScreenState extends ConsumerState<BlockedSendersScreen> {
  MailSenderRuleList? _list;
  Object? _loadError;
  bool _loading = true;
  final Set<String> _removing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final list = await ref.read(mailApiProvider).senderRules();
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
      });
    } on AppException catch (e) {
      DiagnosticLog.warn('mail', 'sender rules load failed', error: e);
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  void _replaceRules(List<MailSenderRule> rules) {
    final list = _list;
    if (list == null) return;
    setState(
      () => _list = MailSenderRuleList(
        rules: rules,
        limit: list.limit,
        sync: const MailSyncState(state: 'pending'),
      ),
    );
  }

  Future<void> _add() async {
    final l10n = context.l10n;
    final api = ref.read(mailApiProvider);
    await showDialog<bool>(
      context: context,
      builder: (_) => MailFormDialog(
        title: l10n.mailBlockedAddTitle,
        submitLabel: l10n.mailBlockedAdd,
        fields: [
          MailFormFieldSpec(
            key: 'blocked_value',
            label: l10n.mailBlockedValue,
            hint: l10n.mailBlockedValueHint,
            keyboardType: TextInputType.emailAddress,
          ),
          MailFormFieldSpec(key: 'blocked_note', label: l10n.mailBlockedNote),
        ],
        validate: (values) {
          if (values[0].trim().isEmpty) return l10n.mailErrEmptyPattern;
          if (values[1].trim().runes.length > MailSenderRule.maxNoteChars) {
            return l10n.mailErrNoteTooLong;
          }
          return null;
        },
        onSubmit: (values) async {
          try {
            final rule = await api.addSenderRule(
              value: values[0],
              note: values[1],
            );
            if (mounted) _replaceRules([rule, ...?_list?.rules]);
            return null;
          } on AppException catch (e) {
            DiagnosticLog.warn('mail', 'sender rule add failed', error: e);
            return MailErrorText.describe(l10n, e);
          }
        },
      ),
    );
  }

  Future<void> _remove(MailSenderRule rule) async {
    final l10n = context.l10n;
    final ok = await confirmMailAction(
      context,
      title: l10n.mailBlockedRemoveTitle(rule.pattern),
      confirmLabel: l10n.mailBlockedRemove,
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _removing.add(rule.id));
    try {
      await ref.read(mailApiProvider).deleteSenderRule(rule.id);
      if (!mounted) return;
      _replaceRules([...?_list?.rules.where((r) => r.id != rule.id)]);
    } on AppException catch (e) {
      DiagnosticLog.warn('mail', 'sender rule delete failed', error: e);
      if (!mounted) return;
      if (e is ApiException && e.code == ApiErrorCodes.ruleNotFound) {
        _replaceRules([...?_list?.rules.where((r) => r.id != rule.id)]);
      }
      messenger.showSnackBar(
        SnackBar(content: Text(MailErrorText.describe(l10n, e))),
      );
    } finally {
      if (mounted) setState(() => _removing.remove(rule.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final list = _list;

    Widget body;
    if (_loading && list == null) {
      body = const StateView.loading();
    } else if (list == null) {
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
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                Space.sm,
                Space.md,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.mailSettingsBlockedSubtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                  ),
                  if (list.rules.isNotEmpty)
                    Text(
                      l10n.mailBlockedCount(list.rules.length, list.limit),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                    ),
                  MailSyncNotice(list.sync),
                ],
              ),
            ),
            if (list.rules.isEmpty)
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.5,
                child: StateView.empty(
                  title: l10n.mailBlockedEmpty,
                  icon: LucideIcons.ban,
                ),
              ),
            for (final rule in list.rules)
              ListTile(
                key: ValueKey('rule_${rule.id}'),
                leading: Icon(switch (rule.kind) {
                  'ip' => LucideIcons.server,
                  'network' => LucideIcons.network,
                  _ => LucideIcons.globe,
                }),
                title: Text(rule.pattern),
                subtitle: Text(
                  [
                    switch (rule.kind) {
                      'ip' => l10n.mailBlockedKindIp,
                      'network' => l10n.mailBlockedKindNetwork,
                      _ => l10n.mailBlockedKindDomain,
                    },
                    if (rule.note.isNotEmpty) rule.note,
                  ].join(' · '),
                ),
                trailing: _removing.contains(rule.id)
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        tooltip: l10n.mailBlockedRemove,
                        icon: const Icon(LucideIcons.trash2),
                        onPressed: () => _remove(rule),
                      ),
              ),
          ],
        ),
      );
    }

    final canAdd = list != null && list.rules.length < list.limit;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mailSettingsBlocked)),
      body: body,
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(
              key: const Key('blocked_add'),
              onPressed: _add,
              icon: const Icon(LucideIcons.ban),
              label: Text(l10n.mailBlockedAdd),
            )
          : null,
    );
  }
}
