import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/localization/localization.dart';
import '../../core/theme/tokens.dart';
import '../../shared/models/profile_session.dart';
import '../../shared/utils/error_text.dart';
import '../../shared/widgets/ds/x_badge.dart';
import '../../shared/widgets/state_view.dart';
import '../../shared/widgets/app_sheet.dart';

/// `GET /me/sessions` of the Mail API: every signed-in device, current first.
final mySessionsProvider = FutureProvider.autoDispose<List<ProfileSession>>(
  (ref) => ref.watch(authApiProvider).sessions(),
);

/// How a session is shown: the app's own User-Agent has no browser, so an
/// Android/iOS session without one is «Приложение XatBox».
extension SessionPresentation on ProfileSession {
  bool get isXatBoxApp => browser.isEmpty && (os == 'Android' || os == 'iOS' || os == 'iPadOS');

  String title(AppLocalizations l10n) {
    if (isXatBoxApp) return l10n.sessionsXatBoxApp;
    if (browser.isEmpty && os.isEmpty) return l10n.sessionsUnknownDevice;
    return browser.isEmpty ? os : browser;
  }

  String? platformLabel() => os.isEmpty || browser.isEmpty && !isXatBoxApp ? null : os;

  IconData get icon => switch (kind) {
    'mobile' => LucideIcons.smartphone,
    'tablet' => LucideIcons.tablet,
    'other' => LucideIcons.terminal,
    _ => LucideIcons.monitor,
  };
}

