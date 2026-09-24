import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/core/platform/desktop_settings.dart';
import 'package:xatbox_mobile/core/platform/desktop_sounds.dart';

void main() {
  group('synthesizeMelodyWav', () {
    test('writes a 16-bit mono WAV of the requested length', () {
      final wav = synthesizeMelodyWav(xatboxChime, xatboxChimeLength, sampleRate: 8000);
      final b = ByteData.sublistView(wav);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(b.getUint16(22, Endian.little), 1, reason: 'mono');
      expect(b.getUint32(24, Endian.little), 8000);
      expect(b.getUint32(40, Endian.little), (xatboxChimeLength * 8000).round() * 2);
      expect(wav.length, 44 + (xatboxChimeLength * 8000).round() * 2);
    });

    test('is normalised to the peak and fades out — a loop has no click', () {
      final wav = synthesizeMelodyWav(xatboxRingtone, xatboxRingtoneLength, sampleRate: 8000, peak: 0.5);
      final b = ByteData.sublistView(wav);
      final n = (wav.length - 44) ~/ 2;
      var max = 0;
      for (var i = 0; i < n; i++) {
        max = b.getInt16(44 + i * 2, Endian.little).abs() > max ? b.getInt16(44 + i * 2, Endian.little).abs() : max;
      }
      expect(max, closeTo(0.5 * 32767, 2));
      expect(b.getInt16(44, Endian.little).abs(), lessThan(200), reason: 'starts from silence');
      expect(b.getInt16(44 + (n - 1) * 2, Endian.little).abs(), lessThan(200), reason: 'ends in silence');
    });
  });

  test('sound settings survive a round trip and unknown values fall back to XatBox', () {
    const s = DesktopSettings(notificationSound: DesktopNotificationSound.none, ringtone: DesktopRingtone.classic);
    final back = DesktopSettings.fromJson(s.toJson());
    expect(back.notificationSound, DesktopNotificationSound.none);
    expect(back.ringtone, DesktopRingtone.classic);
    final odd = DesktopSettings.fromJson({'notification_sound': 'loud', 'ringtone': 42});
    expect(odd.notificationSound, DesktopNotificationSound.xatbox);
    expect(odd.ringtone, DesktopRingtone.xatbox);
    expect(const DesktopSettings().notificationSound, DesktopNotificationSound.xatbox);
  });

  test('silencing a toast keeps its buttons and category', () {
    const action = WindowsAction(content: 'Прочитано', arguments: 'x');
    final d = silencedToastDetails(
      const NotificationDetails(
        windows: WindowsNotificationDetails(actions: [action], scenario: WindowsNotificationScenario.reminder),
        macOS: DarwinNotificationDetails(categoryIdentifier: 'chat'),
      ),
    );
    expect(d.windows!.audio!.isSilent, isTrue);
    expect(d.windows!.actions.single.content, 'Прочитано');
    expect(d.windows!.scenario, WindowsNotificationScenario.reminder);
    expect(d.macOS!.presentSound, isFalse);
    expect(d.macOS!.categoryIdentifier, 'chat');
    expect(d.linux!.suppressSound, isTrue);
    expect(silencedToastDetails(null).windows!.audio!.isSilent, isTrue);
  });
}
