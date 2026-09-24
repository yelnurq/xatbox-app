import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/platform/desktop.dart';
import '../../../core/localization/localization.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../update/data/update_models.dart';
import '../../update/presentation/update_controller.dart';
import '../../update/presentation/update_widgets.dart';
import '../data/endpoint_status.dart';
import '../../../shared/widgets/app_sheet.dart';

/// Settings → «О приложении»: build, server status, «Что нового», privacy,
/// open-source licences and «Сообщить о проблеме».
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  void _whatsNew(BuildContext context, AppRelease release) {
    showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const UpdateHeroIcon(icon: LucideIcons.gift),
            const SizedBox(height: Space.md),
            ReleaseFacts(release: release),
            const SizedBox(height: Space.md),
            ReleaseNotesCard(release: release),
          ],
        ),
      ),
    );
  }

  void _licenses(BuildContext context, InstalledApp? app) {
    final t = context.tokens;
    showLicensePage(
      context: context,
      applicationName: context.l10n.appTitle,
      applicationVersion: app?.label,
      applicationIcon: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: BrandMark(size: 48, color: t.mark),
      ),
      applicationLegalese: '© ${DateTime.now().year} XatBox',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final app = ref.watch(installedAppProvider).value;
    final update = ref.watch(updateControllerProvider);
    final release = update.release;
    final status = ref.watch(endpointStatusProvider);

    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xs, 0, Space.xs, Space.sm),
            child: Text(t.sectionLabel(title), style: text.labelMedium?.copyWith(color: t.textTertiary, letterSpacing: 0.6)),
          ),
          Material(
            color: t.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(t.radiusLg),
              side: BorderSide(color: t.border, width: t.borderWidth),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xl),
        children: [
          // Hero: mark, name, version.
          Container(
            padding: const EdgeInsets.symmetric(vertical: Space.xl, horizontal: Space.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(t.radiusXl),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.primarySoft, t.surface],
              ),
              border: Border.all(color: t.border, width: t.borderWidth),
            ),
            child: Column(
              children: [
                BrandMark(size: 64, color: t.mark),
                const SizedBox(height: Space.md),
                Text(l10n.appTitle, style: text.headlineSmall),
                const SizedBox(height: Space.xs),
                Text(l10n.aboutTagline, style: text.bodyMedium?.copyWith(color: t.textSecondary), textAlign: TextAlign.center),
                if (app != null) ...[
                  const SizedBox(height: Space.md),
                  GestureDetector(
                    child: Container(
                      key: const Key('about_version'),
                      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 6),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(XatBoxTokens.radiusPill),
                        border: Border.all(color: t.border, width: t.borderWidth),
                      ),
                      child: Text(
                        l10n.aboutVersion(app.versionName, '${app.buildNumber}'),
                        style: text.labelLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          section(l10n.aboutServers, [
            ...status.when(
              loading: () => [
                for (final kind in ServiceKind.values)
                  _ServerTile(kind: kind, status: null),
              ],
              error: (_, _) => [const SizedBox.shrink()],
              data: (list) => [for (final s in list) _ServerTile(kind: s.kind, status: s)],
            ),
            Divider(height: 1, color: t.divider),
            ListTile(
              key: const Key('about_recheck'),
              leading: Icon(LucideIcons.refreshCw, color: t.primary, size: 20),
              title: Text(l10n.aboutRecheck, style: TextStyle(color: t.primary)),
              onTap: status.isLoading ? null : () => ref.invalidate(endpointStatusProvider),
            ),
          ]),
          section(l10n.aboutAppSection, [
            if (ref.watch(appUpdatesSupportedProvider))
              ListTile(
                key: const Key('about_update'),
                leading: const Icon(LucideIcons.download),
                title: Text(l10n.updateTitle),
                subtitle: update.hasUpdate && release != null
                    ? Text(l10n.updateSettingsAvailable(release.versionName), style: TextStyle(color: t.primary))
                    : null,
                trailing: const Icon(LucideIcons.chevronRight, size: 16),
                onTap: () => context.push(Routes.settingsUpdate),
              ),
            if (release != null && release.hasRelease)
              ListTile(
                key: const Key('about_whats_new'),
                leading: const Icon(LucideIcons.gift),
                title: Text(l10n.aboutWhatsNew),
                subtitle: Text(l10n.updateNewVersion(release.versionName)),
                trailing: const Icon(LucideIcons.chevronRight, size: 16),
                onTap: () => _whatsNew(context, release),
              ),
            ListTile(
              key: const Key('about_report'),
              leading: const Icon(LucideIcons.messageSquareWarning),
              title: Text(l10n.reportTitle),
              trailing: const Icon(LucideIcons.chevronRight, size: 16),
              onTap: () => context.push(Routes.reportProblem),
            ),
            ListTile(
              key: const Key('about_licenses'),
              leading: const Icon(LucideIcons.scrollText),
              title: Text(l10n.aboutLicenses),
              trailing: const Icon(LucideIcons.chevronRight, size: 16),
              onTap: () => _licenses(context, app),
            ),
          ]),
          section(l10n.aboutPrivacy, [
            _PrivacyItem(icon: LucideIcons.server, title: l10n.aboutPrivacyDataTitle, body: l10n.aboutPrivacyDataBody),
            _PrivacyItem(icon: LucideIcons.bellRing, title: l10n.aboutPrivacyPushTitle, body: isDesktop ? l10n.aboutPrivacyPushBodyDesktop : l10n.aboutPrivacyPushBody),
            _PrivacyItem(icon: LucideIcons.shieldAlert, title: l10n.aboutPrivacyReportsTitle, body: l10n.aboutPrivacyReportsBody),
            _PrivacyItem(icon: LucideIcons.lockKeyhole, title: l10n.aboutPrivacyLockTitle, body: l10n.aboutPrivacyLockBody, last: true),
          ]),
        ],
      ),
    );
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({required this.kind, required this.status});

  final ServiceKind kind;
  final EndpointStatus? status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final s = status;
    final (IconData icon, String name) = switch (kind) {
      ServiceKind.mail => (LucideIcons.mail, l10n.aboutServerMail),
      ServiceKind.chat => (LucideIcons.messageCircle, l10n.aboutServerChat),
      ServiceKind.calls => (LucideIcons.phone, l10n.aboutServerCalls),
    };
    final (Color dot, String label) = switch (s) {
      null => (t.textDisabled, l10n.loading),
      EndpointStatus(configured: false) => (t.textDisabled, l10n.aboutServerNotConfigured),
      EndpointStatus(reachable: false) => (t.danger, l10n.aboutServerUnreachable),
      EndpointStatus(degraded: true) => (t.warning, l10n.aboutServerDegraded),
      _ => (
        (s.latency?.inMilliseconds ?? 0) > 800 ? t.warning : t.success,
        l10n.aboutServerLatency(s.latency?.inMilliseconds ?? 0),
      ),
    };
    return ListTile(
      key: Key('about_server_${kind.name}'),
      leading: Icon(icon),
      title: Text(name),
      subtitle: s == null || s.host.isEmpty ? null : Text(s.host, style: text.bodySmall?.copyWith(color: t.textTertiary)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: Space.sm),
          Text(label, style: text.labelMedium?.copyWith(color: t.textSecondary, fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

class _PrivacyItem extends StatelessWidget {
  const _PrivacyItem({required this.icon, required this.title, required this.body, this.last = false});

  final IconData icon;
  final String title;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: t.divider, width: t.borderWidth)),
      ),
      padding: const EdgeInsets.all(Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(t.radiusMd)),
            child: Icon(icon, size: 18, color: t.primary),
          ),
          const SizedBox(width: Space.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: text.bodySmall?.copyWith(color: t.textSecondary, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
