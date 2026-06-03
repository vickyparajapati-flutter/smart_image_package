import 'package:flutter/material.dart';

import '../widgets/smart_image.dart';
import '../viewer/zoomable_image.dart';

/// A swipeable, zoomable, full-screen gallery over a list of images.
///
/// Each page is independently zoomable (pinch / double-tap / pan) and, when a
/// matching [heroTagBuilder] is supplied, animates with a shared-element
/// transition. Every page is a [SmartImage], so all images flow through the
/// same cache/retry/format pipeline.
///
/// ```dart
/// SmartImageGallery(
///   images: photoUrls,
///   initialIndex: tappedIndex,
/// )
/// ```
class SmartImageGallery extends StatefulWidget {
  /// Creates a gallery over [images] (any source type [SmartImage] accepts).
  const SmartImageGallery({
    required this.images,
    this.initialIndex = 0,
    this.backgroundColor = Colors.black,
    this.maxScale = 5.0,
    this.showIndicator = true,
    this.heroTagBuilder,
    this.onPageChanged,
    super.key,
  })  : assert(initialIndex >= 0, 'initialIndex must be non-negative');

  /// The images to display, in order.
  final List<Object> images;

  /// The page shown first.
  final int initialIndex;

  /// Backdrop colour.
  final Color backgroundColor;

  /// Maximum zoom factor per page.
  final double maxScale;

  /// Whether to show the "n / total" page indicator.
  final bool showIndicator;

  /// Optional hero-tag builder for shared-element transitions.
  final Object Function(int index)? heroTagBuilder;

  /// Invoked when the visible page changes.
  final ValueChanged<int>? onPageChanged;

  /// Opens the gallery as a full-screen route.
  static Future<void> open(
    BuildContext context, {
    required List<Object> images,
    int initialIndex = 0,
    Color backgroundColor = Colors.black,
    double maxScale = 5.0,
    bool showIndicator = true,
    Object Function(int index)? heroTagBuilder,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: backgroundColor,
        pageBuilder: (_, __, ___) => SmartImageGallery(
          images: images,
          initialIndex: initialIndex,
          backgroundColor: backgroundColor,
          maxScale: maxScale,
          showIndicator: showIndicator,
          heroTagBuilder: heroTagBuilder,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<SmartImageGallery> createState() => _SmartImageGalleryState();
}

class _SmartImageGalleryState extends State<SmartImageGallery> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(
      0,
      widget.images.isEmpty ? 0 : widget.images.length - 1,
    );
    _controller = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              widget.onPageChanged?.call(index);
            },
            itemBuilder: (context, index) {
              Widget page = ZoomableImage(
                maxScale: widget.maxScale,
                child: SmartImage(
                  image: widget.images[index],
                  fit: BoxFit.contain,
                  enableZoom: false,
                ),
              );
              final tag = widget.heroTagBuilder?.call(index);
              if (tag != null) {
                page = Hero(tag: tag, child: page);
              }
              return page;
            },
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
          if (widget.showIndicator && widget.images.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.images.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
