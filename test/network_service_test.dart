import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_image_x/smart_image_x.dart';
import 'package:smart_image_x/src/services/network_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(SmartImageConfig.reset);

  test('returns bytes and content-type on a 200', () async {
    final client = MockClient((request) async {
      return http.Response.bytes(
        Uint8List.fromList([1, 2, 3, 4]),
        200,
        headers: {'content-type': 'image/png'},
      );
    });
    final service = NetworkService(client: client);

    final result = await service.fetch(Uri.parse('https://x.com/a.png'));
    expect(result.bytes, [1, 2, 3, 4]);
    expect(result.mimeType, 'image/png');
  });

  test('reports download progress', () async {
    final body = Uint8List.fromList(List.filled(100, 7));
    final client = MockClient((request) async {
      return http.Response.bytes(body, 200, headers: {
        'content-type': 'image/png',
        'content-length': '100',
      },);
    });
    final service = NetworkService(client: client);

    final events = <DownloadProgress>[];
    await service.fetch(
      Uri.parse('https://x.com/a.png'),
      onProgress: events.add,
    );
    expect(events, isNotEmpty);
    expect(events.last.received, 100);
  });

  test('throws a categorised httpStatus error on non-2xx', () async {
    final client = MockClient((request) async => http.Response('nope', 404));
    final service = NetworkService(client: client);

    await expectLater(
      service.fetch(Uri.parse('https://x.com/missing.png')),
      throwsA(
        isA<SmartImageException>()
            .having((e) => e.type, 'type', SmartImageErrorType.httpStatus)
            .having((e) => e.statusCode, 'statusCode', 404),
      ),
    );
  });

  test('rejects a host outside allowedDomains', () async {
    SmartImageConfig.configure(
      const SmartImageConfig(allowedDomains: ['allowed.com']),
    );
    final client = MockClient((request) async => http.Response('x', 200));
    final service = NetworkService(client: client);

    await expectLater(
      service.fetch(Uri.parse('https://evil.com/a.png')),
      throwsA(
        isA<SmartImageException>()
            .having((e) => e.type, 'type', SmartImageErrorType.blockedDomain),
      ),
    );
  });

  test('allows a whitelisted host', () async {
    SmartImageConfig.configure(
      const SmartImageConfig(allowedDomains: ['allowed.com']),
    );
    final client = MockClient(
      (request) async => http.Response.bytes([9], 200),
    );
    final service = NetworkService(client: client);

    final result = await service.fetch(Uri.parse('https://allowed.com/a.png'));
    expect(result.bytes, [9]);
  });

  test('honours the concurrency cap across queued requests', () async {
    SmartImageConfig.configure(
      const SmartImageConfig(maxConcurrentDownloads: 2),
    );
    var active = 0;
    var maxActive = 0;
    final client = MockClient((request) async {
      active++;
      maxActive = active > maxActive ? active : maxActive;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      active--;
      return http.Response.bytes(utf8.encode(request.url.path), 200);
    });
    final service = NetworkService(client: client);

    await Future.wait([
      for (var i = 0; i < 6; i++)
        service.fetch(Uri.parse('https://x.com/$i.png')),
    ]);
    expect(maxActive, lessThanOrEqualTo(2));
  });

  test('higher priority requests are served first when queued', () async {
    SmartImageConfig.configure(
      const SmartImageConfig(maxConcurrentDownloads: 1),
    );
    final order = <String>[];
    final client = MockClient((request) async {
      order.add(request.url.path);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      return http.Response.bytes([0], 200);
    });
    final service = NetworkService(client: client);

    // Occupy the single slot, then queue low then critical; critical should
    // run before low.
    final first = service.fetch(
      Uri.parse('https://x.com/first'),
      priority: ImagePriority.normal,
    );
    final low = service.fetch(
      Uri.parse('https://x.com/low'),
      priority: ImagePriority.low,
    );
    final critical = service.fetch(
      Uri.parse('https://x.com/critical'),
      priority: ImagePriority.critical,
    );
    await Future.wait([first, low, critical]);

    expect(order.first, '/first');
    expect(order.indexOf('/critical'), lessThan(order.indexOf('/low')));
  });
}
