// Host Booking Lifecycle & Filter State Machine (`host_booking_status_helper.dart`).
// Synchronized with Backend `common/booking-display-status.ts` and `bookings.service.ts`.
// Separates financial settlement overlays (`payout_*`, `refund_*`) from canonical
// booking lifecycle states so Host tabs ("Khách đã nhận phòng", "Hoàn tất", "Đã hủy",
// "Quá hạn thanh toán", KPI & Calendar) always classify 100% accurately.

/// Vai trò người dùng thực hiện đánh giá quyền thao tác trên đơn đặt phòng.
enum BookingActionRole {
  /// Khách hàng đặt phòng.
  guest,

  /// Chủ nhà quản lý chỗ nghỉ.
  host,

  /// Quản trị viên vận hành hệ thống.
  admin,
}

/// Cấp độ sắc thái thị giác cho huy hiệu trạng thái đặt phòng.
enum BookingStatusTone {
  /// Sắc thái cảnh báo hoặc chờ xử lý.
  warning,

  /// Sắc thái nguy hiểm, từ chối, hủy hoặc quá hạn.
  danger,

  /// Sắc thái thành công hoặc hoàn tất.
  success,

  /// Sắc thái thông tin đang diễn ra (như đang lưu trú / vừa trả phòng).
  info,

  /// Sắc thái trung tính cho đơn khách chủ động hủy hoặc chưa xác định.
  muted,
}

/// Tập quyền thao tác hợp lệ tại thời điểm hiện tại trên một đơn đặt phòng.
class BookingStatusActions {
  /// Cho phép xác nhận đơn đặt phòng sau khi khách đã thanh toán.
  final bool canConfirm;

  /// Cho phép ghi nhận khách nhận phòng (Check-in) khi đến hoặc qua ngày nhận phòng theo giờ Việt Nam.
  final bool canCheckIn;

  /// Cho phép ghi nhận khách trả phòng (Check-out) khi đến hoặc qua ngày trả phòng theo giờ Việt Nam.
  final bool canCheckOut;

  /// Cho phép hủy đơn đặt phòng khi đơn chưa chuyển sang trạng thái lưu trú hoặc kết thúc.
  final bool canCancel;

  /// Khởi tạo tập cờ quyền thao tác đặt phòng.
  const BookingStatusActions({
    this.canConfirm = false,
    this.canCheckIn = false,
    this.canCheckOut = false,
    this.canCancel = false,
  });

  /// Cho biết đơn đặt phòng hiện có ít nhất một thao tác nghiệp vụ khả dụng hay không.
  bool get hasAnyAction => canConfirm || canCheckIn || canCheckOut || canCancel;
}

/// Mô hình hiển thị trạng thái đặt phòng đã hợp nhất giữa vòng đời lưu trú và lớp phủ đối soát tài chính.
class BookingDisplayStatus {
  /// Nhãn tiếng Việt hiển thị trên huy hiệu trạng thái của đơn đặt phòng.
  final String label;

  /// Sắc thái màu ngữ nghĩa đi kèm huy hiệu.
  final BookingStatusTone tone;

  /// Mã trạng thái vòng đời chuẩn (`pending_payment`, `payment_expired`, `paid`,
  /// `confirmed`, `checked_in`, `checked_out`, `completed`,
  /// `cancelled_by_guest`, `cancelled_by_host`, `cancelled_by_admin`, `rejected`).
  /// Không bao giờ bị ghi đè bởi các trạng thái tài chính (`payout_*`, `refund_*`).
  final String normalizedStatus;

  /// Mã huy hiệu thị giác phục vụ tô màu pill (có thể mang `payout_paid`,
  /// `payout_pending`, `refunded`, `refund_pending`).
  final String code;

  /// Lý do hủy hoặc quá hạn đã được Việt hóa dễ hiểu cho người dùng.
  final String? reason;

  /// Cho biết đơn đặt phòng đã đi tới trạng thái kết thúc vòng đời hay chưa.
  final bool isTerminal;

