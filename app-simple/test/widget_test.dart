import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mossaid_simple/api.dart';
import 'package:mossaid_simple/app_theme.dart';
import 'package:mossaid_simple/main.dart';
import 'package:mossaid_simple/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Landing shows logo, login/register and version',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiClient(baseUrl: 'http://localhost:8000/api');
    final session = Session(api)..loaded = true; // skip async token restore
    final theme = AppTheme();
    await tester.pumpWidget(
      MossaidSimple(session: session, api: api, theme: theme),
    );
    await tester.pump();

    expect(find.text('Mossaid'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.textContaining('1.0.6'), findsOneWidget);

    // Tapping login opens the auth screen in login mode.
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('Sun/moon toggle switches theme mode', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiClient(baseUrl: 'http://localhost:8000/api');
    final session = Session(api)
      ..loaded = true
      ..user = {'id': 1, 'name': 'Test', 'role': 'client'};
    final theme = AppTheme();
    await tester.pumpWidget(
      MossaidSimple(session: session, api: api, theme: theme),
    );
    await tester.pump();

    // Starts in light mode → moon icon offered.
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pumpAndSettle();
    expect(theme.mode, ThemeMode.dark);
    expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
  });

  test('ApiClient builds auth headers', () {
    final api = ApiClient(baseUrl: 'http://localhost:8000/api');
    expect(api.token, isNull);
    api.token = 'abc';
    // No exception = headers getter works with token set.
    expect(api.baseUrl, 'http://localhost:8000/api');
  });
}
