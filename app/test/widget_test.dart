import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthvault/main.dart';
import 'package:healthvault/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the empty state when there are no saved reports', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    await tester.pumpWidget(const HealthVaultApp());
    await tester.pumpAndSettle();

    expect(find.text('Understand your medical reports'), findsOneWidget);
    expect(find.text('Add report'), findsOneWidget);
  });

  testWidgets('first launch asks for a name and language, then opens home', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const HealthVaultApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome to HealthVault'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Nipuna');
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Add report'), findsOneWidget);
    expect((await activeProfile()).name, 'Nipuna');
    expect(await isOnboarded(), isTrue);
    expect(await loadLanguage(), supportedLanguages.first);
  });
}
