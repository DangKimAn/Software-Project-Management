class BookingNightlyPriceItem {
  final String date;
  final int amount;
  final String source;
  final bool isWeekend;

  const BookingNightlyPriceItem({
    required this.date,
    required this.amount,
    this.source = 'base',
    this.isWeekend = false,
  });

  factory BookingNightlyPriceItem.fromJson(Map<String, dynamic> json) {
    return BookingNightlyPriceItem(
      date: (json['date'] ?? '').toString(),
      amount: ((json['amount'] ?? json['price'] ?? 0) as num).round(),
      source: (json['source'] ?? 'base').toString(),
      isWeekend: json['isWeekend'] == true,
    );
  }
}

class BookingPriceBreakdown {
  final int totalNights;
  final int weekdayNights;
  final int weekendNights;
  final int nightlyPrice;
  final int weekendPrice;
  final List<BookingNightlyPriceItem> nightlyPrices;
  final int subtotalAmount;
  final int baseNightsAmount;
  final int weekendSurchargeAmount;
  final int surchargeAmount;
  final int extraGuestFeeAmount;
  final int cleaningFee;
  final int serviceFee;
  final int discountAmount;
  final int totalAmount;
  final int? couponId;
  final String? couponCode;

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

  int get cleaningFeeAmount => cleaningFee;
  int get serviceFeeAmount => serviceFee;

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

class CouponValidationResult {
  final bool valid;
  final String code;
  final String? title;
  final String? description;
  final String? discountType; // 'percent' | 'fixed_amount'
  final double? discountValue;
  final int? maxDiscountAmount;
  final int? minOrderValue;
  final int? totalLimit;
  final int? usedCount;
  final int? limitPerUser;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool? isActive;
  final int discountAmount;
  final int? finalAmount;
  final String? reason;
  final String? message;

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

  bool get isExpired => reason?.toLowerCase().contains('expired') == true;

  bool get isListingNotApplicable =>
      reason?.toLowerCase().contains('listing') == true;

  bool get isMinOrderNotMet =>
      reason?.toLowerCase().contains('minordervalue') == true;

  String? get displayMessage => message ?? localizeRejectionReason(reason);

  static String? localizeRejectionReason(String? rawReason) {
    if (rawReason == null || rawReason.trim().isEmpty) return null;
    final trimmed = rawReason.trim();
    final lower = trimmed.toLowerCase();
    if (lower.contains('not found')) {
      return 'Không tìm thấy mã giảm giá này.';
    }
    if (lower.contains('inactive')) {
      return 'Mã giảm giá hiện đang tạm ngưng áp dụng.';
    }
    if (lower.contains('not active yet')) {
      return 'Mã giảm giá chưa đến thời gian áp dụng.';
    }
    if (lower.contains('expired')) {
      return 'Mã giảm giá đã hết hạn.';
    }
    if (lower.contains('usage limit reached')) {
      return 'Mã giảm giá đã hết lượt sử dụng.';
    }
    if (lower.contains('minordervalue')) {
      return 'Giá trị đơn đặt phòng chưa đạt mức tối thiểu để áp dụng mã này.';
    }
    if (lower.contains('user reached coupon usage limit')) {
      return 'Bạn đã sử dụng hết số lượt cho phép của mã giảm giá này.';
    }
    if (lower.contains('not applicable for this listing')) {
      return 'Mã giảm giá không áp dụng cho chỗ nghỉ này.';
    }
    return trimmed;
  }

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

class PaymentMethodAvailability {
  final String method; // 'vnpay' | 'momo'
  final String label;
  final bool available;
  final List<String> missingConfigKeys;
  final String? unavailableReason;

  const PaymentMethodAvailability({
    required this.method,
    required this.label,
    required this.available,
    this.missingConfigKeys = const [],
    this.unavailableReason,
  });

  String? get reason => unavailableReason;

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

class PaymentSessionResult {
  final String paymentId;
  final String bookingId;
  final String method;
  final String paymentStatus;
  final String paymentResultStatus;
  final int amount;
  final String currency;
  final String? paymentUrl;
  final String? provider;
  final String? providerTxnRef;
  final String? providerTransactionNo;
  final String? providerResponseCode;
  final DateTime? paidAt;
  final bool requiresRefund;
  final String? refundStatus;
  final String? latePaymentReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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

  String get status => paymentStatus;
  String? get transactionRef => providerTxnRef;

  bool get isRefundPending =>
      paymentResultStatus == 'refund_pending' ||
      requiresRefund ||
      refundStatus == 'pending' ||
      refundStatus == 'processing';

  bool get isRefunded =>
      paymentStatus == 'refunded' ||
      refundStatus == 'succeeded' ||
      refundStatus == 'refunded';

