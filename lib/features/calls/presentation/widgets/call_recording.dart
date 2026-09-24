import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/ds/x_badge.dart';
import '../../../chat/presentation/chat_providers.dart';
import '../../data/call_chat.dart';
import '../../data/call_models.dart';
import '../call_transcript_screen.dart';
import '../calls_format.dart';
import '../calls_providers.dart';
import 'call_stage.dart';
import 'call_style.dart';

/// Where downloaded recordings are kept (app documents; a temp dir in tests).
final callRecordingsDirProvider = Provider<Future<Directory> Function()>(
  (_) =>
      () async => Directory(p.join((await getApplicationDocumentsDirectory()).path, 'call_recordings')),
);

// ---------------------------------------------------------------------------
// In call: «REC • 00:12» for everyone, one-time banner, confirmation
// ---------------------------------------------------------------------------

/// Red «REC • mm:ss» shown to every participant while the call is recorded
/// (legal transparency); [compact] is the dot + «REC» of the mini bar / PiP.
class CallRecIndicator extends ConsumerWidget {
  const CallRecIndicator({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rec = ref.watch(callControllerProvider.select((s) => s.inCall ? s.recording : CallRecordingState.none));
    if (!rec.active) return const SizedBox.shrink();
    final pal = context.callPalette;
    final style = TextStyle(color: CallPalette.ink, fontSize: compact ? 10 : 12, fontWeight: FontWeight.w700, letterSpacing: 0.6);
    return Semantics(
      label: context.l10n.callsRecordingBanner,
      liveRegion: true,
      excludeSemantics: true,
      child: DecoratedBox(
        key: Key(compact ? 'call_rec_compact' : 'call_rec_indicator'),
        decoration: BoxDecoration(
          color: pal.danger,
          borderRadius: BorderRadius.circular(XatBoxTokens.radiusPill),
          boxShadow: [BoxShadow(color: pal.danger.withValues(alpha: 0.45), blurRadius: 12)],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10, vertical: compact ? 2 : 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulseDot(size: compact ? 6 : 8),
              SizedBox(width: compact ? 4 : 6),
              Text('REC', style: style),
              if (!compact) ...[
                Text(' • ', style: style.copyWith(fontWeight: FontWeight.w500)),
                CallTimerText(since: (rec.startedAt ?? DateTime.now()).toLocal(), style: style.copyWith(letterSpacing: 0)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.size});
  final double size;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900), value: 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (callAnimationsEnabled(context)) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
    child: Container(
      width: widget.size,
      height: widget.size,
      decoration: const BoxDecoration(color: CallPalette.ink, shape: BoxShape.circle),
    ),
  );
}

/// «Звонок записывается» once per recording, over the call stage.
class CallRecordingBanner extends ConsumerStatefulWidget {
  const CallRecordingBanner({super.key});

  @override
  ConsumerState<CallRecordingBanner> createState() => _CallRecordingBannerState();
}

class _CallRecordingBannerState extends ConsumerState<CallRecordingBanner> {
  CallRecordingState? _shown;
  Timer? _timer;
  StreamSubscription<CallRecordingState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(callControllerProvider.notifier).recordingNotices.listen((r) {
      if (!mounted) return;
      setState(() => _shown = r);
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 5), _hide);
    });
  }

  void _hide() {
    if (mounted) setState(() => _shown = null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final l10n = context.l10n;
    final pal = context.callPalette;
    Widget banner() {
      final selfId = ref.read(currentUserProvider)?.id ?? '';
      final by = shown!.startedBy ?? '';
      final name = by.isEmpty || by == selfId ? '' : (ref.read(callPeopleProvider)[by]?.label ?? '');
      return ConstrainedBox(
        key: const Key('call_recording_banner'),
        constraints: const BoxConstraints(maxWidth: 440),
        child: CallGlass(
          radius: 18,
          strong: true,
          padding: const EdgeInsets.fromLTRB(Space.smd, Space.sm, Space.xs, Space.sm),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: pal.danger.withValues(alpha: 0.25), shape: BoxShape.circle),
                  child: Icon(LucideIcons.circleDot, size: 18, color: pal.danger),
                ),
              ),
              const SizedBox(width: Space.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.callsRecordingBanner,
                      style: const TextStyle(color: CallPalette.ink, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    if (name.isNotEmpty)
                      Text(
                        l10n.callsRecordingBannerBy(name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: pal.inkSecondary, fontSize: 12),
                      ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('call_recording_banner_close'),
                tooltip: l10n.close,
                onPressed: _hide,
                icon: Icon(LucideIcons.x, size: 18, color: pal.inkSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.4), end: Offset.zero).animate(a),
          child: child,
        ),
      ),
      child: shown == null ? const SizedBox.shrink() : KeyedSubtree(key: ValueKey(shown.recordingId), child: banner()),
    );
  }
}

