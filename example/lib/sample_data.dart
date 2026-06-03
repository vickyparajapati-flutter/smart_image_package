import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Shared demo data and lazy loaders so the Asset / Memory / Base64 / File demos
/// all reference the same bundled [samplePngAsset] image.
class SampleData {
  SampleData._();

  static const samplePngAsset = 'assets/sample.png';
  static const logoSvgAsset = 'assets/logo.svg';
  static const avatarSvgAsset = 'assets/avatar_placeholder.svg';

  /// A precomputed BlurHash for one of the demo network photos.
  static const demoBlurHash = r'L6PZfSi_.AyE_3t7t7R**0o#DgR4';

  /// Network photos used across the gallery / network demos.
  static const networkPhotos = <String>[
    'https://picsum.photos/id/1015/800/600',
    'https://picsum.photos/id/1025/800/600',
    'https://picsum.photos/id/1003/800/600',
    'https://picsum.photos/id/1044/800/600',
    'https://picsum.photos/id/1062/800/600',
    'https://picsum.photos/id/1074/800/600',
  ];

  static const inlineSvg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
      '<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">'
      '<stop offset="0" stop-color="#6750A4"/>'
      '<stop offset="1" stop-color="#00ACC1"/></linearGradient></defs>'
      '<rect width="100" height="100" rx="18" fill="url(#g)"/>'
      '<path d="M28 52l16 16 30-34" stroke="white" stroke-width="9" '
      'fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>';

  static Uint8List? _bytes;
  static String? _filePath;

  /// The bundled sample image as raw bytes (for the Memory demo).
  static Future<Uint8List> bytes() async {
    return _bytes ??=
        (await rootBundle.load(samplePngAsset)).buffer.asUint8List();
  }

  /// The bundled sample image as a base64 `data:` URI (for the Base64 demo).
  static Future<String> base64DataUri() async {
    final data = await bytes();
    return 'data:image/png;base64,${base64Encode(data)}';
  }

  /// Writes the bundled sample image to a temp file once and returns its path
  /// (for the File demo).
  static Future<String> tempFilePath() async {
    if (_filePath != null) return _filePath!;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/smart_image_x_sample.png');
    await file.writeAsBytes(await bytes());
    return _filePath = file.path;
  }
}
