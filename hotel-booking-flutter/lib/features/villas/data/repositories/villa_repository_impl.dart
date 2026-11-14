import '../../../../core/date/booking_date.dart';
import '../../../../core/media/app_media_helper.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/widgets/vung_tau_map_picker.dart';
import '../../domain/entities/nightly_price.dart';
import '../../domain/entities/villa.dart';
import '../../domain/entities/villa_specs.dart';
import '../../domain/repositories/villa_repository.dart';

/// Triển khai kho dữ liệu `VillaRepository` kết nối trực tiếp tới các điểm cuối REST API thực tế
/// (`/api/listings`, `/api/amenities`) thông qua `DioClient`.
///
/// Production VillaRepository communicating with live Express Backend REST endpoints (/api/listings, /api/amenities).
class VillaRepositoryImpl implements VillaRepository {
  final DioClient _client;

  /// Khởi tạo `VillaRepositoryImpl` sử dụng bộ khách mạng `_client`.
  const VillaRepositoryImpl(this._client);

  static const Set<String> _validPropertyTypes = {
    'apartment',
    'villa',
    'hotel',
    'homestay',
  };

  static const Map<String, String> _amenityCodeAliases = {
    'pool': 'pool',
    'hồ bơi': 'pool',
    'ho boi': 'pool',
    'hồ bơi riêng': 'pool',
    'hồ bơi nước mặn': 'pool',
    'wifi': 'wifi',
    'wi-fi': 'wifi',
    'kitchen': 'kitchen',
    'bếp': 'kitchen',
    'bep': 'kitchen',
    'bếp & bbq': 'kitchen',
    'air_conditioner': 'air_conditioner',
    'điều hòa': 'air_conditioner',
    'dieu hoa': 'air_conditioner',
    'máy lạnh': 'air_conditioner',
    'washer': 'washer',
    'máy giặt': 'washer',
    'may giat': 'washer',
    'parking': 'parking',
    'chỗ đậu xe': 'parking',
    'cho dau xe': 'parking',
    'đậu xe ô tô': 'parking',
    'pet_friendly': 'pet_friendly',
    'cho mang thú cưng': 'pet_friendly',
    'thú cưng': 'pet_friendly',
    'thu cung': 'pet_friendly',
    'near_beach': 'near_beach',
    'gần biển': 'near_beach',
    'gan bien': 'near_beach',
    'bbq': 'bbq',
    'có bbq': 'bbq',
    'co bbq': 'bbq',
    'balcony': 'balcony',
    'ban công': 'balcony',
    'ban cong': 'balcony',
    'nice_view': 'nice_view',
    'view đẹp': 'nice_view',
    'view dep': 'nice_view',
    'view biển': 'nice_view',
    'self_checkin': 'self_checkin',
    'tự check-in': 'self_checkin',
    'tu check-in': 'self_checkin',
    'karaoke': 'karaoke',
    'billiards': 'billiards',
    'bàn bida': 'billiards',
    'bida': 'billiards',
    'elevator': 'elevator',
    'thang máy': 'elevator',
  };

  /// Chuẩn hóa chuỗi tên hoặc bí danh tiện ích `raw` sang mã chuẩn backend thông qua bảng `_amenityCodeAliases`.
  static String normalizeAmenityCode(String raw) {
    final trimmed = raw.trim();
    final lower = trimmed.toLowerCase();
    return _amenityCodeAliases[lower] ?? trimmed;
  }

