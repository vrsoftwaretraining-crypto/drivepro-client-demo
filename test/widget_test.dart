// Developed by @Ramana Code Softwares

import 'package:drivepro/app.dart';
import 'package:drivepro/core/providers/auth_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DrivePro app renders authentication error state',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.error(
              StateError('Test authentication error'),
            ),
          ),
        ],
        child: const DriveProApp(),
      ),
    );

    await tester.pump();

    expect(
      find.textContaining('Authentication error:'),
      findsOneWidget,
    );
  });
}
