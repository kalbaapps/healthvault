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
    if (referenceLow == null && referenceHigh == null) return '';
    return '${referenceLow ?? ''} – ${referenceHigh ?? ''}${unit == null ? '' : ' $unit'}';
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
  });

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
        questionsForDoctor:
            (j['questionsForDoctor'] as List).map((q) => q as String).toList(),
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
      };
}

/// An analysis the user chose to keep on this device.
class SavedReport {
  final String id;
  final DateTime savedAt;
  final ReportAnalysis analysis;

  const SavedReport({
    required this.id,
    required this.savedAt,
    required this.analysis,
  });

  factory SavedReport.fromJson(Map<String, dynamic> j) => SavedReport(
        id: j['id'] as String,
        savedAt: DateTime.parse(j['savedAt'] as String),
        analysis: ReportAnalysis.fromJson(j['analysis'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'savedAt': savedAt.toIso8601String(),
        'analysis': analysis.toJson(),
      };
}
