/// Concrete image encodings SmartImageX can recognise and render.
///
/// Formats are resolved automatically by the format-detection engine from
/// magic bytes and, as a fallback, file extension or MIME hints — developers
/// never specify a format by hand.
enum ImageFormat {
  /// Portable Network Graphics.
  png,

  /// JPEG / JFIF (covers `.jpg` and `.jpeg`).
  jpeg,

  /// WebP (lossy or lossless).
  webp,

  /// Graphics Interchange Format (animated or static).
  gif,

  /// Scalable Vector Graphics (XML, rendered via the vector renderer).
  svg,

  /// AV1 Image File Format. Recognised for forward-compatibility; rendering
  /// depends on the host platform's codec support.
  avif,

  /// Bitmap.
  bmp,

  /// The format could not be determined.
  unknown;

  /// Whether this is a raster (pixel) format handled by the bitmap renderer.
  bool get isRaster => this != ImageFormat.svg && this != ImageFormat.unknown;

  /// Whether this is a vector format handled by the SVG renderer.
  bool get isVector => this == ImageFormat.svg;

  /// Whether the format can contain multiple animation frames.
  bool get isAnimated => this == ImageFormat.gif || this == ImageFormat.webp;

  /// The canonical lowercase file extension (without a leading dot).
  String get extension => switch (this) {
        ImageFormat.png => 'png',
        ImageFormat.jpeg => 'jpg',
        ImageFormat.webp => 'webp',
        ImageFormat.gif => 'gif',
        ImageFormat.svg => 'svg',
        ImageFormat.avif => 'avif',
        ImageFormat.bmp => 'bmp',
        ImageFormat.unknown => 'bin',
      };

  /// The canonical MIME type for the format.
  String get mimeType => switch (this) {
        ImageFormat.png => 'image/png',
        ImageFormat.jpeg => 'image/jpeg',
        ImageFormat.webp => 'image/webp',
        ImageFormat.gif => 'image/gif',
        ImageFormat.svg => 'image/svg+xml',
        ImageFormat.avif => 'image/avif',
        ImageFormat.bmp => 'image/bmp',
        ImageFormat.unknown => 'application/octet-stream',
      };
}
