import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthvault/models.dart';
import 'package:healthvault/pdf_brief.dart';

LabValue _value(int i, {String name = 'Triglycerides', String flag = 'high'}) =>
    LabValue(
      name: '$name $i',
      value: 288.6,
      valueText: '288.6',
      unit: 'mg/dl',
      referenceLow: 50,
      referenceHigh: 200,
      flag: flag,
      explanation: '',
    );

ReportAnalysis _report({
  List<LabValue>? values,
  String summary = 'Your triglycerides are high.',
  bool urgent = false,
}) => ReportAnalysis(
  isMedicalReport: true,
  reportType: 'Lipid profile',
  reportDate: '2026-08-23',
  patientName: null,
  values: values ?? [_value(1)],
  summary: summary,
  urgent: urgent,
  urgentReason: urgent ? 'Please see a doctor today.' : null,
  questionsForDoctor: const ['Should I repeat the test?'],
  foodSuggestions: const ['Eat more oats and beans.'],
  exerciseSuggestions: const ['Walk for 30 minutes.'],
);

bool _isPng(List<int> bytes) =>
    bytes.length > 8 &&
    bytes[0] == 0x89 &&
    latin1.decode(bytes.sublist(1, 4)) == 'PNG';

void main() {
  testWidgets('a normal report fits on one page and is a real PNG', (
    tester,
  ) async {
    final pages = await tester.runAsync(
      () => renderBriefPages(_report(), 'Nipuna'),
    );

    expect(pages, hasLength(1));
    expect(_isPng(pages!.single), isTrue);
  });

  testWidgets('a long report continues onto more pages', (tester) async {
    final values = [for (var i = 0; i < 80; i++) _value(i)];
    final pages = await tester.runAsync(
      () => renderBriefPages(_report(values: values), 'Nipuna'),
    );

    expect(pages!.length, greaterThan(1));
    expect(pages.every(_isPng), isTrue);
  });

  testWidgets('Sinhala, Tamil, Hindi and Arabic text does not break it', (
    tester,
  ) async {
    const text =
        'ඔබේ ට්‍රයිග්ලිසරයිඩ් අගය ඉහළයි. உங்கள் அளவு அதிகம். आपका स्तर ऊंचा है. مستوى الدهون مرتفع.';
    final pages = await tester.runAsync(
      () => renderBriefPages(
        _report(
          summary: text,
          values: [_value(1, name: 'Triglycerides (ට්‍රයිග්ලිසරයිඩ්)')],
        ),
        'Nipuna',
      ),
    );

    expect(pages, isNotEmpty);
  });

  testWidgets('an urgent report and an empty result list still render', (
    tester,
  ) async {
    final pages = await tester.runAsync(
      () => renderBriefPages(_report(urgent: true, values: []), 'Nipuna'),
    );

    expect(pages, hasLength(1));
  });

  testWidgets('the PDF is valid and holds one page image per page', (
    tester,
  ) async {
    final values = [for (var i = 0; i < 80; i++) _value(i)];
    final report = _report(values: values);

    final result = await tester.runAsync(() async {
      final pdf = await buildBriefPdf(report, 'Nipuna');
      final pages = await renderBriefPages(report, 'Nipuna');
      return (pdf, pages.length);
    });

    final (pdf, pageCount) = result!;
    expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
    // Each page of the PDF is declared as a "/Type/Page" object.
    final declared = RegExp(r'/Type\s*/Page(?![a-zA-Z])')
        .allMatches(latin1.decode(pdf));
    expect(declared.length, pageCount);
    expect(pageCount, greaterThan(1));
  });
}
