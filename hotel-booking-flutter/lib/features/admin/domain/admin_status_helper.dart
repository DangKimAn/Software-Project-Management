// Giải thuật phân loại trạng thái tài khoản, kiểm tra điều kiện duyệt xác minh
// và cắt cửa sổ dữ liệu doanh thu mới nhất cho cổng Quản trị (Admin Portal).

/// Nhóm trạng thái chuẩn hóa của tài khoản người dùng trên bảng Quản lý người dùng.
enum AdminUserStatusKind {
  active,
  inactive,
  suspended,
  deleted,
}

/// Thông tin hiển thị và hành động tương ứng với từng trạng thái người dùng.
class AdminUserStatusClassification {
  const AdminUserStatusClassification({
    required this.kind,
    required this.rawStatus,
    required this.badgeLabel,
    required this.canToggleStatus,
    this.nextTargetStatus,
    this.actionLabel,
    this.confirmTitle,
    this.confirmCtaLabel,
  });

  final AdminUserStatusKind kind;
  final String rawStatus;
  final String badgeLabel;
  final bool canToggleStatus;
  final String? nextTargetStatus;
  final String? actionLabel;
  final String? confirmTitle;
  final String? confirmCtaLabel;

  bool get isActive => kind == AdminUserStatusKind.active;
  bool get isInactive => kind == AdminUserStatusKind.inactive;
  bool get isSuspended => kind == AdminUserStatusKind.suspended;
  bool get isDeleted => kind == AdminUserStatusKind.deleted;

  /// Chỉ tài khoản đang hoạt động thực sự mới hiển thị chấm xanh active.
  bool get showsActiveDot => kind == AdminUserStatusKind.active;
}

/// Nhóm trạng thái xét duyệt hồ sơ đăng ký Host và Legacy Verifications.
enum AdminReviewStatusKind {
  pending,
  approved,
  rejected,
  closed,
}

/// Kết quả phân loại trạng thái xét duyệt để quyết định hiển thị nút thao tác.
class AdminReviewStatusClassification {
  const AdminReviewStatusClassification({
    required this.kind,
    required this.rawStatus,
    required this.badgeLabel,
    required this.canApproveOrReject,
  });

  final AdminReviewStatusKind kind;
  final String rawStatus;
  final String badgeLabel;
  final bool canApproveOrReject;
}

/// Bộ công cụ thuần nghiệp vụ phân loại trạng thái người dùng, kiểm tra điều kiện xét duyệt hồ sơ và cắt cửa sổ doanh thu cho cổng Quản trị.
abstract final class AdminStatusHelper {
  static const Set<String> _lockedAliases = <String>{
    'suspended',
    'blocked',
    'locked',
  };

  // Giải thuật phân loại trạng thái người dùng thành 4 nhóm tách biệt:
  // active, inactive, suspended (gộp blocked/locked) và deleted.
  // CONFLICT-RESOLVED: Tránh gán nhầm trạng thái inactive/deleted thành chấm xanh active và đồng bộ nhóm khóa với tab lọc status=suspended của backend.
  /// Phân loại trạng thái tài khoản thô `rawStatus` sang đối tượng `AdminUserStatusClassification` phục vụ hiển thị huy hiệu và nút khóa/mở khóa.
  static AdminUserStatusClassification classifyUserStatus(Object? rawStatus) {
    final normalized = '${rawStatus ?? ''}'.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'null' || normalized == 'active') {
      return const AdminUserStatusClassification(
        kind: AdminUserStatusKind.active,
        rawStatus: 'active',
        badgeLabel: 'Đang hoạt động',
        canToggleStatus: true,
        nextTargetStatus: 'suspended',
        actionLabel: 'Khóa',
        confirmTitle: 'Xác nhận khóa tài khoản',
        confirmCtaLabel: 'Xác nhận khóa',
      );
    }

    if (_lockedAliases.contains(normalized)) {
      return AdminUserStatusClassification(
        kind: AdminUserStatusKind.suspended,
        rawStatus: normalized,
        badgeLabel: 'Tạm khóa',
        canToggleStatus: true,
        nextTargetStatus: 'active',
        actionLabel: 'Mở khóa',
        confirmTitle: 'Xác nhận mở khóa tài khoản',
        confirmCtaLabel: 'Xác nhận mở khóa',
      );
    }

