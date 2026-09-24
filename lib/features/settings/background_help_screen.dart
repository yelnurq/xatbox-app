import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/localization/localization.dart';
import '../../core/theme/tokens.dart';

/// Settings → Уведомления → «Автозапуск и фоновая работа»: text-only steps
/// for vendor firmwares that kill background apps harder than stock Android.
class BackgroundHelpScreen extends StatelessWidget {
  const BackgroundHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sections = <(String, String)>[
      (l10n.bgHelpCommonTitle, l10n.bgHelpCommonSteps),
      (l10n.bgHelpXiaomiTitle, l10n.bgHelpXiaomiSteps),
      (l10n.bgHelpHuaweiTitle, l10n.bgHelpHuaweiSteps),
      (l10n.bgHelpSamsungTitle, l10n.bgHelpSamsungSteps),
      (l10n.bgHelpOppoTitle, l10n.bgHelpOppoSteps),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.bgHelpTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const Key('background_help'),
          padding: const EdgeInsets.all(Space.md),
          children: [
            Text(l10n.bgHelpIntro, style: theme.textTheme.bodyMedium),
            for (final (title, steps) in sections) ...[
              const SizedBox(height: Space.lg),
              Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.titleSmall),
              ),
              const SizedBox(height: Space.xs),
              SelectableText(steps, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: Space.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ExcludeSemantics(child: Icon(LucideIcons.circleCheck, size: 20)),
                const SizedBox(width: Space.sm),
                Expanded(child: Text(l10n.bgHelpCheck, style: theme.textTheme.bodySmall)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
