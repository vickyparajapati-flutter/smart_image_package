<div align="center">

# SmartImageX

### One image widget for everything.

[![pub package](https://img.shields.io/badge/pub-1.0.0-blue.svg)](https://pub.dev)
[![license: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![style: flutter_lints](https://img.shields.io/badge/style-flutter__lints-blue.svg)](https://pub.dev/packages/flutter_lints)

</div>

SmartImageX replaces a stack of single-purpose image packages with **one
widget** that figures everything out for you — the source, the format, caching,
retries, fallbacks, placeholders, zoom, galleries and more.

```dart
SmartImage(image: anything)
```

That's the whole API for the common case. `anything` can be a network URL, an
asset path, a file path, a `Uint8List`, a base64 string, a `data:` URI or inline
SVG markup. SmartImageX detects what it is, picks the right renderer, caches it,
and shows a placeholder while it loads — with **zero configuration**.

---

## Table of contents

- [Why SmartImageX](#why-smartimagex)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Advanced usage](#advanced-usage)
- [Supported sources & formats](#supported-sources--formats)
- [Caching](#caching)
- [Loaders, errors & fallbacks](#loaders-errors--fallbacks)
- [Zoom, viewer & gallery](#zoom-viewer--gallery)
- [Progressive loading & BlurHash](#progressive-loading--blurhash)
- [Image utilities](#image-utilities)
- [Lifecycle callbacks](#lifecycle-callbacks)
- [Global configuration](#global-configuration)
- [Static API reference](#static-api-reference)
- [Performance guide](#performance-guide)
- [Architecture](#architecture)
- [Migration guide](#migration-guide)
- [Testing](#testing)
- [Contributing](#contributing)

---

## Why SmartImageX

A typical Flutter app pulls in several packages to handle images:
`cached_network_image`, `flutter_svg`, `photo_view`, `shimmer`,
`flutter_blurhash`, `flutter_image_compress`, plus glue code to wire them
together. SmartImageX collapses all of that into a single, cohesive widget with
a clean architecture and a great default experience.

| You used to need…            | Now you write…                          |
| ---------------------------- | --------------------------------------- |
| `cached_network_image`       | `SmartImage(image: url)`                |
| `flutter_svg`                | `SmartImage(image: url)` *(auto-SVG)*   |
| `photo_view` / lightbox      | `SmartImage(image: url, enableZoom: true)` |
| `shimmer` placeholders       | built-in (`LoaderType.shimmer`)         |
| `flutter_blurhash`           | `SmartImage(image: url, blurHash: h)`   |
| `flutter_image_compress`     | `SmartImageTools.compressImage(bytes)`  |
| gallery viewer               | `SmartImageGallery(images: [...])`      |

## Installation

Add the dependency:

```yaml
dependencies:
  smart_image_x: ^1.0.0
```

Then:

```bash
flutter pub get
```

Import the single library:

```dart
import 'package:smart_image_x/smart_image_x.dart';
```

> **Platforms:** Android, iOS, macOS, Windows, Linux. The disk cache uses the
> platform temporary directory; on web the disk tier degrades gracefully to
> memory-only.

## Quick start

```dart
// Network image — cached, retried, with a shimmer placeholder, automatically.
SmartImage(image: 'https://example.com/photo.jpg')

// Asset — detected from the path.
SmartImage(image: 'assets/logo.png')

// SVG — detected from the markup or the .svg extension.
SmartImage(image: 'assets/icon.svg')

// Raw bytes / base64 / data URI — all just work.
SmartImage(image: myUint8List)
SmartImage(image: 'data:image/png;base64,iVBORw0...')
```

## Advanced usage

Every behaviour is overridable on the widget:

```dart
SmartImage(
  image: imageUrl,

  width: 120,
  height: 120,
  fit: BoxFit.cover,

  // Shape
  shape: BoxShape.circle,             // or borderRadius for rounded corners
  borderRadius: BorderRadius.circular(12),

  // Placeholders & errors
  loaderType: LoaderType.shimmer,
  loadingBuilder: (context) => const MyLoader(),
  errorBuilder: (context, error) => MyError(error),

  // Fallback chain: image → icon → error widget
  fallbackImage: 'assets/default_user.png',
  fallbackIcon: Icons.person,

  // Resilience
  retryCount: 3,
  retryDelay: const Duration(seconds: 1),

  // Interaction
  enableZoom: true,                   // inline pinch/double-tap zoom
  openViewerOnTap: true,              // or full-screen on tap
  heroTag: 'profile',

  // Perception
  blurHash: blurHashString,           // instant placeholder
  thumbnail: thumbUrl,                // progressive load
  transition: TransitionType.fade,
  transitionDuration: const Duration(milliseconds: 300),

  // Performance & policy
  adaptiveQuality: true,
  cachePolicy: CachePolicy.smart,
  priority: ImagePriority.high,

  // Effects (processed off the UI thread)
  grayscale: true,
  blur: 4,
  brightness: 0.1,
  contrast: 110,
  saturation: 1.2,

  // Accessibility & security
  semanticLabel: 'User profile photo',
  allowedDomains: ['cdn.example.com'],

  // Callbacks
  onLoadStart: () {},
  onLoadSuccess: () {},
  onLoadError: (error) {},
  onRetry: (attempt, error) {},
  onFallback: () {},
  onCacheHit: () {},
  onCacheMiss: () {},
  onProgress: (p) => print('${p.percent}%'),
)
```

## Supported sources & formats

**Sources** (auto-detected, no configuration):

| Source        | Example                                    |
| ------------- | ------------------------------------------ |
| Network URL   | `https://…/a.png`                          |
| Asset         | `assets/a.png`                             |
| File          | `/storage/a.jpg`, `C:\a.png`               |
| Bytes         | `Uint8List` / `List<int>`                  |
| Base64        | bare base64 or `data:image/png;base64,…`   |
| Inline SVG    | `<svg>…</svg>`                             |

**Formats** (detected by magic bytes first, then MIME, then extension):

PNG · JPEG · WebP · GIF · SVG · AVIF\* · BMP

\* AVIF rendering depends on host-platform codec support.

## Caching

Caching is **on by default** with a two-tier flow:

```
request → memory (LRU) → disk (TTL + size bounded) → network → write back
```

Choose a policy per widget:

```dart
SmartImage(image: url, cachePolicy: CachePolicy.smart)      // default
SmartImage(image: url, cachePolicy: CachePolicy.memoryOnly)
SmartImage(image: url, cachePolicy: CachePolicy.diskOnly)
SmartImage(image: url, cachePolicy: CachePolicy.refresh)    // bust + repopulate
SmartImage(image: url, cachePolicy: CachePolicy.none)       // bypass
```

Manage and inspect the cache through the static API:

```dart
await SmartImage.preload(url);
await SmartImage.preloadAll([url1, url2, url3]);

final stats = await SmartImage.cacheStats();
print('hit rate: ${(stats.hitRate * 100).toStringAsFixed(1)}%');
print('disk: ${stats.diskCacheSizeMb.toStringAsFixed(1)} MB');

SmartImage.clearMemoryCache();
await SmartImage.clearDiskCache();
await SmartImage.clearCache();
```

## Loaders, errors & fallbacks

Placeholder styles: `LoaderType.circular` (determinate when progress is known),
`LoaderType.shimmer`, `LoaderType.skeleton`, or a custom `loadingBuilder`.

On failure SmartImageX walks a **fallback chain**:

```
primary image → fallbackImage → fallbackIcon → errorBuilder → default error UI
```

The default error UI is theme-aware and offers a manual **Retry** button.

## Zoom, viewer & gallery

```dart
// Inline zoom (pinch, double-tap, pan) — no extra package.
SmartImage(image: url, enableZoom: true)

// Tap to open a full-screen, zoomable viewer with a hero transition.
SmartImage(image: url, openViewerOnTap: true, heroTag: 'hero')

// A swipeable, zoomable gallery.
SmartImageGallery(images: photoUrls, initialIndex: 2)

// Or open it as a route on demand.
SmartImageGallery.open(context, images: photoUrls, initialIndex: index);
```

## Progressive loading & BlurHash

```dart
// Show a tiny thumbnail first, then swap in the full image.
SmartImage(image: fullUrl, thumbnail: thumbUrl)

// Show a BlurHash placeholder instantly (decoded natively — no dependency).
SmartImage(image: fullUrl, blurHash: 'L6PZfSi_.AyE_3t7t7R**0o#DgR4')
```

## Image utilities

Standalone, isolate-backed helpers for one-off processing:

```dart
final jpeg   = await SmartImageTools.compressImage(bytes, quality: 70);
final thumb  = await SmartImageTools.resizeImage(bytes, width: 200);
final cut    = await SmartImageTools.cropImage(bytes, x: 0, y: 0, width: 100, height: 100);
final png    = await SmartImageTools.convertFormat(bytes, CompressionFormat.png);
final turned = await SmartImageTools.rotateImage(bytes, 90);
final mirror = await SmartImageTools.flipImage(bytes);

final meta = await SmartImage.getMetadata(bytes); // width, height, format, EXIF…
```

## Lifecycle callbacks

`onLoadStart`, `onLoadSuccess`, `onLoadError`, `onRetry`, `onFallback`,
`onCacheHit`, `onCacheMiss`, `onProgress` — wire any subset you need.

## Global configuration

Set process-wide defaults once at startup:

```dart
void main() {
  SmartImageConfig.configure(
    const SmartImageConfig(
      cache: CacheConfig(
        maxMemoryBytes: 64 * 1024 * 1024,
        maxDiskBytes: 256 * 1024 * 1024,
        diskEntryTtl: Duration(days: 7),
      ),
      defaultRetry: RetryConfig(maxAttempts: 4),
      defaultLoaderType: LoaderType.shimmer,
      maxConcurrentDownloads: 6,
      allowedDomains: ['cdn.example.com'],
      logLevel: SmartImageLogLevel.warning,
    ),
  );
  runApp(const MyApp());
}
```

## Static API reference

| Method                              | Description                                |
| ----------------------------------- | ------------------------------------------ |
| `SmartImage.clearCache()`           | Clear memory **and** disk tiers.           |
| `SmartImage.clearMemoryCache()`     | Clear the in-memory tier.                  |
| `SmartImage.clearDiskCache()`       | Clear the on-disk tier.                    |
| `SmartImage.cleanupCache()`         | Prune expired disk entries.                |
| `SmartImage.cacheStats()`           | Return a `CacheStats` snapshot.            |
| `SmartImage.preload(image)`         | Warm the cache for one source.             |
| `SmartImage.preloadAll([...])`      | Warm the cache for many sources.           |
| `SmartImage.getMetadata(image)`     | Read `ImageMetadata` (size, format, EXIF). |

## Performance guide

- **Use it in lists.** Each `SmartImage` resolves lazily and shares the global
  cache; combine with `cacheWidth`-style decode hints via `adaptiveQuality` to
  bound memory.
- **Set explicit `width`/`height`.** This lets the decoder downscale and keeps
  layout stable.
- **Pick the cheapest placeholder for long lists.** `LoaderType.skeleton` is a
  single paint with no animation; `shimmer` animates and costs a little more.
- **Preload above-the-fold imagery** with `SmartImage.preloadAll(...)` and a
  high `priority`.
- **Effects run off the UI thread** (background isolates), so `grayscale`,
  `blur` and friends won't jank scrolling — but they do re-encode, so prefer
  pre-processing static assets at build time.
- **Tune the cache** to your app's working set via `CacheConfig`.

## Architecture

SmartImageX is built as a layered, SOLID pipeline. See
[`doc/ARCHITECTURE.md`](doc/ARCHITECTURE.md) for the full design, diagrams and
the rationale behind each decision. In brief:

```
Source Detector → Format Detector → Loader (Cache → Network → Retry)
  → Transform → Renderer (raster | vector) → SmartImage widget
```

## Migration guide

**From `cached_network_image`:**

```dart
// Before
CachedNetworkImage(imageUrl: url, placeholder: (c, _) => Spinner());
// After
SmartImage(image: url, loadingBuilder: (c) => const Spinner());
```

**From `flutter_svg`:** drop the explicit `SvgPicture` — `SmartImage(image: …)`
auto-detects SVG.

**From `photo_view`:** replace with `SmartImage(image: url, enableZoom: true)`
or `SmartImageGallery`.

**From `flutter_blurhash`:** pass the hash to `SmartImage(blurHash: …)`.

## Testing

```bash
flutter test
```

The package ships with unit and widget tests covering source/format detection,
the cache, the retry engine, BlurHash decoding, the models, the image utilities
and the widget state machine.

## Contributing

Issues and PRs are welcome. Please run `flutter analyze` and `flutter test`
before submitting; both must be clean.

## License

MIT — see [LICENSE](LICENSE).
