import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../enums/transition_type.dart';
import '../services/image_loader_service.dart';

/// Presents a [LoadedImage] — raster or vector — at the requested size and fit.
///
/// This is a pure presenter: it holds no loading state. The owning controller
/// only constructs it once bytes/provider are resolved, so the renderer's sole
/// concern is choosing the right Flutter primitive ([Image] for raster,
/// [SvgPicture] for vector) and wiring decode-time callbacks back up.
///
/// Raster decode errors (e.g. a corrupt asset that slipped past detection) are
/// surfaced through [onError] so the controller can run its fallback chain.
class ImageRenderer extends StatelessWidget {
  /// Creates a renderer for [loaded].
  const ImageRenderer({
    required this.loaded,
    required this.fit,
    this.width,
    this.height,
    this.color,
    this.semanticLabel,
    this.transition = TransitionType.fade,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.cacheWidth,
    this.cacheHeight,
    this.onError,
    this.onFirstFrame,
    super.key,
  });

  /// The resolved image to present.
  final LoadedImage loaded;

  /// How the image fills its box.
  final BoxFit fit;

  /// Optional target width.
  final double? width;

  /// Optional target height.
  final double? height;

  /// Optional tint (applied to SVG and raster alike).
  final Color? color;

  /// Accessibility label.
  final String? semanticLabel;

  /// Entrance animation for raster frames.
  final TransitionType transition;

  /// Duration of the entrance animation.
  final Duration transitionDuration;

  /// Decode-time width hint (memory optimisation / adaptive quality).
  final int? cacheWidth;

  /// Decode-time height hint.
  final int? cacheHeight;

  /// Invoked if a raster frame fails to decode.
  final void Function(Object error, StackTrace? stack)? onError;

  /// Invoked (once) when the first raster frame becomes available.
  final VoidCallback? onFirstFrame;

  @override
  Widget build(BuildContext context) {
    if (loaded.isSvg) {
      return _buildSvg();
    }
    return _buildRaster();
  }

  Widget _buildSvg() {
    final svg = loaded.svg!;
    final colorFilter =
        color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn);
    switch (svg.delivery) {
      case SvgDelivery.string:
        return SvgPicture.string(
          svg.string!,
          width: width,
          height: height,
          fit: fit,
          colorFilter: colorFilter,
          semanticsLabel: semanticLabel,
        );
      case SvgDelivery.asset:
        return SvgPicture.asset(
          svg.path!,
          width: width,
          height: height,
          fit: fit,
          colorFilter: colorFilter,
          semanticsLabel: semanticLabel,
        );
      case SvgDelivery.file:
        return SvgPicture.file(
          File(svg.path!),
          width: width,
          height: height,
          fit: fit,
          colorFilter: colorFilter,
          semanticsLabel: semanticLabel,
        );
      case SvgDelivery.bytes:
        return SvgPicture.memory(
          svg.bytes!,
          width: width,
          height: height,
          fit: fit,
          colorFilter: colorFilter,
          semanticsLabel: semanticLabel,
        );
    }
  }

  Widget _buildRaster() {
    // Apply a decode-size hint (memory optimisation / adaptive quality) by
    // wrapping the provider in a ResizeImage when a cache dimension is set.
    final provider = (cacheWidth != null || cacheHeight != null)
        ? ResizeImage(
            loaded.provider!,
            width: cacheWidth,
            height: cacheHeight,
            policy: ResizeImagePolicy.fit,
          )
        : loaded.provider!;

    return Image(
      image: provider,
      width: width,
      height: height,
      fit: fit,
      color: color,
      semanticLabel: semanticLabel,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      frameBuilder: _frameBuilder,
      errorBuilder: (context, error, stack) {
        onError?.call(error, stack);
        // The controller will replace this subtree; render nothing meanwhile.
        return const SizedBox.shrink();
      },
    );
  }

  Widget _frameBuilder(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if (frame != null && onFirstFrame != null) {
      // Defer to after this build to avoid setState-during-build in listeners.
      WidgetsBinding.instance.addPostFrameCallback((_) => onFirstFrame!());
    }
    if (transition == TransitionType.none || wasSynchronouslyLoaded) {
      return child;
    }
    final visible = frame != null;
    switch (transition) {
      case TransitionType.scale:
        return AnimatedScale(
          scale: visible ? 1.0 : 0.92,
          duration: transitionDuration,
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: visible ? 1.0 : 0.0,
            duration: transitionDuration,
            child: child,
          ),
        );
      case TransitionType.fade:
      case TransitionType.crossFade:
      case TransitionType.none:
        return AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: transitionDuration,
          curve: Curves.easeOut,
          child: child,
        );
    }
  }
}