    if (normalized == 'deleted') {
      return const AdminUserStatusClassification(
        kind: AdminUserStatusKind.deleted,
        rawStatus: 'deleted',
        badgeLabel: 'Đã xóa',
        canToggleStatus: false,
      );
    }

    final isExplicitInactive = normalized == 'inactive';
    return AdminUserStatusClassification(
      kind: AdminUserStatusKind.inactive,
      rawStatus: normalized,
      badgeLabel: isExplicitInactive ? 'Ngừng hoạt động' : 'Chưa kích hoạt',
      canToggleStatus: true,
      nextTargetStatus: 'active',
      actionLabel: 'Kích hoạt',
      confirmTitle: 'Xác nhận kích hoạt tài khoản',
      confirmCtaLabel: 'Xác nhận kích hoạt',
    );
  }

  // Giải thuật chuẩn hóa payload trạng thái gửi lên PATCH /api/users/:id/status.
  // CONFLICT-RESOLVED: Gom các giá trị 'blocked' và 'locked' về chuẩn 'suspended' theo hợp đồng backend.
  /// Chuẩn hóa chuỗi trạng thái `status` trước khi gửi yêu cầu cập nhật lên máy chủ.
  static String normalizeOutboundUserStatus(String status) {
    final trimmed = status.trim();
    final lower = trimmed.toLowerCase();
    if (_lockedAliases.contains(lower)) {
      return 'suspended';
    }
    return lower.isEmpty ? 'active' : lower;
  }

  // Giải thuật kiểm tra trạng thái xét duyệt hồ sơ Host & Legacy Verifications.
  // CONFLICT-RESOLVED: Chỉ bật nút Duyệt/Từ chối khi status == 'pending' nhằm ngăn lỗi HTTP 409 từ host-application.service.ts và verifications API.
  /// Phân loại trạng thái hồ sơ xét duyệt `rawStatus` để quyết định nhãn hiển thị và quyền bật nút Duyệt/Từ chối.
  static AdminReviewStatusClassification classifyReviewStatus(
    Object? rawStatus,
  ) {
    final normalized = '${rawStatus ?? ''}'.trim().toLowerCase();
    switch (normalized) {
      case '':
      case 'null':
      case 'pending':
        return const AdminReviewStatusClassification(
          kind: AdminReviewStatusKind.pending,
          rawStatus: 'pending',
          badgeLabel: 'Chờ duyệt',
          canApproveOrReject: true,
        );
      case 'approved':
        return const AdminReviewStatusClassification(
          kind: AdminReviewStatusKind.approved,
          rawStatus: 'approved',
          badgeLabel: 'Đã duyệt',
          canApproveOrReject: false,
        );
      case 'rejected':
        return const AdminReviewStatusClassification(
          kind: AdminReviewStatusKind.rejected,
          rawStatus: 'rejected',
          badgeLabel: 'Đã từ chối',
          canApproveOrReject: false,
        );
      default:
        return AdminReviewStatusClassification(
          kind: AdminReviewStatusKind.closed,
          rawStatus: normalized,
          badgeLabel: 'Đã đóng',
          canApproveOrReject: false,
        );
    }
  }

  // Giải thuật kiểm tra nhanh quyền thực thi hành động xét duyệt trên bản ghi.
  /// Kiểm tra nhanh xem bản ghi ở trạng thái `rawStatus` còn cho phép phê duyệt hoặc từ chối hay không.
  static bool canReviewSubmission(Object? rawStatus) {
    return classifyReviewStatus(rawStatus).canApproveOrReject;
  }

  // Giải thuật cắt cửa sổ N điểm doanh thu gần nhất theo thứ tự thời gian tăng dần (ASC).
  // CONFLICT-RESOLVED: Backend trả về series sắp xếp ASC (cũ -> mới), dùng sublist lấy đuôi thay vì take(14) để không làm mất các ngày doanh thu mới nhất ở chế độ 30/90 ngày.
  /// Cắt tối đa `maxItems` điểm doanh thu mới nhất ở cuối chuỗi thời gian `series` (sắp xếp tăng dần).
  static List<T> sliceLatestRevenueWindow<T>(
    List<T> series, {
    int maxItems = 14,
  }) {
    if (maxItems <= 0 || series.isEmpty) {
      return const [];
    }
    if (series.length <= maxItems) {
      return List<T>.unmodifiable(series);
    }
    return List<T>.unmodifiable(series.sublist(series.length - maxItems));
  }
}
