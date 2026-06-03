/// Tuning parameters for the two-tier cache.
///
/// Supplied once at startup through `SmartImageConfig` and consumed by the
/// cache manager when it constructs the memory and disk tiers.
class CacheConfig {
  /// Creates a cache configuration.
  const CacheConfig({
    this.maxMemoryBytes = 100 * 1024 * 1024,
    this.maxMemoryEntries = 500,
    this.maxDiskBytes = 500 * 1024 * 1024,
    this.diskEntryTtl = const Duration(days: 30),
    this.subDirectory = 'smart_image_x',
    this.enabled = true,
    this.compressDiskEntries = true,
  })  : assert(maxMemoryBytes > 0),
        assert(maxMemoryEntries > 0),
        assert(maxDiskBytes > 0);

  /// Hard ceiling on the in-memory tier, in bytes. The LRU evicts oldest
  /// entries once exceeded. Defaults to 100 MiB.
  final int maxMemoryBytes;

  /// Maximum number of entries the in-memory tier retains. Defaults to 500.
  final int maxMemoryEntries;

  /// Hard ceiling on the on-disk tier, in bytes. Defaults to 500 MiB.
  final int maxDiskBytes;

  /// How long a disk entry remains valid before it is treated as stale and
  /// eligible for cleanup. Defaults to 30 days.
  final Duration diskEntryTtl;

  /// Sub-directory (under the platform cache dir) for disk storage.
  final String subDirectory;

  /// Master switch; when `false` the cache manager becomes a no-op.
  final bool enabled;

  /// Whether to gzip disk entries.
  ///
  /// Compression is applied opportunistically: an entry is only stored
  /// compressed when gzip actually shrinks it (a one-byte header records
  /// which). This is a real win for text-based payloads such as SVG and a
  /// no-op for already-compressed raster formats (PNG/JPEG/WebP), so enabling
  /// it never bloats the cache.
  final bool compressDiskEntries;

  /// Returns a copy with selected fields overridden.
  CacheConfig copyWith({
    int? maxMemoryBytes,
    int? maxMemoryEntries,
    int? maxDiskBytes,
    Duration? diskEntryTtl,
    String? subDirectory,
    bool? enabled,
    bool? compressDiskEntries,
  }) =>
      CacheConfig(
        maxMemoryBytes: maxMemoryBytes ?? this.maxMemoryBytes,
        maxMemoryEntries: maxMemoryEntries ?? this.maxMemoryEntries,
        maxDiskBytes: maxDiskBytes ?? this.maxDiskBytes,
        diskEntryTtl: diskEntryTtl ?? this.diskEntryTtl,
        subDirectory: subDirectory ?? this.subDirectory,
        enabled: enabled ?? this.enabled,
        compressDiskEntries: compressDiskEntries ?? this.compressDiskEntries,
      );
}
