import '../entities/review_item.dart';

abstract class ReviewRepository {
  Future<List<ReviewItem>> getListingReviews(
    String listingId, {
    int? page,
    int? limit,
  });
}
