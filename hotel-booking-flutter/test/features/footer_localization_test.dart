import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/di/providers.dart';
import 'package:hotel_booking_flutter/l10n/l10n.dart';
import 'package:hotel_booking_flutter/shared/widgets/app_header_footer.dart';

class _TestLocaleNotifier extends StateNotifier<String> implements LocaleNotifier {
  _TestLocaleNotifier(super.state);

  @override
  Future<void> setLocale(String languageCode) async {
    state = languageCode;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AppFooter Dynamic Localization Tests', () {
    Widget buildTestHarness(String languageCode) {
      return ProviderScope(
        overrides: [
          localeProvider.overrideWith((ref) => _TestLocaleNotifier(languageCode)),
        ],
        child: MaterialApp(
          locale: Locale(languageCode),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('vi'),
            Locale('en'),
            Locale('ko'),
          ],
          home: const Scaffold(
            body: SingleChildScrollView(
              child: AppFooter(),
            ),
          ),
        ),
      );
    }

    testWidgets('Renders English strings when active locale is en', (tester) async {
      await tester.pumpWidget(buildTestHarness('en'));
      await tester.pumpAndSettle();

      expect(find.text('Support'), findsOneWidget);
      expect(find.text('Booking Guide'), findsOneWidget);
      expect(find.text('Cancellation Policy'), findsOneWidget);
      expect(find.text('Complaints & Feedback'), findsOneWidget);
      expect(find.text('Frequently Asked Questions (FAQ)'), findsOneWidget);

      expect(find.text('Explore Vung Tau'), findsOneWidget);
      expect(find.text('About Us'), findsOneWidget);
      expect(find.text('Travel Guide'), findsOneWidget);
      expect(find.text('Add-on Services'), findsOneWidget);
      expect(find.text('Member Offers'), findsOneWidget);

      expect(find.text('Contact'), findsOneWidget);
      expect(find.text('Address: 28 Thi Sach'), findsOneWidget);
      expect(find.text('Social'), findsOneWidget);
      expect(find.text('© Copyright Villa Vung Tau 2026'), findsOneWidget);
    });

    testWidgets('Renders Vietnamese strings when active locale is vi', (tester) async {
      await tester.pumpWidget(buildTestHarness('vi'));
      await tester.pumpAndSettle();

      expect(find.text('Hỗ trợ'), findsOneWidget);
      expect(find.text('Hướng dẫn đặt phòng'), findsOneWidget);
      expect(find.text('Chính sách hủy phòng'), findsOneWidget);
      expect(find.text('Khiếu nại & Góp ý'), findsOneWidget);
      expect(find.text('Câu hỏi thường gặp (FAQ)'), findsOneWidget);

      expect(find.text('Khám phá Vũng Tàu'), findsOneWidget);
      expect(find.text('Về chúng tôi'), findsOneWidget);
      expect(find.text('Cẩm nang du lịch'), findsOneWidget);
      expect(find.text('Dịch vụ đi kèm'), findsOneWidget);
      expect(find.text('Ưu đãi thành viên'), findsOneWidget);

      expect(find.text('Liên hệ'), findsOneWidget);
      expect(find.text('Địa chỉ: 28 Thi Sách'), findsOneWidget);
      expect(find.text('Mạng xã hội'), findsOneWidget);
      expect(find.text('© Bản quyền thuộc về Villa Vũng Tàu 2026'), findsOneWidget);
    });

    testWidgets('Renders Korean strings when active locale is ko', (tester) async {
      await tester.pumpWidget(buildTestHarness('ko'));
      await tester.pumpAndSettle();

      expect(find.text('고객 지원'), findsOneWidget);
      expect(find.text('예약 안내'), findsOneWidget);
      expect(find.text('취소 정책'), findsOneWidget);
      expect(find.text('붕따우 둘러보기'), findsOneWidget);
      expect(find.text('연락처'), findsOneWidget);
      expect(find.text('소셜 미디어'), findsOneWidget);
    });
  });
}
