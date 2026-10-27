import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/core/config/app_config.dart';

void main() {
  group('AppConfig Flavor, API_BASE_URL & Placeholder Audit', () {
    test(
        'Default dev API_BASE_URL matches local backend port 7000 and not dead NXDOMAIN host',
        () {
      expect(AppConfig.environment, 'dev');
      expect(AppConfig.apiBaseUrl, 'http://localhost:7000');
      expect(
        AppConfig.apiBaseUrl.contains('dev-api.minhthanhvilla.com'),
        isFalse,
      );
    });

    test('normalizeApiBaseUrl strips trailing slash and duplicate /api suffix',
        () {
      expect(
        AppConfig.normalizeApiBaseUrl('https://api.minhthanhvilla.com/api/'),
        'https://api.minhthanhvilla.com',
      );
      expect(
        AppConfig.normalizeApiBaseUrl('https://api.minhthanhvilla.com/api'),
        'https://api.minhthanhvilla.com',
      );
      expect(
        AppConfig.normalizeApiBaseUrl('http://localhost:7000/api/api/'),
        'http://localhost:7000',
      );
      expect(
        AppConfig.normalizeApiBaseUrl('http://10.0.2.2:7000/'),
        'http://10.0.2.2:7000',
      );
    });

    test(
        'resolveDeviceApiBaseUrl remaps localhost to 10.0.2.2 on Android emulator when enabled',
        () {
      expect(
        AppConfig.resolveDeviceApiBaseUrl(
          rawUrl: 'http://localhost:7000/api/',
          isWeb: false,
          platform: TargetPlatform.android,
          remapAndroidLoopback: true,
        ),
        'http://10.0.2.2:7000',
      );
      expect(
        AppConfig.resolveDeviceApiBaseUrl(
          rawUrl: 'http://127.0.0.1:7000',
          isWeb: false,
          platform: TargetPlatform.android,
          remapAndroidLoopback: true,
        ),
        'http://10.0.2.2:7000',
      );
      // Preserves localhost on Windows / iOS / Web or when remapping is disabled
      expect(
        AppConfig.resolveDeviceApiBaseUrl(
          rawUrl: 'http://localhost:7000',
          isWeb: false,
          platform: TargetPlatform.windows,
          remapAndroidLoopback: true,
        ),
        'http://localhost:7000',
      );
      expect(
        AppConfig.resolveDeviceApiBaseUrl(
          rawUrl: 'http://localhost:7000',
          isWeb: true,
          platform: TargetPlatform.android,
          remapAndroidLoopback: true,
        ),
        'http://localhost:7000',
      );
    });

    test(
        'Detects unverified placeholder hotline and Zalo URLs instead of treating sample numbers as verified',
        () {
      expect(AppConfig.isPlaceholderHotline('0901234567'), isTrue);
      expect(AppConfig.isPlaceholderHotline('+84 901 234 567'), isTrue);
      expect(AppConfig.isPlaceholderHotline('0123456789'), isTrue);
      expect(AppConfig.isVerifiedHotline('0901234567'), isFalse);

      expect(
          AppConfig.isPlaceholderZaloUrl('https://zalo.me/0901234567'), isTrue);
      expect(
          AppConfig.isVerifiedZaloUrl('https://zalo.me/0901234567'), isFalse);

      // Default config uses placeholder 0901234567 unless overridden via dart-define
      expect(AppConfig.hasUnverifiedContactPlaceholders, isTrue);
      expect(AppConfig.verifiedHotlineOrNull, isNull);
      expect(AppConfig.verifiedZaloUrlOrNull, isNull);
    });

    test(
        'auditConfiguration reports placeholder warnings and validate enforces verified contacts when requested',
        () {
      final warnings = AppConfig.auditConfiguration(
        currentEnvironment: 'prod',
        currentApiBaseUrl: 'https://api.minhthanhvilla.com',
        currentHotline: '0901234567',
        currentZaloUrl: 'https://zalo.me/0901234567',
      );
      expect(warnings.length, greaterThanOrEqualTo(2));
      expect(
        warnings.any((w) => w.contains('HOTLINE_NUMBER')),
        isTrue,
      );
      expect(
        warnings.any((w) => w.contains('ZALO_OA_URL')),
        isTrue,
      );

      expect(
        () => AppConfig.validate(
          expectedEnvironment: 'prod',
          currentEnvironment: 'prod',
          currentApiBaseUrl: 'https://api.minhthanhvilla.com',
          currentHotline: '0901234567',
          currentZaloUrl: 'https://zalo.me/0901234567',
          enforceVerifiedContactsInProd: true,
        ),
        throwsStateError,
      );
    });
  });
}
