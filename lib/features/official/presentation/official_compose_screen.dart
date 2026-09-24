import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/state_view.dart';
import '../../contacts/data/contact_models.dart';
import '../data/official_models.dart';
import 'official_providers.dart';
import 'official_widgets.dart';
import '../../../shared/widgets/app_sheet.dart';

/// New official message (`/official/new`): title, plain-text body, optional
/// acknowledgement requirement and recipients — the whole organization
/// (`official.send.organization`), departments (`official.send.department`)
/// and/or specific colleagues (either permission). The server sends to the
/// union of the chosen sets.
class OfficialComposeScreen extends ConsumerStatefulWidget {
  const OfficialComposeScreen({super.key});

  @override
  ConsumerState<OfficialComposeScreen> createState() =>
      _OfficialComposeScreenState();
}

class _OfficialComposeScreenState extends ConsumerState<OfficialComposeScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _requiresAck = false;
  bool _wholeOrganization = false;
  final Map<String, Department> _departments = {};
  final Map<String, Contact> _users = {};
  bool _sending = false;
  bool _showErrors = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  OfficialDraft get _draft => OfficialDraft(
    title: _title.text,
    body: _body.text,
    requiresAcknowledgement: _requiresAck,
    wholeOrganization: _wholeOrganization,
    departmentIds: _departments.keys.toList(),
    userIds: _users.keys.toList(),
  );

  Future<void> _send() async {
    final l10n = context.l10n;
    final draft = _draft;
    if (!draft.hasContent || !draft.hasRecipients) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final created = await ref.read(officialRepositoryProvider).create(draft);
      ref.invalidate(officialSentProvider);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.officialSentToast(created.recipientCount))),
      );
      unawaited(
        router.pushReplacement(
          Routes.officialStatsPath(created.id),
          extra: SentOfficial(
            id: created.id,
            title: draft.title.trim(),
            recipientCount: created.recipientCount,
            requiresAcknowledgement: draft.requiresAcknowledgement,
          ),
        ),
      );
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(
        SnackBar(content: Text(officialErrorText(l10n, e))),
      );
    }
  }

  Future<void> _pickDepartments() async {
    final picked = await showAppSheet<Map<String, Department>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DepartmentPicker(initial: _departments),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _departments
        ..clear()
        ..addAll(picked);
    });
  }

  Future<void> _pickUser() async {
    final picked = await showAppSheet<Contact>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _UserPicker(exclude: _users.keys.toSet()),
    );
    if (picked == null || !mounted) return;
    setState(() => _users[picked.id] = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final rights = ref.watch(officialSendRightsProvider);

    if (!rights.any) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.officialComposeTitle)),
        body: StateView.empty(
          title: l10n.officialErrForbidden,
          icon: LucideIcons.lock,
        ),
      );
    }

    final draft = _draft;
    Widget header(String text) => Padding(
      padding: const EdgeInsets.only(top: Space.md, bottom: Space.xs),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.officialComposeTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Space.sm),
            child: FilledButton.icon(
              key: const Key('official_send'),
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.send, size: 18),
              label: Text(l10n.officialSend),
            ),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _sending,
        child: ListView(
          padding: const EdgeInsets.all(Space.md),
          children: [
            TextField(
              key: const Key('official_title_field'),
              controller: _title,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.officialFieldTitle,
                errorText: _showErrors && draft.title.trim().isEmpty
                    ? l10n.officialTitleRequired
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Space.sm),
            TextField(
              key: const Key('official_body_field'),
              controller: _body,
              minLines: 6,
              maxLines: 16,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.officialFieldBody,
                alignLabelWithHint: true,
                errorText: _showErrors && draft.body.trim().isEmpty
                    ? l10n.officialBodyRequired
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            SwitchListTile(
              key: const Key('official_require_ack'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.officialRequireAck),
              subtitle: Text(l10n.officialRequireAckHint),
              value: _requiresAck,
              onChanged: (v) => setState(() => _requiresAck = v),
            ),
            header(l10n.officialRecipients),
            if (rights.organization)
              SwitchListTile(
                key: const Key('official_whole_org'),
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(LucideIcons.building2),
                title: Text(l10n.officialRecipientsOrganization),
                value: _wholeOrganization,
                onChanged: (v) => setState(() => _wholeOrganization = v),
              ),
            if (!_wholeOrganization) ...[
              if (rights.department) ...[
                ListTile(
                  key: const Key('official_pick_departments'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(LucideIcons.network),
                  title: Text(l10n.officialRecipientsDepartments),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: _pickDepartments,
                ),
                if (_departments.isNotEmpty)
                  Wrap(
                    spacing: Space.xs,
                    runSpacing: Space.xs,
                    children: [
                      for (final d in _departments.values)
                        InputChip(
                          key: ValueKey('official_dept_${d.id}'),
                          label: Text(d.name),
                          onDeleted: () =>
                              setState(() => _departments.remove(d.id)),
                        ),
                    ],
                  ),
              ],
              ListTile(
                key: const Key('official_pick_users'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.userPlus),
                title: Text(l10n.officialRecipientsUsers),
                trailing: const Icon(LucideIcons.plus),
                onTap: _pickUser,
              ),
              if (_users.isNotEmpty)
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  children: [
                    for (final u in _users.values)
                      InputChip(
                        key: ValueKey('official_user_${u.id}'),
                        label: Text(u.label),
                        onDeleted: () => setState(() => _users.remove(u.id)),
                      ),
                  ],
                ),
            ],
            if (_showErrors && !draft.hasRecipients)
              Padding(
                padding: const EdgeInsets.only(top: Space.sm),
                child: Text(
                  l10n.officialRecipientsRequired,
                  key: const Key('official_recipients_error'),
                  style: theme.textTheme.bodySmall?.copyWith(color: t.danger),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DepartmentPicker extends ConsumerStatefulWidget {
  const _DepartmentPicker({required this.initial});
  final Map<String, Department> initial;

  @override
  ConsumerState<_DepartmentPicker> createState() => _DepartmentPickerState();
}

class _DepartmentPickerState extends ConsumerState<_DepartmentPicker> {
  late final Map<String, Department> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(officialDepartmentsProvider);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.officialRecipientsDepartments,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  FilledButton(
                    key: const Key('official_departments_done'),
                    onPressed: () => Navigator.pop(context, _selected),
                    child: Text(l10n.officialSelectedDone(_selected.length)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const StateView.loading(),
                error: (e, _) => StateView.error(
                  message: officialErrorText(l10n, e),
                  onRetry: () => ref.invalidate(officialDepartmentsProvider),
                ),
                data: (list) => list.isEmpty
                    ? StateView.empty(
                        title: l10n.officialNoDepartments,
                        icon: LucideIcons.network,
                      )
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final d = list[i];
                          return CheckboxListTile(
                            key: ValueKey('official_pick_dept_${d.id}'),
                            value: _selected.containsKey(d.id),
                            title: Text(d.name),
                            subtitle: d.employeeCount > 0
                                ? Text(
                                    l10n.officialRecipientCount(
                                      d.employeeCount,
                                    ),
                                  )
                                : null,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selected[d.id] = d;
                              } else {
                                _selected.remove(d.id);
                              }
                            }),
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

class _UserPicker extends ConsumerStatefulWidget {
  const _UserPicker({required this.exclude});
  final Set<String> exclude;

  @override
  ConsumerState<_UserPicker> createState() => _UserPickerState();
}

class _UserPickerState extends ConsumerState<_UserPicker> {
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
    final results = ref.watch(officialUserSearchProvider(_query));
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                0,
                Space.md,
                Space.sm,
              ),
              child: TextField(
                key: const Key('official_user_search'),
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.officialSearchUsers,
                  prefixIcon: const Icon(LucideIcons.search),
                ),
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
                loading: () => const StateView.loading(),
                error: (e, _) =>
                    StateView.error(message: officialErrorText(l10n, e)),
                data: (users) {
                  final visible = users
                      .where((u) => !widget.exclude.contains(u.id))
                      .toList();
                  if (visible.isEmpty) {
                    return StateView.empty(
                      title: l10n.officialNoUsers,
                      icon: LucideIcons.userX,
                    );
                  }
                  return ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (_, i) {
                      final u = visible[i];
                      return ListTile(
                        key: ValueKey('official_pick_user_${u.id}'),
                        title: Text(u.label),
                        subtitle: Text(
                          [
                            u.department,
                            u.email,
                          ].where((s) => s.isNotEmpty).join(' · '),
                        ),
                        onTap: () => Navigator.pop(context, u),
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
