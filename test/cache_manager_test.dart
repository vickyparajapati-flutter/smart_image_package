import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_image_x/smart_image_x.dart';

void main() {
  // Disk operations are exercised separately; in the unit-test environment the
  // platform cache directory is unavailable, so the disk tier degrades to a
  // no-op and these tests focus on the memory tier + analytics, which is where
  // the orchestration logic lives.
  Uint8List payload(int size) => Uint8List(size);

  late CacheManager manager;

  setUp(() {
    manager = CacheManager(const CacheConfig(maxMemoryBytes: 10000));
  });

  test('memoryOnly write then read is a hit', () async {
    await manager.write('k', payload(100), CachePolicy.memoryOnly);
    final result = await manager.read('k', CachePolicy.memoryOnly);
    expect(result, isNotNull);
    expect(manager.analytics.memoryHits, 1);
    expect(manager.analytics.misses, 0);
  });

  test('read records a miss when absent', () async {
    final result = await manager.read('absent', CachePolicy.smart);
    expect(result, isNull);
    expect(manager.analytics.misses, 1);
  });

  test('fires onHit / onMiss callbacks', () async {
    var hits = 0;
    var misses = 0;
    await manager.read('x', CachePolicy.memoryOnly, onMiss: () => misses++);
    await manager.write('x', payload(10), CachePolicy.memoryOnly);
    await manager.read('x', CachePolicy.memoryOnly, onHit: () => hits++);
    expect(misses, 1);
    expect(hits, 1);
  });

  test('CachePolicy.none never reads or records analytics', () async {
    await manager.write('k', payload(10), CachePolicy.memoryOnly);
    final result = await manager.read('k', CachePolicy.none);
    expect(result, isNull);
    expect(manager.analytics.total, 0);
  });

  test('clearMemory empties the memory tier', () async {
    await manager.write('k', payload(10), CachePolicy.memoryOnly);
    manager.clearMemory();
    final result = await manager.read('k', CachePolicy.memoryOnly);
    expect(result, isNull);
  });

  test('stats reflect stored entries and hit rate', () async {
    await manager.write('a', payload(100), CachePolicy.memoryOnly);
    await manager.read('a', CachePolicy.memoryOnly); // hit
    await manager.read('b', CachePolicy.memoryOnly); // miss
    final stats = await manager.stats();
    expect(stats.memoryEntryCount, 1);
    expect(stats.memoryCacheSize, 100);
    expect(stats.hitCount, 1);
    expect(stats.missCount, 1);
    expect(stats.hitRate, 0.5);
  });
}
