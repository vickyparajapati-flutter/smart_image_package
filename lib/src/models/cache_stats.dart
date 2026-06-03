/// A point-in-time snapshot of cache health and utilisation.
///
/// Returned by `SmartImage.cacheStats()`. All sizes are in bytes; convert with
/// [memoryCacheSizeMb] / [diskCacheSizeMb] for display.
class CacheStats {
  /// Creates an immutable stats snapshot.
  const CacheStats({
    required this.memoryCacheSize,
    required this.diskCacheSize,
    required this.memoryEntryCount,
    required this.diskFileCount,
    required this.hitCount,
    required this.missCount,
  });

  /// An all-zero snapshot.
  const CacheStats.empty()
      : memoryCacheSize = 0,
        diskCacheSize = 0,
        memoryEntryCount = 0,
        diskFileCount = 0,
        hitCount = 0,
        missCount = 0;

  /// Bytes currently held in the in-memory tier.
  final int memoryCacheSize;

  /// Bytes currently occupied by the on-disk tier.
  final int diskCacheSize;

  /// Number of entries in the in-memory tier.
  final int memoryEntryCount;

  /// Number of files in the on-disk tier.
  final int diskFileCount;

  /// Total cache hits (memory or disk) observed since process start.
  final int hitCount;

  /// Total cache misses observed since process start.
  final int missCount;

  /// Total lookups recorded ([hitCount] + [missCount]).
  int get totalLookups => hitCount + missCount;

  /// Fraction of lookups served from cache, in the range `0.0..1.0`.
  double get hitRate => totalLookups == 0 ? 0 : hitCount / totalLookups;

  /// Fraction of lookups that missed, in the range `0.0..1.0`.
  double get missRate => totalLookups == 0 ? 0 : missCount / totalLookups;

  /// In-memory tier size in mebibytes.
  double get memoryCacheSizeMb => memoryCacheSize / (1024 * 1024);

  /// On-disk tier size in mebibytes.
  double get diskCacheSizeMb => diskCacheSize / (1024 * 1024);

  /// Returns a copy with selected fields overridden.
  CacheStats copyWith({
    int? memoryCacheSize,
    int? diskCacheSize,
    int? memoryEntryCount,
    int? diskFileCount,
    int? hitCount,
    int? missCount,
  }) =>
      CacheStats(
        memoryCacheSize: memoryCacheSize ?? this.memoryCacheSize,
        diskCacheSize: diskCacheSize ?? this.diskCacheSize,
        memoryEntryCount: memoryEntryCount ?? this.memoryEntryCount,
        diskFileCount: diskFileCount ?? this.diskFileCount,
        hitCount: hitCount ?? this.hitCount,
        missCount: missCount ?? this.missCount,
      );

  /// A JSON-serialisable view, handy for diagnostics overlays and logging.
  Map<String, Object> toMap() => {
        'memoryCacheSize': memoryCacheSize,
        'diskCacheSize': diskCacheSize,
        'memoryEntryCount': memoryEntryCount,
        'diskFileCount': diskFileCount,
        'hitCount': hitCount,
        'missCount': missCount,
        'hitRate': hitRate,
        'missRate': missRate,
      };

  @override
  String toString() =>
      'CacheStats(mem: ${memoryCacheSizeMb.toStringAsFixed(1)}MB/'
      '$memoryEntryCount, disk: ${diskCacheSizeMb.toStringAsFixed(1)}MB/'
      '$diskFileCount, hitRate: ${(hitRate * 100).toStringAsFixed(1)}%)';
}
