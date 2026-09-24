import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../shared/utils/diagnostic_log.dart';
import 'desktop.dart';

/// The sound of a desktop toast (new chat message, new letter).
enum DesktopNotificationSound {
  /// XatBox's own chime, played by the app; the toast itself is silent.
  xatbox,

  /// Whatever the operating system plays for a notification.
  system,

  /// Silent toasts.
  none;

  static DesktopNotificationSound parse(Object? v) =>
      values.where((s) => s.name == v).firstOrNull ?? xatbox;
}

/// The melody of an incoming call on the desktop.
enum DesktopRingtone {
  /// XatBox's own melody.
  xatbox,

  /// The two-tone ring the app always had.
  classic;

  static DesktopRingtone parse(Object? v) => values.where((s) => s.name == v).firstOrNull ?? xatbox;
}

/// One struck note of a melody.
class ToneNote {
  const ToneNote(this.frequency, this.start, {this.length = 0.9, this.volume = 1});

  /// Hz.
  final double frequency;

  /// Seconds from the start of the sound.
  final double start;

  /// Seconds the note rings before it is cut (it has mostly faded by then).
  final double length;

  /// 0…1, relative to the other notes.
  final double volume;
}

// Pentatonic notes around A (the XatBox sounds stay in one key, so the
// chime and the ringtone belong together).
const _e5 = 659.26, _a5 = 880.0, _c6 = 1046.5, _d6 = 1174.66, _e6 = 1318.51;

/// «XatBox»: two soft notes going up — a fifth, short enough to hear many
/// times a day without getting tired of it.
const xatboxChime = [
  ToneNote(_a5, 0, length: 0.5, volume: 0.8),
  ToneNote(_e6, 0.11, length: 0.75),
];

/// The chime's length, the file it is rendered into included.
const xatboxChimeLength = 0.9;

/// «XatBox» ringtone: a rising phrase and its answer, then a breath. Looped
/// while the call rings.
const xatboxRingtone = [
  ToneNote(_e5, 0, length: 0.5, volume: 0.75),
  ToneNote(_a5, 0.16, length: 0.5, volume: 0.8),
  ToneNote(_c6, 0.32, length: 0.5, volume: 0.85),
  ToneNote(_e6, 0.48, length: 1.0),
  ToneNote(_d6, 1.12, length: 0.45, volume: 0.8),
  ToneNote(_c6, 1.28, length: 0.45, volume: 0.8),
  ToneNote(_a5, 1.44, length: 1.1, volume: 0.9),
];

/// One loop of the ringtone, silence after the phrase included.
const xatboxRingtoneLength = 3.4;

/// 16-bit mono PCM WAV of [notes] over [seconds]. Each note sounds like a
/// soft mallet on a metal bar: a fundamental with a few quieter overtones,
/// a 4 ms attack and an exponential fade, so a loop has no clicks. The mix
/// is normalised to [peak]. Pure, so it is unit-tested.
Uint8List synthesizeMelodyWav(List<ToneNote> notes, double seconds, {int sampleRate = 22050, double peak = 0.5}) {
  final total = (seconds * sampleRate).round();
  final mix = Float64List(total);
  // (partial ratio, level, decay time in seconds)
  const partials = [(1.0, 1.0, 0.42), (2.0, 0.22, 0.2), (3.0, 0.08, 0.12), (5.4, 0.05, 0.05)];
  final attack = (0.004 * sampleRate).round();
  for (final n in notes) {
    final from = (n.start * sampleRate).round();
    final len = math.min((n.length * sampleRate).round(), total - from);
    final release = math.min((0.03 * sampleRate).round(), len);
    for (var i = 0; i < len; i++) {
      final t = i / sampleRate;
      var v = 0.0;
      for (final (ratio, level, decay) in partials) {
        final f = n.frequency * ratio;
        if (f >= sampleRate / 2) continue;
        v += level * math.exp(-t / decay) * math.sin(2 * math.pi * f * t);
      }
      var env = i < attack ? i / attack : 1.0;
      if (i > len - release) env *= (len - i) / release;
      mix[from + i] += v * env * n.volume;
    }
  }
  var max = 0.0;
  for (final v in mix) {
    max = math.max(max, v.abs());
  }
  final gain = max == 0 ? 0.0 : peak / max;

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
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, dataLength, Endian.little);
  for (var i = 0; i < total; i++) {
    bytes.setInt16(44 + i * 2, (mix[i] * gain * 32767).round().clamp(-32768, 32767), Endian.little);
  }
  return bytes.buffer.asUint8List();
}

