import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/auth_session.dart';
import '../../core/localization/localization.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/brand_logo.dart';

/// Logo → check secure storage → `GET /me` → main screen or login
/// (ТЗ п.24.3). Navigation itself is done by the router redirect.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    final session = ref.read(authSessionProvider);
    if (session.status == AuthStatus.unknown) {
      Future.microtask(session.restore);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final status = ref.watch(authStateProvider).status;
    final session = ref.read(authSessionProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const XatBoxLogo(size: 96),
                const SizedBox(height: Space.lg),
                if (status == AuthStatus.unreachable) ...[
                  Text(
                    l10n.splashUnreachableTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    l10n.splashUnreachableBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tokens.textMuted),
                  ),
                  const SizedBox(height: Space.md),
                  FilledButton(
                    onPressed: session.retryRestore,
                    child: Text(l10n.retry),
                  ),
                  TextButton(
                    onPressed: session.discardStoredSession,
                    child: Text(l10n.splashSignInAgain),
                  ),
                ] else ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: Space.md),
                  Text(
                    l10n.splashChecking,
                    style: TextStyle(color: tokens.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Xatbox lockup (the web `BrandLogo` + `BrandName`): the mark in the
/// skin's mark colour above the wordmark in the surface ink.
class XatBoxLogo extends StatelessWidget {
  const XatBoxLogo({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: size),
        const SizedBox(height: Space.smd),
        BrandName(size: size * 0.34),
      ],
    );
  }}
