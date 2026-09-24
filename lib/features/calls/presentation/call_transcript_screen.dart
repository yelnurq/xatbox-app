import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/ds/x_badge.dart';
import '../../../shared/widgets/state_view.dart';
import '../data/meetings.dart';
import 'calls_format.dart';
import 'calls_providers.dart';

/// Transcript of a call recording: search with highlighted matches, copy,
/// automatic «Ключевые фразы». Recordings open in the system player, so the
/// times are shown as text (no in-app seeking).
class CallTranscriptScreen extends ConsumerStatefulWidget {
  const CallTranscriptScreen({super.key, required this.recordingId, this.title = ''});

  final String recordingId;
  final String title;

  @override
  ConsumerState<CallTranscriptScreen> createState() => _CallTranscriptScreenState();
}

class _CallTranscriptScreenState extends ConsumerState<CallTranscriptScreen> {
  CallTranscript? _transcript;
  Object? _error;
  bool _loading = true;
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final t = await ref.read(callsApiProvider).transcript(widget.recordingId);
      if (mounted) {
        setState(() {
          _transcript = t;
          _error = null;
        });
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy(String text) async {
    final messenger = ScaffoldMessenger.of(context);
    final done = context.l10n.callsTranscriptCopied;
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(SnackBar(content: Text(done)));
  }

  static String _clock(int sec) => CallsFormat.duration(Duration(seconds: sec));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = _transcript;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.callsTranscript),
        actions: [
          if (t != null && t.ready && t.segments.isNotEmpty)
            IconButton(
              key: const Key('transcript_copy'),
              tooltip: l10n.callsTranscriptCopy,
              icon: const Icon(LucideIcons.copy),
              onPressed: () => _copy(t.plainText),
            ),
        ],
      ),
      body: t == null
          ? (_loading ? const StateView.loading() : StateView.error(message: CallsFormat.error(l10n, _error ?? ''), onRetry: _load))
          : t.pending
          ? StateView.empty(title: l10n.callsTranscriptPending, icon: LucideIcons.hourglass)
          : t.failed
          ? StateView.error(message: l10n.callsTranscriptFailed, onRetry: _load)
          : _body(context, t),
    );
  }

  Widget _body(BuildContext context, CallTranscript t) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final q = _query.trim().toLowerCase();
    final segments = q.isEmpty ? t.segments : t.segments.where((s) => s.text.toLowerCase().contains(q)).toList();
    final matches = q.isEmpty ? 0 : t.segments.fold<int>(0, (n, s) => n + q.allMatches(s.text.toLowerCase()).length);
    return ListView(
      key: const Key('transcript_view'),
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.xl),
      children: [
        TextField(
          key: const Key('transcript_search'),
          controller: _search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.callsTranscriptSearch,
            prefixIcon: const Icon(LucideIcons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: l10n.cancel,
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => setState(() {
                      _search.clear();
                      _query = '';
                    }),
                  ),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        if (q.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xs, Space.sm, Space.xs, 0),
            child: Text(l10n.callsTranscriptMatches(matches), key: const Key('transcript_matches'), style: TextStyle(color: tokens.textTertiary)),
          ),
        if (q.isEmpty && t.keyPhrases.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          DecoratedBox(
            key: const Key('transcript_key_phrases'),
            decoration: BoxDecoration(color: tokens.primarySoft, borderRadius: tokens.cardRadius),
            child: Padding(
              padding: const EdgeInsets.all(Space.smd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.sparkles, size: 16, color: tokens.primary),
                          const SizedBox(width: Space.xs),
                          Text(l10n.callsTranscriptKeyPhrases, style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      XBadge(l10n.callsTranscriptAutomatic, tone: BadgeTone.info, small: true),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Text(l10n.callsTranscriptKeyPhrasesNote, style: TextStyle(color: tokens.textSecondary, fontSize: tokens.display.fontSizeMeta + 1)),
                  const SizedBox(height: Space.sm),
                  for (final p in t.keyPhrases)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 52,
                            child: Text(
                              _clock(p.startSec),
                              style: TextStyle(color: tokens.primary, fontFeatures: const [FontFeature.tabularFigures()], fontSize: tokens.display.fontSizeMeta + 1),
                            ),
                          ),
                          Expanded(child: Text(p.text, style: TextStyle(color: tokens.textPrimary))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: Space.md),
        if (t.segments.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Text(l10n.callsTranscriptEmpty, textAlign: TextAlign.center, style: TextStyle(color: tokens.textTertiary)),
          ),
        for (final s in segments)
          Padding(
            key: ValueKey('transcript_segment_${s.index}'),
            padding: const EdgeInsets.only(bottom: Space.md),
            child: GestureDetector(
              onLongPress: () => _copy(s.text),
              onSecondaryTap: () => _copy(s.text),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_clock(s.startSec)} – ${_clock(s.endSec)}',
                    style: TextStyle(
                      color: tokens.textTertiary,
                      fontSize: tokens.display.fontSizeMeta,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: Space.xxs),
                  SelectableText.rich(
                    TextSpan(children: highlightMatches(s.text, q, TextStyle(color: tokens.textPrimary, height: 1.45), tokens.selection)),
                  ),
                ],
              ),
            ),
          ),
        Text(l10n.callsTranscriptNoSeek, style: TextStyle(color: tokens.textTertiary, fontSize: tokens.display.fontSizeMeta)),
      ],
    );
  }
}

/// Splits [text] into spans with every case-insensitive [query] match marked.
List<TextSpan> highlightMatches(String text, String query, TextStyle style, Color highlight) {
  if (query.isEmpty) return [TextSpan(text: text, style: style)];
  final lower = text.toLowerCase();
  final spans = <TextSpan>[];
  var i = 0;
  while (true) {
    final hit = lower.indexOf(query, i);
    if (hit < 0) break;
    if (hit > i) spans.add(TextSpan(text: text.substring(i, hit), style: style));
    spans.add(TextSpan(text: text.substring(hit, hit + query.length), style: style.copyWith(backgroundColor: highlight, fontWeight: FontWeight.w600)));
    i = hit + query.length;
  }
  if (i < text.length) spans.add(TextSpan(text: text.substring(i), style: style));
  return spans;
}
