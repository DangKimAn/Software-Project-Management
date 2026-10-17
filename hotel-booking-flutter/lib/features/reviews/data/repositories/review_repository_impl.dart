import '../../../../core/network/dio_client.dart';
import '../../domain/entities/review_item.dart';
import '../../domain/repositories/review_repository.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  final DioClient _client;

  const ReviewRepositoryImpl(this._client);

  @override
  Future<List<ReviewItem>> getListingReviews(
    String listingId, {
    int? page,
    int? limit,
    int? rating,
  }) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/api/listings/$listingId/reviews',
        queryParameters: {
          'page': page ?? 1,
          'limit': limit ?? 20,
          if (rating != null && rating >= 1 && rating <= 5) 'rating': rating,
        },
      );
      final body = response.data;
      final dataObj = body?['data'];
      List<dynamic> items = [];
      if (dataObj is Map<String, dynamic> && dataObj['items'] is List) {
        items = dataObj['items'] as List<dynamic>;
      } else if (dataObj is List) {
        items = dataObj;
      }

      final mapped = items
          .map((json) => ReviewItem.fromJson(json as Map<String, dynamic>))
          .toList();
      if (rating != null && rating >= 1 && rating <= 5) {
        return mapped.where((item) => item.rating.round() == rating).toList();
      }
      return mapped;
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  @override
  Future<ReviewItem> createReview({
    required String bookingId,
    required int rating,
    required String comment,
  }) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/api/reviews',
        data: {
          'bookingId': int.tryParse(bookingId) ?? bookingId,
          'rating': rating,
          'comment': comment.trim(),
        },
      );
      final data = DioClient.unwrapEnvelope(response.data);
      if (data is Map<String, dynamic>) {
        return ReviewItem.fromJson(data);
      }
      return ReviewItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        reviewerName: 'Khách hàng',
        rating: rating.toDouble(),
        comment: comment.trim(),
        createdAt: DateTime.now(),
      );
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }
}
