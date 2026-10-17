import '../../../../core/date/booking_date.dart';
import 'villa_specs.dart';

enum VillaBadgeType {
  featured(0, 'Nổi bật'),
  newVilla(1, 'Mới'),
  nearBeach(2, 'Gần biển'),
  saltwater(3, 'Hồ bơi nước mặn'),
  group(4, 'Đoàn đông');

  final int priority;
  final String labelVi;
  const VillaBadgeType(this.priority, this.labelVi);
}

class VillaImage {
  final String imageId;
  final String url;
  final String?
      type; // bedroom, living_room, kitchen, bathroom, pool, exterior, view, dining, other
  final double? typeConfidence;
  final String? typeSource; // ai | manual
  final int sortOrder;
  final bool isCover;

  const VillaImage({
    required this.imageId,
    required this.url,
    this.type,
    this.typeConfidence,
    this.typeSource,
    this.sortOrder = 0,
    this.isCover = false,
  });

  String? get typeLabelVi {
    switch (type) {
      case 'bedroom':
        return 'Phòng ngủ';
      case 'living_room':
        return 'Phòng khách';
      case 'kitchen':
        return 'Phòng bếp';
      case 'bathroom':
        return 'Phòng tắm';
      case 'pool':
        return 'Hồ bơi';
      case 'exterior':
        return 'Ngoại thất';
      case 'view':
        return 'Tầm nhìn';
      case 'dining':
        return 'Phòng ăn';
      case 'other':
        return 'Không gian khác';
      default:
        return null;
    }
  }

  factory VillaImage.fromJson(Map<String, dynamic> json) {
    return VillaImage(
      imageId: (json['imageId'] ?? json['id'] ?? '').toString(),
      url: (json['url'] ?? json['imageUrl'] ?? '').toString(),
      type: json['type']?.toString(),
      typeConfidence: (json['typeConfidence'] as num?)?.toDouble(),
      typeSource: json['typeSource']?.toString(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isCover: json['isCover'] == true,
    );
  }
}

class VillaHostInfo {
  final String hostId;
  final String fullName;
  final String? avatarUrl;
  final String? bio;
  final String? joinedAt;
  final bool isVerified;

  const VillaHostInfo({
    required this.hostId,
    required this.fullName,
    this.avatarUrl,
    this.bio,
    this.joinedAt,
    this.isVerified = true,
  });

  factory VillaHostInfo.fromJson(Map<String, dynamic> json) {
    return VillaHostInfo(
      hostId: (json['userId'] ?? json['hostId'] ?? json['id'] ?? '').toString(),
      fullName: (json['fullName'] ?? json['name'] ?? 'Chủ nhà').toString(),
      avatarUrl: (json['avatarUrl'] ?? json['avatar'])?.toString(),
      bio: json['bio']?.toString(),
      joinedAt: (json['createdAt'] ?? json['joinedAt'])?.toString(),
      isVerified: json['isVerified'] as bool? ?? true,
    );
  }
}

class VillaRules {
  final String checkInFrom;
  final String checkInUntil;
  final String checkOutBefore;
  final String? quietHours;
  final bool allowPets;
  final bool allowSmoking;
  final bool allowParties;
  final List<String> additionalRules;

  const VillaRules({
    this.checkInFrom = '14:00',
    this.checkInUntil = '22:00',
    this.checkOutBefore = '12:00',
    this.quietHours = '22:00 - 07:00',
    this.allowPets = false,
    this.allowSmoking = false,
    this.allowParties = false,
    this.additionalRules = const [],
  });

  factory VillaRules.fromJson(Map<String, dynamic> json) {
    final extra = <String>[];
    if (json['additionalRules'] is List) {
      extra.addAll(
        (json['additionalRules'] as List).map((e) => e.toString()),
      );
    } else if (json['houseRules'] is List) {
      extra.addAll(
        (json['houseRules'] as List).map((e) => e.toString()),
      );
    } else if (json['additionalRules'] is String &&
        (json['additionalRules'] as String).trim().isNotEmpty) {
      extra.add((json['additionalRules'] as String).trim());
    }
    return VillaRules(
      checkInFrom:
          (json['checkInFrom'] ?? json['checkInTime'] ?? '14:00').toString(),
      checkInUntil: (json['checkInUntil'] ?? '22:00').toString(),
      checkOutBefore:
          (json['checkOutBefore'] ?? json['checkOutTime'] ?? '12:00')
              .toString(),
      quietHours: (json['quietHours'] ?? '22:00 - 07:00')?.toString(),
      allowPets: json['allowPets'] == true || json['petsAllowed'] == true,
      allowSmoking:
          json['allowSmoking'] == true || json['smokingAllowed'] == true,
      allowParties:
          json['allowParties'] == true || json['eventsAllowed'] == true,
      additionalRules: extra,
    );
  }
}

class SemanticDateIntent {
  final String? label;
  final String? friendlyName;
  final String? checkIn;
  final String? checkOut;
  final bool isAutoFilled;

