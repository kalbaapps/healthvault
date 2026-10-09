import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const _reportsKey = 'saved_reports';
const _profilesKey = 'profiles';
const _activeProfileKey = 'active_profile';
const _languageKey = 'language';
const _emergencyPrefix = 'emergency_';

const supportedLanguages = [
  'English',
  'සිංහල (Sinhala)',
  'தமிழ் (Tamil)',
  'हिन्दी (Hindi)',
  'Español',
  'Français',
  'العربية (Arabic)',
  'Bahasa Indonesia',
  'Português',
  '中文',
];

Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

// ---- Profiles ----

Future<List<Profile>> loadProfiles() async {
  final prefs = await _prefs;
  final raw = prefs.getStringList(_profilesKey);
  if (raw == null || raw.isEmpty) {
    return const [Profile(id: defaultProfileId, name: 'Me')];
  }
  return raw
      .map((p) => Profile.fromJson(jsonDecode(p) as Map<String, dynamic>))
      .toList();
}

Future<void> _writeProfiles(List<Profile> profiles) async {
  final prefs = await _prefs;
  await prefs.setStringList(
    _profilesKey,
    profiles.map((p) => jsonEncode(p.toJson())).toList(),
  );
}

Future<Profile> activeProfile() async {
  final profiles = await loadProfiles();
  final id = (await _prefs).getString(_activeProfileKey);
  return profiles.firstWhere((p) => p.id == id, orElse: () => profiles.first);
}

Future<void> setActiveProfile(String id) async {
  await (await _prefs).setString(_activeProfileKey, id);
}

Future<Profile> addProfile(String name) async {
  final profiles = await loadProfiles();
  final profile = Profile(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    name: name.trim(),
  );
  await _writeProfiles([...profiles, profile]);
  return profile;
}

Future<void> renameProfile(String id, String name) async {
  final profiles = await loadProfiles();
  await _writeProfiles([
    for (final p in profiles)
      p.id == id ? Profile(id: id, name: name.trim()) : p,
  ]);
}

/// Deletes a profile together with its reports and emergency card.
/// The last remaining profile cannot be deleted.
Future<void> deleteProfile(String id) async {
  final profiles = await loadProfiles();
  if (profiles.length <= 1) return;
  await _writeProfiles(profiles.where((p) => p.id != id).toList());

  final reports = await _loadAll();
  await _writeReports(reports.where((r) => r.profileId != id).toList());
  await (await _prefs).remove('$_emergencyPrefix$id');

  if ((await activeProfile()).id == id) {
    await setActiveProfile((await loadProfiles()).first.id);
  }
}

// ---- Reports ----

Future<List<SavedReport>> _loadAll() async {
  final raw = (await _prefs).getStringList(_reportsKey) ?? [];
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
  return reports;
}

Future<void> _writeReports(List<SavedReport> reports) async {
  await (await _prefs).setStringList(
    _reportsKey,
    reports.map((r) => jsonEncode(r.toJson())).toList(),
  );
}

/// Reports of the active profile, newest first.
Future<List<SavedReport>> loadReports() async {
  final profile = await activeProfile();
  final reports = (await _loadAll())
      .where((r) => r.profileId == profile.id)
      .toList();
  reports.sort((a, b) => b.savedAt.compareTo(a.savedAt));
  return reports;
}

Future<void> saveReport(ReportAnalysis analysis, {String? profileId}) async {
  final reports = await _loadAll();
  final now = DateTime.now();
  reports.add(
    SavedReport(
      id: now.microsecondsSinceEpoch.toString(),
      profileId: profileId ?? (await activeProfile()).id,
      savedAt: now,
      analysis: analysis,
    ),
  );
  await _writeReports(reports);
}

Future<void> deleteReport(String id) async {
  final reports = await _loadAll();
  reports.removeWhere((r) => r.id == id);
  await _writeReports(reports);
}

// ---- Emergency card (per profile) ----

Future<EmergencyInfo> loadEmergencyInfo([String? profileId]) async {
  final id = profileId ?? (await activeProfile()).id;
  final raw = (await _prefs).getString('$_emergencyPrefix$id');
  if (raw == null) return const EmergencyInfo();
  try {
    return EmergencyInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return const EmergencyInfo();
  }
}

Future<void> saveEmergencyInfo(EmergencyInfo info) async {
  final id = (await activeProfile()).id;
  await (await _prefs).setString(
    '$_emergencyPrefix$id',
    jsonEncode(info.toJson()),
  );
}

// ---- Language ----

Future<String> loadLanguage() async =>
    (await _prefs).getString(_languageKey) ?? 'English';

Future<void> saveLanguage(String language) async {
  await (await _prefs).setString(_languageKey, language);
}

// ---- First launch ----

Future<bool> isOnboarded() async =>
    (await _prefs).getBool('onboarded') ?? false;

Future<void> setOnboarded() async {
  await (await _prefs).setBool('onboarded', true);
}

// ---- Ask: consent to send questions and results to the AI ----

Future<bool> hasAskConsent() async =>
    (await _prefs).getBool('ask_consent') ?? false;

Future<void> setAskConsent() async {
  await (await _prefs).setBool('ask_consent', true);
}
