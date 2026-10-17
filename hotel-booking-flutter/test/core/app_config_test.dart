import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/core/config/app_config.dart';
import 'package:hotel_booking_flutter/core/logging/app_logger.dart';

void main() {
  group('AppConfig Environment & Release Security Gate Tests (BUG-35 & BUG-36)',
      () {
    test(
        'resolveExpectedEnvironment prioritizes explicit env, then flavor, then build mode',
        () {
      expect(
        AppConfig.resolveExpectedEnvironment(
          explicitExpectedEnvironment: 'staging',
          buildFlavor: 'dev',
          isReleaseBuild: true,
        ),
        'staging',
      );

      expect(
        AppConfig.resolveExpectedEnvironment(
          buildFlavor: 'staging',
          isReleaseBuild: false,
        ),
        'staging',
      );

      expect(
        AppConfig.resolveExpectedEnvironment(
          buildFlavor: null,
          isReleaseBuild: true,
        ),
        'prod',
      );

      expect(
        AppConfig.resolveExpectedEnvironment(
          buildFlavor: null,
          isReleaseBuild: false,
        ),
        'dev',
      );
    });

    test(
        'validate throws StateError when environment does not match expectedEnvironment',
        () {
      expect(
        () => AppConfig.validate(
          expectedEnvironment: 'prod',
          currentEnvironment: 'dev',
          currentApiBaseUrl: 'https://api.minhthanhvilla.com',
          isReleaseBuild: false,
        ),
        throwsStateError,
      );
    });

    test(
        'validate throws StateError when native buildFlavor mismatches APP_ENV',
        () {
      expect(
        () => AppConfig.validate(
          expectedEnvironment: 'prod',
          currentEnvironment: 'prod',
          buildFlavor: 'dev',
          currentApiBaseUrl: 'https://api.minhthanhvilla.com',
          isReleaseBuild: true,
        ),
        throwsStateError,
      );
    });

    test('validate blocks release builds from running with APP_ENV=dev', () {
      expect(
        () => AppConfig.validate(
          expectedEnvironment: 'dev',
          currentEnvironment: 'dev',
          currentApiBaseUrl: 'https://dev-api.minhthanhvilla.com',
          isReleaseBuild: true,
        ),
        throwsStateError,
      );
    });

    test(
        'validate blocks non-HTTPS API_BASE_URL in staging, prod, and release builds',
        () {
      expect(
        () => AppConfig.validate(
          expectedEnvironment: 'staging',
          currentEnvironment: 'staging',
          currentApiBaseUrl: 'http://staging-api.minhthanhvilla.com',
          isReleaseBuild: false,
        ),
        throwsStateError,
      );

      expect(
        () => AppConfig.validate(
          expectedEnvironment: 'prod',
          currentEnvironment: 'prod',
          currentApiBaseUrl: 'http://api.minhthanhvilla.com',
          isReleaseBuild: true,
        ),
        throwsStateError,
      );
    });

    test(
        'validate blocks prod/release builds from targeting localhost or dev API hosts',
        () {
      expect(
        () => AppConfig.validate(
          expectedEnvironment: 'prod',
          currentEnvironment: 'prod',
          currentApiBaseUrl: 'https://dev-api.minhthanhvilla.com',
          isReleaseBuild: true,
        ),
        throwsStateError,
      );

      expect(
        () => AppConfig.validate(
          expectedEnvironment: 'prod',
          currentEnvironment: 'prod',
          currentApiBaseUrl: 'https://localhost:5000',
          isReleaseBuild: false,
        ),
        throwsStateError,
      );
    });

    test('validate succeeds for valid dev, staging, and prod configurations',
        () {
      expect(
        () => AppConfig.validate(
          expectedEnvironment: 'dev',
          currentEnvironment: 'dev',
          buildFlavor: 'dev',
          currentApiBaseUrl: 'http://localhost:5000',
          isReleaseBuild: false,
        ),
        returnsNormally,
      );

      expect(
        () => AppConfig.validate(
          expectedEnvironment: 'staging',
          currentEnvironment: 'staging',
          buildFlavor: 'staging',
          currentApiBaseUrl: 'https://staging-api.minhthanhvilla.com',
          isReleaseBuild: true,
        ),
        returnsNormally,
      );

      expect(
        () => AppConfig.validate(
          expectedEnvironment: 'prod',
          currentEnvironment: 'prod',
          buildFlavor: 'prod',
          currentApiBaseUrl: 'https://api.minhthanhvilla.com',
          isReleaseBuild: true,
        ),
        returnsNormally,
      );
    });

    test(
        'AppLogger.sanitize redacts Bearer tokens, cookies, and JSON token fields',
        () {
      const sensitiveLog =
          'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.abc.def '
          'Cookie: refreshToken=secret_refresh_value_123; '
          '{"accessToken":"secret_access","refreshToken":"secret_refresh","password":"myPassword123"}';

      final sanitized = AppLogger.sanitize(sensitiveLog);

      expect(
          sanitized, isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')));
      expect(sanitized, isNot(contains('secret_refresh_value_123')));
      expect(sanitized, isNot(contains('secret_access')));
      expect(sanitized, isNot(contains('secret_refresh')));
      expect(sanitized, isNot(contains('myPassword123')));
      expect(sanitized, contains('Bearer [REDACTED]'));
      expect(sanitized, contains('refreshToken=[REDACTED]'));
    });
  });
}