  const SemanticDateIntent({
    this.label,
    this.friendlyName,
    this.checkIn,
    this.checkOut,
    this.isAutoFilled = false,
  });

  factory SemanticDateIntent.fromJson(Map<String, dynamic> json) {
    return SemanticDateIntent(
      label: json['label']?.toString(),
      friendlyName: json['friendlyName']?.toString(),
      checkIn: json['checkIn']?.toString(),
      checkOut: json['checkOut']?.toString(),
      isAutoFilled: json['isAutoFilled'] == true,
    );
  }
}

class SemanticSearchResponse {
  final String query;
  final String mode; // 'semantic' | 'keyword_fallback'
  final String? reason;
  final String? message;
  final String? availabilityNotice;
  final SemanticDateIntent? dateIntent;
  final String? detectedRoomType;
  final List<Villa> items;

  const SemanticSearchResponse({
    required this.query,
    this.mode = 'semantic',
    this.reason,
    this.message,
    this.availabilityNotice,
    this.dateIntent,
    this.detectedRoomType,
    required this.items,
  });

  bool get isRejected =>
      mode == 'rejected' || (reason != null && reason!.trim().isNotEmpty);
}

class Villa {
  final String id;
  final String code;
  final String name;
  final String tagline;
  final String address;
  final String? ward;
  final String? district;
  final String? city;
  final double? latitude;
  final double? longitude;
  final String propertyType;
  final String description;
  final List<String> imageUrls;
  final List<VillaImage> images;
  final VillaSpecs specs;
  final int? basePriceVnd;
  final int? saturdayPriceVnd;
  final int cleaningFeeVnd;
  final int serviceFeeVnd;
  final double? serviceFeePct;
  final int extraGuestFeeVnd;
  final int includedGuests;
  final int surchargeAmountVnd;
  final int minNights;
  final int maxNights;
  final bool instantBook;
  final String cancellationPolicy; // flexible | moderate | strict
  final String status; // draft | pending | approved | rejected
  final VillaHostInfo? host;
  final VillaRules? rules;
  final double rating;
  final int reviewCount;
  final List<VillaBadgeType> badges;
  final List<String> amenities;
  final Set<String> bookedDatesIso; // 'YYYY-MM-DD' dates that are unavailable
  final double? similarityScore;
  final String? matchedRoomType;
  final String? matchedImageUrl;
  final List<String> matchedReasons;

  const Villa({
    required this.id,
    required this.code,
    required this.name,
    required this.tagline,
    required this.address,
    this.ward,
    this.district,
    this.city,
    this.latitude,
    this.longitude,
    this.propertyType = 'villa',
    required this.description,
    required this.imageUrls,
    this.images = const [],
    required this.specs,
    this.basePriceVnd,
    this.saturdayPriceVnd,
    this.cleaningFeeVnd = 0,
    this.serviceFeeVnd = 0,
    this.serviceFeePct,
    this.extraGuestFeeVnd = 0,
    this.includedGuests = 2,
    this.surchargeAmountVnd = 0,
    this.minNights = 1,
    this.maxNights = 30,
    this.instantBook = true,
    this.cancellationPolicy = 'moderate',
    this.status = 'approved',
    this.host,
    this.rules,
    this.rating = 5.0,
    this.reviewCount = 0,
    this.badges = const [],
    this.amenities = const [],
    this.bookedDatesIso = const {},
    this.similarityScore,
    this.matchedRoomType,
    this.matchedImageUrl,
    this.matchedReasons = const [],
  });

  /// Returns AT MOST ONE primary badge based on strict business priority:
  /// `featured > new > near-beach > saltwater > group`
  VillaBadgeType? get primaryBadge {
    if (badges.isEmpty) return null;
    final sorted = List<VillaBadgeType>.from(badges)
      ..sort((a, b) => a.priority.compareTo(b.priority));
    return sorted.first;
  }

