import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import 'update_controller.dart';
import 'update_widgets.dart';

/// Settings → «Обновление приложения».
class UpdateScreen extends ConsumerStatefulWidget {
  const UpdateScreen({super.key});

  @override
  ConsumerState<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends ConsumerState<UpdateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = ref.read(updateControllerProvider.notifier);
      final phase = ref.read(updateControllerProvider).phase;
      // Show the last answer at once; ask the server when nothing is known.
      if (phase == UpdatePhase.idle) c.check();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final s = ref.watch(updateControllerProvider);
    final c = ref.read(updateControllerProvider.notifier);
    final installed = s.installed ?? ref.watch(installedAppProvider).value;
    final release = s.release;
    final hasUpdate = s.hasUpdate && release != null;

    final (IconData icon, Color tone, String title) = switch (s.phase) {
      _ when s.mandatory => (LucideIcons.triangleAlert, t.warning, l10n.updateMandatoryTitle),
      _ when hasUpdate => (LucideIcons.sparkles, t.primary, l10n.updateAvailableTitle),
      UpdatePhase.checking || UpdatePhase.idle => (LucideIcons.refreshCw, t.primary, l10n.updateChecking),
      UpdatePhase.failed => (LucideIcons.cloudOff, t.danger, l10n.updateCheckFailed),
      UpdatePhase.unsupported => (LucideIcons.info, t.textTertiary, l10n.updateTitle),
      _ => (LucideIcons.circleCheck, t.success, l10n.updateUpToDate),
    };

    final checked = s.checkedAt;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.updateTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.lg, Space.md, Space.xl),
        children: [
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: UpdateHeroIcon(key: ValueKey(icon), icon: icon, tone: tone, size: 72),
            ),
          ),
          const SizedBox(height: Space.md),
          Text(title, key: const Key('update_status_title'), style: text.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: Space.xs),
          if (installed != null)
            Text(
              l10n.updateCurrentVersion(installed.label),
              style: text.bodyMedium?.copyWith(color: t.textSecondary),
              textAlign: TextAlign.center,
            ),
          if (checked != null)
            Text(
              l10n.updateCheckedAt(DateFormat.yMMMd(l10n.localeName).add_Hm().format(checked.toLocal())),
              style: text.bodySmall?.copyWith(color: t.textTertiary),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: Space.lg),
          if (s.phase == UpdatePhase.unsupported)
            Text(
              s.installed?.managedByAdmin == true ? l10n.updateManagedByAdmin : l10n.updateUnsupported,
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            )
          else ...[
            if (hasUpdate) ...[
              ReleaseFacts(release: release),
              const SizedBox(height: Space.md),
            ],
            if (release != null && release.hasRelease) ...[
              ReleaseNotesCard(release: release),
              const SizedBox(height: Space.lg),
            ],
            if (hasUpdate || s.phase == UpdatePhase.failed) const UpdateActionPanel(),
            if (!s.busy && !hasUpdate && s.phase != UpdatePhase.failed)
              Center(
                child: OutlinedButton.icon(
                  key: const Key('update_check'),
                  onPressed: c.check,
                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                  label: Text(l10n.updateCheck),
                ),
              ),
            if (hasUpdate && !s.busy) ...[
              const SizedBox(height: Space.sm),
              Center(
                child: TextButton(onPressed: c.check, child: Text(l10n.updateCheck)),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