  /// Xây dựng từ điển tham số truy vấn HTTP chuẩn hóa cho điểm cuối `/api/listings`.
  ///
  /// Giải thuật chuẩn hóa tham số tìm kiếm:
  /// 1. Phân giải cụm khu vực `locationGroup` chuẩn tại Vũng Tàu và triệt tiêu từ khóa `q` trùng lặp
  ///    nếu `searchQuery` đang trùng tên với chính `locationGroup` (tránh truy vấn kép thu hẹp sai tập kết quả).
  /// 2. Ánh xạ danh sách `amenities` sang mã snake_case không trùng lặp và kiểm chứng `propertyType` hợp lệ.
  /// 3. Kẹp biên ngày nhận phòng `checkIn` không lùi về quá khứ trước `BookingDate.todayVn()` (UTC+7)
  ///    và bảo đảm bất biến khoảng nửa mở `[checkIn, checkOut)` tối thiểu `1` đêm.
  Map<String, dynamic> _buildSearchQueryParams({
    String? searchQuery,
    String? locationGroup,
    double? lat,
    double? lng,
    int? radius,
    String? propertyType,
    int? priceMin,
    int? priceMax,
    int? minGuests,
    int? bedrooms,
    int? beds,
    int? bathrooms,
    bool? pets,
    List<String>? amenities,
    BookingDate? checkIn,
    BookingDate? checkOut,
    String? sort,
    required int page,
    required int limit,
  }) {
    final canonicalLocationGroup =
        VungTauMapConstants.resolveLocationGroupName(locationGroup) ??
            (locationGroup != null && locationGroup.trim().isNotEmpty
                ? locationGroup.trim()
                : null);

    final trimmedQuery = searchQuery?.trim() ?? '';
    final queryMatchesLocationGroup = canonicalLocationGroup != null &&
        (trimmedQuery.toLowerCase() == canonicalLocationGroup.toLowerCase() ||
            VungTauMapConstants.resolveLocationGroupName(trimmedQuery) ==
                canonicalLocationGroup);

    final normalizedAmenities = amenities
        ?.map(normalizeAmenityCode)
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final normalizedPropertyType = propertyType?.trim().toLowerCase();
    final validPropertyType = normalizedPropertyType != null &&
            _validPropertyTypes.contains(normalizedPropertyType)
        ? normalizedPropertyType
        : null;

    BookingDate? effectiveCheckIn = checkIn;
    BookingDate? effectiveCheckOut = checkOut;
    if (effectiveCheckIn != null && effectiveCheckOut != null) {
      final todayVn = BookingDate.todayVn();
      if (effectiveCheckIn.isBefore(todayVn)) {
        effectiveCheckIn = todayVn;
      }
      if (!effectiveCheckOut.isAfter(effectiveCheckIn)) {
        effectiveCheckOut = effectiveCheckIn.addDays(1);
      }
    } else {
      effectiveCheckIn = null;
      effectiveCheckOut = null;
    }

    return {
      if (trimmedQuery.isNotEmpty &&
          canonicalLocationGroup == null &&
          !queryMatchesLocationGroup)
        'q': trimmedQuery,
      if (canonicalLocationGroup != null)
        'locationGroup': canonicalLocationGroup,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (radius != null && radius > 0) 'radius': radius,
      if (validPropertyType != null) 'propertyType': validPropertyType,
      if (priceMin != null && priceMin > 0) 'priceMin': priceMin,
      if (priceMax != null && priceMax > 0) 'priceMax': priceMax,
      if (minGuests != null && minGuests > 0) 'guests': minGuests,
      if (bedrooms != null && bedrooms > 0) 'bedrooms': bedrooms,
      if (beds != null && beds > 0) 'beds': beds,
      if (bathrooms != null && bathrooms > 0) 'bathrooms': bathrooms,
      if (pets != null) 'pets': pets,
      if (normalizedAmenities != null && normalizedAmenities.isNotEmpty)
        'amenities': normalizedAmenities.join(','),
      if (effectiveCheckIn != null) 'checkIn': effectiveCheckIn.toIsoDate(),
      if (effectiveCheckOut != null) 'checkOut': effectiveCheckOut.toIsoDate(),
      if (sort != null && sort.trim().isNotEmpty) 'sort': sort.trim(),
      'page': page,
      'limit': limit,
    };
  }

  /// Lấy danh sách phẳng các biệt thự bằng cách ủy quyền cho `getVillasPaginated` và trích xuất `items`.
  @override
  Future<List<Villa>> getVillas({
    String? searchQuery,
    String? locationGroup,
    double? lat,
    double? lng,
    int? radius,
    String? propertyType,
    int? priceMin,
    int? priceMax,
    int? minGuests,
    int? bedrooms,
    int? beds,
    int? bathrooms,
    bool? pets,
    List<String>? amenities,
    BookingDate? checkIn,
    BookingDate? checkOut,
    String? sort,
    int page = 1,
    int limit = 20,
  }) async {
    final result = await getVillasPaginated(
      searchQuery: searchQuery,
      locationGroup: locationGroup,
      lat: lat,
      lng: lng,
      radius: radius,
      propertyType: propertyType,
      priceMin: priceMin,
      priceMax: priceMax,
      minGuests: minGuests,
      bedrooms: bedrooms,
      beds: beds,
      bathrooms: bathrooms,
      pets: pets,
      amenities: amenities,
      checkIn: checkIn,
      checkOut: checkOut,
      sort: sort,
      page: page,
      limit: limit,
    );
    return result.items;
  }

