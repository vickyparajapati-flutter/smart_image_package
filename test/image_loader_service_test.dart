import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:smart_image_x/smart_image_x.dart';
import 'package:smart_image_x/src/services/image_loader_service.dart';
import 'package:smart_image_x/src/services/network_service.dart';

Uint8List _png({int w = 16, int h = 16}) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(10, 20, 30));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ImageLoaderService loaderWith(http.Client client) => ImageLoaderService(
        cacheManager: CacheManager(const CacheConfig()),
        networkService: NetworkService(client: client),
      );

  test('loads in-memory bytes as a raster provider', () async {
    final loaded = await ImageLoaderService().load(
      ResolvedImageSource.memory(_png()),
    );
    expect(loaded.isSvg, isFalse);
    expect(loaded.provider, isA<MemoryImage>());
    expect(loaded.format, ImageFormat.png);
  });

  test('loads inline SVG as a vector source', () async {
    final loaded = await ImageLoaderService().load(
      SourceDetector.detect('<svg viewBox="0 0 1 1"></svg>'),
    );
    expect(loaded.isSvg, isTrue);
    expect(loaded.svg!.delivery, SvgDelivery.string);
  });

  test('loads a local file as a FileImage', () async {
    final dir = Directory.systemTemp.createTempSync('six_loader');
    final file = File('${dir.path}/pic.png')..writeAsBytesSync(_png());
    try {
      final loaded = await ImageLoaderService().load(
        ResolvedImageSource.file(file.path),
      );
      expect(loaded.provider, isA<FileImage>());
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test('throws notFound for a missing file', () async {
    await expectLater(
      ImageLoaderService().load(
        ResolvedImageSource.file('/no/such/file.png'),
      ),
      throwsA(
        isA<SmartImageException>()
            .having((e) => e.type, 'type', SmartImageErrorType.notFound),
      ),
    );
  });

  test('throws invalidSource for an unknown source', () async {
    await expectLater(
      ImageLoaderService().load(ResolvedImageSource.unknown(42)),
      throwsA(
        isA<SmartImageException>()
            .having((e) => e.type, 'type', SmartImageErrorType.invalidSource),
      ),
    );
  });

  test('fetches a network image and reports a cache miss', () async {
    final png = _png();
    var calls = 0;
    final loader = loaderWith(MockClient((_) async {
      calls++;
      return http.Response.bytes(png, 200, headers: {
        'content-type': 'image/png',
      },);
    }),);

    var missed = false;
    final loaded = await loader.load(
      ResolvedImageSource.network('https://x.com/a.png'),
      callbacks: SmartImageCallbacks(onCacheMiss: () => missed = true),
    );
    expect(loaded.provider, isA<MemoryImage>());
    expect(missed, isTrue);
    expect(calls, 1);
  });

  test('serves a second network load from cache (hit, no refetch)', () async {
    final png = _png();
    var calls = 0;
    final cache = CacheManager(const CacheConfig());
    final loader = ImageLoaderService(
      cacheManager: cache,
      networkService: NetworkService(client: MockClient((_) async {
        calls++;
        return http.Response.bytes(png, 200, headers: {
          'content-type': 'image/png',
        },);
      }),),
    );
    final source = ResolvedImageSource.network('https://x.com/cached.png');

    await loader.load(source, policy: CachePolicy.memoryOnly);
    var hit = false;
    await loader.load(
      source,
      policy: CachePolicy.memoryOnly,
      callbacks: SmartImageCallbacks(onCacheHit: () => hit = true),
    );
    expect(hit, isTrue);
    expect(calls, 1);
  });

  test('applies a transform to network bytes', () async {
    final png = _png(w: 20, h: 20);
    final loader = loaderWith(MockClient(
      (_) async => http.Response.bytes(png, 200, headers: {
        'content-type': 'image/png',
      },),
    ),);
    final loaded = await loader.load(
      ResolvedImageSource.network('https://x.com/g.png'),
      transform: const TransformSpec(grayscale: true),
    );
    expect(loaded.provider, isA<MemoryImage>());
  });
}
