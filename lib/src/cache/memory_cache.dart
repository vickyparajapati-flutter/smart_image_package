import 'dart:collection';
import 'dart:typed_data';

/// An in-memory, byte-size-bounded LRU cache for encoded image payloads.
///
/// Eviction is driven by two independent ceilings — total bytes and entry
/// count — whichever is hit first. Recency is tracked by the insertion order
/// of a [LinkedHashMap]: on every read or write the entry is moved to the most
/// recently used position, so eviction always removes the true LRU entry.
///
/// This tier stores *encoded* bytes (not decoded pixels). Decoded frames are
/// handled separately by Flutter's own [ImageCache]; keeping encoded bytes
/// here lets SmartImageX rehydrate decoded frames without a disk or network
/// round-trip after Flutter evicts them.
class MemoryCache {
  /// Creates a memory cache bounded by [maxBytes] and [maxEntries].
  MemoryCache({
    required this.maxBytes,
    required this.maxEntries,
  })  : assert(maxBytes > 0),
        assert(maxEntries > 0);

  /// Total byte ceiling.
  final int maxBytes;

  /// Entry-count ceiling.
  final int maxEntries;

  final LinkedHashMap<String, Uint8List> _entries =
      LinkedHashMap<String, Uint8List>();
  int _currentBytes = 0;

  /// Current total bytes held.
  int get currentBytes => _currentBytes;

  /// Current entry count.
  int get length => _entries.length;

  /// Whether [key] is present (does not affect recency).
  bool contains(String key) => _entries.containsKey(key);

  /// Returns the bytes for [key], promoting it to most-recently-used, or `null`
  /// on a miss.
  Uint8List? get(String key) {
    final value = _entries.remove(key);
    if (value == null) return null;
    _entries[key] = value; // Re-insert at MRU position.
    return value;
  }

  /// Inserts or replaces [key] with [bytes], evicting LRU entries as needed.
  ///
  /// An entry larger than [maxBytes] on its own is not cached (it would force
  /// out everything else and immediately need eviction itself).
  void put(String key, Uint8List bytes) {
    if (bytes.lengthInBytes > maxBytes) return;

    final existing = _entries.remove(key);
    if (existing != null) _currentBytes -= existing.lengthInBytes;

    _entries[key] = bytes;
    _currentBytes += bytes.lengthInBytes;

    _evictIfNeeded();
  }

  /// Removes [key] if present, returning whether anything was removed.
  bool remove(String key) {
    final removed = _entries.remove(key);
    if (removed == null) return false;
    _currentBytes -= removed.lengthInBytes;
    return true;
  }

  /// Empties the cache.
  void clear() {
    _entries.clear();
    _currentBytes = 0;
  }

  void _evictIfNeeded() {
    while (_entries.isNotEmpty &&
        (_currentBytes > maxBytes || _entries.length > maxEntries)) {
      // The first key in iteration order is the least recently used.
      final lruKey = _entries.keys.first;
      final removed = _entries.remove(lruKey);
      if (removed != null) _currentBytes -= removed.lengthInBytes;
    }
  }
}
