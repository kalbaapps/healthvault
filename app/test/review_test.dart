import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthvault/screens/review_screen.dart';

/// Opens [ReviewScreen] from a button and records what it pops with.
Future<ReviewChoice?> _open(
  WidgetTester tester, {
  required bool isPdf,
  required String tap,
}) async {
  ReviewChoice? result;
  var popped = false;

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<ReviewChoice>(
                MaterialPageRoute(
                  builder: (_) =>
                      ReviewScreen(file: File('scan.pdf'), isPdf: isPdf),
                ),
              );
              popped = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  await tester.tap(find.text(tap));
  await tester.pumpAndSettle();
  expect(popped, isTrue);
  return result;
}

void main() {
  testWidgets('"Use this photo" confirms the photo', (tester) async {
    expect(
      await _open(tester, isPdf: false, tap: 'Use this photo'),
      ReviewChoice.use,
    );
  });

  testWidgets('"Retake" asks to take it again', (tester) async {
    expect(
      await _open(tester, isPdf: false, tap: 'Retake'),
      ReviewChoice.retake,
    );
  });

  testWidgets('"Cancel" backs out without choosing', (tester) async {
    expect(await _open(tester, isPdf: false, tap: 'Cancel'), isNull);
  });

  testWidgets('a PDF is offered "Choose another" and shows its name', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewScreen(file: File('reports/scan.pdf'), isPdf: true),
      ),
    );

    expect(find.text('scan.pdf'), findsOneWidget);
    expect(find.text('Use this file'), findsOneWidget);
    expect(find.text('Choose another'), findsOneWidget);
  });
}
