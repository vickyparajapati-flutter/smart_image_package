import 'package:flutter_test/flutter_test.dart';
import 'package:smart_image_x/smart_image_x.dart';

void main() {
  // A valid 4x3-component BlurHash from the reference test vectors.
  const validHash = r'LEHV6nWB2yk8pyo0adR*.7kCMdnj';

  group('BlurHashDecoder.isValid', () {
    test('accepts a well-formed hash', () {
      expect(BlurHashDecoder.isValid(validHash), isTrue);
    });

    test('rejects too-short strings', () {
      expect(BlurHashDecoder.isValid('abc'), isFalse);
      expect(BlurHashDecoder.isValid(''), isFalse);
    });

    test('rejects hashes with an inconsistent length', () {
      expect(BlurHashDecoder.isValid('${validHash}EXTRA'), isFalse);
    });
  });

  group('BlurHashDecoder.decodeToRgba', () {
    test('produces an RGBA buffer of the requested size', () {
      final pixels = BlurHashDecoder.decodeToRgba(
        validHash,
        width: 16,
        height: 12,
      );
      expect(pixels.length, 16 * 12 * 4);
    });

    test('every alpha byte is fully opaque', () {
      final pixels = BlurHashDecoder.decodeToRgba(validHash, width: 8, height: 8);
      for (var i = 3; i < pixels.length; i += 4) {
        expect(pixels[i], 255);
      }
    });

    test('all colour channels are valid bytes', () {
      final pixels = BlurHashDecoder.decodeToRgba(validHash, width: 8, height: 8);
      for (final value in pixels) {
        expect(value, inInclusiveRange(0, 255));
      }
    });

    test('throws on an invalid hash', () {
      expect(
        () => BlurHashDecoder.decodeToRgba('!!'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
