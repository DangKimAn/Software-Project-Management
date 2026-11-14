import '../../../../core/date/booking_date.dart';
import '../../../../core/network/dio_client.dart';
import '../entities/nightly_price.dart';
import '../entities/villa.dart';

/// Giao diện kho dữ liệu trung tâm cung cấp danh sách, chi tiết, lịch trống và bảng giá biệt thự.
///
/// Tách biệt hoàn toàn tầng miền (`domain`) khỏi chi tiết giao thức HTTP/Dio ở tầng dữ liệu (`data`).
abstract class VillaRepository {
  /// Truy vấn danh sách phẳng các biệt thự thỏa mãn bộ tiêu chí tìm kiếm, vị trí địa lý và tiện ích.
  Future<List<Villa>> getVillas({
    String? searchQuery,
    String? locationGroup,
    double? lat,
    double? lng,
    int? radius,
    String? propertyType,
    int? priceMin,
    int? priceMax,
    int? minGuests,
    int? bedrooms,
    int? beds,
    int? bathrooms,
    bool? pets,
    List<String>? amenities,
    BookingDate? checkIn,
    BookingDate? checkOut,
    String? sort,
    int page = 1,
    int limit = 20,
  });

  /// Truy vấn danh sách biệt thự kèm thông tin phân trang (`PaginatedResult<Villa>`) phục vụ lưới kết quả tìm kiếm.
  Future<PaginatedResult<Villa>> getVillasPaginated({
    String? searchQuery,
    String? locationGroup,
    double? lat,
    double? lng,
    int? radius,
    String? propertyType,
    int? priceMin,
    int? priceMax,
    int? minGuests,
    int? bedrooms,
    int? beds,
    int? bathrooms,
    bool? pets,
    List<String>? amenities,
    BookingDate? checkIn,
    BookingDate? checkOut,
    String? sort,
    int page = 1,
    int limit = 12,
  });

  /// Tải thông tin chi tiết đầy đủ của một biệt thự theo `id` (bao gồm lịch kín phòng và nội quy lưu trú).
  Future<Villa?> getVillaById(String id);

  /// Tải bộ nội quy lưu trú và khung giờ nhận - trả phòng của biệt thự `villaId`.
  Future<VillaRules> getVillaRules(String villaId);

  /// Lấy danh sách biệt thự gợi ý tương tự với `villaId`, giới hạn tối đa `limit` kết quả.
  Future<List<Villa>> getRecommendations(String villaId, {int limit = 4});

  /// Thu thập tập các ngày đã kín phòng (`YYYY-MM-DD`) của `villaId` trong `monthsAhead` tháng tới.
  Future<Set<String>> getUnavailableDates(
    String villaId, {
    int monthsAhead = 6,
  });

  /// Truy vấn bảng giá và trạng thái trống từng đêm từ lịch máy chủ cho khoảng lưu trú nửa mở `[checkIn, checkOut)`.
  ///
  /// Giải thuật hợp đồng dữ liệu:
  /// - Khoảng ngày áp dụng quy ước nửa mở `[checkIn, checkOut)`: bao gồm đêm `checkIn` cho tới
  ///   đêm sát trước `checkOut`, tuyệt đối không tính ngày trả phòng `checkOut` vào danh sách đêm nghỉ.
  /// - Tự động gom tất cả các tháng dương lịch mà kỳ lưu trú đi qua (kể cả kỳ nghỉ vắt qua ranh giới
  ///   tháng hoặc năm) để trả về danh sách `NightlyPrice` đầy đủ cho bảng bóc tách giá chi tiết.
  Future<List<NightlyPrice>> getNightlyPrices({
    required String villaId,
    required BookingDate checkIn,
    required BookingDate checkOut,
  });

  /// Kiểm tra toàn bộ các đêm trong khoảng nửa mở `[checkIn, checkOut)` của `villaId` có còn trống hay không.
  Future<bool> checkAvailability({
    required String villaId,
    required BookingDate checkIn,
    required BookingDate checkOut,
  });

  /// Tải danh mục tiện ích chuẩn từ máy chủ để hiển thị bộ lọc tìm kiếm.
  Future<List<Map<String, dynamic>>> getAmenitiesCatalog();
}
