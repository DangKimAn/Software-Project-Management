import '../../../../core/date/booking_date.dart';
import 'villa_specs.dart';

/// Phân loại nhãn nổi bật của biệt thự theo thứ tự ưu tiên nghiệp vụ tăng dần.
///
/// Giá trị `priority` càng nhỏ thì độ ưu tiên hiển thị trên thẻ biệt thự càng cao:
/// `featured (0) < newVilla (1) < nearBeach (2) < saltwater (3) < group (4)`.
enum VillaBadgeType {
  /// Nhãn biệt thự nổi bật có điểm đánh giá và số lượt nhận xét cao.
  featured(0, 'Nổi bật'),

  /// Nhãn biệt thự mới đưa vào vận hành trên hệ thống.
  newVilla(1, 'Mới'),

  /// Nhãn biệt thự nằm gần bãi biển (khoảng cách từ 200m trở xuống).
  nearBeach(2, 'Gần biển'),

  /// Nhãn biệt thự sở hữu hồ bơi điện phân nước mặn.
  saltwater(3, 'Hồ bơi nước mặn'),

  /// Nhãn biệt thự có sức chứa lớn phù hợp đoàn đông từ 15 khách trở lên.
  group(4, 'Đoàn đông');

  /// Thứ tự ưu tiên số học (số nhỏ hơn được ưu tiên chọn làm nhãn chính).
  final int priority;

  /// Nhãn hiển thị tiếng Việt mặc định của loại huy hiệu.
  final String labelVi;

  /// Khởi tạo hằng số phân loại nhãn biệt thự.
  const VillaBadgeType(this.priority, this.labelVi);
}

/// Thực thể ảnh chi tiết của biệt thự kèm siêu dữ liệu phân loại không gian phòng.
class VillaImage {
  /// Mã định danh duy nhất của tấm ảnh.
  final String imageId;

  /// Đường dẫn ảnh mạng hoặc đường dẫn tài nguyên nội bộ (`assets/images/...`).
  final String url;

  /// Nhãn phân loại không gian ảnh (phòng ngủ, hồ bơi, phòng khách, bếp...).
  final String?
      type; // bedroom, living_room, kitchen, bathroom, pool, exterior, view, dining, other

  /// Độ tin cậy phân loại không gian do mô hình AI chấm điểm (từ `0.0` đến `1.0`).
  final double? typeConfidence;

  /// Nguồn gắn nhãn không gian (`ai` tự động hoặc `manual` do quản trị viên chọn).
  final String? typeSource; // ai | manual

  /// Thứ tự sắp xếp hiển thị trong bộ sưu tập ảnh.
  final int sortOrder;

  /// Cho biết đây có phải ảnh bìa đại diện chính của biệt thự hay không.
  final bool isCover;

  /// Khởi tạo thực thể ảnh biệt thự `VillaImage`.
  const VillaImage({
    required this.imageId,
    required this.url,
    this.type,
    this.typeConfidence,
    this.typeSource,
    this.sortOrder = 0,
    this.isCover = false,
  });

  /// Tên khu vực không gian bằng tiếng Việt tương ứng với mã `type`, hoặc `null` nếu chưa phân loại.
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

  /// Giải mã đối tượng JSON từ API thành thực thể `VillaImage` an toàn kiểu dữ liệu.
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

/// Thông tin hồ sơ chủ nhà hoặc đơn vị vận hành quản lý căn biệt thự.
class VillaHostInfo {
  /// Mã định danh người dùng của chủ nhà.
  final String hostId;

  /// Họ và tên hiển thị của chủ nhà.
  final String fullName;

  /// Đường dẫn ảnh đại diện của chủ nhà (nếu có).
  final String? avatarUrl;

  /// Đoạn giới thiệu ngắn về chủ nhà.
  final String? bio;

  /// Thời điểm chủ nhà tham gia nền tảng dưới dạng chuỗi ISO hoặc nhãn thời gian.
  final String? joinedAt;

