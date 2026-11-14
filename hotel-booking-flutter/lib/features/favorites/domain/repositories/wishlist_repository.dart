import '../../../villas/domain/entities/villa.dart';

/// Mô hình phản hồi chuẩn hóa chứa dữ liệu danh sách yêu thích từ máy chủ.
///
/// Đóng gói đồng thời danh sách thực thể `items` để hiển thị giao diện,
/// tập mã định danh hợp lệ `listingIds`, và tập `invalidListingIds` phục vụ
/// giải thuật cắt tỉa các chỗ nghỉ đã ngừng hoạt động khỏi bộ nhớ cục bộ.
class WishlistResponse {
  /// Danh sách các biệt thự hợp lệ đang nằm trong mục yêu thích của người dùng.
  final List<Villa> items;

  /// Danh sách mã định danh chỗ nghỉ hợp lệ đã được chuẩn hóa.
  final List<String> listingIds;

  /// Danh sách mã định danh chỗ nghỉ không còn tồn tại hoặc đã bị ẩn trên hệ thống.
  final List<String> invalidListingIds;

  /// Mã định danh người dùng sở hữu danh sách yêu thích (nếu đã đăng nhập).
  final String? userId;

  /// Khởi tạo kết quả phản hồi danh sách yêu thích bất biến.
  const WishlistResponse({
    required this.items,
    this.listingIds = const [],
    this.invalidListingIds = const [],
    this.userId,
  });
}

/// Hợp đồng kho lưu trữ quản lý và đồng bộ danh sách biệt thự yêu thích (Wishlist).
///
/// Định nghĩa giao diện trừu tượng giữa tầng trình diễn và tầng dữ liệu cho các
/// nghiệp vụ đối soát hai chiều cục bộ - máy chủ, thêm/xóa chỗ nghỉ yêu thích
/// và di trú dữ liệu từ phiên khách vãng lai sang tài khoản chính thức.
abstract class WishlistRepository {
  /// Đồng bộ và trả về danh sách mã định danh chỗ nghỉ yêu thích hợp lệ.
  Future<List<String>> getWishlistListingIds();

  /// Truy xuất chi tiết danh sách biệt thự yêu thích cùng danh mục ID cần cắt tỉa.
  Future<WishlistResponse> getWishlistDetail();

  /// Thêm chỗ nghỉ có mã `listingId` vào danh sách yêu thích trên máy chủ.
  Future<void> addWishlistListing(String listingId);

  /// Xóa chỗ nghỉ có mã `listingId` khỏi danh sách yêu thích trên máy chủ.
  Future<void> removeWishlistListing(String listingId);

  /// Di trú danh sách mã chỗ nghỉ `listingIds` đã lưu lúc chưa đăng nhập lên tài khoản người dùng.
  Future<List<String>> migrateWishlistListingIds(List<String> listingIds);
}
