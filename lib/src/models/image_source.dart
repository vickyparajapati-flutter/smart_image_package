import 'dart:convert';
import 'dart:typed_data';

import '../enums/image_source_type.dart';

/// An immutable, fully-classified description of an image origin.
///
/// Produced by the source-detection engine. It normalises the loosely-typed
/// `Object` passed to `SmartImage(image: ...)` into a strongly-typed value the
/// rest of the pipeline can reason about without re-sniffing.
class ResolvedImageSource {
  /// Creates a resolved source. Prefer the named factory constructors which
  /// guarantee the right fields are populated for each [type].
  const ResolvedImageSource({
    required this.type,
    required this.raw,
    this.uri,
    this.path,
    this.bytes,
    this.svgMarkup,
  });

  /// A remote `http`/`https` source.
  factory ResolvedImageSource.network(String url) => ResolvedImageSource(
        type: ImageSourceType.network,
        raw: url,
        uri: Uri.parse(url),
      );

  /// A bundled asset source.
  factory ResolvedImageSource.asset(String assetPath) => ResolvedImageSource(
        type: ImageSourceType.asset,
        raw: assetPath,
        path: assetPath,
      );

  /// A local filesystem source.
  factory ResolvedImageSource.file(String filePath) => ResolvedImageSource(
        type: ImageSourceType.file,
        raw: filePath,
        path: filePath,
      );

  /// An in-memory byte source.
  factory ResolvedImageSource.memory(Uint8List bytes) => ResolvedImageSource(
        type: ImageSourceType.memory,
        raw: bytes,
        bytes: bytes,
      );

  /// A base64 source. [decoded] is the already-decoded payload.
  factory ResolvedImageSource.base64(String value, Uint8List decoded) =>
      ResolvedImageSource(
        type: ImageSourceType.base64,
        raw: value,
        bytes: decoded,
      );

  /// An inline SVG markup source.
  factory ResolvedImageSource.svgString(String markup) => ResolvedImageSource(
        type: ImageSourceType.svgString,
        raw: markup,
        svgMarkup: markup,
        bytes: Uint8List.fromList(utf8.encode(markup)),
      );

  /// An unclassifiable source. Always renders as an error.
  factory ResolvedImageSource.unknown(Object? value) => ResolvedImageSource(
        type: ImageSourceType.unknown,
        raw: value,
      );

  /// The detected origin kind.
  final ImageSourceType type;

  /// The original, unmodified value supplied by the developer.
  final Object? raw;

  /// Parsed URI for [ImageSourceType.network] sources.
  final Uri? uri;

  /// Filesystem or asset path for [ImageSourceType.file] / [ImageSourceType.asset].
  final String? path;

  /// Decoded bytes for inline sources ([ImageSourceType.memory],
  /// [ImageSourceType.base64], [ImageSourceType.svgString]).
  final Uint8List? bytes;

  /// Raw SVG markup for [ImageSourceType.svgString].
  final String? svgMarkup;

  /// A stable identity for caching and de-duplication.
  ///
  /// Remote/asset/file sources key off their location. Inline byte sources
  /// fold their length into the key so distinct payloads don't collide while
  /// identical ones share an entry. The actual content hash is computed lazily
  /// by the cache layer; this is only the human-readable seed.
  String get cacheKey => switch (type) {
        ImageSourceType.network => uri!.toString(),
        ImageSourceType.asset => 'asset:$path',
        ImageSourceType.file => 'file:$path',
        ImageSourceType.memory => 'memory:${bytes?.length ?? 0}',
        ImageSourceType.base64 => 'base64:${bytes?.length ?? 0}',
        ImageSourceType.svgString => 'svg:${svgMarkup?.length ?? 0}',
        ImageSourceType.unknown => 'unknown',
      };

  /// Whether this source needs a network round-trip to obtain its bytes.
  bool get requiresNetwork => type.isRemote;

  /// Whether the bytes are already in hand.
  bool get hasInlineBytes => bytes != null;

  @override
  String toString() => 'ResolvedImageSource($type, key: $cacheKey)';
}
