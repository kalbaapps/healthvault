import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Build with `--dart-define=USE_MOCK=false --dart-define=API_URL=http://<host>:8080`
/// to talk to the real server. 10.0.2.2 is the host PC as seen from the Android emulator.
const _useMock = bool.fromEnvironment('USE_MOCK', defaultValue: true);
const _apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:8080',
);

class AnalysisException implements Exception {
  final String message;
  const AnalysisException(this.message);
  @override
  String toString() => message;
}

Future<ReportAnalysis> analyzeReport(
  File file, {
  String language = 'English',
}) async {
  if (_useMock) {
    await Future<void>.delayed(const Duration(seconds: 2));
    return ReportAnalysis.fromJson(_withJitter(_mockResponse));
  }

  final request = http.MultipartRequest('POST', Uri.parse('$_apiUrl/analyze'))
    ..fields['language'] = language
    ..files.add(await http.MultipartFile.fromPath('file', file.path));

  final http.Response response;
  try {
    response = await http.Response.fromStream(
      await request.send().timeout(const Duration(minutes: 2)),
    );
  } on SocketException {
    throw const AnalysisException(
      'Cannot reach the server. Check your connection.',
    );
  } on Exception {
    throw const AnalysisException('The server took too long to respond.');
  }

  final body = jsonDecode(response.body) as Map<String, dynamic>;
  if (response.statusCode != 200) {
    throw AnalysisException(
      body['error'] as String? ?? 'Something went wrong.',
    );
  }
  return ReportAnalysis.fromJson(body);
}

/// Mock mode only: nudges each number a little so several saved samples
/// produce a visible trend, and recomputes the flag from the printed range.
Map<String, dynamic> _withJitter(Map<String, dynamic> base) {
  final random = Random();
  final values = [
    for (final v in base['values'] as List)
      () {
        final m = Map<String, dynamic>.of(v as Map<String, dynamic>);
        final value = (m['value'] as num) * (0.9 + random.nextDouble() * 0.2);
        final rounded = double.parse(value.toStringAsFixed(1));
        final low = m['referenceLow'] as num?;
        final high = m['referenceHigh'] as num?;
        m['value'] = rounded;
        m['valueText'] = rounded.toString();
        m['flag'] = (low != null && rounded < low)
            ? 'low'
            : (high != null && rounded > high)
            ? 'high'
            : 'normal';
        return m;
      }(),
  ];
  return {...base, 'values': values};
}

const _mockResponse = <String, dynamic>{
  'isMedicalReport': true,
  'reportType': 'Complete blood count and lipid profile',
  'reportDate': '2026-09-18',
  'patientName': null,
  'values': [
    {
      'name': 'Hemoglobin',
      'value': 11.2,
      'valueText': '11.2',
      'unit': 'g/dL',
      'referenceLow': 12.0,
      'referenceHigh': 15.5,
      'flag': 'low',
      'explanation': 'Hemoglobin carries oxygen in your blood. Yours is a little below the usual range, which can make you feel tired. Many things can cause this, so it is worth discussing with your doctor.',
    },
    {
      'name': 'White blood cells',
      'value': 6.4,
      'valueText': '6.4',
      'unit': '10^3/µL',
      'referenceLow': 4.0,
      'referenceHigh': 11.0,
      'flag': 'normal',
      'explanation':
          'These cells fight infection. Your count is within the normal range.',
    },
    {
      'name': 'LDL cholesterol',
      'value': 148,
      'valueText': '148',
      'unit': 'mg/dL',
      'referenceLow': null,
      'referenceHigh': 100,
      'flag': 'high',
      'explanation': '"Bad" cholesterol. Yours is above the suggested limit. Diet, activity and sometimes medication can bring it down; your doctor can advise what suits you.',
    },
    {
      'name': 'Fasting glucose',
      'value': 92,
      'valueText': '92',
      'unit': 'mg/dL',
      'referenceLow': 70,
      'referenceHigh': 99,
      'flag': 'normal',
      'explanation': 'Your blood sugar after fasting is in the normal range.',
    },
  ],
  'summary': 'Most of your results are normal. Two are slightly outside the usual range: hemoglobin is a bit low and LDL cholesterol is a bit high. Neither is an emergency, but both are worth discussing at your next visit.',
  'urgent': false,
  'urgentReason': null,
  'questionsForDoctor': [
    'Could my low hemoglobin be related to iron or diet?',
    'What can I do to bring my LDL cholesterol down?',
    'When should I repeat these tests?',
  ],
};
