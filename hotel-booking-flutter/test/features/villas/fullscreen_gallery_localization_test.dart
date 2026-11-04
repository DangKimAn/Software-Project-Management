import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/app/theme/app_theme.dart';
import 'package:hotel_booking_flutter/features/villa_detail/presentation/screens/villa_detail_screen.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa_specs.dart';
import 'package:hotel_booking_flutter/l10n/l10n.dart';

void main() {
  const testSpecs = VillaSpecs(
    bedrooms: 4,
    beds: 5,
    maxGuests: 10,
    bathrooms: 4,
  );

  final testImages10 = List.generate(
    10,
    (index) => VillaImage(
      imageId: 'img-$index',
      url: 'https://example.com/photo-$index.jpg',
      type: index == 0
          ? 'living_room'
          : index == 1
              ? 'bedroom'
              : index == 2
                  ? 'pool'
                  : 'exterior',
    ),
  );

  final villa10Photos = Villa(
    id: 'villa-101',
    code: 'MTV-101',
    name: 'Seaside Sunset Homestay & Studio Hạ Long',
    tagline: 'Biệt thự hồ bơi riêng gần biển',
    address: '84 Hạ Long, Vũng Tàu',
    description: 'Chỗ nghỉ sát biển view hoàng hôn.',
    basePriceVnd: 3500000,
    rating: 4.9,
    reviewCount: 24,
    imageUrls: testImages10.map((i) => i.url).toList(),
    images: testImages10,
    specs: testSpecs,
  );

  final singleImage = [
    const VillaImage(
      imageId: 'img-single',
      url: 'https://example.com/photo-single.jpg',
      type: 'living_room',
    ),
  ];

  final villa1Photo = Villa(
    id: 'villa-102',
    code: 'MTV-102',
    name: 'Cozy Studio',
    tagline: 'Studio nhỏ xinh',
    address: '10 Trần Phú',
    description: 'Studio nghỉ dưỡng.',
    basePriceVnd: 1200000,
    rating: 4.8,
    reviewCount: 10,
    imageUrls: singleImage.map((i) => i.url).toList(),
    images: singleImage,
    specs: testSpecs,
  );

  Widget buildGalleryApp(String localeCode, Villa villa) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      locale: Locale(localeCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: FullscreenGalleryModal(villa: villa),
      ),
    );
  }

  group('FullscreenGalleryModal Photo Count & Space Localization', () {
    testWidgets('Renders (10 photos) and English spaces when locale is en',
        (tester) async {
      await tester.pumpWidget(buildGalleryApp('en', villa10Photos));
      await tester.pumpAndSettle();

      // Title must show "(10 photos)" in English, not hardcoded "(10 ảnh)"
      expect(
        find.text('Seaside Sunset Homestay & Studio Hạ Long (10 photos)'),
        findsOneWidget,
      );
      expect(find.textContaining('(10 ảnh)'), findsNothing);

      // Category chips in English
      expect(find.text('Living room'), findsOneWidget);
      expect(find.text('Bedroom'), findsOneWidget);
      expect(find.text('Swimming pool'), findsOneWidget);
      expect(find.text('Exterior'), findsOneWidget);

      // Space caption in English
      expect(find.text('Space: Living room'), findsOneWidget);
    });

    testWidgets('Renders singular (1 photo) when count is 1 in English',
        (tester) async {
      await tester.pumpWidget(buildGalleryApp('en', villa1Photo));
      await tester.pumpAndSettle();

      expect(
        find.text('Cozy Studio (1 photo)'),
        findsOneWidget,
      );
    });

    testWidgets('Renders (10장의 사진) and Korean spaces when locale is ko',
        (tester) async {
      await tester.pumpWidget(buildGalleryApp('ko', villa10Photos));
      await tester.pumpAndSettle();

      expect(
        find.text('Seaside Sunset Homestay & Studio Hạ Long (10장의 사진)'),
        findsOneWidget,
      );

      // Category chips in Korean
      expect(find.text('거실'), findsOneWidget);
      expect(find.text('침실'), findsOneWidget);
      expect(find.text('수영장'), findsOneWidget);
      expect(find.text('외관'), findsOneWidget);

      // Space caption in Korean
      expect(find.text('공간: 거실'), findsOneWidget);
    });

    testWidgets('Renders (10 ảnh) and Vietnamese spaces when locale is vi',
        (tester) async {
      await tester.pumpWidget(buildGalleryApp('vi', villa10Photos));
      await tester.pumpAndSettle();

      expect(
        find.text('Seaside Sunset Homestay & Studio Hạ Long (10 ảnh)'),
        findsOneWidget,
      );

      // Category chips in Vietnamese
      expect(find.text('Phòng khách'), findsOneWidget);
      expect(find.text('Phòng ngủ'), findsOneWidget);
      expect(find.text('Hồ bơi'), findsOneWidget);
      expect(find.text('Ngoại thất'), findsOneWidget);

      // Space caption in Vietnamese
      expect(find.text('Không gian: Phòng khách'), findsOneWidget);
    });
  });
}
