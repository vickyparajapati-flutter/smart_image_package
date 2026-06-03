import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Pure-Dart decoder for the [BlurHash](https://blurha.sh) placeholder format.
///
/// Implemented natively so SmartImageX carries no BlurHash dependency. Given a
/// compact hash string it reconstructs a small, blurred RGBA bitmap suitable as
/// an instant placeholder while the full image loads.
///
/// The algorithm follows the reference spec: the hash encodes a DC term plus a
/// grid of AC terms over the cosine basis; each output pixel is the sum of
/// those terms weighted by the basis functions, then sRGB-encoded.
class BlurHashDecoder {
  const BlurHashDecoder._();

  static const String _digits =
      r'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~';

  /// Returns `true` if [hash] is structurally a valid BlurHash.
  static bool isValid(String hash) {
    if (hash.length < 6) return false;
    final sizeFlag = _decode83(hash[0]);
    if (sizeFlag < 0) return false;
    final numY = (sizeFlag ~/ 9) + 1;
    final numX = (sizeFlag % 9) + 1;
    return hash.length == 4 + 2 * numX * numY;
  }

  /// Decodes [hash] into a [width]×[height] RGBA8888 byte buffer.
  ///
  /// [punch] (default `1.0`) scales contrast of the AC components. Throws
  /// [FormatException] when the hash is malformed.
  static Uint8List decodeToRgba(
    String hash, {
    int width = 32,
    int height = 32,
    double punch = 1.0,
  }) {
    if (!isValid(hash)) {
      throw const FormatException('Invalid BlurHash string');
    }

    final sizeFlag = _decode83(hash[0]);
    final numY = (sizeFlag ~/ 9) + 1;
    final numX = (sizeFlag % 9) + 1;

    final quantisedMaxValue = _decode83(hash[1]);
    final maxValue = (quantisedMaxValue + 1) / 166.0;

    final colorCount = numX * numY;
    final colors = List<List<double>>.filled(colorCount, const []);

    colors[0] = _decodeDc(_decode83(hash.substring(2, 6)));
    for (var i = 1; i < colorCount; i++) {
      final value = _decode83(hash.substring(4 + i * 2, 6 + i * 2));
      colors[i] = _decodeAc(value, maxValue * punch);
    }

    final pixels = Uint8List(width * height * 4);
    var offset = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var r = 0.0, g = 0.0, b = 0.0;
        for (var j = 0; j < numY; j++) {
          for (var i = 0; i < numX; i++) {
            final basis = math.cos(math.pi * x * i / width) *
                math.cos(math.pi * y * j / height);
            final color = colors[i + j * numX];
            r += color[0] * basis;
            g += color[1] * basis;
            b += color[2] * basis;
          }
        }
        pixels[offset++] = _linearToSrgb(r);
        pixels[offset++] = _linearToSrgb(g);
        pixels[offset++] = _linearToSrgb(b);
        pixels[offset++] = 255;
      }
    }
    return pixels;
  }

  /// Decodes [hash] into a [ui.Image] ready to paint.
  static Future<ui.Image> decodeToImage(
    String hash, {
    int width = 32,
    int height = 32,
    double punch = 1.0,
  }) {
    final rgba = decodeToRgba(hash, width: width, height: height, punch: punch);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  static int _decode83(String value) {
    var result = 0;
    for (var i = 0; i < value.length; i++) {
      final index = _digits.indexOf(value[i]);
      if (index == -1) return -1;
      result = result * 83 + index;
    }
    return result;
  }

  static List<double> _decodeDc(int value) {
    final r = value >> 16;
    final g = (value >> 8) & 255;
    final b = value & 255;
    return [_srgbToLinear(r), _srgbToLinear(g), _srgbToLinear(b)];
  }

  static List<double> _decodeAc(int value, double maxValue) {
    final r = value ~/ (19 * 19);
    final g = (value ~/ 19) % 19;
    final b = value % 19;
    return [
      _signedPow((r - 9) / 9.0) * maxValue,
      _signedPow((g - 9) / 9.0) * maxValue,
      _signedPow((b - 9) / 9.0) * maxValue,
    ];
  }

  static double _signedPow(double value) =>
      value.sign * math.pow(value.abs(), 2.0).toDouble();

  static double _srgbToLinear(int value) {
    final v = value / 255.0;
    return v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  static int _linearToSrgb(double value) {
    final v = value.clamp(0.0, 1.0);
    final result = v <= 0.0031308
        ? v * 12.92
        : 1.055 * math.pow(v, 1 / 2.4).toDouble() - 0.055;
    return (result * 255 + 0.5).floor().clamp(0, 255);
  }
}
