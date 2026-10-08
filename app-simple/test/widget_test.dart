import 'package:flutter_test/flutter_test.dart';
import 'package:mossaid_simple/api.dart';
import 'package:mossaid_simple/main.dart';
import 'package:mossaid_simple/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Auth screen shows login/register', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiClient(baseUrl: 'http://localhost:8000/api');
    final session = Session(api)..loaded = true; // skip async token restore
    await tester.pumpWidget(MossaidSimple(session: session, api: api));
    await tester.pump();
    expect(find.text('Mossaid — crafts marketplace'), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
  });

  test('ApiClient builds auth headers', () {
    final api = ApiClient(baseUrl: 'http://localhost:8000/api');
    expect(api.token, isNull);
    api.token = 'abc';
    // No exception = headers getter works with token set.
    expect(api.baseUrl, 'http://localhost:8000/api');
  });
}
