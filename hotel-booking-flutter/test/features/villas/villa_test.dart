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
  });
}
