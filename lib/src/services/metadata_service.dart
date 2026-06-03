import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../format_detector/format_detector.dart';
import '../models/image_metadata.dart';

/// Extracts structural [ImageMetadata] (dimensions, format, EXIF) from image
/// bytes.
///
/// Decoding the header is comparatively cheap but still CPU work, so it runs in
/// a background isolate via [compute]. SVG payloads are handled separately
/// (vector dimensions come from the document's `viewBox`/`width`/`height`).
class MetadataService {
  const MetadataService._();

  /// Reads metadata from [bytes]. Returns `null` if the payload cannot be
  /// decoded by the raster codec.
  static Future<ImageMetadata?> fromBytes(Uint8List bytes) {
    return compute(_extractIsolate, bytes);
  }

  static ImageMetadata? _extractIsolate(Uint8List bytes) {
    final format = FormatDetector.fromBytes(bytes);

    final decoder = img.findDecoderForData(bytes);
    if (decoder == null) {
      // Could be SVG or an unsupported raster format; we can still report size.
      return ImageMetadata(
        width: 0,
        height: 0,
        sizeInBytes: bytes.length,
        format: format,
      );
    }

    final image = decoder.decode(bytes);
    if (image == null) return null;

    final exif = image.exif;
    final orientation = exif.imageIfd.hasOrientation
        ? exif.imageIfd.orientation
        : null;

    return ImageMetadata(
      width: image.width,
      height: image.height,
      sizeInBytes: bytes.length,
      format: format,
      orientation: orientation,
      isAnimated: image.numFrames > 1,
      frameCount: image.numFrames,
      hasAlpha: image.hasAlpha,
      createdAt: _readDateTime(exif),
    );
  }

  static DateTime? _readDateTime(img.ExifData exif) {
    try {
      final value = exif.imageIfd['DateTime']?.toString();
      if (value == null || value.isEmpty) return null;
      // EXIF format: "YYYY:MM:DD HH:MM:SS".
      final normalised = value.replaceFirst(':', '-').replaceFirst(':', '-');
      return DateTime.tryParse(normalised);
    } catch (_) {
      return null;
    }
  }
}
