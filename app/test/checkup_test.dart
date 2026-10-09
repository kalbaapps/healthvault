import 'package:flutter_test/flutter_test.dart';
import 'package:healthvault/checkup.dart';
import 'package:healthvault/dates.dart';
import 'package:healthvault/models.dart';
import 'package:healthvault/reminders.dart';
import 'package:healthvault/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_reminders.dart';

ReportAnalysis _analysis({String? date = '2026-08-23', int? followUp = 3}) =>
    ReportAnalysis(
      isMedicalReport: true,
      reportType: 'Lipid profile',
      reportDate: date,
      patientName: null,
      values: const [],
      summary: '',
      urgent: false,
      urgentReason: null,
      questionsForDoctor: const [],
      followUpMonths: followUp,
    );

void main() {
  group('dates', () {
    test('reads ISO dates', () {
      expect(parseReportDate('2026-08-23'), DateTime(2026, 8, 23));
      expect(parseReportDate('2026-8-3'), DateTime(2026, 8, 3));
      expect(parseReportDate('2026-08-23T10:15:00Z'), DateTime(2026, 8, 23));
    });

    test('reads dates written with a month name (older saved reports)', () {
      expect(parseReportDate('August 23, 2026'), DateTime(2026, 8, 23));
      expect(parseReportDate('aug 3 2026'), DateTime(2026, 8, 3));
      expect(parseReportDate('23 August 2026'), DateTime(2026, 8, 23));
      expect(parseReportDate('1st March 2026'), DateTime(2026, 3, 1));
    });

    test('does not guess ambiguous or impossible dates', () {
      expect(parseReportDate('03/04/2026'), isNull);
      expect(parseReportDate('23-08-2026'), isNull);
      expect(parseReportDate('February 31, 2026'), isNull);
      expect(parseReportDate('whenever'), isNull);
      expect(parseReportDate(null), isNull);
    });

    test('adding months keeps the day or uses the month end', () {
      expect(addMonths(DateTime(2026, 8, 23), 3), DateTime(2026, 11, 23));
      expect(addMonths(DateTime(2026, 8, 31), 6), DateTime(2027, 2, 28));
      expect(addMonths(DateTime(2028, 8, 31), 6), DateTime(2029, 2, 28));
      expect(addMonths(DateTime(2027, 8, 31), 6), DateTime(2028, 2, 29));
      expect(addMonths(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    });

    test('counts whole calendar days', () {
      expect(daysBetween(DateTime(2026, 10, 9), DateTime(2026, 10, 19)), 10);
      expect(daysBetween(DateTime(2026, 10, 9), DateTime(2026, 10, 9)), 0);
      expect(daysBetween(DateTime(2026, 10, 9), DateTime(2026, 10, 8)), -1);
      expect(
        daysBetween(
          DateTime(2026, 10, 9, 23, 59),
          DateTime(2026, 10, 10, 0, 1),
        ),
        1,
      );
    });

    test('formats days', () {
      expect(formatDay(DateTime(2026, 11, 3)), '3 Nov 2026');
      expect(isoDay(DateTime(2026, 11, 3)), '2026-11-03');
    });
  });

  group('suggested check-up date', () {
    test('is the report date plus the suggested months', () {
      expect(
        defaultNextCheck(_analysis(), DateTime(2026, 10, 9)),
        DateTime(2026, 11, 23),
      );
    });

    test('falls back to the day it was saved when the date is unreadable', () {
      expect(
        defaultNextCheck(
          _analysis(date: '03/04/2026'),
          DateTime(2026, 10, 9, 14),
        ),
        DateTime(2027, 1, 9),
      );
      expect(
        defaultNextCheck(_analysis(date: null), DateTime(2026, 10, 9)),
        DateTime(2027, 1, 9),
      );
    });

    test('is null when the AI made no suggestion', () {
      expect(
        defaultNextCheck(_analysis(followUp: null), DateTime(2026, 10, 9)),
        isNull,
      );
    });
  });

  group('status wording', () {
    final today = DateTime(2026, 10, 9);

    test('overdue, singular and plural', () {
      expect(
        checkupStatus(DateTime(2026, 10, 8), today).text,
        'Check-up overdue by 1 day',
      );
      expect(
        checkupStatus(DateTime(2026, 10, 1), today).text,
        'Check-up overdue by 8 days',
      );
      expect(
        checkupStatus(DateTime(2026, 10, 1), today).urgency,
        CheckupUrgency.overdue,
      );
      expect(
        checkupStatus(DateTime(2026, 10, 8), today).short,
        'overdue by 1 day',
      );
      expect(
        checkupStatus(DateTime(2026, 10, 1), today).short,
        'overdue by 8 days',
      );
    });

    test('due today', () {
      final s = checkupStatus(today, today);
      expect(s.text, 'Check-up due today');
      expect(s.urgency, CheckupUrgency.today);
      expect(s.short, 'today');
    });

    test('within 30 days it counts down', () {
      expect(
        checkupStatus(DateTime(2026, 10, 10), today).text,
        'Next check-up in 1 day',
      );
      expect(
        checkupStatus(DateTime(2026, 11, 8), today).text,
        'Next check-up in 30 days',
      );
      expect(
        checkupStatus(DateTime(2026, 11, 8), today).urgency,
        CheckupUrgency.soon,
      );
      expect(checkupStatus(DateTime(2026, 10, 10), today).short, 'in 1 day');
      expect(checkupStatus(DateTime(2026, 11, 8), today).short, 'in 30 days');
    });

    test('further away it shows the date', () {
      final s = checkupStatus(DateTime(2026, 11, 9), today);
      expect(s.text, 'Next check-up: 9 Nov 2026');
      expect(s.urgency, CheckupUrgency.later);
      expect(s.short, isEmpty, reason: 'the card shows the date instead');
    });
  });

  group('reminders for a check-up', () {
    late FakeReminders fake;
    final today = dateOnly(DateTime.now());

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fake = FakeReminders();
      reminders = fake;
    });

    ReportAnalysis dated(DateTime day, {int? followUp = 3}) =>
        _analysis(date: isoDay(day), followUp: followUp);

    test(
      'three alerts: 2 days before, 1 day before and on the day at 9am',
      () async {
        final saved = await saveReportWithCheckup(dated(today));
        final day = addMonths(today, 3);

        expect(saved.nextCheckAt, day);
        expect(fake.scheduled.map((r) => r.when).toList(), [
          DateTime(day.year, day.month, day.day - 2, 9),
          DateTime(day.year, day.month, day.day - 1, 9),
          DateTime(day.year, day.month, day.day, 9),
        ]);
        expect(fake.scheduled.map((r) => r.title).toList(), [
          'Check-up in 2 days',
          'Check-up tomorrow',
          'Time for your next check-up',
        ]);
        expect(
          fake.scheduled.every((r) => r.body.contains('Lipid profile')),
          isTrue,
        );
        expect((await loadReports()).single.nextCheckAt, day);
      },
    );

    test('each alert has its own id, different from other reports', () {
      final a = [
        for (final d in reminderLeadDays) reminderIdFor('111', daysBefore: d),
      ];
      final b = [
        for (final d in reminderLeadDays) reminderIdFor('222', daysBefore: d),
      ];

      expect({...a, ...b}, hasLength(6));
      for (final id in [...a, ...b]) {
        expect(id, inInclusiveRange(0, 0x7fffffff));
      }
      expect(reminderIdFor('111'), reminderIdFor('111', daysBefore: 0));
    });

    test('a date the user picked wins over the suggestion', () async {
      final picked = today.add(const Duration(days: 60));
      final saved = await saveReportWithCheckup(
        dated(today),
        nextCheckAt: picked,
      );

      expect(saved.nextCheckAt, picked);
      expect(
        fake.scheduled.last.when,
        DateTime(picked.year, picked.month, picked.day, 9),
      );
    });

    test('with suggestions off, no date means no reminders at all', () async {
      final saved = await saveReportWithCheckup(dated(today), suggest: false);

      expect(saved.nextCheckAt, isNull);
      expect(fake.scheduled, isEmpty);
      expect(fake.cancelled.toSet(), {
        for (final d in reminderLeadDays)
          reminderIdFor(saved.id, daysBefore: d),
      });
    });

    test('no AI suggestion means no reminder', () async {
      final saved = await saveReportWithCheckup(dated(today, followUp: null));
      expect(saved.nextCheckAt, isNull);
      expect(fake.scheduled, isEmpty);
    });

    test('alerts that are already in the past are skipped', () async {
      final day = DateTime(2026, 10, 20);
      // Two days before has passed, one day before is still ahead.
      await scheduleCheckup(
        reportId: '5',
        analysis: _analysis(),
        date: day,
        now: DateTime(2026, 10, 18, 10),
      );
      expect(fake.scheduled.map((r) => r.when).toList(), [
        DateTime(2026, 10, 19, 9),
        DateTime(2026, 10, 20, 9),
      ]);

      fake.scheduled.clear();
      // Morning of the check-up before 9am: only the on-the-day alert is left.
      await scheduleCheckup(
        reportId: '5',
        analysis: _analysis(),
        date: day,
        now: DateTime(2026, 10, 20, 8),
      );
      expect(fake.scheduled.map((r) => r.when).toList(), [
        DateTime(2026, 10, 20, 9),
      ]);

      fake.scheduled.clear();
      // After 9am on the day nothing is left to schedule.
      await scheduleCheckup(
        reportId: '5',
        analysis: _analysis(),
        date: day,
        now: DateTime(2026, 10, 20, 9, 30),
      );
      expect(fake.scheduled, isEmpty);
    });

    test('a date in the past schedules nothing', () async {
      await saveReportWithCheckup(_analysis(date: '2020-01-01', followUp: 1));
      expect(fake.scheduled, isEmpty);
    });

    test('changing the date replaces the earlier alerts', () async {
      final saved = await saveReport(
        _analysis(),
        nextCheckAt: today.add(const Duration(days: 40)),
      );
      final ids = {
        for (final d in reminderLeadDays)
          reminderIdFor(saved.id, daysBefore: d),
      };

      await scheduleCheckup(
        reportId: saved.id,
        analysis: _analysis(),
        date: today.add(const Duration(days: 90)),
      );

      // All three old ids are cleared first, then the new ones are set.
      expect(fake.cancelled.toSet(), ids);
      expect(fake.scheduled.map((r) => r.id).toSet(), ids);
    });

    test('the date can be changed and cleared later', () async {
      final saved = await saveReport(
        _analysis(),
        nextCheckAt: DateTime(2026, 11, 23),
      );

      await setNextCheck(saved.id, DateTime(2026, 12, 1));
      expect((await loadReports()).single.nextCheckAt, DateTime(2026, 12, 1));

      await setNextCheck(saved.id, null);
      expect((await loadReports()).single.nextCheckAt, isNull);
    });

    test('changing one report leaves the others alone', () async {
      final a = await saveReport(
        _analysis(),
        nextCheckAt: DateTime(2026, 11, 23),
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final b = await saveReport(
        _analysis(),
        nextCheckAt: DateTime(2027, 2, 2),
      );

      await setNextCheck(a.id, null);

      final byId = {for (final r in await loadReports()) r.id: r.nextCheckAt};
      expect(byId[a.id], isNull);
      expect(byId[b.id], DateTime(2027, 2, 2));
    });

    test('cancelling removes all three alerts', () async {
      await cancelCheckupReminders('9');
      expect(fake.cancelled.toSet(), {
        for (final d in reminderLeadDays) reminderIdFor('9', daysBefore: d),
      });
    });
  });
}
