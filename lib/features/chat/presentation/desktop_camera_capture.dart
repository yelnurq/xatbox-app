import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/localization/localization.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/utils/diagnostic_log.dart';
import 'chat_providers.dart';

/// Desktop «Камера»: takes a photograph with the computer's camera and
/// returns it as a file ready to attach, or null if the window was closed
/// without taking one.
///
/// image_picker has no camera on Windows, macOS or Linux, so this uses the
/// LiveKit camera track the calls already use there — no extra plugin, and
/// the same device list as a video call.
Future<ChatPickedFile?> showDesktopCameraCapture(BuildContext context) =>
    showDialog<ChatPickedFile>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DesktopCameraCapture(),
    );

class DesktopCameraCapture extends StatefulWidget {
  const DesktopCameraCapture({super.key});

  @override
  State<DesktopCameraCapture> createState() => _DesktopCameraCaptureState();
}

class _DesktopCameraCaptureState extends State<DesktopCameraCapture> {
  lk.LocalVideoTrack? _track;
  List<lk.MediaDevice> _cameras = const [];
  String? _deviceId;

  /// The frame that was taken, shown instead of the live picture until it is
  /// sent or retaken.
  Uint8List? _shot;
  bool _busy = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    // The track outlives the widget unless it is stopped: the camera light
    // would stay on after the window closed.
    _stopTrack(_track);
    super.dispose();
  }

  static void _stopTrack(lk.LocalVideoTrack? track) {
    if (track == null) return;
    () async {
      try {
        await track.stop();
        await track.dispose();
      } on Object catch (e) {
        DiagnosticLog.warn('chat', 'camera not stopped', error: e);
      }
    }();
  }

  Future<void> _start({String? deviceId}) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    final previous = _track;
    _track = null;
    _stopTrack(previous);
    try {
      final cameras = await lk.Hardware.instance.videoInputs();
      final id = deviceId ?? _deviceId ?? cameras.firstOrNull?.deviceId;
      final track = await lk.LocalVideoTrack.createCameraTrack(
        lk.CameraCaptureOptions(deviceId: id),
      );
      if (!mounted) {
        _stopTrack(track);
        return;
      }
      setState(() {
        _cameras = cameras;
        _deviceId = id;
        _track = track;
        _busy = false;
      });
    } on Object catch (e) {
      DiagnosticLog.warn('chat', 'camera capture unavailable', error: e);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failed = true;
      });
    }
  }

  Future<void> _capture() async {
    final track = _track;
    if (track == null) return;
    setState(() => _busy = true);
    try {
      final frame = await track.mediaStreamTrack.captureFrame();
      if (!mounted) return;
      setState(() {
        _shot = frame.asUint8List();
        _busy = false;
      });
    } on Object catch (e) {
      DiagnosticLog.warn('chat', 'frame not captured', error: e);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failed = true;
      });
    }
  }

  Future<void> _send() async {
    final shot = _shot;
    if (shot == null) return;
    setState(() => _busy = true);
    try {
      final dir = await getTemporaryDirectory();
      final name = 'camera_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(p.join(dir.path, name));
      await file.writeAsBytes(shot, flush: true);
      if (!mounted) return;
      Navigator.pop(context, (path: file.path, name: name));
    } on Object catch (e) {
      DiagnosticLog.warn('chat', 'photo not written', error: e);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final shot = _shot;
    final track = _track;
    return AlertDialog(
      title: Text(l10n.chatCameraTitle),
      contentPadding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.sm),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(t.radiusMd),
                child: ColoredBox(
                  color: t.surfaceMuted,
                  child: switch ((shot, track, _failed)) {
                    // A frame was taken: it is what will be sent, so it is
                    // shown exactly as it is — not mirrored.
                    (final Uint8List bytes, _, _) => Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                    (_, _, true) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(Space.lg),
                        child: Text(
                          l10n.chatCameraUnavailable,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: t.textTertiary),
                        ),
                      ),
                    ),
                    (_, final lk.LocalVideoTrack live, _) => lk.VideoTrackRenderer(
                      live,
                      fit: lk.VideoViewFit.contain,
                      // What you see is what gets sent; a mirrored preview
                      // and an unmirrored photograph would not match.
                      mirrorMode: lk.VideoViewMirrorMode.off,
                    ),
                    _ => const Center(child: CircularProgressIndicator()),
                  },
                ),
              ),
            ),
            // Only worth a row when there is something to choose between.
            if (shot == null && _cameras.length > 1) ...[
              const SizedBox(height: Space.sm),
              DropdownButtonFormField<String>(
                key: const Key('camera_device'),
                initialValue: _deviceId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.chatCameraDevice,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final c in _cameras)
                    DropdownMenuItem(
                      value: c.deviceId,
                      child: Text(
                        c.label.isEmpty ? c.deviceId : c.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy ? null : (id) => id == null ? null : _start(deviceId: id),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        if (shot != null)
          TextButton(
            key: const Key('camera_retake'),
            onPressed: _busy ? null : () => setState(() => _shot = null),
            child: Text(l10n.chatCameraRetake),
          ),
        if (shot == null)
          FilledButton.icon(
            key: const Key('camera_take'),
            onPressed: _busy || track == null ? null : _capture,
            icon: const Icon(LucideIcons.camera, size: 18),
            label: Text(l10n.chatCameraTake),
          )
        else
          FilledButton.icon(
            key: const Key('camera_send'),
            onPressed: _busy ? null : _send,
            icon: const Icon(LucideIcons.send, size: 18),
            label: Text(l10n.chatSend),
          ),
      ],
    );
  }
}
