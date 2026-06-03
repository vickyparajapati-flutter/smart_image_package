/// The kind of origin an image value resolves to.
///
/// Determined automatically by the source-detection engine from the runtime
/// type and shape of the value passed to `SmartImage(image: ...)`.
enum ImageSourceType {
  /// An `http`/`https` URL pointing at a remote resource.
  network,

  /// A bundled asset path (resolved through the asset bundle).
  asset,

  /// An absolute or relative path to a file on the local filesystem.
  file,

  /// In-memory image bytes (`Uint8List` / `List<int>`).
  memory,

  /// A base64-encoded byte string, optionally with a `data:` URI prefix.
  base64,

  /// Raw inline SVG XML markup.
  svgString,

  /// The value could not be classified.
  unknown;

  /// Whether resolving this source requires network access.
  bool get isRemote => this == ImageSourceType.network;

  /// Whether the bytes for this source are already available locally without
  /// I/O (memory, base64, inline SVG).
  bool get isInline =>
      this == ImageSourceType.memory ||
      this == ImageSourceType.base64 ||
      this == ImageSourceType.svgString;
}
