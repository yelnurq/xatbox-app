import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import 'update_controller.dart';
import 'update_widgets.dart';
import '../../../shared/widgets/app_sheet.dart';

/// «Доступно обновление» bottom sheet: version, «Что нового», size, then the
/// download / install flow in place. «Позже» postpones this version.
Future<void> showUpdateSheet(BuildContext context) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => const UpdateSheet(),
);

class UpdateSheet extends ConsumerWidget {
  const UpdateSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final s = ref.watch(updateControllerProvider);
    final release = s.release;
    if (release == null) return const SizedBox(height: 120);
    final installed = s.installed;
    return SingleChildScrollView(
      key: const Key('update_sheet'),
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: UpdateHeroIcon()),
          const SizedBox(height: Space.md),
          Text(l10n.updateAvailableTitle, style: text.headlineSmall, textAlign: TextAlign.center),
          if (installed != null) ...[
            const SizedBox(height: Space.xs),
            Text(
              l10n.updateCurrentVersion(installed.versionName),
              style: text.bodyMedium?.copyWith(color: t.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: Space.md),
          ReleaseFacts(release: release),
          const SizedBox(height: Space.md),
          ReleaseNotesCard(release: release, maxHeight: 220),
          const SizedBox(height: Space.lg),
          UpdateActionPanel(
            onLater: () async {
              await ref.read(updateControllerProvider.notifier).postpone();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
