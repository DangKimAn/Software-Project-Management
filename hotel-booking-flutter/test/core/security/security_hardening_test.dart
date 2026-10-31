import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/core/logging/app_logger.dart';
import 'package:hotel_booking_flutter/core/network/dio_client.dart';
import 'package:hotel_booking_flutter/core/security/secure_storage_service.dart';
import 'package:hotel_booking_flutter/core/security/url_security_validator.dart';
import 'package:hotel_booking_flutter/core/storage/preferences_service.dart';
import 'package:hotel_booking_flutter/features/host/data/host_repository.dart';
import 'package:hotel_booking_flutter/features/host/domain/host_models.dart';
import 'package:hotel_booking_flutter/features/host/onboarding/host_onboarding_services.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_header_footer.dart';

class _InMemorySecureStorage extends SecureStorageService {
  final String? _authToken;
  final String? _refreshCookie;

  _InMemorySecureStorage({String? authToken, String? refreshCookie})
      : _authToken = authToken,
        _refreshCookie = refreshCookie;

  @override
  Future<String?> getAuthToken() async => _authToken;

  @override
  Future<String?> getRefreshCookie() async => _refreshCookie;

  @override
  Future<String?> getRefreshToken() async => null;
}

class _CaptureRequestAdapter implements HttpClientAdapter {
  final List<RequestOptions> captured = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured.add(options);
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{'ok': true}),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('Security Hardening Regression Suite', () {
    test(
      'UrlSecurityValidator enforces HTTPS, payment host allowlist, and blocks phishing/cleartext/Drive URLs',
      () {
        expect(
          UrlSecurityValidator.isValidPaymentGatewayUrl(
            'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?vnp_TxnRef=123',
            apiBaseUrl: 'https://api.thepalmvilla.vn',
            isDev: false,
            isRelease: true,
          ),
          isTrue,
        );
        expect(
          UrlSecurityValidator.isValidPaymentGatewayUrl(
            'https://test-payment.momo.vn/v2/gateway/pay?t=abc',
            apiBaseUrl: 'https://api.thepalmvilla.vn',
            isDev: false,
            isRelease: true,
          ),
          isTrue,
        );
        // Phishing domain & userinfo spoofing rejected
        expect(
          UrlSecurityValidator.isValidPaymentGatewayUrl(
            'https://vnpayment.vn.attacker.evil/pay',
            apiBaseUrl: 'https://api.thepalmvilla.vn',
            isDev: false,
            isRelease: true,
          ),
          isFalse,
        );
        expect(
          UrlSecurityValidator.isValidPaymentGatewayUrl(
            'https://vnpayment.vn@attacker.evil/pay',
            apiBaseUrl: 'https://api.thepalmvilla.vn',
            isDev: false,
            isRelease: true,
          ),
          isFalse,
        );
        // Cleartext HTTP rejected in release/prod
        expect(
          UrlSecurityValidator.isValidPaymentGatewayUrl(
            'http://sandbox.vnpayment.vn/paymentv2/vpcpay.html',
            apiBaseUrl: 'https://api.thepalmvilla.vn',
            isDev: false,
            isRelease: true,
          ),
          isFalse,
        );
        // Google Drive & cleartext media rejected
        expect(
          UrlSecurityValidator.isSafeUploadOrMediaUrl(
            'https://drive.google.com/uc?id=12345',
            isDev: true,
            isRelease: false,
          ),
          isFalse,
        );
        expect(
          UrlSecurityValidator.isSafeUploadOrMediaUrl(
            'http://cdn.example.com/villa.jpg',
            isDev: false,
            isRelease: true,
          ),
          isFalse,
        );
      },
    );

    test(
      'DioClient attaches Authorization only to configured API origin and strips it from third-party hosts',
      () async {
        final storage = _InMemorySecureStorage(
          authToken: 'eyJhbGciOiJIUzI1NiJ9.secret-jwt',
          refreshCookie: 'refresh-secret',
        );
        final adapter = _CaptureRequestAdapter();
        final client = DioClient(
          dio: Dio(BaseOptions(baseUrl: 'https://api.thepalmvilla.vn')),
          httpClientAdapter: adapter,
          secureStorage: storage,
        );

        await client.dio.get<dynamic>('/api/bookings');
        await client.dio.put<dynamic>(
          'https://pub-bucket.r2.cloudflarestorage.com/listings/photo.jpg',
          data: <int>[1, 2, 3],
        );

        expect(adapter.captured, hasLength(2));
        expect(
          adapter.captured[0].headers['Authorization'],
          'Bearer eyJhbGciOiJIUzI1NiJ9.secret-jwt',
        );
        expect(adapter.captured[1].headers.containsKey('Authorization'), isFalse);
        expect(adapter.captured[1].headers.containsKey('Cookie'), isFalse);
      },
    );

    test(
      'PreferencesService isolates per-user account profiles and purges all user caches on clearSessionData',
      () async {
        final prefs = PreferencesService.inMemory();

        await prefs.saveAccountProfile('user-101', <String, dynamic>{
          'bio': 'Private bio of User 101',
          'phone': '0911222333',
        });

        // User 202 must NOT inherit User 101's cached profile
        expect(prefs.getAccountProfile('user-202'), isEmpty);
        expect(
          prefs.getAccountProfile('user-101')['bio'],
          'Private bio of User 101',
        );

        await prefs.clearSessionData();
        expect(prefs.getAccountProfile('user-101'), isEmpty);
      },
    );

    test(
      'HostOnboardingValidator rejects all-zero spoofed KYC buffers and HostRepository fails closed when unauthenticated',
      () {
        final allZeroPdf = HostPickedFile(
          name: 'spoofed_zero.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 256,
          bytes: Uint8List(256),
        );
        expect(
          HostOnboardingValidator.validatePickedFile(allZeroPdf),
          isNotNull,
        );

        final validPdfBytes = Uint8List(128);
        final header = ascii.encode('%PDF-1.7\n');
        validPdfBytes.setRange(0, header.length, header);
        final realPdf = HostPickedFile(
          name: 'license.pdf',
          mimeType: 'application/pdf',
          sizeBytes: validPdfBytes.length,
          bytes: validPdfBytes,
        );
        expect(HostOnboardingValidator.validatePickedFile(realPdf), isNull);

        final unauthRepo = HostRepository(
          Dio(BaseOptions(baseUrl: 'http://localhost:7000')),
          roleResolver: () => null,
        );
        expect(
          () => unauthRepo.assertHostRoleAuthorized(),
          throwsA(
            isA<HostAuthorizationException>().having(
              (e) => e.statusCode,
              'statusCode',
              401,
            ),
          ),
        );
      },
    );

    test(
      'AppNotificationItem.isSafeInternalRoute and AppLogger.sanitize block traversal & redact query tokens',
      () {
        expect(
          AppNotificationItem.isSafeInternalRoute('/trips/123'),
          isTrue,
        );
        expect(
          AppNotificationItem.isSafeInternalRoute('/admin/../../etc/passwd'),
          isFalse,
        );
        expect(
          AppNotificationItem.isSafeInternalRoute('/%2f%2fevil.example.com'),
          isFalse,
        );

        final sanitized = AppLogger.sanitize(
          'GET /api/admin/host-applications/1/documents/2/file?streamToken=abc.def&token=jwt123',
        );
        expect(sanitized, isNot(contains('abc.def')));
        expect(sanitized, isNot(contains('jwt123')));
        expect(sanitized, contains('streamToken=[REDACTED]'));
        expect(sanitized, contains('token=[REDACTED]'));
      },
    );
  });
}
