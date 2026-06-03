// Generates the example app's raster sample asset.
//
// Run from the package root:  dart run tool/gen_sample_asset.dart
//
// Produces a colourful, photo-like PNG used by the example's Asset / Memory /
// Base64 / File demos so they all show the same recognisable image.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  const width = 600;
  const height = 450;
  final image = img.Image(width: width, height: height);

  // Diagonal gradient backdrop (indigo → teal).
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final t = (x + y) / (width + height);
      final r = (0x67 * (1 - t) + 0x00 * t).round();
      final g = (0x50 * (1 - t) + 0xAC * t).round();
      final b = (0xA4 * (1 - t) + 0xC1 * t).round();
      image.setPixelRgb(x, y, r, g, b);
    }
  }

  // A few soft translucent circles for visual interest.
  final circles = [
    [120, 130, 90, 0xFF, 0xD8, 0xE4],
    [470, 110, 70, 0xFF, 0xFF, 0xFF],
    [430, 330, 120, 0x21, 0x96, 0xF3],
    [200, 350, 60, 0xFF, 0xC1, 0x07],
  ];
  for (final c in circles) {
    final cx = c[0], cy = c[1], radius = c[2];
    for (var y = cy - radius; y < cy + radius; y++) {
      for (var x = cx - radius; x < cx + radius; x++) {
        if (x < 0 || y < 0 || x >= width || y >= height) continue;
        final d = math.sqrt(math.pow(x - cx, 2) + math.pow(y - cy, 2));
        if (d <= radius) {
          final alpha = (1 - d / radius) * 0.45;
          final src = image.getPixel(x, y);
          final nr = (src.r * (1 - alpha) + c[3] * alpha).round();
          final ng = (src.g * (1 - alpha) + c[4] * alpha).round();
          final nb = (src.b * (1 - alpha) + c[5] * alpha).round();
          image.setPixelRgb(x, y, nr, ng, nb);
        }
      }
    }
  }

  final out = File('example/assets/sample.png');
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(img.encodePng(image));
  stdout.writeln('Wrote ${out.path} (${out.lengthSync()} bytes)');
}
