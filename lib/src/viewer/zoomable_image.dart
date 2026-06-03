import 'package:flutter/widgets.dart';

/// Wraps any [child] in pinch-zoom, pan and double-tap-to-zoom gestures using
/// Flutter's built-in [InteractiveViewer] — no external package required.
///
/// Double-tapping toggles between the un-zoomed state and [doubleTapScale],
/// animating around the tap point so the region under the finger stays put.
class ZoomableImage extends StatefulWidget {
  /// Creates a zoomable wrapper around [child].
  const ZoomableImage({
    required this.child,
    this.minScale = 1.0,
    this.maxScale = 5.0,
    this.doubleTapScale = 2.5,
    this.enableDoubleTap = true,
    super.key,
  });

  /// The content to make zoomable (typically an image).
  final Widget child;

  /// Minimum zoom factor.
  final double minScale;

  /// Maximum zoom factor.
  final double maxScale;

  /// Zoom factor applied by a double-tap.
  final double doubleTapScale;

  /// Whether double-tap-to-zoom is enabled.
  final bool enableDoubleTap;

  @override
  State<ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImage>
    with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _animationController.addListener(_onAnimate);
  }

  void _onAnimate() {
    if (_animation != null) _controller.value = _animation!.value;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (!widget.enableDoubleTap) return;
    final isZoomed = _controller.value.getMaxScaleOnAxis() > 1.01;
    final Matrix4 end;
    if (isZoomed) {
      end = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      final scale = widget.doubleTapScale;
      // Translate so the tapped point remains stationary after scaling.
      end = Matrix4.identity()
        ..translateByDouble(
          -position.dx * (scale - 1),
          -position.dy * (scale - 1),
          0,
          1,
        )
        ..scaleByDouble(scale, scale, scale, 1);
    }
    _animation = Matrix4Tween(begin: _controller.value, end: end).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: widget.minScale,
        maxScale: widget.maxScale,
        clipBehavior: Clip.none,
        child: widget.child,
      ),
    );
  }
}
