import 'package:flutter_test/flutter_test.dart';
import 'package:drivepro/core/logging/app_logger.dart';

void main() {
  tearDown(() => AppLogger.testSink = null);

  test('logger prefixes messages and preserves severity', () {
    String? message;
    AppLogLevel? level;
    AppLogger.testSink = (value, severity) {
      message = value;
      level = severity;
    };

    AppLogger.warning('Low disk space', tag: 'Storage');

    expect(message, '[Storage] Low disk space');
    expect(level, AppLogLevel.warning);
  });
}
