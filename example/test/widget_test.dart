import 'package:flutter_test/flutter_test.dart';
import 'package:smart_image_x_example/main.dart';

void main() {
  testWidgets('example app boots with its four demo tabs', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('SmartImageX'), findsOneWidget);
    expect(find.text('Basics'), findsOneWidget);
    expect(find.text('Gallery & Zoom'), findsOneWidget);
  });
}