/// Settings → «Мои устройства и сеансы». Ending a session revokes its
/// token on the Mail API; that device gets `401` from the next request or
/// socket re-check and wipes everything local (`registerSignOutWipes`).
class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  final _ending = <String>{};
  bool _endingOthers = false;

  Future<bool> _confirm({required String title, required String body, required String action}) async {
    final t = context.tokens;
    final ok = await showAppSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: t.dangerSoft, shape: BoxShape.circle),
                child: Icon(LucideIcons.logOut, color: t.danger),
              ),
              const SizedBox(height: Space.md),
              Text(title, style: Theme.of(ctx).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: Space.sm),
              Text(
                body,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: t.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('sessions_confirm'),
                  style: FilledButton.styleFrom(backgroundColor: t.danger, foregroundColor: t.textInverse),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(action),
                ),
              ),
              const SizedBox(height: Space.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.cancel)),
              ),
            ],
          ),
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _end(ProfileSession s) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _confirm(
      title: l10n.sessionsEndConfirmTitle,
      body: l10n.sessionsEndConfirmBody(s.title(l10n)),
      action: l10n.sessionsEnd,
    );
    if (!ok || !mounted) return;
    setState(() => _ending.add(s.id));
    try {
      await ref.read(authApiProvider).endSession(s.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.sessionsEnded)));
    } on AppException catch (e) {
      // Already gone elsewhere: the refreshed list shows the truth.
      if (!(e is ApiException && e.statusCode == 404)) {
        messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorText.describe(l10n, e))));
      }
    } finally {
      if (mounted) setState(() => _ending.remove(s.id));
      ref.invalidate(mySessionsProvider);
    }
  }

  Future<void> _endOthers() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _confirm(
      title: l10n.sessionsEndOthers,
      body: l10n.sessionsEndOthersConfirmBody,
      action: l10n.sessionsEndOthers,
    );
    if (!ok || !mounted) return;
    setState(() => _endingOthers = true);
    try {
      final n = await ref.read(authApiProvider).endOtherSessions();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.profileSessionsEnded(n))));
    } on AppException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorText.describe(l10n, e))));
    } finally {
      if (mounted) setState(() => _endingOthers = false);
      ref.invalidate(mySessionsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final sessions = ref.watch(mySessionsProvider);

    Widget section(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.xs, Space.lg, Space.xs, Space.sm),
      child: Text(t.sectionLabel(label), style: text.labelMedium?.copyWith(color: t.textTertiary, letterSpacing: 0.6)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sessionsTitle)),
      body: sessions.when(
        loading: () => const StateView.loading(),
        error: (e, _) => StateView.error(
          message: ErrorText.describe(l10n, e),
          retryLabel: l10n.updateRetry,
          onRetry: () => ref.invalidate(mySessionsProvider),
        ),
        data: (list) {
          final current = list.where((s) => s.current).toList();
          final others = list.where((s) => !s.current).toList();
          return RefreshIndicator(
            onRefresh: () => ref.refresh(mySessionsProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.xl),
              children: [
                Text(l10n.sessionsHint, style: text.bodySmall?.copyWith(color: t.textSecondary, height: 1.4)),
                section(l10n.sessionsThisDevice),
                for (final s in current) _SessionCard(session: s),
                section(l10n.sessionsOthers),
                if (others.isEmpty)
                  Container(
                    key: const Key('sessions_no_others'),
                    padding: const EdgeInsets.all(Space.lg),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(t.radiusLg),
                      border: Border.all(color: t.border, width: t.borderWidth),
                    ),
                    child: Column(
                      children: [
                        ExcludeSemantics(child: Icon(LucideIcons.shieldCheck, color: t.success, size: 28)),
                        const SizedBox(height: Space.sm),
                        Text(l10n.sessionsNoOthers, style: text.bodyMedium, textAlign: TextAlign.center),
                      ],
                    ),
                  )
                else ...[
                  for (final s in others)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.sm),
                      child: _SessionCard(
                        session: s,
                        busy: _ending.contains(s.id) || _endingOthers,
                        onEnd: () => _end(s),
                      ),
                    ),
                  const SizedBox(height: Space.md),
                  // Min height (≥ 48 dp): a long label may wrap.
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: Space.xxxl),
                    child: OutlinedButton.icon(
                      key: const Key('sessions_end_others'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.danger,
                        side: BorderSide(color: t.danger.withValues(alpha: 0.5)),
                      ),
                      onPressed: _endingOthers ? null : _endOthers,
                      icon: _endingOthers
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(LucideIcons.logOut, size: 18),
                      label: Text(l10n.sessionsEndOthers),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, this.onEnd, this.busy = false});

  final ProfileSession session;
  final VoidCallback? onEnd;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final s = session;
    final fmt = DateFormat.yMMMd(l10n.localeName).add_Hm();
    final lastSeen = s.lastSeenAt;
    final details = <String>[
      if (s.current)
        l10n.sessionsActiveNow
      else if (lastSeen != null)
        l10n.sessionsLastActive(fmt.format(lastSeen.toLocal())),
      if (s.createdAt != null) l10n.sessionsSignedIn(fmt.format(s.createdAt!.toLocal())),
      if (s.ip != null && s.ip!.isNotEmpty) l10n.sessionsIp(s.ip!),
    ];
    final platform = s.platformLabel();
    // The card reads as one node; «Завершить» stays a separate button.
    final label = [
      s.title(l10n),
      ?platform,
      if (s.current) l10n.sessionsThisDevice,
      ...details,
    ].join(', ');
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return AnimatedOpacity(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
      opacity: busy ? 0.5 : 1,
      child: Semantics(
        container: true,
        label: label,
        child: Container(
        key: Key('session_${s.id}'),
        decoration: BoxDecoration(
          color: s.current ? t.primarySoft : t.surface,
          borderRadius: BorderRadius.circular(t.radiusLg),
          border: Border.all(color: s.current ? t.primary.withValues(alpha: 0.35) : t.border, width: t.borderWidth),
        ),
        padding: const EdgeInsets.all(Space.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: s.current ? t.primary : t.surfaceSubtle,
                borderRadius: BorderRadius.circular(t.radiusMd),
              ),
              child: Icon(s.icon, color: s.current ? t.textInverse : t.textSecondary, size: 22),
              ),
            ),
            const SizedBox(width: Space.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(s.title(l10n), style: text.titleSmall),
                      if (platform != null) XBadge(platform, small: true),
                      if (s.current) XBadge(l10n.sessionsThisDevice, tone: BadgeTone.success, small: true, icon: LucideIcons.check),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  for (final d in details)
                    Text(d, style: text.bodySmall?.copyWith(color: t.textSecondary)),
                      ],
                    ),
                  ),
                  if (onEnd != null) ...[
                    const SizedBox(height: Space.sm),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        key: Key('session_end_${s.id}'),
                        style: TextButton.styleFrom(
                          foregroundColor: t.danger,
                          padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                          visualDensity: VisualDensity.compact,
                          // Compact look, 48 dp hit area.
                          tapTargetSize: MaterialTapTargetSize.padded,
                        ),
                        onPressed: busy ? null : onEnd,
                        icon: const Icon(LucideIcons.logOut, size: 16),
                        label: Text(l10n.sessionsEnd),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
