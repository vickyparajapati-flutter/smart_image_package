/// Strategy that governs how a [SmartImage] reads from and writes to the
/// two-tier cache (memory + disk).
///
/// The default for every widget is [CachePolicy.smart], which transparently
/// promotes/demotes bytes between tiers and falls back to the network only
/// when necessary.
enum CachePolicy {
  /// Full two-tier flow: memory → disk → network, writing back to every tier
  /// on a miss. This is the recommended default for almost all use cases.
  smart,

  /// Use only the in-memory LRU cache. Bytes are never persisted to disk and
  /// do not survive an app restart. Useful for sensitive or short-lived
  /// imagery.
  memoryOnly,

  /// Use only the persistent disk cache. Decoded frames are still held by
  /// Flutter's [ImageCache], but SmartImageX will not retain raw bytes in its
  /// own memory tier.
  diskOnly,

  /// Bypass every cache tier and always fetch from the origin. Bytes are not
  /// written back.
  none,

  /// Force a fresh network fetch, then overwrite any existing cached entry.
  /// Equivalent to a cache-busting reload that repopulates the cache.
  refresh;

  /// Whether this policy permits reading from the in-memory tier.
  bool get readsMemory =>
      this == CachePolicy.smart || this == CachePolicy.memoryOnly;

  /// Whether this policy permits reading from the persistent disk tier.
  bool get readsDisk =>
      this == CachePolicy.smart || this == CachePolicy.diskOnly;

  /// Whether this policy permits writing bytes back into any cache tier.
  bool get writesCache => this != CachePolicy.none;

  /// Whether this policy must hit the network even when a cached copy exists.
  bool get forcesNetwork => this == CachePolicy.refresh;
}