  String get cancellationPolicyLabelVi {
    switch (cancellationPolicy.toLowerCase()) {
      case 'flexible':
        return 'Linh hoạt — Hoàn tiền 100% trước 24 giờ nhận phòng';
      case 'strict':
        return 'Nghiêm ngặt — Hoàn tiền 50% trước 7 ngày nhận phòng';
      case 'moderate':
      default:
        return 'Trung bình — Hoàn tiền 100% trước 5 ngày nhận phòng';
    }
  }

  Villa copyWith({
    Set<String>? bookedDatesIso,
    VillaRules? rules,
  }) {
    return Villa(
      id: id,
      code: code,
      name: name,
      tagline: tagline,
      address: address,
      ward: ward,
      district: district,
      city: city,
      latitude: latitude,
      longitude: longitude,
      propertyType: propertyType,
      description: description,
      imageUrls: imageUrls,
      images: images,
      specs: specs,
      basePriceVnd: basePriceVnd,
      saturdayPriceVnd: saturdayPriceVnd,
      cleaningFeeVnd: cleaningFeeVnd,
      serviceFeeVnd: serviceFeeVnd,
      serviceFeePct: serviceFeePct,
      extraGuestFeeVnd: extraGuestFeeVnd,
      includedGuests: includedGuests,
      surchargeAmountVnd: surchargeAmountVnd,
      minNights: minNights,
      maxNights: maxNights,
      instantBook: instantBook,
      cancellationPolicy: cancellationPolicy,
      status: status,
      host: host,
      rules: rules ?? this.rules,
      rating: rating,
      reviewCount: reviewCount,
      badges: badges,
      amenities: amenities,
      bookedDatesIso: bookedDatesIso ?? this.bookedDatesIso,
      similarityScore: similarityScore,
      matchedRoomType: matchedRoomType,
      matchedImageUrl: matchedImageUrl,
      matchedReasons: matchedReasons,
    );
  }
}

/// Rejection copy helper matching `getRejectionCopy` in `Source goc/frontend/src/views/pages/AiSearch/AiSearchPage.tsx`.
class AiSearchRejectionCopy {
  final String title;
  final String description;
  final List<String> tips;

  const AiSearchRejectionCopy({
    required this.title,
    required this.description,
    required this.tips,
  });

