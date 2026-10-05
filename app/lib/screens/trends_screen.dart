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

class _TrendCard extends StatelessWidget {
  final _Series series;

  const _TrendCard({required this.series});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = series.points.first;
    final last = series.points.last;
    final change = last.value - first.value;
    final arrow = change > 0 ? '↑' : (change < 0 ? '↓' : '→');
    final unit = series.unit == null ? '' : ' ${series.unit}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(series.name, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              '${_fmt(last.value)}$unit  $arrow ${_fmt(change.abs())} since ${_date(first.date)}',
              style: theme.textTheme.bodyMedium,
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
