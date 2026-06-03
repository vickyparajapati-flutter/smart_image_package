/// Thread-of-control-safe counters for cache hit/miss analytics.
///
/// A single instance is owned by the cache manager and folded into the
/// [CacheStats] returned by `SmartImage.cacheStats()`. Counters are monotonic
/// for the life of the process unless explicitly [reset].
class CacheAnalytics {
  int _memoryHits = 0;
  int _diskHits = 0;
  int _misses = 0;

  /// Hits served from the in-memory tier.
  int get memoryHits => _memoryHits;

  /// Hits served from the on-disk tier.
  int get diskHits => _diskHits;

  /// Total hits across both tiers.
  int get hits => _memoryHits + _diskHits;

  /// Total misses (had to fetch from origin).
  int get misses => _misses;

  /// Total recorded lookups.
  int get total => hits + _misses;

  /// Fraction of lookups served from cache (`0.0..1.0`).
  double get hitRate => total == 0 ? 0 : hits / total;

  /// Fraction of lookups that missed (`0.0..1.0`).
  double get missRate => total == 0 ? 0 : _misses / total;

  /// Records a hit in the memory tier.
  void recordMemoryHit() => _memoryHits++;

  /// Records a hit in the disk tier.
  void recordDiskHit() => _diskHits++;

  /// Records a miss.
  void recordMiss() => _misses++;

  /// Resets every counter to zero.
  void reset() {
    _memoryHits = 0;
    _diskHits = 0;
    _misses = 0;
  }
}
