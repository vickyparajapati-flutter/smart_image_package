import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

import '../cache/cache_manager.dart';
import '../callbacks/image_callbacks.dart';
import '../compression/image_transformer.dart';
import '../enums/cache_policy.dart';
import '../enums/image_format.dart';
import '../enums/image_priority.dart';
import '../enums/image_source_type.dart';
import '../format_detector/format_detector.dart';
import '../models/image_source.dart';
import '../models/retry_config.dart';
import '../models/smart_image_exception.dart';
import '../retry/retry_engine.dart';
import 'network_service.dart';

/// How an SVG payload should be handed to the vector renderer.
enum SvgDelivery { string, asset, file, bytes }

/// A resolved description of how to deliver an SVG to `flutter_svg`.
class SvgRenderSource {
  /// Creates an SVG render descriptor.
  const SvgRenderSource(this.delivery, {this.string, this.path, this.bytes});

  /// The delivery mechanism.
  final SvgDelivery delivery;

  /// Inline markup for [SvgDelivery.string].
  final String? string;

  /// Asset/file path for [SvgDelivery.asset] / [SvgDelivery.file].
  final String? path;

  /// Raw bytes for [SvgDelivery.bytes].
  final Uint8List? bytes;
}

/// The product of loading: either a raster [ImageProvider] or an SVG source.
class LoadedImage {
  /// A raster result backed by an [ImageProvider].
  const LoadedImage.raster(this.provider, this.format)
      : svg = null,
        isSvg = false;

  /// A vector (SVG) result.
  const LoadedImage.vector(this.svg, this.format)
      : provider = null,
        isSvg = true;

  /// Provider for raster results.
  final ImageProvider? provider;

  /// Source descriptor for SVG results.
  final SvgRenderSource? svg;

  /// Whether this is an SVG result.
  final bool isSvg;

  /// The detected/known format.
  final ImageFormat format;
}

/// Turns a [ResolvedImageSource] into a renderable [LoadedImage], applying the
/// cache, retry, network, transform and adaptive-quality stages as needed.
///
/// This is the pipeline's coordinator. It owns *no* state of its own beyond the
/// injected services, so a single instance is safe to share; the [SmartImage]
/// controller calls it per load. Pure-data inputs and clearly-typed outputs
/// keep it unit-testable without a widget tree.
class ImageLoaderService {
  /// Creates a loader. Services default to their shared singletons; inject
  /// fakes in tests.
  ImageLoaderService({
    CacheManager? cacheManager,
    NetworkService? networkService,
  })  : _cache = cacheManager,
        _network = networkService;

  final CacheManager? _cache;
  final NetworkService? _network;

  CacheManager get _cacheManager => _cache ?? CacheManager.instance;
  NetworkService get _networkService => _network ?? NetworkService.instance;

  /// Loads [source].
  ///
  /// For raster sources this resolves (and, for network sources, fetches and
  /// caches) the bytes, applies [transform] when non-identity, and returns a
  /// ready [ImageProvider]. For SVG sources it returns a descriptor the
  /// renderer hands to `flutter_svg`.
  Future<LoadedImage> load(
    ResolvedImageSource source, {
    CachePolicy policy = CachePolicy.smart,
    ImagePriority priority = ImagePriority.normal,
    RetryConfig retryConfig = const RetryConfig(),
    SmartImageCallbacks callbacks = const SmartImageCallbacks(),
    TransformSpec? transform,
    bool Function()? isCancelled,
  }) async {
    switch (source.type) {
      case ImageSourceType.svgString:
        return LoadedImage.vector(
          SvgRenderSource(SvgDelivery.string, string: source.svgMarkup),
          ImageFormat.svg,
        );

      case ImageSourceType.memory:
      case ImageSourceType.base64:
        return _fromBytes(source.bytes!, transform);

      case ImageSourceType.asset:
        return _fromAsset(source.path!, transform);

      case ImageSourceType.file:
        return _fromFile(source.path!, transform);

      case ImageSourceType.network:
        return _fromNetwork(
          source,
          policy: policy,
          priority: priority,
          retryConfig: retryConfig,
          callbacks: callbacks,
          transform: transform,
          isCancelled: isCancelled,
        );

      case ImageSourceType.unknown:
        throw SmartImageException(
          SmartImageErrorType.invalidSource,
          'Could not determine how to load the provided image source.',
          sourceType: source.type,
        );
    }
  }

