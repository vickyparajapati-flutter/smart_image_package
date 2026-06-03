import '../enums/image_format.dart';

/// Decoded structural information about an image payload.
///
/// Returned by `SmartImage.getMetadata()`. Fields that cannot be determined
/// for a given format (e.g. EXIF [createdAt] on a PNG) are left `null`.
class ImageMetadata {
  /// Creates an immutable metadata record.
  const ImageMetadata({
    required this.width,
    required this.height,
    required this.sizeInBytes,
    required this.format,
    this.orientation,
    this.createdAt,
    this.isAnimated = false,
    this.frameCount = 1,
    this.hasAlpha = false,
  });

  /// Intrinsic pixel width.
  final int width;

  /// Intrinsic pixel height.
  final int height;

  /// Encoded payload size in bytes.
  final int sizeInBytes;

  /// Detected encoding.
  final ImageFormat format;

  /// EXIF orientation (1–8) when present.
  final int? orientation;

  /// EXIF/creation timestamp when present.
  final DateTime? createdAt;

  /// Whether the image contains more than one animation frame.
  final bool isAnimated;

  /// Number of animation frames (1 for still images).
  final int frameCount;

  /// Whether the image carries an alpha channel.
  final bool hasAlpha;

  /// Aspect ratio (`width / height`); `0` if [height] is `0`.
  double get aspectRatio => height == 0 ? 0 : width / height;

  /// Payload size in kibibytes.
  double get sizeInKb => sizeInBytes / 1024;

  /// Payload size in mebibytes.
  double get sizeInMb => sizeInBytes / (1024 * 1024);

  /// Total pixel count.
  int get pixelCount => width * height;

  /// A JSON-serialisable view.
  Map<String, Object?> toMap() => {
        'width': width,
        'height': height,
        'sizeInBytes': sizeInBytes,
        'format': format.name,
        'orientation': orientation,
        'createdAt': createdAt?.toIso8601String(),
        'isAnimated': isAnimated,
        'frameCount': frameCount,
        'hasAlpha': hasAlpha,
      };

  @override
  String toString() =>
      'ImageMetadata(${width}x$height, ${format.name}, '
      '${sizeInKb.toStringAsFixed(1)}KB)';
}
