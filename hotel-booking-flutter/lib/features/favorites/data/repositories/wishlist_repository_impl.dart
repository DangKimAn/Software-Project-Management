import 'package:dio/dio.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/storage/preferences_service.dart';
import '../../../villas/domain/entities/villa.dart';
import '../../../villas/domain/entities/villa_specs.dart';
import '../../domain/repositories/wishlist_repository.dart';

/// Triển khai kho lưu trữ danh sách yêu thích kết hợp `PreferencesService` cục bộ và REST API `/api/wishlist`.
///
/// Chịu trách nhiệm hợp nhất các yêu cầu mạng trùng lặp đang bay (In-Flight Coalescing),
/// di trú danh sách tim của khách vãng lai sau khi đăng nhập, đối soát hai chiều giữa
/// `SharedPreferences` và backend, tự động cắt tỉa `invalidListingIds`, đồng thời
/// chuyển hóa lỗi mạng thành `AppFailure` để tầng trạng thái hoàn tác thao tác bấm tim lạc quan (Optimistic Toggle Rollback).
class WishlistRepositoryImpl implements WishlistRepository {
  final dynamic _client;
  final PreferencesService? _prefs;

  Future<List<String>>? _inFlightSyncIds;
  Future<WishlistResponse>? _inFlightDetail;

  /// Khởi tạo `WishlistRepositoryImpl` với HTTP `_client` (`Dio` hoặc `DioClient`) và tùy chọn `prefs`.
  WishlistRepositoryImpl(this._client, {PreferencesService? prefs})
      : _prefs = prefs;

  Dio get _dio => _client is Dio ? _client : (_client as dynamic).dio as Dio;

  PreferencesService? get _effectivePrefs =>
      _prefs ?? PreferencesService.activeInstance;

  // Giải thuật bóc tách phong bì dữ liệu API (Envelope Unwrapping):
  // Kiểm tra cờ `success == false` để chủ động ném `ValidationFailure` kèm mã lỗi nghiệp vụ,
  // sau đó trích xuất trường `data` nếu phản hồi tuân theo chuẩn `{ success, data }`.
  static dynamic _unwrapEnvelope(dynamic responseBody) {
    if (responseBody is Map<String, dynamic>) {
      if (responseBody['success'] == false) {
        final msg = responseBody['message']?.toString() ??
            'Không thể thực hiện yêu cầu.';
        final code = responseBody['code']?.toString() ?? 'API_ERROR';
        throw ValidationFailure(msg, code: code);
      }
      if (responseBody.containsKey('data')) {
        return responseBody['data'];
      }
    }
    return responseBody;
  }

