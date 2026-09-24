import 'package:flutter/widgets.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../../../shared/utils/diagnostic_log.dart';

/// Camera preview of the pre-join screen, behind an interface (fake in tests).
abstract class CallCameraPreview {
  /// Starts the front camera; false when it is unavailable.
  Future<bool> start();
  Future<void> stop();
  Widget view();

  /// Names of the devices a call will use (null when unknown).
  Future<String?> microphoneLabel();
  Future<String?> cameraLabel();
}

/// LiveKit local camera track, stopped before the call publishes its own.
class LiveKitCameraPreview implements CallCameraPreview {
  lk.LocalVideoTrack? _track;

  @override
  Future<bool> start() async {
    if (_track != null) return true;
    try {
      _track = await lk.LocalVideoTrack.createCameraTrack(const lk.CameraCaptureOptions(cameraPosition: lk.CameraPosition.front));
      return true;
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'camera preview failed', error: e);
      return false;
    }
  }

  @override
  Future<void> stop() async {
    final track = _track;
    _track = null;
    try {
      await track?.stop();
      await track?.dispose();
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'camera preview stop failed', error: e);
    }
  }

  @override
  Widget view() {
    final track = _track;
    if (track == null) return const SizedBox.shrink();
    return lk.VideoTrackRenderer(track, fit: lk.VideoViewFit.cover, mirrorMode: lk.VideoViewMirrorMode.mirror);
  }

  Future<String?> _label(Future<List<lk.MediaDevice>> Function() list) async {
    try {
      final devices = await list();
      final label = devices.firstOrNull?.label ?? '';
      return label.isEmpty ? null : label;
    } on Object {
      return null;
    }
  }

  @override
  Future<String?> microphoneLabel() => _label(lk.Hardware.instance.audioInputs);

  @override
  Future<String?> cameraLabel() => _label(lk.Hardware.instance.videoInputs);
}
