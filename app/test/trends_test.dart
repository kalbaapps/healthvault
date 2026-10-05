import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:healthvault/models.dart';
import 'package:healthvault/screens/trends_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _report(
  String id,
  String date,
  num ldl, {
  num? high = 100,
  String name = 'LDL cholesterol',
  String? canonical,
}) {
  final flag = (high != null && ldl > high) ? 'high' : 'normal';
  return jsonEncode(
    SavedReport(
      id: id,
      profileId: defaultProfileId,
      savedAt: DateTime.parse(date),
      analysis: ReportAnalysis(
        isMedicalReport: true,
        reportType: 'Lipid profile',
        reportDate: date,
        patientName: null,
        values: [
          LabValue(
            name: name,
            canonicalName: canonical,
            value: ldl,
            valueText: '$ldl',
            unit: 'mg/dL',
            referenceLow: null,
            referenceHigh: high,
            flag: flag,
            explanation: '',
          ),
        ],
        summary: '',
        urgent: false,
        urgentReason: null,
        questionsForDoctor: const [],
      ),
    ).toJson(),
  );
}

Future<void> _show(WidgetTester tester, List<String> reports) async {
  SharedPreferences.setMockInitialValues({'saved_reports': reports});
  await tester.pumpWidget(const MaterialApp(home: TrendsScreen()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('one test is matched across reports in different languages', (
    tester,
  ) async {
    // Same test, printed in English on one report and in Sinhala on the next.
    await _show(tester, [
      _report('1', '2026-08-10', 120, canonical: 'LDL cholesterol'),
      _report(
        '2',
        '2026-09-10',
        148,
        name: 'එල්.ඩී.එල් කොලෙස්ටරෝල්',
        canonical: 'LDL cholesterol',
      ),
    ]);

    expect(find.text('Getting worse'), findsOneWidget);
    expect(find.text('120 mg/dL'), findsOneWidget);
    expect(find.text('148 mg/dL'), findsOneWidget);
  });

  testWidgets('without a canonical name, different names stay separate', (
    tester,
  ) async {
    await _show(tester, [
      _report('1', '2026-08-10', 120),
      _report('2', '2026-09-10', 148, name: 'LDL-C'),
    ]);

    expect(find.textContaining('at least two reports'), findsOneWidget);
  });

  testWidgets('compares the latest month with the previous one', (
    tester,
  ) async {
    await _show(tester, [
      _report('1', '2026-08-10', 120),
      _report('2', '2026-09-10', 148),
    ]);

    expect(find.text('Aug 2026'), findsOneWidget);
    expect(find.text('Sep 2026'), findsOneWidget);
    expect(find.text('120 mg/dL'), findsOneWidget);
    expect(find.text('148 mg/dL'), findsOneWidget);
    expect(find.text('Getting worse'), findsOneWidget);
    expect(find.text('Worth mentioning to your doctor.'), findsOneWidget);
  });

  testWidgets('calls a move toward the usual range an improvement', (
    tester,
  ) async {
    await _show(tester, [
      _report('1', '2026-08-10', 148),
      _report('2', '2026-09-10', 120),
    ]);

    expect(find.text('Improving'), findsOneWidget);
    expect(find.text('Worth mentioning to your doctor.'), findsNothing);
  });

  testWidgets('says "in the usual range" when both values are normal', (
    tester,
  ) async {
    await _show(tester, [
      _report('1', '2026-08-10', 90),
      _report('2', '2026-09-10', 95),
    ]);

    expect(find.text('In the usual range'), findsOneWidget);
  });

  testWidgets('shows a hint when there is only one report', (tester) async {
    await _show(tester, [_report('1', '2026-08-10', 90)]);

    expect(find.textContaining('at least two reports'), findsOneWidget);
  });
}