/// Asks before starting: everyone will see the indicator.
Future<bool> showCallRecordConfirm(BuildContext context) async {
  final l10n = context.l10n;
  final t = context.tokens;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const Key('call_record_confirm'),
      icon: Icon(LucideIcons.circleDot, color: t.danger),
      title: Text(l10n.callsRecordConfirmTitle),
      content: Text(l10n.callsRecordConfirmBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
        FilledButton(key: const Key('call_record_confirm_start'), onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.callsRecordConfirmStart)),
      ],
    ),
  );
  return ok ?? false;
}

// ---------------------------------------------------------------------------
// Call card: recordings with download / open
// ---------------------------------------------------------------------------

/// Recordings of a call (participants only; hidden when recording is off or
/// the call has none).
class CallRecordingsSection extends ConsumerStatefulWidget {
  const CallRecordingsSection({super.key, required this.callId});
  final String callId;

  @override
  ConsumerState<CallRecordingsSection> createState() => _CallRecordingsSectionState();
}

class _CallRecordingsSectionState extends ConsumerState<CallRecordingsSection> {
  List<CallRecordingItem>? _items;
  Object? _error;
  bool _loading = false;
  bool _unavailable = false;

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final items = await ref.read(callsApiProvider).recordings(widget.callId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        // Off on the server, or not a participant: nothing to show.
        if (const {'FEATURE_DISABLED', 'CALL_NOT_FOUND', 'NOT_INVITED', 'PARTICIPANT_REMOVED'}.contains(e.code)) {
          _unavailable = true;
        } else {
          _error = e;
        }
      });
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(callsConfigProvider.select((c) => c.recordingEnabled));
    if (!enabled || _unavailable) return const SizedBox.shrink();
    if (_items == null && _error == null && !_loading) Future.microtask(_load);
    final items = _items ?? const <CallRecordingItem>[];
    final l10n = context.l10n;
    final t = context.tokens;
    if (items.isEmpty && _error == null) return const SizedBox.shrink();
    return Column(
      key: const Key('call_recordings'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.xs, Space.lg, Space.xs, Space.sm),
          child: Text(
            l10n.callsRecordings,
            style: TextStyle(color: t.textTertiary, fontSize: t.display.fontSizeMeta + 1, fontWeight: FontWeight.w600),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(borderRadius: t.cardRadius, boxShadow: t.shadowSm),
          child: Material(
            color: t.surface,
            shape: RoundedRectangleBorder(
              borderRadius: t.cardRadius,
              side: BorderSide(color: t.border, width: t.borderWidth),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                if (_error != null)
                  ListTile(
                    leading: Icon(LucideIcons.circleAlert, color: t.danger),
                    title: Text(CallsFormat.error(l10n, _error!)),
                    trailing: TextButton(onPressed: _load, child: Text(l10n.retry)),
                  ),
                for (final (i, r) in items.indexed) ...[
                  if (i > 0 || _error != null) Divider(height: 1, indent: 68, color: t.divider),
                  _RecordingTile(key: ValueKey('call_recording_${r.id}'), recording: r),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecordingTile extends ConsumerStatefulWidget {
  const _RecordingTile({super.key, required this.recording});
  final CallRecordingItem recording;

  @override
  ConsumerState<_RecordingTile> createState() => _RecordingTileState();
}

class _RecordingTileState extends ConsumerState<_RecordingTile> {
  double? _progress;
  File? _file;
  CancelToken? _cancel;

  CallRecordingItem get _r => widget.recording;
  String get _localName => '${_r.id}.${_r.isAudio ? 'ogg' : 'mp4'}';

  @override
  void initState() {
    super.initState();
    Future.microtask(_findDownloaded);
  }

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }

  Future<File> _target() async {
    final dir = await ref.read(callRecordingsDirProvider)();
    return File(p.join(dir.path, _localName));
  }

  Future<void> _findDownloaded() async {
    if (!_r.ready) return;
    try {
      final f = await _target();
      if (await f.exists() && mounted) setState(() => _file = f);
    } on Object {
      // No storage: offer the download.
    }
  }

  Future<void> _download() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final cancel = CancelToken();
    setState(() {
      _cancel = cancel;
      _progress = 0;
    });
    try {
      final target = await _target();
      await target.parent.create(recursive: true);
      final part = '${target.path}.part';
      await ref
          .read(callsApiProvider)
          .downloadRecording(
            _r,
            part,
            cancelToken: cancel,
            onProgress: (received, total) {
              if (mounted && total > 0) setState(() => _progress = received / total);
            },
          );
      await File(part).rename(target.path);
      if (mounted) setState(() => _file = target);
    } on CancelledException {
      // The user cancelled.
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e is AppException ? '${l10n.callsRecordingDownloadFailed}: ${CallsFormat.error(l10n, e)}' : l10n.callsRecordingDownloadFailed)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _progress = null;
          _cancel = null;
        });
      }
    }
  }

  /// Local override after a retry (queued) until the list reloads.
  String? _transcriptStatus;

  Future<void> _retryTranscript() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final t = await ref.read(callsApiProvider).retryTranscript(_r.id);
      if (mounted) setState(() => _transcriptStatus = t.status);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(CallsFormat.error(l10n, e))));
    }
  }

  Future<void> _open() async {
    final file = _file;
    if (file == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    if (!await file.exists()) {
      if (mounted) setState(() => _file = null);
      return;
    }
    final opened = await ref.read(chatFileOpenerProvider)(file.path, _r.contentType);
    if (!opened) messenger.showSnackBar(SnackBar(content: Text(l10n.callsRecordingNoApp)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final r = _r;
    final details = <String>[
      if (r.durationSec > 0) CallsFormat.duration(Duration(seconds: r.durationSec)),
      if (r.sizeBytes > 0) CallsFormat.fileSize(context, r.sizeBytes),
      if (r.startedByName.isNotEmpty) r.startedByName,
    ];
    final Widget trailing;
    if (!r.ready) {
      trailing = r.failed
          ? XBadge(l10n.callsRecordingFailed, tone: BadgeTone.danger, small: true)
          : XBadge(l10n.callsRecordingInProgress, tone: BadgeTone.info, small: true);
    } else if (_file != null) {
      trailing = IconButton(
        key: ValueKey('call_recording_open_${r.id}'),
        tooltip: l10n.callsRecordingOpen,
        onPressed: _open,
        icon: Icon(LucideIcons.play, color: t.primary),
      );
    } else if (_progress != null) {
      trailing = SizedBox.square(
        dimension: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: 30,
              child: CircularProgressIndicator(key: ValueKey('call_recording_progress_${r.id}'), value: _progress == 0 ? null : _progress, strokeWidth: 2.5),
            ),
            IconButton(
              tooltip: l10n.cancel,
              onPressed: () => _cancel?.cancel(),
              icon: Icon(LucideIcons.x, size: 14, color: t.textSecondary),
            ),
          ],
        ),
      );
    } else {
      trailing = IconButton(
        key: ValueKey('call_recording_download_${r.id}'),
        tooltip: l10n.callsRecordingDownload,
        onPressed: _download,
        icon: Icon(LucideIcons.download, color: t.primary),
      );
    }
    final transcription = ref.watch(callsConfigProvider.select((c) => c.transcriptionEnabled));
    final transcript = _transcriptStatus ?? r.transcriptStatus;
    final Widget? transcriptAction = !transcription || !r.ready || transcript == 'none'
        ? null
        : switch (transcript) {
            'complete' => TextButton.icon(
              key: ValueKey('call_transcript_open_${r.id}'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.padded),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CallTranscriptScreen(recordingId: r.id))),
              icon: const Icon(LucideIcons.fileText, size: 16),
              label: Text(l10n.callsTranscript),
            ),
            'failed' => TextButton.icon(
              key: ValueKey('call_transcript_retry_${r.id}'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.padded, foregroundColor: t.danger),
              onPressed: _retryTranscript,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: Text(l10n.callsTranscriptRetry),
            ),
            _ => Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: XBadge(l10n.callsTranscriptPending, key: ValueKey('call_transcript_pending_${r.id}'), tone: BadgeTone.info, small: true),
            ),
          };
    return ListTile(
      onTap: !r.ready ? null : (_file != null ? _open : (_progress == null ? _download : null)),
      leading: ExcludeSemantics(
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: r.failed ? t.dangerSoft : t.surfaceSubtle, borderRadius: t.controlRadius),
          child: Icon(r.isAudio ? LucideIcons.fileAudio : LucideIcons.fileVideo, size: 18, color: r.failed ? t.danger : t.textSecondary),
        ),
      ),
      title: Text(
        [r.isAudio ? l10n.callsRecordingAudio : l10n.callsRecordingVideo, CallsFormat.when(context, r.startedAt)].where((s) => s.isNotEmpty).join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w500),
      ),
      subtitle: details.isEmpty && transcriptAction == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (details.isNotEmpty)
                  Text(
                    details.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: t.textSecondary),
                  ),
                ?transcriptAction,
              ],
            ),
      trailing: trailing,
    );
  }
}
