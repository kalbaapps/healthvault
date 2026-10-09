import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Where things sit on the bar, as fractions from 0 (left) to 1 (right).
class RangeBarGeometry {
  final double bandStart;
  final double bandEnd;
  final double dot;

  const RangeBarGeometry({
    required this.bandStart,
    required this.bandEnd,
    required this.dot,
  });
}

/// Positions the usual-range band and the result on a bar. Returns null when
/// the report prints no range at all, because then there is nothing to compare
/// against. A range with only one end (for example "up to 100") fills the bar
/// from the open end to that limit.
RangeBarGeometry? rangeBarGeometry(num value, num? low, num? high) {
  if (low == null && high == null) return null;

  final v = value.toDouble();
  late final double axisMin;
  late final double axisMax;
  double bandStart;
  double bandEnd;

  if (low != null && high != null) {
    final lo = low.toDouble();
    final hi = high.toDouble();
    final span = hi > lo ? hi - lo : math.max(hi.abs(), 1.0);
    axisMin = math.min(lo - span * 0.5, v - span * 0.1);
    axisMax = math.max(hi + span * 0.5, v + span * 0.1);
    bandStart = lo;
    bandEnd = hi;
  } else if (high != null) {
    final hi = high.toDouble();
    final span = math.max(hi.abs(), 1.0);
    axisMin = math.min(hi - span, v - span * 0.1);
    axisMax = math.max(hi + span * 0.5, v + span * 0.1);
    bandStart = axisMin;
    bandEnd = hi;
  } else {
    final lo = low!.toDouble();
    final span = math.max(lo.abs(), 1.0);
    axisMin = math.min(lo - span * 0.5, v - span * 0.1);
    axisMax = math.max(lo + span, v + span * 0.1);
    bandStart = lo;
    bandEnd = axisMax;
  }

  final width = axisMax - axisMin;
  double at(double x) => ((x - axisMin) / width).clamp(0.0, 1.0);
  return RangeBarGeometry(
    bandStart: at(bandStart),
    bandEnd: at(bandEnd),
    dot: at(v),
  );
}

/// A slim bar showing the usual range as a green band and the result as a dot.
class RangeBar extends StatelessWidget {
  final num value;
  final num? low;
  final num? high;
  final String flag; // low | normal | high | unknown

  const RangeBar({
    super.key,
    required this.value,
    required this.low,
    required this.high,
    required this.flag,
  });

  @override
  Widget build(BuildContext context) {
    final geometry = rangeBarGeometry(value, low, high);
    if (geometry == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final dotColor = switch (flag) {
      'high' => Colors.red,
      'low' => Colors.orange,
      'normal' => Colors.green.shade700,
      _ => Colors.grey,
    };

    return Semantics(
      label: switch (flag) {
        'high' => 'Result is above the usual range',
        'low' => 'Result is below the usual range',
        'normal' => 'Result is within the usual range',
        _ => 'Result compared with the usual range',
      },
      child: SizedBox(
        height: 18,
        width: double.infinity,
        child: CustomPaint(
          painter: _RangeBarPainter(
            geometry: geometry,
            track: scheme.surfaceContainerHighest,
            band: Colors.green.withValues(alpha: 0.35),
            dot: dotColor,
            outline: scheme.surface,
          ),
        ),
      ),
    );
  }
}

class _RangeBarPainter extends CustomPainter {
  final RangeBarGeometry geometry;
  final Color track;
  final Color band;
  final Color dot;
  final Color outline;

  const _RangeBarPainter({
    required this.geometry,
    required this.track,
    required this.band,
    required this.dot,
    required this.outline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 7.0;
    final left = radius;
    final width = size.width - 2 * radius;
    final centerY = size.height / 2;
    double x(double f) => left + f * width;

    final trackRect = RRect.fromLTRBR(
      left,
      centerY - 4,
      left + width,
      centerY + 4,
      const Radius.circular(4),
    );
    canvas.drawRRect(trackRect, Paint()..color = track);

    canvas.save();
    canvas.clipRRect(trackRect);
    canvas.drawRect(
      Rect.fromLTRB(
        x(geometry.bandStart),
        centerY - 4,
        x(geometry.bandEnd),
        centerY + 4,
      ),
      Paint()..color = band,
    );
    canvas.restore();

    final center = Offset(x(geometry.dot), centerY);
    canvas.drawCircle(center, radius, Paint()..color = outline);
    canvas.drawCircle(center, radius - 2, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_RangeBarPainter old) =>
      old.geometry != geometry || old.dot != dot || old.band != band;
}