  /// Cho biết danh tính chủ nhà đã được xác minh hay chưa.
  final bool isVerified;

  /// Khởi tạo hồ sơ chủ nhà `VillaHostInfo`.
  const VillaHostInfo({
    required this.hostId,
    required this.fullName,
    this.avatarUrl,
    this.bio,
    this.joinedAt,
    this.isVerified = true,
  });

  /// Ánh xạ dữ liệu JSON đa biến thể khóa (`userId`/`hostId`, `fullName`/`name`) sang `VillaHostInfo`.
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

/// Bộ nội quy lưu trú và khung giờ nhận - trả phòng của biệt thự.
class VillaRules {
  /// Giờ bắt đầu nhận phòng tiêu chuẩn (ví dụ `'14:00'`).
  final String checkInFrom;

  /// Giờ kết thúc hỗ trợ nhận phòng muộn (ví dụ `'22:00'`).
  final String checkInUntil;

  /// Giờ tối đa phải hoàn tất trả phòng (ví dụ `'12:00'`).
  final String checkOutBefore;

  /// Khung giờ hạn chế tiếng ồn ban đêm tại khu dân cư / nghỉ dưỡng.
  final String? quietHours;

  /// Cho biết biệt thự có cho phép mang theo thú cưng hay không.
  final bool allowPets;

  /// Cho biết biệt thự có cho phép hút thuốc trong nhà hay không.
  final bool allowSmoking;

  /// Cho biết biệt thự có cho phép tổ chức tiệc hoặc sự kiện đông người hay không.
  final bool allowParties;

  /// Danh sách các quy định bổ sung do chủ nhà thiết lập riêng.
  final List<String> additionalRules;

  /// Khởi tạo bộ nội quy lưu trú `VillaRules` với các mốc giờ tiêu chuẩn ngành khách sạn.
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

  /// Phân tích JSON nội quy lưu trú và hợp nhất các trường mở rộng (`additionalRules`, `houseRules`).
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

/// Thực thể miền trung tâm biểu diễn đầy đủ thông tin, giá phòng, lịch bận và chính sách của một căn biệt thự.
///
/// Giá `basePriceVnd` có kiểu khả rỗng (`int?`) để phân biệt rõ trường hợp chưa xác minh giá
/// (hiển thị trạng thái liên hệ tư vấn báo giá, tuyệt đối không tự bịa số tiền giả).
class Villa {
  /// Mã định danh duy nhất của căn biệt thự trên hệ thống.
  final String id;

  /// Mã tham chiếu hiển thị nội bộ (ví dụ `VILLA-102`).
  final String code;

  /// Tên thương mại của căn biệt thự.
  final String name;

  /// Câu mô tả ngắn nhấn mạnh điểm đặc sắc nhất của biệt thự.
  final String tagline;

  /// Địa chỉ hiển thị đầy đủ của biệt thự.
  final String address;

  /// Phường / xã nơi biệt thự tọa lạc.
  final String? ward;

  /// Quận / huyện / thành phố trực thuộc tỉnh.
  final String? district;

  /// Tỉnh / thành phố.
  final String? city;

  /// Vĩ độ địa lý (`WGS84`) phục vụ định vị trên bản đồ Vũng Tàu.
  final double? latitude;

  /// Kinh độ địa lý (`WGS84`) phục vụ định vị trên bản đồ Vũng Tàu.
  final double? longitude;

  /// Loại hình lưu trú (`villa`, `apartment`, `hotel`, `homestay`).
  final String propertyType;

  /// Bài giới thiệu chi tiết về kiến trúc, không gian và trải nghiệm tại biệt thự.
  final String description;

  /// Danh sách đường dẫn ảnh phẳng phục vụ trình chiếu nhanh trên thẻ danh sách.
  final List<String> imageUrls;

  /// Danh sách đối tượng ảnh giàu siêu dữ liệu phục vụ trang chi tiết biệt thự.
  final List<VillaImage> images;

