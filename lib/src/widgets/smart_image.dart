import 'dart:async';

import 'package:flutter/material.dart';

import '../blurhash/blurhash_view.dart';
import '../cache/cache_manager.dart';
import '../callbacks/image_callbacks.dart';
import '../compression/image_transformer.dart';
import '../enums/cache_policy.dart';
import '../enums/image_priority.dart';
import '../enums/loader_type.dart';
import '../enums/transition_type.dart';
import '../models/cache_stats.dart';
import '../models/download_progress.dart';
import '../models/image_metadata.dart';
import '../models/retry_config.dart';
import '../models/smart_image_config.dart';
import '../models/smart_image_exception.dart';
import '../renderer/image_renderer.dart';
import '../services/connectivity_service.dart';
import '../services/image_loader_service.dart';
import '../services/metadata_service.dart';
import '../source_detector/source_detector.dart';
import '../utils/byte_resolver.dart';
import '../utils/domain_guard.dart';
import '../viewer/image_viewer.dart';
import '../viewer/zoomable_image.dart';
import 'default_error_widget.dart';
import 'loaders.dart';

/// The display phase of a [SmartImage]'s internal state machine.
enum RenderPhase {
  /// Bytes are being resolved/fetched; a placeholder is shown.
  loading,

  /// Bytes resolved; the image (or its first frame) is rendering.
  loaded,

  /// Loading failed terminally; the fallback chain renders.
  error,
}

/// The one image widget for everything.
///
/// Pass any image value to [image] — a network URL, asset path, file path,
/// `Uint8List`, base64 string or inline SVG — and SmartImageX detects the
/// source and format, fetches and caches the bytes, shows a placeholder while
/// loading, retries transient failures, falls back gracefully on error, and
/// renders the result with the requested shape, fit and transition. None of
/// that requires configuration:
///
/// ```dart
/// SmartImage(image: someUrl)
/// ```
///
/// Every behaviour is individually overridable; see the constructor parameters.
class SmartImage extends StatefulWidget {
  /// Creates a smart image.
  const SmartImage({
    required this.image,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.shape = BoxShape.rectangle,
    this.borderRadius,
    this.color,
    this.alignment = Alignment.center,
    this.loadingBuilder,
    this.errorBuilder,
    this.fallbackImage,
    this.fallbackIcon,
    this.placeholderColor,
    this.loaderType,
    this.retryCount,
    this.retryDelay,
    this.enableZoom = false,
    this.openViewerOnTap = false,
    this.heroTag,
    this.blurHash,
    this.thumbnail,
    this.adaptiveQuality,
    this.cachePolicy = CachePolicy.smart,
    this.priority = ImagePriority.normal,
    this.transition,
    this.transitionDuration,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.allowedDomains,
    this.grayscale = false,
    this.blur,
    this.brightness,
    this.contrast,
    this.saturation,
    this.onLoadStart,
    this.onLoadSuccess,
    this.onLoadError,
    this.onRetry,
    this.onFallback,
    this.onCacheHit,
    this.onCacheMiss,
    this.onProgress,
    super.key,
  });

  /// The image source — any type recognised by the source-detection engine.
  final Object image;

  /// Target width. When null the image sizes itself.
  final double? width;

  /// Target height.
  final double? height;

  /// How the image fills its box. Defaults to [BoxFit.cover].
  final BoxFit fit;

  /// Clip shape. [BoxShape.circle] produces a circular avatar.
  final BoxShape shape;

  /// Corner radius for a rounded rectangle (ignored when [shape] is circle).
  final BorderRadius? borderRadius;

  /// Optional tint colour applied to the rendered image.
  final Color? color;

  /// Alignment of the image within its box.
  final Alignment alignment;

  /// Builds a custom placeholder while loading. Overrides [loaderType].
  final WidgetBuilder? loadingBuilder;

  /// Builds a custom error widget. Receives the categorised exception.
  final Widget Function(BuildContext context, SmartImageException error)?
      errorBuilder;

  /// Image shown if the primary image fails (any [SmartImage] source type).
  final Object? fallbackImage;

