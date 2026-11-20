// CONFLICT-RESOLVED: Bổ sung `HostListingFormViewModel` cho biểu mẫu tạo/sửa chỗ nghỉ
// (`host_listing_form_screen.dart`) theo chuẩn MVVM (FLUTTER_RULES.md Mục 2), loại bỏ việc Screen gọi trực tiếp
// `hostRepositoryProvider`, `hostFilePickerProvider` và `hostCurrentUserRoleProvider`.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/host_repository.dart';
import '../../domain/host_models.dart';
import '../../services/host_file_picker_service.dart';

export '../../services/host_file_picker_service.dart' show HostPickedFile;

/// Provider theo dõi vai trò hiện tại của Chủ nhà trên màn hình thêm/chỉnh sửa chỗ nghỉ.
final hostListingFormUserRoleProvider = Provider<String?>((ref) {
  return ref.watch(hostCurrentUserRoleProvider);
});

/// ViewModel điều phối tải dữ liệu chỗ nghỉ, tải ảnh R2, phân tích nhãn ảnh AI và lưu thông tin biệt thự.
class HostListingFormViewModel {
  final Ref _ref;
  final HostRepository _repo;
  final HostFilePickerService _picker;

  /// Khởi tạo `HostListingFormViewModel` với `Ref`, kho lưu trữ `HostRepository` và bộ chọn tệp `HostFilePickerService`.
  const HostListingFormViewModel(this._ref, this._repo, this._picker);

  /// Vai trò người dùng hiện hành phục vụ kiểm soát quyền lưu chỗ nghỉ.
  String? get currentUserRole => _ref.read(hostCurrentUserRoleProvider);

  // Giải thuật tải danh mục tiện nghi công khai, chi tiết tin đăng và kết quả phân tích ảnh AI hiện có.
  /// Truy xuất danh sách toàn bộ tiện nghi công khai từ `/api/amenities`.
  Future<List<Map<String, dynamic>>> getPublicAmenities() {
    return _repo.getPublicAmenities();
  }

  /// Truy xuất chi tiết thông tin chỗ nghỉ theo mã `id` để nạp vào biểu mẫu chỉnh sửa.
  Future<Map<String, dynamic>> getHostListingById(String id) {
    return _repo.getHostListingById(id);
  }

  /// Truy xuất danh sách ảnh hiện có kèm từ điển 22 nhãn và kết quả phân tích AI Vision của `listingId`.
  Future<
      ({
        List<ExistingListingImage> images,
        List<ImageTagTaxonomy> tagTaxonomies,
        Map<String, dynamic> summary,
      })> getListingImagesAnalysis(String listingId) {
    return _repo.getListingImagesAnalysis(listingId);
  }

  // Giải thuật chọn ảnh từ thiết bị, tải lên R2 Presigned URL và gắn thẻ AI cho từng ảnh chỗ nghỉ.
  /// Mở hộp thoại chọn tối đa `maxImages` tệp ảnh chỗ nghỉ thực tế từ thiết bị.
  Future<List<HostPickedFile>> pickListingImages({
    BuildContext? context,
    int maxImages = kMaxListingImagesCount,
  }) {
    return _picker.pickListingImages(context: context, maxImages: maxImages);
  }

  /// Xin presigned URL và đẩy trực tiếp luồng byte của `file` lên lưu trữ Cloudflare R2.
  Future<HostR2UploadResult> uploadFileToR2(
    HostPickedFile file, {
    String folder = 'listings',
    String? listingId,
    void Function(int sent, int total)? onSendProgress,
  }) {
    return _repo.uploadFileToR2(
      file,
      folder: folder,
      listingId: listingId,
      onSendProgress: onSendProgress,
    );
  }

  /// Ghi nhận danh sách siêu dữ liệu ảnh `images` vừa tải lên R2 vào hồ sơ chỗ nghỉ `listingId`.
  Future<List<ExistingListingImage>> addListingImages(
    String listingId,
    List<Map<String, dynamic>> images, {
    List<ImageTagTaxonomy> taxonomies = kDefaultImageTagTaxonomies,
  }) {
    return _repo.addListingImages(listingId, images, taxonomies: taxonomies);
  }

