import 'package:flutter_riverpod/flutter_riverpod.dart';
export 'trips_actions_view_model.dart';
import '../../../../app/di/providers.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../../domain/entities/booking.dart';
import '../../domain/repositories/booking_repository.dart';

/// Provider khởi tạo kho lưu trữ đặt phòng và thanh toán `BookingRepository`.
final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  return BookingRepositoryImpl(client);
});

/// Provider tải toàn bộ danh sách chuyến đi của khách hàng hiện tại.
///
/// Tự động lắng nghe thay đổi danh tính người dùng và trả về danh sách rỗng nếu phiên đăng nhập là Quản trị viên.
final myBookingsProvider =
    FutureProvider.autoDispose<List<Booking>>((ref) async {
  final authScope = ref.watch(
    authNotifierProvider.select(
      (s) => (s.valueOrNull?.id, s.valueOrNull?.isAdmin ?? false),
    ),
  );
  if (authScope.$2) {
    return const <Booking>[];
  }
  final repository = ref.watch(bookingRepositoryProvider);
  return repository.getMyBookings();
});

/// Provider xác định đơn đặt phòng đang chờ thanh toán có thời hạn giữ chỗ sắp hết sớm nhất
/// để hiển thị biểu ngữ đếm ngược toàn cục (`GlobalPendingBookingBanner`).
///
/// Trả về `null` nếu người dùng chưa đăng nhập, là Quản trị viên hoặc không có đơn nào còn hạn giữ chỗ.
final activePendingBookingProvider = Provider<Booking?>((ref) {
  // Giải thuật chọn đơn giữ chỗ khẩn cấp nhất:
  // Lọc các đơn thỏa mãn `canPayNow`, chưa thanh toán, chưa hủy và `computeRemainingPaymentSeconds > 0`,
  // sau đó sắp xếp tăng dần theo số giây còn lại để ưu tiên nhắc thanh toán đơn sắp hết hạn trước nhất.
  final authState = ref.watch(authNotifierProvider);
  final user = authState.valueOrNull;
  if (user == null || user.isAdmin) {
    return null;
  }

  final bookingsAsync = ref.watch(myBookingsProvider);
  return bookingsAsync.when(
    data: (bookings) {
      final now = DateTime.now();
      final pendingBookings = bookings.where((b) {
        return b.canPayNow &&
            !b.isPaid &&
            !b.isCancelled &&
            b.computeRemainingPaymentSeconds(now: now) > 0;
      }).toList();

      if (pendingBookings.isEmpty) return null;

      pendingBookings.sort((a, b) => a
          .computeRemainingPaymentSeconds(now: now)
          .compareTo(b.computeRemainingPaymentSeconds(now: now)));

      return pendingBookings.first;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Provider truy vấn chi tiết một đơn đặt phòng theo mã `bookingId`.
final bookingDetailProvider =
    FutureProvider.autoDispose.family<Booking?, String>((ref, bookingId) async {
  ref.watch(authNotifierProvider.select((s) => s.valueOrNull?.id));
  final repository = ref.watch(bookingRepositoryProvider);
  return repository.getBookingById(bookingId);
});

/// Provider tải danh sách các phương thức thanh toán trực tuyến khả dụng từ máy chủ.
final paymentMethodsProvider =
    FutureProvider.autoDispose<List<PaymentMethodAvailability>>((ref) async {
  final repository = ref.watch(bookingRepositoryProvider);
  return repository.getPaymentMethods();
});

/// Provider truy vấn chi tiết phiên giao dịch thanh toán theo mã `paymentId`.
final paymentDetailProvider = FutureProvider.autoDispose
    .family<PaymentSessionResult?, String>((ref, paymentId) async {
  ref.watch(authNotifierProvider.select((s) => s.valueOrNull?.id));
  final repository = ref.watch(bookingRepositoryProvider);
  return repository.getPaymentById(paymentId);
});
