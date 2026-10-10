abstract class WishlistRepository {
  Future<List<String>> getWishlistListingIds();
  Future<void> addWishlistListing(String listingId);
  Future<void> removeWishlistListing(String listingId);
}
