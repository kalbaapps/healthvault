import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthvault/dates.dart';
import 'package:healthvault/models.dart';
import 'package:healthvault/range_bar.dart';
import 'package:healthvault/reminders.dart';
import 'package:healthvault/screens/home_screen.dart';
import 'package:healthvault/screens/result_screen.dart';
import 'package:healthvault/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_reminders.dart';

LabValue _value(String name, num v, String flag) => LabValue(
  name: name,
  value: v,
  valueText: '$v',
  unit: 'mg/dl',
  referenceLow: 50,
  referenceHigh: 200,
  flag: flag,
  explanation: 'About $name.',
);

ReportAnalysis _analysis({int? followUp = 3, String? date}) => ReportAnalysis(
  isMedicalReport: true,
  reportType: 'Lipid profile',
  reportDate: date ?? isoDay(DateTime.now()),
  patientName: null,
  values: [
    _value('Triglycerides', 288.6, 'high'),
    _value('LDL', 120, 'normal'),
  ],
  summary: 'Summary.',
  urgent: false,
  urgentReason: null,
  questionsForDoctor: const [],
  followUpMonths: followUp,
);

late FakeReminders fake;

void _freshPrefs([Map<String, Object> extra = const {}]) {
  SharedPreferences.setMockInitialValues(extra);
  fake = FakeReminders();
  reminders = fake;
}

/// Shows [screen] on top of a home route so Navigator.pop works like in the app.
Future<void> _open(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => screen)),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

String _saved(String id, ReportAnalysis a, DateTime? next) => jsonEncode(
  SavedReport(
    id: id,
    profileId: defaultProfileId,
    savedAt: DateTime.now(),
    analysis: a,
    nextCheckAt: next,
  ).toJson(),
);

