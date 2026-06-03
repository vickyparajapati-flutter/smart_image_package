# SmartImageX — Architecture

This document explains how SmartImageX is structured, why it is structured that
way, and how data flows through it. The guiding goal is the project's headline
promise — **`SmartImage(image: anything)` just works** — achieved without
sacrificing testability, performance or maintainability.

## Design principles

1. **Zero configuration by default, full control when needed.** Every widget
   parameter has a sensible default sourced from a global `SmartImageConfig`.
2. **Single Responsibility per layer.** Detection, caching, transport, retry,
   rendering and processing are independent units with narrow interfaces.
3. **Pure where possible.** Detectors, the LRU, the retry policy and the models
   are pure Dart with no Flutter or platform dependencies, so they are trivially
   unit-testable (and indeed are tested without a widget tree).
4. **Off the UI thread for heavy work.** All codec work (compress, transform,
   metadata) runs in background isolates via `compute`.
5. **Fail gracefully.** Disk cache unavailable? Degrade to memory. Network
   down? Retry, then fall back. Bad source? Categorised error, not a crash.

## Layered pipeline

```
                         ┌───────────────────────────┐
   image: Object  ─────► │   Source Detection Layer   │  → ResolvedImageSource
                         └───────────────────────────┘
                                       │
                         ┌───────────────────────────┐
                         │   Image Loader Service     │  (the coordinator)
                         │                            │
                         │   ┌──────────────────────┐ │
                         │   │  Cache Layer          │ │  memory LRU + disk
                         │   ├──────────────────────┤ │
                         │   │  Network Layer        │ │  priority queue,
                         │   │  (+ Retry Engine)     │ │  streamed progress
                         │   ├──────────────────────┤ │
                         │   │  Format Detection     │ │  magic-byte sniffing
                         │   ├──────────────────────┤ │
                         │   │  Transform Layer      │ │  isolate-backed
                         │   └──────────────────────┘ │
                         └───────────────────────────┘
                                       │  LoadedImage (provider | svg)
                         ┌───────────────────────────┐
                         │      Renderer Layer        │  Image | SvgPicture
                         └───────────────────────────┘
                                       │
                         ┌───────────────────────────┐
                         │     SmartImage widget      │  state machine, shape,
                         │  (placeholder/loaded/error)│  hero, zoom, callbacks
                         └───────────────────────────┘
```

## Directory layout

The published API lives behind `lib/smart_image_x.dart`; all implementation is
under `lib/src/`, organised by layer. The spec's conceptual folders map onto
`lib/src/` directories one-to-one:

```
lib/
├── smart_image_x.dart            # public barrel — the only import users need
└── src/
    ├── enums/                    # CachePolicy, ImageFormat, ImagePriority, …
    ├── models/                   # ResolvedImageSource, CacheStats, configs, …
    ├── callbacks/                # lifecycle typedefs + bundle
    ├── source_detector/          # Source Detection Layer
    ├── format_detector/          # Format Detection Layer
    ├── cache/                    # MemoryCache, DiskCache, CacheManager
    ├── analytics/                # CacheAnalytics (hit/miss metrics)
    ├── retry/                    # RetryEngine
    ├── services/                 # NetworkService, ConnectivityService,
    │                             #   ImageLoaderService, MetadataService
    ├── compression/              # ImageCompressor, ImageTransformer
    ├── blurhash/                 # native decoder + view
    ├── renderer/                 # ImageRenderer (raster/vector strategy)
    ├── viewer/                   # ZoomableImage, SmartImageViewer
    ├── gallery/                  # SmartImageGallery
    ├── widgets/                  # SmartImage, loaders, error/fallback widgets
    ├── utils/                    # logger, domain guard, byte resolver
    └── smart_image_tools.dart    # public utilities facade
```

## Layer responsibilities

### Source Detection (`SourceDetector`)

Pure, synchronous classifier turning an `Object` into a `ResolvedImageSource`.
Ordered most-specific-first (inline SVG → data URI → URL → asset → file →
base64) so ambiguous strings resolve deterministically. Performs no I/O.

