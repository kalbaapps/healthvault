import 'models.dart';

/// One question or answer in the chat.
class ChatTurn {
  final bool fromUser;
  final String text;

  const ChatTurn({required this.fromUser, required this.text});

  Map<String, dynamic> toJson() => {
    'role': fromUser ? 'user' : 'assistant',
    'text': text,
  };
}

String _date(SavedReport r) =>
    r.analysis.reportDate ?? r.savedAt.toIso8601String().substring(0, 10);

/// The saved reports in the compact form the server's /ask endpoint expects.
/// Names and personal details are not included, only the test results.
List<Map<String, dynamic>> reportsForAsk(List<SavedReport> reports) => [
  for (final r in reports)
    {
      'date': _date(r),
      'type': r.analysis.reportType,
      'values': [
        for (final v in r.analysis.values)
          {
            'name': v.name,
            'canonicalName': v.canonicalName,
            'valueText': v.valueText,
            'unit': v.unit,
            'referenceLow': v.referenceLow,
            'referenceHigh': v.referenceHigh,
            'flag': v.flag,
          },
      ],
    },
];

/// Demo-mode answer built from the saved reports, so the chat can be tried
/// without the server.
String demoAnswer(List<SavedReport> reports) {
  const prefix =
      'Demo mode: this is not the AI, just a summary of your saved reports.';
  if (reports.isEmpty) {
    return '$prefix\n\nYou have no saved reports yet. Add one and ask again.';
  }
  final latest = reports.first; // newest first
  final outside = latest.analysis.values
      .where((v) => v.flag == 'low' || v.flag == 'high')
      .map((v) => '${v.name} (${v.valueText}, ${v.flag})')
      .toList();
  final count = latest.analysis.values.length;
  return outside.isEmpty
      ? '$prefix\n\nYour latest report (${_date(latest)}) has $count results, all in the usual range.'
      : '$prefix\n\nYour latest report (${_date(latest)}) has $count results. '
            'Outside the usual range: ${outside.join(', ')}.';
}
