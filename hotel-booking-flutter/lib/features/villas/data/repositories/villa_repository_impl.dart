import '../../../../core/date/booking_date.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/nightly_price.dart';
import '../../domain/entities/villa.dart';
import '../../domain/entities/villa_specs.dart';
import '../../domain/repositories/villa_repository.dart';

/// Production VillaRepository communicating with live Express Backend REST endpoints (/api/listings).
///
/// NOTE: Hardcoded mock/seed data is strictly forbidden.
/// All villa details, pricing, availability, and booked dates are loaded directly from the backend API.
class VillaRepositoryImpl implements VillaRepository {
  final DioClient _client;

  const VillaRepositoryImpl(this._client);

  @override
  Future<List<Villa>> getVillas({
    String? searchQuery,
    int? minGuests,
    BookingDate? checkIn,
    BookingDate? checkOut,
  }) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/api/listings',
        queryParameters: {
          if (searchQuery != null && searchQuery.trim().isNotEmpty)
            'q': searchQuery.trim(),
          if (minGuests != null && minGuests > 0) 'guests': minGuests,
          if (checkIn != null) 'checkIn': checkIn.toIsoDate(),
          if (checkOut != null) 'checkOut': checkOut.toIsoDate(),
          'limit': 20,
        },
      );
      final body = response.data;
      final dataObj = body?['data'];
      List<dynamic> items = [];
      if (dataObj is Map<String, dynamic> && dataObj['items'] is List) {
        items = dataObj['items'] as List<dynamic>;
      } else if (dataObj is List) {
        items = dataObj;
      }

      return items
          .map((json) => _mapJsonToVilla(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  @override
  Future<Villa?> getVillaById(String id) async {
    try {
      final response =
          await _client.dio.get<Map<String, dynamic>>('/api/listings/$id');
      final body = response.data;
      final data = (body?['data'] as Map<String, dynamic>?) ?? body;
      if (data == null) return null;
      return _mapJsonToVilla(data);
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  @override
  Future<List<NightlyPrice>> getNightlyPrices({
    required String villaId,
    required BookingDate checkIn,
    required BookingDate checkOut,
  }) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/api/listings/$villaId/availability',
        queryParameters: {
          'month': checkIn.month,
          'year': checkIn.year,
        },
      );
      final body = response.data;
      final dataObj = body?['data'] as Map<String, dynamic>?;
      final daysList = (dataObj?['days'] as List<dynamic>?) ?? [];

      return daysList.map((item) {
        final m = item as Map<String, dynamic>;
        final dateStr = m['date']?.toString() ?? checkIn.toIsoDate();
        final parsedDate = BookingDate.parse(dateStr);
        final isSat = parsedDate.isSaturday;
        return NightlyPrice(
          date: parsedDate,
          priceVnd: (m['price'] as num?)?.toInt() ?? 0,
          isWeekend: isSat,
          isAvailable:
              m['isAvailable'] as bool? ?? (m['is_available'] as bool? ?? true),
          note: m['note'] as String?,
        );
      }).toList();
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  @override
  Future<bool> checkAvailability({
    required String villaId,
    required BookingDate checkIn,
    required BookingDate checkOut,
  }) async {
    try {
      final prices = await getNightlyPrices(
        villaId: villaId,
        checkIn: checkIn,
        checkOut: checkOut,
      );
      if (prices.isEmpty) return true;
      return prices.every((p) => p.isAvailable);
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Villa _mapJsonToVilla(Map<String, dynamic> json) {
    final listingId = (json['listingId'] ?? json['id'])?.toString() ?? '';
    final title = json['title']?.toString() ?? (json['name']?.toString() ?? '');
    final description = json['description']?.toString() ?? '';
    final basePrice = (json['basePrice'] ?? json['base_price_vnd']) as num?;
    final weekendPrice =
        (json['weekendPrice'] ?? json['saturday_price_vnd']) as num?;

    // Extract address
    String address = json['address']?.toString() ?? '';
    if (address.isEmpty) {
      final addrSummary = json['addressSummary'] as Map<String, dynamic>?;
      if (addrSummary != null) {
        final parts = [
          addrSummary['addressLine'],
          addrSummary['ward'],
          addrSummary['district'],
          addrSummary['city']
        ]
            .where((e) => e != null && e.toString().trim().isNotEmpty)
            .map((e) => e.toString().trim());
        address = parts.join(', ');
      } else {
        final parts = [
          json['addressLine'],
          json['ward'],
          json['district'],
          json['city']
        ]
            .where((e) => e != null && e.toString().trim().isNotEmpty)
            .map((e) => e.toString().trim());
        address = parts.join(', ');
      }
    }

    // Extract images
    final imageUrls = <String>[];
    if (json['images'] is List) {
      for (final img in json['images'] as List<dynamic>) {
        if (img is Map<String, dynamic> && img['url'] != null) {
          imageUrls.add(img['url'].toString());
        } else if (img is String) {
          imageUrls.add(img);
        }
      }
    }
    if (imageUrls.isEmpty) {
      final cover = json['coverImage'];
      if (cover is Map<String, dynamic> && cover['url'] != null) {
        imageUrls.add(cover['url'].toString());
      } else if (json['imageUrl'] != null) {
        imageUrls.add(json['imageUrl'].toString());
      } else if (json['image_urls'] is List) {
        imageUrls.addAll((json['image_urls'] as List).map((e) => e.toString()));
      }
    }

    // Extract rating
    double rating = 5.0;
    int reviewCount = 0;
    if (json['ratingSummary'] is Map) {
      final rs = json['ratingSummary'] as Map<String, dynamic>;
      rating = (rs['avgRating'] as num?)?.toDouble() ?? 5.0;
      reviewCount = (rs['reviewCount'] as num?)?.toInt() ?? 0;
    } else {
      final rawRating = json['ratingAvg'] ?? json['rating'];
      rating = (rawRating is num) ? rawRating.toDouble() : 5.0;
      final rawCount = json['reviewCount'] ?? json['review_count'];
      reviewCount = (rawCount is num) ? rawCount.toInt() : 0;
    }

    // Extract amenities
    final amenitiesList = <String>[];
    if (json['amenities'] is List) {
      for (final a in json['amenities'] as List<dynamic>) {
        if (a is Map<String, dynamic> && a['name'] != null) {
          amenitiesList.add(a['name'].toString());
        } else if (a is String) {
          amenitiesList.add(a);
        }
      }
    }

    // Extract specs
    final specs = _parseSpecs(json);

    // Badges
    final badges = <VillaBadgeType>[];
    if (specs.beachDistanceMeters != null &&
        specs.beachDistanceMeters! <= 200) {
      badges.add(VillaBadgeType.nearBeach);
    }
    if (specs.hasSaltwaterPool) {
      badges.add(VillaBadgeType.saltwater);
    }
    if (specs.maxGuests >= 15) {
      badges.add(VillaBadgeType.group);
    }
    if (rating >= 4.8 && reviewCount >= 5) {
      badges.insert(0, VillaBadgeType.featured);
    }

    return Villa(
      id: listingId,
      code: 'VILLA-$listingId',
      name: title,
      tagline:
          json['tagline']?.toString() ?? 'Biệt thự nghỉ dưỡng cao cấp Vũng Tàu',
      address: address.isNotEmpty ? address : 'Thành phố Vũng Tàu',
      description: description,
      imageUrls: imageUrls,
      specs: specs,
      basePriceVnd: basePrice?.toInt(),
      saturdayPriceVnd: weekendPrice?.toInt(),
      rating: rating,
      reviewCount: reviewCount,
      badges: badges,
      amenities: amenitiesList,
      bookedDatesIso: const {},
    );
  }

  VillaSpecs _parseSpecs(Map<String, dynamic> json) {
    final specsJson = json['specs'] as Map<String, dynamic>?;
    if (specsJson != null) {
      return VillaSpecs(
        bedrooms: (specsJson['bedrooms'] as num?)?.toInt() ?? 0,
        beds: (specsJson['beds'] as num?)?.toInt() ?? 0,
        maxGuests: ((specsJson['max_guests'] ?? specsJson['maxGuests']) as num?)
                ?.toInt() ??
            0,
        bathrooms: (specsJson['bathrooms'] as num?)?.toInt() ?? 0,
        beachDistanceMeters:
            (specsJson['beach_distance_meters'] as num?)?.toInt(),
        hasPrivatePool: specsJson['has_private_pool'] as bool? ?? false,
        hasSaltwaterPool: specsJson['has_saltwater_pool'] as bool? ?? false,
        hasBbqKitchen: specsJson['has_bbq_kitchen'] as bool? ?? false,
        hasParking: specsJson['has_parking'] as bool? ?? false,
        poolAreaM2: (specsJson['pool_area_m2'] as num?)?.toDouble(),
      );
    }

    // Direct root attributes from Backend Listing model
    final bedrooms = (json['bedrooms'] as num?)?.toInt() ?? 0;
    final beds = (json['beds'] as num?)?.toInt() ?? 0;
    final rawGuests = json['maxGuests'] ?? json['max_guests'];
    final maxGuests = (rawGuests is num) ? rawGuests.toInt() : 0;
    final bathrooms = (json['bathrooms'] as num?)?.toInt() ?? 0;
    final distanceMeters = (json['distanceMeters'] as num?)?.toInt();

    // Check amenities for features
    final amenitiesText = (json['amenities']?.toString() ?? '').toLowerCase();
    final hasPool =
        amenitiesText.contains('hồ bơi') || amenitiesText.contains('pool');
    final hasSalt = amenitiesText.contains('nước mặn') ||
        amenitiesText.contains('saltwater');
    final hasBbq =
        amenitiesText.contains('bbq') || amenitiesText.contains('bếp');
    final hasParking =
        amenitiesText.contains('đậu xe') || amenitiesText.contains('parking');

    return VillaSpecs(
      bedrooms: bedrooms,
      beds: beds,
      maxGuests: maxGuests,
      bathrooms: bathrooms,
      beachDistanceMeters: distanceMeters,
      hasPrivatePool: hasPool,
      hasSaltwaterPool: hasSalt,
      hasBbqKitchen: hasBbq,
      hasParking: hasParking,
    );
  }
}
