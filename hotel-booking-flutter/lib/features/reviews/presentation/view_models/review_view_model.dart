// CONFLICT-RESOLVED: Tách `reviewRepositoryProvider` và các provider truy vấn đánh giá phân trang an toàn
// ra khỏi tệp Widget (`review_list_widget.dart`) sang tầng ViewModel theo chuẩn MVVM (FLUTTER_RULES.md Mục 2).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/providers.dart';
import '../../data/repositories/review_repository_impl.dart';
import '../../domain/entities/review_item.dart';
import '../../domain/repositories/review_repository.dart';

/// Provider cung cấp thực thể `ReviewRepository` gắn với `DioClient` trung tâm.
final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  return ReviewRepositoryImpl(client);
});

/// Bộ tham số truy vấn danh sách đánh giá theo chỗ nghỉ, bộ lọc sao và số trang cần nạp.
typedef ListingReviewsQuery = ({
  String listingId,
  int? rating,
  int pageCount,
});

/// Giải thuật phân trang đánh giá an toàn theo từng trang (Safe Multi-Page Review Pagination):
/// Tăng dần `page = 1..pageCount` với `limit = 20` (luôn `<= 50`) và khử trùng lặp theo `id`,
/// tuyệt đối không bao giờ gửi `limit > 50` làm phát sinh lỗi HTTP 422 từ validator của backend.
// CONFLICT-RESOLVED: Sửa lỗi cộng dồn `limit = _visibleLimit` vượt quá 50 gây HTTP 422 khi tải thêm đánh giá.
final listingReviewsQueryProvider = FutureProvider.autoDispose
    .family<List<ReviewItem>, ListingReviewsQuery>((ref, query) async {
  final repo = ref.watch(reviewRepositoryProvider);
  const safePageLimit = 20;
  final targetPages = query.pageCount < 1 ? 1 : query.pageCount;
  final merged = <ReviewItem>[];
  final seenIds = <String>{};

  for (int currentPage = 1; currentPage <= targetPages; currentPage++) {
    final batch = await repo.getListingReviews(
      query.listingId,
      page: currentPage,
      limit: safePageLimit,
      rating: query.rating,
    );
    for (final item in batch) {
      if (item.id.isEmpty || seenIds.add(item.id)) {
        merged.add(item);
      }
    }
    if (batch.length < safePageLimit) {
      break;
    }
  }
  return merged;
});

final listingReviewsProvider = FutureProvider.autoDispose
    .family<List<ReviewItem>, String>((ref, listingId) async {
  final repo = ref.watch(reviewRepositoryProvider);
  return repo.getListingReviews(listingId);
});
