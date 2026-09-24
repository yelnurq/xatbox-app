import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/utils/diagnostic_log.dart';
import '../../../../shared/utils/error_text.dart';
import '../../../../shared/widgets/state_view.dart';
import '../../data/mail_settings_models.dart';
import '../mail_error_text.dart';
import '../mail_providers.dart';

/// `GET/PUT /mail/signature`.
class SignatureSettingsScreen extends ConsumerStatefulWidget {
  const SignatureSettingsScreen({super.key});

  @override
  ConsumerState<SignatureSettingsScreen> createState() =>
      _SignatureSettingsScreenState();
}

class _SignatureSettingsScreenState
    extends ConsumerState<SignatureSettingsScreen> {
  final _text = TextEditingController();
  MailPersonalSignature? _signature;
  MailSignaturePreview? _preview;
  Object? _loadError;
  bool _loading = true;
  bool _saving = false;

  /// Server-side failure, shown above the form.
  String? _error;

  /// A save was attempted over the byte limit; shown on the field itself,
  /// next to the caret, until the text fits again.
  bool _limitError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final api = ref.read(mailApiProvider);
    try {
      final signature = await api.signature();
      if (!mounted) return;
      setState(() {
        _signature = signature;
        _text.text = signature.text;
        _loading = false;
      });
      await _loadPreview();
    } on AppException catch (e) {
      DiagnosticLog.warn('mail', 'signature load failed', error: e);
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadPreview() async {
    try {
      final preview = await ref.read(mailApiProvider).signaturePreview();
      if (mounted) setState(() => _preview = preview);
    } on AppException catch (e) {
      DiagnosticLog.warn('mail', 'signature preview failed', error: e);
    }
  }

  int get _bytes => utf8.encode(_text.text.trim()).length;
  bool get _overLimit => _bytes > MailPersonalSignature.maxBytes;

  Future<void> _save({bool restoreDefault = false}) async {
    if (_saving) return;
    final l10n = context.l10n;
    if (!restoreDefault && _overLimit) {
      setState(() => _limitError = true);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _limitError = false;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await ref
          .read(mailApiProvider)
          .updateSignature(restoreDefault ? '' : _text.text.trim());
      if (!mounted) return;
      setState(() {
        _signature = saved;
        _text.text = saved.text;
      });
      ref.invalidate(mailSignaturePreviewProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.mailSettingsSaved)));
      await _loadPreview();
    } on AppException catch (e) {
      DiagnosticLog.warn('mail', 'signature save failed', error: e);
      if (!mounted) return;
      setState(() => _error = MailErrorText.describe(l10n, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final signature = _signature;
    final muted = theme.textTheme.bodySmall?.copyWith(color: tokens.textMuted);

    Widget body;
    if (_loading && signature == null) {
      body = const StateView.loading();
    } else if (signature == null) {
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
      final preview = _preview;
      body = ListView(
        padding: const EdgeInsets.all(Space.md),
        children: [
          if (_error != null) ...[
            ErrorMessage(_error!),
            const SizedBox(height: Space.md),
          ],
          if (signature.isDefault) ...[
            Text(l10n.mailSignatureDefaultNote, style: muted),
            const SizedBox(height: Space.sm),
          ],
          TextField(
            key: const Key('signature_text'),
            controller: _text,
            enabled: !_saving,
            minLines: 4,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              labelText: l10n.mailSignatureLabel,
              alignLabelWithHint: true,
              helperText: l10n.mailSignatureBytes(
                _bytes,
                MailPersonalSignature.maxBytes,
              ),
              helperStyle: _overLimit ? TextStyle(color: tokens.danger) : null,
              errorText: _limitError && _overLimit
                  ? l10n.mailSignatureTooLong
                  : null,
            ),
            onChanged: (_) => setState(() {
              if (!_overLimit) _limitError = false;
            }),
          ),
          if (preview != null &&
              !preview.personal &&
              _text.text.trim().isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Text(l10n.mailSignatureNotApplied, style: muted),
          ],
          if (!signature.isDefault) ...[
            const SizedBox(height: Space.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('signature_restore'),
                onPressed: _saving ? null : () => _save(restoreDefault: true),
                icon: const Icon(LucideIcons.rotateCcw),
                label: Text(l10n.mailSignatureRestoreDefault),
              ),
            ),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mailSettingsSignature),
        // In the app bar so it stays reachable above a long signature.
        actions: [
          if (signature != null)
            TextButton(
              key: const Key('signature_save'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.save),
            ),
        ],
      ),
      body: body,
    );
  }
}
