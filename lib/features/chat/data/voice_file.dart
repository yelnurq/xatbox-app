import 'dart:io';

import '../../../shared/utils/diagnostic_log.dart';

/// Marks a recorded voice note as an audio MP4 («M4A ») when the recorder
/// wrote a generic MP4 brand.
///
/// Windows (Media Foundation) writes AAC recordings with the `mp42`/`isom`
/// major brand; the Chat Service sniffs uploads by their first bytes and
/// files such an upload as `video/mp4`, so the voice message arrived as a
/// video file. Android's recorder already writes `M4A `. Only the 4-byte
/// major brand is replaced; the audio itself is untouched. Never throws.
Future<void> markVoiceAsAudioMp4(String path) async {
  RandomAccessFile? file;
  try {
    file = await File(path).open(mode: FileMode.append);
    await file.setPosition(0);
    final head = await file.read(12);
    if (head.length < 12) return;
    final isFtyp = String.fromCharCodes(head.sublist(4, 8)) == 'ftyp';
    final brand = String.fromCharCodes(head.sublist(8, 12));
    if (!isFtyp || brand.startsWith('M4A')) return;
    await file.setPosition(8);
    await file.writeFrom('M4A '.codeUnits);
  } on Object catch (e) {
    DiagnosticLog.warn('chat', 'voice brand not rewritten', error: e);
  } finally {
    await file?.close();
  }
}
