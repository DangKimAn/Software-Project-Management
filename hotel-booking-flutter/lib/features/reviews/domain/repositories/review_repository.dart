import '../entities/review_item.dart';

/// Giao diện kho dữ liệu truy vấn danh sách đánh giá theo chỗ nghỉ và gửi đánh giá mới sau kỳ lưu trú.
abstract class ReviewRepository {
  /// Tải danh sách đánh giá của chỗ nghỉ `listingId` có hỗ trợ phân trang (`page`, `limit`) và lọc theo số sao `rating` (`1..5`).
  Future<List<ReviewItem>> getListingReviews(
    String listingId, {
    int? page,
    int? limit,
    int? rating,
  });

  /// Tạo mới đánh giá cho đơn đặt phòng `bookingId` với thang điểm `rating` và nhận xét `comment`.
  Future<ReviewItem> createReview({
    required String bookingId,
    required int rating,
    required String comment,
  });
}
