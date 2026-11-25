import 'package:drivepro/core/errors/app_error_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a helpful startup error and retry action', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AppErrorScreen(onRetry: () => retried = true),
      ),
    );

    expect(find.text('Unable to start DrivePro'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });
}
