import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/di/providers.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/core/network/dio_client.dart';
import 'package:hotel_booking_flutter/core/security/secure_storage_service.dart';
import 'package:hotel_booking_flutter/features/booking_inquiry/domain/services/contact_service.dart';
import 'package:hotel_booking_flutter/features/contact/presentation/screens/contact_screen.dart';

class _FakeSecureStorage extends SecureStorageService {
  String? token;

  @override
  Future<String?> getAuthToken() async => token;

  @override
  Future<void> saveAuthToken(String value) async {
    token = value;
  }

  @override
  Future<void> deleteAuthToken() async {
    token = null;
  }
}

Dio _buildMockDio() {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': {'items': const <dynamic>[], 'unreadCount': 0},
            },
          ),
        );
      },
    ),
  );
  return dio;
}

Widget _wrapContactScreen(
  Widget child, {
  double textScale = 1.0,
  Size? surfaceSize,
}) {
  final fakeStorage = _FakeSecureStorage();
  final dio = _buildMockDio();
  return ProviderScope(
    overrides: [
      secureStorageProvider.overrideWithValue(fakeStorage),
      dioClientProvider.overrideWithValue(
        DioClient(dio: dio, secureStorage: fakeStorage),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: surfaceSize,
          textScaler: TextScaler.linear(textScale),
        ),
        child: widget!,
      ),
      home: child,
    ),
  );
}

void main() {
  tearDown(ContactService.resetTestOverrides);

  group(
      'ContactScreen — Config Validation, Launcher Fallback & No Fake Success',
      () {
    testWidgets(
      'flags default sample hotline/Zalo config (0901234567) as unverified and does not claim it is real',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_wrapContactScreen(const ContactScreen()));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('contact-config-warning-banner')),
          findsOneWidget,
        );
        expect(
          find.text('Cấu hình mẫu — Chưa xác minh'),
          findsNWidgets(2),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'verified hotline launches tel: and falls back to copying phone when tel: launcher fails',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        String? copiedPhone;
        ContactService.canLaunchUrlOverride = (_) async => false;
        ContactService.clipboardSetDataOverride = (text) async {
          copiedPhone = text;
        };

        await tester.pumpWidget(
          _wrapContactScreen(
            const ContactScreen(
              hotlineOverride: '0909888777',
              zaloOaUrlOverride: 'https://zalo.me/0909888777',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Đã xác minh cấu hình'), findsNWidgets(2));

        final callBtn = find.byKey(const ValueKey('contact-call-hotline-btn'));
        await tester.ensureVisible(callBtn);
        await tester.tap(callBtn);
        await tester.pumpAndSettle();

        expect(copiedPhone, '0909888777');
        expect(
          find.textContaining('Đã sao chép số 0909 888 777'),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'consultation draft builder validates fields, requires consent, and copies draft without faking server submission',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        String? copiedDraft;
        ContactService.clipboardSetDataOverride = (text) async {
          copiedDraft = text;
        };

        await tester.pumpWidget(
          _wrapContactScreen(
            const ContactScreen(
              hotlineOverride: '0909888777',
              zaloOaUrlOverride: 'https://zalo.me/0909888777',
            ),
          ),
        );
        await tester.pumpAndSettle();

        final submitBtn = find.byKey(const ValueKey('contact-submit-button'));
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Missing required fields + consent not checked
        expect(find.text('Vui lòng nhập họ và tên'), findsOneWidget);
        expect(find.text('Vui lòng nhập số điện thoại'), findsOneWidget);
        expect(find.text('Vui lòng nhập nội dung cần hỗ trợ'), findsOneWidget);
        expect(copiedDraft, isNull);

        // Enter invalid email
        await tester.enterText(
          find.byKey(const ValueKey('contact-name-input')),
          'Nguyễn Minh Anh',
        );
        await tester.enterText(
          find.byKey(const ValueKey('contact-phone-input')),
          '0912345678',
        );
        await tester.enterText(
          find.byKey(const ValueKey('contact-email-input')),
          'email-sai-dinh-dang',
        );
        await tester.enterText(
          find.byKey(const ValueKey('contact-message-input')),
          'Cần tư vấn căn 4 phòng ngủ Bãi Sau cho 10 người lớn.',
        );

        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(find.text('Email không đúng định dạng'), findsOneWidget);
        expect(copiedDraft, isNull);

        // Fix email and toggle consent checkbox
        await tester.enterText(
          find.byKey(const ValueKey('contact-email-input')),
          'minhanh@example.com',
        );
        final consentBox =
            find.byKey(const ValueKey('contact-consent-checkbox'));
        await tester.ensureVisible(consentBox);
        await tester.tap(consentBox);
        await tester.pumpAndSettle();

        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(copiedDraft, isNotNull);
        expect(copiedDraft, contains('Nguyễn Minh Anh'));
        expect(copiedDraft, contains('0912345678'));
        expect(copiedDraft, contains('minhanh@example.com'));
        expect(find.byKey(const ValueKey('contact-draft-preview')),
            findsOneWidget);
      },
    );

    testWidgets(
      'API mode validates required email and does not fake success when endpoint fails',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        var shouldFail = true;
        ContactInquiryPayload? submittedPayload;

        await tester.pumpWidget(
          _wrapContactScreen(
            ContactScreen(
              hotlineOverride: '0909888777',
              zaloOaUrlOverride: 'https://zalo.me/0909888777',
              onSubmitInquiryEndpoint: (submission) async {
                if (shouldFail) {
                  throw Exception('Máy chủ tạm thời quá tải');
                }
                submittedPayload = submission;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('contact-name-input')),
          'Trần Quốc Bảo',
        );
        await tester.enterText(
          find.byKey(const ValueKey('contact-phone-input')),
          '0987654321',
        );
        await tester.enterText(
          find.byKey(const ValueKey('contact-message-input')),
          'Báo giá villa 5 phòng ngủ cuối tuần.',
        );

        final consentBox =
            find.byKey(const ValueKey('contact-consent-checkbox'));
        await tester.ensureVisible(consentBox);
        await tester.tap(consentBox);
        await tester.pumpAndSettle();

        final submitBtn = find.byKey(const ValueKey('contact-submit-button'));
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Email is required in API mode
        expect(
            find.text('Vui lòng nhập email để nhận phản hồi'), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('contact-email-input')),
          'quocbao@example.com',
        );
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Endpoint threw error -> must NOT fake success and must keep user data
        expect(submittedPayload, isNull);
        expect(find.textContaining('Không thể gửi yêu cầu'), findsOneWidget);
        expect(find.text('Trần Quốc Bảo'), findsOneWidget);

        // Now allow endpoint to succeed
        shouldFail = false;
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(submittedPayload, isNotNull);
        expect(submittedPayload!.email, 'quocbao@example.com');
      },
    );

    testWidgets(
      'renders cleanly across 320dp, 360dp, 390dp, 430dp and textScale 1.0 / 1.3 / 1.6 without overflow',
      (tester) async {
        for (final width in [320.0, 360.0, 390.0, 430.0]) {
          for (final scale in [1.0, 1.3, 1.6]) {
            await tester.binding.setSurfaceSize(Size(width, 960));
            await tester.pumpWidget(
              _wrapContactScreen(
                const ContactScreen(),
                surfaceSize: Size(width, 960),
                textScale: scale,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason:
                  'ContactScreen overflowed at width=$width, textScale=$scale',
            );
          }
        }
        await tester.binding.setSurfaceSize(null);
      },
    );
  });
}
