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
  }) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/api/listings/$listingId/reviews',
        queryParameters: {
          'page': page ?? 1,
          'limit': limit ?? 20,
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

      return items
          .map((json) => ReviewItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }
}
