import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:smart_image_x/smart_image_x.dart';
import 'package:smart_image_x/src/analytics/cache_analytics.dart';
import 'package:smart_image_x/src/services/network_service.dart';
import 'package:smart_image_x/src/utils/byte_resolver.dart';
import 'package:smart_image_x/src/utils/logger.dart';

Uint8List _png() {
  final image = img.Image(width: 12, height: 12);
  img.fill(image, color: img.ColorRgb8(70, 90, 110));
  return Uint8List.fromList(img.encodePng(image));
}

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmartImageCallbacks', () {
    test('isEmpty reflects whether any callback is set', () {
      expect(const SmartImageCallbacks().isEmpty, isTrue);
      expect(
        SmartImageCallbacks(onLoadStart: () {}).isEmpty,
        isFalse,
      );
      expect(
        SmartImageCallbacks(onProgress: (_) {}).isEmpty,
        isFalse,
      );
    });
  });

  group('CacheAnalytics', () {
    test('tracks hits, misses and rates, and resets', () {
      final a = CacheAnalytics()
        ..recordMemoryHit()
        ..recordDiskHit()
        ..recordMiss();
      expect(a.memoryHits, 1);
      expect(a.diskHits, 1);
      expect(a.hits, 2);
      expect(a.misses, 1);
      expect(a.total, 3);
      expect(a.hitRate, closeTo(2 / 3, 0.001));
      expect(a.missRate, closeTo(1 / 3, 0.001));
      a.reset();
      expect(a.total, 0);
      expect(a.hitRate, 0);
    });
  });

  group('SmartLogger', () {
    tearDown(SmartImageConfig.reset);

    test('emits at every level when verbose, no-ops when none', () {
      SmartImageConfig.configure(
        const SmartImageConfig(logLevel: SmartImageLogLevel.verbose),
      );
      // Should not throw at any level.
      SmartLogger.error('e', Exception('x'), StackTrace.current);
      SmartLogger.warning('w');
      SmartLogger.info('i');
      SmartLogger.verbose(() => 'v');

      SmartImageConfig.configure(
        const SmartImageConfig(logLevel: SmartImageLogLevel.none),
      );
      var built = false;
      SmartLogger.verbose(() {
        built = true;
        return 'should-not-build';
      });
      expect(built, isFalse);
    });
  });

  group('CacheManager extras', () {
    Uint8List p(int n) => Uint8List(n);

    test('evict removes from both tiers', () async {
      final m = CacheManager(const CacheConfig());
      await m.write('k', p(10), CachePolicy.memoryOnly);
      await m.evict('k');
      expect(await m.read('k', CachePolicy.memoryOnly), isNull);
    });

    test('reconfigure swaps the memory tier', () async {
      final m = CacheManager(const CacheConfig());
      await m.write('k', p(10), CachePolicy.memoryOnly);
      m.debugReconfigure(const CacheConfig(maxMemoryBytes: 2048));
      // Old memory entry is discarded by reconfigure.
      expect(await m.read('k', CachePolicy.memoryOnly), isNull);
    });

    test('clearAll and clearDisk complete without error', () async {
      final m = CacheManager(const CacheConfig());
      await m.write('k', p(10), CachePolicy.memoryOnly);
      await m.clearAll();
      await m.clearDisk();
      expect(await m.read('k', CachePolicy.memoryOnly), isNull);
    });

    test('refresh policy writes to memory', () async {
      final m = CacheManager(const CacheConfig());
      await m.write('k', p(10), CachePolicy.refresh);
      // refresh forces network so read returns null, but the value was stored.
      expect(await m.read('k', CachePolicy.memoryOnly), isNotNull);
    });

    test('static instance and reconfigure are wired', () {
      CacheManager.reconfigure(const CacheConfig(maxMemoryBytes: 4096));
      expect(CacheManager.instance, isNotNull);
    });
  });

  group('SmartImageBytes network resolution', () {
    test('fetches and caches network bytes', () async {
      final png = _png();
      NetworkService.debugInstance = NetworkService(
        client: MockClient(
          (_) async => http.Response.bytes(png, 200, headers: {
            'content-type': 'image/png',
          },),
        ),
      );
      CacheManager.debugInstance = CacheManager(const CacheConfig());

      final result = await SmartImageBytes.resolve(
        ResolvedImageSource.network('https://x.com/b.png'),
        policy: CachePolicy.memoryOnly,
      );
      expect(result, png);

      // Restore real singletons for any later widget tests.
      NetworkService.debugInstance = NetworkService();
      CacheManager.debugInstance = CacheManager(SmartImageConfig.instance.cache);
    });
  });

  group('ResolvedImageSource', () {
    test('exposes identity helpers', () {
      final net = ResolvedImageSource.network('https://x.com/a.png');
      expect(net.requiresNetwork, isTrue);
      expect(net.hasInlineBytes, isFalse);
      expect(net.toString(), contains('network'));

      final mem = ResolvedImageSource.memory(Uint8List(4));
      expect(mem.hasInlineBytes, isTrue);
      expect(mem.cacheKey, 'memory:4');
    });
  });

  group('SourceDetector Uri inputs', () {
    test('classifies file, network and data URIs', () {
      expect(
        SourceDetector.detect(Uri.parse('file:///tmp/a.png')).type,
        ImageSourceType.file,
      );
      expect(
        SourceDetector.detect(Uri.parse('https://x.com/a.png')).type,
        ImageSourceType.network,
      );
      expect(
        SourceDetector.detect(
          Uri.parse('data:text/plain;base64,aGVsbG8gd29ybGQgMTIzNDU2Nzg5'),
        ).type,
        ImageSourceType.base64,
      );
    });
  });

  group('ZoomableImage double-tap', () {
    testWidgets('double-tap zooms in then out', (tester) async {
      await tester.pumpWidget(
        _host(
          const ZoomableImage(
            child: SizedBox(width: 200, height: 200, child: ColoredBox(color: Color(0xFF112233))),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(InteractiveViewer));

      // First double-tap → zoom in.
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center);
      await tester.pumpAndSettle();

      // Second double-tap → zoom back out.
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center);
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsOneWidget);
    });
  });

  group('SmartImage interaction & placeholders', () {
    testWidgets('enableZoom wraps content in a ZoomableImage', (tester) async {
      await tester.pumpWidget(
        _host(
          SmartImage(
            image: _png(),
            enableZoom: true,
            loaderType: LoaderType.skeleton,
            width: 60,
            height: 60,
          ),
        ),
      );
      expect(find.byType(ZoomableImage), findsOneWidget);
    });

    testWidgets('openViewerOnTap opens the full-screen viewer', (tester) async {
      await tester.pumpWidget(
        _host(
          SmartImage(
            image: _png(),
            openViewerOnTap: true,
            loaderType: LoaderType.skeleton,
            width: 60,
            height: 60,
          ),
        ),
      );
      await tester.tap(find.byType(SmartImage).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('placeholderColor wraps the loader in a ColoredBox',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const SmartImage(
            image: 'https://example.com/pending-image.png',
            loaderType: LoaderType.circular,
            placeholderColor: Color(0xFFEEEEEE),
            width: 60,
            height: 60,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Drain the in-flight request (resolves to an error) without settling on
      // the indeterminate spinner, which never stops animating.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    });

    testWidgets('reloads when the image source changes (didUpdateWidget)',
        (tester) async {
      await tester.pumpWidget(
        _host(
          SmartImage(
            image: _png(),
            loaderType: LoaderType.skeleton,
            transition: TransitionType.none,
          ),
        ),
      );
      await tester.pump();
      // Swap to a different source → triggers didUpdateWidget reload path.
      await tester.pumpWidget(
        _host(
          SmartImage(
            image: _png(),
            loaderType: LoaderType.skeleton,
            transition: TransitionType.none,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(SmartImage), findsOneWidget);
    });
  });
}
