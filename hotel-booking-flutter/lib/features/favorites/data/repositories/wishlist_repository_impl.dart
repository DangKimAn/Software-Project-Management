import '../../../../core/network/dio_client.dart';
import '../../domain/repositories/wishlist_repository.dart';

class WishlistRepositoryImpl implements WishlistRepository {
  final DioClient _client;

  const WishlistRepositoryImpl(this._client);

  @override
  Future<List<String>> getWishlistListingIds() async {
    try {
      final response =
          await _client.dio.get<Map<String, dynamic>>('/api/wishlist');
      final body = response.data;
      final dataObj = body?['data'];
      List<dynamic> items = [];
      if (dataObj is List) {
        items = dataObj;
      } else if (dataObj is Map<String, dynamic> && dataObj['items'] is List) {
        items = dataObj['items'] as List<dynamic>;
      }

      return items
          .map((item) {
            if (item is Map) {
              return (item['listingId'] ?? item['id'])?.toString();
            }
            return item?.toString();
          })
          .whereType<String>()
          .toList();
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  @override
  Future<void> addWishlistListing(String listingId) async {
    try {
      await _client.dio.post<Map<String, dynamic>>('/api/wishlist/$listingId');
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  @override
  Future<void> removeWishlistListing(String listingId) async {
    try {
      await _client.dio
          .delete<Map<String, dynamic>>('/api/wishlist/$listingId');
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }
}
