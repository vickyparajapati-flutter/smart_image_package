import 'package:flutter_test/flutter_test.dart';
import 'package:smart_image_x/smart_image_x.dart';

void main() {
  group('CacheStats', () {
    test('computes hit and miss rates', () {
      const stats = CacheStats(
        memoryCacheSize: 1024,
        diskCacheSize: 2048,
        memoryEntryCount: 2,
        diskFileCount: 4,
        hitCount: 3,
        missCount: 1,
      );
      expect(stats.totalLookups, 4);
      expect(stats.hitRate, 0.75);
      expect(stats.missRate, 0.25);
    });

    test('handles zero lookups without dividing by zero', () {
      const stats = CacheStats.empty();
      expect(stats.hitRate, 0);
      expect(stats.missRate, 0);
    });

    test('converts byte sizes to MB', () {
      const stats = CacheStats(
        memoryCacheSize: 1024 * 1024,
        diskCacheSize: 5 * 1024 * 1024,
        memoryEntryCount: 0,
        diskFileCount: 0,
        hitCount: 0,
        missCount: 0,
      );
      expect(stats.memoryCacheSizeMb, 1.0);
      expect(stats.diskCacheSizeMb, 5.0);
    });
  });

  group('DownloadProgress', () {
    test('reports determinate progress as a percentage', () {
      const progress = DownloadProgress(received: 50, total: 200);
      expect(progress.isDeterminate, isTrue);
      expect(progress.fraction, 0.25);
      expect(progress.percent, 25);
    });

    test('reports indeterminate progress when total is unknown', () {
      const progress = DownloadProgress(received: 50, total: -1);
      expect(progress.isDeterminate, isFalse);
      expect(progress.fraction, isNull);
      expect(progress.percent, isNull);
    });

    test('clamps fraction to 1.0', () {
      const progress = DownloadProgress(received: 300, total: 200);
      expect(progress.fraction, 1.0);
    });
  });

  group('SmartImageException.isRetryable', () {
    test('network errors are retryable', () {
      const e = SmartImageException(SmartImageErrorType.network, 'x');
      expect(e.isRetryable, isTrue);
    });

    test('5xx and 429 are retryable; 4xx are not', () {
      const server = SmartImageException(
        SmartImageErrorType.httpStatus,
        'x',
        statusCode: 503,
      );
      const rateLimit = SmartImageException(
        SmartImageErrorType.httpStatus,
        'x',
        statusCode: 429,
      );
      const notFound = SmartImageException(
        SmartImageErrorType.httpStatus,
        'x',
        statusCode: 404,
      );
      expect(server.isRetryable, isTrue);
      expect(rateLimit.isRetryable, isTrue);
      expect(notFound.isRetryable, isFalse);
    });

    test('decode and notFound are not retryable', () {
      expect(
        const SmartImageException(SmartImageErrorType.decode, 'x').isRetryable,
        isFalse,
      );
      expect(
        const SmartImageException(SmartImageErrorType.notFound, 'x').isRetryable,
        isFalse,
      );
    });
  });

  group('CachePolicy', () {
    test('smart reads both tiers and writes', () {
      expect(CachePolicy.smart.readsMemory, isTrue);
      expect(CachePolicy.smart.readsDisk, isTrue);
      expect(CachePolicy.smart.writesCache, isTrue);
    });

    test('none reads nothing and writes nothing', () {
      expect(CachePolicy.none.readsMemory, isFalse);
      expect(CachePolicy.none.writesCache, isFalse);
    });

    test('refresh forces a network fetch', () {
      expect(CachePolicy.refresh.forcesNetwork, isTrue);
    });
  });

  group('ImagePriority', () {
    test('weights are strictly ordered', () {
      expect(ImagePriority.low.weight, lessThan(ImagePriority.normal.weight));
      expect(
        ImagePriority.normal.weight,
        lessThan(ImagePriority.high.weight),
      );
      expect(
        ImagePriority.high.weight,
        lessThan(ImagePriority.critical.weight),
      );
    });
  });
}
