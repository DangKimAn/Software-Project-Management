import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';
import '../../../trips/domain/entities/booking.dart';
import '../../../trips/domain/repositories/booking_repository.dart';
import '../../../trips/presentation/view_models/trips_view_model.dart';
import '../../data/support_repository.dart';
import '../../domain/entities/support_page_models.dart';

export '../../../trips/domain/entities/booking.dart'
    show CouponValidationResult;
export '../../domain/entities/support_page_models.dart' show UserSupportReport;

// CONFLICT-RESOLVED: Tách tầng ViewModel cho phân hệ Hỗ trợ (features/support) theo chuẩn MVVM
// tại FLUTTER_RULES.md Mục 2, loại bỏ việc Widget `support_api_forms.dart` gọi trực tiếp
// `supportRepositoryProvider` và `bookingRepositoryProvider`.

/// Provider tải danh sách phản ánh cá nhân của người dùng đang đăng nhập thông qua tầng ViewModel.
final mySupportReportsProvider =
    FutureProvider.autoDispose<List<UserSupportReport>>((ref) async {
  // Giải thuật truy vấn lịch sử báo cáo theo phiên đăng nhập:
  // Nếu người dùng chưa xác thực thì trả ngay danh sách rỗng để tránh gọi API `/api/reports/mine` bị lỗi 401;
  // ngược lại ủy quyền qua `SupportRepository` để lấy danh sách phản ánh mới nhất.
  final user = ref.watch(authNotifierProvider).valueOrNull;
  if (user == null) {
    return const <UserSupportReport>[];
  }
  return ref.watch(supportRepositoryProvider).getMyReports();
});

/// ViewModel điều phối các tác vụ gửi khiếu nại / góp ý và kiểm tra hiệu lực mã ưu đãi thành viên.
class SupportViewModel {
  final Ref _ref;
  final SupportRepository _supportRepository;
  final BookingRepository _bookingRepository;

  const SupportViewModel(
    this._ref,
    this._supportRepository,
    this._bookingRepository,
  );

  // Giải thuật gửi báo cáo phản ánh và làm mới danh sách lịch sử tức thời:
  // Ủy quyền xác thực & gửi dữ liệu tới `SupportRepository.submitReport`, sau đó vô hiệu hóa
  // bộ đệm `mySupportReportsProvider` để giao diện tự động đồng bộ bản ghi vừa tạo.
  Future<UserSupportReport> submitFeedbackReport({
    required String targetType,
    required int targetId,
    required String reason,
    String? description,
  }) async {
    final created = await _supportRepository.submitReport(
      targetType: targetType,
      targetId: targetId,
      reason: reason,
      description: description,
    );
    _ref.invalidate(mySupportReportsProvider);
    return created;
  }

  // Giải thuật kiểm tra hiệu lực mã giảm giá thành viên từ giá trị đơn tạm tính:
  // Đảm bảo giá trị đơn truyền lên tối thiểu dương (mặc định 5.000.000 VNĐ nếu người dùng bỏ trống)
  // trước khi đối soát điều kiện áp dụng qua `BookingRepository.validateCoupon`.
  Future<CouponValidationResult> validateMemberCoupon({
    required String code,
    required int bookingAmount,
  }) {
    final normalizedAmount = bookingAmount > 0 ? bookingAmount : 5000000;
    return _bookingRepository.validateCoupon(
      code: code.trim().toUpperCase(),
      bookingAmount: normalizedAmount,
    );
  }
}

final supportViewModelProvider = Provider<SupportViewModel>((ref) {
  final supportRepository = ref.watch(supportRepositoryProvider);
  final bookingRepository = ref.watch(bookingRepositoryProvider);
  return SupportViewModel(ref, supportRepository, bookingRepository);
});
