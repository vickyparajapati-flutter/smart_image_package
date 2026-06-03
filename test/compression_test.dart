import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:smart_image_x/smart_image_x.dart';

/// Builds a deterministic test PNG of the given size.
Uint8List _testPng({int width = 64, int height = 48}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgba(x, y, x * 4 % 256, y * 4 % 256, 128, 255);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('ImageCompressor', () {
    test('compresses a PNG to JPEG', () async {
      final png = _testPng();
      final jpeg = await SmartImageTools.compressImage(
        png,
        format: CompressionFormat.jpg,
        quality: 60,
      );
      expect(FormatDetector.fromBytes(jpeg), ImageFormat.jpeg);
    });

    test('resize honours an explicit width and preserves aspect ratio',
        () async {
      final png = _testPng(width: 100, height: 50);
      final resized = await SmartImageTools.resizeImage(png, width: 50);
      final decoded = img.decodeImage(resized)!;
      expect(decoded.width, 50);
      expect(decoded.height, 25);
    });

    test('convertFormat re-encodes without resizing', () async {
      final png = _testPng(width: 30, height: 30);
      final jpeg = await SmartImageTools.convertFormat(
        png,
        CompressionFormat.jpg,
      );
      final decoded = img.decodeImage(jpeg)!;
      expect(decoded.width, 30);
      expect(decoded.height, 30);
    });

    test('compress with maxWidth downscales oversized images', () async {
      final png = _testPng(width: 200, height: 100);
      final out = await SmartImageTools.compressImage(
        png,
        format: CompressionFormat.png,
        maxWidth: 80,
      );
      final decoded = img.decodeImage(out)!;
      expect(decoded.width, lessThanOrEqualTo(80));
    });

    test('WebP encoding throws a descriptive error', () async {
      final png = _testPng();
      await expectLater(
        SmartImageTools.convertFormat(png, CompressionFormat.webp),
        throwsA(isA<SmartImageException>()),
      );
    });
  });

  group('ImageTransformer', () {
    test('grayscale produces equal RGB channels', () async {
      final png = _testPng(width: 16, height: 16);
      final out = await SmartImageTools.transform(
        png,
        const TransformSpec(grayscale: true),
      );
      final decoded = img.decodeImage(out)!;
      final pixel = decoded.getPixel(8, 8);
      expect(pixel.r.round(), pixel.g.round());
      expect(pixel.g.round(), pixel.b.round());
    });

    test('crop yields the requested dimensions', () async {
      final png = _testPng(width: 100, height: 100);
      final out = await SmartImageTools.cropImage(
        png,
        x: 10,
        y: 10,
        width: 40,
        height: 30,
      );
      final decoded = img.decodeImage(out)!;
      expect(decoded.width, 40);
      expect(decoded.height, 30);
    });

    test('rotate by 90 swaps width and height', () async {
      final png = _testPng(width: 80, height: 40);
      final out = await SmartImageTools.rotateImage(png, 90);
      final decoded = img.decodeImage(out)!;
      expect(decoded.width, 40);
      expect(decoded.height, 80);
    });

    test('identity transform returns the original bytes', () async {
      final png = _testPng();
      final out = await ImageTransformer.transform(png, const TransformSpec());
      expect(identical(out, png), isTrue);
    });
  });

  group('MetadataService', () {
    test('extracts dimensions and format from a PNG', () async {
      final png = _testPng(width: 64, height: 48);
      final meta = await SmartImage.getMetadata(png);
      expect(meta, isNotNull);
      expect(meta!.width, 64);
      expect(meta.height, 48);
      expect(meta.format, ImageFormat.png);
      expect(meta.aspectRatio, closeTo(64 / 48, 0.001));
    });
  });
}
