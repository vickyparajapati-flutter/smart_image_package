import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:smart_image_x/smart_image_x.dart';
import 'package:smart_image_x/src/renderer/image_renderer.dart';
import 'package:smart_image_x/src/services/image_loader_service.dart';

Uint8List _png() {
  final image = img.Image(width: 16, height: 16);
  img.fill(image, color: img.ColorRgb8(50, 100, 150));
  return Uint8List.fromList(img.encodePng(image));
}

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('ImageRenderer', () {
    testWidgets('renders a raster Image with a cache-width hint',
        (tester) async {
      await tester.pumpWidget(
        _host(
          ImageRenderer(
            loaded: LoadedImage.raster(MemoryImage(_png()), ImageFormat.png),
            fit: BoxFit.cover,
            cacheWidth: 32,
            transition: TransitionType.none,
          ),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('renders an inline SVG string', (tester) async {
      await tester.pumpWidget(
        _host(
          const ImageRenderer(
            loaded: LoadedImage.vector(
              SvgRenderSource(SvgDelivery.string,
                  string: '<svg viewBox="0 0 1 1"></svg>',),
              ImageFormat.svg,
            ),
            fit: BoxFit.contain,
          ),
        ),
      );
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('renders an SVG from bytes', (tester) async {
      final bytes = Uint8List.fromList('<svg viewBox="0 0 1 1"></svg>'.codeUnits);
      await tester.pumpWidget(
        _host(
          ImageRenderer(
            loaded: LoadedImage.vector(
              SvgRenderSource(SvgDelivery.bytes, bytes: bytes),
              ImageFormat.svg,
            ),
            fit: BoxFit.contain,
          ),
        ),
      );
      expect(find.byType(SvgPicture), findsOneWidget);
    });
  });

  group('ZoomableImage', () {
    testWidgets('wraps its child in an InteractiveViewer', (tester) async {
      await tester.pumpWidget(
        _host(const ZoomableImage(child: SizedBox(width: 100, height: 100))),
      );
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });
  });

  group('SmartImageViewer', () {
    testWidgets('shows a close button and zoomable content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SmartImageViewer(image: _png())),
      );
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byType(ZoomableImage), findsOneWidget);
    });

    testWidgets('open() pushes a viewer route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    SmartImageViewer.open(context, image: _png()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });

  group('SmartImageGallery', () {
    testWidgets('shows a page indicator and close button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SmartImageGallery(images: [_png(), _png(), _png()]),
        ),
      );
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('open() pushes a gallery route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SmartImageGallery.open(
                  context,
                  images: [_png(), _png()],
                ),
                child: const Text('gallery'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('gallery'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('1 / 2'), findsOneWidget);
    });
  });

  group('BlurHashView', () {
    testWidgets('decodes a hash and paints a RawImage', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          _host(
            const SizedBox(
              width: 80,
              height: 80,
              child: BlurHashView(hash: r'LEHV6nWB2yk8pyo0adR*.7kCMdnj'),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(find.byType(RawImage), findsOneWidget);
    });

    testWidgets('renders an empty box for an invalid hash', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(width: 80, height: 80, child: BlurHashView(hash: '!')),
        ),
      );
      await tester.pump();
      expect(find.byType(RawImage), findsNothing);
    });
  });

  group('SmartImage crossFade', () {
    testWidgets('builds with a crossFade transition', (tester) async {
      await tester.pumpWidget(
        _host(
          SmartImage(
            image: _png(),
            transition: TransitionType.crossFade,
            loaderType: LoaderType.skeleton,
            width: 60,
            height: 60,
          ),
        ),
      );
      // Let the load microtask resolve so the loaded branch builds.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(SmartImage), findsOneWidget);
    });
  });
}