  /// Tập các hành động nghiệp vụ được phép thực hiện trên đơn.
  final BookingStatusActions actions;

  /// Khởi tạo đối tượng hiển thị trạng thái đặt phòng bất biến.
  const BookingDisplayStatus({
    required this.label,
    required this.tone,
    required this.normalizedStatus,
    required this.code,
    this.reason,
    required this.isTerminal,
    required this.actions,
  });
}

/// Kết quả phân vùng danh sách đơn đặt phòng cho màn hình quản lý khách lưu trú của Host.
class HostGuestBookingsPartition {
  /// Danh sách đơn đang lưu trú hoặc có lịch nhận phòng ngay trong ngày hôm nay (theo giờ Việt Nam).
  final List<Map<String, dynamic>> todayBookings;

  /// Danh sách đơn đã xác nhận/thanh toán có ngày nhận phòng trong tương lai.
  final List<Map<String, dynamic>> upcomingBookings;

  /// Danh sách đơn khớp với bộ lọc tab trạng thái hiện hành, sắp xếp giảm dần theo mã đơn.
  final List<Map<String, dynamic>> statusMatchedBookings;

  /// Khởi tạo kết quả phân vùng danh sách đặt phòng của Host.
  const HostGuestBookingsPartition({
    required this.todayBookings,
    required this.upcomingBookings,
    required this.statusMatchedBookings,
  });
}

/// Tập các mã trạng thái đặt phòng kết thúc vòng đời (không thể chuyển tiếp thao tác vận hành).
const Set<String> kHostTerminalBookingStatuses = {
  'payment_expired',
  'completed',
  'cancelled_by_guest',
  'cancelled_by_host',
  'cancelled_by_admin',
  'rejected',
};

/// Tập các mã trạng thái thuộc nhóm đơn đã bị hủy hoặc bị từ chối.
const Set<String> kHostCancelledBookingStatuses = {
  'cancelled_by_guest',
  'cancelled_by_host',
  'cancelled_by_admin',
  'rejected',
};

/// Tập các mã trạng thái biểu thị đơn đặt phòng thành công (dùng để tính KPI doanh thu và khóa lịch).
const Set<String> kHostSuccessfulBookingStatuses = {
  'paid',
  'confirmed',
  'checked_in',
  'checked_out',
  'completed',
};

const Set<String> _financialOverlayCodes = {
  'refund_pending',
  'refunded',
  'payout_pending',
  'payout_paid',
};

