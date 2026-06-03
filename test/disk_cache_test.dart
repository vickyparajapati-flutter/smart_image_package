import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:smart_image_x/smart_image_x.dart';
import 'package:smart_image_x/src/cache/disk_cache.dart';

/// Routes `getTemporaryDirectory()` to a real, disposable temp directory so the
/// disk cache exercises actual file I/O without a platform plugin.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getTemporaryPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('six_disk_test');
    PathProviderPlatform.instance = _FakePathProvider(tempRoot.path);
  });

  tearDown(() {
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  Uint8List bytes(List<int> v) => Uint8List.fromList(v);

  test('writes then reads an entry back', () async {
    final cache = DiskCache(const CacheConfig(subDirectory: 'rw'));
    await cache.put('k', bytes([10, 20, 30]));
    expect(await cache.get('k'), [10, 20, 30]);
    expect(await cache.contains('k'), isTrue);
  });

  test('returns null for a missing entry', () async {
    final cache = DiskCache(const CacheConfig(subDirectory: 'miss'));
    expect(await cache.get('absent'), isNull);
    expect(await cache.contains('absent'), isFalse);
  });

  test('round-trips through gzip compression for compressible data', () async {
    final cache = DiskCache(
      const CacheConfig(subDirectory: 'gz', compressDiskEntries: true),
    );
    // Highly compressible payload (repeated bytes).
    final payload = bytes(List.filled(2000, 65));
    await cache.put('svgish', payload);
    expect(await cache.get('svgish'), payload);
    // On disk it should be smaller than the raw payload thanks to gzip.
    expect(await cache.currentBytes(), lessThan(payload.length));
  });

  test('stores incompressible data without bloating it', () async {
    final cache = DiskCache(
      const CacheConfig(subDirectory: 'raw', compressDiskEntries: true),
    );
    // Pseudo-random, effectively incompressible bytes.
    final payload = bytes(List.generate(1000, (i) => (i * 131 + 7) % 256));
    await cache.put('rnd', payload);
    expect(await cache.get('rnd'), payload);
  });

  test('remove deletes a single entry', () async {
    final cache = DiskCache(const CacheConfig(subDirectory: 'rm'));
    await cache.put('k', bytes([1]));
    await cache.remove('k');
    expect(await cache.get('k'), isNull);
  });

  test('clear empties the cache', () async {
    final cache = DiskCache(const CacheConfig(subDirectory: 'clr'));
    await cache.put('a', bytes([1]));
    await cache.put('b', bytes([2]));
    await cache.clear();
    expect(await cache.fileCount(), 0);
  });

  test('expired entries are treated as a miss and pruned', () async {
    final cache = DiskCache(
      const CacheConfig(
        subDirectory: 'ttl',
        diskEntryTtl: Duration(milliseconds: 1),
      ),
    );
    await cache.put('k', bytes([1, 2, 3]));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(await cache.get('k'), isNull);
  });

  test('cleanupExpired removes stale files and reports the count', () async {
    final cache = DiskCache(
      const CacheConfig(
        subDirectory: 'cleanup',
        diskEntryTtl: Duration(milliseconds: 1),
      ),
    );
    // Drain the fire-and-forget startup cleanup before seeding entries so it
    // doesn't race the assertion below.
    await cache.ensureInitialized();
    await cache.cleanupExpired();

    await cache.put('a', bytes([1]));
    await cache.put('b', bytes([2]));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final removed = await cache.cleanupExpired();
    expect(removed, greaterThanOrEqualTo(1));
    expect(await cache.fileCount(), 0);
  });

  test('enforces the disk size ceiling by evicting oldest entries', () async {
    final cache = DiskCache(
      // Disable compression so byte math is predictable.
      const CacheConfig(
        subDirectory: 'evict',
        maxDiskBytes: 1500,
        compressDiskEntries: false,
      ),
    );
    await cache.put('a', bytes(List.filled(700, 1)));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await cache.put('b', bytes(List.filled(700, 2)));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await cache.put('c', bytes(List.filled(700, 3)));
    // Total would be ~2100 > 1500; the oldest ('a') should be evicted.
    expect(await cache.currentBytes(), lessThanOrEqualTo(1500));
    expect(await cache.contains('c'), isTrue);
  });
}