void main() {
  final today = dateOnly(DateTime.now());

  group('result screen: check-up card', () {
    testWidgets('a fresh result suggests a date and saves it with a reminder', (
      tester,
    ) async {
      _freshPrefs();
      await _open(tester, ResultScreen(analysis: _analysis()));
      final expected = addMonths(today, 3);

      await tester.scrollUntilVisible(find.text('Next check-up'), 300);
      expect(find.textContaining(formatDay(expected)), findsOneWidget);
      // The heading says it once; the date line must not repeat the words.
      expect(find.textContaining('Next check-up'), findsOneWidget);

      await tester.tap(find.text('Save to my records'));
      await tester.pumpAndSettle();

      final saved = (await loadReports()).single;
      expect(saved.nextCheckAt, expected);
      expect(
        fake.scheduled.single.when,
        DateTime(expected.year, expected.month, expected.day, 9),
      );
      expect(fake.scheduled.single.id, reminderIdFor(saved.id));
    });

    testWidgets('turning the reminder off before saving saves no date', (
      tester,
    ) async {
      _freshPrefs();
      await _open(tester, ResultScreen(analysis: _analysis()));

      await tester.scrollUntilVisible(find.byTooltip('Turn off reminder'), 300);
      await tester.ensureVisible(find.byTooltip('Turn off reminder'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Turn off reminder'));
      await tester.pumpAndSettle();
      expect(find.text('No reminder set'), findsOneWidget);

      await tester.tap(find.text('Save to my records'));
      await tester.pumpAndSettle();

      expect((await loadReports()).single.nextCheckAt, isNull);
      expect(fake.scheduled, isEmpty);
    });

    testWidgets('with no AI suggestion it starts empty and offers to set one', (
      tester,
    ) async {
      _freshPrefs();
      await _open(tester, ResultScreen(analysis: _analysis(followUp: null)));

      await tester.scrollUntilVisible(find.text('Set a date'), 300);
      expect(find.text('No reminder set'), findsOneWidget);
    });

    testWidgets(
      'turning off a saved report clears it and cancels the reminder',
      (tester) async {
        _freshPrefs();
        final next = addMonths(today, 3);
        final a = _analysis();
        _freshPrefs({
          'saved_reports': [_saved('42', a, next)],
        });

        await _open(
          tester,
          ResultScreen(analysis: a, savedId: '42', nextCheckAt: next),
        );
        await tester.scrollUntilVisible(
          find.byTooltip('Turn off reminder'),
          300,
        );
        await tester.ensureVisible(find.byTooltip('Turn off reminder'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Turn off reminder'));
        await tester.pumpAndSettle();

        expect((await loadReports()).single.nextCheckAt, isNull);
        expect(fake.cancelled, contains(reminderIdFor('42')));
      },
    );

    testWidgets(
      'confirming a date on a saved report schedules it and asks permission',
      (tester) async {
        final a = _analysis();
        _freshPrefs({
          'saved_reports': [_saved('42', a, null)],
        });

        await _open(tester, ResultScreen(analysis: a, savedId: '42'));
        await tester.scrollUntilVisible(find.text('Set a date'), 300);
        await tester.tap(find.text('Set a date'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        final saved = (await loadReports()).single;
        expect(saved.nextCheckAt, isNotNull);
        expect(fake.permissionRequests, 1);
        expect(fake.scheduled.single.id, reminderIdFor('42'));
        expect(fake.scheduled.single.when.hour, 9);
      },
    );

    testWidgets('if notifications are refused it explains how to allow them', (
      tester,
    ) async {
      final a = _analysis();
      _freshPrefs({
        'saved_reports': [_saved('42', a, null)],
      });
      fake.permission = false;

      await _open(tester, ResultScreen(analysis: a, savedId: '42'));
      await tester.scrollUntilVisible(find.text('Set a date'), 300);
      await tester.tap(find.text('Set a date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Allow notifications'), findsOneWidget);
    });

    testWidgets('deleting a saved report cancels its reminder', (tester) async {
      final a = _analysis();
      _freshPrefs({
        'saved_reports': [_saved('42', a, addMonths(today, 3))],
      });

      await _open(tester, ResultScreen(analysis: a, savedId: '42'));
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(await loadReports(), isEmpty);
      expect(fake.cancelled, contains(reminderIdFor('42')));
    });
  });

  group('result screen: range bars', () {
    testWidgets('each numeric result gets a bar', (tester) async {
      _freshPrefs();
      await _open(tester, ResultScreen(analysis: _analysis()));
      await tester.scrollUntilVisible(find.text('LDL'), 200);

      expect(find.byType(RangeBar), findsNWidgets(2));
    });
  });

  group('home screen: check-up banner', () {
    Future<void> showHome(WidgetTester tester, DateTime? next) async {
      _freshPrefs({
        'saved_reports': [_saved('1', _analysis(), next)],
      });
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('counts down to an upcoming check-up', (tester) async {
      await showHome(tester, today.add(const Duration(days: 10)));
      expect(find.text('Next check-up in 10 days'), findsOneWidget);
    });

    testWidgets('a far-off date appears once, not twice', (tester) async {
      final far = today.add(const Duration(days: 90));
      await showHome(tester, far);

      expect(find.textContaining(formatDay(far)), findsOneWidget);
      expect(find.text('From your latest report'), findsOneWidget);
    });

    testWidgets('warns when a check-up is overdue', (tester) async {
      await showHome(tester, today.subtract(const Duration(days: 3)));
      expect(find.text('Check-up overdue by 3 days'), findsOneWidget);
    });

    testWidgets('shows nothing when the newest report has no reminder', (
      tester,
    ) async {
      await showHome(tester, null);
      expect(find.textContaining('check-up', findRichText: true), findsNothing);
      expect(find.textContaining('Check-up'), findsNothing);
    });

    testWidgets('tapping the banner opens that report', (tester) async {
      await showHome(tester, today.add(const Duration(days: 10)));
      await tester.tap(find.text('Next check-up in 10 days'));
      await tester.pumpAndSettle();
      expect(find.byType(ResultScreen), findsOneWidget);
    });
  });
}
