import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:xatbox_mobile/features/chat/data/chat_photo.dart';

void main() {
  test('a big photo is scaled to 2560 on its longest side, as JPEG', () {
    final big = img.encodePng(img.Image(width: 4000, height: 1000));
    final out = compressChatPhoto(big)!;
    final back = img.decodeJpg(out)!;
    expect((back.width, back.height), (chatPhotoMaxSide, 640));
  });

  test('a sideways phone photo is turned upright (EXIF orientation 6)', () {
    final photo = img.Image(width: 400, height: 300);
    photo.exif.imageIfd.orientation = 6;
    final out = compressDecodedPhoto(photo, 1000)!;
    final back = img.decodeJpg(out)!;
    expect((back.width, back.height), (300, 400));
    expect(back.exif.imageIfd.hasOrientation && back.exif.imageIfd.orientation != 1, isFalse);
  });

  test('a small upright picture goes as it is; other files are not photos', () {
    expect(compressChatPhoto(img.encodePng(img.Image(width: 800, height: 600))), isNull);
    expect(compressChatPhoto(img.encodePng(img.Image(width: 8, height: 8)).sublist(0, 10)), isNull);
    expect(isChatPhoto('/a/b/IMG_1.JPG'), isTrue);
    expect(isChatPhoto('/a/b/report.pdf'), isFalse);
  });
}
