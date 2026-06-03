import 'dart:typed_data';

import 'compression/image_compressor.dart';
import 'compression/image_transformer.dart';

/// Stand-alone image processing utilities.
///
/// These wrap the compression and transformation engines behind a flat,
/// discoverable API for one-off byte manipulation outside the widget pipeline
/// (e.g. preparing an upload). Every operation runs in a background isolate.
///
/// ```dart
/// final thumb = await SmartImageTools.resizeImage(bytes, width: 200);
/// final jpeg  = await SmartImageTools.compressImage(bytes, quality: 70);
/// ```
class SmartImageTools {
  const SmartImageTools._();

  /// Compresses [bytes] to [format] at [quality], optionally downscaling to fit
  /// [maxWidth]/[maxHeight].
  static Future<Uint8List> compressImage(
    Uint8List bytes, {
    CompressionFormat format = CompressionFormat.jpg,
    int quality = 85,
    int? maxWidth,
    int? maxHeight,
  }) {
    return ImageCompressor.compress(
      CompressionRequest(
        bytes: bytes,
        format: format,
        quality: quality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
    );
  }

  /// Resizes [bytes]; preserves aspect ratio when only one dimension is given.
  static Future<Uint8List> resizeImage(
    Uint8List bytes, {
    int? width,
    int? height,
    CompressionFormat format = CompressionFormat.png,
    int quality = 90,
  }) {
    return ImageCompressor.resize(
      bytes,
      width: width,
      height: height,
      format: format,
      quality: quality,
    );
  }

  /// Crops [bytes] to the given pixel rectangle.
  static Future<Uint8List> cropImage(
    Uint8List bytes, {
    required int x,
    required int y,
    required int width,
    required int height,
  }) {
    return ImageTransformer.crop(
      bytes,
      x: x,
      y: y,
      width: width,
      height: height,
    );
  }

  /// Re-encodes [bytes] into [format] without resizing.
  static Future<Uint8List> convertFormat(
    Uint8List bytes,
    CompressionFormat format, {
    int quality = 90,
  }) {
    return ImageCompressor.convertFormat(bytes, format, quality: quality);
  }

  /// Rotates [bytes] clockwise by [degrees].
  static Future<Uint8List> rotateImage(Uint8List bytes, num degrees) {
    return ImageTransformer.rotate(bytes, degrees);
  }

  /// Mirrors [bytes] along [direction].
  static Future<Uint8List> flipImage(
    Uint8List bytes, {
    FlipDirection direction = FlipDirection.horizontal,
  }) {
    return ImageTransformer.flip(bytes, direction: direction);
  }

  /// Applies an arbitrary [TransformSpec] (greyscale, blur, colour adjust…).
  static Future<Uint8List> transform(Uint8List bytes, TransformSpec spec) {
    return ImageTransformer.transform(bytes, spec);
  }
}
