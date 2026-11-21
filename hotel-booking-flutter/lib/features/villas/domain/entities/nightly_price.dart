import '../../../../core/date/booking_date.dart';

/// Thông tin giá phòng và trạng thái trống của một đêm lưu trú cụ thể trên lịch máy chủ.
///
/// Mỗi bản ghi đại diện cho một ngày nhận đêm trong khoảng nửa mở `[checkIn, checkOut)`.
/// Khi `priceVnd` bằng `0`, tầng hiển thị sẽ nhận diện đây là đêm chưa có giá ghi đè riêng
/// và chuyển sang dùng mức giá cơ sở ngày thường hoặc cuối tuần của căn biệt thự.
class NightlyPrice {
  /// Ngày diễn ra đêm lưu trú theo múi giờ Việt Nam (`YYYY-MM-DD`).
  final BookingDate date;

  /// Đơn giá phòng của đêm đó tính bằng VNĐ từ lịch máy chủ.
  final int priceVnd;

  /// Cho biết ngày này có rơi vào dịp cuối tuần hay không.
  final bool isWeekend;

  /// Cho biết đêm này còn trống để khách đặt phòng hay đã khóa lịch.
  final bool isAvailable;

  /// Ghi chú phụ thu lễ, Tết hoặc điều kiện đặc biệt của đêm lưu trú (nếu có).
  final String? note;

  /// Khởi tạo thực thể giá theo từng đêm lưu trú `NightlyPrice`.
  const NightlyPrice({
    required this.date,
    required this.priceVnd,
    this.isWeekend = false,
    this.isAvailable = true,
    this.note,
  });
}
