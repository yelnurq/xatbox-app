import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/storage/storage_usage.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/error_text.dart';
import '../data/apk_installer.dart';
import '../data/apk_downloader.dart';
import '../data/update_models.dart';
import 'update_controller.dart';
import '../../../core/platform/desktop.dart';

/// `12,4 МБ` in the app's size units.
String formatBytes(AppLocalizations l10n, int bytes) {
  final (value, unit) = splitBytes(bytes);
  final digits = unit == SizeUnit.b || value >= 100 ? 0 : 1;
  final text = NumberFormat.decimalPatternDigits(
    locale: l10n.localeName,
    decimalDigits: digits,
  ).format(value);
  return switch (unit) {
    SizeUnit.b => l10n.appSizeBytes(text),
    SizeUnit.kb => l10n.appSizeKb(text),
    SizeUnit.mb => l10n.appSizeMb(text),
    SizeUnit.gb => l10n.appSizeGb(text),
  };
}

String updateErrorText(AppLocalizations l10n, Object? error) => switch (error) {
  ApkIntegrityException() => l10n.updateIntegrityFailed,
  InstallFailedException() => isDesktop
      ? [l10n.updateInstallFailedDesktop, ?WindowsSetupInstaller.lastError].join(': ')
      : l10n.updateInstallFailed,
  AppException() => ErrorText.describe(l10n, error),
  _ => l10n.updateFailed,
};

/// Brand-tinted round badge with an icon (sheet / screen headers).
/// Decorative: hidden from screen readers.
class UpdateHeroIcon extends StatelessWidget {
  const UpdateHeroIcon({super.key, this.icon = LucideIcons.sparkles, this.size = 64, this.tone});

  final IconData icon;
  final double size;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = tone ?? t.primary;
    return ExcludeSemantics(
      child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.06)],
        ),
        border: Border.all(color: color.withValues(alpha: 0.25), width: t.borderWidth),
      ),
      child: Icon(icon, color: color, size: size * 0.44),
      ),
    );
  }
}

/// «Что нового»: notes in the app language with a soft panel.
class ReleaseNotesCard extends StatelessWidget {
  const ReleaseNotesCard({super.key, required this.release, this.maxHeight});

  final AppRelease release;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final notes = release.notesFor(l10n.localeName);
    final body = Text(
      notes.isEmpty ? l10n.updateNoNotes : notes,
      style: text.bodyMedium?.copyWith(color: t.textSecondary, height: 1.45),
    );
    return Container(
      key: const Key('update_notes'),
      width: double.infinity,
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: t.surfaceSubtle,
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: Border.all(color: t.border, width: t.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.gift, size: 16, color: t.primary),
              const SizedBox(width: Space.sm),
              Text(l10n.updateWhatsNew, style: text.titleSmall),
            ],
          ),
          const SizedBox(height: Space.sm),
          if (maxHeight == null)
            body
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight!),
              child: SingleChildScrollView(child: body),
            ),
        ],
      ),
    );
  }
}

/// Version, size and date chips of a release.
class ReleaseFacts extends StatelessWidget {
  const ReleaseFacts({super.key, required this.release});
  final AppRelease release;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    Widget chip(IconData icon, String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.smd, vertical: 6),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(XatBoxTokens.radiusPill),
        border: Border.all(color: t.border, width: t.borderWidth),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: t.textTertiary),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: t.textSecondary)),
        ],
      ),
    );
    final published = release.publishedAt;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        chip(LucideIcons.tag, l10n.updateNewVersion(release.versionName)),
        if (release.file != null)
          chip(LucideIcons.download, formatBytes(l10n, release.file!.size)),
        if (published != null)
          chip(
            LucideIcons.calendar,
            DateFormat.yMMMd(l10n.localeName).format(published.toLocal()),
          ),
      ],
    );
  }
}

/// Download progress, permission guidance and the main action for the
/// current [UpdateState]; shared by the sheet, the screen and the gate.
class UpdateActionPanel extends ConsumerWidget {
  const UpdateActionPanel({super.key, this.onLater});

