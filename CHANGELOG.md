# Changelog

All notable changes to **SmartImageX** are documented here. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.0.0

Initial release — "one image widget for everything".

### Added

- **`SmartImage`** widget with automatic source and format detection.
- **Source detection** for network URLs, asset paths, file paths, `Uint8List`,
  `List<int>`, base64 / `data:` URIs and inline SVG markup.
- **Format detection** by magic bytes (PNG, JPEG, WebP, GIF, SVG, AVIF, BMP)
  with MIME and extension fallbacks.
- **Two-tier cache** (in-memory LRU + persistent disk) with `CachePolicy`
  strategies, TTL-based expiry, size-bounded eviction and analytics.
- **Opportunistic disk-cache compression** — entries are gzipped only when it
  actually shrinks them (a real win for SVG/text, a no-op for raster), toggled
  via `CacheConfig.compressDiskEntries`.
- Static cache API: `clearCache`, `clearMemoryCache`, `clearDiskCache`,
  `cleanupCache`, `preload`, `preloadAll`, `cacheStats`, `getMetadata`.
- **Network layer** with streamed byte-level progress, a priority queue and a
  global concurrency cap.
- **Retry engine** with exponential backoff, jitter and retryability rules.
- **Fallback chain**: primary → fallback image → fallback icon → error widget.
- **Loaders**: circular (determinate), shimmer, skeleton, and custom builders.
- **BlurHash** placeholder support via a native, dependency-free decoder.
- **Progressive loading** via a `thumbnail` source.
- **Zoom**: inline pinch / double-tap / pan, plus a full-screen viewer.
- **`SmartImageGallery`**: swipeable, zoomable, hero-animated gallery.
- **Adaptive quality** that downscales decode resolution on slow connections.
- **Image utilities** (`SmartImageTools`): compress, resize, crop, convert,
  rotate, flip, and colour transforms — all off the UI thread.
- **Accessibility**: semantic labels and image semantics.
- **Theming**: light/dark-aware placeholders and error states.
- **Security**: optional `allowedDomains` whitelist (global and per-widget).
- Eight lifecycle callbacks: `onLoadStart`, `onLoadSuccess`, `onLoadError`,
  `onRetry`, `onFallback`, `onCacheHit`, `onCacheMiss`, `onProgress`.

### Known limitations

- WebP **encoding** is unavailable in the pure-Dart codec (decoding works);
  `CompressionFormat.webp` throws a descriptive error. Use JPEG or PNG.
- AVIF rendering depends on host-platform codec support.
