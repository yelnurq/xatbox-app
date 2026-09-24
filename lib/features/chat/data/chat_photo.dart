import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../shared/utils/diagnostic_log.dart';

/// Longest side of a photo sent to a chat, as the phone's image picker
/// (`maxWidth: 2560`, `imageQuality: 85`).
const chatPhotoMaxSide = 2560;
const chatPhotoQuality = 85;

/// Files at or under this size and [chatPhotoMaxSide] that need no turning
/// are sent as they are.
const _smallEnough = 1536 * 1024;

const _photoExtensions = {'.jpg', '.jpeg', '.png', '.webp', '.bmp'};

bool isChatPhoto(String path) => _photoExtensions.contains(p.extension(path).toLowerCase());

/// The photo as a chat sends it (pure, unit-tested): turned upright by its
/// EXIF orientation, at most [chatPhotoMaxSide] on the longest side, JPEG
/// [chatPhotoQuality] (transparency over white). Null when the original can
/// go as it is (already small and upright) or is not a picture it can read.
Uint8List? compressChatPhoto(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } on Object {
    return null; // cut short or not a picture
  }
  if (decoded == null) return null;
  return compressDecodedPhoto(decoded, bytes.length);
}

/// [compressChatPhoto] after decoding ([size]: bytes of the original).
@visibleForTesting
Uint8List? compressDecodedPhoto(img.Image decoded, int size) {
  final ifd = decoded.exif.imageIfd;
  final turned = ifd.hasOrientation && ifd.orientation != 1;
  final longest = math.max(decoded.width, decoded.height);
  if (!turned && longest <= chatPhotoMaxSide && size <= _smallEnough) return null;
  var image = img.bakeOrientation(decoded);
  if (longest > chatPhotoMaxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: chatPhotoMaxSide, interpolation: img.Interpolation.average)
        : img.copyResize(image, height: chatPhotoMaxSide, interpolation: img.Interpolation.average);
  }
  if (image.hasAlpha) {
    final flat = img.Image(width: image.width, height: image.height)..clear(img.ColorRgb8(255, 255, 255));
    image = img.compositeImage(flat, image);
  }
  return img.encodeJpg(image, quality: chatPhotoQuality);
}

/// Desktop: a photo from the picker, a drop or the clipboard, made ready to
/// send off the UI isolate. Anything else, or a photo that cannot be read,
/// comes back unchanged. Never throws.
Future<({String path, String name})> prepareChatPhoto(String path, String name) async {
  if (!isChatPhoto(path)) return (path: path, name: name);
  try {
    final out = await compute(compressChatPhoto, await File(path).readAsBytes());
    if (out == null) return (path: path, name: name);
    final dir = Directory(p.join((await getTemporaryDirectory()).path, 'chat_photos'));
    await dir.create(recursive: true);
    final jpg = '${p.basenameWithoutExtension(name)}.jpg';
    final file = File(p.join(dir.path, '${DateTime.now().microsecondsSinceEpoch}-$jpg'));
    await file.writeAsBytes(out, flush: true);
    return (path: file.path, name: jpg);
  } on Object catch (e) {
    DiagnosticLog.warn('chat', 'photo not compressed', error: e);
    return (path: path, name: name);
  }
}