  /// Kích hoạt phân tích AI Vision gắn nhãn tự động cho một ảnh đơn lẻ `imageId`.
  Future<ExistingListingImage> analyzeSingleListingImage(
    String listingId,
    dynamic imageId, {
    List<ImageTagTaxonomy> taxonomies = kDefaultImageTagTaxonomies,
  }) {
    return _repo.analyzeSingleListingImage(
      listingId,
      imageId,
      taxonomies: taxonomies,
    );
  }

  /// Kích hoạt phân tích AI Vision hàng loạt cho toàn bộ ảnh của chỗ nghỉ `listingId`.
  Future<
      ({
        int analyzedCount,
        int failedCount,
        List<ExistingListingImage> images,
      })> analyzeAllListingImages(
    String listingId, {
    bool force = true,
    List<ImageTagTaxonomy> taxonomies = kDefaultImageTagTaxonomies,
  }) {
    return _repo.analyzeAllListingImages(
      listingId,
      force: force,
      taxonomies: taxonomies,
    );
  }

  /// Đặt ảnh `imageId` làm ảnh bìa đại diện cho chỗ nghỉ `listingId`.
  Future<void> setListingCoverImage(String listingId, dynamic imageId) {
    return _repo.setListingCoverImage(listingId, imageId);
  }

  /// Xóa ảnh `imageId` khỏi danh sách ảnh chỗ nghỉ.
  Future<void> deleteHostImage(dynamic imageId) {
    return _repo.deleteHostImage(imageId);
  }

  /// Lưu danh sách nhãn không gian/tiện ích `tags` đã chỉnh sửa cho ảnh `imageId`.
  Future<ExistingListingImage> updateListingImageTags(
    dynamic imageId,
    List<String> tags, {
    List<ImageTagTaxonomy> taxonomies = kDefaultImageTagTaxonomies,
  }) {
    return _repo.updateListingImageTags(
      imageId,
      tags,
      taxonomies: taxonomies,
    );
  }

  // Giải thuật khởi tạo hoặc cập nhật thông tin chỗ nghỉ cùng tiện nghi và nội quy lưu trú.
  /// Khởi tạo mới chỗ nghỉ với dữ liệu `data` trên hệ thống.
  Future<Map<String, dynamic>> createHostListing(
    Map<String, dynamic> data, {
    String? userRole,
  }) {
    return _repo.createHostListing(data, userRole: userRole ?? currentUserRole);
  }

  /// Cập nhật thông tin chỗ nghỉ `id` với tập thay đổi `data`.
  Future<Map<String, dynamic>> updateHostListing(
    String id,
    Map<String, dynamic> data, {
    String? userRole,
  }) {
    return _repo.updateHostListing(
      id,
      data,
      userRole: userRole ?? currentUserRole,
    );
  }

  /// Cập nhật danh sách mã tiện nghi `amenityIds` của chỗ nghỉ `listingId`.
  Future<void> updateListingAmenities(String listingId, List<int> amenityIds) {
    return _repo.updateListingAmenities(listingId, amenityIds);
  }

  /// Cập nhật nội quy nhận/trả phòng và quy định lưu trú `rules` của chỗ nghỉ `listingId`.
  Future<void> updateListingRules(
    String listingId,
    Map<String, dynamic> rules,
  ) {
    return _repo.updateListingRules(listingId, rules);
  }

  /// Rút trích thông báo lỗi tiếng Việt dễ hiểu từ đối tượng `error`.
  String extractErrorMessage(
    Object error, [
    String fallback = 'Đã xảy ra lỗi. Vui lòng thử lại.',
  ]) {
    return _repo.extractErrorMessage(error, fallback);
  }
}

/// Provider cung cấp `HostListingFormViewModel` cho màn hình tạo/chỉnh sửa chỗ nghỉ.
final hostListingFormViewModelProvider =
    Provider<HostListingFormViewModel>((ref) {
  final repo = ref.watch(hostRepositoryProvider);
  final picker = ref.watch(hostFilePickerProvider);
  return HostListingFormViewModel(ref, repo, picker);
});
