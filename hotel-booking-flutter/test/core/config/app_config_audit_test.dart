import 'dart:convert';
import 'dart:io';
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

    test(
        'config/prod.json and config/staging.json target local backend http://localhost:7000 and contain verified contacts',
        () {
      for (final fileName in ['prod.json', 'staging.json']) {
        final candidates = <File>[
          File('config/$fileName'),
          File('hotel-booking-flutter/config/$fileName'),
        ];
        final configFile = candidates.firstWhere((f) => f.existsSync());
        final json =
            jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
        final env = json['APP_ENV'] as String? ?? '';
        final apiBaseUrl = json['API_BASE_URL'] as String? ?? '';
        final allowLocal = json['ALLOW_LOCAL_API_IN_NON_DEV'] == 'true';
        final hotline = json['HOTLINE_NUMBER'] as String? ?? '';
        final zaloUrl = json['ZALO_OA_URL'] as String? ?? '';

        expect(apiBaseUrl, 'http://localhost:7000',
            reason:
                '$fileName API_BASE_URL must target local backend http://localhost:7000 instead of unrelated external domains');
        expect(apiBaseUrl.contains('minhthanhvilla'), isFalse);
        expect(allowLocal, isTrue);

        expect(
          () => AppConfig.validate(
            expectedEnvironment: env,
            currentEnvironment: env,
            currentApiBaseUrl: apiBaseUrl,
            currentHotline: hotline,
            currentZaloUrl: zaloUrl,
            isReleaseBuild: true,
            enforceVerifiedContactsInProd: true,
            allowLocalApiOverride: allowLocal,
          ),
          returnsNormally,
        );

        expect(AppConfig.isPlaceholderHotline(hotline), isFalse,
            reason:
                '$fileName HOTLINE_NUMBER must not be a blocked placeholder');
        expect(AppConfig.isVerifiedHotline(hotline), isTrue,
            reason:
                '$fileName HOTLINE_NUMBER must pass ContactService/AppConfig verification');
        expect(AppConfig.isPlaceholderZaloUrl(zaloUrl), isFalse,
            reason: '$fileName ZALO_OA_URL must not be a blocked placeholder');
        expect(AppConfig.isVerifiedZaloUrl(zaloUrl), isTrue,
            reason:
                '$fileName ZALO_OA_URL must pass ContactService/AppConfig verification');
      }
    });
  });
}
