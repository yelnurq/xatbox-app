// Prepares the photo backdrops of the desktop glass skins (and the contact
// sheets used to choose them). Run from the project root:
//
//   dart run tool/backdrop_photos.dart sheet <out.png> <in.jpg…>
//   dart run tool/backdrop_photos.dart asset <in.jpg> <out.jpg> [width] [quality] [cropTop] [cropBottom]
//
// `sheet` tiles the inputs into one image for review. `asset` scales a photo
// down to [width] (2560 by default), optionally trimming [cropTop] and
// [cropBottom] of the height first (fractions, e.g. 0.07 to cut a camera's
// date stamp away), and writes a JPEG at [quality] — small enough to ship in
// the app bundle and sharp enough for a 4K window.
import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: sheet <out.png> <in…> | asset <in> <out> [width] [quality] [cropTop]');
    exit(64);
  }
  switch (args.first) {
    case 'sheet':
      _sheet(args[1], args.sublist(2));
    case 'asset':
      _asset(
        args[1],
        args[2],
        width: args.length > 3 ? int.parse(args[3]) : 2560,
        quality: args.length > 4 ? int.parse(args[4]) : 82,
        cropTop: args.length > 5 ? double.parse(args[5]) : 0,
        cropBottom: args.length > 6 ? double.parse(args[6]) : 0,
      );
    default:
      stderr.writeln('unknown command ${args.first}');
      exit(64);
  }
}

void _sheet(String out, List<String> inputs, {int columns = 4, int cell = 420}) {
  final tiles = [
    for (final path in inputs) img.copyResize(img.decodeImage(File(path).readAsBytesSync())!, width: cell),
  ];
  final rows = (tiles.length / columns).ceil();
  final rowHeight = <int>[];
  for (var r = 0; r < rows; r++) {
    var tallest = 0;
    for (var c = 0; c < columns; c++) {
      final i = r * columns + c;
      if (i < tiles.length) tallest = tallest > tiles[i].height ? tallest : tiles[i].height;
    }
    rowHeight.add(tallest);
  }
  final canvas = img.Image(width: columns * (cell + 8) + 8, height: rowHeight.fold(8, (a, b) => a + b + 8));
  img.fill(canvas, color: img.ColorRgb8(20, 20, 24));
  var y = 8;
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < columns; c++) {
      final i = r * columns + c;
      if (i >= tiles.length) break;
      img.compositeImage(canvas, tiles[i], dstX: 8 + c * (cell + 8), dstY: y);
    }
    y += rowHeight[r] + 8;
  }
  File(out).writeAsBytesSync(img.encodePng(canvas));
  stdout.writeln('$out ${canvas.width}x${canvas.height} (${tiles.length} tiles, $columns per row)');
}

void _asset(
  String input,
  String out, {
  required int width,
  required int quality,
  double cropTop = 0,
  double cropBottom = 0,
}) {
  var photo = img.decodeImage(File(input).readAsBytesSync())!;
  if (cropTop > 0 || cropBottom > 0) {
    final top = (photo.height * cropTop).round();
    final bottom = (photo.height * cropBottom).round();
    photo = img.copyCrop(photo, x: 0, y: top, width: photo.width, height: photo.height - top - bottom);
  }
  final scaled = photo.width > width ? img.copyResize(photo, width: width, interpolation: img.Interpolation.cubic) : photo;
  File(out).writeAsBytesSync(img.encodeJpg(scaled, quality: quality));
  final kb = (File(out).lengthSync() / 1024).round();
  stdout.writeln('$out ${scaled.width}x${scaled.height} $kb KB');
}
