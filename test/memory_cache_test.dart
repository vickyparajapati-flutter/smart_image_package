import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_image_x/src/cache/memory_cache.dart';

Uint8List _payload(int size) => Uint8List(size);

void main() {
  group('MemoryCache', () {
    test('stores and retrieves values', () {
      final cache = MemoryCache(maxBytes: 1000, maxEntries: 10);
      cache.put('a', _payload(100));
      expect(cache.get('a'), isNotNull);
      expect(cache.length, 1);
      expect(cache.currentBytes, 100);
    });

    test('returns null on miss', () {
      final cache = MemoryCache(maxBytes: 1000, maxEntries: 10);
      expect(cache.get('missing'), isNull);
    });

    test('evicts least-recently-used entry when over byte limit', () {
      final cache = MemoryCache(maxBytes: 250, maxEntries: 10);
      cache.put('a', _payload(100));
      cache.put('b', _payload(100));
      // Touch 'a' so 'b' becomes the LRU.
      cache.get('a');
      cache.put('c', _payload(100)); // total would be 300 > 250 → evict 'b'.
      expect(cache.get('a'), isNotNull);
      expect(cache.get('b'), isNull);
      expect(cache.get('c'), isNotNull);
    });

    test('evicts when over entry-count limit', () {
      final cache = MemoryCache(maxBytes: 100000, maxEntries: 2);
      cache.put('a', _payload(10));
      cache.put('b', _payload(10));
      cache.put('c', _payload(10));
      expect(cache.length, 2);
      expect(cache.get('a'), isNull); // oldest evicted
    });

    test('does not cache an item larger than the whole cache', () {
      final cache = MemoryCache(maxBytes: 50, maxEntries: 10);
      cache.put('big', _payload(100));
      expect(cache.get('big'), isNull);
      expect(cache.currentBytes, 0);
    });

    test('replacing a key updates byte accounting', () {
      final cache = MemoryCache(maxBytes: 1000, maxEntries: 10);
      cache.put('a', _payload(100));
      cache.put('a', _payload(50));
      expect(cache.currentBytes, 50);
      expect(cache.length, 1);
    });

    test('remove and clear', () {
      final cache = MemoryCache(maxBytes: 1000, maxEntries: 10);
      cache.put('a', _payload(100));
      expect(cache.remove('a'), isTrue);
      expect(cache.remove('a'), isFalse);
      cache.put('b', _payload(100));
      cache.clear();
      expect(cache.length, 0);
      expect(cache.currentBytes, 0);
    });
  });
}
