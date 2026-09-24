import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../localization/localization.dart';
import '../theme/tokens.dart';
import 'device_permissions.dart';
import '../../shared/widgets/app_sheet.dart';

/// Once per app run, shortly after the signed-in shell appears, explains and
/// asks for the grants that are still missing (notifications, full-screen
/// incoming calls). Each explainer is shown at most once per device; the
/// rows in Settings → Уведомления stay for later changes.
class PermissionOnboardingHost extends ConsumerStatefulWidget {
  const PermissionOnboardingHost({
    super.key,
    required this.callsEnabled,
    required this.child,
    this.delay = const Duration(milliseconds: 1200),
  });

  final bool callsEnabled;
  final Widget child;

  /// Lets the first screen settle (and a share or deep link open) first.
  final Duration delay;

  @override
  ConsumerState<PermissionOnboardingHost> createState() => _PermissionOnboardingHostState();
}

class _PermissionOnboardingHostState extends ConsumerState<PermissionOnboardingHost> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final permissions = ref.read(devicePermissionsProvider);
    // Nothing to ask (iOS, tests): no timer at all.
    if (!permissions.supported || ref.read(permissionOnboardingStartedProvider)) return;
    _timer = Timer(widget.delay, _run);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    if (!mounted || ref.read(permissionOnboardingStartedProvider)) return;
    ref.read(permissionOnboardingStartedProvider.notifier).start();
    await runPermissionOnboarding(
      permissions: ref.read(devicePermissionsProvider),
      store: ref.read(permissionPromptStoreProvider),
      callsEnabled: widget.callsEnabled,
      stillWanted: () => mounted,
      explain: (prompt) async => mounted && await showPermissionExplainer(context, prompt),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Started once per process (provider-scoped, so each test container starts clean).
final permissionOnboardingStartedProvider =
    NotifierProvider<_OnboardingStarted, bool>(_OnboardingStarted.new);

class _OnboardingStarted extends Notifier<bool> {
  @override
  bool build() => false;
  void start() => state = true;
}

/// The explainer sheet; true when the user taps «Разрешить».
Future<bool> showPermissionExplainer(BuildContext context, PermissionPrompt prompt) async {
  final l10n = context.l10n;
  final (icon, title, body, action) = switch (prompt) {
    PermissionPrompt.notifications => (
      LucideIcons.bellRing,
      l10n.permOnboardNotifTitle,
      l10n.permOnboardNotifBody,
      l10n.permAllow,
    ),
    PermissionPrompt.fullScreenIntent => (
      LucideIcons.phoneIncoming,
      l10n.permOnboardFsiTitle,
      l10n.permOnboardFsiBody,
      l10n.permOpenSettings,
    ),
  };
  final agreed = await showAppSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.md),
        child: Column(
          key: Key('permission_explainer_${prompt.name}'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: Space.md),
            Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            ),
            const SizedBox(height: Space.sm),
            Text(body, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: Space.lg),
            FilledButton(
              key: const Key('permission_explainer_allow'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(action),
            ),
            const SizedBox(height: Space.xs),
            TextButton(
              key: const Key('permission_explainer_later'),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.permNotNow),
            ),
          ],
        ),
      ),
    ),
  );
  return agreed == true;
}
