import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthvault/models.dart';
import 'package:healthvault/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

ReportAnalysis _analysis(String type) => ReportAnalysis(
  isMedicalReport: true,
  reportType: type,
  reportDate: null,
  patientName: null,
  values: const [],
  summary: 'ok',
  urgent: false,
  urgentReason: null,
  questionsForDoctor: const [],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('starts with a default "Me" profile', () async {
    final profiles = await loadProfiles();
    expect(profiles.map((p) => p.name), ['Me']);
    expect((await activeProfile()).id, defaultProfileId);
  });

  test('keeps each profile\'s reports separate', () async {
    await saveReport(_analysis('mine'));

    final mum = await addProfile('Mum');
    await setActiveProfile(mum.id);
    await saveReport(_analysis('mums'));

    expect((await loadReports()).map((r) => r.analysis.reportType), ['mums']);

    await setActiveProfile(defaultProfileId);
    expect((await loadReports()).map((r) => r.analysis.reportType), ['mine']);
  });

  test('deleting a profile removes its reports and emergency card', () async {
    final mum = await addProfile('Mum');
    await setActiveProfile(mum.id);
    await saveReport(_analysis('mums'));
    await saveEmergencyInfo(const EmergencyInfo(bloodType: 'O+'));

    await deleteProfile(mum.id);

    expect((await loadProfiles()).map((p) => p.name), ['Me']);
    expect((await activeProfile()).id, defaultProfileId);
    expect(await loadReports(), isEmpty);
    expect((await loadEmergencyInfo(mum.id)).isEmpty, isTrue);
  });

  test('the last profile cannot be deleted', () async {
    await deleteProfile(defaultProfileId);
    expect((await loadProfiles()).length, 1);
  });

  test(
    'reports saved before profiles existed belong to the default profile',
    () async {
      final legacy = {
        'id': '1',
        'savedAt': DateTime(2026, 9, 1).toIso8601String(),
        'analysis': _analysis('old').toJson(),
      };
      SharedPreferences.setMockInitialValues({
        'saved_reports': [jsonEncode(legacy)],
      });

      final reports = await loadReports();
      expect(reports.single.analysis.reportType, 'old');
      expect(reports.single.profileId, defaultProfileId);
    },
  );

  test('emergency card is stored per profile', () async {
    await saveEmergencyInfo(const EmergencyInfo(allergies: 'penicillin'));
    final mum = await addProfile('Mum');

    expect((await loadEmergencyInfo(defaultProfileId)).allergies, 'penicillin');
    expect((await loadEmergencyInfo(mum.id)).isEmpty, isTrue);
  });

  test('reference range text reads naturally', () {
    LabValue v({num? low, num? high}) => LabValue(
      name: 'x',
      value: 1,
      valueText: '1',
      unit: 'mg/dL',
      referenceLow: low,
      referenceHigh: high,
      flag: 'normal',
      explanation: '',
    );
    expect(v(low: 70, high: 99).referenceText, '70 – 99 mg/dL');
    expect(v(high: 100).referenceText, 'up to 100 mg/dL');
    expect(v(low: 5).referenceText, 'at least 5 mg/dL');
    expect(v().referenceText, '');
  });
}
