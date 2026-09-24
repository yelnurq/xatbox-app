import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../../data/chat_models.dart';
import '../chat_formatters.dart';
import '../chat_providers.dart';
import '../messenger2_providers.dart';

/// Under a voice message: «Расшифровать» (when the server has a transcriber),
/// an animated progress while the shared transcript is prepared, then the
/// text, collapsible, with copy (hidden in chats that forbid copying).
class VoiceTranscriptView extends ConsumerStatefulWidget {
  const VoiceTranscriptView({super.key, required this.message});
  final ChatMessage message;

  @override
  ConsumerState<VoiceTranscriptView> createState() =>
      _VoiceTranscriptViewState();
}

class _VoiceTranscriptViewState extends ConsumerState<VoiceTranscriptView> {
  ChatTranscript? _local;
  bool _requesting = false;
  bool _expanded = true;
  bool _autoTried = false;

  ChatMessage get _m => widget.message;

  /// The server copy wins once it is final; the local answer covers the gap
  /// until the socket event arrives.
  ChatTranscript? get _transcript {
    final server = _m.transcript;
    if (server != null && !server.pending) return server;
    return _local ?? server;
  }

  Future<void> _request() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    try {
      final t = await ref.read(chatMessenger2ApiProvider).transcribe(_m.id);
      if (mounted) setState(() => _local = t);
    } on AppException catch (e) {
      if (mounted) {
        setState(() => _local = const ChatTranscript(status: 'failed'));
      }
      messenger?.showSnackBar(
        SnackBar(content: Text(ChatFormat.error(l10n, e))),
      );
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  void didUpdateWidget(covariant VoiceTranscriptView old) {
    super.didUpdateWidget(old);
    // A retry replaced a failed transcript: forget the stale local copy.
    if (_m.transcript != null && !_m.transcript!.pending) _local = null;
  }

  @override
  Widget build(BuildContext context) {
    final enabled =
        ref.watch(chatFeaturesProvider).value?.transcription ?? false;
    final t = _transcript;
    if (_m.seq <= 0 || _m.isDeleted || (!enabled && t == null)) {
      return const SizedBox.shrink();
    }
    if (enabled && t == null && !_autoTried && ref.watch(chatAutoTranscribeProvider)) {
      _autoTried = true;
      Future.microtask(_request);
    }
    final child = switch (t) {
      _ when _requesting || (t?.pending ?? false) => _progress(context),
      ChatTranscript(done: true) => _text(context, t),
      ChatTranscript(failed: true) => _failed(context, enabled),
      _ => _button(context),
    };
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return AnimatedSize(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topLeft,
      child: SizedBox(width: 236, child: child),
    );
  }

  Widget _button(BuildContext context) {
    final t = context.tokens;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: ValueKey('voice_transcribe_${_m.id}'),
        // Standard density + padded: a 48 dp touch target (ТЗ п.24.22).
        style: TextButton.styleFrom(
          foregroundColor: t.primary,
          visualDensity: VisualDensity.standard,
          padding: const EdgeInsets.symmetric(horizontal: Space.xs),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        onPressed: _request,
        icon: const Icon(LucideIcons.audioLines, size: 16),
        label: Text(context.l10n.chatTranscribe),
      ),
    );
  }

  Widget _progress(BuildContext context) {
    final t = context.tokens;
    return Padding(
      key: ValueKey('voice_transcribing_${_m.id}'),
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          _Dots(color: t.primary),
          const SizedBox(width: Space.sm),
          Text(
            context.l10n.chatTranscribing,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: t.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _failed(BuildContext context, bool enabled) {
    final t = context.tokens;
    return Row(
      key: ValueKey('voice_transcript_failed_${_m.id}'),
      children: [
        ExcludeSemantics(
          child: Icon(LucideIcons.circleAlert, size: 14, color: t.danger),
        ),
        const SizedBox(width: Space.xs),
        Flexible(
          child: Text(
            context.l10n.chatTranscriptFailed,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: t.textTertiary),
          ),
        ),
        if (enabled)
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.standard,
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            onPressed: _request,
            child: Text(context.l10n.chatTranscriptRetry),
          ),
      ],
    );
  }

  Widget _text(BuildContext context, ChatTranscript tr) {
    final t = context.tokens;
    final l10n = context.l10n;
    final noCopy = ref.watch(
      conversationProvider(
        _m.conversationId,
      ).select((s) => s.conversation?.protection.noForward ?? false),
    );
    final theme = Theme.of(context);
    final text = tr.text.trim();
    return Container(
      key: ValueKey('voice_transcript_${_m.id}'),
      margin: const EdgeInsets.only(top: Space.xs),
      // The header row is 48 dp tall (touch targets), so no top/right
      // padding of its own.
      padding: const EdgeInsets.fromLTRB(Space.sm, 0, 0, Space.xs),
      decoration: BoxDecoration(
        color: t.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(t.radiusSm),
        border: Border(left: BorderSide(color: t.primary, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(LucideIcons.audioLines, size: 14, color: t.primary),
              ),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Semantics(
                  container: true,
                  button: true,
                  expanded: _expanded,
                  child: InkWell(
                    key: ValueKey('voice_transcript_toggle_${_m.id}'),
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: kMinInteractiveDimension,
                      ),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              _expanded
                                  ? l10n.chatTranscriptHide
                                  : l10n.chatTranscriptShow,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: t.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ExcludeSemantics(
                            child: Icon(
                              _expanded
                                  ? LucideIcons.chevronUp
                                  : LucideIcons.chevronDown,
                              size: 14,
                              color: t.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (!noCopy && text.isNotEmpty)
                Semantics(
                  container: true,
                  button: true,
                  label: l10n.chatCopy,
                  child: InkResponse(
                    key: ValueKey('voice_transcript_copy_${_m.id}'),
                    radius: 18,
                    onTap: () async {
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      await Clipboard.setData(ClipboardData(text: text));
                      messenger?.showSnackBar(
                        SnackBar(content: Text(l10n.chatCopied)),
                      );
                    },
                    // Visual 14 px icon, 48 × 48 dp touch target.
                    child: SizedBox.square(
                      dimension: kMinInteractiveDimension,
                      child: Center(
                        child: Icon(
                          LucideIcons.copy,
                          size: 14,
                          color: t.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: Space.xs),
              child: Text(
                text.isEmpty ? l10n.chatTranscriptEmpty : text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: text.isEmpty ? t.textTertiary : t.textPrimary,
                  fontStyle: text.isEmpty ? FontStyle.italic : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Three pulsing dots (transcription in progress).
class _Dots extends StatefulWidget {
  const _Dots({required this.color});
  final Color color;

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: static dots instead of a looping pulse.
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_reduceMotion) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(
                  alpha: _reduceMotion
                      ? 0.6
                      : 0.25 + 0.75 * _pulse((_c.value - i * 0.2) % 1.0),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  static double _pulse(double x) => x < 0.5 ? x * 2 : (1 - x) * 2;
}
