import 'dart:typed_data';

import '../enums/image_format.dart';

/// Determines the [ImageFormat] of an image payload.
///
/// Detection is primarily by *magic bytes* (the file signature), which is
/// authoritative regardless of file extension or server-declared MIME type.
/// Extension and MIME hints are used only as a fallback when bytes are
/// unavailable (e.g. before a download starts) or inconclusive.
class FormatDetector {
  const FormatDetector._();

  /// The number of leading bytes required to identify every supported format.
  static const int sniffLength = 32;

  /// Detects the format from the leading [bytes] of a payload.
  ///
  /// Returns [ImageFormat.unknown] when no signature matches.
  static ImageFormat fromBytes(Uint8List bytes) {
    if (bytes.length < 4) return ImageFormat.unknown;

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (_matches(bytes, const [0x89, 0x50, 0x4E, 0x47])) {
      return ImageFormat.png;
    }

    // JPEG: FF D8 FF
    if (_matches(bytes, const [0xFF, 0xD8, 0xFF])) {
      return ImageFormat.jpeg;
    }

    // GIF: "GIF87a" / "GIF89a"
    if (_matches(bytes, const [0x47, 0x49, 0x46, 0x38])) {
      return ImageFormat.gif;
    }

    // BMP: "BM"
    if (_matches(bytes, const [0x42, 0x4D])) {
      return ImageFormat.bmp;
    }

    // RIFF container — distinguish WEBP via the "WEBP" fourCC at offset 8.
    if (_matches(bytes, const [0x52, 0x49, 0x46, 0x46]) &&
        bytes.length >= 12 &&
        _matchesAt(bytes, 8, const [0x57, 0x45, 0x42, 0x50])) {
      return ImageFormat.webp;
    }

    // ISO-BMFF container ("ftyp" at offset 4) — AVIF/HEIC family. Inspect the
    // major brand at offset 8.
    if (bytes.length >= 12 && _matchesAt(bytes, 4, const [0x66, 0x74, 0x79, 0x70])) {
      final brand = String.fromCharCodes(bytes.sublist(8, 12));
      if (brand == 'avif' || brand == 'avis') return ImageFormat.avif;
    }

    // SVG: textual XML. Scan a small window for the "<svg" token.
    if (_looksLikeSvgBytes(bytes)) return ImageFormat.svg;

    return ImageFormat.unknown;
  }

  /// Best-effort detection from a file path or URL extension.
  static ImageFormat fromPath(String path) {
    final clean = path.split('?').first.split('#').first;
    final dot = clean.lastIndexOf('.');
    if (dot < 0) return ImageFormat.unknown;
    return fromExtension(clean.substring(dot + 1));
  }

  /// Maps a bare extension (with or without a leading dot) to a format.
  static ImageFormat fromExtension(String extension) {
    switch (extension.toLowerCase().replaceFirst('.', '')) {
      case 'png':
        return ImageFormat.png;
      case 'jpg':
      case 'jpeg':
      case 'jfif':
        return ImageFormat.jpeg;
      case 'webp':
        return ImageFormat.webp;
      case 'gif':
        return ImageFormat.gif;
      case 'svg':
      case 'svgz':
        return ImageFormat.svg;
      case 'avif':
        return ImageFormat.avif;
      case 'bmp':
        return ImageFormat.bmp;
      default:
        return ImageFormat.unknown;
    }
  }

  /// Maps a MIME type (e.g. a `Content-Type` header) to a format.
  static ImageFormat fromMimeType(String mimeType) {
    final type = mimeType.split(';').first.trim().toLowerCase();
    switch (type) {
      case 'image/png':
        return ImageFormat.png;
      case 'image/jpeg':
      case 'image/jpg':
        return ImageFormat.jpeg;
      case 'image/webp':
        return ImageFormat.webp;
      case 'image/gif':
        return ImageFormat.gif;
      case 'image/svg+xml':
        return ImageFormat.svg;
      case 'image/avif':
        return ImageFormat.avif;
      case 'image/bmp':
      case 'image/x-ms-bmp':
        return ImageFormat.bmp;
      default:
        return ImageFormat.unknown;
    }
  }

  /// Resolves the format using the strongest available signal: magic bytes
  /// first, then MIME, then path/extension.
  static ImageFormat resolve({
    Uint8List? bytes,
    String? mimeType,
    String? path,
  }) {
    if (bytes != null) {
      final byFormat = fromBytes(bytes);
      if (byFormat != ImageFormat.unknown) return byFormat;
    }
    if (mimeType != null) {
      final byMime = fromMimeType(mimeType);
      if (byMime != ImageFormat.unknown) return byMime;
    }
    if (path != null) {
      final byPath = fromPath(path);
      if (byPath != ImageFormat.unknown) return byPath;
    }
    return ImageFormat.unknown;
  }

  static bool _matches(Uint8List bytes, List<int> signature) =>
      _matchesAt(bytes, 0, signature);

  static bool _matchesAt(Uint8List bytes, int offset, List<int> signature) {
    if (bytes.length < offset + signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[offset + i] != signature[i]) return false;
    }
    return true;
  }

  static bool _looksLikeSvgBytes(Uint8List bytes) {
    final window = bytes.length < 256 ? bytes.length : 256;
    // Cheap ASCII scan for "<svg" (case-insensitive) within the window.
    for (var i = 0; i < window - 3; i++) {
      final c0 = bytes[i];
      if (c0 == 0x3C /* < */) {
        final c1 = bytes[i + 1] | 0x20;
        final c2 = bytes[i + 2] | 0x20;
        final c3 = bytes[i + 3] | 0x20;
        if (c1 == 0x73 /* s */ && c2 == 0x76 /* v */ && c3 == 0x67 /* g */) {
          return true;
        }
      }
    }
    return false;
  }
}
