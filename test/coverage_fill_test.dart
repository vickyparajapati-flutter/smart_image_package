import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:smart_image_x/smart_image_x.dart';
import 'package:smart_image_x/src/services/connectivity_service.dart';
import 'package:smart_image_x/src/utils/byte_resolver.dart';

Uint8List _png() {
  final image = img.Image(width: 8, height: 8);
  img.fill(image, color: img.ColorRgb8(1, 2, 3));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('ConnectivityService.classify', () {
    test('no connectivity is offline', () {
      expect(
        ConnectivityService.classify([ConnectivityResult.none]),
        ConnectionQuality.offline,
      );
      expect(ConnectivityService.classify([]), ConnectionQuality.offline);
    });

    test('wifi/ethernet is fast', () {
      expect(
        ConnectivityService.classify([ConnectivityResult.wifi]),
        ConnectionQuality.fast,
      );
      expect(
        ConnectivityService.classify([ConnectivityResult.ethernet]),
        ConnectionQuality.fast,
      );
    });

    test('mobile is slow', () {
      expect(
        ConnectivityService.classify([ConnectivityResult.mobile]),
        ConnectionQuality.slow,
      );
    });

    test('vpn/other defaults to fast', () {
      expect(
        ConnectivityService.classify([ConnectivityResult.vpn]),
        ConnectionQuality.fast,
      );
    });
  });

  group('ConnectionQuality', () {
    test('prefersLowData for slow and offline', () {
      expect(ConnectionQuality.slow.prefersLowData, isTrue);
      expect(ConnectionQuality.offline.prefersLowData, isTrue);
      expect(ConnectionQuality.fast.prefersLowData, isFalse);
    });
  });

  group('SmartImageBytes.resolve', () {
    test('returns inline bytes directly', () async {
      final png = _png();
      final result =
          await SmartImageBytes.resolve(ResolvedImageSource.memory(png));
      expect(result, png);
    });

    test('returns SVG markup bytes', () async {
      final result = await SmartImageBytes.resolve(
        ResolvedImageSource.svgString('<svg></svg>'),
      );
      expect(result, isNotNull);
    });

    test('returns null for an unknown source', () async {
      final result =
          await SmartImageBytes.resolve(ResolvedImageSource.unknown(1));
      expect(result, isNull);
    });

    test('returns null for a missing file', () async {
      final result = await SmartImageBytes.resolve(
        ResolvedImageSource.file('/no/such/path.png'),
      );
      expect(result, isNull);
    });
  });

  group('ImageFormat properties', () {
    test('extension and mimeType are consistent', () {
      expect(ImageFormat.jpeg.extension, 'jpg');
      expect(ImageFormat.jpeg.mimeType, 'image/jpeg');
      expect(ImageFormat.svg.mimeType, 'image/svg+xml');
      expect(ImageFormat.unknown.extension, 'bin');
    });
  });

  group('ImageSourceType properties', () {
    test('isRemote and isInline classify correctly', () {
      expect(ImageSourceType.network.isRemote, isTrue);
      expect(ImageSourceType.memory.isInline, isTrue);
      expect(ImageSourceType.svgString.isInline, isTrue);
      expect(ImageSourceType.asset.isInline, isFalse);
    });
  });

  group('ImageMetadata', () {
    test('computes derived values and serialises', () {
      const meta = ImageMetadata(
        width: 200,
        height: 100,
        sizeInBytes: 2048,
        format: ImageFormat.png,
        orientation: 1,
        hasAlpha: true,
      );
      expect(meta.aspectRatio, 2.0);
      expect(meta.pixelCount, 20000);
      expect(meta.sizeInKb, 2.0);
      expect(meta.toMap()['format'], 'png');
      expect(meta.toString(), contains('200x100'));
    });
  });

  group('CacheConfig.copyWith', () {
    test('overrides only the given fields', () {
      const base = CacheConfig();
      final updated = base.copyWith(
        maxMemoryBytes: 1234,
        compressDiskEntries: false,
      );
      expect(updated.maxMemoryBytes, 1234);
      expect(updated.compressDiskEntries, isFalse);
      expect(updated.maxDiskBytes, base.maxDiskBytes);
    });
  });

  group('SmartImageConfig', () {
    tearDown(SmartImageConfig.reset);

    test('configure installs and reset restores defaults', () {
      SmartImageConfig.configure(
        const SmartImageConfig(maxConcurrentDownloads: 99),
      );
      expect(SmartImageConfig.instance.maxConcurrentDownloads, 99);
      SmartImageConfig.reset();
      expect(SmartImageConfig.instance.maxConcurrentDownloads, 6);
    });

    test('copyWith overrides selectively', () {
      const base = SmartImageConfig();
      final updated = base.copyWith(logLevel: SmartImageLogLevel.verbose);
      expect(updated.logLevel, SmartImageLogLevel.verbose);
      expect(updated.maxConcurrentDownloads, base.maxConcurrentDownloads);
    });
  });

  group('CacheStats serialisation', () {
    test('toMap and toString expose key fields', () {
      const stats = CacheStats(
        memoryCacheSize: 100,
        diskCacheSize: 200,
        memoryEntryCount: 1,
        diskFileCount: 2,
        hitCount: 8,
        missCount: 2,
      );
      expect(stats.toMap()['hitRate'], 0.8);
      expect(stats.copyWith(hitCount: 0).hitCount, 0);
      expect(stats.toString(), contains('hitRate'));
    });
  });

  group('TransitionType', () {
    test('enum has the documented members', () {
      expect(TransitionType.values, contains(TransitionType.crossFade));
      expect(TransitionType.values, contains(TransitionType.scale));
    });
  });
}