  /// Secondary «Позже» (optional updates only).
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final s = ref.watch(updateControllerProvider);
    final c = ref.read(updateControllerProvider.notifier);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    Widget primary(String label, VoidCallback? onPressed, {IconData? icon, Key? key}) =>
        SizedBox(
          width: double.infinity,
          // Min height: the label may wrap at large text.
          child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Space.controlLg + 8),
          child: FilledButton.icon(
            key: key,
            onPressed: onPressed,
            icon: Icon(icon ?? LucideIcons.download, size: 18),
            label: Text(label),
          ),
          ),
        );
    Widget? later = onLater == null
        ? null
        : TextButton(key: const Key('update_later'), onPressed: onLater, child: Text(l10n.updateLater));

    final children = <Widget>[];
    if (s.incompatible) {
      children.add(_Notice(icon: LucideIcons.circleAlert, tone: t.warning, soft: t.warningSoft, text: l10n.updateIncompatible));
    } else {
      switch (s.phase) {
        case UpdatePhase.downloading:
          final p = s.progress;
          final percent = ((p ?? 0) * 100).round();
          final sizes = l10n.updateDownloadedOf(formatBytes(l10n, s.received), formatBytes(l10n, s.total));
          children.addAll([
            ClipRRect(
              borderRadius: BorderRadius.circular(XatBoxTokens.radiusPill),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: p ?? 0),
                duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
                builder: (_, v, _) => LinearProgressIndicator(
                  key: const Key('update_progress'),
                  value: p == null ? null : v,
                  semanticsLabel: l10n.updateDownloading(percent),
                  semanticsValue: p == null ? null : sizes,
                  minHeight: 8,
                  backgroundColor: t.surfaceMuted,
                ),
              ),
            ),
            const SizedBox(height: Space.sm),
            // Wraps at narrow width / large text; with a known progress the
            // same text is already in the indicator's semantics.
            ExcludeSemantics(
              excluding: p != null,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: Space.sm,
                runSpacing: Space.xxs,
                children: [
                  Text(
                    l10n.updateDownloading(percent),
                    style: text.labelLarge,
                  ),
                  Text(
                    sizes,
                    style: text.labelMedium?.copyWith(color: t.textTertiary, fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('update_cancel'),
                onPressed: c.cancelDownload,
                child: Text(l10n.updateCancel),
              ),
            ),
          ]);
        case UpdatePhase.needsPermission:
          children.addAll([
            _Notice(
              icon: LucideIcons.shieldCheck,
              tone: t.info,
              soft: t.infoSoft,
              title: l10n.updatePermissionTitle,
              text: l10n.updatePermissionBody,
            ),
            const SizedBox(height: Space.md),
            primary(l10n.updatePermissionOpen, c.openInstallSettings, icon: LucideIcons.settings2, key: const Key('update_open_settings')),
          ]);
        case UpdatePhase.ready when s.installed?.isLinux == true:
        case UpdatePhase.installing when s.installed?.isLinux == true:
          // Linux: the .deb is opened with the system's package installer.
          if (s.phase == UpdatePhase.installing) {
            children.addAll([
              _Notice(
                icon: LucideIcons.packageCheck,
                tone: t.success,
                soft: t.successSoft,
                title: l10n.updateLinuxOpened,
                text: l10n.updateLinuxOpenedHint,
              ),
              const SizedBox(height: Space.md),
            ]);
          }
          children.add(primary(l10n.updateLinuxOpen, c.install, icon: LucideIcons.packageOpen, key: const Key('update_install')));
        case UpdatePhase.ready:
        case UpdatePhase.installing:
          if (s.phase == UpdatePhase.installing) {
            children.addAll([
              _Notice(icon: LucideIcons.packageCheck, tone: t.success, soft: t.successSoft, title: l10n.updateInstalling, text: l10n.updateInstallingHint),
              const SizedBox(height: Space.md),
            ]);
          }
          if (s.installed?.isDesktopApp == true && s.phase == UpdatePhase.ready) {
            // Desktop: installing restarts XatBox; now or when quitting.
            if (s.installOnQuit) {
              children.addAll([
                _Notice(icon: LucideIcons.clock, tone: t.info, soft: t.infoSoft, text: l10n.updateOnQuitScheduled),
                const SizedBox(height: Space.md),
              ]);
            }
            children.add(primary(l10n.updateRestartNow, c.install, icon: LucideIcons.refreshCw, key: const Key('update_install')));
            if (!s.installOnQuit) {
              children.addAll([
                const SizedBox(height: Space.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: const Key('update_on_quit'),
                    onPressed: c.installOnQuit,
                    child: Text(l10n.updateOnQuit),
                  ),
                ),
              ]);
            }
          } else {
            children.add(primary(l10n.updateInstall, c.install, icon: LucideIcons.packageCheck, key: const Key('update_install')));
          }
        case UpdatePhase.failed:
          children.addAll([
            _Notice(icon: LucideIcons.circleAlert, tone: t.danger, soft: t.dangerSoft, text: updateErrorText(l10n, s.error)),
            const SizedBox(height: Space.md),
            if (s.hasUpdate)
              primary(
                s.received > 0 ? l10n.updateResume : l10n.updateDownload,
                c.download,
                key: const Key('update_download'),
              )
            else
              primary(l10n.updateRetry, c.check, icon: LucideIcons.refreshCw, key: const Key('update_retry')),
          ]);
        case UpdatePhase.checking:
          children.add(primary(l10n.updateChecking, null, icon: LucideIcons.loader));
        case UpdatePhase.available:
          children.add(primary(
            s.received > 0
                ? l10n.updateResume
                : (s.installed?.isLinux == true ? l10n.updateDownloadOnly : l10n.updateDownload),
            c.download,
            key: const Key('update_download'),
          ));
        case UpdatePhase.idle:
        case UpdatePhase.upToDate:
        case UpdatePhase.unsupported:
          break;
      }
    }
    if (later != null && s.phase != UpdatePhase.downloading) {
      children.addAll([const SizedBox(height: Space.xs), Center(child: later)]);
    }
    return AnimatedSize(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.tone, required this.soft, required this.text, this.title});

  final IconData icon;
  final Color tone;
  final Color soft;
  final String? title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Space.smd),
        decoration: BoxDecoration(
          color: soft,
          borderRadius: BorderRadius.circular(t.radiusMd),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: tone),
            const SizedBox(width: Space.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(title!, style: style.titleSmall?.copyWith(color: t.textPrimary)),
                    const SizedBox(height: 2),
                  ],
                  Text(text, style: style.bodySmall?.copyWith(color: t.textSecondary, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