  /// Thông số kỹ thuật cốt lõi (phòng ngủ, giường, sức chứa, phòng tắm, khoảng cách biển).
  final VillaSpecs specs;

  /// Giá cơ sở ngày thường tính bằng VNĐ (`null` nếu giá chưa được xác minh công khai).
  final int? basePriceVnd;

  /// Giá áp dụng cho đêm cuối tuần / thứ Bảy tính bằng VNĐ (`null` nếu dùng chung `basePriceVnd`).
  final int? saturdayPriceVnd;

  /// Phí dọn dẹp vệ sinh cố định cho mỗi kỳ lưu trú (VNĐ).
  final int cleaningFeeVnd;

  /// Phí dịch vụ cố định (VNĐ) khi không cấu hình tỷ lệ phần trăm `serviceFeePct`.
  final int serviceFeeVnd;

  /// Tỷ lệ phần trăm phí dịch vụ tính trên tổng tiền phòng và phụ thu khách vượt chuẩn.
  final double? serviceFeePct;

  /// Đơn giá phụ thu trên mỗi khách vượt chuẩn cho từng đêm lưu trú (VNĐ/khách/đêm).
  final int extraGuestFeeVnd;

  /// Số lượng khách tiêu chuẩn đã bao gồm trong giá phòng cơ sở.
  final int includedGuests;

  /// Khoản phụ thu trọn gói một lần khi tổng số khách vượt ngưỡng `includedGuests` (VNĐ).
  final int surchargeAmountVnd;

  /// Số đêm lưu trú tối thiểu được phép đặt.
  final int minNights;

  /// Số đêm lưu trú tối đa cho một đơn đặt phòng.
  final int maxNights;

  /// Cho biết căn biệt thự hỗ trợ xác nhận đặt ngay hay cần chờ chủ nhà duyệt.
  final bool instantBook;

  /// Mã chính sách hủy phòng (`flexible`, `moderate`, `strict`).
  final String cancellationPolicy; // flexible | moderate | strict

  /// Trạng thái kiểm duyệt tin đăng (`draft`, `pending`, `approved`, `rejected`).
  final String status; // draft | pending | approved | rejected

  /// Hồ sơ chủ nhà quản lý biệt thự.
  final VillaHostInfo? host;

  /// Bộ nội quy lưu trú của biệt thự.
  final VillaRules? rules;

  /// Điểm đánh giá trung bình (thang điểm `5.0`).
  final double rating;

  /// Tổng số lượt đánh giá xác thực từ khách đã lưu trú.
  final int reviewCount;

  /// Danh sách các huy hiệu nổi bật mà căn biệt thự đạt điều kiện.
  final List<VillaBadgeType> badges;

  /// Danh sách tên hoặc mã tiện ích đi kèm của biệt thự.
  final List<String> amenities;

  /// Tập hợp các chuỗi ngày chuẩn ISO (`YYYY-MM-DD`) đã kín phòng không thể nhận khách.
  final Set<String> bookedDatesIso; // 'YYYY-MM-DD' dates that are unavailable

  /// Khởi tạo thực thể `Villa`.
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
  });

  /// Trả về tối đa một huy hiệu ưu tiên cao nhất để tránh gây nhiễu thị giác trên thẻ:
  /// Returns AT MOST ONE primary badge based on strict business priority:
  /// `featured > new > near-beach > saltwater > group`
  VillaBadgeType? get primaryBadge {
    if (badges.isEmpty) return null;
    final sorted = List<VillaBadgeType>.from(badges)
      ..sort((a, b) => a.priority.compareTo(b.priority));
    return sorted.first;
  }

  /// Diễn giải chi tiết chính sách hủy phòng bằng tiếng Việt tương ứng với `cancellationPolicy`.
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

  /// Tạo bản sao bất biến mới của `Villa` với lịch kín phòng `bookedDatesIso` hoặc nội quy `rules` được cập nhật.
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
    );
  }
}

