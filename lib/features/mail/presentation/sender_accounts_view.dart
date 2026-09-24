import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/error_text.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/widgets/ds/x_badge.dart';
import '../../../shared/widgets/state_view.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../data/mail_models.dart';
import 'mail_providers.dart';

final smartFolderAccountsProvider = FutureProvider.autoDispose.family<List<MailSmartFolderAccount>, String>(
  (ref, folderId) => ref.watch(mailApiProvider).smartFolderAccounts(folderId),
);

/// A smart folder opened without a sender shows its senders (the web's
/// "account view"): avatar, name, address, last subject, unread pill, chevron.
/// Tapping one filters the folder to that sender.
class SenderAccountsView extends ConsumerWidget {
  const SenderAccountsView({super.key, required this.folder});
  final MailFolder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final accounts = ref.watch(smartFolderAccountsProvider(folder.id));
    final locale = Localizations.localeOf(context).toString();
    return accounts.when(
      loading: () => const StateView.loading(),
      error: (e, _) => StateView.error(
        message: ErrorText.describe(l10n, e),
        onRetry: () => ref.invalidate(smartFolderAccountsProvider(folder.id)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return StateView.empty(title: l10n.mailEmptyFolder, subtitle: l10n.mailFolderModalHint, icon: LucideIcons.folder);
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(smartFolderAccountsProvider(folder.id)),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final a = list[i];
              final c = t.folderColors(folder.color);
              return Material(
                color: t.surface,
                child: InkWell(
                  key: Key('sender_${a.address}'),
                  onTap: () => ref.read(mailFiltersProvider.notifier).setSender(a.address),
                  child: Container(
                    constraints: BoxConstraints(minHeight: t.display.rowMinHeight),
                    padding: EdgeInsets.symmetric(horizontal: Space.smd, vertical: t.display.rowPaddingY),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border, width: t.borderWidth))),
                    child: Row(
                      children: [
                        UserAvatar(email: a.address, label: a.label, radius: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      a.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: a.unread > 0 ? FontWeight.w600 : FontWeight.w400),
                                    ),
                                  ),
                                  const SizedBox(width: Space.sm),
                                  Text(FormatUtils.listDate(a.lastDate, locale), style: Theme.of(context).textTheme.labelSmall!.copyWith(fontFamily: 'JetBrains Mono')),
                                ],
                              ),
                              Text(a.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall),
                              if (a.lastSubject.isNotEmpty)
                                Text(a.lastSubject, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        if (a.unread > 0) CountPill(a.unread, color: c.foreground, background: c.background),
                        const SizedBox(width: 4),
                        Icon(LucideIcons.chevronRight, size: 16, color: t.textTertiary),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
