import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../utils/logger.dart';
import 'blurhash_decoder.dart';

/// Paints a decoded [BlurHashDecoder] bitmap, scaled to fill its box.
///
/// Decoding happens off the build path (in [initState]/[didUpdateWidget]) and
/// the tiny source bitmap is stretched by the GPU, so this is cheap enough to
/// use as a placeholder behind every image in a long list.
class BlurHashView extends StatefulWidget {
  /// Creates a BlurHash placeholder for [hash].
  const BlurHashView({
    required this.hash,
    this.decodeWidth = 32,
    this.decodeHeight = 32,
    this.fit = BoxFit.cover,
    this.punch = 1.0,
    super.key,
  });

  /// The BlurHash string.
  final String hash;

  /// Width of the intermediate decoded bitmap (kept small for speed).
  final int decodeWidth;

  /// Height of the intermediate decoded bitmap.
  final int decodeHeight;

  /// How the placeholder fills its box.
  final BoxFit fit;

  /// Contrast multiplier for AC components.
  final double punch;

  @override
  State<BlurHashView> createState() => _BlurHashViewState();
}

class _BlurHashViewState extends State<BlurHashView> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(BlurHashView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hash != widget.hash ||
        oldWidget.punch != widget.punch ||
        oldWidget.decodeWidth != widget.decodeWidth ||
        oldWidget.decodeHeight != widget.decodeHeight) {
      _decode();
    }
  }

  Future<void> _decode() async {
    try {
      final image = await BlurHashDecoder.decodeToImage(
        widget.hash,
        width: widget.decodeWidth,
        height: widget.decodeHeight,
        punch: widget.punch,
      );
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _image?.dispose();
        _image = image;
      });
    } catch (error) {
      SmartLogger.warning('BlurHash decode failed: $error');
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return const SizedBox.expand();
    return RawImage(image: image, fit: widget.fit);
  }
}
