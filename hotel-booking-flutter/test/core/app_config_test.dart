import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/core/config/app_config.dart';

void main() {
  group('AppConfig Tests', () {
    test('validate throws StateError when environment does not match', () {
      expect(
        () => AppConfig.validate(expectedEnvironment: 'unexpected_env'),
        throwsStateError,
      );
    });

    test('default environment exposes getters correctly', () {
      expect(AppConfig.environment, isNotEmpty);
      expect(AppConfig.apiBaseUrl.startsWith('https://'), isTrue);
    });
  });
}
