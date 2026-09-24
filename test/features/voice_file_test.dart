import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xatbox_mobile/features/chat/data/voice_file.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('voice_file'));
  tearDown(() => dir.delete(recursive: true));

  Future<List<int>> write(String brand) async {
    final bytes = [0, 0, 0, 24, ...'ftyp'.codeUnits, ...brand.codeUnits, 0, 0, 2, 0, ...'isommp42'.codeUnits, 1, 2, 3];
    await File('${dir.path}/v.m4a').writeAsBytes(bytes);
    return bytes;
  }

  test('a generic MP4 brand (Windows recorder) becomes M4A, the rest is untouched', () async {
    final before = await write('mp42');
    await markVoiceAsAudioMp4('${dir.path}/v.m4a');
    final after = await File('${dir.path}/v.m4a').readAsBytes();
    expect(String.fromCharCodes(after.sublist(8, 12)), 'M4A ');
    expect(after.length, before.length);
    expect(after.sublist(12), before.sublist(12));
    expect(after.sublist(0, 8), before.sublist(0, 8));
  });

  test('an M4A file and a non-MP4 file are left as they are', () async {
    final m4a = await write('M4A ');
    await markVoiceAsAudioMp4('${dir.path}/v.m4a');
    expect(await File('${dir.path}/v.m4a').readAsBytes(), m4a);

    final ogg = 'OggS-not-mp4-at-all'.codeUnits;
    await File('${dir.path}/v.ogg').writeAsBytes(ogg);
    await markVoiceAsAudioMp4('${dir.path}/v.ogg');
    expect(await File('${dir.path}/v.ogg').readAsBytes(), ogg);
  });
}
