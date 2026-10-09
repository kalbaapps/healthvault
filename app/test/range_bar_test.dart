import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthvault/range_bar.dart';

void main() {
  group('rangeBarGeometry', () {
    test('a value inside the range sits inside the band', () {
      final g = rangeBarGeometry(100, 75, 159)!;
      expect(g.dot, greaterThan(g.bandStart));
      expect(g.dot, lessThan(g.bandEnd));
      expect(g.bandStart, lessThan(g.bandEnd));
    });

    test('a high value sits to the right of the band', () {
      final g = rangeBarGeometry(288.6, 50, 200)!;
      expect(g.dot, greaterThan(g.bandEnd));
    });

    test('a low value sits to the left of the band', () {
      final g = rangeBarGeometry(38, 40, 80)!;
      expect(g.dot, lessThan(g.bandStart));
    });

    test('a value exactly on a limit sits on the band edge', () {
      final g = rangeBarGeometry(200, 140, 200)!;
      expect(g.dot, closeTo(g.bandEnd, 1e-9));
    });

    test('an upper limit only fills the bar from the left up to the limit', () {
      final inside = rangeBarGeometry(80, null, 100)!;
      expect(inside.bandStart, 0);
      expect(inside.dot, lessThan(inside.bandEnd));

      final above = rangeBarGeometry(148, null, 100)!;
      expect(above.dot, greaterThan(above.bandEnd));
    });

    test('a lower limit only fills the bar from the limit to the right', () {
      final inside = rangeBarGeometry(60, 40, null)!;
      expect(inside.bandEnd, 1);
      expect(inside.dot, greaterThan(inside.bandStart));

      final below = rangeBarGeometry(20, 40, null)!;
      expect(below.dot, lessThan(below.bandStart));
    });

    test('no range means no bar', () {
      expect(rangeBarGeometry(5, null, null), isNull);
    });

    test('every position stays within the bar, even for extreme values', () {
      for (final g in [
        rangeBarGeometry(1e9, 50, 200)!,
        rangeBarGeometry(-1e9, 50, 200)!,
        rangeBarGeometry(0, 0, 0)!,
        rangeBarGeometry(5, 10, 10)!,
        rangeBarGeometry(0, null, 0)!,
      ]) {
        for (final f in [g.bandStart, g.bandEnd, g.dot]) {
          expect(f, inInclusiveRange(0.0, 1.0));
          expect(f.isNaN, isFalse);
        }
        expect(g.bandStart, lessThanOrEqualTo(g.bandEnd));
      }
    });
  });

  group('RangeBar widget', () {
    testWidgets('draws for a result with a range and says where it is', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RangeBar(value: 288.6, low: 50, high: 200, flag: 'high'),
        ),
      );
      expect(find.byType(CustomPaint), findsWidgets);
      expect(
        find.bySemanticsLabel('Result is above the usual range'),
        findsOneWidget,
      );
    });

    testWidgets('draws nothing when no range is printed', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RangeBar(value: 5, low: null, high: null, flag: 'unknown'),
        ),
      );
      expect(find.byType(SizedBox), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('usual range')), findsNothing);
    });
  });
}
