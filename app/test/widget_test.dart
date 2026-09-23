import 'package:flutter_test/flutter_test.dart';
import 'package:mossaid_app/main.dart';

void main() {
  testWidgets('Mossaid Phase0 onboarding renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MossaidApp());
    await tester.pumpAndSettle();

    // l10n onboardingTitle for fr locale (default) is French: "Trouvez des artisans"
    // Check for common elements that exist regardless of locale
    expect(find.textContaining('Mossaid'), findsOneWidget);
    // Phone input screen should show Send OTP button (fr: Envoyer OTP)
    expect(find.textContaining('OTP'), findsOneWidget);
  });
}
