import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa.dart';
import 'package:hotel_booking_flutter/features/villas/domain/entities/villa_specs.dart';

void main() {
  group('Villa Domain Entity Tests', () {
    test(
        'primaryBadge selects highest priority badge (featured > new > near-beach > saltwater > group)',
        () {
      const specs = VillaSpecs(
        bedrooms: 4,
        beds: 6,
        maxGuests: 12,
        bathrooms: 4,
      );

      // Case 1: contains group and featured -> featured wins
      const villa1 = Villa(
        id: '1',
        code: 'V1',
        name: 'Villa 1',
        tagline: 'Tagline',
        address: 'Address',
        description: 'Desc',
        imageUrls: [],
        specs: specs,
        badges: [VillaBadgeType.group, VillaBadgeType.featured],
      );
      expect(villa1.primaryBadge, VillaBadgeType.featured);

      // Case 2: contains saltwater and newVilla -> newVilla wins
      const villa2 = Villa(
        id: '2',
        code: 'V2',
        name: 'Villa 2',
        tagline: 'Tagline',
        address: 'Address',
        description: 'Desc',
        imageUrls: [],
        specs: specs,
        badges: [VillaBadgeType.saltwater, VillaBadgeType.newVilla],
      );
      expect(villa2.primaryBadge, VillaBadgeType.newVilla);

      // Case 3: contains nearBeach and saltwater -> nearBeach wins
      const villa3 = Villa(
        id: '3',
        code: 'V3',
        name: 'Villa 3',
        tagline: 'Tagline',
        address: 'Address',
        description: 'Desc',
        imageUrls: [],
        specs: specs,
        badges: [VillaBadgeType.saltwater, VillaBadgeType.nearBeach],
      );
      expect(villa3.primaryBadge, VillaBadgeType.nearBeach);

      // Case 4: empty badges -> null
      const villa4 = Villa(
        id: '4',
        code: 'V4',
        name: 'Villa 4',
        tagline: 'Tagline',
        address: 'Address',
        description: 'Desc',
        imageUrls: [],
        specs: specs,
        badges: [],
      );
      expect(villa4.primaryBadge, isNull);
    });

    test('localizes villa description for Korean and English and supports original Vietnamese', () {
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
        address: '84 Hạ Long',
        description:
            'Căn hộ homestay view cung đường biển Hạ Long lãng mạn. Phù hợp cho cặp đôi hoặc nhóm bạn nhỏ 4 người thích sự yên tĩnh, ngắm tàu thuyền qua lại và đi dạo ngọn Hải Đăng.',
        imageUrls: [],
        specs: specs,
      );

      // Vietnamese (original)
      expect(
        homestay104.descriptionDisplayFor('vi'),
        'Căn hộ homestay view cung đường biển Hạ Long lãng mạn. Phù hợp cho cặp đôi hoặc nhóm bạn nhỏ 4 người thích sự yên tĩnh, ngắm tàu thuyền qua lại và đi dạo ngọn Hải Đăng.',
      );
      expect(homestay104.hasTranslationFor('vi'), isFalse);

      // Korean translation (requested by user)
      expect(
        homestay104.descriptionDisplayFor('ko'),
        '낭만적인 하롱 해안 도로 전망을 갖춘 홈스테이 아파트입니다. 평화로운 분위기 속에서 오가는 선박을 감상하고 등대까지 산책을 즐기고자 하는 커플이나 4인 소규모 여행객에게 안성맞춤입니다.',
      );
      expect(homestay104.hasTranslationFor('ko'), isTrue);

      // English translation
      expect(
        homestay104.descriptionDisplayFor('en'),
        'Romantic homestay apartment overlooking the scenic Ha Long coastal road. Perfect for couples or small groups of up to 4 guests who love tranquility, watching passing boats, and taking walks to the Lighthouse.',
      );
      expect(homestay104.hasTranslationFor('en'), isTrue);
    });
  });
}
