import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_image_x/smart_image_x.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageFormat getters', () {
    test('extensions and mime types for every format', () {
      expect(ImageFormat.bmp.extension, 'bmp');
      expect(ImageFormat.bmp.mimeType, 'image/bmp');
      expect(ImageFormat.avif.extension, 'avif');
      expect(ImageFormat.avif.mimeType, 'image/avif');
      expect(ImageFormat.gif.extension, 'gif');
      expect(ImageFormat.webp.isAnimated, isTrue);
      expect(ImageFormat.avif.isRaster, isTrue);
      expect(ImageFormat.bmp.isRaster, isTrue);
    });
  });

  group('RetryConfig boundary', () {
    test('non-positive attempts yield zero delay', () {
      const config = RetryConfig();
      expect(config.delayForAttempt(0), Duration.zero);
      expect(config.delayForAttempt(-3), Duration.zero);
    });
  });

  group('CacheConfig copyWith full coverage', () {
    test('overrides ttl, subDirectory and enabled', () {
      const base = CacheConfig();
      final updated = base.copyWith(
        diskEntryTtl: const Duration(days: 1),
        subDirectory: 'custom',
        enabled: false,
        maxMemoryEntries: 99,
        maxDiskBytes: 12345,
      );
      expect(updated.diskEntryTtl, const Duration(days: 1));
      expect(updated.subDirectory, 'custom');
      expect(updated.enabled, isFalse);
      expect(updated.maxMemoryEntries, 99);
      expect(updated.maxDiskBytes, 12345);
    });
  });

  group('SmartImage compact error', () {
    testWidgets('uses the compact error widget for tiny targets',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SmartImage(
                image: 7, // unknown source
                width: 40,
                height: 40,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      // Compact variant shows no "Retry" label.
      expect(find.text('Retry'), findsNothing);
    });
  });
}