/// Bộ tính toán dự toán chi phí lưu trú thuần hàm (pure calculator), đồng bộ công thức
/// nghiệp vụ với `booking-pricing.service.ts` phía máy chủ.
///
/// Giải thuật tính giá theo khoảng nửa mở `[checkIn, checkOut)`:
/// 1. **Quy ước đêm lưu trú nửa mở `[checkIn, checkOut)`**: Khách lưu trú qua đêm tại các ngày
///    `d` thỏa `checkIn <= d < checkOut`. Ngày `checkOut` là ngày trả phòng buổi trưa nên không
///    tính tiền đêm. Nếu chưa chọn đủ ngày hoặc khoảng ngày không dương, mặc định dự toán `1` đêm.
/// 2. **Phân tách đêm thường và đêm cuối tuần**: Duyệt con trỏ `cursor` từng ngày trong khoảng
///    `[checkIn, checkOut)`, đếm số đêm thỏa `cursor.isWeekend` làm `weekendNights`, phần còn lại
///    là `weekdayNights = (nights - weekendNights).clamp(0, nights)`.
/// 3. **Cơ chế giá dự phòng (Fallback) so với giá lịch máy chủ (Server-Override)**:
///    - Bộ tính này dùng `basePriceVnd` cho đêm thường và `saturdayPriceVnd ?? basePrice` cho
///      đêm cuối tuần để ước tính tức thì. Khi `basePriceVnd` là `null` hoặc `<= 0` (giá chưa xác minh),
///      hệ số cơ sở nhận `0` và giao diện bắt buộc kiểm tra điều kiện này để hiển thị nhãn
///      `"Liên hệ nhận báo giá"` thay vì hiển thị giá `0₫`.
///    - Khi tầng chi tiết tải được danh sách `NightlyPrice` từ API lịch máy chủ cho khoảng
///      `[checkIn, checkOut)`, bảng bóc tách giá từng đêm (`DailyPriceBreakdown`) sẽ ưu tiên lấy
///      đơn giá ghi đè từ máy chủ (`serverOverride.priceVnd > 0`) trước khi lùi về giá ngày thường/cuối tuần.
/// 4. **Phụ thu vượt số khách tiêu chuẩn (`includedGuests`)**:
///    `extraGuests = clamp(guestsCount - includedGuests, 0, 100)`, kết hợp phụ thu theo đêm
///    (`extraGuests * extraGuestFeeVnd * nights`) cộng với phụ thu cố định một lần `surchargeAmountVnd`
///    nếu `guestsCount > includedGuests`.
/// 5. **Phí dịch vụ, phí dọn dẹp và giảm giá**: Nếu `serviceFeePct > 0`, phí dịch vụ tính theo tỷ lệ
///    phần trăm làm tròn trên `(roomSubtotal + extraGuestTotal)`, ngược lại lấy mức cố định `serviceFeeVnd`;
///    sau đó cộng `cleaningFeeVnd` và trừ `couponDiscountVnd` (được kẹp trần không vượt tổng gộp `gross`).
///
/// Pure pricing preview calculator matching `Source goc/backend/src/modules/bookings/booking-pricing.service.ts`.
class VillaDetailPricingCalculator {
  VillaDetailPricingCalculator._();

  /// Tính tổng số đêm lưu trú của khoảng nửa mở `[checkIn, checkOut)` (tối thiểu `1` đêm để xem trước giá).
  static int calculateNights(BookingDate? checkIn, BookingDate? checkOut) {
    if (checkIn == null || checkOut == null) return 1;
    final n = checkIn.differenceInNights(checkOut);
    return n > 0 ? n : 1;
  }

