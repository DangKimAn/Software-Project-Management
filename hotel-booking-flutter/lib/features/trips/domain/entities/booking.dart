import '../../../../core/date/booking_date.dart';

export 'payment_status_resolver.dart';

/// Đơn giá chi tiết của một đêm lưu trú cụ thể trong bảng bóc tách chi phí đặt phòng.
class BookingNightlyPriceItem {
  /// Ngày lưu trú theo định dạng `YYYY-MM-DD`.
  final String date;

  /// Đơn giá áp dụng cho đêm lưu trú (VND).
  final int amount;

  /// Nguồn cấu hình giá (ví dụ `'base'`, `'weekend'`, hoặc giá tùy chỉnh theo lịch).
  final String source;

  /// Cho biết đêm lưu trú này có rơi vào cuối tuần hay không.
  final bool isWeekend;

  /// Khởi tạo `BookingNightlyPriceItem`.
  const BookingNightlyPriceItem({
    required this.date,
    required this.amount,
    this.source = 'base',
    this.isWeekend = false,
  });

  /// Giải mã đối tượng JSON từng đêm lưu trú thành `BookingNightlyPriceItem`.
  factory BookingNightlyPriceItem.fromJson(Map<String, dynamic> json) {
    return BookingNightlyPriceItem(
      date: (json['date'] ?? '').toString(),
      amount: ((json['amount'] ?? json['price'] ?? 0) as num).round(),
      source: (json['source'] ?? 'base').toString(),
      isWeekend: json['isWeekend'] == true,
    );
  }
}

/// Bảng bóc tách toàn diện chi phí đặt phòng (tiền đêm cơ bản, phụ thu cuối tuần, phụ phí khách thêm,
/// phí dọn dẹp, phí dịch vụ và chiết khấu mã giảm giá).
class BookingPriceBreakdown {
  /// Tổng số đêm lưu trú của kỳ nghỉ.
  final int totalNights;

  /// Số đêm ngày thường trong kỳ nghỉ.
  final int weekdayNights;

  /// Số đêm cuối tuần trong kỳ nghỉ.
  final int weekendNights;

  /// Đơn giá tiêu chuẩn mỗi đêm ngày thường (VND).
  final int nightlyPrice;

  /// Đơn giá áp dụng cho đêm cuối tuần (VND).
  final int weekendPrice;

  /// Danh sách chi tiết đơn giá của từng đêm trong khoảng lưu trú.
  final List<BookingNightlyPriceItem> nightlyPrices;

  /// Tổng tiền phòng tạm tính (đã bao gồm phụ thu cuối tuần).
  final int subtotalAmount;

  /// Tiền phòng cơ bản chưa tách riêng hoặc trước cộng phụ thu cuối tuần.
  final int baseNightsAmount;

  /// Khoản chênh lệch phụ thu cuối tuần (VND).
  final int weekendSurchargeAmount;

  /// Các khoản phụ phí ngày lễ hoặc sự kiện đặc biệt khác (VND).
  final int surchargeAmount;

  /// Phụ phí vượt số lượng khách tiêu chuẩn (VND).
  final int extraGuestFeeAmount;

  /// Phí dọn dẹp vệ sinh một lần cho kỳ lưu trú (VND).
  final int cleaningFee;

  /// Phí dịch vụ vận hành nền tảng (VND).
  final int serviceFee;

  /// Số tiền được giảm nhờ áp dụng mã khuyến mãi (VND).
  final int discountAmount;

  /// Tổng số tiền thanh toán cuối cùng sau khi cộng phí và trừ chiết khấu (VND).
  final int totalAmount;

  /// Mã định danh số nguyên của mã giảm giá đã áp dụng (nếu có).
  final int? couponId;

  /// Chuỗi mã giảm giá đã áp dụng trên đơn đặt phòng (nếu có).
  final String? couponCode;

  /// Khởi tạo `BookingPriceBreakdown`, tự động suy ra `subtotalAmount` nếu không truyền tường minh.
  const BookingPriceBreakdown({
    this.totalNights = 1,
    this.weekdayNights = 1,
    this.weekendNights = 0,
    this.nightlyPrice = 0,
    this.weekendPrice = 0,
    this.nightlyPrices = const [],
    int? subtotalAmount,
    this.baseNightsAmount = 0,
    this.weekendSurchargeAmount = 0,
    this.surchargeAmount = 0,
    this.extraGuestFeeAmount = 0,
    this.cleaningFee = 0,
    this.serviceFee = 0,
    this.discountAmount = 0,
    this.totalAmount = 0,
    this.couponId,
    this.couponCode,
  }) : subtotalAmount =
            subtotalAmount ?? (baseNightsAmount + weekendSurchargeAmount);

  /// Giá trị phí dọn dẹp đồng bộ tên trường với lược đồ API.
  int get cleaningFeeAmount => cleaningFee;

  /// Giá trị phí dịch vụ đồng bộ tên trường với lược đồ API.
  int get serviceFeeAmount => serviceFee;

