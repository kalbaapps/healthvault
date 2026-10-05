import 'package:flutter_test/flutter_test.dart';
import 'package:healthvault/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the empty state when there are no saved reports', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const HealthVaultApp());
    await tester.pumpAndSettle();

    expect(find.text('Understand your medical reports'), findsOneWidget);
    expect(find.text('Add report'), findsOneWidget);
  });
}