  static AiSearchRejectionCopy resolve(String? reason, [String? message]) {
    switch (reason) {
      case 'QUERY_TOO_SHORT':
        return AiSearchRejectionCopy(
          title: 'Mô tả của bạn còn hơi ngắn để AI hiểu đúng nhu cầu',
          description: message ??
              'Hãy viết tối thiểu một cụm rõ ý như khu vực, số khách, tiện nghi hoặc bầu không khí mong muốn.',
          tips: const [
            'Thêm số khách dự kiến, ví dụ cho 4 người hoặc nhóm 8 người',
            'Nêu 1-2 tiện nghi quan trọng như hồ bơi, BBQ, bếp hoặc gần biển',
            'Nếu có ngày dự kiến, bạn có thể viết trực tiếp như từ 18/4 đến 20/4',
          ],
        );
      case 'LOW_INFORMATION_QUERY':
        return AiSearchRejectionCopy(
          title: 'Nội dung tìm kiếm chưa có nghĩa rõ ràng',
          description: message ??
              'AI chưa nhận diện được từ khóa lưu trú hợp lệ từ chuỗi ký tự vừa nhập.',
          tips: const [
            'Viết bằng tiếng Việt tự nhiên hoặc từ khóa địa điểm, tiện nghi thực tế',
            'Tránh nhập ký tự lặp, chuỗi ngẫu nhiên hoặc một từ rời rạc không rõ ngữ cảnh',
            'Ví dụ tốt: "villa sát biển Bãi Sau có hồ bơi cho 6 người"',
          ],
        );
      case 'UNSUPPORTED_DOMAIN':
        return AiSearchRejectionCopy(
          title: 'Truy vấn này không thuộc phạm vi tìm chỗ nghỉ',
          description: message ??
              'AI Search tại đây chỉ hỗ trợ tìm villa, homestay, căn hộ và khách sạn tại Vũng Tàu.',
          tips: const [
            'Mô tả loại hình lưu trú bạn cần như villa, homestay, căn hộ hoặc khách sạn',
            'Thêm khu vực tại Vũng Tàu như Bãi Sau, Bãi Trước, Long Cung hoặc Chí Linh',
            'Nêu tiện nghi mong muốn như hồ bơi, gần biển, chỗ đậu xe, bếp hoặc BBQ',
          ],
        );
      case 'UNSUPPORTED_LOCATION':
      case 'OFF_DOMAIN_DESTINATIONS':
        return AiSearchRejectionCopy(
          title: 'Hiện hệ thống chỉ hỗ trợ tìm chỗ nghỉ tại Vũng Tàu',
          description: message ??
              'Địa điểm trong mô tả của bạn nằm ngoài khu vực Vũng Tàu nên AI từ chối trả kết quả để tránh gợi ý sai.',
          tips: const [
            'Thử các khu vực tại Vũng Tàu như Bãi Sau, Bãi Trước, Thùy Vân, Trần Phú hoặc Long Cung',
            'Kết hợp thêm nhu cầu như số khách, ngân sách, hồ bơi hoặc khoảng cách ra biển',
            'Ví dụ: "villa Bãi Sau gần biển có hồ bơi riêng cho 8 người"',
          ],
        );
      case 'NO_APPROVED_LISTINGS':
        return AiSearchRejectionCopy(
          title: 'Hiện chưa có chỗ nghỉ sẵn sàng để tìm kiếm',
          description: message ??
              'Dữ liệu chỗ nghỉ đang được cập nhật, vui lòng thử lại sau.',
          tips: const [
            'Thử lại sau ít phút hoặc chuyển sang trang tìm kiếm thường để kiểm tra danh sách hiện có',
          ],
        );
      case 'NO_VIABLE_MATCH':
      default:
        return AiSearchRejectionCopy(
          title: 'Chưa có chỗ nghỉ đủ sát với mô tả của bạn',
          description: message ??
              'AI đã đối chiếu ngữ nghĩa, tiện nghi, sức chứa, ngân sách và lịch trống nhưng chưa tìm thấy lựa chọn đủ tin cậy.',
          tips: const [
            'Nới nhẹ một tiêu chí như ngân sách, số khách hoặc bỏ bớt 1 tiện nghi phụ',
            'Thử đổi khu vực sang Bãi Sau, Bãi Trước hoặc toàn bộ Vũng Tàu',
            'Nếu có ngày cụ thể, hãy thử lùi hoặc dịch chuyển 1-2 ngày để mở rộng phòng còn trống',
          ],
        );
    }
  }
}

/// Pure pricing preview calculator matching `Source goc/backend/src/modules/bookings/booking-pricing.service.ts`.
class VillaDetailPricingCalculator {
  VillaDetailPricingCalculator._();

  static int calculateNights(BookingDate? checkIn, BookingDate? checkOut) {
    if (checkIn == null || checkOut == null) return 1;
    final n = checkIn.differenceInNights(checkOut);
    return n > 0 ? n : 1;
  }

  static int countWeekendNights(BookingDate? checkIn, BookingDate? checkOut) {
    if (checkIn == null || checkOut == null) return 0;
    var count = 0;
    var cursor = checkIn;
    while (cursor.isBefore(checkOut)) {
      if (cursor.isWeekend) {
        count++;
      }
      cursor = cursor.addDays(1);
    }
    return count;
  }

  static ({
    int nights,
    int weekendNights,
    int roomSubtotal,
    int extraGuestTotal,
    int cleaningFee,
    int serviceFee,
    int discount,
    int finalTotal,
  }) calculatePricing({
    required Villa villa,
    required BookingDate? checkIn,
    required BookingDate? checkOut,
    required int guestsCount,
    int couponDiscountVnd = 0,
  }) {
    final nights = calculateNights(checkIn, checkOut);
    final weekendNights = countWeekendNights(checkIn, checkOut);
    final weekdayNights = (nights - weekendNights).clamp(0, nights);
    final basePrice = villa.basePriceVnd ?? 0;
    final weekendNightPrice = villa.saturdayPriceVnd ?? basePrice;
    final roomSubtotal =
        weekdayNights * basePrice + weekendNights * weekendNightPrice;
    final extraGuests = (guestsCount - villa.includedGuests).clamp(0, 100);
    final flatSurcharge =
        guestsCount > villa.includedGuests ? villa.surchargeAmountVnd : 0;
    final extraGuestTotal =
        extraGuests * villa.extraGuestFeeVnd * nights + flatSurcharge;
    final cleaningFee = villa.cleaningFeeVnd;
    final serviceFee = (villa.serviceFeePct != null && villa.serviceFeePct! > 0)
        ? ((roomSubtotal + extraGuestTotal) * villa.serviceFeePct! / 100)
            .round()
        : villa.serviceFeeVnd;
    final gross = roomSubtotal + extraGuestTotal + cleaningFee + serviceFee;
    final discount = couponDiscountVnd.clamp(0, gross);
    final finalTotal = (gross - discount).clamp(0, 999999999);

    return (
      nights: nights,
      weekendNights: weekendNights,
      roomSubtotal: roomSubtotal,
      extraGuestTotal: extraGuestTotal,
      cleaningFee: cleaningFee,
      serviceFee: serviceFee,
      discount: discount,
      finalTotal: finalTotal,
    );
  }
}

/// Pure query & payload normalizer matching `listings.validator.ts`, `filterOptions.ts`,
/// `SearchPage.tsx`, and `AiSearchPage.tsx`.
class VillaSearchQueryNormalizer {
  VillaSearchQueryNormalizer._();

