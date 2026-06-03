import 'package:flutter_test/flutter_test.dart';
import 'package:smart_image_x_example/main.dart';

void main() {
  testWidgets('app boots with the five demo sections', (tester) async {
    await tester.pumpWidget(const SmartImageXDemo());
    // NavigationBar destination labels.
    expect(find.text('Sources'), findsOneWidget);
    expect(find.text('Features'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Tools'), findsOneWidget);
    expect(find.text('Cache'), findsOneWidget);
  });
}
