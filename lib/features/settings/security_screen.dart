import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/localization/localization.dart';
import '../../core/platform/desktop_layout.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/tokens.dart';
import '../../shared/utils/error_text.dart';
import '../../shared/widgets/state_view.dart';

/// The web settings "Security" section: change password (`POST /me/password`,
/// new password ≥ 10 characters) and the way to the sessions list.
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  static const minLength = 10;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _mismatch => _confirm.text.isNotEmpty && _next.text != _confirm.text;
  bool get _canSubmit => !_busy && _current.text.isNotEmpty && _next.text.length >= minLength && !_mismatch;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authApiProvider).changePassword(current: _current.text, next: _next.text);
      _current.clear();
      _next.clear();
      _confirm.clear();
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsPasswordChanged)));
    } on AppException catch (e) {
      if (mounted) setState(() => _error = ErrorText.describe(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    Widget label(String s) => Padding(padding: const EdgeInsets.only(bottom: 6, top: Space.md), child: Text(s, style: text.labelMedium));
    // Desktop: the panels sit on the settings page itself (the section
    // list names the page), not inside a second panel.
    final desktop = ref.watch(desktopLayoutProvider);
    return Scaffold(
      backgroundColor: desktop ? Colors.transparent : null,
      appBar: desktop ? null : AppBar(title: Text(l10n.settingsSecuritySection)),
      body: ListView(
        padding: desktop ? const EdgeInsets.only(bottom: Space.md) : const EdgeInsets.all(Space.md),
        children: [
          _Panel(
            title: l10n.settingsSecurityChangePassword,
            hint: l10n.settingsSecurityChangePasswordHint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label(l10n.settingsCurrentPassword),
                TextField(
                  key: const Key('password_current'),
                  controller: _current,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  onChanged: (_) => setState(() {}),
                ),
                label(l10n.settingsNewPassword),
                TextField(
                  key: const Key('password_new'),
                  controller: _next,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    errorText: _next.text.isNotEmpty && _next.text.length < minLength ? l10n.settingsPasswordTooShort : null,
                  ),
                ),
                label(l10n.settingsRepeatPassword),
                TextField(
                  key: const Key('password_confirm'),
                  controller: _confirm,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(errorText: _mismatch ? l10n.settingsPasswordsMismatch : null),
                ),
                if (_error != null) ...[const SizedBox(height: Space.md), ErrorMessage(_error!)],
                const SizedBox(height: Space.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _busy || (_current.text.isEmpty && _next.text.isEmpty && _confirm.text.isEmpty)
                          ? null
                          : () => setState(() {
                              _current.clear();
                              _next.clear();
                              _confirm.clear();
                              _error = null;
                            }),
                      child: Text(l10n.cancel),
                    ),
                    const SizedBox(width: Space.sm),
                    FilledButton(
                      key: const Key('password_submit'),
                      onPressed: _canSubmit ? _submit : null,
                      child: _busy
                          ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: t.textInverse))
                          : Text(l10n.settingsSecurityChangePassword),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          _Panel(
            title: l10n.profileSessions,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.monitorSmartphone),
              title: Text(l10n.profileSessions),
              trailing: const Icon(LucideIcons.chevronRight, size: 16),
              onTap: () => context.push(Routes.settingsSessions),
            ),
          ),
        ],
      ),
    );
  }
}

/// `xatbox-panel` with the settings `Section` header: title (+ hint) on the
/// subtle surface, a hairline, the content.
class _Panel extends StatelessWidget {
  const _Panel({required this.title, this.hint, required this.child});
  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(t.radiusLg),
        border: Border.all(color: t.border, width: t.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.mlg, vertical: Space.smd),
            decoration: BoxDecoration(
              color: t.surfaceSubtle,
              border: Border(bottom: BorderSide(color: t.border, width: t.borderWidth)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                if (hint != null) Text(hint!, style: text.labelSmall),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(Space.mlg), child: child),
        ],
      ),
    );
  }
}
