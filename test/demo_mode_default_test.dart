import 'package:drivepro/core/services/backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('demo mode is disabled unless explicitly enabled', () {
    expect(demoMode, isFalse);
  });
}
