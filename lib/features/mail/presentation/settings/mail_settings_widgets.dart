import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/state_view.dart';
import '../../data/mail_settings_models.dart';

/// "Applying on the mail server" / "not accepted" line for block list and
/// out-of-office changes; nothing when synced.
class MailSyncNotice extends StatelessWidget {
  const MailSyncNotice(this.sync, {super.key});
  final MailSyncState sync;

  @override
  Widget build(BuildContext context) {
    if (!sync.isPending && !sync.isFailed) return const SizedBox.shrink();
    final l10n = context.l10n;
    final tokens = context.tokens;
    final color = sync.isFailed ? tokens.danger : tokens.textMuted;
    return Padding(
      key: const Key('mail_sync_notice'),
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          Icon(
            sync.isFailed ? LucideIcons.refreshCwOff : LucideIcons.refreshCw,
            size: 16,
            color: color,
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              sync.isFailed ? l10n.mailSyncFailed : l10n.mailSyncPending,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class MailFormFieldSpec {
  const MailFormFieldSpec({
    required this.key,
    required this.label,
    this.hint,
    this.initial = '',
    this.keyboardType,
  });

  final String key;
  final String label;
  final String? hint;
  final String initial;
  final TextInputType? keyboardType;
}

/// Small form dialog that runs the request itself, so server errors are
/// shown next to the fields. Pops `true` on success.
class MailFormDialog extends StatefulWidget {
  const MailFormDialog({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.fields,
    required this.onSubmit,
    this.validate,
  });

  final String title;
  final String submitLabel;
  final List<MailFormFieldSpec> fields;

  /// Client-side check; returns error text or null.
  final String? Function(List<String> values)? validate;

  /// Performs the request; returns error text or null on success.
  final Future<String?> Function(List<String> values) onSubmit;

  @override
  State<MailFormDialog> createState() => _MailFormDialogState();
}

class _MailFormDialogState extends State<MailFormDialog> {
  late final List<TextEditingController> _controllers = [
    for (final f in widget.fields) TextEditingController(text: f.initial),
  ];
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final values = [for (final c in _controllers) c.text];
    final invalid = widget.validate?.call(values);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onSubmit(values);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              ErrorMessage(_error!),
              const SizedBox(height: Space.sm),
            ],
            for (var i = 0; i < widget.fields.length; i++) ...[
              TextField(
                key: Key(widget.fields[i].key),
                controller: _controllers[i],
                enabled: !_busy,
                autofocus: i == 0,
                keyboardType: widget.fields[i].keyboardType,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: widget.fields[i].label,
                  hintText: widget.fields[i].hint,
                ),
                onSubmitted: i == widget.fields.length - 1
                    ? (_) => _submit()
                    : null,
              ),
              const SizedBox(height: Space.sm),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('mail_form_submit'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.submitLabel),
        ),
      ],
    );
  }
}

Future<bool> confirmMailAction(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? body,
  bool destructive = false,
}) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('mail_confirm'),
          onPressed: () => Navigator.pop(ctx, true),
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: ctx.tokens.danger)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}
