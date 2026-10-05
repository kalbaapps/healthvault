import 'package:flutter/material.dart';

import '../models.dart';
import '../storage.dart';

class _Point {
  final DateTime date;
  final double value;
  final String flag;

  const _Point(this.date, this.value, this.flag);
}

class _Series {
  final String name;
  final String? unit;
  final num? low;
  final num? high;
  final List<_Point> points;

  const _Series(this.name, this.unit, this.low, this.high, this.points);
}

/// Groups numeric results by test name across reports, oldest first.
/// Only tests that appear in at least two reports can show a trend.
List<_Series> _buildSeries(List<SavedReport> reports) {
  final byName = <String, List<(DateTime, LabValue)>>{};
  for (final report in reports) {
    final date =
        DateTime.tryParse(report.analysis.reportDate ?? '') ?? report.savedAt;
    for (final v in report.analysis.values) {
      if (v.value == null) continue;
      byName.putIfAbsent(v.name.trim().toLowerCase(), () => []).add((date, v));
    }
  }

  final series = <_Series>[];
  for (final entries in byName.values) {
    if (entries.length < 2) continue;
    entries.sort((a, b) => a.$1.compareTo(b.$1));
    final latest = entries.last.$2;
    series.add(
      _Series(
        latest.name,
        latest.unit,
        latest.referenceLow,
        latest.referenceHigh,
        [
          for (final (date, v) in entries)
            _Point(date, v.value!.toDouble(), v.flag),
        ],
      ),
    );
  }
  series.sort((a, b) => a.name.compareTo(b.name));
  return series;
}

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  late final Future<List<_Series>> _series = loadReports().then(_buildSeries);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trends')),
      body: FutureBuilder<List<_Series>>(
        future: _series,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final series = snapshot.data!;
          if (series.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Trends appear once you have saved at least two reports that include the same test.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            itemCount: series.length,
            itemBuilder: (context, i) => _TrendCard(series: series[i]),
          );
        },
      ),
    );
  }
}

enum _Verdict { improving, worse, steady, inRange }

/// How far a value sits outside its usual range (0 when inside, or when no range).
double _distanceOutside(double v, num? low, num? high) {
  if (low != null && v < low) return low - v;
  if (high != null && v > high) return v - high;
  return 0;
}

_Verdict _verdict(_Series s) {
  final prev = s.points[s.points.length - 2].value;
  final last = s.points.last.value;
  final before = _distanceOutside(prev, s.low, s.high);
  final now = _distanceOutside(last, s.low, s.high);

  if (before == 0 && now == 0) return _Verdict.inRange;
  if ((now - before).abs() < (prev.abs() * 0.02)) return _Verdict.steady;
  return now < before ? _Verdict.improving : _Verdict.worse;
}

const _months = [
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

String _month(DateTime d) => '${_months[d.month - 1]} ${d.year}';

class _TrendCard extends StatelessWidget {
  final _Series series;

  const _TrendCard({required this.series});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = series.points.last;
    final prev = series.points[series.points.length - 2];
    final unit = series.unit == null ? '' : ' ${series.unit}';
    final change = last.value - prev.value;
    final percent = prev.value == 0 ? null : change / prev.value * 100;
    final verdict = _verdict(series);

    final (label, color) = switch (verdict) {
      _Verdict.improving => ('Improving', Colors.green),
      _Verdict.worse => ('Getting worse', Colors.red),
      _Verdict.steady => ('Steady', Colors.blueGrey),
      _Verdict.inRange => ('In the usual range', Colors.green),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(series.name, style: theme.textTheme.titleSmall),
                ),
                Chip(
                  label: Text(label),
                  side: BorderSide(color: color),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Compare(
                  heading: _month(prev.date),
                  value: '${_fmt(prev.value)}$unit',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.arrow_forward),
                ),
                _Compare(
                  heading: _month(last.date),
                  value: '${_fmt(last.value)}$unit',
                  emphasize: true,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              change == 0
                  ? 'No change since ${_month(prev.date)}.'
                  : '${change > 0 ? 'Up' : 'Down'} ${_fmt(change.abs())}$unit'
                        '${percent == null ? '' : ' (${percent.abs().toStringAsFixed(0)}%)'}'
                        ' since ${_month(prev.date)}.',
              style: theme.textTheme.bodyMedium,
            ),
            if (verdict == _Verdict.worse)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Worth mentioning to your doctor.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: color),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(
                painter: _ChartPainter(
                  series: series,
                  line: theme.colorScheme.primary,
                  band: Colors.green.withValues(alpha: 0.15),
                  alert: Colors.red,
                  label: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Compare extends StatelessWidget {
  final String heading;
  final String value;
  final bool emphasize;

  const _Compare({
    required this.heading,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading, style: theme.textTheme.bodySmall),
        Text(
          value,
          style: emphasize
              ? theme.textTheme.titleLarge
              : theme.textTheme.titleMedium,
        ),
      ],
    );
  }
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _ChartPainter extends CustomPainter {
  final _Series series;
  final Color line;
  final Color band;
  final Color alert;
  final Color label;

  const _ChartPainter({
    required this.series,
    required this.line,
    required this.band,
    required this.alert,
    required this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final values = series.points.map((p) => p.value).toList();
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    final low = series.low?.toDouble();
    final high = series.high?.toDouble();
    if (low != null && low < lo) {
      lo = low;
    }
    if (high != null && high > hi) {
      hi = high;
    }
    if (hi == lo) {
      hi += 1;
      lo -= 1;
    }
    final pad = (hi - lo) * 0.1;
    lo -= pad;
    hi += pad;

    const side = 8.0;
    const bottom = 18.0;
    final chartHeight = size.height - bottom;
    double y(double v) => chartHeight - (v - lo) / (hi - lo) * chartHeight;
    double x(int i) => series.points.length == 1
        ? size.width / 2
        : side + i * (size.width - 2 * side) / (series.points.length - 1);

    // Usual range band.
    final bandTop = y((series.high ?? hi).toDouble());
    final bandBottom = y((series.low ?? lo).toDouble());
    canvas.drawRect(
      Rect.fromLTRB(0, bandTop, size.width, bandBottom),
      Paint()..color = band,
    );

    final path = Path();
    for (var i = 0; i < series.points.length; i++) {
      final p = Offset(x(i), y(series.points[i].value));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    for (var i = 0; i < series.points.length; i++) {
      final point = series.points[i];
      final outside = point.flag == 'low' || point.flag == 'high';
      canvas.drawCircle(
        Offset(x(i), y(point.value)),
        4,
        Paint()..color = outside ? alert : line,
      );
    }

    // First and last dates under the chart.
    void text(String s, double dx, {bool right = false}) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(fontSize: 11, color: label),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(right ? dx - tp.width : dx, size.height - 14));
    }

    text(_date(series.points.first.date), 0);
    text(_date(series.points.last.date), size.width, right: true);
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.series != series;
}
