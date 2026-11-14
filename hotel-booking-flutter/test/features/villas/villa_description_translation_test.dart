import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/features/villa_detail/presentation/widgets/villa_description_section.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa_specs.dart';
import 'package:hotel_booking_flutter/l10n/l10n.dart';

void main() {
  const specs = VillaSpecs(
    bedrooms: 2,
    beds: 2,
    maxGuests: 4,
    bathrooms: 2,
  );

  const homestay104 = Villa(
    id: '104',
    code: 'VILLA-104',
    name: 'Seaside Sunset Homestay & Studio Hạ Long',
    tagline: 'Homestay view biển',
    address: '84 Hạ Long, Vũng Tàu',
    description:
        'Căn hộ homestay view cung đường biển Hạ Long lãng mạn. Phù hợp cho cặp đôi hoặc nhóm bạn nhỏ 4 người thích sự yên tĩnh, ngắm tàu thuyền qua lại và đi dạo ngọn Hải Đăng.',
    imageUrls: ['https://example.com/cover.jpg'],
    specs: specs,
  );

  Widget buildApp(Locale locale, Villa villa) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      locale: locale,
      supportedLocales: const [Locale('vi'), Locale('en'), Locale('ko')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: SingleChildScrollView(
          child: VillaDescriptionSection(villa: villa),
        ),
      ),
    );
  }

  group('Villa Description Localization & Original Toggle Tests', () {
    testWidgets('renders Korean translation by default, toggles to original and back', (tester) async {
      await tester.pumpWidget(buildApp(const Locale('ko'), homestay104));
      await tester.pumpAndSettle();

      // Section title localized to Korean
      expect(find.text('숙소 소개'), findsOneWidget);

      // Translation badge and action
      expect(find.text('한국어로 번역됨'), findsOneWidget);
      expect(find.text('원문 보기'), findsOneWidget);

      // Translated Korean description text
      expect(
        find.text(
          '낭만적인 하롱 해안 도로 전망을 갖춘 홈스테이 아파트입니다. 평화로운 분위기 속에서 오가는 선박을 감상하고 등대까지 산책을 즐기고자 하는 커플이나 4인 소규모 여행객에게 안성맞춤입니다.',
        ),
        findsOneWidget,
      );

      // Tap "원문 보기" (Show original)
      await tester.tap(find.text('원문 보기'));
      await tester.pumpAndSettle();

      // Badge toggles to original, action becomes "번역 보기"
      expect(find.text('원문 (베트남어)'), findsOneWidget);
      expect(find.text('번역 보기'), findsOneWidget);

      // Description switches to original Vietnamese
      expect(
        find.text(
          'Căn hộ homestay view cung đường biển Hạ Long lãng mạn. Phù hợp cho cặp đôi hoặc nhóm bạn nhỏ 4 người thích sự yên tĩnh, ngắm tàu thuyền qua lại và đi dạo ngọn Hải Đăng.',
        ),
        findsOneWidget,
      );

      // Tap "번역 보기" (Show translation)
      await tester.tap(find.text('번역 보기'));
      await tester.pumpAndSettle();

      // Toggles back to Korean
      expect(find.text('한국어로 번역됨'), findsOneWidget);
      expect(find.text('원문 보기'), findsOneWidget);
      expect(
        find.text(
          '낭만적인 하롱 해안 도로 전망을 갖춘 홈스테이 아파트입니다. 평화로운 분위기 속에서 오가는 선박을 감상하고 등대까지 산책을 즐기고자 하는 커플이나 4인 소규모 여행객에게 안성맞춤입니다.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders English translation by default and allows toggling to original', (tester) async {
      await tester.pumpWidget(buildApp(const Locale('en'), homestay104));
      await tester.pumpAndSettle();

      // Section title localized to English
      expect(find.text('About this villa'), findsOneWidget);

      // Translation badge and action
      expect(find.text('Translated to English'), findsOneWidget);
      expect(find.text('Show original'), findsOneWidget);

      // Translated English description
      expect(
        find.text(
          'Romantic homestay apartment overlooking the scenic Ha Long coastal road. Perfect for couples or small groups of up to 4 guests who love tranquility, watching passing boats, and taking walks to the Lighthouse.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders Vietnamese description directly without translation badge', (tester) async {
      await tester.pumpWidget(buildApp(const Locale('vi'), homestay104));
      await tester.pumpAndSettle();

      // Section title in Vietnamese
      expect(find.text('Giới thiệu biệt thự'), findsOneWidget);

      // Original Vietnamese description
      expect(
        find.text(
          'Căn hộ homestay view cung đường biển Hạ Long lãng mạn. Phù hợp cho cặp đôi hoặc nhóm bạn nhỏ 4 người thích sự yên tĩnh, ngắm tàu thuyền qua lại và đi dạo ngọn Hải Đăng.',
        ),
        findsOneWidget,
      );

      // No translation badges in native Vietnamese
      expect(find.text('Đã dịch sang Tiếng Việt'), findsNothing);
      expect(find.text('Xem bản gốc'), findsNothing);
    });
  });
}