// Thuật toán quy đổi mốc thời gian hiện tại sang chuỗi ngày `YYYY-MM-DD` theo múi giờ Việt Nam (`UTC+7`) để đồng bộ với `getTodayInVietnam()` ở Backend.
/// Quy đổi mốc thời gian `now` sang chuỗi ngày `YYYY-MM-DD` theo múi giờ Việt Nam (`UTC+7`).
String getVietnamTodayDateString([DateTime? now]) {
  final current = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
  final y = current.year.toString().padLeft(4, '0');
  final m = current.month.toString().padLeft(2, '0');
  final d = current.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

// Thuật toán trích xuất phần ngày chuẩn `YYYY-MM-DD` từ chuỗi ISO-8601 hoặc đối tượng ngày nhằm tránh lệch múi giờ khi so sánh lịch nhận/trả phòng.
/// Trích xuất chuỗi ngày chuẩn `YYYY-MM-DD` từ giá trị ISO-8601 hoặc `DateTime` đầu vào `value`.
String? extractBookingDateOnly(dynamic value) {
  if (value == null) return null;
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  final datePart = raw.split('T').first;
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(datePart)) {
    return datePart;
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  final y = parsed.year.toString().padLeft(4, '0');
  final m = parsed.month.toString().padLeft(2, '0');
  final d = parsed.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

// Thuật toán kiểm tra ngày nhận/trả phòng đã đến hoặc qua so với ngày hiện tại theo múi giờ Việt Nam (`UTC+7`).
/// Kiểm tra mốc ngày `dateValue` đã đến hoặc đi qua ngày hiện tại theo múi giờ Việt Nam (`UTC+7`) hay chưa.
bool isDateReachedInVietnam(dynamic dateValue, [DateTime? now]) {
  final dateStr = extractBookingDateOnly(dateValue);
  if (dateStr == null) return false;
  return dateStr.compareTo(getVietnamTodayDateString(now)) <= 0;
}

// Thuật toán chuẩn hóa mã trạng thái đặt phòng thô (bao gồm các alias cũ) về tập mã trạng thái chuẩn của hệ thống.
String? _normalizeKnownBookingCode(dynamic value) {
  final normalized = (value?.toString() ?? '').trim().toLowerCase();
  switch (normalized) {
    case 'pending':
    case 'awaiting_payment':
    case 'pending_payment':
      return 'pending_payment';
    case 'expired':
    case 'hold_expired':
    case 'payment_expired':
      return 'payment_expired';
    case 'pending_host':
    case 'pending_host_confirmation':
    case 'paid':
      return 'paid';
    case 'confirmed':
      return 'confirmed';
    case 'in_house':
    case 'staying':
    case 'active_stay':
    case 'checked_in':
      return 'checked_in';
    case 'checked_out':
      return 'checked_out';
    case 'completed':
      return 'completed';
    case 'guest_cancelled':
    case 'customer_cancelled':
    case 'cancelled_by_guest':
      return 'cancelled_by_guest';
    case 'host_cancelled':
    case 'cancelled_by_host':
      return 'cancelled_by_host';
    case 'admin_cancelled':
    case 'cancelled_by_admin':
      return 'cancelled_by_admin';
    case 'host_rejected':
    case 'rejected':
      return 'rejected';
    case 'refund_pending':
    case 'refunded':
    case 'payout_pending':
    case 'payout_paid':
      return normalized;
    default:
      return null;
  }
}

// Thuật toán phân loại chi tiết tác nhân hủy đơn đối với dữ liệu đặt phòng dùng mã `'cancelled'` chung dựa trên lý do hủy và ID người thao tác.
String _normalizeLegacyCancellation(Map<String, dynamic> booking) {
  final reason =
      (booking['cancellationReason'] ?? booking['cancellation_reason'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
  if (reason == 'PAYMENT_EXPIRED' ||
      reason == 'EXPIRED' ||
      reason == 'HOLD_EXPIRED') {
    return 'payment_expired';
  }
  if (reason == 'ADMIN_CANCELLED' || reason == 'CANCELLED_BY_ADMIN') {
    return 'cancelled_by_admin';
  }
  if (reason == 'HOST_REJECTED' || reason == 'REJECTED') {
    return 'rejected';
  }
  if (reason == 'HOST_CANCELLED' || reason == 'CANCELLED_BY_HOST') {
    return 'cancelled_by_host';
  }
  final cancelledBy =
      booking['cancelledByUserId'] ?? booking['cancelled_by_user_id'];
  final hostId = booking['hostUserId'] ?? booking['host_user_id'];
  if (cancelledBy != null && hostId != null && '$cancelledBy' == '$hostId') {
    return 'cancelled_by_host';
  }
  return 'cancelled_by_guest';
}

// Thuật toán suy diễn trạng thái vòng đời đặt phòng gốc, đảm bảo các nhãn tài chính (`payout_*`, `refund_*`) không bao giờ ghi đè trạng thái lưu trú thực tế.
/// Suy diễn mã trạng thái vòng đời đặt phòng chính tắc từ `booking`, tách biệt khỏi lớp phủ tài chính.
String getBookingLifecycleStatus(Map<String, dynamic> booking) {
  final displayMap = booking['displayStatus'] is Map<Object?, Object?>
      ? Map<String, dynamic>.from(
          booking['displayStatus'] as Map<Object?, Object?>,
        )
      : null;

  for (final rawCandidate in [
    booking['internalStatus'],
    booking['persistedStatus'],
    booking['status'],
    booking['bookingStatus'],
    displayMap?['normalizedStatus'],
  ]) {
    final lowered = (rawCandidate ?? '').toString().trim().toLowerCase();
    if (lowered == 'cancelled' || lowered == 'canceled') {
      return _normalizeLegacyCancellation(booking);
    }
  }

  String? nonFinancialCode(dynamic value) {
    final code = _normalizeKnownBookingCode(value);
    if (code == null || _financialOverlayCodes.contains(code)) return null;
    return code;
  }

  final internalLifecycle = nonFinancialCode(booking['internalStatus']);
  final persistedLifecycle = nonFinancialCode(booking['persistedStatus']);
  final displayLifecycle = nonFinancialCode(displayMap?['normalizedStatus']) ??
      nonFinancialCode(displayMap?['code']);
  final publicLifecycle = nonFinancialCode(booking['status']) ??
      nonFinancialCode(booking['bookingStatus']);

  if (displayLifecycle != null &&
      kHostTerminalBookingStatuses.contains(displayLifecycle)) {
    return displayLifecycle;
  }
  if (publicLifecycle != null &&
      kHostTerminalBookingStatuses.contains(publicLifecycle)) {
    return publicLifecycle;
  }

  final resolvedLifecycle = internalLifecycle ??
      persistedLifecycle ??
      displayLifecycle ??
      publicLifecycle;
  if (resolvedLifecycle != null) {
    return resolvedLifecycle;
  }

  // Fallback nếu payload chỉ truyền trực tiếp mã tài chính mà thiếu trường lifecycle.
  final fallbackFinancial = _normalizeKnownBookingCode(booking['status']) ??
      _normalizeKnownBookingCode(displayMap?['code']);
  if (fallbackFinancial == 'payout_pending' ||
      fallbackFinancial == 'payout_paid') {
    final hasCheckIn =
        (booking['checkedInAt'] ?? booking['checked_in_at']) != null;
    final hasCheckOut =
        (booking['checkedOutAt'] ?? booking['checked_out_at']) != null;
    if (hasCheckIn && !hasCheckOut) return 'checked_in';
    return 'completed';
  }
  if (fallbackFinancial == 'refund_pending' ||
      fallbackFinancial == 'refunded') {
    return _normalizeLegacyCancellation(booking);
  }

  return 'unknown';
}

// Thuật toán kiểm tra đơn đặt phòng đã hoàn tất thanh toán dựa trên `paymentStatus`, `paidAt` hoặc trạng thái hậu thanh toán.
bool _isBookingPaid(Map<String, dynamic> booking, String lifecycleStatus) {
  final paymentStatus =
      (booking['paymentStatus'] ?? booking['payment_status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
  return paymentStatus == 'paid' ||
      (booking['paidAt'] ?? booking['paid_at']) != null ||
      kHostSuccessfulBookingStatuses.contains(lifecycleStatus);
}

// Thuật toán xác định trạng thái vòng đời hiệu lực theo thời gian thực (tự động nhận diện đơn giữ chỗ quá hạn thanh toán hoặc đơn đã trả tiền).
/// Xác định trạng thái vòng đời hiệu lực của `booking` theo thời gian thực tại mốc `now`.
String getEffectiveBookingLifecycleStatus(
  Map<String, dynamic> booking, [
  DateTime? now,
]) {
  final currentNow = now ?? DateTime.now();
  final lifecycle = getBookingLifecycleStatus(booking);
  final reason =
      (booking['cancellationReason'] ?? booking['cancellation_reason'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
  final isPaid = _isBookingPaid(booking, lifecycle);

  if (!isPaid &&
      (reason == 'PAYMENT_EXPIRED' ||
          reason == 'EXPIRED' ||
          reason == 'HOLD_EXPIRED')) {
    return 'payment_expired';
  }

  if (lifecycle == 'pending_payment') {
    if (isPaid) return 'paid';
    final paymentStatus =
        (booking['paymentStatus'] ?? booking['payment_status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    if (paymentStatus == 'expired') return 'payment_expired';

    final rawExpiry = booking['paymentExpiresAt'] ??
        booking['payment_expires_at'] ??
        booking['lockedUntil'] ??
        booking['locked_until'];
    if (rawExpiry != null) {
      final parsedExpiry = DateTime.tryParse(rawExpiry.toString().trim());
      if (parsedExpiry != null &&
          !parsedExpiry.toUtc().isAfter(currentNow.toUtc())) {
        return 'payment_expired';
      }
    }
  }

  return lifecycle;
}

// Thuật toán tính toán các thao tác hợp lệ (Xác nhận, Check-in, Check-out, Hủy) theo vai trò và ngày lưu trú tại múi giờ Việt Nam.
/// Tính toán tập quyền thao tác vận hành hợp lệ cho `booking` dựa trên `role` và mốc thời gian `now`.
BookingStatusActions getBookingStatusActions(
  Map<String, dynamic> booking, {
  BookingActionRole role = BookingActionRole.host,
  DateTime? now,
}) {
  final currentNow = now ?? DateTime.now();
  final lifecycle = getEffectiveBookingLifecycleStatus(booking, currentNow);

  if (kHostTerminalBookingStatuses.contains(lifecycle)) {
    return const BookingStatusActions();
  }

  final isStaff =
      role == BookingActionRole.host || role == BookingActionRole.admin;
  if (!isStaff) {
    return BookingStatusActions(
      canCancel:
          const {'pending_payment', 'paid', 'confirmed'}.contains(lifecycle),
    );
  }

  final checkInDate =
      booking['checkInDate'] ?? booking['check_in_date'] ?? booking['check_in'];
  final checkOutDate = booking['checkOutDate'] ??
      booking['check_out_date'] ??
      booking['check_out'];

  return BookingStatusActions(
    canConfirm: lifecycle == 'paid',
    canCheckIn: lifecycle == 'confirmed' &&
        isDateReachedInVietnam(checkInDate, currentNow),
    canCheckOut: lifecycle == 'checked_in' &&
        isDateReachedInVietnam(checkOutDate, currentNow),
    canCancel: lifecycle == 'paid' || lifecycle == 'confirmed',
  );
}

// Thuật toán tổng hợp thông tin hiển thị trạng thái đặt phòng: giữ nguyên `normalizedStatus` là vòng đời chuẩn và gắn thêm nhãn chi trả/hoàn tiền minh bạch cho Host.
/// Tổng hợp đối tượng hiển thị `BookingDisplayStatus` đầy đủ nhãn, màu ngữ nghĩa, lý do hủy và quyền thao tác.
BookingDisplayStatus getBookingDisplayStatus(
  Map<String, dynamic> booking, {
  BookingActionRole role = BookingActionRole.host,
  DateTime? now,
}) {
  final currentNow = now ?? DateTime.now();
  final lifecycle = getEffectiveBookingLifecycleStatus(booking, currentNow);
  final actions = getBookingStatusActions(booking, role: role, now: currentNow);
  final isStaff =
      role == BookingActionRole.host || role == BookingActionRole.admin;

  final payoutStatus =
      (booking['payoutStatus'] ?? booking['payout_status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
  final refundStatus =
      (booking['refundStatus'] ?? booking['refund_status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
  final paymentStatus =
      (booking['paymentStatus'] ?? booking['payment_status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

  String label;
  BookingStatusTone tone;
  String badgeCode = lifecycle;

  switch (lifecycle) {
    case 'pending_payment':
      label = 'Chờ thanh toán';
      tone = BookingStatusTone.warning;
      break;
    case 'payment_expired':
      label = 'Quá hạn thanh toán';
      tone = BookingStatusTone.danger;
      break;
    case 'paid':
      label = 'Thanh toán thành công';
      tone = BookingStatusTone.success;
      break;
    case 'confirmed':
      label = 'Đã xác nhận';
      tone = BookingStatusTone.success;
      break;
    case 'checked_in':
      label = isStaff ? 'Khách đã nhận phòng' : 'Đã nhận phòng';
      tone = BookingStatusTone.info;
      break;
    case 'checked_out':
      label = 'Đã trả phòng';
      tone = BookingStatusTone.info;
      break;
    case 'completed':
      label = 'Hoàn tất';
      tone = BookingStatusTone.success;
      break;
    case 'cancelled_by_guest':
      label = 'Khách đã hủy';
      tone = BookingStatusTone.muted;
      break;
    case 'cancelled_by_host':
      label = 'Host đã hủy';
      tone = BookingStatusTone.danger;
      break;
    case 'cancelled_by_admin':
      label = 'Admin đã hủy';
      tone = BookingStatusTone.danger;
      break;
    case 'rejected':
      label = 'Host đã từ chối';
      tone = BookingStatusTone.danger;
      break;
    default:
      label = 'Không rõ';
      tone = BookingStatusTone.muted;
      break;
  }

  // Bổ sung thông tin quyết toán cho Host/Admin mà KHÔNG ghi đè normalizedStatus.
  if (isStaff && (lifecycle == 'checked_out' || lifecycle == 'completed')) {
    if (payoutStatus == 'paid') {
      badgeCode = 'payout_paid';
      label = '$label · Đã chi trả';
      tone = BookingStatusTone.success;
    } else if (const {'pending', 'approved', 'processing'}
        .contains(payoutStatus)) {
      badgeCode = 'payout_pending';
      label = '$label · Chờ chi trả';
      tone = BookingStatusTone.warning;
    }
  }

  // Bổ sung thông tin hoàn tiền cho các đơn hủy / từ chối / quá hạn mà KHÔNG làm mất phân loại hủy.
  final isCancelledOrExpired =
      kHostCancelledBookingStatuses.contains(lifecycle) ||
          lifecycle == 'payment_expired';
  final isRefunded = paymentStatus == 'refunded' || refundStatus == 'succeeded';
  final isRefundPending = isCancelledOrExpired &&
      const {'pending', 'processing'}.contains(refundStatus);

  if (isRefunded) {
    if (isStaff && isCancelledOrExpired) {
      label = '$label · Đã hoàn tiền';
    } else if (!isStaff) {
      badgeCode = 'refunded';
      label = 'Đã hoàn tiền';
      tone = BookingStatusTone.success;
    }
  } else if (isRefundPending) {
    if (isStaff) {
      label = '$label · Chờ hoàn tiền';
    } else {
      badgeCode = 'refund_pending';
      label = 'Đang chờ hoàn tiền';
      tone = BookingStatusTone.warning;
    }
  }

  final rawReason =
      (booking['cancellationReason'] ?? booking['cancellation_reason'])
          ?.toString()
          .trim();
  String? localizedReason = rawReason;
  if (rawReason != null && rawReason.isNotEmpty) {
    switch (rawReason.toUpperCase()) {
      case 'PAYMENT_EXPIRED':
      case 'EXPIRED':
      case 'HOLD_EXPIRED':
        localizedReason =
            'Quá thời hạn thanh toán (hệ thống tự động hủy giữ chỗ)';
        break;
      case 'CUSTOMER_CANCELLED':
      case 'CANCELLED_BY_GUEST':
      case 'GUEST_CANCELLED':
        localizedReason = 'Khách hàng chủ động hủy đặt phòng';
        break;
      case 'HOST_REJECTED':
      case 'REJECTED':
        localizedReason = 'Chủ nhà từ chối yêu cầu đặt phòng';
        break;
      case 'HOST_CANCELLED':
      case 'CANCELLED_BY_HOST':
        localizedReason = 'Chủ nhà đã hủy đặt phòng';
        break;
      case 'ADMIN_CANCELLED':
      case 'CANCELLED_BY_ADMIN':
        localizedReason = 'Quản trị viên đã hủy đặt phòng';
        break;
      case 'LATE_PAYMENT_AFTER_BOOKING_EXPIRED':
      case 'PAYMENT_SUCCESS_AFTER_HOLD_EXPIRED':
        localizedReason =
            'Thanh toán phát sinh sau khi đã hết thời gian giữ chỗ';
        break;
      default:
        if (RegExp(r'^[A-Za-z0-9]+(_[A-Za-z0-9]+)+$').hasMatch(rawReason)) {
          localizedReason = 'Đơn đặt phòng đã bị hủy theo quy định hệ thống';
        }
        break;
    }
  }

  return BookingDisplayStatus(
    label: label,
    tone: tone,
    normalizedStatus: lifecycle,
    code: badgeCode,
    reason: localizedReason,
    isTerminal: kHostTerminalBookingStatuses.contains(lifecycle) || isRefunded,
    actions: actions,
  );
}

// Thuật toán đối khớp đơn đặt phòng với bộ lọc danh mục của Host (xử lý đồng nhất `checked_in`, `completed`/`checked_out`, `cancelled`, `payment_expired`).
/// Kiểm tra `booking` có khớp với mã bộ lọc tab trạng thái `filterStatus` của Host hay không.
bool bookingMatchesDisplayStatus(
  Map<String, dynamic> booking,
  String filterStatus, {
  BookingActionRole role = BookingActionRole.host,
  DateTime? now,
}) {
  final normalizedFilter = filterStatus.trim().toLowerCase();
  if (normalizedFilter.isEmpty || normalizedFilter == 'all') return true;

  final lifecycle = getEffectiveBookingLifecycleStatus(booking, now);

  switch (normalizedFilter) {
    case 'cancelled':
      return kHostCancelledBookingStatuses.contains(lifecycle);
    case 'completed':
      // Backend tự động chuyển `checked_out` -> `completed` ngay khi serialize,
      // nên cả hai trạng thái hậu trả phòng đều thuộc mục "Hoàn tất".
      return lifecycle == 'completed' || lifecycle == 'checked_out';
    case 'checked_out':
      if (lifecycle == 'checked_out') return true;
      final hasCheckedOutAt =
          (booking['checkedOutAt'] ?? booking['checked_out_at']) != null;
      return lifecycle == 'completed' && hasCheckedOutAt;
    default:
      return lifecycle == normalizedFilter;
  }
}

// Thuật toán đếm chính xác số lượng đơn đặt phòng khớp với từng tab trạng thái của Host.
/// Đếm tổng số đơn trong `bookings` thỏa mãn điều kiện bộ lọc `filterStatus`.
int countHostBookingsMatchingFilter(
  Iterable<Map<String, dynamic>> bookings,
  String filterStatus, {
  BookingActionRole role = BookingActionRole.host,
  DateTime? now,
}) {
  if (filterStatus.trim().isEmpty || filterStatus == 'all') {
    return bookings.length;
  }
  var count = 0;
  for (final booking in bookings) {
    if (bookingMatchesDisplayStatus(
      booking,
      filterStatus,
      role: role,
      now: now,
    )) {
      count++;
    }
  }
  return count;
}

// Thuật toán phân vùng danh sách khách lưu trú cho màn hình "Khách lưu trú" (`Hôm nay`, `Sắp tới`, và danh sách lọc theo trạng thái chuyên biệt).
/// Phân vùng danh sách `bookings` thành các nhóm lưu trú hôm nay, sắp tới và danh sách theo bộ lọc `statusFilter`.
HostGuestBookingsPartition partitionHostGuestBookings(
  Iterable<Map<String, dynamic>> bookings, {
  String listingIdFilter = 'all',
  String statusFilter = 'all',
  DateTime? now,
}) {
  final currentNow = now ?? DateTime.now();
  final todayVN = getVietnamTodayDateString(currentNow);

  final relevant = <Map<String, dynamic>>[];
  for (final b in bookings) {
    if (listingIdFilter != 'all' && listingIdFilter.isNotEmpty) {
      final bListingId = '${b['listingId'] ?? b['listing_id'] ?? ''}';
      if (bListingId != listingIdFilter) continue;
    }
    relevant.add(b);
  }

  final todayList = <Map<String, dynamic>>[];
  final upcomingList = <Map<String, dynamic>>[];

  for (final b in relevant) {
    final lifecycle = getEffectiveBookingLifecycleStatus(b, currentNow);
    final inDate = extractBookingDateOnly(
      b['checkInDate'] ?? b['check_in_date'] ?? b['check_in'],
    );
    final outDate = extractBookingDateOnly(
      b['checkOutDate'] ?? b['check_out_date'] ?? b['check_out'],
    );

    if (lifecycle == 'checked_in') {
      todayList.add(b);
      continue;
    }

    if (lifecycle == 'confirmed' || lifecycle == 'paid') {
      if (inDate == null) continue;
      final effectiveOut = outDate ?? inDate;
      final isActiveToday = inDate == todayVN ||
          (inDate.compareTo(todayVN) <= 0 &&
              todayVN.compareTo(effectiveOut) <= 0);
      if (isActiveToday) {
        todayList.add(b);
      } else if (inDate.compareTo(todayVN) > 0) {
        upcomingList.add(b);
      }
    }
  }

  final statusMatched = statusFilter == 'all' || statusFilter.trim().isEmpty
      ? List<Map<String, dynamic>>.from(relevant)
      : relevant
          .where(
            (b) => bookingMatchesDisplayStatus(
              b,
              statusFilter,
              role: BookingActionRole.host,
              now: currentNow,
            ),
          )
          .toList();

  statusMatched.sort((a, b) {
    final idA = int.tryParse('${a['bookingId'] ?? a['id'] ?? 0}') ?? 0;
    final idB = int.tryParse('${b['bookingId'] ?? b['id'] ?? 0}') ?? 0;
    return idB.compareTo(idA);
  });

  return HostGuestBookingsPartition(
    todayBookings: todayList,
    upcomingBookings: upcomingList,
    statusMatchedBookings: statusMatched,
  );
}

// Thuật toán xác định đơn đặt phòng thành công (đã thanh toán/xác nhận/nhận phòng/hoàn tất) để tính KPI Tổng quan.
/// Kiểm tra `booking` có thuộc tập trạng thái đặt phòng thành công để cộng vào KPI Tổng quan hay không.
bool isSuccessfulHostBooking(Map<String, dynamic> booking, [DateTime? now]) {
  final lifecycle = getEffectiveBookingLifecycleStatus(booking, now);
  return kHostSuccessfulBookingStatuses.contains(lifecycle);
}

// Giải thuật kiểm tra đơn đặt phòng thực sự chiếm lịch lưu trú (loại trừ đơn hủy, từ chối, chờ thanh toán và quá hạn thanh toán).
/// Kiểm tra `booking` có đang chiếm giữ ngày trên lịch lưu trú của Host hay không.
bool isCalendarBlockingHostBooking(
  Map<String, dynamic> booking, [
  DateTime? now,
]) {
  final lifecycle = getEffectiveBookingLifecycleStatus(booking, now);
  return kHostSuccessfulBookingStatuses.contains(lifecycle);
}

// Giải thuật kiểm tra mã trạng thái trên ô lịch tháng có thực sự khóa phòng hay không:
// CONFLICT-RESOLVED: Chỉ các mã trạng thái đặt phòng còn hiệu lực mới khóa ngày lịch; đơn hủy/từ chối/chờ thanh toán/quá hạn không khóa lịch.
/// Xác định mã trạng thái thô `rawStatus` của một ngày trên lịch có thực sự khóa phòng hay không.
bool isCalendarBlockingStatusCode(String? rawStatus) {
  if (rawStatus == null || rawStatus.trim().isEmpty) return false;
  final trimmed = rawStatus.trim().toLowerCase();
  if (trimmed == 'booked') return true;
  final normalized = _normalizeKnownBookingCode(trimmed);
  if (normalized == null) return false;
  if (normalized == 'payout_pending' || normalized == 'payout_paid') {
    return true;
  }
  return kHostSuccessfulBookingStatuses.contains(normalized);
}
