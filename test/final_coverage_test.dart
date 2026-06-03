import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:smart_image_x/smart_image_x.dart';
import 'package:smart_image_x/src/renderer/image_renderer.dart';
import 'package:smart_image_x/src/services/connectivity_service.dart';
import 'package:smart_image_x/src/services/image_loader_service.dart';

Uint8List _png({int w = 16, int h = 16}) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(33, 66, 99));
  return Uint8List.fromList(img.encodePng(image));
}

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

/// A controllable [Connectivity] for the connectivity-service tests.
class _FakeConnectivity implements Connectivity {
  _FakeConnectivity(this.results);
  final List<ConnectivityResult> results;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => results;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      Stream<List<ConnectivityResult>>.value(results);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConnectivityService lifecycle', () {
    test('start() classifies the current connection', () async {
      final service =
          ConnectivityService(connectivity: _FakeConnectivity([ConnectivityResult.wifi]));
      expect(service.quality, ConnectionQuality.unknown);
      await service.start();
      expect(service.quality, ConnectionQuality.fast);
      await service.start(); // idempotent
      await service.dispose();
    });

    test('probe() returns the current quality without subscribing', () async {
      final service = ConnectivityService(
        connectivity: _FakeConnectivity([ConnectivityResult.mobile]),
      );
      expect(await service.probe(), ConnectionQuality.slow);
      await service.dispose();
    });
  });

  group('ImageTransformer branches', () {
    final png = _png(w: 24, h: 24);

    test('vertical and both flips encode successfully', () async {
      final v = await SmartImageTools.flipImage(
        png,
        direction: FlipDirection.vertical,
      );
      final b = await SmartImageTools.flipImage(
        png,
        direction: FlipDirection.both,
      );
      expect(img.decodeImage(v), isNotNull);
      expect(img.decodeImage(b), isNotNull);
    });

    test('colour adjustments + blur to a GIF output', () async {
      final out = await ImageTransformer.transform(
        png,
        const TransformSpec(
          brightness: 1.1,
          contrast: 110,
          saturation: 1.2,
          blurRadius: 2,
          outputFormat: CompressionFormat.gif,
        ),
      );
      expect(FormatDetector.fromBytes(out), ImageFormat.gif);
    });

    test('crop + rotate to a BMP output', () async {
      final out = await ImageTransformer.transform(
        png,
        const TransformSpec(
          crop: Rect(x: 2, y: 2, width: 10, height: 10),
          rotateDegrees: 45,
          outputFormat: CompressionFormat.bmp,
        ),
      );
      expect(FormatDetector.fromBytes(out), ImageFormat.bmp);
    });

    test('webp output throws', () async {
      await expectLater(
        ImageTransformer.transform(
          png,
          const TransformSpec(grayscale: true, outputFormat: CompressionFormat.webp),
        ),
        throwsA(isA<SmartImageException>()),
      );
    });
  });

  group('ImageCompressor extras', () {
    test('encodableFor maps formats correctly', () {
      expect(ImageCompressor.encodableFor(ImageFormat.jpeg), CompressionFormat.jpg);
      expect(ImageCompressor.encodableFor(ImageFormat.png), CompressionFormat.png);
      expect(ImageCompressor.encodableFor(ImageFormat.gif), CompressionFormat.gif);
      expect(ImageCompressor.encodableFor(ImageFormat.bmp), CompressionFormat.bmp);
      expect(ImageCompressor.encodableFor(ImageFormat.svg), isNull);
      expect(ImageCompressor.encodableFor(ImageFormat.webp), isNull);
    });

    test('compresses to GIF and BMP', () async {
      final png = _png();
      final gif = await SmartImageTools.convertFormat(png, CompressionFormat.gif);
      final bmp = await SmartImageTools.convertFormat(png, CompressionFormat.bmp);
      expect(FormatDetector.fromBytes(gif), ImageFormat.gif);
      expect(FormatDetector.fromBytes(bmp), ImageFormat.bmp);
    });
  });

  group('ImageRenderer SVG from file', () {
    testWidgets('renders an SVG loaded from a file path', (tester) async {
      final dir = Directory.systemTemp.createTempSync('six_svg');
      final file = File('${dir.path}/icon.svg')
        ..writeAsStringSync('<svg viewBox="0 0 1 1"></svg>');
      try {
        await tester.pumpWidget(
          _host(
            ImageRenderer(
              loaded: LoadedImage.vector(
                SvgRenderSource(SvgDelivery.file, path: file.path),
                ImageFormat.svg,
              ),
              fit: BoxFit.contain,
              color: const Color(0xFF00FF00),
            ),
          ),
        );
        expect(find.byType(SvgPicture), findsOneWidget);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });

  group('BlurHashView didUpdateWidget', () {
    testWidgets('re-decodes when the hash changes', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          _host(
            const SizedBox(
              width: 64,
              height: 64,
              child: BlurHashView(hash: r'LEHV6nWB2yk8pyo0adR*.7kCMdnj'),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await tester.pumpWidget(
          _host(
            const SizedBox(
              width: 64,
              height: 64,
              child: BlurHashView(hash: r'L6PZfSi_.AyE_3t7t7R**0o#DgR4'),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pump();
      expect(find.byType(BlurHashView), findsOneWidget);
    });
  });

  group('SmartImage fallback & adaptive', () {
    testWidgets('falls back to a secondary image when the primary fails',
        (tester) async {
      final fallback = _png();
      var fellBack = false;
      await tester.pumpWidget(
        _host(
          SmartImage(
            // An unrecognised source fails deterministically (invalidSource),
            // exercising the same fallback chain without network timing.
            image: 12345,
            fallbackImage: fallback,
            loaderType: LoaderType.skeleton,
            transition: TransitionType.none,
            width: 60,
            height: 60,
            onFallback: () => fellBack = true,
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      // Outer widget + nested fallback SmartImage.
      expect(find.byType(SmartImage), findsNWidgets(2));
      expect(fellBack, isTrue);
    });

    testWidgets('adaptiveQuality applies a decode hint on a slow link',
        (tester) async {
      // Force a slow connection through the shared service.
      ConnectivityService.debugInstance = ConnectivityService(
        connectivity: _FakeConnectivity([ConnectivityResult.mobile]),
      );
      await ConnectivityService.instance.start();

      await tester.pumpWidget(
        _host(
          SmartImage(
            image: _png(),
            adaptiveQuality: true,
            loaderType: LoaderType.skeleton,
            transition: TransitionType.none,
            width: 100,
            height: 100,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(Image), findsOneWidget);

      ConnectivityService.debugInstance = ConnectivityService();
    });

    testWidgets('shows a tinted image (color) for in-memory bytes',
        (tester) async {
      await tester.pumpWidget(
        _host(
          SmartImage(
            image: _png(),
            color: const Color(0x80FF0000),
            loaderType: LoaderType.skeleton,
            transition: TransitionType.none,
            width: 60,
            height: 60,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(Image), findsOneWidget);
    });
  });

  group('RetryConfig.copyWith', () {
    test('overrides only the given fields', () {
      const base = RetryConfig(maxAttempts: 2);
      final updated = base.copyWith(maxAttempts: 5, useJitter: false);
      expect(updated.maxAttempts, 5);
      expect(updated.useJitter, isFalse);
      expect(updated.delay, base.delay);
    });
  });

  group('ResolvedImageSource cache keys', () {
    test('are stable per source type', () {
      expect(ResolvedImageSource.asset('a/b.png').cacheKey, 'asset:a/b.png');
      expect(ResolvedImageSource.file('/x.png').cacheKey, 'file:/x.png');
      expect(
        ResolvedImageSource.base64('AAAA', Uint8List(3)).cacheKey,
        'base64:3',
      );
      expect(
        ResolvedImageSource.svgString('<svg></svg>').cacheKey,
        'svg:11',
      );
    });
  });
}
