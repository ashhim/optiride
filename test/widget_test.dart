import 'package:flutter_test/flutter_test.dart';

import 'package:optiride/main.dart';

void main() {
  testWidgets('OptiRide app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const OptiRideApp());
    expect(find.text('OPTIRIDE'), findsOneWidget);
  });
}
