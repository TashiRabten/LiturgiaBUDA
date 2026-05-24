import 'package:flutter_test/flutter_test.dart';
import 'package:liturgiabuda/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LiturgiaBudaApp());
    expect(find.byType(LiturgiaBudaApp), findsOneWidget);
  });
}