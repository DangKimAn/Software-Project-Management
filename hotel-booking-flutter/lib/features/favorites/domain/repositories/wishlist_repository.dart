import '../../../villas/domain/entities/villa.dart';

class WishlistResponse {
  final List<Villa> items;
  final List<String> listingIds;
  final List<String> invalidListingIds;
  final String? userId;

  const WishlistResponse({
    required this.items,
    this.listingIds = const [],
    this.invalidListingIds = const [],
    this.userId,
  });
}

abstract class WishlistRepository {
  Future<List<String>> getWishlistListingIds();
  Future<WishlistResponse> getWishlistDetail();
  Future<void> addWishlistListing(String listingId);
  Future<void> removeWishlistListing(String listingId);
  Future<List<String>> migrateWishlistListingIds(List<String> listingIds);
}