### Format Detection (`FormatDetector`)

Authoritative detection by **magic bytes** (file signatures), independent of
extension or server MIME — both of which lie often enough to matter. Falls back
to MIME, then extension, when bytes are unavailable.

### Cache (`MemoryCache`, `DiskCache`, `CacheManager`)

- `MemoryCache` — a byte-size- and count-bounded LRU over a `LinkedHashMap`.
- `DiskCache` — SHA-256-keyed files under the platform temp dir, with
  last-modified-based TTL and oldest-first size eviction. Initialises lazily and
  degrades to a no-op where no filesystem exists.
- `CacheManager` — orchestrates the two tiers (`memory → disk`), promotes disk
  hits into memory, and records analytics. It deliberately never touches the
  network: callers supply bytes after fetching, keeping caching and transport
  decoupled and the manager fully unit-testable.

### Network (`NetworkService`) + Retry (`RetryEngine`)

`NetworkService` streams downloads for byte-level progress, orders requests by
`ImagePriority` and caps concurrency. `RetryEngine` wraps fetches with
exponential backoff + jitter, consulting `SmartImageException.isRetryable` so
404s fail fast while 503s and dropped connections retry.

### Loader (`ImageLoaderService`)

The coordinator. Given a resolved source it runs the right stages and returns a
`LoadedImage` — either a raster `ImageProvider` or an SVG descriptor. Network
sources go cache → retry/network → cache-write → format-resolve → transform.
Asset/file sources without effects defer to Flutter's own `AssetImage`/
`FileImage` so the framework handles lazy decode and its decoded-frame cache.

### Renderer (`ImageRenderer`)

A pure presenter that chooses `Image` (raster) or `SvgPicture` (vector), applies
the entrance transition via `frameBuilder`, surfaces decode errors back to the
controller, and honours decode-size hints (`ResizeImage`) for memory control.

### Widget (`SmartImage`)

A `StatefulWidget` whose state is a small machine: `loading → loaded | error`.
It owns the fallback chain, progressive thumbnail, BlurHash placeholder, shape
clipping, hero wrapping, zoom/viewer interaction, semantics and the eight
lifecycle callbacks. A monotonic load token guards against stale async
completions when the source changes mid-flight.

## Concurrency & threading model

- **UI thread:** detection, cache lookups, widget building — all cheap and
  synchronous.
- **Async I/O:** network and disk operations are `Future`-based and cancellable
  via the load token.
- **Background isolates:** compression, transformation and metadata extraction
  run through `compute`, so codec work never blocks frames.

## Error model

A single `SmartImageException` carries a categorised `SmartImageErrorType`
(`invalidSource`, `blockedDomain`, `network`, `httpStatus`, `decode`,
`notFound`, `unknown`), an optional HTTP status, and the underlying cause. Its
`isRetryable` getter centralises retry policy in one place.

## Extensibility

- New formats: extend `FormatDetector` signatures and `ImageFormat`.
- New source kinds: extend `SourceDetector` and `ImageSourceType`.
- New placeholders: add a `LoaderType` and a case in `SmartLoader`, or pass a
  `loadingBuilder`.
- New transforms: add fields to `TransformSpec` and a step in the isolate.

## Key trade-offs

| Decision | Rationale | Trade-off |
| --- | --- | --- |
| Bundle `flutter_svg`, `image`, etc. internally | Honours "no extra packages for the developer" | Larger dependency closure for the package |
| Pre-fetch bytes for network, then `MemoryImage` | Enables progress, retry, and our own cache | Bypasses Flutter's network-image cache (we provide our own) |
| Native BlurHash decoder | Removes a dependency; small, well-specified algorithm | Maintained in-tree |
| Magic-byte format detection | Correct regardless of extension/MIME lies | A few bytes read before classification |
| WebP encode unsupported | Pure-Dart codec limitation; honesty over silent fallback | Callers must use JPEG/PNG to encode |
