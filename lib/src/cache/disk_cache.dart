import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../models/cache_config.dart';
import '../utils/logger.dart';

/// A persistent, TTL- and size-bounded disk cache for encoded image payloads.
///
/// Files are named by the SHA-256 of their cache key, so keys of arbitrary
/// length and content map to safe, fixed-length filenames. Entry freshness is
/// derived from the file's last-modified time against
/// [CacheConfig.diskEntryTtl]; size enforcement evicts the oldest files first.
///
/// All public methods are safe to call before [ensureInitialized] completes —
/// they await initialisation internally. On platforms without a filesystem
/// (e.g. the web target) initialisation fails gracefully and every operation
/// becomes a no-op.
class DiskCache {
  /// Creates a disk cache governed by [config].
  DiskCache(this.config);

  /// Cache tuning parameters.
  final CacheConfig config;

  Directory? _directory;
  Future<void>? _initFuture;
  bool _available = false;

  /// Lazily initialises the cache directory exactly once.
  Future<void> ensureInitialized() {
    return _initFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      final base = await getTemporaryDirectory();
      final dir = Directory('${base.path}/${config.subDirectory}');
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      _directory = dir;
      _available = true;
      // Opportunistically prune expired entries on startup.
      unawaited(cleanupExpired());
    } catch (error, stack) {
      _available = false;
      SmartLogger.warning('Disk cache unavailable: $error');
      SmartLogger.verbose(() => stack.toString());
    }
  }

  /// Whether the disk cache is usable on this platform.
  bool get isAvailable => _available;

  /// Returns the cached bytes for [key], or `null` on a miss or if the entry
  /// has expired (expired entries are deleted as a side effect).
  Future<Uint8List?> get(String key) async {
    await ensureInitialized();
    if (!_available) return null;
    final file = _fileFor(key);
    try {
      if (!file.existsSync()) return null;
      if (_isExpired(file)) {
        await file.delete();
        return null;
      }
      // Touch to mark as recently used for size-based eviction ordering.
      await file.setLastModified(_now());
      return _decode(await file.readAsBytes());
    } catch (error) {
      SmartLogger.warning('Disk cache read failed for "$key": $error');
      return null;
    }
  }

  /// Persists [bytes] under [key], enforcing the size ceiling afterwards.
  Future<void> put(String key, Uint8List bytes) async {
    await ensureInitialized();
    if (!_available) return;
    try {
      final file = _fileFor(key);
      await file.writeAsBytes(_encode(bytes), flush: false);
      await _enforceSizeLimit();
    } catch (error) {
      SmartLogger.warning('Disk cache write failed for "$key": $error');
    }
  }

  /// Whether a fresh entry exists for [key].
  Future<bool> contains(String key) async {
    await ensureInitialized();
    if (!_available) return false;
    final file = _fileFor(key);
    return file.existsSync() && !_isExpired(file);
  }

  /// Removes the entry for [key], if present.
  Future<void> remove(String key) async {
    await ensureInitialized();
    if (!_available) return;
    final file = _fileFor(key);
    if (file.existsSync()) {
      try {
        await file.delete();
      } catch (_) {/* best-effort */}
    }
  }

  /// Deletes every cached file.
  Future<void> clear() async {
    await ensureInitialized();
    if (!_available || _directory == null) return;
    try {
      if (_directory!.existsSync()) {
        await _directory!.delete(recursive: true);
        await _directory!.create(recursive: true);
      }
    } catch (error) {
      SmartLogger.warning('Disk cache clear failed: $error');
    }
  }

  /// Total bytes currently occupied on disk.
  Future<int> currentBytes() async {
    final files = await _listFiles();
    var total = 0;
    for (final f in files) {
      total += _safeLength(f);
    }
    return total;
  }

  /// Number of cached files.
  Future<int> fileCount() async => (await _listFiles()).length;

  /// Deletes every entry older than [CacheConfig.diskEntryTtl].
  Future<int> cleanupExpired() async {
    await ensureInitialized();
    if (!_available) return 0;
    var removed = 0;
    for (final file in await _listFiles()) {
      if (_isExpired(file)) {
        try {
          await file.delete();
          removed++;
        } catch (_) {/* best-effort */}
      }
    }
    if (removed > 0) SmartLogger.info('Disk cache: pruned $removed expired entries');
    return removed;
  }

  Future<void> _enforceSizeLimit() async {
    final files = await _listFiles();
    var total = 0;
    for (final f in files) {
      total += _safeLength(f);
    }
    if (total <= config.maxDiskBytes) return;

    // Oldest-first eviction until under the ceiling.
    files.sort((a, b) => _safeModified(a).compareTo(_safeModified(b)));
    for (final file in files) {
      if (total <= config.maxDiskBytes) break;
      final size = _safeLength(file);
      try {
        await file.delete();
        total -= size;
      } catch (_) {/* best-effort */}
    }
  }

  Future<List<File>> _listFiles() async {
    await ensureInitialized();
    if (!_available || _directory == null) return const [];
    try {
      return _directory!
          .listSync()
          .whereType<File>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  // Storage format: a one-byte header (_rawTag / _gzipTag) followed by the
  // payload. Compression is only kept when it actually shrinks the data, so
  // already-compressed raster formats are stored verbatim with no size cost.
  static const int _rawTag = 0x00;
  static const int _gzipTag = 0x01;

  Uint8List _encode(Uint8List bytes) {
    if (config.compressDiskEntries) {
      try {
        final compressed = gzip.encode(bytes);
        if (compressed.length < bytes.length) {
          final out = Uint8List(compressed.length + 1)
            ..[0] = _gzipTag
            ..setRange(1, compressed.length + 1, compressed);
          return out;
        }
      } catch (_) {
        // Fall through to storing raw.
      }
    }
    final out = Uint8List(bytes.length + 1)
      ..[0] = _rawTag
      ..setRange(1, bytes.length + 1, bytes);
    return out;
  }

  Uint8List _decode(Uint8List stored) {
    if (stored.isEmpty) return stored;
    final payload = Uint8List.sublistView(stored, 1);
    if (stored[0] == _gzipTag) {
      return Uint8List.fromList(gzip.decode(payload));
    }
    return Uint8List.fromList(payload);
  }

  File _fileFor(String key) => File('${_directory!.path}/${_hash(key)}');

  bool _isExpired(File file) {
    final age = _now().difference(_safeModified(file));
    return age > config.diskEntryTtl;
  }

  DateTime _now() => DateTime.now();

  static int _safeLength(File f) {
    try {
      return f.lengthSync();
    } catch (_) {
      return 0;
    }
  }

  static DateTime _safeModified(File f) {
    try {
      return f.lastModifiedSync();
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  static String _hash(String key) => sha256.convert(utf8.encode(key)).toString();
}
