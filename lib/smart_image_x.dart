/// SmartImageX — one image widget for everything.
///
/// Import this single library to access the entire public API:
///
/// ```dart
/// import 'package:smart_image_x/smart_image_x.dart';
/// ```
///
/// The headline export is [SmartImage]; everything else (enums, models,
/// configuration, the gallery/viewer widgets and the stand-alone
/// [SmartImageTools] utilities) is re-exported here so applications never need
/// to reach into `src/`.
library smart_image_x;

// Core widget and its render-phase enum.
export 'src/widgets/smart_image.dart' show SmartImage, RenderPhase;

// Auxiliary widgets.
export 'src/widgets/loaders.dart'
    show SmartLoader, CircularLoader, ShimmerLoader, SkeletonLoader;
export 'src/widgets/default_error_widget.dart'
    show DefaultErrorWidget, FallbackIcon;
export 'src/blurhash/blurhash_view.dart' show BlurHashView;
export 'src/blurhash/blurhash_decoder.dart' show BlurHashDecoder;
export 'src/viewer/image_viewer.dart' show SmartImageViewer;
export 'src/viewer/zoomable_image.dart' show ZoomableImage;
export 'src/gallery/smart_image_gallery.dart' show SmartImageGallery;

// Utilities facade.
export 'src/smart_image_tools.dart' show SmartImageTools;

// Engines exposed for advanced/standalone use and testing.
export 'src/source_detector/source_detector.dart' show SourceDetector;
export 'src/format_detector/format_detector.dart' show FormatDetector;
export 'src/cache/cache_manager.dart' show CacheManager;

// Enums.
export 'src/enums/enums.dart';

// Models & configuration.
export 'src/models/models.dart';

// Compression / transform value types.
export 'src/compression/image_compressor.dart'
    show CompressionFormat, CompressionRequest, ImageCompressor;
export 'src/compression/image_transformer.dart'
    show TransformSpec, FlipDirection, Rect, ImageTransformer;

// Callback typedefs.
export 'src/callbacks/image_callbacks.dart';
