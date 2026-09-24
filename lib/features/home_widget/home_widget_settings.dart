import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/localization/localization.dart';
import '../../core/theme/tokens.dart';
import 'home_widget_service.dart';

/// Settings → «Виджет и ярлыки» (Android): message text in the home screen
/// widget, off by default.
class HomeWidgetSettingsSection extends ConsumerWidget {
  const HomeWidgetSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(homeWidgetSupportedProvider)) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
          child: Text(
            l10n.settingsWidgetSection,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        SwitchListTile(
          key: const Key('settings_widget_preview'),
          secondary: const Icon(LucideIcons.layoutGrid),
          title: Text(l10n.settingsWidgetPreview),
          subtitle: Text(l10n.settingsWidgetPreviewHint),
          value: ref.watch(homeWidgetPreviewProvider),
          onChanged: (v) => ref.read(homeWidgetPreviewProvider.notifier).set(v),
        ),
      ],
    );
  }
}