/// Writes [wav] to `<temp>/<name>` once per process (again when the bytes
/// changed with an update) and returns the path.
Future<String> cachedWavFile(String name, Uint8List wav) async {
  final file = File(p.join((await getTemporaryDirectory()).path, name));
  if (!await file.exists() || await file.length() != wav.length) {
    await file.writeAsBytes(wav, flush: true);
  }
  return file.path;
}

/// The desktop's notification sounds. The settings (desktop_settings.json)
/// set [notification]; toasts read it in showDesktopToast.
abstract final class DesktopSounds {
  static DesktopNotificationSound notification = DesktopNotificationSound.xatbox;

  static AudioPlayer? _player;
  static DateTime _lastChime = DateTime.fromMillisecondsSinceEpoch(0);

  /// A toast should stay silent: the app plays its own chime, or nothing.
  static bool get silenceToasts => isDesktop && notification != DesktopNotificationSound.system;

  /// The chime of a new message, when the settings ask for it. Several
  /// toasts at once (a burst of letters) chime once.
  static Future<void> chimeForToast() async {
    if (!isDesktop || notification != DesktopNotificationSound.xatbox) return;
    final now = DateTime.now();
    if (now.difference(_lastChime) < const Duration(milliseconds: 1200)) return;
    _lastChime = now;
    await playChime();
  }

  static Future<void> playChime() => _playOnce('xatbox_chime.wav', () => synthesizeMelodyWav(xatboxChime, xatboxChimeLength));

  /// «Прослушать» in the settings: one loop of the ringtone.
  static Future<void> previewRingtone(DesktopRingtone ringtone, Future<String> Function(DesktopRingtone) file) async {
    try {
      final path = await file(ringtone);
      await _play(path);
    } on Object catch (e) {
      DiagnosticLog.warn('sounds', 'ringtone preview failed', error: e);
    }
  }

  static Future<void> stopPreview() async {
    try {
      await _player?.stop();
    } on Object {
      // Nothing playing.
    }
  }

  static Future<void> _playOnce(String name, Uint8List Function() wav) async {
    try {
      await _play(await cachedWavFile(name, wav()));
    } on Object catch (e) {
      DiagnosticLog.warn('sounds', '$name failed', error: e);
    }
  }

  static Future<void> _play(String path) async {
    final player = _player ??= AudioPlayer(handleInterruptions: false, handleAudioSessionActivation: false);
    await player.stop();
    await player.setLoopMode(LoopMode.off);
    await player.setFilePath(path);
    // play() completes only when playback stops: never await it.
    unawaited(player.play().catchError((Object e) => DiagnosticLog.warn('sounds', 'playback failed', error: e)));
  }
}

/// [details] with the toast's own sound switched off on every desktop
/// platform, the rest kept (pure, unit-tested).
NotificationDetails silencedToastDetails(NotificationDetails? details) {
  final w = details?.windows;
  final m = details?.macOS;
  final l = details?.linux;
  return NotificationDetails(
    windows: WindowsNotificationDetails(
      actions: w?.actions ?? const [],
      inputs: w?.inputs ?? const [],
      images: w?.images ?? const [],
      rows: w?.rows ?? const [],
      progressBars: w?.progressBars ?? const [],
      bindings: w?.bindings ?? const {},
      header: w?.header,
      duration: w?.duration,
      scenario: w?.scenario,
      timestamp: w?.timestamp,
      subtitle: w?.subtitle,
      audio: WindowsNotificationAudio.silent(),
    ),
    macOS: DarwinNotificationDetails(
      presentAlert: m?.presentAlert,
      presentBanner: m?.presentBanner,
      presentList: m?.presentList,
      presentBadge: m?.presentBadge,
      presentSound: false,
      badgeNumber: m?.badgeNumber,
      attachments: m?.attachments,
      threadIdentifier: m?.threadIdentifier,
      categoryIdentifier: m?.categoryIdentifier,
      interruptionLevel: m?.interruptionLevel,
      subtitle: m?.subtitle,
    ),
    linux: LinuxNotificationDetails(
      icon: l?.icon,
      urgency: l?.urgency,
      category: l?.category,
      actions: l?.actions ?? const [],
      defaultActionName: l?.defaultActionName,
      timeout: l?.timeout ?? const LinuxNotificationTimeout.systemDefault(),
      resident: l?.resident ?? false,
      transient: l?.transient ?? false,
      location: l?.location,
      customHints: l?.customHints,
      actionKeyAsIconName: l?.actionKeyAsIconName ?? false,
      suppressSound: true,
    ),
  );
}
