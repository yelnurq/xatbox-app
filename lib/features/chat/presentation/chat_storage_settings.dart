import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/desktop.dart';
import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/format_utils.dart';
import '../data/media_auto_download.dart';
import 'chat_providers.dart';
import 'voice_record_mode.dart';

/// Chat storage controls for the Settings screen: media auto-download policy,
/// messages kept per conversation, size of the chat media directory with a
/// clear button. Renders nothing when chat is disabled.
class ChatStorageSettingsSection extends ConsumerWidget {
  const ChatStorageSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(chatEnabledProvider)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final policy = ref.watch(chatMediaAutoDownloadProvider);
    final limit = ref.watch(chatMessageLimitProvider);
    final size = ref.watch(chatMediaSizeProvider);

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xs),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return Column(
      key: const Key('chat_storage_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        header(l10n.chatStorageSection),
        ListTile(
          title: Text(l10n.chatAutoDownloadTitle),
          subtitle: Text(
            l10n.chatAutoDownloadHint,
            style: TextStyle(color: tokens.textMuted),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          child: SegmentedButton<MediaAutoDownload>(
            key: const Key('chat_auto_download'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: MediaAutoDownload.never,
                label: Text(l10n.chatAutoDownloadNever),
              ),
              ButtonSegment(
                value: MediaAutoDownload.wifiOnly,
                label: Text(l10n.chatAutoDownloadWifi),
              ),
              ButtonSegment(
                value: MediaAutoDownload.always,
                label: Text(l10n.chatAutoDownloadAlways),
              ),
            ],
            selected: {policy},
            onSelectionChanged: (s) =>
                ref.read(chatMediaAutoDownloadProvider.notifier).set(s.first),
          ),
        ),
        ListTile(title: Text(l10n.chatMessagesKeptTitle)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          child: SegmentedButton<int>(
            key: const Key('chat_messages_limit'),
            showSelectedIcon: false,
            segments: [
              for (final n in chatMessageLimitOptions)
                ButtonSegment(value: n, label: Text('$n')),
            ],
            selected: {
              chatMessageLimitOptions.contains(limit)
                  ? limit
                  : chatMessageLimitDefault,
            },
            onSelectionChanged: (s) =>
                ref.read(chatMessageLimitProvider.notifier).set(s.first),
          ),
        ),
        // «Запись голосовых»: hold (default) or tap to record; the desktop
        // always taps (ChatVoiceRecordMode.effective).
        if (!isDesktop) ...[
          ListTile(
            title: Text(l10n.chatVoiceModeTitle),
            subtitle: Text(
              l10n.chatVoiceModeHint,
              style: TextStyle(color: tokens.textMuted),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: SegmentedButton<ChatVoiceRecordMode>(
              key: const Key('chat_voice_mode'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ChatVoiceRecordMode.hold,
                  label: Text(l10n.chatVoiceModeHold),
                ),
                ButtonSegment(
                  value: ChatVoiceRecordMode.tap,
                  label: Text(l10n.chatVoiceModeTap),
                ),
              ],
              selected: {ref.watch(chatVoiceRecordModeProvider)},
              onSelectionChanged: (s) =>
                  ref.read(chatVoiceRecordModeProvider.notifier).set(s.first),
            ),
          ),
          const SizedBox(height: Space.sm),
        ],
        ListTile(
          key: const Key('chat_media_size'),
          leading: const Icon(LucideIcons.images),
          title: size.when(
            data: (bytes) => Text(l10n.chatMediaSize(FormatUtils.bytes(bytes))),
            loading: () => Text(l10n.loading),
            error: (_, _) => Text(l10n.errUnexpected),
          ),
          trailing: TextButton(
            key: const Key('chat_media_clear'),
            onPressed: (size.value ?? 0) == 0
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await ref.read(chatRepositoryProvider).clearMedia();
                    ref.invalidate(chatMediaSizeProvider);
                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.chatMediaCleared)),
                    );
                  },
            child: Text(l10n.chatMediaClear),
          ),
        ),
      ],
    );
  }
}
