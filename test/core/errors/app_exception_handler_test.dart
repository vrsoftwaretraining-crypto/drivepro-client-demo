import 'package:flutter_test/flutter_test.dart';
import 'package:drivepro/core/errors/app_exception_handler.dart';
import 'package:drivepro/core/logging/app_logger.dart';

void main() {
  tearDown(() => AppLogger.testSink = null);

  test('guard returns successful operation result', () async {
    expect(
        await AppExceptionHandler.guard<int>('calculate', () async => 42), 42);
  });

  test('guard logs and rethrows failures', () async {
    String? logged;
    AppLogger.testSink = (message, _) => logged = message;

    await expectLater(
      AppExceptionHandler.guard<void>(
        'Save failed',
        () async => throw StateError('offline'),
        tag: 'TestRepository',
      ),
      throwsA(isA<StateError>()),
    );
    expect(
        logged, contains('[TestRepository] Save failed: Bad state: offline'));
  });
}
