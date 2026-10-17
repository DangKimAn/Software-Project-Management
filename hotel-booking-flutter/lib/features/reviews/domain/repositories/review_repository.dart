import '../entities/review_item.dart';

abstract class ReviewRepository {
  Future<List<ReviewItem>> getListingReviews(
    String listingId, {
    int? page,
    int? limit,
    int? rating,
  });

  Future<ReviewItem> createReview({
    required String bookingId,
    required int rating,
    required String comment,
  });
}
