import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../../data/chat_translation.dart';
import 'translation_providers.dart';

/// Settings → Язык: «Язык перевода» (the app language by default). Hidden
/// when the server has no translator.
class TranslateTargetSettingsTile extends ConsumerWidget {
  const TranslateTargetSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(translationAvailableProvider)) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final pref = ref.watch(translateTargetPrefProvider);
    final appLanguage = translateLanguageName(
      l10n,
      TranslateLanguages.normalize(
        Localizations.localeOf(context).languageCode,
      ),
    );
    String label(String? code) => code == null
        ? l10n.translateTargetAppLanguage(appLanguage)
        : translateLanguageName(l10n, code);
    return ListTile(
      key: const Key('settings_translate_target'),
      leading: const Icon(LucideIcons.languages),
      title: Text(l10n.translateTargetSetting),
      subtitle: Text(label(pref)),
      onTap: () async {
        const app = '';
        final picked = await showDialog<String>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: Text(l10n.translateTargetSetting),
            children: [
              for (final code in [app, ...TranslateLanguages.supported])
                SimpleDialogOption(
                  key: ValueKey(
                    'translate_target_${code.isEmpty ? 'app' : code}',
                  ),
                  onPressed: () => Navigator.pop(ctx, code),
                  child: Row(
                    children: [
                      Icon(
                        (pref ?? app) == code
                            ? LucideIcons.circleDot
                            : LucideIcons.circle,
                        color: (pref ?? app) == code
                            ? Theme.of(ctx).colorScheme.primary
                            : null,
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(child: Text(label(code.isEmpty ? null : code))),
                    ],
                  ),
                ),
            ],
          ),
        );
        if (picked == null) return;
        await ref
            .read(translateTargetPrefProvider.notifier)
            .set(picked.isEmpty ? null : picked);
      },
    );
  }
}

/// Chat info: «Переводить автоматически на …» for incoming messages of this
/// conversation (this device). Hidden when the server has no translator.
class ChatAutoTranslateTile extends ConsumerWidget {
  const ChatAutoTranslateTile({super.key, required this.conversationId});
  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(translationAvailableProvider)) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final target = translateTarget(ref, context);
    return SwitchListTile(
      key: const Key('chat_info_auto_translate'),
      secondary: const Icon(LucideIcons.languages),
      title: Text(
        l10n.translateAutoInChat(translateLanguageName(l10n, target)),
      ),
      subtitle: Text(
        l10n.translateAutoInChatHint,
        style: TextStyle(color: context.tokens.textMuted),
      ),
      value: ref.watch(chatAutoTranslateProvider).contains(conversationId),
      onChanged: (v) =>
          ref.read(chatAutoTranslateProvider.notifier).set(conversationId, v),
    );
  }
}
