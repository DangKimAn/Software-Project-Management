// Giải thuật chuẩn hóa chỉ số KPI đối soát chi trả, lọc trạng thái và nhận diện hội thoại số thực cho Host Portal.
// CONFLICT-RESOLVED: Tách biệt trạng thái chi trả đang xử lý (pending/approved/processing) khỏi trạng thái kết thúc lỗi/hủy (rejected/failed/cancelled).

import 'host_booking_status_helper.dart';

/// Các trạng thái chi trả đang chờ xử lý hợp lệ được cộng vào KPI "Chờ xử lý".
const Set<String> kHostPayoutPendingStatuses = <String>{
  'pending',
  'approved',
  'processing',
};

/// Nhãn tiếng Việt chuẩn hóa cho toàn bộ trạng thái đối soát chi trả (Payouts).
const Map<String, String> kHostPayoutStatusLabels = <String, String>{
  'pending': 'Chờ duyệt',
  'approved': 'Đã duyệt',
  'processing': 'Đang chuyển',
  'paid': 'Đã chuyển tiền',
  'failed': 'Thất bại',
  'rejected': 'Đã từ chối',
  'cancelled': 'Đã hủy',
};

/// Danh sách tab bộ lọc trạng thái chi trả đầy đủ trên giao diện Thanh toán Host.
const List<(String, String)> kHostPayoutFilterTabs = <(String, String)>[
  ('all', 'Tất cả'),
  ('pending', 'Chờ duyệt'),
  ('approved', 'Đã duyệt'),
  ('processing', 'Đang chuyển'),
  ('paid', 'Đã chuyển tiền'),
  ('failed', 'Thất bại'),
  ('rejected', 'Đã từ chối'),
  ('cancelled', 'Đã hủy'),
];

/// Kết quả tổng hợp KPI đối soát chi trả của Host.
class HostPayoutSummary {
  /// Tổng số tiền đã được giải ngân thành công (`status == 'paid'`).
  final double totalPaid;

  /// Tổng số tiền đang nằm trong tiến trình chờ duyệt hoặc đang chuyển khoản.
  final double totalPending;

  /// Bản đồ số lượng đợt chi trả theo từng mã trạng thái chuẩn hóa và khóa `'all'`.
  final Map<String, int> statusCounts;

  /// Khởi tạo kết quả tổng hợp KPI đối soát chi trả bất biến.
  const HostPayoutSummary({
    required this.totalPaid,
    required this.totalPending,
    required this.statusCounts,
  });
}

// Giải thuật tổng hợp KPI chi trả Host từ danh sách payouts đã phân trang đầy đủ:
// - Chỉ cộng vào totalPaid khi status == 'paid'.
// - Chỉ cộng vào totalPending khi status thuộc {'pending', 'approved', 'processing'}.
// - CONFLICT-RESOLVED: Tuyệt đối KHÔNG cộng các khoản 'rejected', 'failed', 'cancelled' vào "Chờ xử lý".
/// Tính toán chỉ số KPI doanh thu đã nhận, khoản chờ giải ngân và bộ đếm theo từng trạng thái từ `payouts`.
HostPayoutSummary computeHostPayoutSummary(
  Iterable<Map<String, dynamic>> payouts,
) {
  double totalPaid = 0;
  double totalPending = 0;
  final counts = <String, int>{
    'all': 0,
    for (final key in kHostPayoutStatusLabels.keys) key: 0,
  };

  for (final payout in payouts) {
    counts['all'] = (counts['all'] ?? 0) + 1;
    final rawAmount = payout['amount'];
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : (double.tryParse('${rawAmount ?? 0}') ?? 0);
    final status = (payout['status'] ?? '').toString().trim().toLowerCase();
    counts[status] = (counts[status] ?? 0) + 1;

    if (status == 'paid') {
      totalPaid += amount;
    } else if (kHostPayoutPendingStatuses.contains(status)) {
      totalPending += amount;
    }
  }

  return HostPayoutSummary(
    totalPaid: totalPaid,
    totalPending: totalPending,
    statusCounts: counts,
  );
}

// Giải thuật kiểm tra mã hội thoại có phải ID số nguyên hợp lệ trên Backend hay không:
// CONFLICT-RESOLVED: Ngăn gọi các endpoint /api/conversations/:id/messages hoặc /read với khóa giả lập như 'admin_support'.
/// Kiểm tra `rawId` có phải mã định danh hội thoại số nguyên dương hợp lệ trên máy chủ hay không.
bool isNumericHostConversationId(String? rawId) {
  if (rawId == null) return false;
  final trimmed = rawId.trim();
  if (trimmed.isEmpty) return false;
  final parsed = int.tryParse(trimmed);
  return parsed != null && parsed > 0;
}

// Giải thuật kiểm tra một ô ngày trên lịch lưu trú có thực sự đang bị khóa bởi đơn đặt phòng hợp lệ hay không:
// CONFLICT-RESOLVED: Dùng isCalendarBlockingStatusCode thay vì kiểm tra chuỗi bookingStatus khác rỗng.
/// Xác định ô ngày trên lịch Host có đang bị khóa bởi một đơn đặt phòng còn hiệu lực hay không.
bool isHostCalendarDayLockedByBooking({
  required bool isBookedFlag,
  required String? bookingStatus,
}) {
  final raw = bookingStatus?.trim() ?? '';
  if (raw.isNotEmpty) {
    return isCalendarBlockingStatusCode(raw);
  }
  return isBookedFlag;
}
