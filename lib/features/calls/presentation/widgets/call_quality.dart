import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../../data/meetings.dart';
import '../calls_providers.dart';
import 'call_style.dart';
import '../../../../shared/widgets/app_sheet.dart';

/// «Качество» from «Ещё»: microphone processing (livekit AudioCaptureOptions,
/// on by default), music mode and traffic saving. Background blur is not
/// offered: livekit_client 2.12 has no native segmentation processor.
Future<void> showCallQualitySheet(BuildContext context) {
  final t = context.tokens;
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: t.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusXl))),
    builder: (_) => const _QualitySheet(),
  );
}

class _QualitySheet extends ConsumerWidget {
  const _QualitySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final q = ref.watch(callQualitySettingsProvider);
    final notifier = ref.read(callQualitySettingsProvider.notifier);
    final a = q.audio;
    void audio(CallAudioSettings next) => unawaited(notifier.set(q.copyWith(audio: next)));

    Widget label(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.xs, Space.smd, Space.xs, Space.xs),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(color: t.textTertiary, fontSize: t.display.fontSizeMeta, fontWeight: FontWeight.w600, letterSpacing: 0.6),
      ),
    );

    Widget toggle(Key key, IconData icon, String title, bool value, ValueChanged<bool>? onChanged, {String? subtitle}) => SwitchListTile(
      key: key,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.xs),
      secondary: Icon(icon, color: onChanged == null ? t.textDisabled : t.textSecondary),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle, style: TextStyle(color: t.textTertiary)),
      value: value,
      onChanged: onChanged,
    );

    final savers = [
      (CallDataSaver.off, l10n.callsDataSaverOff, LucideIcons.video),
      (CallDataSaver.lowVideo, l10n.callsDataSaverLow, LucideIcons.gauge),
      (CallDataSaver.audioOnly, l10n.callsDataSaverAudio, LucideIcons.videoOff),
    ];

    return SingleChildScrollView(
      key: const Key('call_quality_sheet'),
      // The sheet keeps its own bottom inset clear of the gesture bar.
      padding: EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.lg + MediaQuery.viewPaddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.xs),
            child: Text(l10n.callsQualitySettings, style: theme.textTheme.titleMedium?.copyWith(color: t.textPrimary, fontWeight: t.titleWeight)),
          ),
          label(l10n.callsQualityAudio),
          toggle(const Key('call_audio_noise'), LucideIcons.audioLines, l10n.callsNoiseSuppression, a.noiseSuppression && !a.musicMode,
              a.musicMode ? null : (v) => audio(a.copyWith(noiseSuppression: v))),
          toggle(const Key('call_audio_echo'), LucideIcons.ear, l10n.callsEchoCancellation, a.echoCancellation && !a.musicMode,
              a.musicMode ? null : (v) => audio(a.copyWith(echoCancellation: v))),
          toggle(const Key('call_audio_gain'), LucideIcons.volume2, l10n.callsAutoGain, a.autoGain && !a.musicMode,
              a.musicMode ? null : (v) => audio(a.copyWith(autoGain: v))),
          toggle(const Key('call_audio_music'), LucideIcons.music, l10n.callsMusicMode, a.musicMode, (v) => audio(a.copyWith(musicMode: v)),
              subtitle: l10n.callsMusicModeHint),
          label(l10n.callsDataSaver),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            children: [
              for (final (mode, text, icon) in savers)
                ChoiceChip(
                  key: ValueKey('call_data_saver_${mode.name}'),
                  avatar: Icon(icon, size: 16),
                  label: Text(text),
                  selected: q.dataSaver == mode,
                  onSelected: (_) => unawaited(notifier.set(q.copyWith(dataSaver: mode))),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xs, Space.xs, Space.xs, 0),
            child: Text(l10n.callsDataSaverHint, style: TextStyle(color: t.textTertiary, fontSize: t.display.fontSizeMeta + 1)),
          ),
          label(l10n.callsQualityVideo),
          ListTile(
            key: const Key('call_blur_unavailable'),
            enabled: false,
            contentPadding: const EdgeInsets.symmetric(horizontal: Space.xs),
            leading: const Icon(LucideIcons.sparkles),
            title: Text(l10n.callsBackgroundBlur),
            subtitle: Text(l10n.callsBackgroundBlurUnavailable),
          ),
        ],
      ),
    );
  }
}

/// Offers traffic saving when the connection stays poor (once per call).
class CallQualityPromptBanner extends ConsumerStatefulWidget {
  const CallQualityPromptBanner({super.key});

  @override
  ConsumerState<CallQualityPromptBanner> createState() => _CallQualityPromptBannerState();
}

class _CallQualityPromptBannerState extends ConsumerState<CallQualityPromptBanner> {
  bool _shown = false;
  Timer? _timer;
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(callControllerProvider.notifier).qualityPrompts.listen((_) {
      if (!mounted) return;
      setState(() => _shown = true);
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 20), _hide);
    });
  }

  void _hide() {
    if (mounted) setState(() => _shown = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  void _choose(CallDataSaver mode) {
    final notifier = ref.read(callQualitySettingsProvider.notifier);
    unawaited(notifier.set(ref.read(callQualitySettingsProvider).copyWith(dataSaver: mode)));
    _hide();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pal = context.callPalette;
    final inCall = ref.watch(callControllerProvider.select((s) => s.inCall));
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: !_shown || !inCall
          ? const SizedBox.shrink()
          : Padding(
              key: const Key('call_quality_prompt'),
              padding: const EdgeInsets.only(top: Space.sm),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: CallGlass(
                  radius: 18,
                  strong: true,
                  padding: const EdgeInsets.fromLTRB(Space.smd, Space.sm, Space.sm, Space.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.wifiOff, size: 18, color: pal.warning),
                          const SizedBox(width: Space.sm),
                          Expanded(
                            child: Text(
                              l10n.callsPoorNetworkTitle,
                              style: const TextStyle(color: CallPalette.ink, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: Space.xxs, left: 26),
                        child: Text(l10n.callsPoorNetworkText, style: TextStyle(color: pal.inkSecondary, fontSize: 13)),
                      ),
                      Wrap(
                        alignment: WrapAlignment.end,
                        children: [
                          TextButton(
                            key: const Key('call_quality_prompt_dismiss'),
                            onPressed: _hide,
                            child: Text(l10n.callsPoorNetworkDismiss, style: TextStyle(color: pal.inkSecondary)),
                          ),
                          TextButton(
                            key: const Key('call_quality_prompt_audio'),
                            onPressed: () => _choose(CallDataSaver.audioOnly),
                            child: Text(l10n.callsDataSaverAudio, style: const TextStyle(color: CallPalette.ink)),
                          ),
                          TextButton(
                            key: const Key('call_quality_prompt_accept'),
                            onPressed: () => _choose(CallDataSaver.lowVideo),
                            child: Text(l10n.callsPoorNetworkAccept, style: const TextStyle(color: CallPalette.ink, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
