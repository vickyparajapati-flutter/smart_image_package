import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/smart_image_exception.dart';
import 'image_compressor.dart';

/// Axis for [ImageTransformer.flip].
enum FlipDirection { horizontal, vertical, both }

/// A bundle of colour/geometry adjustments applied in a single isolate pass.
///
/// Used both by the standalone utility methods and by `SmartImage`'s inline
/// `grayscale`/`blur`/`brightness`/… props so a widget can request several
/// effects without repeatedly decoding the source.
@immutable
class TransformSpec {
  /// Creates a transform specification. Unset fields are no-ops.
  const TransformSpec({
    this.grayscale = false,
    this.blurRadius,
    this.brightness,
    this.contrast,
    this.saturation,
    this.rotateDegrees,
    this.flip,
    this.crop,
    this.outputFormat = CompressionFormat.png,
    this.quality = 90,
  });

  /// Convert to greyscale.
  final bool grayscale;

  /// Gaussian blur radius in pixels (`null` = no blur).
  final int? blurRadius;

  /// Brightness adjustment; `1.0` is unchanged.
  final double? brightness;

  /// Contrast adjustment; `100` is unchanged in the underlying codec.
  final double? contrast;

  /// Saturation adjustment; `1.0` is unchanged.
  final double? saturation;

  /// Clockwise rotation in degrees.
  final num? rotateDegrees;

  /// Mirror axis.
  final FlipDirection? flip;

  /// Crop rectangle in pixels.
  final Rect? crop;

  /// Output encoding.
  final CompressionFormat outputFormat;

  /// Output quality for lossy encodings.
  final int quality;

  /// Whether any effect is actually requested.
  bool get isIdentity =>
      !grayscale &&
      blurRadius == null &&
      brightness == null &&
      contrast == null &&
      saturation == null &&
      rotateDegrees == null &&
      flip == null &&
      crop == null;
}

/// An integer pixel rectangle for cropping.
@immutable
class Rect {
  /// Creates a crop rectangle.
  const Rect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Left offset in pixels.
  final int x;

  /// Top offset in pixels.
  final int y;

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;
}

/// CPU-bound pixel transformations, offloaded to a background isolate.
class ImageTransformer {
  const ImageTransformer._();

  /// Applies an arbitrary [spec] to [bytes].
  static Future<Uint8List> transform(Uint8List bytes, TransformSpec spec) {
    if (spec.isIdentity) return Future.value(bytes);
    return compute(_transformIsolate, _Req(bytes, spec));
  }

  /// Converts [bytes] to greyscale.
  static Future<Uint8List> grayscale(Uint8List bytes) =>
      transform(bytes, const TransformSpec(grayscale: true));

  /// Gaussian-blurs [bytes] by [radius] pixels.
  static Future<Uint8List> blur(Uint8List bytes, {int radius = 10}) =>
      transform(bytes, TransformSpec(blurRadius: radius));

  /// Crops [bytes] to the given pixel rectangle.
  static Future<Uint8List> crop(
    Uint8List bytes, {
    required int x,
    required int y,
    required int width,
    required int height,
  }) =>
      transform(
        bytes,
        TransformSpec(crop: Rect(x: x, y: y, width: width, height: height)),
      );

  /// Rotates [bytes] clockwise by [degrees].
  static Future<Uint8List> rotate(Uint8List bytes, num degrees) =>
      transform(bytes, TransformSpec(rotateDegrees: degrees));

  /// Mirrors [bytes] along [direction].
  static Future<Uint8List> flip(
    Uint8List bytes, {
    FlipDirection direction = FlipDirection.horizontal,
  }) =>
      transform(bytes, TransformSpec(flip: direction));

  static Uint8List _transformIsolate(_Req req) {
    var image = img.decodeImage(req.bytes);
    if (image == null) {
      throw const SmartImageException(
        SmartImageErrorType.decode,
        'Could not decode source image for transformation.',
      );
    }
    final spec = req.spec;

    if (spec.crop != null) {
      final c = spec.crop!;
      image = img.copyCrop(
        image,
        x: c.x,
        y: c.y,
        width: c.width,
        height: c.height,
      );
    }
    if (spec.rotateDegrees != null) {
      image = img.copyRotate(image, angle: spec.rotateDegrees!);
    }
    if (spec.flip != null) {
      image = switch (spec.flip!) {
        FlipDirection.horizontal => img.flipHorizontal(image),
        FlipDirection.vertical => img.flipVertical(image),
        FlipDirection.both => img.flipHorizontalVertical(image),
      };
    }
    if (spec.grayscale) {
      image = img.grayscale(image);
    }
    if (spec.brightness != null ||
        spec.contrast != null ||
        spec.saturation != null) {
      image = img.adjustColor(
        image,
        brightness: spec.brightness,
        contrast: spec.contrast,
        saturation: spec.saturation,
      );
    }
    if (spec.blurRadius != null && spec.blurRadius! > 0) {
      image = img.gaussianBlur(image, radius: spec.blurRadius!);
    }

    return switch (spec.outputFormat) {
      CompressionFormat.jpg => img.encodeJpg(image, quality: spec.quality),
      CompressionFormat.png => img.encodePng(image),
      CompressionFormat.gif => img.encodeGif(image),
      CompressionFormat.bmp => img.encodeBmp(image),
      CompressionFormat.webp => throw const SmartImageException(
          SmartImageErrorType.decode,
          'WebP encoding is not supported; use jpg or png.',
        ),
    };
  }
}

@immutable
class _Req {
  const _Req(this.bytes, this.spec);
  final Uint8List bytes;
  final TransformSpec spec;
}