  /// Icon shown if the primary (and fallback) image fails.
  final IconData? fallbackIcon;

  /// Background colour for the placeholder.
  final Color? placeholderColor;

  /// Placeholder style; defaults to the global [SmartImageConfig].
  final LoaderType? loaderType;

  /// Retry attempts on transient failure; defaults to the global config.
  final int? retryCount;

  /// Base delay between retries; defaults to the global config.
  final Duration? retryDelay;

  /// Enables inline pinch/double-tap zoom (ignored when [openViewerOnTap]).
  final bool enableZoom;

  /// Opens a full-screen zoomable viewer when tapped.
  final bool openViewerOnTap;

  /// Hero tag for shared-element transitions (also used by the viewer).
  final Object? heroTag;

  /// BlurHash string shown as an instant placeholder before the image loads.
  final String? blurHash;

  /// A low-resolution source loaded first for progressive rendering.
  final Object? thumbnail;

  /// Whether to downscale decode resolution on slow connections; defaults to
  /// the global config.
  final bool? adaptiveQuality;

  /// Cache strategy. Defaults to [CachePolicy.smart].
  final CachePolicy cachePolicy;

  /// Download priority. Defaults to [ImagePriority.normal].
  final ImagePriority priority;

  /// Placeholder→image transition; defaults to the global config.
  final TransitionType? transition;

  /// Transition duration; defaults to the global config.
  final Duration? transitionDuration;

  /// Accessibility label announced by screen readers.
  final String? semanticLabel;

  /// Whether to hide this image from the semantics tree entirely.
  final bool excludeFromSemantics;

  /// Per-widget host whitelist, checked in addition to the global one.
  final List<String>? allowedDomains;

  /// Render in greyscale.
  final bool grayscale;

  /// Gaussian blur radius in pixels.
  final int? blur;

  /// Brightness adjustment (`1.0` = unchanged).
  final double? brightness;

  /// Contrast adjustment.
  final double? contrast;

  /// Saturation adjustment (`1.0` = unchanged).
  final double? saturation;

  /// {@template smartimagex.onLoadStart}
  /// Fired when loading begins.
  /// {@endtemplate}
  final OnLoadStart? onLoadStart;

  /// Fired when the image is ready.
  final OnLoadSuccess? onLoadSuccess;

  /// Fired on terminal failure.
  final OnLoadError? onLoadError;

  /// Fired before each retry.
  final OnRetry? onRetry;

  /// Fired when falling back to a fallback image/icon.
  final OnFallback? onFallback;

  /// Fired on a cache hit.
  final OnCacheHit? onCacheHit;

  /// Fired on a cache miss.
  final OnCacheMiss? onCacheMiss;

  /// Fired with download progress (`0 → 100`).
  final OnProgress? onProgress;

  // ---------------------------------------------------------------------------
  // Static cache & preload API
  //
  // Exposed on the widget type itself so the documented surface reads as
  // `SmartImage.clearCache()`, `SmartImage.preload(url)`, etc.
  // ---------------------------------------------------------------------------

  /// Clears every cache tier (memory and disk).
  static Future<void> clearCache() => CacheManager.instance.clearAll();

  /// Clears only the in-memory cache tier.
  static void clearMemoryCache() => CacheManager.instance.clearMemory();

  /// Clears only the on-disk cache tier.
  static Future<void> clearDiskCache() => CacheManager.instance.clearDisk();

  /// Prunes expired disk entries; returns the number removed.
  static Future<int> cleanupCache() => CacheManager.instance.cleanupExpired();

  /// Returns a live [CacheStats] snapshot.
  static Future<CacheStats> cacheStats() => CacheManager.instance.stats();

  /// Warms the cache for a single source so it renders instantly later.
  ///
  /// No-ops for non-network sources (they need no warming). Errors are swallowed
  /// — preloading is best-effort.
  static Future<void> preload(
    Object image, {
    CachePolicy policy = CachePolicy.smart,
    ImagePriority priority = ImagePriority.low,
  }) async {
    try {
      final source = SourceDetector.detect(image);
      if (!source.requiresNetwork) return;
      await ImageLoaderService().load(
        source,
        policy: policy,
        priority: priority,
        retryConfig: RetryConfig.disabled,
      );
    } catch (_) {/* best-effort */}
  }

