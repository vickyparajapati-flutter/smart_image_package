import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_image_x/smart_image_x.dart';

Uint8List _bytes(List<int> values, {int pad = 0}) {
  final list = List<int>.from(values)..addAll(List.filled(pad, 0));
  return Uint8List.fromList(list);
}

void main() {
  group('FormatDetector.fromBytes', () {
    test('detects PNG signature', () {
      final png = _bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      expect(FormatDetector.fromBytes(png), ImageFormat.png);
    });

    test('detects JPEG signature', () {
      final jpeg = _bytes([0xFF, 0xD8, 0xFF, 0xE0]);
      expect(FormatDetector.fromBytes(jpeg), ImageFormat.jpeg);
    });

    test('detects GIF signature', () {
      final gif = _bytes([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]);
      expect(FormatDetector.fromBytes(gif), ImageFormat.gif);
    });

    test('detects WEBP via RIFF + WEBP fourCC', () {
      final webp = _bytes([
        0x52, 0x49, 0x46, 0x46, // RIFF
        0x00, 0x00, 0x00, 0x00, // size
        0x57, 0x45, 0x42, 0x50, // WEBP
      ]);
      expect(FormatDetector.fromBytes(webp), ImageFormat.webp);
    });

    test('detects AVIF via ftyp brand', () {
      final avif = _bytes([
        0x00, 0x00, 0x00, 0x18,
        0x66, 0x74, 0x79, 0x70, // ftyp
        0x61, 0x76, 0x69, 0x66, // avif
      ]);
      expect(FormatDetector.fromBytes(avif), ImageFormat.avif);
    });

    test('detects SVG markup bytes', () {
      final svg = Uint8List.fromList('<svg></svg>'.codeUnits);
      expect(FormatDetector.fromBytes(svg), ImageFormat.svg);
    });

    test('returns unknown for noise', () {
      expect(
        FormatDetector.fromBytes(_bytes([0x01, 0x02, 0x03, 0x04])),
        ImageFormat.unknown,
      );
    });
  });

  group('FormatDetector hints', () {
    test('fromExtension maps common extensions', () {
      expect(FormatDetector.fromExtension('jpg'), ImageFormat.jpeg);
      expect(FormatDetector.fromExtension('.JPEG'), ImageFormat.jpeg);
      expect(FormatDetector.fromExtension('svg'), ImageFormat.svg);
      expect(FormatDetector.fromExtension('xyz'), ImageFormat.unknown);
    });

    test('fromPath strips query and fragment', () {
      expect(
        FormatDetector.fromPath('https://x.com/a.png?v=2#frag'),
        ImageFormat.png,
      );
    });

    test('fromMimeType maps content types', () {
      expect(FormatDetector.fromMimeType('image/webp'), ImageFormat.webp);
      expect(
        FormatDetector.fromMimeType('image/svg+xml; charset=utf-8'),
        ImageFormat.svg,
      );
    });

    test('resolve prefers magic bytes over path', () {
      final png = _bytes([0x89, 0x50, 0x4E, 0x47]);
      // Path says jpg but bytes say png — bytes win.
      expect(
        FormatDetector.resolve(bytes: png, path: 'a.jpg'),
        ImageFormat.png,
      );
    });
  });

  group('ImageFormat properties', () {
    test('classifies raster vs vector', () {
      expect(ImageFormat.png.isRaster, isTrue);
      expect(ImageFormat.svg.isVector, isTrue);
      expect(ImageFormat.gif.isAnimated, isTrue);
    });
  });
}
