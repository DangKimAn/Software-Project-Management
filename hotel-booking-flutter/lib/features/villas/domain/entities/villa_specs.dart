/// Tập thông số kỹ thuật cốt lõi và tiện ích bổ trợ của căn biệt thự nghỉ dưỡng.
///
/// Phục vụ hiển thị đồng nhất trên thẻ danh sách (`PropertyCard`), hàng thông số
/// chuẩn thứ tự nghiệp vụ (`PropertySpecsRow`) và bảng tóm tắt chi tiết (`MobileSpecSummary`).
class VillaSpecs {
  // 4 Core Specs (shown in collapsed summary and card)
  /// Số lượng phòng ngủ riêng biệt.
  final int bedrooms;

  /// Tổng số lượng giường ngủ phục vụ khách.
  final int beds;

  /// Sức chứa khách tiêu chuẩn tối đa của biệt thự.
  final int maxGuests;

  /// Số lượng phòng tắm / vệ sinh (`WC`).
  final int bathrooms;

  // Supporting Specs (shown in expanded overview)
  /// Khoảng cách ước tính từ biệt thự ra bãi biển gần nhất tính bằng mét.
  final int? beachDistanceMeters;

  /// Cho biết biệt thự có trang bị hồ bơi riêng hay không.
  final bool hasPrivatePool;

  /// Cho biết hồ bơi của biệt thự có sử dụng công nghệ điện phân muối khoáng hay không.
  final bool hasSaltwaterPool;

  /// Cho biết biệt thự có khu vực bếp nấu ăn và sân nướng BBQ hay không.
  final bool hasBbqKitchen;

  /// Cho biết khuôn viên hoặc khu vực lân cận có chỗ đậu xe ô tô hay không.
  final bool hasParking;

  /// Diện tích mặt nước hồ bơi tính bằng mét vuông (`m2`), nếu được cung cấp.
  final double? poolAreaM2;

  /// Khởi tạo bộ thông số kỹ thuật `VillaSpecs`.
  const VillaSpecs({
    required this.bedrooms,
    required this.beds,
    required this.maxGuests,
    required this.bathrooms,
    this.beachDistanceMeters,
    this.hasPrivatePool = true,
    this.hasSaltwaterPool = false,
    this.hasBbqKitchen = true,
    this.hasParking = true,
    this.poolAreaM2,
  });
}
