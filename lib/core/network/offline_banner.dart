import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/localization.dart';
import '../theme/tokens.dart';
import 'network_status.dart';

/// App-wide strip shown while the device has no network (ТЗ п.24.17). The
/// child keeps its position in the tree, so routes are not rebuilt when the
/// banner appears.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = !ref.watch(isOnlineProvider);
    final media = MediaQuery.of(context);
    final tokens = context.tokens;
    return Column(
      children: [
        if (offline)
          Material(
            key: const Key('offline_banner'),
            color: tokens.offlineBanner,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                Space.md,
                media.padding.top + Space.xs,
                Space.md,
                Space.xs,
              ),
              child: Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.cloudOff,
                      size: 16,
                      color: tokens.onOfflineBanner,
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        context.l10n.appOfflineBanner,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: tokens.onOfflineBanner),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          const SizedBox.shrink(),
        Expanded(
          child: MediaQuery(
            data: offline
                ? media.copyWith(
                    padding: media.padding.copyWith(top: 0),
                    viewPadding: media.viewPadding.copyWith(top: 0),
                  )
                : media,
            child: child,
          ),
        ),
      ],
    );
  }
}
