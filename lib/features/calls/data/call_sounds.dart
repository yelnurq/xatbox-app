import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/platform/desktop.dart';
import '../../../core/platform/desktop_sounds.dart';
import '../../../shared/utils/diagnostic_log.dart';

/// Tones the app plays itself. The system call UI (CallKit on iOS, the
/// callkit notification on Android in background) rings on its own.
enum CallTone {
  /// Caller side while the outgoing call rings (until someone joins).
  ringback,

  /// Incoming call while the app is in the foreground on Android.
  ringtone,
}

/// Call sounds behind an interface (a fake in tests).
abstract class CallSounds {
  /// Starts [tone] looped, replacing whatever was playing.
  Future<void> play(CallTone tone);

  /// Stops at once; safe to call when nothing plays.
  Future<void> stop();

  Future<void> dispose();
}

/// No sounds (tests, platforms without audio output).
class SilentCallSounds implements CallSounds {
  const SilentCallSounds();
  @override
  Future<void> play(CallTone tone) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

/// One piece of a tone pattern: silence when [frequencies] is empty, several
/// frequencies are mixed.
class ToneSegment {
  const ToneSegment(this.duration, [this.frequencies = const []]);
  final Duration duration;
  final List<double> frequencies;
}

/// Russian/European ringback: 425 Hz, 1 s on, 4 s off.
const ringbackPattern = [
  ToneSegment(Duration(seconds: 1), [425.0]),
  ToneSegment(Duration(seconds: 4)),
];

/// Two-tone ring: 660/880 Hz twice, then a pause.
const ringtonePattern = [
  ToneSegment(Duration(milliseconds: 400), [660.0]),
  ToneSegment(Duration(milliseconds: 400), [880.0]),
  ToneSegment(Duration(milliseconds: 400), [660.0]),
  ToneSegment(Duration(milliseconds: 400), [880.0]),
  ToneSegment(Duration(milliseconds: 1400)),
];

/// 16-bit mono PCM WAV of [segments]. Every tone has a 10 ms fade in/out so
/// the loop has no clicks. Pure, so it is unit-tested.
Uint8List synthesizeWav(List<ToneSegment> segments, {int sampleRate = 16000, double volume = 0.35}) {
  final counts = [for (final s in segments) (s.duration.inMicroseconds * sampleRate / 1000000).round()];
  final total = counts.fold<int>(0, (a, b) => a + b);
  final dataLength = total * 2;
  final bytes = ByteData(44 + dataLength);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      bytes.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataLength, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little); // fmt chunk size
  bytes.setUint16(20, 1, Endian.little); // PCM
  bytes.setUint16(22, 1, Endian.little); // mono
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  bytes.setUint16(32, 2, Endian.little); // block align
  bytes.setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  bytes.setUint32(40, dataLength, Endian.little);

  var offset = 44;
  for (var s = 0; s < segments.length; s++) {
    final n = counts[s];
    final freqs = segments[s].frequencies;
    final fade = math.min(sampleRate ~/ 100, n ~/ 2);
    for (var i = 0; i < n; i++) {
      var value = 0.0;
      if (freqs.isNotEmpty) {
        for (final f in freqs) {
          value += math.sin(2 * math.pi * f * i / sampleRate);
        }
        value /= freqs.length;
        final envelope = fade == 0 ? 1.0 : math.min(1.0, math.min(i, n - 1 - i) / fade);
        value *= envelope * volume;
      }
      bytes.setInt16(offset, (value * 32767).round().clamp(-32768, 32767), Endian.little);
      offset += 2;
    }
  }
  return bytes.buffer.asUint8List();
}

/// just_audio implementation: the WAV is synthesized once per process into
/// the temp directory and played looped. It never activates or changes the
/// audio session, which belongs to the call (CallKit / WebRTC).
class JustAudioCallSounds implements CallSounds {
  JustAudioCallSounds({Future<Directory> Function()? tempDir, DesktopRingtone Function()? ringtone})
    : _tempDir = tempDir ?? getTemporaryDirectory,
      _ringtone = ringtone; // ignore: prefer_initializing_formals

  final Future<Directory> Function() _tempDir;

  /// Desktop: the melody chosen in the settings (phones always ring the
  /// classic two tones).
  final DesktopRingtone Function()? _ringtone;
  final Map<CallTone, String> _files = {};
  AudioPlayer? _player;
  CallTone? _wanted;

  static bool get _supported => Platform.isAndroid || Platform.isIOS || isDesktop;

  Future<String> _file(CallTone tone) async {
    if (tone == CallTone.ringtone && isDesktop && _ringtone != null) {
      return ringtoneFile(_ringtone());
    }
    final known = _files[tone];
    if (known != null) return known;
    final path = p.join((await _tempDir()).path, 'xatbox_call_${tone.name}.wav');
    final wav = synthesizeWav(tone == CallTone.ringback ? ringbackPattern : ringtonePattern);
    final file = File(path);
    if (!await file.exists() || await file.length() != wav.length) {
      await file.writeAsBytes(wav, flush: true);
    }
    return _files[tone] = path;
  }

  /// The WAV of a desktop ringtone (also played by «Прослушать»).
  static Future<String> ringtoneFile(DesktopRingtone ringtone) => switch (ringtone) {
    DesktopRingtone.xatbox => cachedWavFile(
      'xatbox_ringtone_xatbox.wav',
      synthesizeMelodyWav(xatboxRingtone, xatboxRingtoneLength),
    ),
    DesktopRingtone.classic => cachedWavFile('xatbox_call_ringtone.wav', synthesizeWav(ringtonePattern)),
  };

  @override
  Future<void> play(CallTone tone) async {
    _wanted = tone;
    if (!_supported) return;
    try {
      final path = await _file(tone);
      if (_wanted != tone) return;
      final player = _player ??= AudioPlayer(handleInterruptions: false, handleAudioSessionActivation: false);
      await player.stop();
      await player.setLoopMode(LoopMode.one);
      await player.setFilePath(path);
      // Stopped (or switched) while loading.
      if (_wanted != tone) {
        await player.stop();
        return;
      }
      // play() completes only when playback stops: never await it.
      unawaited(player.play().catchError((Object e) => DiagnosticLog.warn('calls', 'tone playback failed', error: e)));
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'tone ${tone.name} failed', error: e);
    }
  }

  @override
  Future<void> stop() async {
    _wanted = null;
    final player = _player;
    if (player == null) return;
    try {
      await player.stop();
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'tone stop failed', error: e);
    }
  }

  @override
  Future<void> dispose() async {
    _wanted = null;
    final player = _player;
    _player = null;
    try {
      await player?.dispose();
    } on Object catch (e) {
      DiagnosticLog.warn('calls', 'tone dispose failed', error: e);
    }
  }
}
