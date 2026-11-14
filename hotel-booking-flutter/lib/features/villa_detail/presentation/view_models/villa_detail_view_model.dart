// CONFLICT-RESOLVED: Bổ sung `VillaDetailViewModel` điều phối kiểm tra mã giảm giá, lưu ý định đặt phòng
// chờ đăng nhập và khởi tạo đơn đặt phòng theo chuẩn MVVM (FLUTTER_RULES.md Mục 2), loại bỏ việc
// `VillaDetailScreen` gọi trực tiếp `preferencesServiceProvider` và `bookingRepositoryProvider`.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/providers.dart';
import '../../../../core/storage/preferences_service.dart';
import '../../../trips/domain/entities/booking.dart';
import '../../../trips/domain/repositories/booking_repository.dart';
import '../../../trips/presentation/view_models/trips_view_model.dart';

/// ViewModel điều phối các nghiệp vụ tương tác đặt phòng trên trang Chi tiết biệt thự.
class VillaDetailViewModel {
  final Ref _ref;
  final BookingRepository _bookingRepository;
  final PreferencesService _preferencesService;

  /// Khởi tạo `VillaDetailViewModel` với `Ref`, kho dữ liệu đặt phòng và dịch vụ lưu trữ tùy chọn cục bộ.
  const VillaDetailViewModel(
    this._ref,
    this._bookingRepository,
    this._preferencesService,
  );

  /// Đối soát tính hợp lệ và số tiền giảm của mã ưu đãi `code` theo kỳ lưu trú `[checkInDate, checkOutDate)`.
  // Giải thuật đối soát mã ưu đãi theo khoảng ngày lưu trú, số lượng khách và tiền phòng tạm tính.
  Future<CouponValidationResult> validateCoupon({
    required String code,
    required String listingId,
    required String checkInDate,
    required String checkOutDate,
    required int guestsCount,
    required int subtotalAmount,
  }) {
    return _bookingRepository.validateCoupon(
      code: code,
      listingId: listingId,
      checkInDate: checkInDate,
      checkOutDate: checkOutDate,
      guestsCount: guestsCount,
      subtotalAmount: subtotalAmount,
    );
  }

  /// Lưu tạm thông tin ý định đặt phòng vào bộ nhớ cục bộ để khôi phục sau khi người dùng đăng nhập thành công.
  // Giải thuật lưu tạm ý định đặt phòng (`PendingBookingIntent`) vào bộ nhớ cục bộ trước khi chuyển sang Đăng nhập.
  Future<void> savePendingBookingIntent({
    required String listingId,
    required String checkInDate,
    required String checkOutDate,
    required int guestsCount,
  }) {
    return _preferencesService.setPendingBookingIntent({
      'listingId': listingId,
      'checkInDate': checkInDate,
      'checkOutDate': checkOutDate,
      'guestsCount': guestsCount,
    });
  }

  /// Khởi tạo đơn đặt phòng trên máy chủ và vô hiệu hóa bộ đệm `myBookingsProvider` để đồng bộ danh sách chuyến đi.
  // Giải thuật tạo đơn đặt phòng giữ chỗ 15 phút và làm mới danh sách chuyến đi cá nhân.
  Future<Booking> createBooking({
    required String listingId,
    required String checkInDate,
    required String checkOutDate,
    required int guestsCount,
    String? specialRequests,
    String? couponCode,
  }) async {
    final booking = await _bookingRepository.createBooking(
      listingId: listingId,
      checkInDate: checkInDate,
      checkOutDate: checkOutDate,
      guestsCount: guestsCount,
      specialRequests: specialRequests,
      couponCode: couponCode,
    );
    _ref.invalidate(myBookingsProvider);
    return booking;
  }
}

/// Provider cung cấp thực thể `VillaDetailViewModel` cho tầng giao diện trang Chi tiết biệt thự.
final villaDetailViewModelProvider = Provider<VillaDetailViewModel>((ref) {
  final bookingRepository = ref.watch(bookingRepositoryProvider);
  final preferencesService = ref.watch(preferencesServiceProvider);
  return VillaDetailViewModel(ref, bookingRepository, preferencesService);
});