  /// Giải mã bảng bóc tách giá từ JSON và chống cộng trùng phụ thu cuối tuần vào `subtotalAmount`.
  factory BookingPriceBreakdown.fromJson(Map<String, dynamic> json) {
    final rawSubtotal =
        ((json['subtotalAmount'] ?? json['subtotal']) as num?)?.round();
    final rawBaseNights =
        ((json['baseNightsAmount'] ?? json['roomSubtotal']) as num?)?.round();
    final rawWeekendSurcharge =
        (json['weekendSurchargeAmount'] as num?)?.round() ?? 0;

    final cleaning =
        ((json['cleaningFeeAmount'] ?? json['cleaningFee']) as num?)?.round() ??
            0;
    final service =
        ((json['serviceFeeAmount'] ?? json['serviceFee']) as num?)?.round() ??
            0;
    final surcharge =
        ((json['surchargeAmount'] ?? json['surchargeFee']) as num?)?.round() ??
            0;
    final extraGuest =
        ((json['extraGuestFeeAmount'] ?? json['extraGuestFee']) as num?)
                ?.round() ??
            0;
    final discount =
        ((json['discountAmount'] ?? json['discount']) as num?)?.round() ?? 0;
    final total =
        ((json['totalAmount'] ?? json['finalTotal']) as num?)?.round() ?? 0;

    // When backend provides `subtotalAmount`, it already includes weekend nights pricing.
    // Do NOT double-count weekendSurchargeAmount on top of subtotalAmount, and NEVER return 0
    // for baseNightsAmount when subtotalAmount > 0.
    int resolvedSubtotal;
    int resolvedBaseNights;
    int resolvedWeekendSurcharge;

    if (rawSubtotal != null && rawSubtotal > 0) {
      resolvedSubtotal = rawSubtotal;
      if (rawBaseNights != null &&
          rawBaseNights > 0 &&
          rawBaseNights + rawWeekendSurcharge == rawSubtotal) {
        resolvedBaseNights = rawBaseNights;
        resolvedWeekendSurcharge = rawWeekendSurcharge;
      } else {
        resolvedBaseNights = rawSubtotal;
        resolvedWeekendSurcharge = 0;
      }
    } else if (rawBaseNights != null && rawBaseNights > 0) {
      resolvedBaseNights = rawBaseNights;
      resolvedWeekendSurcharge = rawWeekendSurcharge;
      resolvedSubtotal = rawBaseNights + rawWeekendSurcharge;
    } else {
      final inferredSubtotal =
          (total + discount - cleaning - service - surcharge - extraGuest)
              .clamp(0, 1000000000);
      resolvedSubtotal = inferredSubtotal;
      resolvedBaseNights = inferredSubtotal;
      resolvedWeekendSurcharge = 0;
    }

    final nightlyList = <BookingNightlyPriceItem>[];
    if (json['nightlyPrices'] is List) {
      for (final item in json['nightlyPrices'] as List) {
        if (item is Map<String, dynamic>) {
          nightlyList.add(BookingNightlyPriceItem.fromJson(item));
        } else if (item is Map) {
          nightlyList.add(
            BookingNightlyPriceItem.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final totalNights =
        ((json['totalNights'] ?? json['nights']) as num?)?.toInt() ??
            (nightlyList.isNotEmpty ? nightlyList.length : 1);
    final weekendNights = (json['weekendNights'] as num?)?.toInt() ??
        nightlyList.where((n) => n.isWeekend).length;
    final weekdayNights = (json['weekdayNights'] as num?)?.toInt() ??
        (totalNights - weekendNights).clamp(0, totalNights);

    return BookingPriceBreakdown(
      totalNights: totalNights > 0 ? totalNights : 1,
      weekdayNights: weekdayNights,
      weekendNights: weekendNights,
      nightlyPrice: (json['nightlyPrice'] as num?)?.round() ?? 0,
      weekendPrice: (json['weekendPrice'] as num?)?.round() ?? 0,
      nightlyPrices: nightlyList,
      subtotalAmount: resolvedSubtotal,
      baseNightsAmount: resolvedBaseNights,
      weekendSurchargeAmount: resolvedWeekendSurcharge,
      surchargeAmount: surcharge,
      extraGuestFeeAmount: extraGuest,
      cleaningFee: cleaning,
      serviceFee: service,
      discountAmount: discount,
      totalAmount: total > 0
          ? total
          : (resolvedSubtotal +
                  surcharge +
                  extraGuest +
                  cleaning +
                  service -
                  discount)
              .clamp(0, 1000000000),
      couponId: (json['couponId'] as num?)?.toInt(),
      couponCode: json['couponCode']?.toString(),
    );
  }
}

/// Kết quả thẩm định tính hợp lệ và mức chiết khấu của mã giảm giá từ máy chủ.
class CouponValidationResult {
  /// Cho biết mã giảm giá có đủ điều kiện áp dụng cho đơn đặt phòng hiện tại hay không.
  final bool valid;

  /// Chuỗi mã giảm giá đã chuẩn hóa.
  final String code;

  /// Tiêu đề chương trình khuyến mãi.
  final String? title;

  /// Mô tả chi tiết điều kiện ưu đãi.
  final String? description;

  /// Loại chiết khấu (`'percent'` theo phần trăm hoặc `'fixed_amount'` số tiền cố định).
  final String? discountType; // 'percent' | 'fixed_amount'

  /// Giá trị chiết khấu gốc (phần trăm hoặc số tiền VND).
  final double? discountValue;

  /// Mức giảm tối đa cho phép đối với mã giảm theo phần trăm (VND).
  final int? maxDiscountAmount;

  /// Giá trị đơn hàng tối thiểu để kích hoạt mã giảm giá (VND).
  final int? minOrderValue;

  /// Tổng số lượt sử dụng tối đa của toàn chiến dịch.
  final int? totalLimit;

  /// Số lượt mã đã được sử dụng.
  final int? usedCount;

  /// Giới hạn số lượt sử dụng trên mỗi tài khoản khách hàng.
  final int? limitPerUser;

  /// Thời điểm bắt đầu hiệu lực của mã giảm giá.
  final DateTime? startDate;

  /// Thời điểm kết thúc hiệu lực của mã giảm giá.
  final DateTime? endDate;

  /// Cho biết mã giảm giá có đang ở trạng thái kích hoạt trên hệ thống hay không.
  final bool? isActive;

  /// Số tiền được giảm thực tế trên đơn hàng (luôn bằng `0` nếu `valid` là `false`).
  final int discountAmount;

  /// Tổng tiền đơn hàng dự kiến sau khi trừ chiết khấu.
  final int? finalAmount;

  /// Mã nguyên nhân từ chối thô trả về từ máy chủ khi không hợp lệ.
  final String? reason;

  /// Thông điệp phản hồi hiển thị trực tiếp cho người dùng.
  final String? message;

  /// Khởi tạo `CouponValidationResult`.
  const CouponValidationResult({
    required this.valid,
    required this.code,
    required this.discountAmount,
    this.title,
    this.description,
    this.discountType,
    this.discountValue,
    this.maxDiscountAmount,
    this.minOrderValue,
    this.totalLimit,
    this.usedCount,
    this.limitPerUser,
    this.startDate,
    this.endDate,
    this.isActive,
    this.finalAmount,
    this.reason,
    this.message,
  });

  /// Cho biết mã giảm giá bị từ chối do đã quá hạn sử dụng hay không.
  bool get isExpired => reason?.toLowerCase().contains('expired') == true;

  /// Cho biết mã giảm giá không áp dụng cho chỗ nghỉ đang chọn hay không.
  bool get isListingNotApplicable =>
      reason?.toLowerCase().contains('listing') == true;

  /// Cho biết đơn đặt phòng chưa đạt giá trị tối thiểu của mã giảm giá hay không.
  bool get isMinOrderNotMet =>
      reason?.toLowerCase().contains('minordervalue') == true;

  /// Thông điệp giải thích tiếng Việt ưu tiên hiển thị trên giao diện.
  String? get displayMessage => message ?? localizeRejectionReason(reason);

  /// Chuyển đổi mã nguyên nhân từ chối tiếng Anh/hệ thống `rawReason` sang câu thông báo đa ngôn ngữ (`vi`/`en`/`ko`).
  static String? localizeRejectionReason(
    String? rawReason, {
    String localeCode = 'vi',
  }) {
    if (rawReason == null || rawReason.trim().isEmpty) return null;
    final trimmed = rawReason.trim();
    final lower = trimmed.toLowerCase();
    final lang = localeCode.toLowerCase().split(RegExp('[-_]')).first;

    if (lower.contains('not found') || lower.contains('coupon is invalid')) {
      if (lang == 'en') return 'This promo code is invalid or does not exist.';
      if (lang == 'ko') return '유효하지 않거나 존재하지 않는 프로모션 코드입니다.';
      return 'Mã giảm giá không hợp lệ hoặc không tồn tại.';
    }
    if (lower.contains('inactive')) {
      if (lang == 'en') return 'This promo code is currently inactive.';
      if (lang == 'ko') return '현재 비활성화된 프로모션 코드입니다.';
      return 'Mã giảm giá hiện đang tạm ngưng áp dụng.';
    }
    if (lower.contains('not active yet')) {
      if (lang == 'en') return 'This promo code is not active yet.';
      if (lang == 'ko') return '아직 적용 기간이 시작되지 않은 프로모션 코드입니다.';
      return 'Mã giảm giá chưa đến thời gian áp dụng.';
    }
    if (lower.contains('expired') || lower.contains('expired or not active')) {
      if (lang == 'en') return 'This promo code has expired.';
      if (lang == 'ko') return '만료된 프로모션 코드입니다.';
      return 'Mã giảm giá đã hết hạn.';
    }
    if (lower.contains('user reached coupon usage limit')) {
      if (lang == 'en') {
        return 'You have reached the usage limit for this promo code.';
      }
      if (lang == 'ko') return '이 프로모션 코드의 개인 사용 한도를 초과했습니다.';
      return 'Bạn đã sử dụng hết số lượt cho phép của mã giảm giá này.';
    }
    if (lower.contains('usage limit reached') ||
        lower.contains('usage limit has been reached')) {
      if (lang == 'en') return 'This promo code has reached its usage limit.';
      if (lang == 'ko') return '선착순 사용 한도가 마감된 프로모션 코드입니다.';
      return 'Mã giảm giá đã hết lượt sử dụng.';
    }
    if (lower.contains('minordervalue') ||
        lower.contains('does not meet coupon minimum')) {
      if (lang == 'en') {
        return 'Order total does not meet the minimum value for this promo code.';
      }
      if (lang == 'ko') return '최소 주문 금액 조건을 충족하지 않습니다.';
      return 'Giá trị đơn đặt phòng chưa đạt mức tối thiểu để áp dụng mã này.';
    }
    if (lower.contains('not applicable for this listing')) {
      if (lang == 'en') {
        return 'This promo code does not apply to this property.';
      }
      if (lang == 'ko') return '이 숙소에는 적용할 수 없는 프로모션 코드입니다.';
      return 'Mã giảm giá không áp dụng cho chỗ nghỉ này.';
    }
    if (RegExp(r'^[A-Za-z0-9]+(_[A-Za-z0-9]+)+$').hasMatch(trimmed)) {
      if (lang == 'en') {
        return 'This promo code is not eligible for your booking.';
      }
      if (lang == 'ko') return '현재 예약 조건에 적용할 수 없는 프로모션 코드입니다.';
      return 'Mã giảm giá không đủ điều kiện áp dụng cho đơn đặt phòng này.';
    }
    return trimmed;
  }

  /// Giải mã phản hồi thẩm định mã giảm giá từ JSON, đảm bảo `discountAmount` bằng `0` khi `valid` là `false`.
  factory CouponValidationResult.fromJson(
    Map<String, dynamic> json, {
    String fallbackCode = '',
  }) {
    final isValid = json['valid'] == true;
    final couponMap = json['coupon'] is Map<String, dynamic>
        ? json['coupon'] as Map<String, dynamic>
        : (json['coupon'] is Map
            ? Map<String, dynamic>.from(json['coupon'] as Map)
            : null);

    final rawCode =
        (couponMap?['code'] ?? json['code'] ?? fallbackCode).toString().trim();
    final rawReason = (json['reason'] ?? json['message'])?.toString();
    final rawDiscount = ((json['discountAmount'] ?? 0) as num).round();

    return CouponValidationResult(
      valid: isValid,
      code: rawCode,
      title: (couponMap?['title'] ?? json['title'])?.toString(),
      description:
          (couponMap?['description'] ?? json['description'])?.toString(),
      discountType: (couponMap?['type'] ??
              couponMap?['discountType'] ??
              json['type'] ??
              json['discountType'])
          ?.toString(),
      discountValue:
          ((couponMap?['discountValue'] ?? json['discountValue']) as num?)
              ?.toDouble(),
      maxDiscountAmount: ((couponMap?['maxDiscountAmount'] ??
              json['maxDiscountAmount']) as num?)
          ?.round(),
      minOrderValue:
          ((couponMap?['minOrderValue'] ?? json['minOrderValue']) as num?)
              ?.round(),
      totalLimit:
          ((couponMap?['totalLimit'] ?? json['totalLimit']) as num?)?.toInt(),
      usedCount:
          ((json['usedCount'] ?? couponMap?['usedCount']) as num?)?.toInt(),
      limitPerUser:
          ((couponMap?['limitPerUser'] ?? json['limitPerUser']) as num?)
              ?.toInt(),
      startDate: couponMap?['startDate'] != null
          ? DateTime.tryParse(couponMap!['startDate'].toString())
          : null,
      endDate: couponMap?['endDate'] != null
          ? DateTime.tryParse(couponMap!['endDate'].toString())
          : null,
      isActive:
          (couponMap?['isActive'] as bool?) ?? (json['isActive'] as bool?),
      // Never apply discount if server has not confirmed valid == true.
      discountAmount: isValid && rawDiscount > 0 ? rawDiscount : 0,
      finalAmount: (json['finalAmount'] as num?)?.round(),
      reason: rawReason,
      message: isValid
          ? (json['message']?.toString())
          : (localizeRejectionReason(rawReason) ?? 'Mã giảm giá không hợp lệ.'),
    );
  }
}

/// Thông tin trạng thái cấu hình và khả năng sẵn sàng phục vụ của một phương thức thanh toán trực tuyến.
class PaymentMethodAvailability {
  /// Mã định danh phương thức thanh toán (`'vnpay'` hoặc `'momo'`).
  final String method; // 'vnpay' | 'momo'

  /// Nhãn hiển thị tên cổng thanh toán trên giao diện.
  final String label;

  /// Cho biết cổng thanh toán đã được cấu hình đầy đủ khóa bí mật và sẵn sàng giao dịch hay chưa.
  final bool available;

  /// Danh sách các biến môi trường còn thiếu trên máy chủ (nếu cổng chưa sẵn sàng).
  final List<String> missingConfigKeys;

  /// Lý do giải thích vì sao phương thức thanh toán hiện không khả dụng.
  final String? unavailableReason;

  /// Khởi tạo `PaymentMethodAvailability`.
  const PaymentMethodAvailability({
    required this.method,
    required this.label,
    required this.available,
    this.missingConfigKeys = const [],
    this.unavailableReason,
  });

  /// Bí danh truy cập nhanh lý do không khả dụng `unavailableReason`.
  String? get reason => unavailableReason;

  /// Giải mã đối tượng JSON từ `/api/payments/methods` thành `PaymentMethodAvailability`.
  factory PaymentMethodAvailability.fromJson(Map<String, dynamic> json) {
    final method = (json['method'] ?? 'vnpay').toString().trim().toLowerCase();
    final label =
        (json['label'] ?? (method == 'momo' ? 'MoMo' : 'VNPay')).toString();
    final available = json['available'] == true;
    final missingKeys = <String>[];
    if (json['missingConfigKeys'] is List) {
      for (final k in json['missingConfigKeys'] as List) {
        if (k != null && k.toString().trim().isNotEmpty) {
          missingKeys.add(k.toString().trim());
        }
      }
    }
    return PaymentMethodAvailability(
      method: method,
      label: label,
      available: available,
      missingConfigKeys: missingKeys,
      unavailableReason:
          (json['unavailableReason'] ?? json['reason'])?.toString() ??
              (!available ? '$label chưa được cấu hình trên máy chủ.' : null),
    );
  }
}

/// Thực thể đại diện cho một phiên giao dịch thanh toán gắn với đơn đặt phòng,
/// bao gồm URL chuyển hướng cổng thanh toán, trạng thái đối soát và cờ hoàn tiền khi thanh toán muộn.
class PaymentSessionResult {
  /// Mã định danh phiên thanh toán trên hệ thống.
  final String paymentId;

  /// Mã đơn đặt phòng liên kết với giao dịch này.
  final String bookingId;

  /// Phương thức thanh toán sử dụng (`'vnpay'`, `'momo'`, ...).
  final String method;

  /// Trạng thái bản ghi thanh toán gốc (`'pending'`, `'paid'`, `'failed'`, `'refunded'`, ...).
  final String paymentStatus;

  /// Trạng thái kết quả tổng hợp trả về từ dịch vụ đối soát thanh toán.
  final String paymentResultStatus;

  /// Số tiền giao dịch (VND).
  final int amount;

  /// Đơn vị tiền tệ giao dịch (mặc định `'VND'`).
  final String currency;

  /// Đường dẫn URL chuyển hướng sang cổng thanh toán đối tác (VNPay / MoMo).
  final String? paymentUrl;

  /// Tên nhà cung cấp cổng thanh toán.
  final String? provider;

  /// Mã tham chiếu giao dịch (`TxnRef`) gửi sang cổng thanh toán.
  final String? providerTxnRef;

  /// Mã giao dịch thực tế phát sinh bên phía ngân hàng/ví điện tử đối tác.
  final String? providerTransactionNo;

  /// Mã phản hồi gốc từ cổng thanh toán (ví dụ `'00'` của VNPay).
  final String? providerResponseCode;

  /// Thời điểm cổng thanh toán xác nhận thu tiền thành công.
  final DateTime? paidAt;

  /// Cho biết giao dịch thu tiền thành công sau khi đơn đã hết hạn giữ chỗ và bắt buộc phải hoàn tiền.
  final bool requiresRefund;

  /// Trạng thái tiến trình hoàn tiền (`'pending'`, `'processing'`, `'succeeded'`, `'refunded'`).
  final String? refundStatus;

  /// Nguyên nhân phát sinh giao dịch thanh toán muộn sau khi hết hạn giữ chỗ.
  final String? latePaymentReason;

  /// Thời điểm khởi tạo phiên thanh toán.
  final DateTime? createdAt;

  /// Thời điểm cập nhật bản ghi thanh toán gần nhất.
  final DateTime? updatedAt;

  /// Khởi tạo `PaymentSessionResult`.
  const PaymentSessionResult({
    required this.paymentId,
    required this.bookingId,
    required this.method,
    String? paymentStatus,
    String? status,
    String? paymentResultStatus,
    required this.amount,
    this.currency = 'VND',
    this.paymentUrl,
    this.provider,
    String? providerTxnRef,
    String? transactionRef,
    this.providerTransactionNo,
    this.providerResponseCode,
    this.paidAt,
    this.requiresRefund = false,
    this.refundStatus,
    this.latePaymentReason,
    this.createdAt,
    this.updatedAt,
  })  : paymentStatus = paymentStatus ?? status ?? 'pending',
        paymentResultStatus =
            paymentResultStatus ?? paymentStatus ?? status ?? 'pending',
        providerTxnRef = providerTxnRef ?? transactionRef;

  /// Bí danh trạng thái thanh toán `paymentStatus`.
  String get status => paymentStatus;

  /// Bí danh mã tham chiếu giao dịch `providerTxnRef`.
  String? get transactionRef => providerTxnRef;

  /// Cho biết giao dịch đã được hoàn tiền thành công về phương thức ban đầu hay chưa.
  // Giải thuật phân loại trạng thái hoàn tiền của phiên thanh toán:
  // Kiểm tra trạng thái đã hoàn tiền thành công (`isRefunded`) trước khi xét `isRefundPending`
  // để khi `requiresRefund == true` nhưng `refundStatus == 'succeeded'` thì không bị kẹt ở `refund_pending`.
  // CONFLICT-RESOLVED: Đồng bộ với `payments.service.ts` trả về `paymentResultStatus: "refunded"` khi `refundStatus === "succeeded"`.
  bool get isRefunded =>
      paymentResultStatus == 'refunded' ||
      paymentStatus == 'refunded' ||
      refundStatus == 'succeeded' ||
      refundStatus == 'refunded';

  /// Cho biết giao dịch có đang trong quá trình chờ xử lý hoàn tiền hay không.
  bool get isRefundPending =>
      !isRefunded &&
      (paymentResultStatus == 'refund_pending' ||
          paymentStatus == 'refund_pending' ||
          requiresRefund ||
          refundStatus == 'pending' ||
          refundStatus == 'processing');

  /// Cho biết giao dịch đã thanh toán hợp lệ và không thuộc diện chờ/đã hoàn tiền.
  bool get isPaid => paymentStatus == 'paid' && !isRefundPending && !isRefunded;

  /// Cho biết phiên thanh toán có đang chờ người dùng hoàn tất trên cổng hay không.
  bool get isPending => paymentStatus == 'pending';

  /// Cho biết giao dịch có bị từ chối hoặc thất bại hay không.
  bool get isFailed => paymentStatus == 'failed';

  /// Cho biết người dùng đã hủy giao dịch trên cổng thanh toán hay chưa.
  bool get isCancelled => paymentStatus == 'cancelled';

  /// Cho biết phiên thanh toán đã hết thời hạn giao dịch hay chưa.
  bool get isExpired => paymentStatus == 'expired';

  /// Thông báo tiếng Việt giải thích nguyên nhân thanh toán muộn sau khi hết hạn giữ chỗ.
  String? get latePaymentReasonDisplay =>
      localizeLatePaymentReason(latePaymentReason);

  /// Chuẩn hóa mã lý do thanh toán muộn `rawReason` sang câu giải thích tiếng Việt cho khách hàng.
  static String? localizeLatePaymentReason(String? rawReason) {
    if (rawReason == null || rawReason.trim().isEmpty) return null;
    final trimmed = rawReason.trim();
    final upper = trimmed.toUpperCase();
    if (upper == 'LATE_PAYMENT_AFTER_BOOKING_EXPIRED' ||
        upper == 'PAYMENT_SUCCESS_AFTER_HOLD_EXPIRED' ||
        upper == 'PAYMENT_EXPIRED' ||
        RegExp(r'^[A-Za-z0-9]+(_[A-Za-z0-9]+)+$').hasMatch(trimmed)) {
      return 'Khoản thanh toán được ghi nhận sau khi thời gian giữ chỗ đã hết hạn. Hệ thống đang xử lý hoàn tiền về phương thức thanh toán ban đầu.';
    }
    return trimmed;
  }

  /// Giải mã đối tượng JSON từ API thanh toán thành `PaymentSessionResult`.
  factory PaymentSessionResult.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['paymentStatus'] ?? json['status'] ?? 'pending')
        .toString()
        .trim()
        .toLowerCase();
    final rawResultStatus = (json['paymentResultStatus'] ?? rawStatus)
        .toString()
        .trim()
        .toLowerCase();
    return PaymentSessionResult(
      paymentId: (json['paymentId'] ?? json['id'] ?? '').toString(),
      bookingId: (json['bookingId'] ?? '').toString(),
      method: (json['method'] ?? json['provider'] ?? 'vnpay')
          .toString()
          .trim()
          .toLowerCase(),
      paymentStatus: rawStatus,
      paymentResultStatus: rawResultStatus,
      amount: ((json['amount'] ?? 0) as num).round(),
      currency: (json['currency'] ?? 'VND').toString(),
      paymentUrl: (json['paymentUrl'] ?? json['payUrl'] ?? json['redirectUrl'])
          ?.toString(),
      provider: (json['provider'] ?? json['method'])?.toString(),
      providerTxnRef:
          (json['providerTxnRef'] ?? json['transactionRef'] ?? json['txnRef'])
              ?.toString(),
      providerTransactionNo:
          (json['providerTransactionNo'] ?? json['providerTransactionId'])
              ?.toString(),
      providerResponseCode: json['providerResponseCode']?.toString(),
      paidAt: json['paidAt'] != null
          ? DateTime.tryParse(json['paidAt'].toString())
          : null,
      requiresRefund: json['requiresRefund'] == true,
      refundStatus: json['refundStatus']?.toString(),
      latePaymentReason: json['latePaymentReason']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }
}

/// Chi tiết lỗi xác thực gắn với một dòng mục cụ thể `index` trong yêu cầu đặt nhiều phòng cùng lúc.
class BulkBookingItemError {
  /// Vị trí chỉ mục (bắt đầu từ `0`) của mục đặt phòng gặp lỗi trong danh sách gửi lên.
  final int index;

  /// Tên trường dữ liệu bị lỗi (ví dụ `'checkInDate'`, `'guestCount'`, `'couponCode'`).
  final String? field;

  /// Thông báo lỗi chi tiết cho dòng đặt phòng này.
  final String message;

  /// Khởi tạo `BulkBookingItemError`.
  const BulkBookingItemError({
    required this.index,
    this.field,
    required this.message,
  });
}

/// Ngoại lệ chuyên biệt ném ra khi giao dịch đặt nhiều phòng cùng lúc thất bại ở một hoặc nhiều dòng mục.
class BulkBookingException implements Exception {
  /// Thông báo lỗi tổng quát của yêu cầu đặt phòng hàng loạt.
  final String message;

  /// Danh sách lỗi chi tiết gắn theo từng chỉ mục dòng để hiển thị trực tiếp trên từng thẻ cấu hình.
  final List<BulkBookingItemError> itemErrors;

  /// Khởi tạo `BulkBookingException`.
  const BulkBookingException({
    required this.message,
    this.itemErrors = const [],
  });

  @override
  String toString() => message;
}

/// Thực thể trung tâm biểu diễn một đơn đặt phòng của khách hàng, bao gồm thông tin chỗ nghỉ,
/// lịch nhận/trả phòng, chi phí chi tiết, thời hạn giữ chỗ thanh toán và máy trạng thái vòng đời đơn.
class Booking {
  /// Mã định danh duy nhất của đơn đặt phòng.
  final String id;

  /// Mã định danh chỗ nghỉ/biệt thự được đặt.
  final String listingId;

  /// Tên hiển thị của biệt thự hoặc chỗ nghỉ.
  final String propertyName;

  /// Đường dẫn ảnh bìa đại diện của chỗ nghỉ.
  final String? coverImageUrl;

  /// Ngày nhận phòng theo định dạng `YYYY-MM-DD`.
  final String checkInDate;

  /// Ngày trả phòng theo định dạng `YYYY-MM-DD`.
  final String checkOutDate;

  /// Tổng số đêm lưu trú.
  final int nights;

  /// Tổng số tiền thanh toán cuối cùng của đơn đặt phòng (VND).
  final int totalAmount;

  /// Tiền phòng tạm tính trước phí dọn dẹp, phí dịch vụ và giảm giá (VND).
  final int subtotalAmount;

  /// Phí dọn dẹp vệ sinh (VND).
  final int cleaningFeeAmount;

  /// Phí dịch vụ nền tảng (VND).
  final int serviceFeeAmount;

  /// Số tiền giảm giá từ mã ưu đãi (VND).
  final int discountAmount;

  /// Đơn vị tiền tệ (mặc định `'VND'`).
  final String currency;

  /// Số lượng khách lưu trú đăng ký trong đơn.
  final int guestCount;

  /// Trạng thái đơn đặt phòng trả về từ API.
  final String status;

  /// Trạng thái nội bộ chi tiết của máy trạng thái đặt phòng trên máy chủ (nếu có).
  final String? internalStatus;

  /// Trạng thái thanh toán của đơn (`'unpaid'`, `'paid'`, `'refund_pending'`, `'refunded'`, ...).
  final String paymentStatus;

  /// Trạng thái xử lý hoàn tiền của đơn đặt phòng (nếu phát sinh hoàn tiền).
  final String? refundStatus;

  /// Trạng thái giải ngân doanh thu cho Chủ nhà.
  final String? payoutStatus;

  /// Địa chỉ hiển thị của chỗ nghỉ.
  final String? address;

  /// Mã hoặc nội dung lý do hủy đơn đặt phòng.
  final String? cancellationReason;

  /// Mã định danh người dùng đã thực hiện thao tác hủy đơn.
  final String? cancelledByUserId;

  /// Mã định danh Chủ nhà sở hữu chỗ nghỉ.
  final String? hostUserId;

  /// Mã định danh Khách hàng đặt phòng.
  final String? guestUserId;

  /// Yêu cầu đặc biệt hoặc ghi chú của khách gửi Chủ nhà.
  final String? specialRequests;

  /// Mã giảm giá đã áp dụng cho đơn đặt phòng.
  final String? couponCode;

  /// Thời điểm hết hạn khóa lịch phòng tạm thời (`lockedUntil`).
  final DateTime? lockedUntil;

  /// Thời điểm hết hạn giữ chỗ chờ thanh toán (`paymentExpiresAt`).
  final DateTime? paymentExpiresAt;

  /// Thời điểm bắt đầu mở phiên thanh toán.
  final DateTime? paymentStartedAt;

  /// Thời điểm hoàn tất thanh toán.
  final DateTime? paidAt;

  /// Thời điểm khách thực tế nhận phòng.
  final DateTime? checkedInAt;

  /// Thời điểm khách thực tế trả phòng.
  final DateTime? checkedOutAt;

  /// Thời điểm đơn đặt phòng bị hủy.
  final DateTime? cancelledAt;

  /// Số giây giữ chỗ còn lại do máy chủ tính sẵn tại thời điểm phản hồi (nếu có).
  final int? remainingPaymentSeconds;

  /// Cho biết khách hàng đã gửi đánh giá cho kỳ lưu trú này hay chưa.
  final bool hasReview;

  /// Họ tên hiển thị của Chủ nhà.
  final String? hostName;

  /// Số điện thoại liên hệ của Chủ nhà.
  final String? hostPhone;

  /// Chính sách hoàn hủy áp dụng của chỗ nghỉ (`'flexible'`, `'moderate'`, `'strict'`).
  final String cancellationPolicy;

  /// Đối tượng bóc tách chi tiết cấu thành giá của đơn đặt phòng.
  final BookingPriceBreakdown? priceBreakdown;

  /// Thời điểm tạo đơn đặt phòng.
  final DateTime? createdAt;

  /// Khởi tạo thực thể `Booking`.
  const Booking({
    required this.id,
    required this.listingId,
    required this.propertyName,
    this.coverImageUrl,
    required this.checkInDate,
    required this.checkOutDate,
    required this.nights,
    required this.totalAmount,
    this.subtotalAmount = 0,
    this.cleaningFeeAmount = 0,
    this.serviceFeeAmount = 0,
    this.discountAmount = 0,
    this.currency = 'VND',
    required this.guestCount,
    required this.status,
    this.internalStatus,
    this.paymentStatus = 'unpaid',
    this.refundStatus,
    this.payoutStatus,
    this.address,
    this.cancellationReason,
    this.cancelledByUserId,
    this.hostUserId,
    this.guestUserId,
    this.specialRequests,
    this.couponCode,
    this.lockedUntil,
    this.paymentExpiresAt,
    this.paymentStartedAt,
    this.paidAt,
    this.checkedInAt,
    this.checkedOutAt,
    this.cancelledAt,
    this.remainingPaymentSeconds,
    this.hasReview = false,
    this.hostName,
    this.hostPhone,
    this.cancellationPolicy = 'moderate',
    this.priceBreakdown,
    this.createdAt,
  });

  /// Giải thuật ước tính tỷ lệ và số tiền hoàn trả dự kiến theo chính sách hủy phòng (`flexible` / `moderate` / `strict`),
  /// đối chiếu khoảng cách thời gian thực tới mốc nhận phòng tiêu chuẩn `14:00` giờ Việt Nam (`UTC+7`) đồng bộ với Backend.
  ({int refundPct, int estimatedRefundVnd, String policyKey})
      estimatePolicyRefund({DateTime? now}) {
    final policy = cancellationPolicy.trim().toLowerCase();
    final parsedIn = BookingDate.tryParse(checkInDate.trim());
    double hoursBeforeCheckIn = 0;
    if (parsedIn != null) {
      // Mốc nhận phòng tiêu chuẩn 14:00 ICT (UTC+7) tương đương 07:00 UTC cùng ngày.
      final checkInUtc = DateTime.utc(
        parsedIn.year,
        parsedIn.month,
        parsedIn.day,
        7,
        0,
      );
      final refNow = (now ?? DateTime.now()).toUtc();
      hoursBeforeCheckIn = checkInUtc.difference(refNow).inMinutes / 60.0;
    }

    int pct;
    if (hoursBeforeCheckIn <= 0) {
      pct = 0;
    } else if (policy == 'flexible') {
      pct = hoursBeforeCheckIn >= 24 ? 100 : 50;
    } else if (policy == 'strict') {
      pct = hoursBeforeCheckIn >= 168 ? 50 : 0;
    } else {
      // Chính sách mặc định 'moderate': >= 5 ngày (120h) hoàn 100%, >= 24h hoàn 50%, < 24h hoàn 0%.
      if (hoursBeforeCheckIn >= 120) {
        pct = 100;
      } else if (hoursBeforeCheckIn >= 24) {
        pct = 50;
      } else {
        pct = 0;
      }
    }

    final normalizedPolicy =
        (policy == 'flexible' || policy == 'strict') ? policy : 'moderate';
    final estimated = ((totalAmount * pct) / 100).round();
    return (
      refundPct: pct,
      estimatedRefundVnd: estimated,
      policyKey: normalizedPolicy,
    );
  }

  /// Mốc thời hạn cuối cùng phải hoàn tất thanh toán giữ chỗ (`paymentExpiresAt` ưu tiên hơn `lockedUntil`).
  DateTime? get paymentDeadline => paymentExpiresAt ?? lockedUntil;

  /// Cho biết đơn đặt phòng đã được thanh toán thành công dựa trên `paymentStatus`, `paidAt` hoặc trạng thái vòng đời sau thanh toán.
  bool get isPaid {
    final pStatus = paymentStatus.trim().toLowerCase();
    final rawStatus = (internalStatus ?? status).trim().toLowerCase();
    return pStatus == 'paid' ||
        pStatus == 'completed' ||
        paidAt != null ||
        const {
          'paid',
          'confirmed',
          'checked_in',
          'checked_out',
          'completed',
          'payout_pending',
          'payout_paid',
          'pending_host',
          'pending_host_confirmation',
        }.contains(rawStatus);
  }

  /// Tính số giây giữ chỗ thanh toán còn lại tính từ thời điểm `now` (mặc định là thời gian thực hiện tại),
  /// đảm bảo trả về `0` khi đơn đã thanh toán hoặc đã quá hạn, tuyệt đối không tự đặt lại về `900` giây.
  int computeRemainingPaymentSeconds({DateTime? now}) {
    // Giải thuật tính đếm ngược thời gian giữ chỗ chờ thanh toán:
    // So sánh `paymentDeadline.toUtc()` với mốc `now.toUtc()` theo mili-giây và làm tròn lên (`ceil`) theo giây;
    // nếu không có mốc tuyệt đối mới dùng `remainingPaymentSeconds` dương từ máy chủ.
    if (isPaid) return 0;

    final rawStatus = (internalStatus ?? status).trim().toLowerCase();
    if (rawStatus == 'payment_expired' ||
        rawStatus == 'expired' ||
        cancellationReason?.trim().toUpperCase() == 'PAYMENT_EXPIRED') {
      return 0;
    }

    final deadline = paymentDeadline;
    if (deadline != null) {
      final refNow = (now ?? DateTime.now()).toUtc();
      final diffMs = deadline.toUtc().millisecondsSinceEpoch -
          refNow.millisecondsSinceEpoch;
      if (diffMs <= 0) return 0;
      return (diffMs / 1000).ceil();
    }

    if (remainingPaymentSeconds != null) {
      return remainingPaymentSeconds! > 0 ? remainingPaymentSeconds! : 0;
    }

    return 0;
  }

  /// Kiểm tra xem đơn giữ chỗ chờ thanh toán đã vượt quá thời hạn tại thời điểm `now` hay chưa.
  bool isPaymentExpiredAt([DateTime? now]) {
    final raw = status.trim().toLowerCase();
    final internal = internalStatus?.trim().toLowerCase();
    if (raw == 'payment_expired' ||
        raw == 'expired' ||
        internal == 'payment_expired' ||
        internal == 'expired' ||
        cancellationReason?.trim().toUpperCase() == 'PAYMENT_EXPIRED') {
      return true;
    }

    if (isPaid) return false;

    final isPendingPay = const {
      'pending_payment',
      'pending',
      'awaiting_payment',
      'approved',
    }.contains(raw);

    if (!isPendingPay) return false;

    final deadline = paymentDeadline;
    if (deadline != null) {
      final refNow = (now ?? DateTime.now()).toUtc();
      return !deadline.toUtc().isAfter(refNow);
    }

    if (remainingPaymentSeconds != null && remainingPaymentSeconds! <= 0) {
      return true;
    }

    return false;
  }

  /// Cho biết đơn đặt phòng hiện đã quá thời hạn giữ chỗ thanh toán hay chưa.
  bool get isExpired => isPaymentExpiredAt();

  /// Phân giải mã trạng thái chuẩn hóa có hiệu lực của đơn đặt phòng tại mốc thời gian `now`,
  /// đồng bộ hoàn toàn với máy trạng thái Backend (`bookingStatus.ts` & `booking-state-machine.ts`).
  String effectiveStatusAt([DateTime? now]) {
    // Giải thuật chuẩn hóa trạng thái hiệu lực của đặt phòng (Effective Booking Status):
    // 1. Ưu tiên ánh xạ trạng thái hoàn tiền (`refundStatus == 'succeeded'` -> `'refunded'`;
    //    `pending`/`processing` trên đơn hủy/từ chối/hết hạn -> `'refund_pending'`).
    // 2. Đối với đơn ở trạng thái `'paid'` có ngày hiện tại theo múi giờ Việt Nam (`UTC+7`)
    //    `today >= checkOutDate` (và không bị hủy/hoàn tiền), tự động chuyển sang `'completed'`
    //    để lịch sử lưu trú đã qua không bị kẹt ở nhóm "Sắp tới".
    // CONFLICT-RESOLVED: Đồng bộ logic auto-advance `paid -> completed` khi qua `checkOutDate` với `bookings.service.ts` và chuẩn hóa `refundStatus`.
    final refStatus = refundStatus?.trim().toLowerCase();
    final payStatus = paymentStatus.trim().toLowerCase();
    final raw = status.trim().toLowerCase();
    final internal = internalStatus?.trim().toLowerCase();

    if (refStatus == 'succeeded' ||
        refStatus == 'refunded' ||
        payStatus == 'refunded' ||
        raw == 'refunded') {
      return 'refunded';
    }

    if (raw == 'refund_pending' || payStatus == 'refund_pending') {
      return 'refund_pending';
    }

    String resolved = internal != null && internal.isNotEmpty ? internal : raw;

    if (resolved == 'expired' || isPaymentExpiredAt(now)) {
      resolved = 'payment_expired';
    } else if (resolved == 'host_cancelled') {
      resolved = 'cancelled_by_host';
    } else if (resolved == 'cancelled') {
      final reasonUpper = cancellationReason?.trim().toUpperCase();
      if (reasonUpper == 'PAYMENT_EXPIRED') {
        resolved = 'payment_expired';
      } else if (reasonUpper == 'ADMIN_CANCELLED') {
        resolved = 'cancelled_by_admin';
      } else if (reasonUpper == 'HOST_REJECTED') {
        resolved = 'rejected';
      } else if (cancelledByUserId != null &&
          hostUserId != null &&
          cancelledByUserId!.isNotEmpty &&
          cancelledByUserId == hostUserId) {
        resolved = 'cancelled_by_host';
      } else {
        resolved = 'cancelled_by_guest';
      }
    } else if (resolved == 'pending_host' ||
        resolved == 'pending_host_confirmation') {
      resolved = 'paid';
    } else if (resolved == 'pending' ||
        resolved == 'awaiting_payment' ||
        resolved == 'approved' ||
        resolved == 'pending_payment') {
      resolved = isPaid ? 'paid' : 'pending_payment';
    } else if (resolved == 'payout_pending' || resolved == 'payout_paid') {
      // Guest perspective maps payout statuses to checked_out (`bookingStatus.ts` line 233)
      resolved = 'checked_out';
    }

    final isTerminalOrExpired = const {
      'cancelled_by_guest',
      'cancelled_by_host',
      'cancelled_by_admin',
      'rejected',
      'payment_expired',
    }.contains(resolved);

    final isRawCancelledOrExpired = const {
      'cancelled',
      'cancelled_by_guest',
      'cancelled_by_host',
      'cancelled_by_admin',
      'host_cancelled',
      'rejected',
      'expired',
      'payment_expired',
    }.contains(raw);

    if ((isTerminalOrExpired || isRawCancelledOrExpired) &&
        (refStatus == 'pending' || refStatus == 'processing')) {
      return 'refund_pending';
    }

    if (resolved == 'paid') {
      final parsedCheckOut = BookingDate.tryParse(checkOutDate.trim());
      if (parsedCheckOut != null) {
        final vnNow =
            (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
        final todayVn = BookingDate(
          year: vnNow.year,
          month: vnNow.month,
          day: vnNow.day,
        );
        if (!todayVn.isBefore(parsedCheckOut)) {
          return 'completed';
        }
      }
    }

    return resolved;
  }

  /// Mã trạng thái hiệu lực hiện tại của đơn đặt phòng tại thời điểm hệ thống.
  String get effectiveStatus => effectiveStatusAt();

  /// Cho biết đơn đặt phòng thuộc nhóm đã hủy, bị từ chối, quá hạn thanh toán hoặc đang/đã hoàn tiền.
  bool get isCancelled {
    final eff = effectiveStatus;
    return const {
      'cancelled',
      'cancelled_by_guest',
      'cancelled_by_host',
      'cancelled_by_admin',
      'host_cancelled',
      'rejected',
      'expired',
      'payment_expired',
      'refund_pending',
      'refunded',
    }.contains(eff);
  }

  /// Cho biết kỳ lưu trú đã hoàn tất hoặc khách đã trả phòng.
  bool get isCompleted {
    if (isCancelled) return false;
    final eff = effectiveStatus;
    return eff == 'completed' ||
        eff == 'checked_out' ||
        eff == 'payout_pending' ||
        eff == 'payout_paid';
  }

  /// Cho biết đơn đặt phòng đang hoạt động (sắp tới hoặc đang lưu trú, chưa hủy và chưa hoàn tất).
  bool get isActive => !isCancelled && !isCompleted;

  /// Cho biết khách hàng có thể thực hiện thanh toán ngay cho đơn này hay không
  /// (chỉ cho phép khi `effectiveStatus` là `'pending_payment'`, chưa quá hạn và không đang xử lý giao dịch).
  bool get canPayNow {
    if (isPaid || isExpired || isCancelled || isCompleted) {
      return false;
    }
    final pStatus = paymentStatus.trim().toLowerCase();
    if (pStatus == 'processing') {
      return false;
    }
    return effectiveStatus == 'pending_payment';
  }

  /// Cho biết khách hàng có quyền chủ động hủy đơn đặt phòng ở trạng thái hiện tại hay không
  /// (chỉ hợp lệ khi đơn đang ở `'pending_payment'`, `'paid'` hoặc `'confirmed'`).
  bool get canCancel {
    if (isCancelled || isCompleted || isExpired) {
      return false;
    }
    return const {
      'pending_payment',
      'paid',
      'confirmed',
    }.contains(effectiveStatus);
  }

  /// Cho biết khách hàng đủ điều kiện viết đánh giá cho chuyến đi đã hoàn thành này hay chưa.
  bool get canReview => isCompleted && !hasReview;

  /// Cho biết đơn đặt phòng đã kết thúc vòng đời (hoàn thành hoặc đã hủy) để hiển thị nút đặt lại hay chưa.
  bool get canRebook => isCompleted || isCancelled;

  // CONFLICT-RESOLVED: Hợp nhất tham số tùy chọn `localeCode` từ `origin/develop` để hỗ trợ đa ngôn ngữ VI/EN/KO với tài liệu Dartdoc của nhánh refactor.
  /// Trả về nhãn trạng thái thân thiện theo ngôn ngữ `localeCode` ứng với thời điểm `now`.
  String statusDisplayAt([DateTime? now, String? localeCode]) {
    final raw = status.trim().toLowerCase();
    final eff = effectiveStatusAt(now);
    final isEn = localeCode == 'en' ||
        (localeCode != null && localeCode.startsWith('en'));
    final isKo = localeCode == 'ko' ||
        (localeCode != null && localeCode.startsWith('ko'));

    if (eff == 'refunded') {
      if (isEn) return 'Refunded';
      if (isKo) return '환불 완료';
      return 'Đã hoàn tiền';
    }
    if (eff == 'refund_pending') {
      if (isEn) return 'Refund pending';
      if (isKo) return '환불 대기 중';
      return 'Đang chờ hoàn tiền';
    }
    if (eff == 'payment_expired') {
      if (isEn) return 'Payment expired';
      if (isKo) return '결제 기한 만료';
      return 'Quá hạn thanh toán';
    }
    if (eff == 'cancelled_by_host') {
      if (isEn) return 'Cancelled by host';
      if (isKo) return '호스트 취소';
      return 'Host đã hủy';
    }
    if (eff == 'cancelled_by_admin') {
      if (isEn) return 'Cancelled by admin';
      if (isKo) return '관리자 취소';
      return 'Admin đã hủy';
    }
    if (eff == 'rejected') {
      if (isEn) return 'Host rejected';
      if (isKo) return '호스트 거절';
      return 'Host đã từ chối';
    }
    if (eff == 'cancelled_by_guest') {
      // Preserve legacy 'Đã hủy' only when raw status was generic 'cancelled'
      // while returning 'Khách đã hủy' for canonical 'cancelled_by_guest'.
      if (isEn) return raw == 'cancelled' ? 'Cancelled' : 'Cancelled by guest';
      if (isKo) return raw == 'cancelled' ? '취소됨' : '게스트 취소';
      return raw == 'cancelled' ? 'Đã hủy' : 'Khách đã hủy';
    }

    switch (eff) {
      case 'pending_payment':
        if (isEn) return 'Pending payment';
        if (isKo) return '결제 대기';
        return 'Chờ thanh toán';
      case 'paid':
        if (isEn) return 'Payment successful';
        if (isKo) return '결제 완료';
        return 'Thanh toán thành công';
      case 'confirmed':
        if (isEn) return 'Confirmed';
        if (isKo) return '예약 확정';
        return 'Đã xác nhận';
      case 'checked_in':
        if (isEn) return 'Checked in';
        if (isKo) return '체크인 완료';
        return 'Đã nhận phòng';
      case 'checked_out':
        if (isEn) return raw == 'completed' ? 'Completed' : 'Checked out';
        if (isKo) return raw == 'completed' ? '이용 완료' : '체크아웃 완료';
        return raw == 'completed' ? 'Đã hoàn thành' : 'Đã trả phòng';
      case 'completed':
        if (isEn) return 'Completed';
        if (isKo) return '이용 완료';
        return 'Đã hoàn thành';
      default:
        if (isEn) return 'Processing';
        if (isKo) return '처리 중';
        return 'Đang xử lý';
    }
  }

  /// Nhãn trạng thái tiếng Việt tại thời điểm hiện tại.
  String get statusDisplay => statusDisplayAt();

  // CONFLICT-RESOLVED: Giữ cả hàm tiện ích đa ngôn ngữ `statusDisplayFor`, `cancellationReasonDisplayFor` từ `origin/develop` và tài liệu Dartdoc của nhánh refactor.
  /// Trả về nhãn trạng thái theo mã ngôn ngữ `localeCode` tại thời điểm `now`.
  String statusDisplayFor(String? localeCode, [DateTime? now]) =>
      statusDisplayAt(now, localeCode);

  /// Nội dung lý do hủy đơn đã được bản địa hóa sang tiếng Việt mặc định.
  String? get cancellationReasonDisplay =>
      localizeCancellationReason(cancellationReason);

  /// Nội dung lý do hủy đơn đã được bản địa hóa theo ngôn ngữ `localeCode`.
  String? cancellationReasonDisplayFor(String? localeCode) =>
      localizeCancellationReason(cancellationReason, localeCode);

  /// Chuyển đổi mã lý do hủy đơn hệ thống `rawReason` sang thông điệp rõ nghĩa theo `localeCode`.
  static String? localizeCancellationReason(
    String? rawReason, [
    String? localeCode,
  ]) {
    if (rawReason == null || rawReason.trim().isEmpty) return null;
    final trimmed = rawReason.trim();
    final upper = trimmed.toUpperCase();
    final isEn = localeCode == 'en' ||
        (localeCode != null && localeCode.startsWith('en'));
    final isKo = localeCode == 'ko' ||
        (localeCode != null && localeCode.startsWith('ko'));

    switch (upper) {
      case 'PAYMENT_EXPIRED':
      case 'EXPIRED':
      case 'HOLD_EXPIRED':
        if (isEn) return 'Payment window expired (system auto-released hold)';
        if (isKo) return '결제 기한 만료 (자동 예약 취소)';
        return 'Quá thời hạn thanh toán (hệ thống tự động hủy giữ chỗ)';
      case 'CUSTOMER_CANCELLED':
      case 'CANCELLED_BY_GUEST':
      case 'GUEST_CANCELLED':
      case 'USER_CANCELLED':
        if (isEn) return 'Guest cancelled booking';
        if (isKo) return '게스트 예약 취소';
        return 'Khách hàng chủ động hủy đặt phòng';
      case 'HOST_REJECTED':
      case 'REJECTED':
      case 'REJECTED_BY_HOST':
        if (isEn) return 'Host rejected booking request';
        if (isKo) return '호스트 예약 거절';
        return 'Chủ nhà từ chối yêu cầu đặt phòng';
      case 'HOST_CANCELLED':
      case 'CANCELLED_BY_HOST':
        if (isEn) return 'Host cancelled booking';
        if (isKo) return '호스트 예약 취소';
        return 'Chủ nhà đã hủy đặt phòng';
      case 'ADMIN_CANCELLED':
      case 'CANCELLED_BY_ADMIN':
        if (isEn) return 'Admin cancelled booking';
        if (isKo) return '관리자 예약 취소';
        return 'Quản trị viên đã hủy đặt phòng';
      case 'LATE_PAYMENT_AFTER_BOOKING_EXPIRED':
      case 'PAYMENT_SUCCESS_AFTER_HOLD_EXPIRED':
        if (isEn) return 'Payment made after hold window expired';
        if (isKo) return '예약 대기 시간 만료 후 결제됨';
        return 'Thanh toán phát sinh sau khi đã hết thời gian giữ chỗ';
      case 'SYSTEM_CANCELLED':
      case 'AUTO_CANCELLED':
        if (isEn) return 'System auto-cancelled booking';
        if (isKo) return '시스템 자동 취소';
        return 'Hệ thống tự động hủy đặt phòng';
    }
    if (RegExp(r'^[A-Za-z0-9]+(_[A-Za-z0-9]+)+$').hasMatch(trimmed)) {
      if (isEn) return 'Booking cancelled according to system policy';
      if (isKo) return '시스템 규정에 따라 예약이 취소되었습니다';
      return 'Đơn đặt phòng đã bị hủy theo quy định hệ thống';
    }
    return trimmed;
  }

  /// Phân loại sắc thái màu hiển thị huy hiệu trạng thái (`'warning'`, `'success'`, `'info'`, `'muted'`, `'danger'`).
  String get statusTone {
    final eff = effectiveStatus;
    switch (eff) {
      case 'pending_payment':
      case 'refund_pending':
        return 'warning';
      case 'paid':
      case 'confirmed':
      case 'completed':
      case 'refunded':
        return 'success';
      case 'checked_in':
      case 'checked_out':
        return 'info';
      case 'cancelled_by_guest':
        return 'muted';
      case 'payment_expired':
      case 'cancelled_by_host':
      case 'cancelled_by_admin':
      case 'rejected':
      default:
        return 'danger';
    }
  }

  /// Giải mã đối tượng JSON từ API thành thực thể `Booking`, tự động nội suy số đêm, địa chỉ,
  /// ảnh bìa chỗ nghỉ và hợp nhất bảng bóc tách giá `BookingPriceBreakdown`.
  factory Booking.fromJson(Map<String, dynamic> json) {
    final listing = json['listing'] is Map<String, dynamic>
        ? json['listing'] as Map<String, dynamic>
        : (json['listing'] is Map
            ? Map<String, dynamic>.from(json['listing'] as Map)
            : null);

    final listingTitle = listing?['title']?.toString() ??
        json['listingTitle']?.toString() ??
        json['propertyName']?.toString() ??
        'Chỗ nghỉ #${json['listingId'] ?? ''}';

    String? coverImg;
    if (listing != null) {
      coverImg = listing['coverImageUrl']?.toString() ??
          (listing['coverImage'] is Map
              ? listing['coverImage']['url']?.toString()
              : null) ??
          (listing['images'] is List && (listing['images'] as List).isNotEmpty
              ? ((listing['images'] as List).first is Map
                  ? (listing['images'] as List).first['url']?.toString()
                  : (listing['images'] as List).first?.toString())
              : null) ??
          listing['imageUrl']?.toString();
    }
    coverImg ??= json['imageUrl']?.toString() ?? json['coverImage']?.toString();

    final checkIn = (json['checkInDate'] ?? json['checkIn'] ?? '').toString();
    final checkOut =
        (json['checkOutDate'] ?? json['checkOut'] ?? '').toString();

    int calculatedNights =
        ((json['nights'] ?? json['totalNights']) as num?)?.toInt() ?? 0;
    if (checkIn.isNotEmpty && checkOut.isNotEmpty && calculatedNights <= 0) {
      final inD = DateTime.tryParse(checkIn);
      final outD = DateTime.tryParse(checkOut);
      if (inD != null && outD != null) {
        calculatedNights = outD.difference(inD).inDays;
      }
    }
    final resolvedNights = calculatedNights > 0 ? calculatedNights : 1;

    final total =
        ((json['totalAmount'] ?? json['totalPrice']) as num?)?.round() ?? 0;
    final subtotal = ((json['subtotalAmount'] ??
                json['roomSubtotal'] ??
                json['baseNightsAmount']) as num?)
            ?.round() ??
        0;
    final cleaningFee =
        ((json['cleaningFeeAmount'] ?? json['cleaningFee']) as num?)?.round() ??
            0;
    final serviceFee =
        ((json['serviceFeeAmount'] ?? json['serviceFee']) as num?)?.round() ??
            0;
    final discount =
        ((json['discountAmount'] ?? json['discount']) as num?)?.round() ?? 0;

    BookingPriceBreakdown breakdown;
    if (json['priceBreakdown'] is Map) {
      final rawPb = Map<String, dynamic>.from(json['priceBreakdown'] as Map);
      // Merge top-level pricing fields as fallbacks if missing inside priceBreakdown
      if (rawPb['subtotalAmount'] == null &&
          rawPb['subtotal'] == null &&
          rawPb['baseNightsAmount'] == null &&
          rawPb['roomSubtotal'] == null &&
          subtotal > 0) {
        rawPb['subtotalAmount'] = subtotal;
      }
      rawPb['cleaningFeeAmount'] ??= cleaningFee;
      rawPb['serviceFeeAmount'] ??= serviceFee;
      rawPb['discountAmount'] ??= discount;
      rawPb['totalAmount'] ??= total;
      rawPb['totalNights'] ??= resolvedNights;
      breakdown = BookingPriceBreakdown.fromJson(rawPb);
    } else {
      breakdown = BookingPriceBreakdown.fromJson({
        'totalNights': resolvedNights,
        if (subtotal > 0) 'subtotalAmount': subtotal,
        'weekendSurchargeAmount':
            (json['weekendSurchargeAmount'] as num?)?.round() ?? 0,
        'surchargeAmount':
            ((json['surchargeAmount'] ?? json['surchargeFee']) as num?)
                    ?.round() ??
                0,
        'extraGuestFeeAmount':
            ((json['extraGuestFeeAmount'] ?? json['extraGuestFee']) as num?)
                    ?.round() ??
                0,
        'cleaningFeeAmount': cleaningFee,
        'serviceFeeAmount': serviceFee,
        'discountAmount': discount,
        'totalAmount': total,
        if (json['couponCode'] != null) 'couponCode': json['couponCode'],
      });
    }

    final hostMap = json['host'] is Map<String, dynamic>
        ? json['host'] as Map<String, dynamic>
        : (listing?['host'] is Map<String, dynamic>
            ? listing!['host'] as Map<String, dynamic>
            : null);

    String? resolvedAddress = listing?['addressLine']?.toString() ??
        listing?['address']?.toString() ??
        json['address']?.toString();
    if ((resolvedAddress == null || resolvedAddress.trim().isEmpty) &&
        listing != null) {
      final parts = [
        listing['addressLine'],
        listing['district'],
        listing['city'],
      ]
          .where((e) => e != null && e.toString().trim().isNotEmpty)
          .map((e) => e.toString().trim())
          .toList();
      if (parts.isNotEmpty) {
        resolvedAddress = parts.join(', ');
      }
    }

    return Booking(
      id: (json['bookingId'] ?? json['id'])?.toString() ?? '',
      listingId: (json['listingId'] ?? listing?['listingId'])?.toString() ?? '',
      propertyName: listingTitle,
      coverImageUrl: coverImg,
      checkInDate: checkIn,
      checkOutDate: checkOut,
      nights: resolvedNights,
      totalAmount: total > 0 ? total : breakdown.totalAmount,
      subtotalAmount: subtotal > 0 ? subtotal : breakdown.subtotalAmount,
      cleaningFeeAmount: cleaningFee > 0 ? cleaningFee : breakdown.cleaningFee,
      serviceFeeAmount: serviceFee > 0 ? serviceFee : breakdown.serviceFee,
      discountAmount: discount > 0 ? discount : breakdown.discountAmount,
      currency: (json['currency'] ?? listing?['currency'] ?? 'VND').toString(),
      guestCount: ((json['guestCount'] ?? json['guestsCount'] ?? json['guests'])
                  as num?)
              ?.toInt() ??
          1,
      status: (json['status'] ?? 'pending_payment').toString(),
      internalStatus: json['internalStatus']?.toString(),
      paymentStatus:
          (json['paymentStatus'] ?? json['payment_status'] ?? 'unpaid')
              .toString(),
      refundStatus: (json['refundStatus'] ?? json['refund_status'])?.toString(),
      payoutStatus: (json['payoutStatus'] ?? json['payout_status'])?.toString(),
      address: resolvedAddress,
      cancellationReason:
          (json['cancellationReason'] ?? json['reason'])?.toString(),
      cancelledByUserId: json['cancelledByUserId']?.toString(),
      hostUserId: (json['hostUserId'] ??
              json['hostId'] ??
              listing?['hostId'] ??
              hostMap?['id'])
          ?.toString(),
      guestUserId: (json['guestUserId'] ?? json['guestId'])?.toString(),
      specialRequests:
          (json['specialRequests'] ?? json['bookingNote'])?.toString(),
      couponCode: (json['couponCode'] ?? breakdown.couponCode)?.toString(),
      lockedUntil: json['lockedUntil'] != null
          ? DateTime.tryParse(json['lockedUntil'].toString())
          : null,
      paymentExpiresAt: json['paymentExpiresAt'] != null
          ? DateTime.tryParse(json['paymentExpiresAt'].toString())
          : null,
      paymentStartedAt: json['paymentStartedAt'] != null
          ? DateTime.tryParse(json['paymentStartedAt'].toString())
          : null,
      paidAt: json['paidAt'] != null
          ? DateTime.tryParse(json['paidAt'].toString())
          : null,
      checkedInAt: json['checkedInAt'] != null
          ? DateTime.tryParse(json['checkedInAt'].toString())
          : null,
      checkedOutAt: json['checkedOutAt'] != null
          ? DateTime.tryParse(json['checkedOutAt'].toString())
          : null,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.tryParse(json['cancelledAt'].toString())
          : null,
      remainingPaymentSeconds:
          (json['remainingPaymentSeconds'] as num?)?.toInt(),
      hasReview: json['hasReview'] == true || json['review'] != null,
      hostName: hostMap?['fullName']?.toString() ??
          hostMap?['name']?.toString() ??
          json['hostName']?.toString(),
      hostPhone: hostMap?['phone']?.toString() ?? json['hostPhone']?.toString(),
      cancellationPolicy: (listing?['cancellationPolicy'] ??
              json['cancellationPolicy'] ??
              'moderate')
          .toString(),
      priceBreakdown: breakdown,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}