  // Giải thuật chuẩn hóa ngoại lệ HTTP sang `AppFailure` phục vụ hoàn tác lạc quan (Optimistic Rollback Error Mapping):
  // Ánh xạ `401/403` -> `AuthFailure`, `404` -> `NotFoundFailure`, mã HTTP khác -> `ServerFailure`,
  // và mất kết nối -> `NetworkFailure` để `FavoritesNotifier` bắt được và khôi phục lại trạng thái tim trước đó.
  static AppFailure _handleError(dynamic error) {
    if (error is AppFailure) return error;
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final rawData = error.response?.data;
      final mapData =
          rawData is Map<String, dynamic> ? rawData : <String, dynamic>{};
      final serverMessage = mapData['message']?.toString();
      if (statusCode == 401 || statusCode == 403) {
        return AuthFailure(
          serverMessage ?? 'Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại.',
          mapData['code']?.toString() ?? 'HTTP_$statusCode',
          statusCode ?? 401,
        );
      }
      if (statusCode == 404) {
        return NotFoundFailure(
          serverMessage ?? 'Không tìm thấy dữ liệu yêu cầu.',
        );
      }
      if (statusCode != null) {
        return ServerFailure(
          serverMessage ?? 'Lỗi máy chủ ($statusCode). Vui lòng thử lại sau.',
          statusCode: statusCode,
        );
      }
      return NetworkFailure(
        error.message ?? 'Không thể kết nối đến máy chủ.',
      );
    }
    return UnknownFailure(error.toString());
  }

  /// Đồng bộ danh sách mã định danh yêu thích với cơ chế gộp yêu cầu đồng thời (In-Flight Request Coalescing).
  ///
  /// Nếu một tiến trình đồng bộ `_inFlightSyncIds` đang chạy, các lời gọi song song sẽ
  /// dùng chung cùng một `Future` thay vì phát sinh nhiều lượt di trú và gọi mạng trùng lặp.
  @override
  Future<List<String>> getWishlistListingIds() {
    if (_inFlightSyncIds != null) {
      return _inFlightSyncIds!;
    }
    late final Future<List<String>> future;
    future = _performSyncAndGetIds().whenComplete(() {
      if (identical(_inFlightSyncIds, future)) {
        _inFlightSyncIds = null;
      }
    });
    _inFlightSyncIds = future;
    return future;
  }

  // Giải thuật đồng bộ hai chiều cục bộ <-> máy chủ, hợp nhất phiên khách và cắt tỉa ID hỏng (`_performSyncAndGetIds`):
  // Bước 1 (Đọc hàng đợi khách vãng lai): Truy xuất danh sách `pendingGuestIds` lưu trong `SharedPreferences`
  //   khi người dùng thả tim ở chế độ chưa đăng nhập.
  // Bước 2 (Hợp nhất Guest -> Authenticated): Chuẩn hóa và lọc ID hợp lệ qua `normalizeListingIds` & `isValidListingId`,
  //   sau đó đẩy tuần tự từng ID lên `POST /api/wishlist/:id`. Nếu máy chủ trả về `400`, `404` hoặc `422`
  //   (biệt thự đã bị xóa/ẩn), đưa ID đó vào `invalidFromMigration` và tiếp tục vòng lặp thay vì làm gãy luồng đồng bộ;
  //   các lỗi mạng hoặc hết phiên (`401/403/5xx`) được `rethrow` ngay để bảo toàn hàng đợi cục bộ.
  // Bước 3 (Đối soát nguồn sự thật từ `/api/wishlist`): Gọi `getWishlistDetail()` để thu thập tập `listingIds`
  //   chính tắc trên máy chủ, danh mục `invalidListingIds` do backend phát hiện, và `userId` hiện hành.
  // Bước 4 (Cắt tỉa `invalidListingIds` & Ghi nhận vào `SharedPreferences`): Hợp nhất `invalidFromMigration`
  //   và `detail.invalidListingIds` thành tập `allInvalid`, rồi ủy quyền cho `prefs.markWishlistSynced(...)`
  //   để gộp `backendIds` + `migratedGuestIds`, loại bỏ triệt để mọi ID nằm trong `allInvalid` và xóa hàng đợi chờ.
  // Bước 5 (Bảo toàn dữ liệu khi lỗi): Nếu xảy ra sự cố trong quá trình đồng bộ, đánh dấu `markWishlistSyncFailed()`
  //   trên `SharedPreferences` để giữ nguyên dữ liệu cục bộ không bị ghi đè rỗng và ném `AppFailure` đã phân loại.
  Future<List<String>> _performSyncAndGetIds() async {
    final prefs = _effectivePrefs;
    final pendingGuestIds =
        prefs?.getPendingGuestFavorites() ?? const <String>[];
    final invalidFromMigration = <String>[];
    final migratedGuestIds = <String>[];

    try {
      if (pendingGuestIds.isNotEmpty) {
        final uniqueValidIds = PreferencesService.normalizeListingIds(
          pendingGuestIds,
        ).where(PreferencesService.isValidListingId).toList();

        for (final id in uniqueValidIds) {
          try {
            await addWishlistListing(id);
            migratedGuestIds.add(id);
          } on DioException catch (dioErr) {
            final code = dioErr.response?.statusCode;
            if (code == 404 || code == 422 || code == 400) {
              invalidFromMigration.add(id);
            } else {
              rethrow;
            }
          } catch (err) {
            final msg = err.toString().toLowerCase();
            if (msg.contains('404') || msg.contains('not found')) {
              invalidFromMigration.add(id);
            } else {
              rethrow;
            }
          }
        }
      }

      final detail = await getWishlistDetail();
      final allInvalid = PreferencesService.normalizeListingIds([
        ...invalidFromMigration,
        ...detail.invalidListingIds,
      ]);

      if (prefs != null) {
        return await prefs.markWishlistSynced(
          backendIds: detail.listingIds,
          migratedGuestIds: migratedGuestIds,
          invalidIds: allInvalid,
          userId: detail.userId,
        );
      }

      final invalidSet = allInvalid.toSet();
      return PreferencesService.normalizeListingIds([
        ...detail.listingIds,
        ...migratedGuestIds,
      ]).where((id) => !invalidSet.contains(id)).toList();
    } catch (e) {
      await prefs?.markWishlistSyncFailed();
      throw _handleError(e);
    }
  }

  /// Di trú danh sách mã chỗ nghỉ `listingIds` từ bộ nhớ cục bộ của khách vãng lai lên tài khoản đã xác thực.
  ///
  /// Giải thuật khử trùng lặp và lọc định dạng ID trước khi gọi `addWishlistListing` tuần tự;
  /// tự động bỏ qua các mã trả về lỗi `400`, `404` hoặc `422` để một chỗ nghỉ ngừng hoạt động
  /// không làm gián đoạn việc di trú các chỗ nghỉ hợp lệ còn lại.
  @override
  Future<List<String>> migrateWishlistListingIds(
      List<String> listingIds) async {
    final uniqueValidIds = PreferencesService.normalizeListingIds(listingIds)
        .where(PreferencesService.isValidListingId)
        .toList();
    final migrated = <String>[];
    for (final id in uniqueValidIds) {
      try {
        await addWishlistListing(id);
        migrated.add(id);
      } on DioException catch (dioErr) {
        final code = dioErr.response?.statusCode;
        if (code == 404 || code == 422 || code == 400) {
          continue;
        }
        throw _handleError(dioErr);
      } catch (err) {
        final msg = err.toString().toLowerCase();
        if (msg.contains('404') || msg.contains('not found')) {
          continue;
        }
        rethrow;
      }
    }
    return migrated;
  }

  /// Truy xuất chi tiết danh sách yêu thích từ `/api/wishlist` với cơ chế chia sẻ `Future` đang bay `_inFlightDetail`.
  @override
  Future<WishlistResponse> getWishlistDetail() {
    if (_inFlightDetail != null) {
      return _inFlightDetail!;
    }
    late final Future<WishlistResponse> future;
    future = _fetchWishlistDetail().whenComplete(() {
      if (identical(_inFlightDetail, future)) {
        _inFlightDetail = null;
      }
    });
    _inFlightDetail = future;
    return future;
  }

  // Giải thuật phân tích và đối soát dữ liệu chi tiết `/api/wishlist`:
  // 1. Hỗ trợ đa hình cấu trúc phản hồi (đối tượng `{ items, listingIds, invalidListingIds, userId }` hoặc mảng trực tiếp).
  // 2. Trích xuất ID chỗ nghỉ từ cả mảng `listingIds` tường minh lẫn từng phần tử trong `items` (kể cả cấu trúc lồng `listing.listingId`).
  // 3. Xây dựng tập đen `invalidSet` từ `invalidListingIds` để lọc sạch cả danh sách `combinedIds` lẫn danh sách thực thể `Villa`.
  Future<WishlistResponse> _fetchWishlistDetail() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/wishlist');
      final dataObj = _unwrapEnvelope(response.data);
      List<dynamic> rawItems = [];
      List<String> explicitListingIds = [];
      List<String> invalidIds = [];
      String? userId;

      if (dataObj is Map<String, dynamic>) {
        if (dataObj['userId'] != null) {
          userId = dataObj['userId'].toString();
        }
        if (dataObj['items'] is List) {
          rawItems = dataObj['items'] as List<dynamic>;
        }
        if (dataObj['listingIds'] is List) {
          explicitListingIds =
              (dataObj['listingIds'] as List).map((e) => e.toString()).toList();
        }
        if (dataObj['invalidListingIds'] is List) {
          invalidIds = (dataObj['invalidListingIds'] as List)
              .map((e) => e.toString())
              .toList();
        }
      } else if (dataObj is List) {
        rawItems = dataObj;
      }

      for (final raw in rawItems) {
        if (raw is Map && raw['userId'] != null && userId == null) {
          userId = raw['userId'].toString();
          break;
        }
      }

      final itemIds = rawItems
          .map((item) {
            if (item is Map) {
              return (item['listingId'] ??
                      (item['listing'] is Map
                          ? item['listing']['listingId'] ??
                              item['listing']['id']
                          : null) ??
                      item['id'])
                  ?.toString();
            }
            return item?.toString();
          })
          .whereType<String>()
          .toList();

      final invalidSet =
          PreferencesService.normalizeListingIds(invalidIds).toSet();
      final combinedIds = PreferencesService.normalizeListingIds([
        ...explicitListingIds,
        ...itemIds,
      ])
          .where((id) =>
              PreferencesService.isValidListingId(id) &&
              !invalidSet.contains(id))
          .toList();

      final villas = rawItems
          .whereType<Map<String, dynamic>>()
          .map(_mapWishlistJsonToVilla)
          .where((v) => v.id.isNotEmpty && !invalidSet.contains(v.id))
          .toList();

      return WishlistResponse(
        items: villas,
        listingIds: combinedIds,
        invalidListingIds: invalidSet.toList(),
        userId: userId,
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Gửi yêu cầu `POST /api/wishlist/:listingId` để lưu chỗ nghỉ vào danh sách yêu thích trên máy chủ.
  ///
  /// Bỏ qua sớm nếu `listingId` không đúng định dạng chuẩn. Khi gặp lỗi mạng hoặc xác thực,
  /// phương thức ném `AppFailure` để bộ điều phối trạng thái thực hiện hoàn tác cập nhật lạc quan (Optimistic Toggle Rollback).
  @override
  Future<void> addWishlistListing(String listingId) async {
    final trimmed = listingId.trim();
    if (!PreferencesService.isValidListingId(trimmed)) {
      return;
    }
    try {
      await _dio.post<Map<String, dynamic>>('/api/wishlist/$trimmed');
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Gửi yêu cầu `DELETE /api/wishlist/:listingId` để gỡ chỗ nghỉ khỏi danh sách yêu thích trên máy chủ.
  ///
  /// Bỏ qua sớm nếu `listingId` không hợp lệ. Khi thất bại, phương thức ném `AppFailure`
  /// để bộ điều phối khôi phục lại trạng thái đã lưu trong bộ nhớ và `SharedPreferences` (Optimistic Toggle Rollback).
  @override
  Future<void> removeWishlistListing(String listingId) async {
    final trimmed = listingId.trim();
    if (!PreferencesService.isValidListingId(trimmed)) {
      return;
    }
    try {
      await _dio.delete<Map<String, dynamic>>('/api/wishlist/$trimmed');
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Giải thuật chuẩn hóa JSON mục yêu thích sang thực thể `Villa`:
  // Tự động bóc đối tượng con `listing` (nếu có), hợp nhất giá ngày thường/cuối tuần theo cả camelCase lẫn snake_case,
  // thu thập danh sách ảnh theo thứ tự ưu tiên `images` -> `coverImage` -> `imageUrl`, và ghép địa chỉ hành chính.
  Villa _mapWishlistJsonToVilla(Map<String, dynamic> json) {
    final listing = json['listing'] is Map<String, dynamic>
        ? json['listing'] as Map<String, dynamic>
        : json;
    final id =
        (listing['listingId'] ?? json['listingId'] ?? listing['id'] ?? '')
            .toString();
    final title =
        (listing['title'] ?? listing['name'] ?? 'Chỗ nghỉ đã lưu').toString();
    final basePrice =
        (listing['basePrice'] ?? listing['base_price_vnd']) as num?;
    final weekendPrice =
        (listing['weekendPrice'] ?? listing['saturday_price_vnd']) as num?;

    final images = <String>[];
    if (listing['images'] is List) {
      for (final img in listing['images'] as List) {
        if (img is Map && img['url'] != null) {
          images.add(img['url'].toString());
        } else if (img is String) {
          images.add(img);
        }
      }
    }
    if (images.isEmpty && listing['coverImage'] is Map) {
      final url = (listing['coverImage'] as Map)['url']?.toString();
      if (url != null) images.add(url);
    }
    if (images.isEmpty && listing['imageUrl'] != null) {
      images.add(listing['imageUrl'].toString());
    }

    String address = listing['address']?.toString() ?? '';
    if (address.isEmpty) {
      final parts = [
        listing['addressLine'],
        listing['ward'],
        listing['district'],
        listing['city'],
      ]
          .where((e) => e != null && e.toString().trim().isNotEmpty)
          .map((e) => e.toString().trim());
      address = parts.join(', ');
    }

    // CONFLICT-RESOLVED: Mặc định điểm đánh giá bằng 0.0 thay vì 5.0 giả định khi chỗ nghỉ chưa có đánh giá.
    double rating = 0.0;
    int reviewCount = 0;
    if (listing['ratingSummary'] is Map) {
      final rs = listing['ratingSummary'] as Map<String, dynamic>;
      rating = (rs['avgRating'] as num?)?.toDouble() ?? 0.0;
      reviewCount = (rs['reviewCount'] as num?)?.toInt() ?? 0;
    } else {
      rating =
          ((listing['ratingAvg'] ?? listing['rating']) as num?)?.toDouble() ??
              0.0;
      reviewCount =
          ((listing['reviewCount'] ?? listing['review_count']) as num?)
                  ?.toInt() ??
              0;
    }

    return Villa(
      id: id,
      code: 'VILLA-$id',
      name: title,
      tagline: listing['tagline']?.toString() ?? 'Biệt thự nghỉ dưỡng Vũng Tàu',
      address: address.isNotEmpty ? address : 'Thành phố Vũng Tàu',
      ward: listing['ward']?.toString(),
      district: listing['district']?.toString(),
      city: listing['city']?.toString(),
      description: listing['description']?.toString() ?? '',
      imageUrls: images,
      specs: VillaSpecs(
        bedrooms: (listing['bedrooms'] as num?)?.toInt() ?? 0,
        beds: (listing['beds'] as num?)?.toInt() ?? 0,
        maxGuests: ((listing['maxGuests'] ?? listing['max_guests']) as num?)
                ?.toInt() ??
            0,
        bathrooms: (listing['bathrooms'] as num?)?.toInt() ?? 0,
      ),
      basePriceVnd: basePrice?.toInt(),
      saturdayPriceVnd: weekendPrice?.toInt(),
      rating: rating,
      reviewCount: reviewCount,
    );
  }
}
