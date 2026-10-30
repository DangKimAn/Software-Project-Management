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
      'ContactScreen — Config Validation, Launcher Fallback & Channel Actions',
      () {
    testWidgets(
      'does not mark default sample hotline/Zalo config (0901234567) as verified',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_wrapContactScreen(const ContactScreen()));
        await tester.pumpAndSettle();

        expect(
          find.text('Đã xác minh cấu hình'),
          findsNothing,
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
      'does not render removed consultation draft form section',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _wrapContactScreen(
            const ContactScreen(
              hotlineOverride: '0909888777',
              zaloOaUrlOverride: 'https://zalo.me/0909888777',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Soạn nội dung tư vấn'), findsNothing);
        expect(find.text('Gửi yêu cầu tư vấn'), findsNothing);
        expect(
          find.byKey(const ValueKey('contact-submit-button')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('contact-name-input')),
          findsNothing,
        );
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