  static const Set<String> validPropertyTypes = {
    'apartment',
    'villa',
    'hotel',
    'homestay',
  };

  static const Map<String, String> amenityCodeMap = {
    'pool': 'pool',
    'ho_boi': 'pool',
    'ho_boi_rieng': 'pool',
    'private_pool': 'pool',
    'hồ bơi': 'pool',
    'hồ bơi riêng': 'pool',
    'wifi': 'wifi',
    'wifi_mien_phi': 'wifi',
    'wifi miễn phí': 'wifi',
    'wifi tốc độ cao': 'wifi',
    'kitchen': 'kitchen',
    'bep': 'kitchen',
    'bếp': 'kitchen',
    'bếp đầy đủ': 'kitchen',
    'air_conditioner': 'air_conditioner',
    'ac': 'air_conditioner',
    'dieu_hoa': 'air_conditioner',
    'điều hòa': 'air_conditioner',
    'máy lạnh': 'air_conditioner',
    'washer': 'washer',
    'may_giat': 'washer',
    'máy giặt': 'washer',
    'parking': 'parking',
    'free_parking': 'parking',
    'cho_dau_xe': 'parking',
    'chỗ đậu xe': 'parking',
    'chỗ đậu xe miễn phí': 'parking',
    'pet_friendly': 'pet_friendly',
    'pets_allowed': 'pet_friendly',
    'thu_cung': 'pet_friendly',
    'cho phép thú cưng': 'pet_friendly',
    'thân thiện thú cưng': 'pet_friendly',
    'near_beach': 'near_beach',
    'gan_bien': 'near_beach',
    'gần biển': 'near_beach',
    'bbq': 'bbq',
    'khu_vuc_bbq': 'bbq',
    'khu vực bbq': 'bbq',
    'balcony': 'balcony',
    'ban_cong': 'balcony',
    'ban công': 'balcony',
    'nice_view': 'nice_view',
    'view_dep': 'nice_view',
    'view đẹp': 'nice_view',
    'view biển': 'nice_view',
    'self_checkin': 'self_checkin',
    'tu_nhan_phong': 'self_checkin',
    'tự nhận phòng': 'self_checkin',
    'karaoke': 'karaoke',
    'billiards': 'billiards',
    'ban_bida': 'billiards',
    'bàn bida': 'billiards',
    'elevator': 'elevator',
    'thang_may': 'elevator',
    'thang máy': 'elevator',
  };

  static String? normalizeAmenityCode(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) return null;
    if (amenityCodeMap.containsKey(trimmed)) {
      return amenityCodeMap[trimmed];
    }
    final snake = trimmed.replaceAll(RegExp(r'\s+'), '_');
    return amenityCodeMap[snake] ?? snake;
  }

  static List<String> normalizeAmenities(Iterable<String> rawAmenities) {
    return rawAmenities
        .map(normalizeAmenityCode)
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  static String? normalizePropertyType(String? raw) {
    if (raw == null) return null;
    final clean = raw.trim().toLowerCase();
    return validPropertyTypes.contains(clean) ? clean : null;
  }

  static List<String> filterMatchedReasons(Iterable<String> rawReasons) {
    final debugPatterns = [
      RegExp(r'^semantic\s*\(', caseSensitive: false),
      RegExp(r'^keyword\s*\(', caseSensitive: false),
      RegExp(r'^visual\s*\(', caseSensitive: false),
      RegExp(r'^clip[_\s:]', caseSensitive: false),
      RegExp(r'^score\s*[:=]', caseSensitive: false),
    ];
    return rawReasons
        .map((e) => e.trim())
        .where(
          (r) => r.isNotEmpty && !debugPatterns.any((rx) => rx.hasMatch(r)),
        )
        .toList();
  }
}
