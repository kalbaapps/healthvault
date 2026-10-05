import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const _key = 'saved_reports';

Future<List<SavedReport>> loadReports() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getStringList(_key) ?? [];
  final reports = <SavedReport>[];
  for (final item in raw) {
    try {
      reports.add(
        SavedReport.fromJson(jsonDecode(item) as Map<String, dynamic>),
      );
    } catch (_) {
      // Skip an entry that can no longer be read rather than losing the whole list.
    }
  }
  reports.sort((a, b) => b.savedAt.compareTo(a.savedAt));
  return reports;
}

Future<void> _write(List<SavedReport> reports) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(
    _key,
    reports.map((r) => jsonEncode(r.toJson())).toList(),
  );
}

Future<void> saveReport(ReportAnalysis analysis) async {
  final reports = await loadReports();
  final now = DateTime.now();
  reports.add(
    SavedReport(
      id: now.microsecondsSinceEpoch.toString(),
      savedAt: now,
      analysis: analysis,
    ),
  );
  await _write(reports);
}

Future<void> deleteReport(String id) async {
  final reports = await loadReports();
  reports.removeWhere((r) => r.id == id);
  await _write(reports);
}
