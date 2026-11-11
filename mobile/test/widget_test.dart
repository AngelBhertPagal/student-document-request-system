import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const StudentDocumentApp());
    expect(find.text('Student Document Portal'), findsOneWidget);
  });
}
