import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/auth/auth_session.dart';
import '../../core/localization/localization.dart';
import '../../core/theme/tokens.dart';
import '../../shared/utils/email_address.dart';
import '../../shared/utils/error_text.dart';
import '../../shared/widgets/brand_logo.dart';
import '../../shared/widgets/state_view.dart';
import 'login_ornament.dart';

/// Email + password sign-in against `POST /auth/login`, drawn like the web
/// login: the brand lockup on the full-bleed login field (`--login-field` /
/// `--login-ink` of the skin), the "paper" card centred on it with labelled
/// fields, the error box and the primary button.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authSessionProvider).login(email: _email.text, password: _password.text);
      // Navigation happens through the router redirect on session change.
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _error = ErrorText.describe(context.l10n, e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final session = ref.watch(authSessionProvider);
    final expired = session.signOutReason == SignOutReason.sessionExpired;
    final ink = t.loginInk;

    return Scaffold(
      backgroundColor: t.loginField,
      body: Stack(
        children: [
          Positioned.fill(child: LoginOrnament(color: ink)),
          SafeArea(
        child: Column(
          children: [
            // Header: mark + wordmark + "MAIL" eyebrow, in the field's ink.
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.mlg, vertical: Space.smd),
                child: Row(
                  children: [
                    BrandMark(size: 44, color: ink),
                    const SizedBox(width: Space.smd),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BrandName(color: ink, size: 20),
                        const SizedBox(height: 2),
                        Text(
                          l10n.sectionMail.toUpperCase(),
                          style: theme.textTheme.labelSmall!.copyWith(color: ink.withValues(alpha: 0.7), letterSpacing: 2.2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: Space.mlg, vertical: Space.md),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    // The paper.
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(t.radiusXl),
                        border: Border.all(color: ink.withValues(alpha: 0.25), width: t.borderWidth),
                        boxShadow: t.shadowMd,
                      ),
                      padding: EdgeInsets.all(context.isCompact ? Space.lg : Space.xl),
                      child: Form(
                        key: _formKey,
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                l10n.loginTitle,
                                style: theme.textTheme.headlineMedium!.copyWith(fontSize: 26 * t.display.scale, height: 32 / 26, letterSpacing: -0.3),
                              ),
                              const SizedBox(height: Space.sm),
                              Text(l10n.loginSubtitle, style: theme.textTheme.bodyLarge!.copyWith(color: t.textSecondary)),
                              const SizedBox(height: Space.lg),
                              if (expired && _error == null) ...[
                                ErrorMessage(l10n.sessionExpiredBanner),
                                const SizedBox(height: Space.md),
                              ],
                              _FieldLabel(l10n.loginEmail),
                              TextFormField(
                                controller: _email,
                                key: const Key('login_email'),
                                enabled: !_submitting,
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                autofocus: true,
                                autofillHints: const [AutofillHints.username, AutofillHints.email],
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(hintText: 'name@company.kz', prefixIcon: Icon(LucideIcons.atSign, size: 16)),
                                validator: (v) {
                                  final value = (v ?? '').trim();
                                  if (value.isEmpty) return l10n.loginEmailRequired;
                                  if (!EmailAddress.isBare(value)) return l10n.loginEmailInvalid;
                                  return null;
                                },
                              ),
                              const SizedBox(height: Space.mlg),
                              _FieldLabel(l10n.loginPassword),
                              TextFormField(
                                controller: _password,
                                key: const Key('login_password'),
                                enabled: !_submitting,
                                obscureText: _obscure,
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(LucideIcons.lock, size: 16),
                                  suffixIcon: IconButton(
                                    tooltip: _obscure ? l10n.loginShowPassword : l10n.loginHidePassword,
                                    icon: Icon(_obscure ? LucideIcons.eye : LucideIcons.eyeOff, size: 16),
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                validator: (v) => (v ?? '').isEmpty ? l10n.loginPasswordRequired : null,
                              ),
                              const SizedBox(height: Space.mlg),
                              if (_error != null) ...[
                                ErrorMessage(_error!),
                                const SizedBox(height: Space.md),
                              ],
                              FilledButton(
                                key: const Key('login_submit'),
                                onPressed: _submitting ? null : _submit,
                                style: FilledButton.styleFrom(minimumSize: const Size(0, Space.controlLg)),
                                child: _submitting
                                    ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: t.textInverse))
                                    : Text(l10n.loginButton),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
        ],
      ),
    );
  }
}

/// Label above a field (DESIGN.MD: labels sit above inputs, never float).
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: Theme.of(context).textTheme.labelMedium),
  );
}
