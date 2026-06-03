import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../enums/image_format.dart';
import '../models/smart_image_exception.dart';

/// Output encodings supported by the compressor.
///
/// Encoding is performed in pure Dart. JPEG and PNG are fully supported; GIF
/// and BMP are available for completeness. WebP **encoding** is not available
/// in the pure-Dart codec (decoding is), so [CompressionFormat.webp] throws a
/// descriptive [UnsupportedError] — convert to JPEG/PNG instead. This is a
/// deliberate, documented limitation rather than a silent format swap.
enum CompressionFormat { jpg, png, gif, bmp, webp }

/// Parameters for a compression request (a single object so the work can run in
/// a background isolate via [compute]).
@immutable
class CompressionRequest {
  /// Creates a compression request.
  const CompressionRequest({
    required this.bytes,
    this.format = CompressionFormat.jpg,
    this.quality = 85,
    this.maxWidth,
    this.maxHeight,
  });

  /// Source image bytes.
  final Uint8List bytes;

  /// Desired output encoding.
  final CompressionFormat format;

  /// JPEG quality `0..100` (ignored for lossless formats).
  final int quality;

  /// Optional max width; the image is scaled down to fit, preserving aspect.
  final int? maxWidth;

  /// Optional max height.
  final int? maxHeight;
}

/// CPU-bound image compression and re-encoding, offloaded to a background
/// isolate so it never janks the UI thread.
///
/// All entry points decode the source with the pure-Dart [img] codec, apply
/// the requested transform, and re-encode. Heavy work is wrapped in [compute].
class ImageCompressor {
  const ImageCompressor._();

  /// Compresses [bytes] to [format] at [quality], optionally downscaling to fit
  /// [maxWidth]/[maxHeight].
  static Future<Uint8List> compress(CompressionRequest request) {
    return compute(_compressIsolate, request);
  }

  /// Resizes [bytes] to the given dimensions, preserving aspect ratio when only
  /// one of [width]/[height] is supplied, and re-encodes to [format].
  static Future<Uint8List> resize(
    Uint8List bytes, {
    int? width,
    int? height,
    CompressionFormat format = CompressionFormat.png,
    int quality = 90,
  }) {
    return compute(
      _resizeIsolate,
      _ResizeRequest(bytes, width, height, format, quality),
    );
  }

  /// Re-encodes [bytes] from its current format into [format] without resizing.
  static Future<Uint8List> convertFormat(
    Uint8List bytes,
    CompressionFormat format, {
    int quality = 90,
  }) {
    return compute(
      _compressIsolate,
      CompressionRequest(bytes: bytes, format: format, quality: quality),
    );
  }

  // --- Isolate entry points (top-level pure functions) ---------------------

  static Uint8List _compressIsolate(CompressionRequest request) {
    final decoded = _decodeOrThrow(request.bytes);
    final resized = _maybeResize(decoded, request.maxWidth, request.maxHeight);
    return _encode(resized, request.format, request.quality);
  }

  static Uint8List _resizeIsolate(_ResizeRequest request) {
    final decoded = _decodeOrThrow(request.bytes);
    final resized = img.copyResize(
      decoded,
      width: request.width,
      height: request.height,
      maintainAspect: request.width == null || request.height == null,
      interpolation: img.Interpolation.average,
    );
    return _encode(resized, request.format, request.quality);
  }

  static img.Image _decodeOrThrow(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const SmartImageException(
        SmartImageErrorType.decode,
        'Could not decode source image for processing.',
      );
    }
    return decoded;
  }

  static img.Image _maybeResize(img.Image image, int? maxWidth, int? maxHeight) {
    if (maxWidth == null && maxHeight == null) return image;
    final overWidth = maxWidth != null && image.width > maxWidth;
    final overHeight = maxHeight != null && image.height > maxHeight;
    if (!overWidth && !overHeight) return image;
    return img.copyResize(
      image,
      width: overWidth ? maxWidth : null,
      height: overHeight && !overWidth ? maxHeight : null,
      maintainAspect: true,
      interpolation: img.Interpolation.average,
    );
  }

  static Uint8List _encode(img.Image image, CompressionFormat format, int quality) {
    switch (format) {
      case CompressionFormat.jpg:
        return img.encodeJpg(image, quality: quality.clamp(0, 100));
      case CompressionFormat.png:
        return img.encodePng(image);
      case CompressionFormat.gif:
        return img.encodeGif(image);
      case CompressionFormat.bmp:
        return img.encodeBmp(image);
      case CompressionFormat.webp:
        throw const SmartImageException(
          SmartImageErrorType.decode,
          'WebP encoding is not supported by the pure-Dart codec. '
          'Use CompressionFormat.jpg or .png instead (WebP decoding works).',
        );
    }
  }

  /// Maps a detected [ImageFormat] to a re-encodable [CompressionFormat], or
  /// `null` when the format cannot be encoded (e.g. SVG, AVIF, WebP).
  static CompressionFormat? encodableFor(ImageFormat format) => switch (format) {
        ImageFormat.jpeg => CompressionFormat.jpg,
        ImageFormat.png => CompressionFormat.png,
        ImageFormat.gif => CompressionFormat.gif,
        ImageFormat.bmp => CompressionFormat.bmp,
        ImageFormat.webp ||
        ImageFormat.svg ||
        ImageFormat.avif ||
        ImageFormat.unknown =>
          null,
      };
}

@immutable
class _ResizeRequest {
  const _ResizeRequest(
    this.bytes,
    this.width,
    this.height,
    this.format,
    this.quality,
  );

  final Uint8List bytes;
  final int? width;
  final int? height;
  final CompressionFormat format;
  final int quality;
}
