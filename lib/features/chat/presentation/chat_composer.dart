import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../core/localization/localization.dart';
import '../../../core/platform/desktop.dart';
import '../data/voice_file.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/diagnostic_log.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/state_view.dart';
import '../data/chat_mentions.dart';
import '../data/chat_models.dart';
import '../data/chat_photo.dart';
import 'chat_formatters.dart' as fmt;
import 'chat_providers.dart';
import 'desktop_camera_capture.dart';
import 'message_bubble.dart';
import 'scheduled/scheduled_widgets.dart';
import 'scheduled/when_picker.dart';
import 'status/chat_status_providers.dart';
import 'stickers/chat_sticker_picker.dart';
import 'voice_record_mode.dart';
import '../../../shared/widgets/app_sheet.dart';

/// Composer (ТЗ п.24.7, п.24.8): text with `@mentions` in groups,
/// attachments and contacts, hold-to-record voice with slide-to-cancel and
/// lock, preview before sending. The microphone permission is requested only
/// when the user starts recording.
class ChatComposer extends ConsumerStatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSendText,
    required this.onSendFile,
    required this.onTyping,
    required this.onRecording,
    this.onSendContact,
    this.replyTo,
    this.editing,
    this.onCancelContext,
    this.onSendSticker,
    this.memberNames = const {},
    this.mentionCandidates = const [],
    this.initialText = '',
    this.onTextChanged,
    this.pendingFiles = const [],
    this.onRemovePending,
    this.onCreatePoll,
    this.onScheduleText,
    this.scheduledCount = 0,
    this.onOpenScheduled,
    this.onScheduleWhenOnline,
    this.onEditLast,
  });

  /// Desktop: ↑ in the empty input edits the caller's last message.
  final VoidCallback? onEditLast;

  /// «Отправить, когда появится в сети» in the send-later sheet (1:1 chats
  /// whose peer shows the online status); true when scheduled.
  final Future<bool> Function(String text, List<String> mentions)?
  onScheduleWhenOnline;

  /// «Опрос» in the attach grid (groups and channels only).
  final VoidCallback? onCreatePoll;

  /// Long press on send → «Отправить позже»; true when scheduled.
  final Future<bool> Function(String text, List<String> mentions, DateTime at)?
  onScheduleText;

  /// Unsent scheduled messages of the chat (strip above the input).
  final int scheduledCount;
  final VoidCallback? onOpenScheduled;

  /// Files waiting to be sent with the next send (content shared from
  /// another app); the send button is enabled while there are any.
  final List<ChatPickedFile> pendingFiles;
  final void Function(int index)? onRemovePending;

  /// Draft restored into an empty input.
  final String initialText;

  /// Every edit of the text (drafts).
  final ValueChanged<String>? onTextChanged;

  /// Text and the ids of the members mentioned in it.
  final Future<void> Function(String text, List<String> mentions) onSendText;
  final Future<void> Function({
    required String path,
    required String filename,
    bool voice,
    int? durationMs,
  })
  onSendFile;
  final Future<void> Function(ChatUser user)? onSendContact;
  final VoidCallback onTyping;
  final void Function(bool started) onRecording;
  final ChatMessage? replyTo;
  final ChatMessage? editing;
  final VoidCallback? onCancelContext;

  /// Sticker chosen in the emoji / sticker picker (null: emoji only).
  final void Function(ChatSticker sticker)? onSendSticker;
  final Map<String, String> memberNames;

  /// Members that can be mentioned (group chats, without the caller).
  final List<ChatMember> mentionCandidates;

  @override
  ConsumerState<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends ConsumerState<ChatComposer> {
  final _text = TextEditingController();
  final _recorder = AudioRecorder();
  bool _sending = false;
  bool _recording = false;
  bool _locked = false;
  bool _cancelHint = false;
  DateTime? _recordStart;
  Timer? _tick;
  String? _previewPath;
  int _previewMs = 0;

  /// File the recorder was told to write. Kept so a `stop()` that fails or
  /// never answers still yields the recording instead of losing it.
  String? _recordPath;
  double _dragDx = 0;
  double _dragDy = 0;

  /// Desktop: the loudness of the last seconds, newest last, 0…1. Drawn as
  /// a live waveform in the recording bar so it is obvious the microphone
  /// is hearing something. The phone's bar is unchanged.
  final List<double> _levels = [];
  StreamSubscription<Amplitude>? _amplitude;

  /// How many bars the waveform keeps; at 100 ms a bar that is about six
  /// seconds of sound, which fits the bar at any sane window width.
  static const _maxLevels = 60;

  /// Members inserted through the picker: id → label.
  final Map<String, String> _picked = {};
  ({int start, String query})? _mention;

  /// Text typed before an edit started, restored when it ends.
  String _beforeEdit = '';
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    if (widget.editing != null) {
      _text.text = widget.editing!.body;
    } else if (widget.initialText.isNotEmpty) {
      _text.text = widget.initialText;
    }
  }

  @override
  void didUpdateWidget(covariant ChatComposer old) {
    super.didUpdateWidget(old);
    if (widget.editing != null && widget.editing?.id != old.editing?.id) {
      if (old.editing == null) _beforeEdit = _text.text;
      _setText(widget.editing!.body);
    }
    if (widget.editing == null && old.editing != null) {
      _setText(_beforeEdit);
      _beforeEdit = '';
    }
    if (widget.editing == null &&
        !_touched &&
        _text.text.isEmpty &&
        widget.initialText.isNotEmpty &&
        widget.initialText != old.initialText) {
      _setText(widget.initialText);
    }
  }

  void _setText(String text) {
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  void dispose() {
    _text.dispose();
    _tick?.cancel();
    _stopLevels();
    _recorder.dispose();
    super.dispose();
  }

  KeyEventResult _onComposerKey(FocusNode node, KeyEvent e) {
    if (!isDesktop || e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowUp &&
        widget.onEditLast != null &&
        widget.editing == null &&
        _text.text.isEmpty &&
        !HardwareKeyboard.instance.isShiftPressed &&
        !HardwareKeyboard.instance.isAltPressed) {
      widget.onEditLast!();
      return KeyEventResult.handled;
    }
    if (e.logicalKey != LogicalKeyboardKey.enter && e.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    // Shift+Enter and an unfinished IME composition keep the default.
    if (HardwareKeyboard.instance.isShiftPressed || _text.value.composing.isValid) {
      return KeyEventResult.ignored;
    }
    unawaited(_send());
    return KeyEventResult.handled;
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if ((text.isEmpty && widget.pendingFiles.isEmpty) || _sending) return;
    final mentions = widget.editing == null
        ? ChatMentions.resolve(text, _picked)
        : const <String>[];
    setState(() => _sending = true);
    try {
      await widget.onSendText(text, mentions);
      _text.clear();
      _picked.clear();
      _mention = null;
      _touched = true;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ---- mentions ------------------------------------------------------------------------

  /// «Отправить позже» (long press on send).
  Future<void> _sendLater() async {
    final schedule = widget.onScheduleText;
    final text = _text.text.trim();
    if (schedule == null || _sending || (text.isEmpty && widget.pendingFiles.isEmpty)) {
      return;
    }
    unawaited(HapticFeedback.mediumImpact());
    final whenOnline = widget.onScheduleWhenOnline;
    final choice = await showSendLaterPicker(
      context,
      title: context.l10n.scheduleSendLater,
      whenOnline: whenOnline != null,
    );
    if (choice == null || !mounted) return;
    final mentions = ChatMentions.resolve(text, _picked);
    setState(() => _sending = true);
    try {
      final ok = choice is WhenOnlineChoice && whenOnline != null
          ? await whenOnline(text, mentions)
          : choice is DateTime && await schedule(text, mentions, choice);
      if (ok) {
        _text.clear();
        _picked.clear();
        _mention = null;
        _touched = true;
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _onChanged(String value) {
    _touched = true;
    widget.onTyping();
    if (widget.editing == null) widget.onTextChanged?.call(value);
    final cursor = _text.selection.baseOffset;
    setState(() {
      _mention = widget.mentionCandidates.isEmpty || widget.editing != null
          ? null
          : ChatMentions.activeQuery(value, cursor < 0 ? value.length : cursor);
    });
  }

  List<ChatMember> get _mentionOptions {
    final m = _mention;
    if (m == null) return const [];
    return ChatMentions.filter(
      widget.mentionCandidates,
      m.query,
      label: (c) => c.label,
      email: (c) => c.email,
    );
  }

  void _insertMention(ChatMember member) {
    final m = _mention;
    if (m == null) return;
    final cursor = _text.selection.baseOffset < 0
        ? _text.text.length
        : _text.selection.baseOffset;
    final out = ChatMentions.insert(
      _text.text,
      start: m.start,
      cursor: cursor,
      label: member.label,
    );
    _text.value = TextEditingValue(
      text: out.text,
      selection: TextSelection.collapsed(offset: out.cursor),
    );
    setState(() {
      _picked[member.userId] = member.label;
      _mention = null;
    });
  }

  // ---- attachments -----------------------------------------------------------------------

  /// The tiles of the attach picker, in the order both the sheet and the
  /// desktop dialog show them.
  List<AttachOption> _attachOptions(BuildContext ctx) {
    final l10n = ctx.l10n;
    final t = ctx.tokens;
    return [
      // On the phone this is image_picker's camera; on the desktop, where
      // image_picker has none, it is the WebRTC capture window.
      (
        value: 'camera',
        icon: LucideIcons.camera,
        label: l10n.chatAttachCamera,
        bg: t.labelBlue,
        fg: t.labelBlueText,
      ),
      (
        value: 'gallery',
        icon: LucideIcons.images,
        label: l10n.chatAttachGallery,
        bg: t.labelPurple,
        fg: t.labelPurpleText,
      ),
      (
        value: 'file',
        icon: LucideIcons.fileText,
        label: l10n.chatAttachmentFile,
        bg: t.labelGreen,
        fg: t.labelGreenText,
      ),
      if (widget.onSendContact != null)
        (
          value: 'contact',
          icon: LucideIcons.userRound,
          label: l10n.chatAttachContact,
          bg: t.labelYellow,
          fg: t.labelYellowText,
        ),
      if (widget.onCreatePoll != null)
        (
          value: 'poll',
          icon: LucideIcons.listChecks,
          label: l10n.pollAttach,
          bg: t.primarySoft,
          fg: t.primary,
        ),
    ];
  }

  Future<void> _attach() async {
    // Desktop: a dialog in the middle of the window, as everywhere else in
    // the desktop app; a sheet sliding up from the bottom of a 27" screen
    // belongs to a phone. The phone keeps its sheet exactly as it was.
    final choice = isDesktop
        ? await showDialog<String>(
            context: context,
            builder: (ctx) => AttachDialog(options: _attachOptions(ctx)),
          )
        : await showAppSheet<String>(
            context: context,
            showDragHandle: true,
            builder: (ctx) {
              final t = ctx.tokens;
              final options = _attachOptions(ctx);
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.md,
                    0,
                    Space.md,
                    Space.lg,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceAround,
                    runSpacing: Space.md,
                    children: [
                      for (final o in options)
                        SizedBox(
                          width: 80,
                          child: InkWell(
                            key: Key('attach_${o.value}'),
                            borderRadius: BorderRadius.circular(t.radiusMd),
                            onTap: () => Navigator.pop(ctx, o.value),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: Space.xs,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: o.bg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(o.icon, color: o.fg, size: 26),
                                  ),
                                  const SizedBox(height: Space.xs + 2),
                                  Text(
                                    o.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(ctx).textTheme.labelMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
    if (!mounted) return;
    switch (choice) {
      case 'camera':
        await _captureFromCamera();
      case 'gallery':
        await _pickMedia(ChatMediaSource.gallery);
      case 'file':
        await _pickFiles();
      case 'contact':
        await _pickContact();
      case 'poll':
        widget.onCreatePoll?.call();
    }
  }

  /// «Камера»: the phone hands this to image_picker, the desktop opens its
  /// own capture window (image_picker has no camera on Windows, macOS or
  /// Linux, so the option used to be hidden there).
  Future<void> _captureFromCamera() async {
    if (!isDesktop) return _pickMedia(ChatMediaSource.camera);
    final shot = await showDesktopCameraCapture(context);
    if (shot == null || !mounted) return;
    await widget.onSendFile(path: shot.path, filename: shot.name);
  }

  Future<void> _pickMedia(ChatMediaSource source) async {
    final List<ChatPickedFile> files;
    try {
      files = await ref.read(chatMediaPickerProvider)(source);
    } on Object catch (e) {
      DiagnosticLog.warn('chat', 'media pick failed', error: e);
      return;
    }
    for (final f in files) {
      // Desktop: the image picker cannot scale or turn photos there.
      final ready = isDesktop ? await prepareChatPhoto(f.path, f.name) : f;
      await widget.onSendFile(path: ready.path, filename: ready.name);
    }
  }

  Future<void> _pickFiles() async {
    final files = await FilePicker.pickFiles();
    for (final f in files) {
      final path = f.path;
      if (path == null) continue;
      await widget.onSendFile(path: path, filename: f.name);
    }
  }

  Future<void> _pickContact() async {
    final user = await showAppSheet<ChatUser>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const ContactPickerSheet(),
    );
    if (user == null || !mounted) return;
    await widget.onSendContact?.call(user);
  }

  // ---- voice ---------------------------------------------------------------------------

  Future<bool> _ensureMic() async {
    // permission_handler is phone-only here: desktop asks the recorder,
    // which triggers the OS microphone prompt where there is one.
    if (isDesktop) {
      if (await _recorder.hasPermission()) return true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.chatMicDenied)));
      }
      return false;
    }
    final status = await Permission.microphone.request();
    if (status.isGranted) return true;
    if (!mounted) return false;
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.chatMicDenied),
        action: status.isPermanentlyDenied
            ? SnackBarAction(
                label: l10n.chatOpenSettings,
                onPressed: openAppSettings,
              )
            : null,
      ),
    );
    return false;
  }

  /// True while the finger is still on the mic button. A recorder that only
  /// becomes ready after release (e.g. behind the permission dialog) is
  /// dropped instead of recording with no way to stop it by the gesture.
  bool _holding = false;

  /// [locked]: tap-to-record (or a screen reader) starts straight in the
  /// locked state with stop / send / cancel buttons.
  /// A start that is still waiting for the recorder: a second press meanwhile
  /// must not start another one (two ticking timers, one never cancelled).
  bool _starting = false;

  Future<void> _startRecording({bool locked = false}) async {
    if (_recording || _starting) return;
    _starting = true;
    _holding = !locked;
    _locked = locked;
    if (!await _ensureMic()) {
      _locked = false;
      _starting = false;
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final path = p.join(
        dir.path,
        'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      _recordPath = path;
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );
      if (!mounted) {
        // The composer went away while the recorder was starting: nothing
        // must keep running on its behalf.
        await _recorder.cancel();
        return;
      }
      if (!_holding && !_locked) {
        await _recorder.cancel();
        return;
      }
      setState(() {
        _recording = true;
        _locked = locked;
        _cancelHint = false;
        _recordStart = DateTime.now();
        _dragDx = 0;
        _dragDy = 0;
      });
      widget.onRecording(true);
      // One ticker at a time, and one that stops itself once the widget is
      // gone: a timer that outlived its State called setState on nothing at
      // 200 ms for hours (67 000 reports from one desktop in a day).
      _tick?.cancel();
      _tick = Timer.periodic(const Duration(milliseconds: 200), (t) {
        if (!mounted || !_recording) {
          t.cancel();
          return;
        }
        setState(() {});
      });
      _listenToLevels();
    } on Object catch (e) {
      DiagnosticLog.warn('chat', 'recording start failed', error: e);
      _locked = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatVoiceStartFailed)),
        );
      }
    } finally {
      _starting = false;
    }
  }

  /// Feeds [_levels] (the live waveform) from the recorder. A recorder that
  /// reports no amplitude (or throws) simply leaves the waveform empty and
  /// the bar looks as it always did.
  void _listenToLevels() {
    _levels.clear();
    _stopLevels();
    _amplitude = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen(
          (a) {
            if (!mounted || !_recording) return;
            setState(() {
              _levels.add(_normalizeDbfs(a.current));
              if (_levels.length > _maxLevels) _levels.removeAt(0);
            });
          },
          onError: (Object e) =>
              DiagnosticLog.warn('chat', 'recording level unavailable', error: e),
          cancelOnError: true,
        );
  }

  /// dBFS (−160…0, silence at the bottom) → 0…1. Everything under −50 dB is
  /// room noise, so the floor sits there and quiet speech still shows.
  static double _normalizeDbfs(double dbfs) {
    if (!dbfs.isFinite) return 0;
    const floor = -50.0;
    return ((dbfs.clamp(floor, 0.0) - floor) / -floor).clamp(0.0, 1.0);
  }

  void _stopLevels() {
    _amplitude?.cancel();
    _amplitude = null;
  }

  Future<void> _stopRecording({required bool cancel}) async {
    if (!_recording) return;
    _tick?.cancel();
    _stopLevels();
    widget.onRecording(false);
    // Read before the state is reset: a locked recording is previewed, a
    // hold-and-release one is sent straight away.
    final wasLocked = _locked;
    final elapsed = DateTime.now()
        .difference(_recordStart ?? DateTime.now())
        .inMilliseconds;
    final recorded = _recordPath;
    String? path;
    var stopFailed = false;
    try {
      if (cancel) {
        await _recorder.cancel();
      } else {
        // A recorder that never answers must not leave the bar running with
        // nothing sent: after the timeout the written file is used as it is.
        path = await _recorder.stop().timeout(const Duration(seconds: 5));
      }
    } on Object catch (e) {
      DiagnosticLog.warn('chat', 'recording stop failed', error: e);
      stopFailed = !cancel;
    }
    if (!cancel && path == null && recorded != null && _hasBytes(recorded)) {
      path = recorded; // stop() failed or timed out, the file is there
      stopFailed = false;
    }
    _recordPath = null;
    if (!mounted) return;
    setState(() {
      _recording = false;
      _locked = false;
    });
    if (cancel || path == null || elapsed < 700) {
      if (path != null) _deleteQuietly(path);
      if (stopFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.chatVoiceSendFailed)),
        );
      }
      return;
    }
    if (wasLocked) {
      setState(() {
        _previewPath = path;
        _previewMs = elapsed;
      });
      return;
    }
    if (isDesktop) await markVoiceAsAudioMp4(path);
    await widget.onSendFile(
      path: path,
      filename: p.basename(path),
      voice: true,
      durationMs: elapsed,
    );
  }

  bool _hasBytes(String path) {
    try {
      final f = File(path);
      return f.existsSync() && f.lengthSync() > 0;
    } on FileSystemException {
      return false;
    }
  }

  Future<void> _sendPreview() async {
    final path = _previewPath;
    if (path == null) return;
    setState(() => _previewPath = null);
    if (isDesktop) await markVoiceAsAudioMp4(path);
    await widget.onSendFile(
      path: path,
      filename: p.basename(path),
      voice: true,
      durationMs: _previewMs,
    );
  }

  void _discardPreview() {
    final path = _previewPath;
    setState(() => _previewPath = null);
    if (path != null) _deleteQuietly(path);
  }

  void _deleteQuietly(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } on FileSystemException {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final hasText =
        _text.text.trim().isNotEmpty || widget.pendingFiles.isNotEmpty;
    final options = _mentionOptions;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (options.isNotEmpty && !_recording && _previewPath == null)
            Material(
              key: const Key('mention_picker'),
              elevation: 2,
              color: tokens.surface,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final m in options)
                      ListTile(
                        key: ValueKey('mention_option_${m.userId}'),
                        dense: true,
                        leading: InitialsAvatar(
                          label: m.label,
                          colorKey: m.userId,
                          radius: 14,
                        ),
                        title: Text(m.label),
                        subtitle: _mentionSubtitle(m, tokens),
                        onTap: () => _insertMention(m),
                      ),
                  ],
                ),
              ),
            ),
          if (widget.pendingFiles.isNotEmpty &&
              widget.editing == null &&
              !_recording &&
              _previewPath == null)
            Container(
              key: const Key('composer_pending_files'),
              height: 48,
              decoration: BoxDecoration(
                color: tokens.surface,
                border: Border(
                  top: BorderSide(
                    color: tokens.divider,
                    width: tokens.borderWidth,
                  ),
                ),
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.sm,
                  vertical: Space.xs,
                ),
                itemCount: widget.pendingFiles.length,
                separatorBuilder: (_, _) => const SizedBox(width: Space.xs),
                itemBuilder: (context, i) => InputChip(
                  key: ValueKey('pending_file_$i'),
                  avatar: const Icon(LucideIcons.paperclip, size: 16),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      widget.pendingFiles[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  deleteButtonTooltipMessage: l10n.chatRemoveAttachment,
                  onDeleted: widget.onRemovePending == null
                      ? null
                      : () => widget.onRemovePending!(i),
                ),
              ),
            ),
          if (widget.replyTo != null || widget.editing != null)
            _ContextStrip(
              message: (widget.editing ?? widget.replyTo)!,
              editing: widget.editing != null,
              names: widget.memberNames,
              onCancel: widget.onCancelContext,
            ),
          if (widget.scheduledCount > 0 &&
              widget.onOpenScheduled != null &&
              widget.editing == null)
            ScheduledIndicator(
              count: widget.scheduledCount,
              onTap: widget.onOpenScheduled!,
            ),
          if (_previewPath != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.sm,
                vertical: Space.xs,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.chatVoiceCancel,
                    icon: Icon(LucideIcons.trash2, color: tokens.danger),
                    onPressed: _discardPreview,
                  ),
                  Expanded(
                    child: VoicePlayer(
                      attachment: ChatAttachment(
                        id: 'preview',
                        conversationId: '',
                        filename: '',
                        mimeType: 'audio/mp4',
                        size: 0,
                        kind: 'voice',
                        hasThumbnail: false,
                        scanStatus: '',
                        durationMs: _previewMs,
                      ),
                      localPath: _previewPath,
                    ),
                  ),
                  IconButton.filled(
                    tooltip: l10n.chatSend,
                    icon: const Icon(LucideIcons.send),
                    onPressed: _sendPreview,
                  ),
                ],
              ),
            )
          else if (_recording)
            _RecordingBar(
              elapsed: DateTime.now().difference(
                _recordStart ?? DateTime.now(),
              ),
              locked: _locked,
              cancelHint: _cancelHint,
              levels: _levels,
              onCancel: () => _stopRecording(cancel: true),
              onStop: () => _stopRecording(cancel: false),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.sm,
                Space.xs + 2,
                Space.sm,
                Space.xs + 2,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: tokens.border,
                          width: tokens.borderWidth,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            // Desktop: Enter sends, Shift+Enter breaks the
                            // line (as in desktop messengers).
                            child: Focus(
                              canRequestFocus: false,
                              skipTraversal: true,
                              onKeyEvent: _onComposerKey,
                              child: TextField(
                                key: const Key('chat_input'),
                                controller: _text,
                                minLines: 1,
                                maxLines: 6,
                                textCapitalization: TextCapitalization.sentences,
                                keyboardType: TextInputType.multiline,
                                onChanged: _onChanged,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontSize: tokens.display.fontSizeBase,
                                ),
                                decoration: InputDecoration(
                                  hintText: l10n.chatMessageHint,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.fromLTRB(
                                    Space.md,
                                    Space.smd,
                                    Space.xs,
                                    Space.smd,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            key: const Key('chat_emoji_stickers'),
                            tooltip: l10n.chatStickers,
                            icon: Icon(
                              LucideIcons.smile,
                              color: tokens.textTertiary,
                            ),
                            onPressed: _sending ? null : _openPicker,
                          ),
                          IconButton(
                            key: const Key('chat_attach'),
                            tooltip: l10n.chatAttach,
                            icon: Icon(
                              LucideIcons.paperclip,
                              color: tokens.textTertiary,
                            ),
                            onPressed: _sending || widget.editing != null
                                ? null
                                : _attach,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.xs + 2),
                  // 48 dp slot: the visible circle stays 44 dp, the touch
                  // target is 48 dp (ТЗ п.24.22).
                  SizedBox(
                    width: kMinInteractiveDimension,
                    height: kMinInteractiveDimension,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      // Starts at 0.6 so the button is tappable from the
                      // first frame of the swap.
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: Tween(begin: 0.6, end: 1.0).animate(anim),
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                      child: hasText || widget.editing != null
                          // One screen-reader node: send on tap, schedule
                          // on long press.
                          ? MergeSemantics(
                              key: const ValueKey('chat_send_slot'),
                              child: Semantics(
                              onLongPressHint:
                                  widget.onScheduleText == null ||
                                      widget.editing != null
                                  ? null
                                  : l10n.scheduleSendLater,
                              child: GestureDetector(
                              key: const Key('chat_send_long_press'),
                              onLongPress:
                                  widget.onScheduleText == null ||
                                      widget.editing != null
                                  ? null
                                  : _sendLater,
                              // Desktop: right click on Send.
                              onSecondaryTap:
                                  widget.onScheduleText == null ||
                                      widget.editing != null
                                  ? null
                                  : _sendLater,
                              // A tooltip claims the long press on phones;
                              // keep it for semantics only when scheduling.
                              child: TooltipTheme(
                              data: TooltipTheme.of(context).copyWith(
                                triggerMode: widget.onScheduleText == null
                                    ? null
                                    : TooltipTriggerMode.manual,
                              ),
                              child: IconButton.filled(
                              key: const Key('chat_send'),
                              tooltip: l10n.chatSend,
                              style: IconButton.styleFrom(
                                backgroundColor: tokens.primary,
                                foregroundColor: tokens.textInverse,
                                minimumSize: const Size.square(44),
                                visualDensity: VisualDensity.standard,
                                tapTargetSize: MaterialTapTargetSize.padded,
                              ),
                              icon: _sending
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: tokens.textInverse,
                                      ),
                                    )
                                  : Icon(
                                      widget.editing != null
                                          ? LucideIcons.check
                                          : LucideIcons.sendHorizontal,
                                    ),
                              onPressed: _sending ? null : _send,
                            ),
                            ),
                            ),
                            ),
                            )
                          : _micButton(context),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Emoji go into the text at the cursor; a sticker is sent at once.
  Future<void> _openPicker() async {
    final res = await ChatStickerPickerSheet.show(
      context,
      stickers: widget.onSendSticker != null && widget.editing == null,
    );
    if (res == null || !mounted) return;
    final sticker = res.sticker;
    if (sticker != null) {
      widget.onSendSticker?.call(sticker);
      return;
    }
    final emoji = res.emoji;
    if (emoji == null) return;
    final value = _text.value;
    final sel = value.selection;
    final start = sel.isValid ? sel.start : value.text.length;
    final end = sel.isValid ? sel.end : value.text.length;
    _text.value = TextEditingValue(
      text: value.text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    _onChanged(_text.text);
  }

  /// Status («🌴 В отпуске») or the email under a mention candidate.
  Widget? _mentionSubtitle(ChatMember m, XatBoxTokens tokens) {
    final status = watchUserStatus(ref, m.userId, m.status);
    final text = status != null
        ? ChatStatusFormat.line(context, status, withUntil: false)
        : m.email;
    if (text.isEmpty) return null;
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: tokens.textMuted),
    );
  }

  Widget _micCircle(XatBoxTokens tokens) => SizedBox.square(
    dimension: kMinInteractiveDimension,
    child: Center(
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: tokens.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(LucideIcons.mic, color: tokens.textInverse, size: 22),
      ),
    ),
  );

  Widget _micButton(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final mode = ChatVoiceRecordMode.effective(
      context,
      ref.watch(chatVoiceRecordModeProvider),
    );
    if (mode == ChatVoiceRecordMode.tap) {
      // «Нажать для записи» (and always with TalkBack): a tap starts a
      // locked recording; stop / send / cancel are buttons.
      return MergeSemantics(
        key: const ValueKey('chat_mic_slot'),
        child: GestureDetector(
          key: const Key('chat_mic'),
          behavior: HitTestBehavior.opaque,
          onTap: _recording ? null : () => _startRecording(locked: true),
          child: Semantics(
            button: true,
            label: l10n.chatVoiceTapToRecord,
            child: _micCircle(tokens),
          ),
        ),
      );
    }
    // One screen-reader node for the hold-to-record gestures.
    return MergeSemantics(
      key: const ValueKey('chat_mic_slot'),
      child: GestureDetector(
      key: const Key('chat_mic'),
      // The 48 dp slot around the 44 dp circle is touchable too.
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (_) => _startRecording(),
      onLongPressMoveUpdate: (d) {
        _dragDx = d.offsetFromOrigin.dx;
        _dragDy = d.offsetFromOrigin.dy;
        if (_dragDx < -80 && !_locked) {
          _stopRecording(cancel: true);
        } else if (_dragDy < -70 && !_locked) {
          setState(() => _locked = true);
        } else if (mounted) {
          setState(() => _cancelHint = _dragDx < -30);
        }
      },
      onLongPressEnd: (_) {
        _holding = false;
        if (!_locked) _stopRecording(cancel: false);
      },
      onLongPressCancel: () => _holding = false,
      // A short tap only explains the gesture.
      onTap: () => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.chatVoiceHold))),
      // No Tooltip here: on phones it claims the long press itself and
      // recording would never start.
      child: Semantics(
        button: true,
        label: l10n.chatVoiceHold,
        child: SizedBox.square(
          dimension: kMinInteractiveDimension,
          child: Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tokens.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.mic, color: tokens.textInverse, size: 22),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// Reply / edit context above the input: accent bar, sender and preview.
class _ContextStrip extends StatelessWidget {
  const _ContextStrip({
    required this.message,
    required this.editing,
    required this.names,
    this.onCancel,
  });
  final ChatMessage message;
  final bool editing;
  final Map<String, String> names;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final title = editing
        ? l10n.chatEditing
        : (names[message.senderId]?.isNotEmpty == true
              ? names[message.senderId]!
              : l10n.chatReplyingTo);
    return Container(
      key: const Key('composer_context'),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(
          top: BorderSide(color: t.divider, width: t.borderWidth),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.xs, Space.xs),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              editing ? LucideIcons.pencil : LucideIcons.reply,
              color: t.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: Space.smd),
          ExcludeSemantics(
            child: Container(
              width: 2,
              height: 32,
              decoration: BoxDecoration(
                color: t.primary,
                borderRadius: BorderRadius.circular(XatBoxTokens.radiusPill),
              ),
            ),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: t.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  fmt.ChatFormat.preview(l10n, message),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: t.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.cancel,
            icon: Icon(LucideIcons.x, color: t.textTertiary),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// Colleague picker for a contact message (same directory as new chats).
class ContactPickerSheet extends ConsumerStatefulWidget {
  const ContactPickerSheet({super.key});

  @override
  ConsumerState<ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends ConsumerState<ContactPickerSheet> {
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final selfId = ref.read(chatRepositoryProvider).selfId;
    final results = ref.watch(chatUserSearchProvider(_query));
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                0,
                Space.md,
                Space.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.chatContactPickTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: Space.sm),
                  TextField(
                    key: const Key('contact_search'),
                    decoration: InputDecoration(
                      hintText: l10n.chatSearchUsers,
                      prefixIcon: const Icon(LucideIcons.search),
                    ),
                    onChanged: (v) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 300), () {
                        if (mounted) setState(() => _query = v.trim());
                      });
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: results.when(
                loading: () => const StateView.loading(),
                error: (e, _) => StateView.error(
                  message: fmt.ChatFormat.error(l10n, e),
                  onRetry: () => ref.invalidate(chatUserSearchProvider(_query)),
                ),
                data: (users) {
                  final visible = users
                      .where((u) => u.userId != selfId)
                      .toList();
                  if (visible.isEmpty) {
                    return StateView.empty(
                      title: l10n.chatNoUsers,
                      icon: LucideIcons.userSearch,
                    );
                  }
                  return ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (_, i) {
                      final u = visible[i];
                      return ListTile(
                        key: ValueKey('contact_pick_${u.userId}'),
                        leading: InitialsAvatar(
                          label: u.label,
                          colorKey: u.userId,
                        ),
                        title: Text(u.label),
                        subtitle: Text(
                          u.email,
                          style: TextStyle(color: tokens.textMuted),
                        ),
                        onTap: () => Navigator.pop(context, u),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingBar extends StatelessWidget {
  const _RecordingBar({
    required this.elapsed,
    required this.locked,
    required this.cancelHint,
    required this.onCancel,
    required this.onStop,
    this.levels = const [],
  });
  final Duration elapsed;
  final bool locked;
  final bool cancelHint;
  final VoidCallback onCancel;
  final VoidCallback onStop;

  /// Desktop: the loudness of the last seconds, newest last. Empty on the
  /// phone and whenever the recorder reports no amplitude, and then the bar
  /// shows the hint text it always did.
  final List<double> levels;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.sm,
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(LucideIcons.circle, color: tokens.danger),
          ),
          const SizedBox(width: Space.sm),
          // Deliberately not a live region: it changes every second.
          Text(
            ChatFormat.duration(elapsed.inMilliseconds),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(width: Space.md),
          Expanded(
            // The waveform replaces the hint only where there is one: it
            // says the same thing («we are hearing you») without words. On a
            // phone the hint stays while the button is held — it tells how
            // to cancel — and the waveform shows once the recording is locked.
            child: levels.isEmpty || (!locked && !isDesktop)
                // The swipe hint describes a touch gesture; screen-reader
                // users get the locked state and its buttons instead.
                ? ExcludeSemantics(
                    excluding: !locked,
                    child: Text(
                      locked ? l10n.chatVoiceLocked : l10n.chatVoiceSlideCancel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cancelHint ? tokens.danger : tokens.textMuted,
                      ),
                    ),
                  )
                : Semantics(
                    label: l10n.chatVoiceLocked,
                    child: ExcludeSemantics(
                      child: SizedBox(
                        height: 28,
                        child: CustomPaint(
                          painter: LiveWaveformPainter(
                            levels: List<double>.unmodifiable(levels),
                            color: cancelHint ? tokens.danger : tokens.primary,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ),
          ),
          if (locked) ...[
            TextButton(onPressed: onCancel, child: Text(l10n.chatVoiceCancel)),
            IconButton.filled(
              tooltip: l10n.chatSend,
              icon: const Icon(LucideIcons.square),
              onPressed: onStop,
            ),
          ] else
            ExcludeSemantics(
              child: Icon(LucideIcons.lockOpen, color: tokens.textMuted),
            ),
        ],
      ),
    );
  }
}

/// One tile of the attach picker: what it returns, how it looks, what it
/// is called.
typedef AttachOption = ({String value, IconData icon, String label, Color bg, Color fg});

/// Desktop «Прикрепить»: a small centred window with one large tile per
/// source, instead of the phone's bottom sheet. Tab and the arrow keys walk
/// the tiles, Enter picks one, Esc closes (the dialog route's own handler).
class AttachDialog extends StatelessWidget {
  const AttachDialog({super.key, required this.options});

  final List<AttachOption> options;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return AlertDialog(
      title: Text(l10n.chatAttach),
      // The tiles are the content; a confirm button would add a click.
      contentPadding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.md),
      content: SizedBox(
        width: 396,
        child: Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final (i, o) in options.indexed)
              SizedBox(
                width: 116,
                child: Material(
                  color: t.surfaceSubtle,
                  borderRadius: BorderRadius.circular(t.radiusMd),
                  child: InkWell(
                    key: Key('attach_${o.value}'),
                    autofocus: i == 0,
                    borderRadius: BorderRadius.circular(t.radiusMd),
                    onTap: () => Navigator.pop(context, o.value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Space.md),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(color: o.bg, shape: BoxShape.circle),
                            child: Icon(o.icon, color: o.fg, size: 24),
                          ),
                          const SizedBox(height: Space.sm),
                          Text(
                            o.label,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

/// The live waveform of a recording in progress: one rounded bar per
/// measurement, oldest on the left, the newest arriving on the right. Bars
/// keep a visible minimum height so silence still reads as a line rather
/// than as a dead widget. Unlike [WaveformPainter], which draws the finished
/// note from its id, these are the real levels from the microphone.
class LiveWaveformPainter extends CustomPainter {
  const LiveWaveformPainter({required this.levels, required this.color});

  final List<double> levels;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty || size.width <= 0 || size.height <= 0) return;
    const barWidth = 3.0;
    const gap = 2.0;
    final step = barWidth + gap;
    final fits = (size.width / step).floor();
    if (fits <= 0) return;
    // More measurements than bars: show the most recent ones.
    final shown = levels.length > fits ? levels.sublist(levels.length - fits) : levels;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    // Right-aligned, so a new bar pushes the line leftwards instead of
    // making the whole waveform jump as it fills.
    final startX = size.width - shown.length * step + gap;
    for (var i = 0; i < shown.length; i++) {
      final level = shown[i].clamp(0.0, 1.0);
      final height = (size.height * level).clamp(2.0, size.height);
      final left = startX + i * step;
      final top = (size.height - height) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barWidth, height),
          const Radius.circular(1.5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(LiveWaveformPainter old) =>
      old.color != color || !identical(old.levels, levels);
}

// Re-exported for the recording bar timer label.
abstract final class ChatFormat {
  static String duration(int ms) {
    final d = Duration(milliseconds: ms);
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}
