import 'package:flutter/material.dart';

import '../widgets/smart_image.dart';
import 'zoomable_image.dart';

/// A full-screen, zoomable, dismissible viewer for a single image.
///
/// Opened automatically by `SmartImage(openViewerOnTap: true)` or manually via
/// [SmartImageViewer.open]. Reuses [SmartImage] internally so the viewer
/// benefits from the same cache, retry and format handling as the thumbnail.
class SmartImageViewer extends StatelessWidget {
  /// Creates a full-screen viewer for [image].
  const SmartImageViewer({
    required this.image,
    this.heroTag,
    this.backgroundColor = Colors.black,
    this.maxScale = 5.0,
    super.key,
  });

  /// The image source (any type accepted by [SmartImage]).
  final Object image;

  /// Optional hero tag for a shared-element transition from the thumbnail.
  final Object? heroTag;

  /// Backdrop colour.
  final Color backgroundColor;

  /// Maximum zoom factor.
  final double maxScale;

  /// Pushes a viewer route for [image] onto the navigator.
  static Future<void> open(
    BuildContext context, {
    required Object image,
    Object? heroTag,
    Color backgroundColor = Colors.black,
    double maxScale = 5.0,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: backgroundColor,
        pageBuilder: (_, __, ___) => SmartImageViewer(
          image: image,
          heroTag: heroTag,
          backgroundColor: backgroundColor,
          maxScale: maxScale,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = ZoomableImage(
      maxScale: maxScale,
      child: SmartImage(
        image: image,
        fit: BoxFit.contain,
        // Avoid recursive viewers / zoom inside the viewer's own gesture layer.
        enableZoom: false,
      ),
    );

    if (heroTag != null) {
      content = Hero(tag: heroTag!, child: content);
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: content,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: Material(
              color: Colors.black26,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
