import '../models/download_progress.dart';
import '../models/smart_image_exception.dart';

/// Invoked when loading begins (after source detection, before bytes arrive).
typedef OnLoadStart = void Function();

/// Invoked once the final image has been decoded and is ready to paint.
typedef OnLoadSuccess = void Function();

/// Invoked when loading fails terminally (after retries and fallbacks are
/// exhausted) with the categorised [error].
typedef OnLoadError = void Function(SmartImageException error);

/// Invoked before each retry attempt. [attempt] is 1-based; [error] is the
/// failure that triggered the retry.
typedef OnRetry = void Function(int attempt, SmartImageException error);

/// Invoked when the pipeline falls back from the primary image to a fallback
/// image or icon.
typedef OnFallback = void Function();

/// Invoked when the requested bytes were served from cache.
typedef OnCacheHit = void Function();

/// Invoked when the requested bytes were not cached and had to be fetched.
typedef OnCacheMiss = void Function();

/// Invoked with download progress for remote sources.
typedef OnProgress = void Function(DownloadProgress progress);

/// An aggregate of every lifecycle callback, threaded through the pipeline so
/// individual stages can fire the relevant hook without each taking a long
/// parameter list.
///
/// All members are optional; absent callbacks are simply not invoked.
class SmartImageCallbacks {
  /// Bundles the lifecycle callbacks. All are optional.
  const SmartImageCallbacks({
    this.onLoadStart,
    this.onLoadSuccess,
    this.onLoadError,
    this.onRetry,
    this.onFallback,
    this.onCacheHit,
    this.onCacheMiss,
    this.onProgress,
  });

  /// {@macro smartimagex.onLoadStart}
  final OnLoadStart? onLoadStart;

  /// Fired on successful decode.
  final OnLoadSuccess? onLoadSuccess;

  /// Fired on terminal failure.
  final OnLoadError? onLoadError;

  /// Fired before each retry.
  final OnRetry? onRetry;

  /// Fired when falling back.
  final OnFallback? onFallback;

  /// Fired on a cache hit.
  final OnCacheHit? onCacheHit;

  /// Fired on a cache miss.
  final OnCacheMiss? onCacheMiss;

  /// Fired with download progress.
  final OnProgress? onProgress;

  /// Whether every callback is absent (lets stages skip work cheaply).
  bool get isEmpty =>
      onLoadStart == null &&
      onLoadSuccess == null &&
      onLoadError == null &&
      onRetry == null &&
      onFallback == null &&
      onCacheHit == null &&
      onCacheMiss == null &&
      onProgress == null;
}