  /// Warms the cache for many sources concurrently.
  static Future<void> preloadAll(
    List<Object> images, {
    CachePolicy policy = CachePolicy.smart,
    ImagePriority priority = ImagePriority.low,
  }) {
    return Future.wait(
      images.map((i) => preload(i, policy: policy, priority: priority)),
    );
  }

  /// Reads structural [ImageMetadata] (dimensions, format, EXIF) for [image].
  ///
  /// Returns `null` for sources that cannot be decoded as raster (e.g. SVG).
  static Future<ImageMetadata?> getMetadata(Object image) async {
    final source = SourceDetector.detect(image);
    final bytes = await SmartImageBytes.resolve(source);
    if (bytes == null) return null;
    return MetadataService.fromBytes(bytes);
  }

  @override
  State<SmartImage> createState() => _SmartImageState();
}

class _SmartImageState extends State<SmartImage> {
  final ImageLoaderService _loader = ImageLoaderService();

  RenderPhase _phase = RenderPhase.loading;
  LoadedImage? _loaded;
  LoadedImage? _thumbnailLoaded;
  SmartImageException? _error;
  DownloadProgress? _progress;
  bool _firstFrameShown = false;
  bool _successFired = false;
  bool _fallbackTriggered = false;
  bool _placeholderGone = false;

  /// Monotonic token guarding against stale async completions after a reload.
  int _loadToken = 0;

  SmartImageConfig get _config => SmartImageConfig.instance;

  @override
  void initState() {
    super.initState();
    if (widget.adaptiveQuality ?? _config.adaptiveQualityByDefault) {
      // Best-effort; quality may read as unknown until the first probe lands.
      ConnectivityService.instance.start();
    }
    _startLoad();
  }

