import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:smart_image_x/smart_image_x.dart';

Uint8List _testPng({int width = 32, int height = 32}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(120, 80, 200));
  return Uint8List.fromList(img.encodePng(image));
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('Loaders', () {
    testWidgets('circular loader renders a progress indicator', (tester) async {
      await tester.pumpWidget(
        _host(const SmartLoader(type: LoaderType.circular)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('circular loader is determinate when given progress',
        (tester) async {
      await tester.pumpWidget(
        _host(const SmartLoader(type: LoaderType.circular, progress: 0.4)),
      );
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, 0.4);
    });

    testWidgets('shimmer loader builds without error', (tester) async {
      await tester.pumpWidget(
        _host(const SizedBox(width: 80, height: 80, child: ShimmerLoader())),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ShimmerLoader), findsOneWidget);
    });
  });

  group('DefaultErrorWidget', () {
    testWidgets('shows a retry button when onRetry is provided',
        (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 200,
            height: 200,
            child: DefaultErrorWidget(onRetry: () => retried = true),
          ),
        ),
      );
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });
  });

  group('SmartImage rendering', () {
    testWidgets('renders an Image for in-memory bytes', (tester) async {
      await tester.pumpWidget(
        _host(
          SmartImage(
            image: _testPng(),
            transition: TransitionType.none,
            loaderType: LoaderType.skeleton,
            width: 50,
            height: 50,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('fires onLoadSuccess for a resolvable source', (tester) async {
      var succeeded = false;
      await tester.pumpWidget(
        _host(
          SmartImage(
            image: _testPng(),
            transition: TransitionType.none,
            loaderType: LoaderType.skeleton,
            onLoadSuccess: () => succeeded = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(succeeded, isTrue);
    });
  });

  group('SmartImage error handling', () {
    testWidgets('shows the fallback icon for an unrecognised source',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const SmartImage(
            image: 12345, // not a valid source
            fallbackIcon: Icons.person,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('uses a custom errorBuilder', (tester) async {
      await tester.pumpWidget(
        _host(
          SmartImage(
            image: 12345,
            errorBuilder: (_, error) => Text('ERR:${error.type.name}'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ERR:invalidSource'), findsOneWidget);
    });

    testWidgets('fires onLoadError for an unrecognised source', (tester) async {
      SmartImageException? captured;
      await tester.pumpWidget(
        _host(
          SmartImage(
            image: 12345,
            onLoadError: (e) => captured = e,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(captured, isNotNull);
      expect(captured!.type, SmartImageErrorType.invalidSource);
    });
  });

  group('SmartImage shape', () {
    testWidgets('clips to a circle when shape is circle', (tester) async {
      await tester.pumpWidget(
        _host(
          SmartImage(
            image: _testPng(),
            shape: BoxShape.circle,
            width: 40,
            height: 40,
          ),
        ),
      );
      expect(find.byType(ClipOval), findsOneWidget);
    });

    testWidgets('applies a border radius for rounded rectangles',
        (tester) async {
      await tester.pumpWidget(
        _host(
          SmartImage(
            image: _testPng(),
            borderRadius: BorderRadius.circular(12),
            width: 40,
            height: 40,
          ),
        ),
      );
      expect(find.byType(ClipRRect), findsOneWidget);
    });
  });

  group('SmartImage accessibility', () {
    testWidgets('exposes a semantic label', (tester) async {
      await tester.pumpWidget(
        _host(
          SmartImage(
            image: _testPng(),
            semanticLabel: 'Profile photo',
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Profile photo'),
        findsOneWidget,
      );
    });
  });
}
