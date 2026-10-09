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

/// Removes every reminder of a saved report.
Future<void> cancelCheckupReminders(String reportId) async {
  for (final lead in reminderLeadDays) {
    await reminders.cancel(reminderIdFor(reportId, daysBefore: lead));
  }
}

/// Sets the phone reminders for [date]: 2 days before, 1 day before and on the
/// day, each at 9am. Reminders whose time has already passed are skipped, and
/// any earlier reminders of this report are replaced. A null [date] just
/// removes them. [now] exists for tests.
Future<void> scheduleCheckup({
  required String reportId,
  required ReportAnalysis analysis,
  required DateTime? date,
  DateTime? now,
}) async {
  await cancelCheckupReminders(reportId);
  if (date == null) return;

  final current = now ?? DateTime.now();
  final type = analysis.reportType;
  for (final lead in reminderLeadDays) {
    final when = reminderTime(DateTime(date.year, date.month, date.day - lead));
    if (!when.isAfter(current)) continue;

    final (title, body) = switch (lead) {
      2 => (
        'Check-up in 2 days',
        '$type: your check-up is on ${formatDay(date)}. Ask your doctor what is right for you.',
      ),
      1 => (
        'Check-up tomorrow',
        '$type: your check-up is tomorrow, ${formatDay(date)}. Ask your doctor what is right for you.',
      ),
      _ => (
        'Time for your next check-up',
        '$type: your last report suggested repeating these tests. Ask your doctor what is right for you.',
      ),
    };
    await reminders.schedule(
      id: reminderIdFor(reportId, daysBefore: lead),
      when: when,
      title: title,
      body: body,
    );
  }
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
