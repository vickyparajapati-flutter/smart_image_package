import 'package:flutter/material.dart';

import '../enums/loader_type.dart';

/// A determinate or indeterminate circular spinner placeholder.
class CircularLoader extends StatelessWidget {
  /// Creates a circular loader. Supply [progress] (`0.0..1.0`) for a
  /// determinate indicator.
  const CircularLoader({this.progress, this.color, super.key});

  /// Completion fraction, or `null` for an indeterminate spinner.
  final double? progress;

  /// Optional indicator colour; defaults to the theme's primary colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          value: progress,
          color: color,
        ),
      ),
    );
  }
}

/// An animated shimmer-sweep placeholder, theme-aware for light and dark modes.
class ShimmerLoader extends StatefulWidget {
  /// Creates a shimmer loader.
  const ShimmerLoader({this.baseColor, this.highlightColor, super.key});

  /// Base block colour.
  final Color? baseColor;

  /// Sweep highlight colour.
  final Color? highlightColor;

  @override
  State<ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = widget.baseColor ??
        (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0));
    final highlight = widget.highlightColor ??
        (isDark ? const Color(0xFF3D3D3D) : const Color(0xFFF5F5F5));

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final dx = (bounds.width + bounds.height) * _controller.value;
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlideGradient(dx - bounds.width),
            ).createShader(bounds);
          },
          child: ColoredBox(color: base, child: const SizedBox.expand()),
        );
      },
    );
  }
}

/// Translates a gradient horizontally to animate the shimmer sweep.
class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.dx);
  final double dx;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}

/// A static, theme-aware skeleton block — the cheapest placeholder for long
/// lists (no animation, single paint).
class SkeletonLoader extends StatelessWidget {
  /// Creates a skeleton placeholder.
  const SkeletonLoader({this.color, super.key});

  /// Block colour; defaults to a theme-appropriate neutral.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: color ??
          (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE)),
      child: const SizedBox.expand(),
    );
  }
}

/// Builds the placeholder widget for a given [LoaderType].
///
/// Centralises placeholder selection so the core widget stays declarative.
/// [LoaderType.custom] resolves to a [SkeletonLoader] here; the core widget is
/// expected to short-circuit to the developer's `loadingBuilder` before
/// reaching this fallback.
class SmartLoader extends StatelessWidget {
  /// Creates a loader for [type].
  const SmartLoader({
    required this.type,
    this.progress,
    super.key,
  });

  /// The placeholder style.
  final LoaderType type;

  /// Optional determinate progress for [LoaderType.circular].
  final double? progress;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case LoaderType.circular:
        return CircularLoader(progress: progress);
      case LoaderType.shimmer:
        return const ShimmerLoader();
      case LoaderType.skeleton:
      case LoaderType.custom:
        return const SkeletonLoader();
    }
  }
}
