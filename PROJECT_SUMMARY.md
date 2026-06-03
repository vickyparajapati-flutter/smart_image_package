# SmartImageX — Project Summary

> **One image widget for everything.** A production-grade Flutter package that
> auto-detects the source and format of any image and handles caching, retries,
> fallbacks, placeholders, BlurHash, progressive loading, zoom, galleries,
> compression and transformations — with zero configuration.

---

## 📌 At a glance

| | |
| --- | --- |
| **Package** | `smart_image_x` |
| **Version** | `1.0.1` |
| **pub.dev** | https://pub.dev/packages/smart_image_x |
| **Repository** | https://github.com/vickyparajapati-flutter/smart_image_package |
| **Latest release** | https://github.com/vickyparajapati-flutter/smart_image_package/releases/tag/v1.0.1 |
| **License** | MIT |
| **Author** | Vicky Parajapati |
| **Status** | ✅ Published & live |

### Quality metrics

| Metric | Result |
| --- | --- |
| Tests | **197 passing** |
| Line coverage | **~90%** |
| `flutter analyze` | **0 issues** (lib + test + example) |
| Publish dry-run | **0 warnings** |
| Platforms | Android · iOS · macOS · Windows · Linux · Web |

---

## 🎯 What it does

A developer never needs separate packages for SVG, cached images, loaders,
error handling, retry, zoom, progressive loading, BlurHash, galleries,
compression or image utilities. One widget covers them all:

```dart
SmartImage(image: anything)
```

`anything` = a **network URL**, **asset path**, **file path**, **`Uint8List`**,
**base64 / `data:` URI**, or **inline SVG markup** — detected automatically.

---

## ✨ Feature checklist

- **Auto source detection** — network · asset · file · memory · base64 · SVG.
- **Auto format detection** — PNG · JPEG · WebP · GIF · SVG · AVIF\* · BMP
  (by magic bytes, then MIME, then extension).
- **Two-tier cache** — memory LRU + persistent disk, with TTL, size-bounded
  eviction, hit/miss analytics, and opportunistic gzip compression.
- **Cache policies** — `smart` · `memoryOnly` · `diskOnly` · `refresh` · `none`.
- **Retry engine** — exponential backoff + jitter, retryability rules.
- **Fallback chain** — primary → fallback image → fallback icon → error widget.
- **Loaders** — circular (determinate) · shimmer · skeleton · custom builder.
- **BlurHash** placeholders — decoded **natively** (no dependency).
- **Progressive loading** — low-res `thumbnail` first, then the full image.
- **Zoom & viewers** — inline pinch/double-tap/pan, full-screen viewer, and a
  swipeable hero-animated `SmartImageGallery` (built on `InteractiveViewer`).
- **Effects** — grayscale · blur · brightness · contrast · saturation (run in a
  background isolate).
- **Image utilities** — compress · resize · crop · convert · rotate · flip ·
  metadata via `SmartImageTools`.
- **Adaptive quality** — smaller decode on slow connections.
- **Network** — streamed download progress, priority queue, concurrency cap.
- **Accessibility** — semantic labels & image semantics.
- **Theming** — light/dark-aware placeholders and error states.
- **Security** — optional `allowedDomains` whitelist (global + per-widget).
- **Callbacks** — `onLoadStart`, `onLoadSuccess`, `onLoadError`, `onRetry`,
  `onFallback`, `onCacheHit`, `onCacheMiss`, `onProgress`.

\* AVIF rendering depends on host-platform codec support.

---

## 🏗️ Architecture

A layered, SOLID pipeline (full detail in [`doc/ARCHITECTURE.md`](doc/ARCHITECTURE.md)):

```
Source Detector → Format Detector → Loader (Cache → Network → Retry)
  → Transform → Renderer (raster | vector) → SmartImage widget
```

Source layout (`lib/src/`):

```
enums/  models/  callbacks/  source_detector/  format_detector/
cache/  analytics/  retry/  services/  compression/  blurhash/
renderer/  viewer/  gallery/  widgets/  utils/
```

The public API is exposed through a single barrel: `lib/smart_image_x.dart`.

---

## 📦 Dependencies (bundled internally — the app needs none of these directly)

| Package | Purpose |
| --- | --- |
| `flutter_svg` | SVG rendering |
| `http` | Streamed network downloads + progress |
| `path_provider` | Disk-cache directory |
| `crypto` | Cache keys (SHA-256) |
| `connectivity_plus` | Adaptive-quality connection detection |
| `image` | Compression / transform / metadata codec |

BlurHash decoding and the zoom/gallery viewers are implemented **in-package**
(no extra dependency).

---

## 🧪 Testing & quality

- **197 tests** across detection, cache (memory + disk + compression), network,
  retry, BlurHash, models, utilities and the widget state machine.
- **~90% line coverage.**
- `flutter analyze` clean under strict lints (`flutter_lints` 6).

```bash
flutter test --coverage
flutter analyze
```

---

## 📱 Example app

A polished, screenshot-ready Material 3 showcase ([`example/`](example/)) with a
`NavigationBar` across five sections — **Sources, Features, Gallery, Tools,
Cache** — a light/dark theme toggle, and every demo labelled with its source
type, a code snippet, and "use when / avoid when" guidance.

```bash
cd example
flutter run
```

Screenshots (light + dark) live in [`screenshots/`](screenshots/).

---

## 🚀 Installation & usage

```yaml
dependencies:
  smart_image_x: ^1.0.1
```

```dart
import 'package:smart_image_x/smart_image_x.dart';

SmartImage(image: 'https://example.com/photo.jpg')      // network, cached
SmartImage(image: 'assets/logo.svg')                    // SVG asset
SmartImage(image: myUint8List)                          // bytes
SmartImage(image: url, blurHash: hash, enableZoom: true)
```

Static helpers:

```dart
await SmartImage.preload(url);
final stats = await SmartImage.cacheStats();
await SmartImage.clearCache();
final meta = await SmartImage.getMetadata(bytes);
```

---

## 🗂️ Version history

| Version | Notes |
| --- | --- |
| **1.0.1** | Docs: absolute README image URLs so screenshots render on pub.dev. |
| **1.0.0** | Initial release — full feature set, 197 tests, ~90% coverage. |

See [`CHANGELOG.md`](CHANGELOG.md) for details.

---

## 📚 Documentation map

| File | Contents |
| --- | --- |
| [`README.md`](README.md) | Install, quick start, full API, caching, troubleshooting, FAQ. |
| [`doc/ARCHITECTURE.md`](doc/ARCHITECTURE.md) | Layered design, diagrams, trade-offs. |
| [`CHANGELOG.md`](CHANGELOG.md) | Release history. |
| [`example/`](example/) | Runnable showcase app. |
| [`screenshots/`](screenshots/) | Light/dark screenshots. |

---

_Generated 2026-06-03._
