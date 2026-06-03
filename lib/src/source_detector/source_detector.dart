import 'dart:convert';
import 'dart:typed_data';

import '../models/image_source.dart';
import '../utils/logger.dart';

/// Classifies the loosely-typed `image` value passed to `SmartImage` into a
/// strongly-typed [ResolvedImageSource].
///
/// This is the entry point of the pipeline and the realisation of the
/// "no manual source selection" principle. Detection is heuristic but ordered
/// from most-specific to least-specific so that, for example, a `data:` URI is
/// recognised as base64 before the generic URL branch sees it.
///
/// The classifier is intentionally pure and synchronous: it performs no I/O,
/// only inspecting the runtime type and textual shape of the value.
class SourceDetector {
  const SourceDetector._();

  /// Recognised raster/vector file extensions, used to disambiguate ambiguous
  /// strings that are neither obviously URLs nor obviously asset paths.
  static const Set<String> _imageExtensions = {
    'png', 'jpg', 'jpeg', 'webp', 'gif', 'svg', 'avif', 'bmp', 'heic', 'heif',
  };

  /// The minimum length below which a string is too short to plausibly be a
  /// base64-encoded image, avoiding misclassification of short identifiers.
  static const int _minBase64Length = 32;

  /// Resolves [value] into a [ResolvedImageSource].
  ///
  /// Supports `String` (URL / asset path / file path / base64 / SVG markup),
  /// `Uri`, `Uint8List`, `List<int>`, and an already-[ResolvedImageSource]
  /// (returned as-is). Anything else resolves to
  /// [ResolvedImageSource.unknown].
  static ResolvedImageSource detect(Object? value) {
    if (value == null) {
      return ResolvedImageSource.unknown(value);
    }

    // Already resolved — pass through (lets callers pre-resolve).
    if (value is ResolvedImageSource) return value;

    // Raw bytes.
    if (value is Uint8List) {
      return ResolvedImageSource.memory(value);
    }
    if (value is List<int>) {
      return ResolvedImageSource.memory(Uint8List.fromList(value));
    }

    // A pre-parsed URI.
    if (value is Uri) {
      return _fromUri(value);
    }

    if (value is String) {
      return _fromString(value);
    }

    SmartLogger.warning('Unrecognised image source type: ${value.runtimeType}');
    return ResolvedImageSource.unknown(value);
  }

  static ResolvedImageSource _fromUri(Uri uri) {
    if (uri.scheme == 'data') {
      final bytes = _decodeDataUri(uri.toString());
      if (bytes != null) {
        return ResolvedImageSource.base64(uri.toString(), bytes);
      }
    }
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return ResolvedImageSource.network(uri.toString());
    }
    if (uri.scheme == 'file') {
      return ResolvedImageSource.file(uri.toFilePath());
    }
    return _fromString(uri.toString());
  }

  static ResolvedImageSource _fromString(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return ResolvedImageSource.unknown(value);

    // 1. Inline SVG markup.
    if (_looksLikeSvg(trimmed)) {
      return ResolvedImageSource.svgString(trimmed);
    }

    // 2. data: URI (covers base64 and percent-encoded payloads).
    if (trimmed.startsWith('data:')) {
      final bytes = _decodeDataUri(trimmed);
      if (bytes != null) return ResolvedImageSource.base64(trimmed, bytes);
    }

    // 3. Network URL.
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return ResolvedImageSource.network(trimmed);
    }

    // 4. Explicit file URI / absolute path.
    if (trimmed.startsWith('file://')) {
      return ResolvedImageSource.file(Uri.parse(trimmed).toFilePath());
    }

    // 5. Asset paths conventionally live under assets/ or packages/.
    if (_looksLikeAssetPath(trimmed)) {
      return ResolvedImageSource.asset(trimmed);
    }

    // 6. Filesystem path (absolute, home-relative, or has a path separator and
    //    a known image extension).
    if (_looksLikeFilePath(trimmed)) {
      return ResolvedImageSource.file(trimmed);
    }

    // 7. Bare base64 (no data: prefix) — checked late because it is the most
    //    permissive shape.
    if (_looksLikeBase64(trimmed)) {
      final bytes = _tryDecodeBase64(trimmed);
      if (bytes != null) return ResolvedImageSource.base64(trimmed, bytes);
    }

    // 8. Fall back to treating a relative path with an image extension as an
    //    asset (the most common case for `assets/foo.png`-style values).
    if (_hasImageExtension(trimmed)) {
      return ResolvedImageSource.asset(trimmed);
    }

    SmartLogger.warning('Could not classify image source string: '
        '"${trimmed.length > 48 ? '${trimmed.substring(0, 48)}…' : trimmed}"');
    return ResolvedImageSource.unknown(value);
  }

  static bool _looksLikeSvg(String value) {
    final lower = value.trimLeft().toLowerCase();
    return lower.startsWith('<svg') ||
        (lower.startsWith('<?xml') && lower.contains('<svg'));
  }

  static bool _looksLikeAssetPath(String value) {
    return value.startsWith('assets/') ||
        value.startsWith('asset/') ||
        value.startsWith('packages/') ||
        value.startsWith('lib/assets/');
  }

  static bool _looksLikeFilePath(String value) {
    if (value.startsWith('/') ||
        value.startsWith('~/') ||
        value.startsWith('./') ||
        value.startsWith('../')) {
      return true;
    }
    // Windows drive path e.g. C:\images\a.png
    if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value)) return true;
    // A path separator plus a known image extension.
    if ((value.contains('/') || value.contains(r'\')) &&
        _hasImageExtension(value)) {
      return true;
    }
    return false;
  }

  static bool _hasImageExtension(String value) {
    final withoutQuery = value.split('?').first.split('#').first;
    final dot = withoutQuery.lastIndexOf('.');
    if (dot < 0 || dot == withoutQuery.length - 1) return false;
    final ext = withoutQuery.substring(dot + 1).toLowerCase();
    return _imageExtensions.contains(ext);
  }

  static bool _looksLikeBase64(String value) {
    if (value.length < _minBase64Length) return false;
    // Base64 alphabet (standard + url-safe) with optional padding. Reject
    // anything containing characters outside it (e.g. spaces, path slashes are
    // valid base64 chars, so we also require no obvious extension).
    if (_hasImageExtension(value)) return false;
    return RegExp(r'^[A-Za-z0-9+/_-]+={0,2}$').hasMatch(value) &&
        value.length % 4 == 0;
  }

  static Uint8List? _tryDecodeBase64(String value) {
    try {
      // Normalise url-safe alphabet before decoding.
      final normalised = base64.normalize(value.replaceAll('-', '+').replaceAll('_', '/'));
      return base64.decode(normalised);
    } catch (_) {
      return null;
    }
  }

  /// Decodes a `data:[<mime>][;base64],<payload>` URI to its bytes, or `null`
  /// if it is malformed.
  static Uint8List? _decodeDataUri(String value) {
    try {
      final data = UriData.parse(value);
      return data.contentAsBytes();
    } catch (_) {
      return null;
    }
  }
}
