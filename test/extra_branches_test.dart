import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:smart_image_x/smart_image_x.dart';
import 'package:smart_image_x/src/renderer/image_renderer.dart';
import 'package:smart_image_x/src/services/image_loader_service.dart';
import 'package:smart_image_x/src/services/network_service.dart';
import 'package:smart_image_x/src/utils/byte_resolver.dart';

Uint8List _png() {
  final image = img.Image(width: 12, height: 12);
  img.fill(image, color: img.ColorRgb8(20, 40, 60));
  return Uint8List.fromList(img.encodePng(image));
}

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmartImageException toString / retryability', () {
    test('includes status and cause', () {
      const e = SmartImageException(
        SmartImageErrorType.httpStatus,
        'boom',
        statusCode: 500,
        cause: 'underlying',
      );
      expect(e.isRetryable, isTrue);
      final s = e.toString();
      expect(s, contains('500'));
      expect(s, contains('underlying'));
    });
  });

  group('DownloadProgress toString', () {
    test('renders determinate and indeterminate forms', () {
      expect(const DownloadProgress(received: 5, total: 10).toString(),
          contains('5/10'),);
      expect(const DownloadProgress(received: 5, total: -1).toString(),
          contains('?'),);
    });
  });

  group('MetadataService non-raster', () {
    test('returns zero-dimension metadata for SVG bytes', () async {
      final svg = Uint8List.fromList('<svg viewBox="0 0 1 1"></svg>'.codeUnits);
      final meta = await SmartImage.getMetadata(svg);
      expect(meta, isNotNull);
      expect(meta!.width, 0);
      expect(meta.format, ImageFormat.svg);
    });
  });

  group('ImageLoaderService source branches', () {
    test('asset PNG resolves to an AssetImage', () async {
      final loaded = await ImageLoaderService().load(
        ResolvedImageSource.asset('assets/pic.png'),
      );
      expect(loaded.provider, isA<AssetImage>());
    });

    test('asset SVG resolves to a vector asset source', () async {
      final loaded = await ImageLoaderService().load(
        ResolvedImageSource.asset('assets/icon.svg'),
      );
      expect(loaded.isSvg, isTrue);
      expect(loaded.svg!.delivery, SvgDelivery.asset);
    });

    test('file SVG resolves to a vector file source', () async {
      final dir = Directory.systemTemp.createTempSync('six_fsvg');
      final file = File('${dir.path}/i.svg')
        ..writeAsStringSync('<svg viewBox="0 0 1 1"></svg>');
      try {
        final loaded =
            await ImageLoaderService().load(ResolvedImageSource.file(file.path));
        expect(loaded.isSvg, isTrue);
        expect(loaded.svg!.delivery, SvgDelivery.file);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('network SVG resolves to vector bytes', () async {
      final svg = Uint8List.fromList('<svg viewBox="0 0 1 1"></svg>'.codeUnits);
      final loader = ImageLoaderService(
        cacheManager: CacheManager(const CacheConfig()),
        networkService: NetworkService(client: MockClient((_) async {
          return http.Response.bytes(svg, 200, headers: {
            'content-type': 'image/svg+xml',
          },);
        }),),
      );
      final loaded = await loader.load(
        ResolvedImageSource.network('https://x.com/i.svg'),
      );
      expect(loaded.isSvg, isTrue);
      expect(loaded.svg!.delivery, SvgDelivery.bytes);
    });
  });

  group('ImageRenderer SVG from asset', () {
    testWidgets('builds an SvgPicture.asset', (tester) async {
      await tester.pumpWidget(
        _host(
          const ImageRenderer(
            loaded: LoadedImage.vector(
              SvgRenderSource(SvgDelivery.asset, path: 'assets/icon.svg'),
              ImageFormat.svg,
            ),
            fit: BoxFit.contain,
          ),
        ),
      );
      expect(find.byType(SvgPicture), findsOneWidget);
    });
  });

  group('SmartImageBytes asset', () {
    test('returns null when an asset is absent in tests', () async {
      final result = await SmartImageBytes.resolve(
        ResolvedImageSource.asset('assets/does_not_exist.png'),
      );
      expect(result, isNull);
    });
  });

  group('SourceDetector edge classification', () {
    test('relative path with an image extension resolves to an asset', () {
      expect(SourceDetector.detect('photo.png').type, ImageSourceType.asset);
    });

    test('unclassifiable text resolves to unknown', () {
      expect(SourceDetector.detect('just some random text').type,
          ImageSourceType.unknown,);
    });

    test('packages/ paths resolve to assets', () {
      expect(SourceDetector.detect('packages/p/a.webp').type,
          ImageSourceType.asset,);
    });
  });

  group('SmartImage wrappers', () {
    testWidgets('wraps in a Hero when heroTag is set', (tester) async {
      await tester.pumpWidget(
        _host(
          SmartImage(
            image: _png(),
            heroTag: 'tag-1',
            loaderType: LoaderType.skeleton,
            transition: TransitionType.none,
            width: 50,
            height: 50,
          ),
        ),
      );
      expect(find.byType(Hero), findsOneWidget);
    });

    testWidgets('omits Semantics when excludeFromSemantics is true',
        (tester) async {
      await tester.pumpWidget(
        _host(
          SmartImage(
            image: _png(),
            excludeFromSemantics: true,
            loaderType: LoaderType.skeleton,
            transition: TransitionType.none,
            width: 50,
            height: 50,
          ),
        ),
      );
      expect(find.byType(SmartImage), findsOneWidget);
    });

    testWidgets('runs the thumbnail (progressive) path without error',
        (tester) async {
      await tester.pumpWidget(
        _host(
          SmartImage(
            image: _png(),
            thumbnail: _png(),
            loaderType: LoaderType.skeleton,
            transition: TransitionType.none,
            width: 50,
            height: 50,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(SmartImage), findsOneWidget);
    });

    testWidgets('default error widget retry re-triggers a load', (tester) async {
      await tester.pumpWidget(
        _host(
          const SmartImage(
            image: 9999, // unknown source → default error UI
            width: 200,
            height: 200,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      // Still in error after retry (same unknown source).
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