  /// Truy vấn phân trang danh sách biệt thự từ `/api/listings` kết hợp bộ lọc bảo vệ phía client.
  @override
  Future<PaginatedResult<Villa>> getVillasPaginated({
    String? searchQuery,
    String? locationGroup,
    double? lat,
    double? lng,
    int? radius,
    String? propertyType,
    int? priceMin,
    int? priceMax,
    int? minGuests,
    int? bedrooms,
    int? beds,
    int? bathrooms,
    bool? pets,
    List<String>? amenities,
    BookingDate? checkIn,
    BookingDate? checkOut,
    String? sort,
    int page = 1,
    int limit = 12,
  }) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/api/listings',
        queryParameters: _buildSearchQueryParams(
          searchQuery: searchQuery,
          locationGroup: locationGroup,
          lat: lat,
          lng: lng,
          radius: radius,
          propertyType: propertyType,
          priceMin: priceMin,
          priceMax: priceMax,
          minGuests: minGuests,
          bedrooms: bedrooms,
          beds: beds,
          bathrooms: bathrooms,
          pets: pets,
          amenities: amenities,
          checkIn: checkIn,
          checkOut: checkOut,
          sort: sort,
          page: page,
          limit: limit,
        ),
      );
      final parsed = DioClient.parsePaginated<Villa>(
        response.data,
        _mapJsonToVilla,
      );
      // Giải thuật lọc dự phòng phía client đồng bộ với tham số truy vấn máy chủ:
      // Bảo đảm kết quả luôn thỏa mãn ngưỡng tối thiểu bedrooms/beds/bathrooms và chính sách thú cưng (khi có dữ liệu rules).
      final filteredItems = parsed.items.where((villa) {
        if (bedrooms != null &&
            bedrooms > 0 &&
            villa.specs.bedrooms < bedrooms) {
          return false;
        }
        if (beds != null && beds > 0 && villa.specs.beds < beds) {
          return false;
        }
        if (bathrooms != null &&
            bathrooms > 0 &&
            villa.specs.bathrooms < bathrooms) {
          return false;
        }
        if (pets == true && villa.rules != null && !villa.rules!.allowPets) {
          return false;
        }
        return true;
      }).toList();
      return PaginatedResult<Villa>(
        items: filteredItems,
        pagination: parsed.pagination,
      );
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  /// Tải chi tiết biệt thự từ `/api/listings/:id` và đồng thời nạp song song lịch kín phòng 6 tháng cùng nội quy.
  ///
  /// Giải thuật làm giàu dữ liệu song song chịu lỗi (Concurrent Graceful Hydration):
  /// Sau khi ánh xạ thực thể `Villa` gốc, kích hoạt đồng thời `Future.wait` cho `getUnavailableDates`
  /// và `getVillaRules`. Nếu một nhánh phụ gặp lỗi mạng cục bộ, hệ thống tự động lùi về giá trị mặc định
  /// an toàn thay vì làm hỏng toàn bộ trang chi tiết biệt thự.
  @override
  Future<Villa?> getVillaById(String id) async {
    try {
      final response =
          await _client.dio.get<Map<String, dynamic>>('/api/listings/$id');
      final body = response.data;
      final data = (body?['data'] as Map<String, dynamic>?) ?? body;
      if (data == null) return null;
      var villa = _mapJsonToVilla(data);

      // Fetch unavailable dates (6 months) & rules concurrently with graceful fallback
      try {
        final results = await Future.wait([
          getUnavailableDates(id, monthsAhead: 6).catchError((_) => <String>{}),
          getVillaRules(id).catchError((_) => const VillaRules()),
        ]);
        final unavailable = results[0] as Set<String>;
        final rules = results[1] as VillaRules;
        villa = villa.copyWith(
          bookedDatesIso:
              unavailable.isNotEmpty ? unavailable : villa.bookedDatesIso,
          rules: rules,
        );
      } catch (_) {}

      return villa;
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  /// Tải nội quy lưu trú từ `/api/listings/:id/rules` với cơ chế lùi về `VillaRules` mặc định khi lỗi.
  @override
  Future<VillaRules> getVillaRules(String villaId) async {
    try {
      final response = await _client.dio
          .get<Map<String, dynamic>>('/api/listings/$villaId/rules');
      final data = DioClient.unwrapEnvelope(response.data);
      if (data is Map<String, dynamic>) {
        return VillaRules.fromJson(data);
      }
      return const VillaRules();
    } catch (_) {
      return const VillaRules();
    }
  }

  /// Truy vấn danh sách biệt thự gợi ý tương đồng từ `/api/listings/:id/recommendations`.
  @override
  Future<List<Villa>> getRecommendations(
    String villaId, {
    int limit = 4,
  }) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/api/listings/$villaId/recommendations',
        queryParameters: {'limit': limit},
      );
      final data = DioClient.unwrapEnvelope(response.data);
      List<dynamic> list = [];
      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic> && data['items'] is List) {
        list = data['items'] as List<dynamic>;
      }
      return list
          .whereType<Map<String, dynamic>>()
          .map(_mapJsonToVilla)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Quét song song lịch khả dụng của `monthsAhead` tháng tiếp theo để gom toàn bộ ngày đã kín phòng (`YYYY-MM-DD`).
  @override
  Future<Set<String>> getUnavailableDates(
    String villaId, {
    int monthsAhead = 6,
  }) async {
    // Giải thuật truy vấn lịch kín phòng các tháng tiếp theo theo múi giờ Việt Nam (Asia/Ho_Chi_Minh, UTC+7):
    final now = BookingDate.todayVn();
    final unavailable = <String>{};
    final futures = <Future<void>>[];

    for (var offset = 0; offset < monthsAhead; offset++) {
      final target = DateTime.utc(now.year, now.month + offset, 1);
      futures.add(() async {
        try {
          final response = await _client.dio.get<Map<String, dynamic>>(
            '/api/listings/$villaId/availability',
            queryParameters: {
              'month': target.month,
              'year': target.year,
            },
          );
          final data = DioClient.unwrapEnvelope(response.data);
          if (data is Map<String, dynamic> && data['days'] is List) {
            for (final item in data['days'] as List<dynamic>) {
              if (item is Map<String, dynamic>) {
                final isAvail = item['isAvailable'] as bool? ??
                    (item['is_available'] as bool? ?? true);
                final dateStr = item['date']?.toString();
                if (!isAvail && dateStr != null && dateStr.isNotEmpty) {
                  unavailable.add(dateStr);
                }
              }
            }
          }
        } catch (_) {}
      }());
    }

    await Future.wait(futures);
    return unavailable;
  }

  /// Truy vấn và trích lọc danh sách giá theo từng đêm `NightlyPrice` trong khoảng lưu trú nửa mở `[checkIn, checkOut)`.
  ///
  /// Giải thuật gom tháng dương lịch và lọc khoảng nửa mở `[checkIn, checkOut)`:
  /// 1. **Gom tập tháng dương lịch (`months`)**: Dịch con trỏ `cursor` từ `checkIn` theo bước nhảy
  ///    `15` ngày cho tới `checkOut`, đồng thời chèn tường minh tháng của `checkOut` vào `Set` để
  ///    không bỏ sót bất kỳ tháng trung gian nào dù tháng chỉ có 28 ngày.
  /// 2. **Truy vấn lịch máy chủ**: Gọi `/api/listings/:id/availability` cho từng cặp `(year, month)`.
  /// 3. **Lọc nghiêm ngặt theo khoảng nửa mở `[checkIn, checkOut)`**: Chỉ giữ các ngày `parsedDate`
  ///    thỏa mãn `!parsedDate.isBefore(checkIn) && parsedDate.isBefore(checkOut)` (tức `checkIn <= d < checkOut`),
  ///    ánh xạ `price`, `isWeekend`, `isAvailable` và ghi chú `note` (ẩn ghi chú nếu đêm không khả dụng).
  @override
  Future<List<NightlyPrice>> getNightlyPrices({
    required String villaId,
    required BookingDate checkIn,
    required BookingDate checkOut,
  }) async {
    try {
      // Giải thuật thu thập danh sách các tháng dương lịch nằm giữa checkIn và checkOut:
      // Collect months spanned between checkIn and checkOut
      final months = <({int year, int month})>{};
      var cursor = checkIn;
      while (!cursor.isAfter(checkOut)) {
        months.add((year: cursor.year, month: cursor.month));
        cursor = cursor.addDays(15);
      }
      months.add((year: checkOut.year, month: checkOut.month));

      final allDays = <NightlyPrice>[];
      for (final m in months) {
        final response = await _client.dio.get<Map<String, dynamic>>(
          '/api/listings/$villaId/availability',
          queryParameters: {
            'month': m.month,
            'year': m.year,
          },
        );
        final body = response.data;
        final dataObj = body?['data'] as Map<String, dynamic>?;
        final daysList = (dataObj?['days'] as List<dynamic>?) ?? [];

        for (final item in daysList) {
          final map = item as Map<String, dynamic>;
          final dateStr = map['date']?.toString() ?? checkIn.toIsoDate();
          final parsedDate = BookingDate.parse(dateStr);
          if (!parsedDate.isBefore(checkIn) && parsedDate.isBefore(checkOut)) {
            final available = map['isAvailable'] as bool? ??
                (map['is_available'] as bool? ?? true);
            allDays.add(
              NightlyPrice(
                date: parsedDate,
                priceVnd: (map['price'] as num?)?.toInt() ?? 0,
                isWeekend: parsedDate.isWeekend,
                isAvailable: available,
                note: available ? (map['note'] as String?) : null,
              ),
            );
          }
        }
      }

      return allDays;
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  /// Kiểm tra tính khả dụng xuyên suốt khoảng nửa mở `[checkIn, checkOut)` dựa trên dữ liệu `getNightlyPrices`.
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

  /// Tải danh mục tiện ích chuẩn từ `/api/amenities` phục vụ đồng bộ bộ lọc tìm kiếm.
  @override
  Future<List<Map<String, dynamic>>> getAmenitiesCatalog() async {
    try {
      final response =
          await _client.dio.get<Map<String, dynamic>>('/api/amenities');
      final data = DioClient.unwrapEnvelope(response.data);
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().toList();
      }
      if (data is Map<String, dynamic> && data['items'] is List) {
        return (data['items'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Ánh xạ đối tượng JSON đa định dạng từ backend thành thực thể miền `Villa` chuẩn hóa.
  ///
  /// Giải thuật ánh xạ và chuỗi lùi dự phòng (Multi-Schema Mapping & Fallback Chain):
  /// - **Địa chỉ**: Hợp nhất từ `address`, `addressSummary` hoặc ghép chuỗi `addressLine, ward, district, city`.
  /// - **Bộ ảnh xác thực**: Thay thế tự động mọi ảnh kho mẫu bằng bộ ảnh nội bộ đã tuyển chọn qua
  ///   `AppMediaHelper.bundledGalleryForListing` nhằm giữ đúng chất lượng thị giác của thương hiệu.
  /// - **Giá & phụ phí**: Đồng bộ linh hoạt cả khóa `camelCase` và `snake_case`, giữ nguyên `basePriceVnd = null`
  ///   khi máy chủ chưa công bố giá xác thực.
  /// - **Huy hiệu ưu tiên (`badges`)**: Tự động suy diễn nhãn `featured`, `nearBeach`, `saltwater`, `group`
  ///   từ điểm đánh giá, khoảng cách biển, loại hồ bơi và sức chứa khách.
  Villa _mapJsonToVilla(Map<String, dynamic> json) {
    final listingId = (json['listingId'] ?? json['id'])?.toString() ?? '';
    final title = json['title']?.toString() ?? (json['name']?.toString() ?? '');
    final description = json['description']?.toString() ?? '';
    final basePrice = (json['basePrice'] ?? json['base_price_vnd']) as num?;
    final weekendPrice =
        (json['weekendPrice'] ?? json['saturday_price_vnd']) as num?;

    // Extract address & location fields
    String address = json['address']?.toString() ?? '';
    String? ward = json['ward']?.toString();
    String? district = json['district']?.toString();
    String? city = json['city']?.toString();
    final addrSummary = json['addressSummary'] as Map<String, dynamic>?;
    if (addrSummary != null) {
      ward ??= addrSummary['ward']?.toString();
      district ??= addrSummary['district']?.toString();
      city ??= addrSummary['city']?.toString();
      if (address.isEmpty) {
        final parts = [
          addrSummary['addressLine'],
          addrSummary['ward'],
          addrSummary['district'],
          addrSummary['city'],
        ]
            .where((e) => e != null && e.toString().trim().isNotEmpty)
            .map((e) => e.toString().trim());
        address = parts.join(', ');
      }
    } else if (address.isEmpty) {
      final parts = [
        json['addressLine'],
        json['ward'],
        json['district'],
        json['city'],
      ]
          .where((e) => e != null && e.toString().trim().isNotEmpty)
          .map((e) => e.toString().trim());
      address = parts.join(', ');
    }

    final latitude = ((json['latitude'] ?? json['lat']) as num?)?.toDouble();
    final longitude = ((json['longitude'] ?? json['lng']) as num?)?.toDouble();
    final propertyType =
        (json['propertyType'] ?? json['property_type'] ?? 'villa').toString();

    // Extract images & structured VillaImage list, replacing any stock Unsplash URLs
    // with curated bundled assets in `assets/images/`.
    final fallbackGallery = AppMediaHelper.bundledGalleryForListing(
      listingId,
      title: title,
      address: address,
    );
    final imageUrls = <String>[];
    final villaImages = <VillaImage>[];
    if (json['images'] is List) {
      var idx = 0;
      for (final img in json['images'] as List<dynamic>) {
        if (img is Map<String, dynamic> && img['url'] != null) {
          final parsed = VillaImage.fromJson(img);
          final resolvedUrl = AppMediaHelper.isStockPlaceholderUrl(parsed.url)
              ? fallbackGallery[idx % fallbackGallery.length]
              : parsed.url;
          villaImages.add(
            VillaImage(
              imageId: parsed.imageId,
              url: resolvedUrl,
              type: parsed.type,
              typeConfidence: parsed.typeConfidence,
              typeSource: parsed.typeSource,
              sortOrder: parsed.sortOrder,
              isCover: parsed.isCover,
            ),
          );
          imageUrls.add(resolvedUrl);
          idx++;
        } else if (img is String) {
          final resolvedUrl = AppMediaHelper.isStockPlaceholderUrl(img)
              ? fallbackGallery[idx % fallbackGallery.length]
              : img;
          imageUrls.add(resolvedUrl);
          villaImages.add(
            VillaImage(
              imageId: '${listingId}_$idx',
              url: resolvedUrl,
              sortOrder: idx,
              isCover: idx == 0,
            ),
          );
          idx++;
        }
      }
    }
    if (imageUrls.isEmpty) {
      final cover = json['coverImage'];
      if (cover is Map<String, dynamic> && cover['url'] != null) {
        final rawUrl = cover['url'].toString();
        final url = AppMediaHelper.isStockPlaceholderUrl(rawUrl)
            ? fallbackGallery.first
            : rawUrl;
        imageUrls.add(url);
        villaImages.add(VillaImage(imageId: 'cover', url: url, isCover: true));
      } else if (json['imageUrl'] != null) {
        final rawUrl = json['imageUrl'].toString();
        final url = AppMediaHelper.isStockPlaceholderUrl(rawUrl)
            ? fallbackGallery.first
            : rawUrl;
        imageUrls.add(url);
        villaImages.add(VillaImage(imageId: 'cover', url: url, isCover: true));
      } else if (json['image_urls'] is List) {
        var idx = 0;
        for (final u in (json['image_urls'] as List)) {
          final rawUrl = u.toString();
          final url = AppMediaHelper.isStockPlaceholderUrl(rawUrl)
              ? fallbackGallery[idx % fallbackGallery.length]
              : rawUrl;
          imageUrls.add(url);
          villaImages.add(
            VillaImage(
              imageId: '${listingId}_$idx',
              url: url,
              sortOrder: idx,
              isCover: idx == 0,
            ),
          );
          idx++;
        }
      } else {
        for (var idx = 0; idx < fallbackGallery.length; idx++) {
          final url = fallbackGallery[idx];
          imageUrls.add(url);
          villaImages.add(
            VillaImage(
              imageId: '${listingId}_$idx',
              url: url,
              sortOrder: idx,
              isCover: idx == 0,
            ),
          );
        }
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

    // Pricing & policy fields per `booking-pricing.service.ts`
    final cleaningFee =
        ((json['cleaningFee'] ?? json['cleaning_fee']) as num?)?.toInt() ?? 0;
    final serviceFee =
        ((json['serviceFee'] ?? json['service_fee']) as num?)?.toInt() ?? 0;
    final serviceFeePct =
        ((json['serviceFeePct'] ?? json['service_fee_pct']) as num?)
            ?.toDouble();
    final extraGuestFee =
        ((json['extraGuestFee'] ?? json['extra_guest_fee']) as num?)?.toInt() ??
            0;
    final includedGuests =
        ((json['includedGuests'] ?? json['included_guests']) as num?)
                ?.toInt() ??
            (specs.maxGuests > 0 ? specs.maxGuests : 2);
    final rawSurcharge =
        (json['surchargeAmount'] ?? json['weekendSurchargeAmount']) as num?;
    final surchargeAmount = rawSurcharge?.toInt() ?? 0;

    final minNights =
        ((json['minNights'] ?? json['min_nights']) as num?)?.toInt() ?? 1;
    final maxNights =
        ((json['maxNights'] ?? json['max_nights']) as num?)?.toInt() ?? 30;
    final instantBook = (json['instantBook'] ??
            json['instantBookEnabled'] ??
            json['instant_book']) as bool? ??
        true;
    final cancellationPolicy = (json['cancellationPolicy'] ??
            json['cancellation_policy'] ??
            'moderate')
        .toString();
    final status = (json['status'] ?? 'approved').toString();

    // Host info
    VillaHostInfo? hostInfo;
    if (json['host'] is Map<String, dynamic>) {
      hostInfo = VillaHostInfo.fromJson(json['host'] as Map<String, dynamic>);
    } else if (json['hostId'] != null || json['hostName'] != null) {
      hostInfo = VillaHostInfo(
        hostId: (json['hostId'] ?? '').toString(),
        fullName: (json['hostName'] ?? 'Chủ nhà').toString(),
        avatarUrl: json['hostAvatar']?.toString(),
      );
    }

    // Rules if embedded
    VillaRules? rules;
    if (json['rules'] is Map<String, dynamic>) {
      rules = VillaRules.fromJson(json['rules'] as Map<String, dynamic>);
    }

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
      ward: ward,
      district: district,
      city: city,
      latitude: latitude,
      longitude: longitude,
      propertyType: propertyType,
      description: description,
      imageUrls: imageUrls,
      images: villaImages,
      specs: specs,
      basePriceVnd: basePrice?.toInt(),
      saturdayPriceVnd: weekendPrice?.toInt(),
      cleaningFeeVnd: cleaningFee,
      serviceFeeVnd: serviceFee,
      serviceFeePct: serviceFeePct,
      extraGuestFeeVnd: extraGuestFee,
      includedGuests: includedGuests,
      surchargeAmountVnd: surchargeAmount,
      minNights: minNights,
      maxNights: maxNights,
      instantBook: instantBook,
      cancellationPolicy: cancellationPolicy,
      status: status,
      host: hostInfo,
      rules: rules,
      rating: rating,
      reviewCount: reviewCount,
      badges: badges,
      amenities: amenitiesList,
      bookedDatesIso: const {},
    );
  }

  /// Trích xuất bộ thông số kỹ thuật `VillaSpecs` từ nhánh con `specs` hoặc suy diễn từ trường phẳng và từ khóa tiện ích.
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

    final bedrooms = (json['bedrooms'] as num?)?.toInt() ?? 0;
    final beds = (json['beds'] as num?)?.toInt() ?? 0;
    final rawGuests = json['maxGuests'] ?? json['max_guests'];
    final maxGuests = (rawGuests is num) ? rawGuests.toInt() : 0;
    final bathrooms = (json['bathrooms'] as num?)?.toInt() ?? 0;
    final distanceMeters = (json['distanceMeters'] as num?)?.toInt();

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
