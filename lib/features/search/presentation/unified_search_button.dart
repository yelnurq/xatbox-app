import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/localization/localization.dart';
import '../../../core/platform/desktop_layout.dart';
import '../../../core/routing/routes.dart';

/// App bar action «Поиск везде»: opens the unified search.
class UnifiedSearchButton extends ConsumerWidget {
  const UnifiedSearchButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Desktop: «Поиск» (Ctrl+K) is on the module rail.
    if (ref.watch(desktopLayoutProvider)) return const SizedBox.shrink();
    return IconButton(
      key: const Key('unified_search'),
      tooltip: context.l10n.searchEverywhere,
      icon: const Icon(LucideIcons.textSearch),
      onPressed: () => context.push(Routes.search),
    );
  }
}
