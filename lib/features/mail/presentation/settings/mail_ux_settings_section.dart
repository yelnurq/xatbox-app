import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/platform/desktop.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../mail_ux_settings.dart';

/// Device-local mail preferences in «Настройки почты»: swipe actions of the
/// message list and the «Отменить отправку» delay.
class MailUxSettingsSection extends ConsumerWidget {
  const MailUxSettingsSection({super.key});

  static String swipeLabel(AppLocalizations l10n, MailSwipeAction a) =>
      switch (a) {
        MailSwipeAction.none => l10n.mailUxSwipeNone,
        MailSwipeAction.trash => l10n.mailUxSwipeTrash,
        MailSwipeAction.archive => l10n.mailUxSwipeArchive,
        MailSwipeAction.read => l10n.mailUxSwipeRead,
        MailSwipeAction.bookmark => l10n.mailUxSwipeBookmark,
      };

  static String undoLabel(AppLocalizations l10n, int seconds) => seconds == 0
      ? l10n.mailUxUndoSendOff
      : l10n.mailUxUndoSendSeconds(seconds);

  Future<T?> _choose<T>(
    BuildContext context, {
    required String title,
    required List<T> options,
    required T current,
    required String Function(T) label,
    required String keyPrefix,
  }) => showDialog<T>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(title),
      children: [
        RadioGroup<T>(
          groupValue: current,
          onChanged: (v) => Navigator.pop(ctx, v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final o in options)
                RadioListTile<T>(
                  key: Key('${keyPrefix}_$o'),
                  value: o,
                  title: Text(label(o)),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final ux = ref.watch(mailUxSettingsProvider);
    final hasArchive = ref.watch(mailArchiveFolderProvider) != null;
    final notifier = ref.read(mailUxSettingsProvider.notifier);
    final swipeOptions = [
      for (final a in MailSwipeAction.values)
        if (a != MailSwipeAction.archive || hasArchive) a,
    ];

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.md,
        Space.lg,
        Space.md,
        Space.xs,
      ),
      child: Text(
        t.sectionLabel(text),
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: t.textTertiary, letterSpacing: 0.6),
      ),
    );

    Future<void> pickSwipe(bool left) async {
      final current = left ? ux.swipeLeft : ux.swipeRight;
      final picked = await _choose<MailSwipeAction>(
        context,
        title: left ? l10n.mailUxSwipeLeft : l10n.mailUxSwipeRight,
        options: swipeOptions,
        current: current,
        label: (a) => swipeLabel(l10n, a),
        keyPrefix: left ? 'swipe_left' : 'swipe_right',
      );
      if (picked == null) return;
      await notifier.update(
        left ? ux.copyWith(swipeLeft: picked) : ux.copyWith(swipeRight: picked),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Swipes are touch gestures; the desktop shows the actions on hover.
        if (!isDesktop) ...[
          header(l10n.mailUxSwipeSection),
          ListTile(
            key: const Key('mail_ux_swipe_left'),
            leading: const Icon(LucideIcons.arrowLeft),
            title: Text(l10n.mailUxSwipeLeft),
            subtitle: Text(swipeLabel(l10n, ux.swipeLeft)),
            onTap: () => pickSwipe(true),
          ),
          ListTile(
            key: const Key('mail_ux_swipe_right'),
            leading: const Icon(LucideIcons.arrowRight),
            title: Text(l10n.mailUxSwipeRight),
            subtitle: Text(swipeLabel(l10n, ux.swipeRight)),
            onTap: () => pickSwipe(false),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: Text(
              l10n.mailUxSwipeHint,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: t.textMuted),
            ),
          ),
        ],
        header(l10n.mailUxSendSection),
        ListTile(
          key: const Key('mail_ux_undo_send'),
          leading: const Icon(LucideIcons.undo2),
          title: Text(l10n.mailUxUndoSend),
          subtitle: Text(
            '${undoLabel(l10n, ux.undoSendSeconds)} · ${l10n.mailUxUndoSendHint}',
          ),
          onTap: () async {
            final picked = await _choose<int>(
              context,
              title: l10n.mailUxUndoSend,
              options: MailUxSettings.undoSendChoices,
              current: ux.undoSendSeconds,
              label: (s) => undoLabel(l10n, s),
              keyPrefix: 'undo_send',
            );
            if (picked == null) return;
            await notifier.update(ux.copyWith(undoSendSeconds: picked));
          },
        ),
        const SizedBox(height: Space.lg),
      ],
    );
  }
}
