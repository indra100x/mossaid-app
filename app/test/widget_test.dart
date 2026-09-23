import 'package:flutter_test/flutter_test.dart';
import 'package:mossaid_app/main.dart';

void main() {
  testWidgets('Mossaid skeleton renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MossaidApp());

    expect(find.text('Mossaid'), findsOneWidget);
    expect(find.text('Mossaid — Marketplace Skeleton'), findsOneWidget);
  });
}