  @override
  void didUpdateWidget(SmartImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameSource(oldWidget.image, widget.image) ||
        oldWidget.cachePolicy != widget.cachePolicy ||
        oldWidget.grayscale != widget.grayscale ||
        oldWidget.blur != widget.blur) {
      _startLoad();
    }
  }

  bool _sameSource(Object a, Object b) => identical(a, b) || a == b;

  RetryConfig get _retryConfig {
    if (widget.retryCount == null && widget.retryDelay == null) {
      return _config.defaultRetry;
    }
    return _config.defaultRetry.copyWith(
      maxAttempts: widget.retryCount,
      delay: widget.retryDelay,
    );
  }

  TransformSpec? get _transformSpec {
    if (!widget.grayscale &&
        widget.blur == null &&
        widget.brightness == null &&
        widget.contrast == null &&
        widget.saturation == null) {
      return null;
    }
    return TransformSpec(
      grayscale: widget.grayscale,
      blurRadius: widget.blur,
      brightness: widget.brightness,
      contrast: widget.contrast,
      saturation: widget.saturation,
    );
  }

  SmartImageCallbacks get _callbacks => SmartImageCallbacks(
        onCacheHit: widget.onCacheHit,
        onCacheMiss: widget.onCacheMiss,
        onRetry: (attempt, error) => widget.onRetry?.call(attempt, error),
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
          widget.onProgress?.call(progress);
        },
      );

  Future<void> _startLoad() async {
    final token = ++_loadToken;
    setState(() {
      _phase = RenderPhase.loading;
      _loaded = null;
      _error = null;
      _progress = null;
      _firstFrameShown = false;
      _successFired = false;
      _fallbackTriggered = false;
      _placeholderGone = false;
    });
    widget.onLoadStart?.call();

    // Progressive: load the thumbnail first (cheap, low priority) so the user
    // sees something sharper than a blur while the full image downloads.
    if (widget.thumbnail != null) {
      unawaited(_loadThumbnail(token));
    }

    try {
      final source = SourceDetector.detect(widget.image);

      // Per-widget domain whitelist enforcement for network sources.
      if (source.requiresNetwork && widget.allowedDomains != null) {
        if (!DomainGuard.isAllowed(source.uri!, widget.allowedDomains)) {
          throw SmartImageException(
            SmartImageErrorType.blockedDomain,
            'Host "${source.uri!.host}" is not in the widget allowedDomains.',
            sourceType: source.type,
          );
        }
      }

      final loaded = await _loader.load(
        source,
        policy: widget.cachePolicy,
        priority: widget.priority,
        retryConfig: _retryConfig,
        callbacks: _callbacks,
        transform: _transformSpec,
        isCancelled: () => token != _loadToken || !mounted,
      );

      if (token != _loadToken || !mounted) return;
      setState(() {
        _loaded = loaded;
        _phase = RenderPhase.loaded;
        // SVG paints synchronously, so there is no placeholder to hold back.
        if (loaded.isSvg) _firstFrameShown = true;
      });
      // The bytes/provider are resolved and ready to display.
      _notifySuccess();
    } on SmartImageException catch (error) {
      _handleError(token, error);
    } catch (error, stack) {
      _handleError(
        token,
        SmartImageException(
          SmartImageErrorType.unknown,
          error.toString(),
          cause: error,
          stackTrace: stack,
        ),
      );
    }
  }

  Future<void> _loadThumbnail(int token) async {
    try {
      final source = SourceDetector.detect(widget.thumbnail!);
      final loaded = await _loader.load(
        source,
        policy: widget.cachePolicy,
        priority: ImagePriority.low,
        retryConfig: RetryConfig.disabled,
      );
      if (token != _loadToken || !mounted) return;
      // Only show the thumbnail if the full image hasn't arrived yet.
      if (_phase == RenderPhase.loading) {
        setState(() => _thumbnailLoaded = loaded);
      }
    } catch (_) {
      // A failed thumbnail is non-fatal; the blur/loader placeholder remains.
    }
  }

  void _handleError(int token, SmartImageException error) {
    if (token != _loadToken || !mounted) return;
    setState(() {
      _error = error;
      _phase = RenderPhase.error;
    });
    widget.onLoadError?.call(error);
    if (widget.fallbackImage != null || widget.fallbackIcon != null) {
      if (!_fallbackTriggered) {
        _fallbackTriggered = true;
        widget.onFallback?.call();
      }
    }
  }

  void _notifySuccess() {
    if (_successFired) return;
    _successFired = true;
    widget.onLoadSuccess?.call();
  }

  void _retry() => _startLoad();

  @override
  Widget build(BuildContext context) {
    Widget content = _buildContent(context);
    content = _applySize(content);
    content = _applyShape(content);

    if (widget.heroTag != null) {
      content = Hero(tag: widget.heroTag!, child: content);
    }

    content = _applyInteraction(content);

    if (!widget.excludeFromSemantics) {
      content = Semantics(
        label: widget.semanticLabel,
        image: true,
        child: content,
      );
    }
    return content;
  }

  Widget _buildContent(BuildContext context) {
    switch (_phase) {
      case RenderPhase.loading:
        return _buildPlaceholder(context);
      case RenderPhase.error:
        return _buildError(context);
      case RenderPhase.loaded:
        return _buildLoaded(context);
    }
  }

  Widget _buildLoaded(BuildContext context) {
    final loaded = _loaded!;
    final renderer = _renderLoaded(loaded);
    if (loaded.isSvg) return renderer;

    final transition = widget.transition ?? _config.defaultTransition;
    final duration =
        widget.transitionDuration ?? _config.defaultTransitionDuration;
    final isCrossFade = transition == TransitionType.crossFade;

    // For crossFade we keep the placeholder mounted and fade it out in lockstep
    // with the image fading in (a true cross-dissolve), then drop it once the
    // animation completes. For other transitions the placeholder is simply
    // removed the moment the first frame is painted.
    final Widget? placeholderLayer;
    if (isCrossFade && !_placeholderGone) {
      placeholderLayer = AnimatedOpacity(
        opacity: _firstFrameShown ? 0.0 : 1.0,
        duration: duration,
        curve: Curves.easeOut,
        onEnd: () {
          if (_firstFrameShown && mounted && !_placeholderGone) {
            setState(() => _placeholderGone = true);
          }
        },
        child: _buildPlaceholder(context),
      );
    } else if (!isCrossFade && !_firstFrameShown) {
      placeholderLayer = _buildPlaceholder(context);
    } else {
      placeholderLayer = null;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        if (placeholderLayer != null) Positioned.fill(child: placeholderLayer),
        renderer,
      ],
    );
  }

  Widget _renderLoaded(LoadedImage loaded) {
    return ImageRenderer(
      loaded: loaded,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      color: widget.color,
      semanticLabel: widget.semanticLabel,
      transition: widget.transition ?? _config.defaultTransition,
      transitionDuration:
          widget.transitionDuration ?? _config.defaultTransitionDuration,
      cacheWidth: _adaptiveCacheWidth(),
      onFirstFrame: () {
        // Remove the underlying placeholder once the raster frame is painted.
        if (mounted && !_firstFrameShown) {
          setState(() => _firstFrameShown = true);
        }
      },
      onError: (error, stack) {
        _handleError(
          _loadToken,
          SmartImageException(
            SmartImageErrorType.decode,
            'Failed to decode image.',
            cause: error,
            stackTrace: stack,
          ),
        );
      },
    );
  }

  int? _adaptiveCacheWidth() {
    final adaptive = widget.adaptiveQuality ?? _config.adaptiveQualityByDefault;
    if (!adaptive) return null;
    if (!ConnectivityService.instance.quality.prefersLowData) return null;
    // Halve decode resolution on constrained links to save memory/bandwidth.
    final logicalWidth = widget.width ?? 400;
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    return (logicalWidth * dpr * 0.5).round().clamp(16, 4096);
  }

  Widget _buildPlaceholder(BuildContext context) {
    if (_thumbnailLoaded != null) {
      return _renderLoaded(_thumbnailLoaded!);
    }
    if (widget.blurHash != null) {
      return BlurHashView(hash: widget.blurHash!, fit: widget.fit);
    }
    if (widget.loadingBuilder != null) {
      return widget.loadingBuilder!(context);
    }
    final background = widget.placeholderColor;
    final loader = SmartLoader(
      type: widget.loaderType ?? _config.defaultLoaderType,
      progress: _progress?.fraction,
    );
    if (background == null) return loader;
    return ColoredBox(color: background, child: loader);
  }

  Widget _buildError(BuildContext context) {
    // Fallback chain: fallback image → fallback icon → errorBuilder → default.
    if (widget.fallbackImage != null) {
      return SmartImage(
        image: widget.fallbackImage!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        shape: widget.shape,
        borderRadius: widget.borderRadius,
        color: widget.color,
        fallbackIcon: widget.fallbackIcon,
        errorBuilder: widget.errorBuilder,
        semanticLabel: widget.semanticLabel,
        cachePolicy: widget.cachePolicy,
        // No nested fallbackImage / blurHash / thumbnail to avoid recursion.
      );
    }
    if (widget.fallbackIcon != null) {
      return FallbackIcon(icon: widget.fallbackIcon!);
    }
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context, _error!);
    }
    return DefaultErrorWidget(
      error: _error,
      onRetry: _retryConfig.isEnabled || _error?.isRetryable == true
          ? _retry
          : null,
      compact: (widget.width ?? 80) < 64,
    );
  }

  Widget _applySize(Widget child) {
    if (widget.width == null && widget.height == null) return child;
    return SizedBox(width: widget.width, height: widget.height, child: child);
  }

  Widget _applyShape(Widget child) {
    switch (widget.shape) {
      case BoxShape.circle:
        return ClipOval(child: child);
      case BoxShape.rectangle:
        if (widget.borderRadius != null) {
          return ClipRRect(borderRadius: widget.borderRadius!, child: child);
        }
        return child;
    }
  }

  Widget _applyInteraction(Widget child) {
    if (widget.openViewerOnTap) {
      return GestureDetector(
        onTap: () => SmartImageViewer.open(
          context,
          image: widget.image,
          heroTag: widget.heroTag,
        ),
        child: child,
      );
    }
    if (widget.enableZoom) {
      return ZoomableImage(child: child);
    }
    return child;
  }
}
