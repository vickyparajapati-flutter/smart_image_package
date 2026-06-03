import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_image_x/smart_image_x.dart';

void main() {
  group('SourceDetector', () {
    test('detects http and https network URLs', () {
      expect(
        SourceDetector.detect('https://example.com/a.png').type,
        ImageSourceType.network,
      );
      expect(
        SourceDetector.detect('http://cdn.test/i.jpg').type,
        ImageSourceType.network,
      );
    });

    test('detects asset paths', () {
      expect(
        SourceDetector.detect('assets/images/logo.png').type,
        ImageSourceType.asset,
      );
      expect(
        SourceDetector.detect('packages/foo/assets/x.webp').type,
        ImageSourceType.asset,
      );
    });

    test('detects absolute and relative file paths', () {
      expect(
        SourceDetector.detect('/var/tmp/photo.jpg').type,
        ImageSourceType.file,
      );
      expect(
        SourceDetector.detect('./local/pic.png').type,
        ImageSourceType.file,
      );
      expect(
        SourceDetector.detect(r'C:\images\pic.png').type,
        ImageSourceType.file,
      );
    });

    test('detects raw bytes as memory', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final resolved = SourceDetector.detect(bytes);
      expect(resolved.type, ImageSourceType.memory);
      expect(resolved.bytes, bytes);
    });

    test('detects List<int> as memory', () {
      final resolved = SourceDetector.detect(<int>[1, 2, 3]);
      expect(resolved.type, ImageSourceType.memory);
    });

    test('detects inline SVG markup', () {
      const svg = '<svg viewBox="0 0 1 1"><rect width="1" height="1"/></svg>';
      final resolved = SourceDetector.detect(svg);
      expect(resolved.type, ImageSourceType.svgString);
      expect(resolved.svgMarkup, svg);
    });

    test('detects SVG with XML prolog', () {
      const svg = '<?xml version="1.0"?><svg></svg>';
      expect(SourceDetector.detect(svg).type, ImageSourceType.svgString);
    });

    test('detects data URIs as base64', () {
      const pixel =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M8AAAMBAQDJ/pLvAAAAAElFTkSuQmCC';
      final resolved = SourceDetector.detect(pixel);
      expect(resolved.type, ImageSourceType.base64);
      expect(resolved.bytes, isNotNull);
    });

    test('detects bare base64 payloads', () {
      final raw = base64.encode(List<int>.generate(64, (i) => i % 256));
      final resolved = SourceDetector.detect(raw);
      expect(resolved.type, ImageSourceType.base64);
    });

    test('returns unknown for null and empty', () {
      expect(SourceDetector.detect(null).type, ImageSourceType.unknown);
      expect(SourceDetector.detect('').type, ImageSourceType.unknown);
      expect(SourceDetector.detect(42).type, ImageSourceType.unknown);
    });

    test('passes through an already-resolved source', () {
      final original = ResolvedImageSource.network('https://x.com/a.png');
      expect(identical(SourceDetector.detect(original), original), isTrue);
    });

    test('cache keys are stable and origin-specific', () {
      expect(
        SourceDetector.detect('https://x.com/a.png').cacheKey,
        'https://x.com/a.png',
      );
      expect(
        SourceDetector.detect('assets/a.png').cacheKey,
        'asset:assets/a.png',
      );
    });
  });
}
