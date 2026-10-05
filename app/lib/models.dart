class LabValue {
  final String name;
  final num? value;
  final String valueText;
  final String? unit;
  final num? referenceLow;
  final num? referenceHigh;
  final String flag; // low | normal | high | unknown
  final String explanation;

  const LabValue({
    required this.name,
    required this.value,
    required this.valueText,
    required this.unit,
    required this.referenceLow,
    required this.referenceHigh,
    required this.flag,
    required this.explanation,
  });

  factory LabValue.fromJson(Map<String, dynamic> j) => LabValue(
    name: j['name'] as String,
    value: j['value'] as num?,
    valueText: j['valueText'] as String,
    unit: j['unit'] as String?,
    referenceLow: j['referenceLow'] as num?,
    referenceHigh: j['referenceHigh'] as num?,
    flag: j['flag'] as String,
    explanation: j['explanation'] as String,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'value': value,
    'valueText': valueText,
    'unit': unit,
    'referenceLow': referenceLow,
    'referenceHigh': referenceHigh,
    'flag': flag,
    'explanation': explanation,
  };

  String get referenceText {
    final unitSuffix = unit == null ? '' : ' $unit';
    final low = referenceLow;
    final high = referenceHigh;
    if (low != null && high != null) return '$low – $high$unitSuffix';
    if (high != null) return 'up to $high$unitSuffix';
    if (low != null) return 'at least $low$unitSuffix';
    return '';
  }
}

class ReportAnalysis {
  final bool isMedicalReport;
  final String reportType;
  final String? reportDate;
  final String? patientName;
  final List<LabValue> values;
  final String summary;
  final bool urgent;
  final String? urgentReason;
  final List<String> questionsForDoctor;
  final List<String> foodSuggestions;
  final List<String> exerciseSuggestions;
  final bool seeDoctor;
  final String? seeDoctorReason;

  const ReportAnalysis({
    required this.isMedicalReport,
    required this.reportType,
    required this.reportDate,
    required this.patientName,
    required this.values,
    required this.summary,
    required this.urgent,
    required this.urgentReason,
    required this.questionsForDoctor,
    this.foodSuggestions = const [],
    this.exerciseSuggestions = const [],
    this.seeDoctor = false,
    this.seeDoctorReason,
  });

  static List<String> _strings(Object? v) =>
      v is List ? v.map((e) => e as String).toList() : const [];

  factory ReportAnalysis.fromJson(Map<String, dynamic> j) => ReportAnalysis(
    isMedicalReport: j['isMedicalReport'] as bool,
    reportType: j['reportType'] as String,
    reportDate: j['reportDate'] as String?,
    patientName: j['patientName'] as String?,
    values: (j['values'] as List)
        .map((v) => LabValue.fromJson(v as Map<String, dynamic>))
        .toList(),
    summary: j['summary'] as String,
    urgent: j['urgent'] as bool,
    urgentReason: j['urgentReason'] as String?,
    questionsForDoctor: _strings(j['questionsForDoctor']),
    // Reports saved by earlier versions have none of these fields.
    foodSuggestions: _strings(j['foodSuggestions']),
    exerciseSuggestions: _strings(j['exerciseSuggestions']),
    seeDoctor: j['seeDoctor'] as bool? ?? false,
    seeDoctorReason: j['seeDoctorReason'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'isMedicalReport': isMedicalReport,
    'reportType': reportType,
    'reportDate': reportDate,
    'patientName': patientName,
    'values': values.map((v) => v.toJson()).toList(),
    'summary': summary,
    'urgent': urgent,
    'urgentReason': urgentReason,
    'questionsForDoctor': questionsForDoctor,
    'foodSuggestions': foodSuggestions,
    'exerciseSuggestions': exerciseSuggestions,
    'seeDoctor': seeDoctor,
    'seeDoctorReason': seeDoctorReason,
  };
}

/// A person whose reports are kept together (you, a parent, a child...).
class Profile {
  final String id;
  final String name;

  const Profile({required this.id, required this.name});

  factory Profile.fromJson(Map<String, dynamic> j) =>
      Profile(id: j['id'] as String, name: j['name'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

/// Basic facts a first responder needs. Stored on this device only.
class EmergencyInfo {
  final String bloodType;
  final String allergies;
  final String conditions;
  final String medications;
  final String contactName;
  final String contactPhone;

  const EmergencyInfo({
    this.bloodType = '',
    this.allergies = '',
    this.conditions = '',
    this.medications = '',
    this.contactName = '',
    this.contactPhone = '',
  });

  bool get isEmpty =>
      bloodType.isEmpty &&
      allergies.isEmpty &&
      conditions.isEmpty &&
      medications.isEmpty &&
      contactName.isEmpty &&
      contactPhone.isEmpty;

  factory EmergencyInfo.fromJson(Map<String, dynamic> j) => EmergencyInfo(
    bloodType: j['bloodType'] as String? ?? '',
    allergies: j['allergies'] as String? ?? '',
    conditions: j['conditions'] as String? ?? '',
    medications: j['medications'] as String? ?? '',
    contactName: j['contactName'] as String? ?? '',
    contactPhone: j['contactPhone'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'bloodType': bloodType,
    'allergies': allergies,
    'conditions': conditions,
    'medications': medications,
    'contactName': contactName,
    'contactPhone': contactPhone,
  };
}

/// An analysis the user chose to keep on this device.
class SavedReport {
  final String id;
  final String profileId;
  final DateTime savedAt;
  final ReportAnalysis analysis;

  const SavedReport({
    required this.id,
    required this.profileId,
    required this.savedAt,
    required this.analysis,
  });

  factory SavedReport.fromJson(Map<String, dynamic> j) => SavedReport(
    id: j['id'] as String,
    // Reports saved before profiles existed belong to the default profile.
    profileId: j['profileId'] as String? ?? defaultProfileId,
    savedAt: DateTime.parse(j['savedAt'] as String),
    analysis: ReportAnalysis.fromJson(j['analysis'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'profileId': profileId,
    'savedAt': savedAt.toIso8601String(),
    'analysis': analysis.toJson(),
  };
}

const defaultProfileId = 'me';