  /// Đếm số đêm rơi vào cuối tuần trong khoảng lưu trú nửa mở `[checkIn, checkOut)`.
  static int countWeekendNights(BookingDate? checkIn, BookingDate? checkOut) {
    if (checkIn == null || checkOut == null) return 0;
    // Giải thuật duyệt từng đêm trong khoảng nửa mở [checkIn, checkOut):
    // Bắt đầu từ ngày nhận phòng checkIn, tiến từng bước +1 ngày và dừng ngay khi chạm ngày trả phòng checkOut.
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

  /// Tính toán bản ghi chi tiết toàn bộ cấu phần giá phòng, phụ thu khách, phí dịch vụ, giảm giá và tổng thanh toán.
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
    // Giải thuật tổng hợp chi phí đặt phòng đa thành phần:
    // Bước 1: Tính tổng số đêm, số đêm cuối tuần và suy ra số đêm ngày thường.
    // Bước 2: Nhân đơn giá cơ sở ngày thường (basePriceVnd) và cuối tuần (saturdayPriceVnd ?? basePrice).
    // Bước 3: Tính phụ thu khách vượt ngưỡng includedGuests (theo đầu người * số đêm + phụ phí cố định).
    // Bước 4: Áp phí dọn dẹp, phí dịch vụ (% hoặc cố định) và kẹp biên mã giảm giá trong [0, gross].
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

/// Bộ chuẩn hóa tham số lọc và mã tiện ích tìm kiếm, đồng bộ quy tắc xác thực với
/// `listings.validator.ts`, `filterOptions.ts` và `SearchPage.tsx`.
///
/// Pure query & payload normalizer matching `listings.validator.ts`, `filterOptions.ts`,
/// and `SearchPage.tsx`.
class VillaSearchQueryNormalizer {
  VillaSearchQueryNormalizer._();

  /// Tập hợp các mã loại hình lưu trú hợp lệ được backend chấp nhận.
  static const Set<String> validPropertyTypes = {
    'apartment',
    'villa',
    'hotel',
    'homestay',
  };

  /// Bảng ánh xạ đa biến thể tên tiện ích tiếng Việt (có dấu / không dấu / snake_case) về mã chuẩn backend.
  static const Map<String, String> amenityCodeMap = {
    'pool': 'pool',
    'ho_boi': 'pool',
    'ho_boi_rieng': 'pool',
    'private_pool': 'pool',
    'hồ bơi': 'pool',
    'ho boi': 'pool',
    'hồ bơi riêng': 'pool',
    'hồ bơi nước mặn': 'pool',
    'bếp & bbq': 'kitchen',
    'may giat': 'washer',
    'cho dau xe': 'parking',
    'đậu xe ô tô': 'parking',
    'cho mang thú cưng': 'pet_friendly',
    'thú cưng': 'pet_friendly',
    'có bbq': 'bbq',
    'co bbq': 'bbq',
    'view dep': 'nice_view',
    'tự check-in': 'self_checkin',
    'tu check-in': 'self_checkin',
    'bida': 'billiards',
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

  /// Chuẩn hóa một chuỗi tên hoặc bí danh tiện ích `raw` sang mã định danh chuẩn snake_case.
  static String? normalizeAmenityCode(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) return null;
    if (amenityCodeMap.containsKey(trimmed)) {
      return amenityCodeMap[trimmed];
    }
    final snake = trimmed.replaceAll(RegExp(r'\s+'), '_');
    return amenityCodeMap[snake] ?? snake;
  }

  /// Chuẩn hóa và khử trùng lặp danh sách tiện ích đầu vào `rawAmenities`.
  static List<String> normalizeAmenities(Iterable<String> rawAmenities) {
    return rawAmenities
        .map(normalizeAmenityCode)
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  /// Kiểm tra và trả về mã loại hình lưu trú hợp lệ từ `raw`, hoặc `null` nếu không thuộc danh mục chuẩn.
  static String? normalizePropertyType(String? raw) {
    if (raw == null) return null;
    final clean = raw.trim().toLowerCase();
    return validPropertyTypes.contains(clean) ? clean : null;
  }
}
