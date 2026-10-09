import 'dates.dart';
import 'models.dart';
import 'reminders.dart';
import 'storage.dart';

/// When to suggest the next check-up: the report's own date plus the AI's
/// suggested number of months, or null if it gave no suggestion.
DateTime? defaultNextCheck(ReportAnalysis analysis, DateTime savedAt) {
  final months = analysis.followUpMonths;
  if (months == null) return null;
  final base = parseReportDate(analysis.reportDate) ?? dateOnly(savedAt);
  return addMonths(base, months);
}

enum CheckupUrgency { later, soon, today, overdue }

class CheckupStatus {
  /// A full sentence, for the home screen banner.
  final String text;
  final CheckupUrgency urgency;

  /// Just the timing ("in 10 days"), for places that already say what it is.
  /// Empty when the date is more than a month away.
  final String short;

  const CheckupStatus(this.text, this.urgency, [this.short = '']);
}

/// How to describe a check-up date relative to [today].
CheckupStatus checkupStatus(DateTime next, DateTime today) {
  final days = daysBetween(today, next);
  if (days < 0) {
    final late = -days;
    return CheckupStatus(
      'Check-up overdue by $late ${late == 1 ? 'day' : 'days'}',
      CheckupUrgency.overdue,
      'overdue by $late ${late == 1 ? 'day' : 'days'}',
    );
  }
  if (days == 0) {
    return const CheckupStatus(
      'Check-up due today',
      CheckupUrgency.today,
      'today',
    );
  }
  if (days <= 30) {
    return CheckupStatus(
      'Next check-up in $days ${days == 1 ? 'day' : 'days'}',
      CheckupUrgency.soon,
      'in $days ${days == 1 ? 'day' : 'days'}',
    );
  }
  return CheckupStatus(
    'Next check-up: ${formatDay(next)}',
    CheckupUrgency.later,
  );
}

/// Puts a reminder on the phone for [date], or removes it when [date] is null.
Future<void> scheduleCheckup({
  required String reportId,
  required ReportAnalysis analysis,
  required DateTime? date,
}) async {
  final id = reminderIdFor(reportId);
  if (date == null) {
    await reminders.cancel(id);
    return;
  }
  await reminders.schedule(
    id: id,
    when: reminderTime(date),
    title: 'Time for your next check-up',
    body:
        '${analysis.reportType}: your last report suggested repeating these tests. Ask your doctor what is right for you.',
  );
}

/// Saves a report and sets up its check-up reminder. With [suggest] the AI's
/// suggested date is used when [nextCheckAt] is not given; without it a null
/// [nextCheckAt] means the user chose no reminder.
Future<SavedReport> saveReportWithCheckup(
  ReportAnalysis analysis, {
  String? profileId,
  DateTime? nextCheckAt,
  bool suggest = true,
}) async {
  final next =
      nextCheckAt ??
      (suggest ? defaultNextCheck(analysis, DateTime.now()) : null);
  final saved = await saveReport(
    analysis,
    profileId: profileId,
    nextCheckAt: next,
  );
  await scheduleCheckup(reportId: saved.id, analysis: analysis, date: next);
  return saved;
}