  Future<LoadedImage> _fromBytes(Uint8List bytes, TransformSpec? transform) async {
    final format = FormatDetector.fromBytes(bytes);
    if (format.isVector) {
      return LoadedImage.vector(
        SvgRenderSource(SvgDelivery.bytes, bytes: bytes),
        format,
      );
    }
    final processed = await _maybeTransform(bytes, transform);
    return LoadedImage.raster(MemoryImage(processed), format);
  }

  Future<LoadedImage> _fromAsset(String path, TransformSpec? transform) async {
    final format = FormatDetector.fromPath(path);
    if (format.isVector) {
      return LoadedImage.vector(
        SvgRenderSource(SvgDelivery.asset, path: path),
        format,
      );
    }
    // When no transform is requested, defer to AssetImage so Flutter handles
    // lazy decode and its own decoded-frame cache.
    if (transform == null || transform.isIdentity) {
      return LoadedImage.raster(AssetImage(path), format);
    }
    final raw = (await rootBundle.load(path)).buffer.asUint8List();
    final processed = await _maybeTransform(raw, transform);
    return LoadedImage.raster(MemoryImage(processed), format);
  }

  Future<LoadedImage> _fromFile(String path, TransformSpec? transform) async {
    final format = FormatDetector.fromPath(path);
    final file = File(path);
    if (!file.existsSync()) {
      throw SmartImageException(
        SmartImageErrorType.notFound,
        'File not found: $path',
        sourceType: ImageSourceType.file,
      );
    }
    if (format.isVector) {
      return LoadedImage.vector(
        SvgRenderSource(SvgDelivery.file, path: path),
        format,
      );
    }
    if (transform == null || transform.isIdentity) {
      return LoadedImage.raster(FileImage(file), format);
    }
    final raw = await file.readAsBytes();
    final processed = await _maybeTransform(raw, transform);
    return LoadedImage.raster(MemoryImage(processed), format);
  }

  Future<LoadedImage> _fromNetwork(
    ResolvedImageSource source, {
    required CachePolicy policy,
    required ImagePriority priority,
    required RetryConfig retryConfig,
    required SmartImageCallbacks callbacks,
    required TransformSpec? transform,
    bool Function()? isCancelled,
  }) async {
    final key = source.cacheKey;

    // 1. Cache read.
    final cached = await _cacheManager.read(
      key,
      policy,
      onHit: callbacks.onCacheHit,
      onMiss: callbacks.onCacheMiss,
    );

    Uint8List bytes;
    String? mimeType;
    if (cached != null) {
      bytes = cached;
    } else {
      // 2. Network fetch with retry + progress.
      final engine = RetryEngine(retryConfig);
      final response = await engine.execute(
        () => _networkService.fetch(
          source.uri!,
          priority: priority,
          onProgress: callbacks.onProgress,
        ),
        onRetry: callbacks.onRetry,
        isCancelled: isCancelled,
      );
      bytes = response.bytes;
      mimeType = response.mimeType;
      // 3. Write back to cache.
      await _cacheManager.write(key, bytes, policy);
    }

    final format = FormatDetector.resolve(
      bytes: bytes,
      mimeType: mimeType,
      path: source.uri!.path,
    );

    if (format.isVector) {
      return LoadedImage.vector(
        SvgRenderSource(SvgDelivery.bytes, bytes: bytes),
        format,
      );
    }

    final processed = await _maybeTransform(bytes, transform);
    return LoadedImage.raster(MemoryImage(processed), format);
  }

  Future<Uint8List> _maybeTransform(Uint8List bytes, TransformSpec? spec) async {
    if (spec == null || spec.isIdentity) return bytes;
    return ImageTransformer.transform(bytes, spec);
  }
}
