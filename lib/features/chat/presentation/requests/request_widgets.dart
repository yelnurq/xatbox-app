import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../../data/chat_models.dart';
import '../chat_formatters.dart';
import '../chat_providers.dart';

/// «Заявки» (desktop only for now): the request card, the bot's answer and
/// the form that replaces the composer (chat-service migration 0016).

String requestStatusLabel(AppLocalizations l10n, String status) => switch (status) {
  'in_progress' => l10n.requestsStatusInProgress,
  'done' => l10n.requestsStatusDone,
  'rejected' => l10n.requestsStatusRejected,
  _ => l10n.requestsStatusNew,
};

/// The newest state of every request among [messages]: each bot answer
/// carries the request as it was then, so the last one wins.
Map<String, ChatRequest> latestRequests(Iterable<ChatMessage> messages) {
  final out = <String, ChatRequest>{};
  final at = <String, DateTime>{};
  for (final m in messages) {
    final r = m.request;
    if (r == null || r.id.isEmpty) continue;
    final when = r.updatedAt ?? m.createdAt;
    final seen = at[r.id];
    if (seen == null || !when.isBefore(seen)) {
      out[r.id] = r;
      at[r.id] = when;
    }
  }
  return out;
}

class RequestStatusChip extends StatelessWidget {
  const RequestStatusChip({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (bg, fg) = switch (status) {
      'in_progress' => (t.infoSoft, t.info),
      'done' => (t.successSoft, t.success),
      'rejected' => (t.dangerSoft, t.danger),
      _ => (t.warningSoft, t.warning),
    };
    return Container(
      key: ValueKey('request_status_$status'),
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xxs),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(t.radiusSm)),
      child: Text(
        requestStatusLabel(context.l10n, status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// A filed request inside the user's bubble: number, status and the form.
class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.request});
  final ChatRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final label = theme.textTheme.labelSmall?.copyWith(color: t.textSecondary);
    Widget field(String name, String value) => Padding(
      padding: const EdgeInsets.only(top: Space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: label),
          SelectableText(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: Column(
        key: ValueKey('request_card_${request.id}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(LucideIcons.clipboardList, size: 16, color: t.textSecondary),
              Text(
                l10n.requestsNumber(request.number),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              RequestStatusChip(status: request.status),
            ],
          ),
          field(l10n.requestsWhat, request.what),
          field(l10n.requestsRoom, request.room),
          field(l10n.requestsDate, request.dateLabel),
        ],
      ),
    );
  }
}

/// The bot's answer: «Заявка №N» with the status it set, then the comment.
class RequestUpdateView extends StatelessWidget {
  const RequestUpdateView({super.key, required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final r = message.request!;
    // The body is «Заявка №N[: Статус]\n<comment>»: the first line becomes
    // the header, the rest is what the service wrote.
    final nl = message.body.indexOf('\n');
    final text = nl < 0 ? '' : message.body.substring(nl + 1).trim();
    return Column(
      key: ValueKey('request_update_${message.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              l10n.requestsNumber(r.number),
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            RequestStatusChip(status: r.status),
          ],
        ),
        if (text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: SelectableText(text, style: theme.textTheme.bodyMedium),
          ),
      ],
    );
  }
}

/// The form under the «Заявки» chat, in place of the composer: what
/// happened, the room and the date (today by default).
class RequestForm extends ConsumerStatefulWidget {
  const RequestForm({super.key});

  @override
  ConsumerState<RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends ConsumerState<RequestForm> {
  final _what = TextEditingController();
  final _room = TextEditingController();
  final _whatFocus = FocusNode();
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  bool _busy = false;
  bool _showErrors = false;

  @override
  void dispose() {
    _what.dispose();
    _room.dispose();
    _whatFocus.dispose();
    super.dispose();
  }

  String get _dateIso {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${_date.year}-${two(_date.month)}-${two(_date.day)}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null && mounted) setState(() => _date = DateUtils.dateOnly(picked));
  }

  Future<void> _submit() async {
    if (_busy) return;
    final what = _what.text.trim();
    final room = _room.text.trim();
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (what.isEmpty || room.isEmpty) {
      // The fields say what is missing (a snack bar would cover the button).
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(chatRepositoryProvider).submitRequest(what: what, room: room, date: _dateIso);
      if (!mounted) return;
      setState(() {
        _what.clear();
        _room.clear();
        _date = DateUtils.dateOnly(DateTime.now());
        _showErrors = false;
      });
      _whatFocus.requestFocus();
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ChatFormat.error(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final loc = MaterialLocalizations.of(context);
    String? missing(TextEditingController c) =>
        _showErrors && c.text.trim().isEmpty ? l10n.requestsFillAll : null;
    return Padding(
      key: const Key('request_form'),
      padding: const EdgeInsets.fromLTRB(Space.md, Space.smd, Space.md, Space.md),
      child: CallbackShortcuts(
        // Ctrl+Enter sends from any field, like the web forms.
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, control: true): _submit,
          const SingleActivator(LogicalKeyboardKey.enter, meta: true): _submit,
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('request_what'),
              controller: _what,
              focusNode: _whatFocus,
              enabled: !_busy,
              minLines: 2,
              maxLines: 5,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => _showErrors ? setState(() {}) : null,
              decoration: InputDecoration(
                labelText: l10n.requestsWhat,
                hintText: l10n.requestsWhatHint,
                errorText: missing(_what),
                counterText: '',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: Space.smd),
            // Wide (desktop): room, date and the button in one row. Narrow
            // (phone): room and date side by side, the button full width.
            LayoutBuilder(
              builder: (context, box) {
                final room = TextField(
                  key: const Key('request_room'),
                  controller: _room,
                  enabled: !_busy,
                  maxLength: 100,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  onChanged: (_) => _showErrors ? setState(() {}) : null,
                  decoration: InputDecoration(
                    labelText: l10n.requestsRoom,
                    hintText: l10n.requestsRoomHint,
                    errorText: missing(_room),
                    counterText: '',
                  ),
                );
                final date = InkWell(
                  key: const Key('request_date'),
                  onTap: _busy ? null : _pickDate,
                  borderRadius: BorderRadius.circular(t.radiusSm),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.requestsDate,
                      suffixIcon: const Icon(LucideIcons.calendar, size: 18),
                    ),
                    child: Text(loc.formatMediumDate(_date), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                );
                final submit = FilledButton.icon(
                  key: const Key('request_submit'),
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(LucideIcons.send, size: 18),
                  label: Text(l10n.requestsSubmit),
                );
                if (box.maxWidth >= 600) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 200, child: room),
                      const SizedBox(width: Space.smd),
                      SizedBox(width: 200, child: date),
                      const Spacer(),
                      Padding(padding: const EdgeInsets.only(top: Space.xs), child: submit),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: room),
                        const SizedBox(width: Space.smd),
                        Expanded(child: date),
                      ],
                    ),
                    const SizedBox(height: Space.smd),
                    SizedBox(height: 48, child: submit),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
