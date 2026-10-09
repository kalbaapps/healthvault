import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthvault/ask_context.dart';
import 'package:healthvault/models.dart';
import 'package:healthvault/screens/ask_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

SavedReport _saved(String id, String date, {String? patient = 'Secret Name'}) =>
    SavedReport(
      id: id,
      profileId: defaultProfileId,
      savedAt: DateTime.parse('$date 12:00:00'),
      analysis: ReportAnalysis(
        isMedicalReport: true,
        reportType: 'Lipid profile',
        reportDate: date,
        patientName: patient,
        values: const [
          LabValue(
            name: 'LDL - Cholesterol',
            canonicalName: 'LDL cholesterol',
            value: 148,
            valueText: '148',
            unit: 'mg/dL',
            referenceLow: null,
            referenceHigh: 100,
            flag: 'high',
            explanation: 'long explanation that must not be sent',
          ),
        ],
        summary: 'summary text that must not be sent',
        urgent: false,
        urgentReason: null,
        questionsForDoctor: const [],
      ),
    );

/// The demo answer arrives after a short timer, which pumpAndSettle alone
/// does not wait for.
Future<void> _answered(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  group('reportsForAsk', () {
    test('sends results only, never names or explanations', () {
      final json = jsonEncode(reportsForAsk([_saved('1', '2026-09-23')]));

      expect(json, contains('LDL cholesterol'));
      expect(json, contains('"valueText":"148"'));
      expect(json, contains('"referenceHigh":100'));
      expect(json, isNot(contains('Secret Name')));
      expect(json, isNot(contains('must not be sent')));
    });

    test('uses the save date when a report has no printed date', () {
      final report = SavedReport(
        id: '1',
        profileId: defaultProfileId,
        savedAt: DateTime.parse('2026-07-04 09:00:00'),
        analysis: ReportAnalysis(
          isMedicalReport: true,
          reportType: 'x',
          reportDate: null,
          patientName: null,
          values: const [],
          summary: '',
          urgent: false,
          urgentReason: null,
          questionsForDoctor: const [],
        ),
      );
      expect(reportsForAsk([report]).single['date'], '2026-07-04');
    });
  });

  group('demoAnswer', () {
    test('names the results outside the range in the newest report', () {
      final text = demoAnswer([
        _saved('2', '2026-09-23'),
        _saved('1', '2026-08-23'),
      ]);
      expect(text, contains('2026-09-23'));
      expect(text, contains('LDL - Cholesterol (148, high)'));
    });

    test('asks for a report when there are none', () {
      expect(demoAnswer(const []), contains('no saved reports'));
    });
  });

  group('AskScreen', () {
    Future<void> open(WidgetTester tester, {bool consented = true}) async {
      SharedPreferences.setMockInitialValues({
        'saved_reports': [jsonEncode(_saved('1', '2026-09-23').toJson())],
        if (consented) 'ask_consent': true,
      });
      await tester.pumpWidget(const MaterialApp(home: AskScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('shows suggestions, and tapping one gets an answer', (
      tester,
    ) async {
      await open(tester);

      expect(find.text('How have my results changed?'), findsOneWidget);
      await tester.tap(find.text('How have my results changed?'));
      await _answered(tester);

      expect(
        find.text('How have my results changed?'),
        findsOneWidget,
      ); // the question bubble
      expect(
        find.textContaining('LDL - Cholesterol (148, high)'),
        findsOneWidget,
      );
    });

    testWidgets('typing a question and sending it shows both bubbles', (
      tester,
    ) async {
      await open(tester);

      await tester.enterText(find.byType(TextField), 'Is my LDL ok?');
      await tester.tap(find.byTooltip('Send'));
      await _answered(tester);

      expect(find.text('Is my LDL ok?'), findsOneWidget);
      expect(find.textContaining('Demo mode'), findsOneWidget);
    });

    testWidgets('first use asks for consent before anything is sent', (
      tester,
    ) async {
      await open(tester, consented: false);

      expect(find.text('Before you ask'), findsOneWidget);
      await tester.tap(find.text('I agree'));
      await tester.pumpAndSettle();

      expect(find.text('Before you ask'), findsNothing);
      expect(find.text('How have my results changed?'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('ask_consent'), isTrue);
    });

    testWidgets('declining consent leaves the screen without saving consent', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AskScreen()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.byType(AskScreen), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getBool('ask_consent'),
        isNull,
      );
    });

    testWidgets('with no saved reports it asks you to save one first', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'ask_consent': true});
      await tester.pumpWidget(const MaterialApp(home: AskScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Save a report first'), findsOneWidget);
    });
  });
}