  bool get isPaid => paymentStatus == 'paid' && !isRefundPending && !isRefunded;

  bool get isPending => paymentStatus == 'pending';
  bool get isFailed => paymentStatus == 'failed';
  bool get isCancelled => paymentStatus == 'cancelled';
  bool get isExpired => paymentStatus == 'expired';

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

class BulkBookingItemError {
  final int index;
  final String? field;
  final String message;

  const BulkBookingItemError({
    required this.index,
    this.field,
    required this.message,
  });
}

class BulkBookingException implements Exception {
  final String message;
  final List<BulkBookingItemError> itemErrors;

  const BulkBookingException({
    required this.message,
    this.itemErrors = const [],
  });

  @override
  String toString() => message;
}

class Booking {
  final String id;
  final String listingId;
  final String propertyName;
  final String? coverImageUrl;
  final String checkInDate;
  final String checkOutDate;
  final int nights;
  final int totalAmount;
  final int subtotalAmount;
  final int cleaningFeeAmount;
  final int serviceFeeAmount;
  final int discountAmount;
  final String currency;
  final int guestCount;
  final String status;
  final String? internalStatus;
  final String paymentStatus;
  final String? refundStatus;
  final String? payoutStatus;
  final String? address;
  final String? cancellationReason;
  final String? cancelledByUserId;
  final String? hostUserId;
  final String? guestUserId;
  final String? specialRequests;
  final String? couponCode;
  final DateTime? lockedUntil;
  final DateTime? paymentExpiresAt;
  final DateTime? paymentStartedAt;
  final DateTime? paidAt;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final DateTime? cancelledAt;
  final int? remainingPaymentSeconds;
  final bool hasReview;
  final String? hostName;
  final String? hostPhone;
  final BookingPriceBreakdown? priceBreakdown;
  final DateTime? createdAt;

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
    this.priceBreakdown,
    this.createdAt,
  });

  DateTime? get paymentDeadline => paymentExpiresAt ?? lockedUntil;

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

  /// Calculates remaining hold seconds without EVER resetting 0 or expired deadlines to 900.
  int computeRemainingPaymentSeconds({DateTime? now}) {
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

  bool get isExpired => isPaymentExpiredAt();

  /// Resolves the canonical booking status code matching `bookingStatus.ts` & `booking-state-machine.ts`.
  String effectiveStatusAt([DateTime? now]) {
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

    if (raw == 'refund_pending') {
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

    if (isTerminalOrExpired &&
        (refStatus == 'pending' || refStatus == 'processing')) {
      return 'refund_pending';
    }

    return resolved;
  }

  String get effectiveStatus => effectiveStatusAt();

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

  bool get isCompleted {
    if (isCancelled) return false;
    final eff = effectiveStatus;
    return eff == 'completed' ||
        eff == 'checked_out' ||
        eff == 'payout_pending' ||
        eff == 'payout_paid';
  }

  bool get isActive => !isCancelled && !isCompleted;

  /// Guest can pay now ONLY when status is `pending_payment`, not already paid,
  /// not expired, and payment is not currently processing.
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

  /// Guest can cancel ONLY in `pending_payment`, `paid`, or `confirmed` states (`booking-state-machine.ts`).
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

  bool get canReview => isCompleted && !hasReview;

  bool get canRebook => isCompleted || isCancelled;

  String statusDisplayAt([DateTime? now]) {
    final raw = status.trim().toLowerCase();
    final eff = effectiveStatusAt(now);

    if (eff == 'refunded') return 'Đã hoàn tiền';
    if (eff == 'refund_pending') return 'Đang chờ hoàn tiền';
    if (eff == 'payment_expired') return 'Quá hạn thanh toán';
    if (eff == 'cancelled_by_host') return 'Host đã hủy';
    if (eff == 'cancelled_by_admin') return 'Admin đã hủy';
    if (eff == 'rejected') return 'Host đã từ chối';
    if (eff == 'cancelled_by_guest') {
      // Preserve legacy 'Đã hủy' only when raw status was generic 'cancelled'
      // while returning 'Khách đã hủy' for canonical 'cancelled_by_guest'.
      return raw == 'cancelled' ? 'Đã hủy' : 'Khách đã hủy';
    }

    switch (eff) {
      case 'pending_payment':
        return 'Chờ thanh toán';
      case 'paid':
        return 'Thanh toán thành công';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'checked_in':
        return 'Đã nhận phòng';
      case 'checked_out':
        return raw == 'completed' ? 'Đã hoàn thành' : 'Đã trả phòng';
      case 'completed':
        return 'Đã hoàn thành';
      default:
        return 'Đang xử lý';
    }
  }

  String get statusDisplay => statusDisplayAt();

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
      priceBreakdown: breakdown,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}
