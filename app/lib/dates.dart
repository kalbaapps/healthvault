const _monthNames = [
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
];

const _shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

int? _monthNumber(String word) {
  final w = word.toLowerCase().replaceAll('.', '');
  for (var i = 0; i < _monthNames.length; i++) {
    final name = _monthNames[i];
    if (w == name || (w.length >= 3 && name.startsWith(w))) return i + 1;
  }
  return null;
}

/// A real calendar date, or null when the numbers do not form one (31 Feb).
DateTime? _date(int year, int month, int day) {
  final d = DateTime(year, month, day);
  return d.year == year && d.month == month && d.day == day ? d : null;
}

/// Reads the date of a report. The server sends YYYY-MM-DD; reports saved by
/// earlier versions may hold "August 23, 2026" or "23 August 2026". Numeric
/// day/month orders like 03/04/2026 are ambiguous, so they return null and the
/// caller falls back to the day the report was saved.
DateTime? parseReportDate(String? text) {
  if (text == null) return null;
  final s = text.trim();

  var m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:[T ].*)?$').firstMatch(s);
  if (m != null) {
    return _date(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  m = RegExp(r'^([A-Za-z]{3,9})\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})$')
      .firstMatch(s);
  if (m != null) {
    final month = _monthNumber(m[1]!);
    if (month != null) {
      return _date(int.parse(m[3]!), month, int.parse(m[2]!));
    }
  }

  m = RegExp(r'^(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]{3,9})\.?,?\s+(\d{4})$')
      .firstMatch(s);
  if (m != null) {
    final month = _monthNumber(m[2]!);
    if (month != null) {
      return _date(int.parse(m[3]!), month, int.parse(m[1]!));
    }
  }
  return null;
}

/// [date] plus [months], keeping the day where possible (31 Aug + 6 months is
/// the last day of February, not early March).
DateTime addMonths(DateTime date, int months) {
  final index = date.year * 12 + (date.month - 1) + months;
  final year = index ~/ 12;
  final month = index % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, date.day > lastDay ? lastDay : date.day);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole calendar days from [from] to [to]; negative when [to] is earlier.
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// "23 Nov 2026"
String formatDay(DateTime d) =>
    '${d.day} ${_shortMonths[d.month - 1]} ${d.year}';

/// "2026-11-23"
String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
