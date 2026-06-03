import 'package:flutter/foundation.dart';

import '../analytics/cache_analytics.dart';
import '../enums/cache_policy.dart';
import '../models/cache_config.dart';
import '../models/cache_stats.dart';
import '../models/smart_image_config.dart';
import '../utils/logger.dart';
import 'disk_cache.dart';
import 'memory_cache.dart';

/// Orchestrates the two-tier cache (memory → disk) and exposes the public
/// cache-management surface used by `SmartImage`'s static API.
///
/// The manager never touches the network itself: callers supply bytes via
/// [write] after fetching. This keeps the cache and the transport concerns
/// cleanly separated (Single Responsibility) and makes the manager trivial to
/// unit test without any network or platform mocking — see `cache_test.dart`.
class CacheManager {
  /// Creates a manager over [config]. Prefer the shared [instance] in app code.
  CacheManager(CacheConfig config)
      : _config = config,
        _memory = MemoryCache(
          maxBytes: config.maxMemoryBytes,
          maxEntries: config.maxMemoryEntries,
        ),
        _disk = DiskCache(config),
        analytics = CacheAnalytics();

  CacheConfig _config;
  MemoryCache _memory;
  final DiskCache _disk;

  /// Hit/miss counters folded into [stats].
  final CacheAnalytics analytics;

  static CacheManager? _instance;

  /// The process-wide cache manager, lazily built from
  /// [SmartImageConfig.instance].
  static CacheManager get instance =>
      _instance ??= CacheManager(SmartImageConfig.instance.cache);

  /// Rebuilds the shared instance against a new [config]. Existing in-memory
  /// entries are discarded; disk entries are retained.
  static void reconfigure(CacheConfig config) {
    _instance?._reconfigure(config);
    _instance ??= CacheManager(config);
  }

  /// Test seam: replaces the shared instance.
  static set debugInstance(CacheManager manager) => _instance = manager;

  /// Test seam: rebuilds this instance's tiers against a new [config].
  @visibleForTesting
  void debugReconfigure(CacheConfig config) => _reconfigure(config);

  void _reconfigure(CacheConfig config) {
    _config = config;
    _memory = MemoryCache(
      maxBytes: config.maxMemoryBytes,
      maxEntries: config.maxMemoryEntries,
    );
  }

  /// Reads bytes for [key] honouring [policy].
  ///
  /// On a memory or disk hit the value is promoted into faster tiers and
  /// [onHit] fires; on a complete miss [onMiss] fires and `null` is returned so
  /// the caller can fetch from the origin. Returns `null` immediately (without
  /// recording analytics) for policies that bypass reads
  /// ([CachePolicy.none], [CachePolicy.refresh]).
  Future<Uint8List?> read(
    String key,
    CachePolicy policy, {
    void Function()? onHit,
    void Function()? onMiss,
  }) async {
    if (!_config.enabled || policy.forcesNetwork || policy == CachePolicy.none) {
      return null;
    }

    if (policy.readsMemory) {
      final mem = _memory.get(key);
      if (mem != null) {
        analytics.recordMemoryHit();
        SmartLogger.verbose(() => 'Cache: memory hit "$key"');
        onHit?.call();
        return mem;
      }
    }

    if (policy.readsDisk) {
      final disk = await _disk.get(key);
      if (disk != null) {
        analytics.recordDiskHit();
        SmartLogger.verbose(() => 'Cache: disk hit "$key"');
        // Promote to memory for subsequent reads.
        if (policy.readsMemory) _memory.put(key, disk);
        onHit?.call();
        return disk;
      }
    }

    analytics.recordMiss();
    SmartLogger.verbose(() => 'Cache: miss "$key"');
    onMiss?.call();
    return null;
  }

  /// Writes [bytes] for [key] into every tier permitted by [policy].
  Future<void> write(String key, Uint8List bytes, CachePolicy policy) async {
    if (!_config.enabled || !policy.writesCache) return;
    if (policy.readsMemory || policy == CachePolicy.refresh) {
      _memory.put(key, bytes);
    }
    if (policy.readsDisk ||
        policy == CachePolicy.refresh ||
        policy == CachePolicy.smart) {
      await _disk.put(key, bytes);
    }
  }

  /// Clears both tiers.
  Future<void> clearAll() async {
    _memory.clear();
    await _disk.clear();
    SmartLogger.info('Cache: cleared all tiers');
  }

  /// Clears only the in-memory tier.
  void clearMemory() {
    _memory.clear();
    SmartLogger.info('Cache: cleared memory tier');
  }

  /// Clears only the on-disk tier.
  Future<void> clearDisk() async {
    await _disk.clear();
    SmartLogger.info('Cache: cleared disk tier');
  }

  /// Removes a single [key] from both tiers.
  Future<void> evict(String key) async {
    _memory.remove(key);
    await _disk.remove(key);
  }

  /// Prunes expired disk entries; returns the number removed.
  Future<int> cleanupExpired() => _disk.cleanupExpired();

  /// Builds a current [CacheStats] snapshot.
  Future<CacheStats> stats() async {
    return CacheStats(
      memoryCacheSize: _memory.currentBytes,
      diskCacheSize: await _disk.currentBytes(),
      memoryEntryCount: _memory.length,
      diskFileCount: await _disk.fileCount(),
      hitCount: analytics.hits,
      missCount: analytics.misses,
    );
  }
}
