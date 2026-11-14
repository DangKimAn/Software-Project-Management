/// Thực thể miền biểu diễn một đánh giá lưu trú của khách hàng kèm phản hồi của Chủ nhà.
class ReviewItem {
  final String id;
  final double rating;
  final String comment;
  final String reviewerName;
  final String? reviewerAvatar;
  final String? hostReply;
  final DateTime? createdAt;

  const ReviewItem({
    required this.id,
    required this.rating,
    required this.comment,
    required this.reviewerName,
    this.reviewerAvatar,
    this.hostReply,
    this.createdAt,
  });

  /// Giải thuật giải mã JSON đánh giá đa cấu trúc:
  /// Hợp nhất khóa định danh (`reviewId` hoặc `id`), bóc thông tin người đánh giá trực tiếp hoặc lồng trong `user`, và phân tích an toàn mốc `createdAt`.
  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    return ReviewItem(
      id: (json['reviewId'] ?? json['id'])?.toString() ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      comment: json['comment']?.toString() ?? '',
      reviewerName: json['reviewerName']?.toString() ??
          (json['user'] is Map ? json['user']['name']?.toString() : null) ??
          'Khách lưu trú',
      reviewerAvatar: json['reviewerAvatar']?.toString() ??
          (json['user'] is Map ? json['user']['avatarUrl']?.toString() : null),
      hostReply: json['hostReply']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}
