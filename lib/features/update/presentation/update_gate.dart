import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/localization/localization.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/brand_logo.dart';
import 'update_controller.dart';
import 'update_sheet.dart';
import 'update_widgets.dart';

/// Above the router (MaterialApp.builder, under the app lock): checks for
/// updates once signed in and on resume (throttled by the controller),
/// offers an optional update in a sheet and blocks the app with
/// [MandatoryUpdateScreen] while the installed build is below the server's
/// minimum. Sign-out stays possible.
class UpdateGate extends ConsumerStatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate> {
  late final AppLifecycleListener _lifecycle;
  late final AuthSession _session;
  bool _wasSignedIn = false;
  bool _prompting = false;

  @override
  void initState() {
    super.initState();
    _session = ref.read(authSessionProvider);
    _session.addListener(_onSession);
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSession());
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    _lifecycle.dispose();
    super.dispose();
  }

  void _onSession() {
    final signedIn = _session.isAuthenticated;
    if (signedIn && !_wasSignedIn) unawaited(_check());
    _wasSignedIn = signedIn;
  }

  void _onResume() {
    if (!mounted) return;
    final c = ref.read(updateControllerProvider.notifier);
    unawaited(c.onResume());
    if (_session.isAuthenticated) unawaited(_check());
  }

  Future<void> _check() async {
    final c = ref.read(updateControllerProvider.notifier);
    final fresh = await c.checkIfDue();
    if (!mounted || !fresh || _prompting || !await c.shouldPrompt()) return;
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null || !navContext.mounted || !_session.isAuthenticated) return;
    _prompting = true;
    try {
      await showUpdateSheet(navContext);
    } finally {
      _prompting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mandatory = ref.watch(updateControllerProvider.select((s) => s.mandatory));
    final session = ref.watch(authSessionProvider);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final block = mandatory && session.isAuthenticated;
        return Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                excluding: block,
                child: TickerMode(enabled: !block, child: widget.child),
              ),
            ),
            if (block) const Positioned.fill(child: MandatoryUpdateScreen()),
          ],
        );
      },
    );
  }
}

/// Friendly full-screen block for an unsupported build.
class MandatoryUpdateScreen extends ConsumerStatefulWidget {
  const MandatoryUpdateScreen({super.key});

  @override
  ConsumerState<MandatoryUpdateScreen> createState() => _MandatoryUpdateScreenState();
}

class _MandatoryUpdateScreenState extends ConsumerState<MandatoryUpdateScreen> {
  bool _signingOut = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final s = ref.watch(updateControllerProvider);
    final release = s.release;
    return Material(
      key: const Key('mandatory_update'),
      color: t.appBg,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(Space.lg),
              children: [
                const Center(child: BrandMark(size: 40)),
                const SizedBox(height: Space.xl),
                Center(
                  child: UpdateHeroIcon(icon: LucideIcons.rocket, size: 88, tone: t.primary),
                ),
                const SizedBox(height: Space.lg),
                Text(l10n.updateMandatoryTitle, style: text.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: Space.sm),
                Text(
                  l10n.updateMandatoryBody,
                  style: text.bodyMedium?.copyWith(color: t.textSecondary, height: 1.45),
                  textAlign: TextAlign.center,
                ),
                if (release != null) ...[
                  const SizedBox(height: Space.md),
                  ReleaseFacts(release: release),
                  const SizedBox(height: Space.md),
                  ReleaseNotesCard(release: release, maxHeight: 180),
                ],
                const SizedBox(height: Space.lg),
                if (s.phase == UpdatePhase.checking && release == null)
                  const Center(child: CircularProgressIndicator())
                else
                  const UpdateActionPanel(),
                const SizedBox(height: Space.md),
                Center(
                  child: TextButton.icon(
                    key: const Key('mandatory_sign_out'),
                    style: TextButton.styleFrom(foregroundColor: t.textSecondary),
                    onPressed: _signingOut
                        ? null
                        : () async {
                            setState(() => _signingOut = true);
                            await ref.read(authSessionProvider).logout();
                            if (mounted) setState(() => _signingOut = false);
                          },
                    icon: const Icon(LucideIcons.logOut, size: 16),
                    label: Text(l10n.updateSignOut),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
