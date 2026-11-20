import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import '../../../app/di/providers.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../auth/presentation/view_models/auth_notifier.dart';
import '../domain/host_models.dart';
import '../services/host_file_picker_service.dart';

/// Provider đọc vai trò hiện tại của người dùng đã xác thực phục vụ kiểm soát quyền thao tác Host.
final hostCurrentUserRoleProvider = Provider<String?>((ref) {
  try {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.valueOrNull;
    if (user != null && user.role.trim().isNotEmpty) {
      return user.role;
    }
  } catch (_) {
    // Fallback when authNotifierProvider is not initialized in isolated widget tests
  }
  return null;
});

/// Provider cung cấp kho lưu trữ `HostRepository` gắn kèm bộ kiểm tra vai trò thời gian thực.
final hostRepositoryProvider = Provider<HostRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return HostRepository(
    dioClient.dio,
    roleResolver: () => ref.read(hostCurrentUserRoleProvider),
  );
});

class _HostDioHolder {
  final Dio dio;
  const _HostDioHolder(this.dio);
}

/// Kho lưu trữ trung tâm điều phối toàn bộ giao tiếp REST API của phân hệ Chủ nhà (Host Portal & Onboarding).
///
/// Chịu trách nhiệm xác thực quyền Chủ nhà trước khi ghi dữ liệu, tải tệp trực tiếp lên Cloudflare R2,
/// phân tích ảnh AI Vision, thẩm định dải ngày lịch hàng loạt (`validateCalendarBulkDates`),
/// tự động gom trang dữ liệu lớn (`getMyListings`, `getAllHostBookings`, `getMyPayouts`),
/// đồng bộ Google Sheets và phân loại lỗi thông qua `classifyHostError`.
class HostRepository {
  final _HostDioHolder _client;
  final HostR2DirectUploader _r2Uploader;
  final String? Function()? _roleResolver;

  /// Khởi tạo `HostRepository` từ `Dio` hoặc `DioClient`, bộ tải R2 `r2Uploader` và hàm giải mã vai trò `roleResolver`.
  HostRepository(
    dynamic clientOrDio, {
    HostR2DirectUploader? r2Uploader,
    String? Function()? roleResolver,
  })  : _client = _HostDioHolder(_extractDio(clientOrDio)),
        _r2Uploader = r2Uploader ?? HostR2DirectUploader(),
        _roleResolver = roleResolver;

  /// Thể hiện `Dio` dùng để thực thi các yêu cầu HTTP tới máy chủ ứng dụng.
  Dio get dio => _client.dio;

  static Dio _extractDio(dynamic clientOrDio) {
    if (clientOrDio is Dio) {
      return clientOrDio;
    }
    if (clientOrDio != null) {
      // ignore: avoid_dynamic_calls
      final dynamic inner = clientOrDio.dio;
      if (inner is Dio) {
        return inner;
      }
    }
    return createDefaultDio();
  }

  /// Tạo thể hiện `Dio` mặc định có interceptor tự động đính kèm JWT Bearer token từ `SecureStorageService`.
  static Dio createDefaultDio({SecureStorageService? secureStorage}) {
    final storage = secureStorage ?? const SecureStorageService();
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        sendTimeout: AppConstants.sendTimeout,
        headers: const <String, dynamic>{
          'Accept': 'application/json',
        },
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await storage.getAuthToken();
            if (token != null && token.trim().isNotEmpty) {
              options.headers['Authorization'] = 'Bearer ${token.trim()}';
            }
          } catch (_) {}
          handler.next(options);
        },
      ),
    );
    return dio;
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  Map<String, dynamic> _unwrapMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      if (raw['data'] is Map<String, dynamic>) {
        return raw['data'] as Map<String, dynamic>;
      }
      return raw;
    }
    if (raw is Map<Object?, Object?>) {
      final casted = Map<String, dynamic>.from(raw);
      if (casted['data'] is Map<Object?, Object?>) {
        return Map<String, dynamic>.from(
          casted['data'] as Map<Object?, Object?>,
        );
      }
      return casted;
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _extractList(
    dynamic raw,
    List<String> candidateKeys,
  ) {
    if (raw is List) {
      return raw
          .whereType<Map<Object?, Object?>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    final map = _unwrapMap(raw);
    for (final key in candidateKeys) {
      final val = map[key];
      if (val is List) {
        return val
            .whereType<Map<Object?, Object?>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    if (raw is Map<Object?, Object?>) {
      for (final key in candidateKeys) {
        final val = raw[key];
        if (val is List) {
          return val
              .whereType<Map<Object?, Object?>>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }
    return <Map<String, dynamic>>[];
  }

  /// Phân loại ngoại lệ `error` sang `HostErrorInfo` bằng cách ủy quyền cho giải thuật `classifyHostError`.
  HostErrorInfo classifyError(Object error, [String? fallback]) {
    return classifyHostError(error, fallback);
  }

  /// Trích xuất thông điệp lỗi tiếng Việt thân thiện để hiển thị trực tiếp trên thanh thông báo hoặc biểu mẫu Host.
  ///
  /// Giải thuật rút trích thông báo lỗi ưu tiên (`extractErrorMessage`):
  /// 1. Trả về trực tiếp thông báo kiểm định cục bộ từ `ArgumentError`, `FormatException` và `HostAuthorizationException`.
  /// 2. Với `DioException`, gọi `classifyHostError` để giải mã mã HTTP (`401/403/404/409/422/5xx`) và danh sách `errors` của từng trường.
  /// 3. Loại bỏ các tiền tố kỹ thuật thô (`Exception: `, `Bad state: `) trước khi fallback về chuỗi `fallback`.
  String extractErrorMessage(
    Object error, [
    String fallback = 'Đã xảy ra lỗi khi xử lý yêu cầu.',
  ]) {
    if (error is ArgumentError) {
      return error.message?.toString() ?? fallback;
    }
    if (error is FormatException) {
      return error.message;
    }
    if (error is HostAuthorizationException) {
      return error.message;
    }
    if (error is DioException) {
      final info = classifyHostError(error);
      if (info.message.trim().isNotEmpty) {
        return info.message.trim();
      }
      if (error.message != null && error.message!.trim().isNotEmpty) {
        return error.message!.trim();
      }
      return fallback;
    }
    final text = error.toString();
    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }
    if (text.startsWith('Bad state: ')) {
      return text.substring('Bad state: '.length);
    }
    return text.isNotEmpty ? text : fallback;
  }

  /// Đảm bảo chỉ vai trò hợp lệ (`host` hoặc `admin`) mới được thực thi các thao tác ghi dữ liệu trên Host Portal.
  ///
  /// Áp dụng cơ chế đóng an toàn (Fail-Closed): ném `HostAuthorizationException` mã `401` khi chưa có phiên đăng nhập
  /// hoặc mã `403` khi tài khoản hiện hành không mang quyền Chủ nhà.
  void assertHostRoleAuthorized([String? userRole]) {
    if (userRole == null && _roleResolver == null) return;
    final effectiveRole = userRole ?? _roleResolver?.call();
    if (effectiveRole == null || effectiveRole.trim().isEmpty) {
      throw HostAuthorizationException(
        'Vui lòng đăng nhập bằng tài khoản Chủ nhà (Host) để thực hiện thao tác này.',
        statusCode: 401,
      );
    }
    if (!isApprovedHostRole(effectiveRole)) {
      throw HostAuthorizationException(
        'Tài khoản "$effectiveRole" không có quyền thực hiện thao tác dành riêng cho Chủ nhà (Host).',
        statusCode: 403,
        userRole: effectiveRole,
      );
    }
  }

  // ===========================================================================
  // BUG-10: Host Applications & KYC (`/api/host/applications`)
  // ===========================================================================

  /// Truy xuất hồ sơ đăng ký Chủ nhà hiện tại qua `GET /api/host/applications/me` (trả về `null` nếu nhận mã `404`).
  Future<Map<String, dynamic>?> getMyApplication() async {
    try {
      final response = await _client.dio.get<dynamic>(
        '/api/host/applications/me',
      );
      final map = _unwrapMap(response.data);
      if (map.isEmpty) return null;
      return map;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Truy xuất bản ghi hồ sơ đăng ký Chủ nhà định kiểu mạnh `HostApplicationRecord` từ `GET /api/host/applications/me`.
  Future<HostApplicationRecord?> getMyApplicationRecord() async {
    final map = await getMyApplication();
    if (map == null) return null;
    return HostApplicationRecord.fromApiResponse(map);
  }

  /// Nộp bộ hồ sơ KYC `dto` theo chuẩn `multipart/form-data` lên `POST /api/host/applications`.
  Future<HostApplicationRecord> submitKycApplication(
    HostKycSubmissionDto dto, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final formData = dto.toFormData();
    final response = await _client.dio.post<dynamic>(
      '/api/host/applications',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
      onSendProgress: onSendProgress,
    );
    final map = _unwrapMap(response.data);
    return HostApplicationRecord.fromApiResponse(map);
  }

  /// Gửi hồ sơ đăng ký Chủ nhà qua `POST /api/host/applications` từ bản đồ `data` hoặc `formData` dựng sẵn.
  Future<Map<String, dynamic>> submitApplication(
    Map<String, dynamic> data, {
    FormData? formData,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final payload = formData ?? FormData.fromMap(data);
    final response = await _client.dio.post<dynamic>(
      '/api/host/applications',
      data: payload,
      options: Options(contentType: 'multipart/form-data'),
      onSendProgress: onSendProgress,
    );
    return _unwrapMap(response.data);
  }

  /// Kiểm tra trạng thái xác minh Chủ nhà qua `GET /api/host/applications/me` (dự phòng sang `GET /api/host/verifications/me`).
  Future<Map<String, dynamic>?> getMyVerificationStatus() async {
    try {
      final app = await getMyApplication();
      if (app != null) return app;
      final response = await _client.dio.get<dynamic>(
        '/api/host/verifications/me',
      );
      return _unwrapMap(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Hủy hồ sơ đăng ký Chủ nhà đang chờ duyệt và xóa chứng từ đã tải lên qua `POST /api/host/applications/cancel`.
  Future<bool> cancelApplication() async {
    final response = await _client.dio.post<dynamic>(
      '/api/host/applications/cancel',
    );
    return response.statusCode == 200;
  }

  // ===========================================================================
  // BUG-11: Host Listings (`GET /api/host/listings/mine`)
  // ===========================================================================

  /// Truy xuất một trang danh sách chỗ nghỉ của Chủ nhà qua `GET /api/host/listings/mine` (hỗ trợ lọc `draft`, `pending_approval`, `published`, `hidden`, `rejected`).
  Future<List<Map<String, dynamic>>> getHostListings({
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    final safeLimit = limit.clamp(1, 50);
    final normalizedStatus =
        (status != null && status.isNotEmpty && status != 'all')
            ? HostListingStatus.fromApi(status).value
            : null;
    final response = await _client.dio.get<dynamic>(
      '/api/host/listings/mine',
      queryParameters: {
        if (normalizedStatus != null) 'status': normalizedStatus,
        'page': page,
        'limit': safeLimit,
      },
    );
    final items = _extractList(
      response.data,
      const ['items', 'listings', 'data'],
    );
    return items.map(_normalizeListingMap).toList();
  }

  // Giải thuật phân trang toàn bộ danh sách chỗ nghỉ của Host (page = 1..totalPages, limit = 50, khử trùng theo listingId):
  // CONFLICT-RESOLVED: Đảm bảo chủ nhà có trên 50 chỗ nghỉ không bị cắt dữ liệu KPI hoặc thiếu lựa chọn ở Lịch/Đánh giá/Báo cáo.
  /// Tải trọn vẹn tất cả các trang chỗ nghỉ của Chủ nhà từ `/api/host/listings/mine` và khử trùng lặp theo `listingId`.
  Future<List<Map<String, dynamic>>> getMyListings({
    String? status,
    int limit = 50,
    int maxPages = 20,
  }) async {
    final safeLimit = limit.clamp(1, 50);
    final safeMaxPages = maxPages.clamp(1, 50);
    final normalizedStatus =
        (status != null && status.isNotEmpty && status != 'all')
            ? HostListingStatus.fromApi(status).value
            : null;

    final firstResponse = await _client.dio.get<dynamic>(
      '/api/host/listings/mine',
      queryParameters: {
        if (normalizedStatus != null) 'status': normalizedStatus,
        'page': 1,
        'limit': safeLimit,
      },
    );

    final firstItems = _extractList(
      firstResponse.data,
      const ['items', 'listings', 'data'],
    ).map(_normalizeListingMap).toList();

    final unwrapped = _unwrapMap(firstResponse.data);
    final paginationRaw = unwrapped['pagination'];
    final pagination = paginationRaw is Map<Object?, Object?>
        ? Map<String, dynamic>.from(paginationRaw)
        : null;
    final totalPages = int.tryParse(
          '${pagination?['totalPages'] ?? unwrapped['totalPages'] ?? 1}',
        ) ??
        1;

    if (totalPages <= 1 || firstItems.isEmpty) {
      return firstItems;
    }

    final merged = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    void appendUnique(List<Map<String, dynamic>> pageItems) {
      for (final item in pageItems) {
        final rawId = '${item['listingId'] ?? item['id'] ?? ''}'.trim();
        if (rawId.isNotEmpty && !seenIds.add(rawId)) {
          continue;
        }
        merged.add(item);
      }
    }

    appendUnique(firstItems);

    final targetPages = totalPages > safeMaxPages ? safeMaxPages : totalPages;
    for (var currentPage = 2; currentPage <= targetPages; currentPage++) {
      final pageItems = await getHostListings(
        status: normalizedStatus,
        page: currentPage,
        limit: safeLimit,
      );
      if (pageItems.isEmpty) break;
      appendUnique(pageItems);
    }

    return merged;
  }

  Map<String, dynamic> _normalizeListingMap(Map<String, dynamic> raw) {
    final copy = Map<String, dynamic>.from(raw);
    final statusEnum = HostListingStatus.fromListingMap(copy);
    copy['status'] = statusEnum.value;
    final rawReason =
        (copy['rejectionReason'] ?? copy['rejectReason'])?.toString().trim();
    copy['rejectionReason'] =
        (rawReason != null && rawReason.isNotEmpty) ? rawReason : null;
    copy['id'] = copy['listingId'] ?? copy['id'];
    copy['listingId'] = copy['listingId'] ?? copy['id'];
    return copy;
  }

  /// Truy xuất chi tiết một chỗ nghỉ của Chủ nhà qua `GET /api/host/listings/:id`.
  Future<Map<String, dynamic>> getHostListingById(String id) async {
    final response = await _client.dio.get<dynamic>('/api/host/listings/$id');
    final map = _unwrapMap(response.data);
    final listing = map['listing'] is Map<Object?, Object?>
        ? Map<String, dynamic>.from(map['listing'] as Map<Object?, Object?>)
        : map;
    return _normalizeListingMap(listing);
  }

  /// Tạo mới chỗ nghỉ cho Chủ nhà qua `POST /api/host/listings` sau khi xác thực quyền và chuẩn hóa payload.
  Future<Map<String, dynamic>> createHostListing(
    Map<String, dynamic> data, {
    String? userRole,
  }) async {
    assertHostRoleAuthorized(userRole);
    final payload = _sanitizeCreateListingPayload(data);
    final response = await _client.dio.post<dynamic>(
      '/api/host/listings',
      data: payload,
    );
    final map = _unwrapMap(response.data);
    final listing = map['listing'] is Map<Object?, Object?>
        ? Map<String, dynamic>.from(map['listing'] as Map<Object?, Object?>)
        : map;
    return _normalizeListingMap(listing);
  }

  /// Cập nhật thông tin hoặc trạng thái chỗ nghỉ qua `PATCH /api/host/listings/:id`.
  Future<Map<String, dynamic>> updateHostListing(
    String id,
    Map<String, dynamic> data, {
    String? userRole,
  }) async {
    assertHostRoleAuthorized(userRole);
    final payload = _sanitizeUpdateListingPayload(data);
    final response = await _client.dio.patch<dynamic>(
      '/api/host/listings/$id',
      data: payload,
    );
    final map = _unwrapMap(response.data);
    final listing = map['listing'] is Map<Object?, Object?>
        ? Map<String, dynamic>.from(map['listing'] as Map<Object?, Object?>)
        : map;
    return _normalizeListingMap(listing);
  }

  /// Chuyển trạng thái chỗ nghỉ `listingId` sang chờ quản trị viên phê duyệt (`pending_approval`).
  Future<Map<String, dynamic>> submitListingForApproval(String listingId) {
    return updateHostListing(listingId, const {'status': 'pending_approval'});
  }

  /// Tạm ẩn chỗ nghỉ `listingId` khỏi trang tìm kiếm công khai (`hidden`).
  Future<Map<String, dynamic>> hideHostListing(String listingId) {
    return updateHostListing(listingId, const {'status': 'hidden'});
  }

  /// Mở hiển thị công khai lại cho chỗ nghỉ `listingId` đã được duyệt (`published`).
  Future<Map<String, dynamic>> publishHostListing(String listingId) {
    return updateHostListing(listingId, const {'status': 'published'});
  }

  /// Xóa mềm chỗ nghỉ `id` của Chủ nhà qua `DELETE /api/host/listings/:id`.
  Future<void> deleteHostListing(String id, {String? userRole}) async {
    assertHostRoleAuthorized(userRole);
    await _client.dio.delete<dynamic>('/api/host/listings/$id');
  }

  Map<String, dynamic> _sanitizeCreateListingPayload(
    Map<String, dynamic> input,
  ) {
    final copy = Map<String, dynamic>.from(input);
    copy['country'] = 'VN';
    copy['currency'] = 'VND';
    copy['propertyType'] = HostPropertyType.fromApi(copy['propertyType']).value;
    copy['roomType'] = HostRoomType.fromApi(copy['roomType']).value;
    copy['cancellationPolicy'] =
        HostCancellationPolicy.fromApi(copy['cancellationPolicy']).value;

    // Normalize instantBook -> instantBookEnabled
    if (copy.containsKey('instantBook') &&
        !copy.containsKey('instantBookEnabled')) {
      copy['instantBookEnabled'] = copy.remove('instantBook') == true;
    } else {
      copy.remove('instantBook');
      copy['instantBookEnabled'] = copy['instantBookEnabled'] == true;
    }

    // Normalize status: only 'draft' or 'pending_approval' allowed on create
    final rawStatus =
        (copy['status'] ?? 'draft').toString().trim().toLowerCase();
    copy['status'] = (rawStatus == 'pending_approval' || rawStatus == 'pending')
        ? 'pending_approval'
        : 'draft';

    // Ensure amenityIds is List<int>
    final rawAmenityIds = copy['amenityIds'];
    if (rawAmenityIds is List) {
      copy['amenityIds'] = rawAmenityIds
          .map((e) => e is num ? e.toInt() : int.tryParse('$e'))
          .whereType<int>()
          .where((id) => id > 0)
          .toList();
    } else {
      copy['amenityIds'] = <int>[];
    }

    copy['city'] = (copy['city']?.toString().trim().isNotEmpty == true)
        ? copy['city'].toString().trim()
        : kVungTauCity;
    copy['district'] = (copy['district']?.toString().trim().isNotEmpty == true)
        ? copy['district'].toString().trim()
        : kVungTauCity;

    return copy;
  }

  Map<String, dynamic> _sanitizeUpdateListingPayload(
    Map<String, dynamic> input,
  ) {
    final copy = Map<String, dynamic>.from(input);
    if (copy.containsKey('propertyType')) {
      copy['propertyType'] =
          HostPropertyType.fromApi(copy['propertyType']).value;
    }
    if (copy.containsKey('roomType')) {
      copy['roomType'] = HostRoomType.fromApi(copy['roomType']).value;
    }
    if (copy.containsKey('cancellationPolicy')) {
      copy['cancellationPolicy'] =
          HostCancellationPolicy.fromApi(copy['cancellationPolicy']).value;
    }
    if (copy.containsKey('instantBook') &&
        !copy.containsKey('instantBookEnabled')) {
      copy['instantBookEnabled'] = copy.remove('instantBook') == true;
    } else {
      copy.remove('instantBook');
    }
    if (copy.containsKey('status')) {
      final rawStatus = copy['status']?.toString().trim().toLowerCase();
      if (rawStatus == 'pending') {
        copy['status'] = 'pending_approval';
      } else if (rawStatus == 'approved') {
        copy['status'] = 'published';
      } else {
        copy['status'] = HostListingStatus.fromApi(rawStatus).value;
      }
    }
    if (copy.containsKey('country')) {
      copy['country'] = 'VN';
    }
    if (copy.containsKey('currency')) {
      copy['currency'] = 'VND';
    }
    return copy;
  }

  // ===========================================================================
  // BUG-12: Amenities (`GET /api/amenities`, `PUT /api/host/listings/:id/amenities`)
  // & Rules (`PATCH /api/host/listings/:id/rules`)
  // ===========================================================================

  /// `GET /api/amenities`
  Future<List<Map<String, dynamic>>> getPublicAmenities() async {
    final response = await _client.dio.get<dynamic>('/api/amenities');
    return _extractList(response.data, const ['items', 'amenities', 'data']);
  }

  /// `PUT /api/host/listings/:listingId/amenities` with `{ amenityIds: List<int> }`.
  Future<void> updateListingAmenities(
    String listingId,
    List<int> amenityIds,
  ) async {
    final cleanIds = amenityIds.where((id) => id > 0).toSet().toList();
    await _client.dio.put<dynamic>(
      '/api/host/listings/$listingId/amenities',
      data: {'amenityIds': cleanIds},
    );
  }

  /// `PATCH /api/host/listings/:listingId/rules`
  Future<void> updateListingRules(
    String listingId,
    Map<String, dynamic> rules,
  ) async {
    final normalized = <String, dynamic>{};
    if (rules.containsKey('checkInFrom') || rules.containsKey('checkInTime')) {
      normalized['checkInFrom'] = rules['checkInFrom'] ?? rules['checkInTime'];
    }
    if (rules.containsKey('checkOutBefore') ||
        rules.containsKey('checkOutTime')) {
      normalized['checkOutBefore'] =
          rules['checkOutBefore'] ?? rules['checkOutTime'];
    }
    if (rules.containsKey('smokingAllowed') ||
        rules.containsKey('allowSmoking')) {
      normalized['smokingAllowed'] =
          (rules['smokingAllowed'] ?? rules['allowSmoking']) == true;
    }
    if (rules.containsKey('petsAllowed') || rules.containsKey('allowPets')) {
      normalized['petsAllowed'] =
          (rules['petsAllowed'] ?? rules['allowPets']) == true;
    }
    if (rules.containsKey('partyAllowed') ||
        rules.containsKey('allowParties')) {
      normalized['partyAllowed'] =
          (rules['partyAllowed'] ?? rules['allowParties']) == true;
    }
    if (rules.containsKey('quietHours')) {
      normalized['quietHours'] = rules['quietHours'];
    }

    await _client.dio.patch<dynamic>(
      '/api/host/listings/$listingId/rules',
      data: normalized,
    );
  }

  // ===========================================================================
  // R2 Presigned Upload & Listing Images
  // ===========================================================================

  /// Xin cấp phát liên kết tải lên trực tiếp Cloudflare R2 qua `POST /api/uploads/presign`.
  Future<HostR2UploadResult> presignUpload({
    required String filename,
    required String contentType,
    int? size,
    String folder = 'listings',
    String? listingId,
  }) async {
    final body = <String, dynamic>{
      'folder': folder,
      'filename': filename,
      'contentType': contentType,
      if (size != null) 'size': size,
      if (listingId != null && listingId.trim().isNotEmpty)
        'listingId': int.tryParse(listingId) ?? listingId,
    };
    final response = await _client.dio.post<dynamic>(
      '/api/uploads/presign',
      data: body,
    );
    final map = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : Map<String, dynamic>.from(response.data as Map<Object?, Object?>);
    return HostR2UploadResult.fromPresignJson(map);
  }

  /// Thẩm định tệp `file`, xin cấp presigned URL và tải thẳng luồng byte lên Cloudflare R2 qua `PUT` mà không rò rỉ Bearer token.
  Future<HostR2UploadResult> uploadFileToR2(
    HostPickedFile file, {
    String folder = 'listings',
    String? listingId,
    void Function(int sent, int total)? onSendProgress,
    int maxRetries = 1,
  }) async {
    final validationErr = validateListingImagePickedFile(file);
    if (validationErr != null) {
      throw ArgumentError(validationErr);
    }

    final presigned = await presignUpload(
      filename: file.name,
      contentType: file.mimeType,
      size: file.sizeBytes,
      folder: folder,
      listingId: listingId,
    );

    return _r2Uploader.putBytesToPresignedUrl(
      file: file,
      presigned: presigned,
      onSendProgress: onSendProgress,
      maxRetries: maxRetries,
    );
  }

  /// `POST /api/host/listings/:listingId/images`
  Future<List<ExistingListingImage>> addListingImages(
    String listingId,
    List<Map<String, dynamic>> images, {
    List<ImageTagTaxonomy> taxonomies = kDefaultImageTagTaxonomies,
  }) async {
    final response = await _client.dio.post<dynamic>(
      '/api/host/listings/$listingId/images',
      data: {'images': images},
    );
    final list = _extractList(response.data, const ['images', 'items', 'data']);
    return list
        .map((e) => ExistingListingImage.fromJson(e, taxonomies: taxonomies))
        .toList();
  }

  /// Legacy single-image helper that delegates to `POST /api/host/listings/:id/images`.
  Future<Map<String, dynamic>> addListingImage(
    String listingId,
    Map<String, dynamic> imageData,
  ) async {
    final saved = await addListingImages(listingId, [imageData]);
    if (saved.isNotEmpty) {
      final first = saved.first;
      return {
        'imageId': first.imageId,
        'url': first.url,
        'key': first.key,
        'isCover': first.isCover,
        'sortOrder': first.sortOrder,
      };
    }
    return <String, dynamic>{};
  }

  /// `PATCH /api/host/listings/:listingId/images/:imageId/cover`
  Future<void> setListingCoverImage(String listingId, dynamic imageId) async {
    await _client.dio.patch<dynamic>(
      '/api/host/listings/$listingId/images/$imageId/cover',
    );
  }

  /// `DELETE /api/host/listings/:listingId/images/:imageId`
  Future<void> deleteListingImage(String listingId, dynamic imageId) async {
    await _client.dio.delete<dynamic>(
      '/api/host/listings/$listingId/images/$imageId',
    );
  }

  /// `DELETE /api/host/images/:imageId`
  Future<void> deleteHostImage(dynamic imageId) async {
    await _client.dio.delete<dynamic>('/api/host/images/$imageId');
  }

  // ===========================================================================
  // AI Image Vision & 22-Tag Taxonomy
  // ===========================================================================

  /// `GET /api/host/listings/:listingId/images/analysis`
  Future<
      ({
        List<ExistingListingImage> images,
        List<ImageTagTaxonomy> tagTaxonomies,
        Map<String, dynamic> summary,
      })> getListingImagesAnalysis(String listingId) async {
    final response = await _client.dio.get<dynamic>(
      '/api/host/listings/$listingId/images/analysis',
    );
    final map = _unwrapMap(response.data);
    final rawTaxonomies = map['tagTaxonomies'];
    final taxonomies = <ImageTagTaxonomy>[];
    if (rawTaxonomies is List && rawTaxonomies.isNotEmpty) {
      for (final item in rawTaxonomies) {
        if (item is Map<Object?, Object?>) {
          final parsed = ImageTagTaxonomy.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (parsed.code.isNotEmpty) taxonomies.add(parsed);
        }
      }
    }
    final effectiveTaxonomies =
        taxonomies.isNotEmpty ? taxonomies : kDefaultImageTagTaxonomies;

    final rawImages = _extractList(map, const ['images', 'items']);
    final images = rawImages
        .map(
          (item) => ExistingListingImage.fromJson(
            item,
            taxonomies: effectiveTaxonomies,
          ),
        )
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final summary = map['summary'] is Map<Object?, Object?>
        ? Map<String, dynamic>.from(map['summary'] as Map<Object?, Object?>)
        : const <String, dynamic>{};

    return (
      images: images,
      tagTaxonomies: effectiveTaxonomies,
      summary: summary,
    );
  }

  /// `POST /api/host/listings/:listingId/images/:imageId/analyze`
  Future<ExistingListingImage> analyzeSingleListingImage(
    String listingId,
    dynamic imageId, {
    List<ImageTagTaxonomy> taxonomies = kDefaultImageTagTaxonomies,
  }) async {
    final response = await _client.dio.post<dynamic>(
      '/api/host/listings/$listingId/images/$imageId/analyze',
    );
    final map = _unwrapMap(response.data);
    final imgMap = map['image'] is Map<Object?, Object?>
        ? Map<String, dynamic>.from(map['image'] as Map<Object?, Object?>)
        : map;
    return ExistingListingImage.fromJson(imgMap, taxonomies: taxonomies);
  }

  /// `POST /api/ai/listings/:listingId/analyze-images?force=true`
  Future<
      ({
        int analyzedCount,
        int failedCount,
        List<ExistingListingImage> images
      })> analyzeAllListingImages(
    String listingId, {
    bool force = true,
    List<ImageTagTaxonomy> taxonomies = kDefaultImageTagTaxonomies,
  }) async {
    final response = await _client.dio.post<dynamic>(
      '/api/ai/listings/$listingId/analyze-images',
      queryParameters: {'force': force},
    );
    final map = _unwrapMap(response.data);
    final analyzedCount = map['analyzedCount'] is num
        ? (map['analyzedCount'] as num).toInt()
        : (int.tryParse('${map['analyzedCount'] ?? 0}') ?? 0);
    final failedCount = map['failedCount'] is num
        ? (map['failedCount'] as num).toInt()
        : (int.tryParse('${map['failedCount'] ?? 0}') ?? 0);
    final rawImages = _extractList(map, const ['images', 'items']);
    final images = rawImages
        .map((e) => ExistingListingImage.fromJson(e, taxonomies: taxonomies))
        .toList();

    return (
      analyzedCount: analyzedCount,
      failedCount: failedCount,
      images: images,
    );
  }

  /// `PATCH /api/host/images/:imageId/tags` with `{ tags: List<String> }`
  Future<ExistingListingImage> updateListingImageTags(
    dynamic imageId,
    List<String> tags, {
    List<ImageTagTaxonomy> taxonomies = kDefaultImageTagTaxonomies,
  }) async {
    final cleanTags =
        tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toSet().toList();
    final response = await _client.dio.patch<dynamic>(
      '/api/host/images/$imageId/tags',
      data: {'tags': cleanTags},
    );
    final map = _unwrapMap(response.data);
    final imgMap = map['image'] is Map<Object?, Object?>
        ? Map<String, dynamic>.from(map['image'] as Map<Object?, Object?>)
        : map;
    return ExistingListingImage.fromJson(imgMap, taxonomies: taxonomies);
  }

  // ===========================================================================
  // BUG-13: Calendar (`GET` & `PATCH /api/host/listings/:id/calendar`)
  // ===========================================================================

  /// Truy xuất danh sách ngày lịch vận hành định kiểu `HostCalendarDay` theo `month` và `year` qua `GET /api/host/listings/:listingId/calendar`.
  Future<List<HostCalendarDay>> getListingCalendarDays(
    String listingId, {
    required int month,
    required int year,
  }) async {
    if (month < 1 || month > 12) {
      throw ArgumentError('Tháng không hợp lệ (1–12).');
    }
    if (year < 2020 || year > 2100) {
      throw ArgumentError('Năm không hợp lệ.');
    }
    final response = await _client.dio.get<dynamic>(
      '/api/host/listings/$listingId/calendar',
      queryParameters: {
        'month': month,
        'year': year,
      },
    );
    final rawDays = _extractList(
      response.data,
      const ['days', 'calendar', 'availability', 'items'],
    );
    return rawDays.map(HostCalendarDay.fromJson).toList();
  }

  /// Truy xuất dữ liệu lịch dạng bản đồ thô từ `GET /api/host/listings/:listingId/calendar` (tự động suy diễn tháng/năm từ `startDate` nếu cần).
  Future<List<Map<String, dynamic>>> getListingCalendar(
    String listingId, {
    int? month,
    int? year,
    String? startDate,
    String? endDate,
  }) async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    int targetMonth = month ?? now.month;
    int targetYear = year ?? now.year;

    if ((month == null || year == null) &&
        startDate != null &&
        startDate.isNotEmpty) {
      final parsed = DateTime.tryParse(startDate);
      if (parsed != null) {
        targetMonth = parsed.month;
        targetYear = parsed.year;
      }
    }

    final response = await _client.dio.get<dynamic>(
      '/api/host/listings/$listingId/calendar',
      queryParameters: {
        'month': targetMonth,
        'year': targetYear,
      },
    );
    return _extractList(
      response.data,
      const ['days', 'calendar', 'availability', 'items'],
    );
  }

  // Giải thuật cập nhật hàng loạt lịch lưu trú và giá theo dải ngày (`bulkUpdateListingCalendar`):
  // 1. Kiểm tra quyền Chủ nhà qua `assertHostRoleAuthorized`.
  // 2. Chuẩn hóa danh sách chuỗi ngày đầu vào về `YYYY-MM-DD` (loại bỏ hậu tố giờ ISO `T...`) và gọi `validateCalendarBulkDates`
  //    để chặn mọi ngày sai định dạng, ngày quá khứ hoặc ngày đang có khách đặt phòng thực.
  // 3. Đóng gói các ràng buộc giá ghi đè (`priceOverride`), đóng/mở phòng (`isAvailable`, `isBlockedByHost`) và số đêm tối thiểu
  //    (`minNightsOverride`), bao gồm cờ xóa ghi đè về `null`, rồi gửi `PATCH /api/host/listings/:listingId/calendar/bulk`.
  /// Cập nhật hàng loạt trạng thái khóa phòng, giá theo đêm và số đêm tối thiểu cho tập `dates` trên lịch chỗ nghỉ `listingId`.
  Future<Map<String, dynamic>> bulkUpdateListingCalendar(
    String listingId, {
    required List<String> dates,
    bool? isAvailable,
    bool? isBlockedByHost,
    double? priceOverride,
    bool includeNullPriceOverride = false,
    int? minNightsOverride,
    bool includeNullMinNightsOverride = false,
    String? notes,
    List<HostCalendarDay>? currentCalendarDays,
    String? todayVietnam,
    String? userRole,
  }) async {
    assertHostRoleAuthorized(userRole);
    final normalizedRawDates =
        dates.map((d) => d.trim().split('T').first).toList();
    final validation = validateCalendarBulkDates(
      normalizedRawDates,
      calendarDays: currentCalendarDays ?? const [],
      todayVietnam: todayVietnam,
    );
    if (validation.hasUnauthorizedDates) {
      throw StateError(validation.errorMessage!);
    }

    final validDates = validation.editableDates;
    if (validDates.isEmpty) {
      throw ArgumentError(
          'Vui lòng chọn ít nhất một ngày hợp lệ (YYYY-MM-DD).');
    }

    final payload = <String, dynamic>{
      'dates': validDates,
      if (isAvailable != null) 'isAvailable': isAvailable,
      if (isBlockedByHost != null) 'isBlockedByHost': isBlockedByHost,
      if (priceOverride != null || includeNullPriceOverride)
        'priceOverride': priceOverride,
      if (minNightsOverride != null || includeNullMinNightsOverride)
        'minNightsOverride': minNightsOverride,
      if (notes != null) 'notes': notes,
    };

    final response = await _client.dio.patch<dynamic>(
      '/api/host/listings/$listingId/calendar/bulk',
      data: payload,
    );
    return _unwrapMap(response.data);
  }

  /// Updates calendar via `PATCH /api/host/listings/:listingId/calendar/bulk`.
  Future<void> updateListingCalendar(
    String listingId,
    List<Map<String, dynamic>> entries,
  ) async {
    if (entries.isEmpty) return;
    final first = entries.first;
    final dates = entries
        .map((e) => (e['date'] ?? '').toString())
        .where((d) => d.isNotEmpty)
        .toList();
    if (dates.isEmpty && first['dates'] is List) {
      dates.addAll((first['dates'] as List<dynamic>).map((e) => e.toString()));
    }
    await bulkUpdateListingCalendar(
      listingId,
      dates: dates,
      isAvailable: first['isAvailable'] is bool
          ? first['isAvailable'] as bool
          : (first['available'] is bool ? first['available'] as bool : null),
      isBlockedByHost: first['isBlockedByHost'] is bool
          ? first['isBlockedByHost'] as bool
          : null,
      priceOverride: first['priceOverride'] is num
          ? (first['priceOverride'] as num).toDouble()
          : (first['price'] is num ? (first['price'] as num).toDouble() : null),
      includeNullPriceOverride:
          first.containsKey('priceOverride') && first['priceOverride'] == null,
      minNightsOverride: first['minNightsOverride'] is num
          ? (first['minNightsOverride'] as num).toInt()
          : null,
      notes: first['notes']?.toString(),
    );
  }

  // ===========================================================================
  // BUG-13: Host Bookings (`/api/host/bookings`)
  // ===========================================================================

  /// `GET /api/host/bookings`
  Future<List<Map<String, dynamic>>> getHostBookings({
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    final safeLimit = limit.clamp(1, 100);
    final response = await _client.dio.get<dynamic>(
      '/api/host/bookings',
      queryParameters: {
        if (status != null && status.isNotEmpty && status != 'all')
          'status': status,
        'page': page < 1 ? 1 : page,
        'limit': safeLimit,
      },
    );
    return _extractList(response.data, const ['items', 'bookings', 'data']);
  }

  // Thuật toán tải trọn vẹn các trang đặt phòng của Host từ `/api/host/bookings` (khử trùng theo `bookingId`) để không bỏ sót các đơn Đã nhận phòng, Hoàn tất hoặc Đã hủy ở trang sau.
  /// Tải toàn bộ danh sách đơn đặt phòng của Chủ nhà qua các trang `/api/host/bookings` và khử trùng theo `bookingId`.
  Future<List<Map<String, dynamic>>> getAllHostBookings({
    String? status,
    int pageSize = 100,
    int maxPages = 10,
  }) async {
    final safePageSize = pageSize.clamp(1, 100);
    final safeMaxPages = maxPages.clamp(1, 25);
    final firstResponse = await _client.dio.get<dynamic>(
      '/api/host/bookings',
      queryParameters: {
        if (status != null && status.isNotEmpty && status != 'all')
          'status': status,
        'page': 1,
        'limit': safePageSize,
      },
    );

    final firstItems = _extractList(
      firstResponse.data,
      const ['items', 'bookings', 'data'],
    );
    final unwrapped = _unwrapMap(firstResponse.data);
    final paginationRaw = unwrapped['pagination'];
    final pagination = paginationRaw is Map<Object?, Object?>
        ? Map<String, dynamic>.from(paginationRaw)
        : null;
    final totalPages = int.tryParse('${pagination?['totalPages'] ?? 1}') ?? 1;

    if (totalPages <= 1 || firstItems.isEmpty) {
      return firstItems;
    }

    final merged = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    void appendUnique(List<Map<String, dynamic>> items) {
      for (final item in items) {
        final rawId = '${item['bookingId'] ?? item['id'] ?? ''}'.trim();
        if (rawId.isNotEmpty && !seenIds.add(rawId)) {
          continue;
        }
        merged.add(item);
      }
    }

    appendUnique(firstItems);

    final targetPages = totalPages > safeMaxPages ? safeMaxPages : totalPages;
    for (var currentPage = 2; currentPage <= targetPages; currentPage++) {
      final pageItems = await getHostBookings(
        status: status,
        page: currentPage,
        limit: safePageSize,
      );
      if (pageItems.isEmpty) break;
      appendUnique(pageItems);
    }

    return merged;
  }

  /// `GET /api/host/bookings/:bookingId`
  Future<Map<String, dynamic>> getHostBookingById(String bookingId) async {
    final response = await _client.dio.get<dynamic>(
      '/api/host/bookings/$bookingId',
    );
    final map = _unwrapMap(response.data);
    return map['booking'] is Map<Object?, Object?>
        ? Map<String, dynamic>.from(map['booking'] as Map<Object?, Object?>)
        : map;
  }

  /// `PATCH /api/host/bookings/:bookingId/confirm`
  Future<Map<String, dynamic>> confirmHostBooking(
    String bookingId, {
    Map<String, dynamic>? currentBooking,
    String? userRole,
  }) async {
    assertHostRoleAuthorized(userRole);
    if (currentBooking != null) {
      final actions = getBookingStatusActions(currentBooking);
      if (!actions.canConfirm) {
        throw StateError(
          'Không thể xác nhận booking ở trạng thái hiện tại.',
        );
      }
    }
    final response = await _client.dio.patch<dynamic>(
      '/api/host/bookings/$bookingId/confirm',
    );
    return _unwrapMap(response.data);
  }

  /// `POST /api/host/bookings/:bookingId/check-in`
  Future<Map<String, dynamic>> checkInHostBooking(
    String bookingId, {
    Map<String, dynamic>? currentBooking,
    String? userRole,
    DateTime? now,
  }) async {
    assertHostRoleAuthorized(userRole);
    if (currentBooking != null) {
      final actions = getBookingStatusActions(currentBooking, now: now);
      if (!actions.canCheckIn) {
        throw StateError(
          'Chỉ có thể Check-in khi booking đã xác nhận và đã tới ngày nhận phòng.',
        );
      }
    }
    final response = await _client.dio.post<dynamic>(
      '/api/host/bookings/$bookingId/check-in',
    );
    return _unwrapMap(response.data);
  }

  /// `POST /api/host/bookings/:bookingId/check-out`
  Future<Map<String, dynamic>> checkOutHostBooking(
    String bookingId, {
    Map<String, dynamic>? currentBooking,
    String? userRole,
    DateTime? now,
  }) async {
    assertHostRoleAuthorized(userRole);
    if (currentBooking != null) {
      final actions = getBookingStatusActions(currentBooking, now: now);
      if (!actions.canCheckOut) {
        throw StateError(
          'Chỉ có thể Check-out khi khách đã nhận phòng và tới ngày trả phòng.',
        );
      }
    }
    final response = await _client.dio.post<dynamic>(
      '/api/host/bookings/$bookingId/check-out',
    );
    return _unwrapMap(response.data);
  }

  /// `PATCH /api/host/bookings/:bookingId/cancel`
  Future<Map<String, dynamic>> cancelHostBooking(
    String bookingId, {
    String? reason,
    Map<String, dynamic>? currentBooking,
    String? userRole,
  }) async {
    assertHostRoleAuthorized(userRole);
    if (currentBooking != null) {
      final actions = getBookingStatusActions(currentBooking);
      if (!actions.canCancel) {
        throw StateError(
          'Không thể hủy booking ở trạng thái hiện tại.',
        );
      }
    }
    final trimmedReason = reason?.trim();
    final response = await _client.dio.patch<dynamic>(
      '/api/host/bookings/$bookingId/cancel',
      data: {
        if (trimmedReason != null && trimmedReason.isNotEmpty)
          'reason': trimmedReason,
      },
    );
    return _unwrapMap(response.data);
  }

  // ===========================================================================
  // BUG-13: Payout Accounts & Payouts (`/api/host/payout-accounts`, `/api/host/payouts`)
  // ===========================================================================

  /// `GET /api/host/payout-accounts`
  Future<List<Map<String, dynamic>>> getPayoutAccounts() async {
    final response =
        await _client.dio.get<dynamic>('/api/host/payout-accounts');
    final raw = _extractList(
      response.data,
      const ['items', 'accounts', 'payoutAccounts', 'data'],
    );
    return raw.map(maskSensitivePayoutMap).toList();
  }

  /// `POST /api/host/payout-accounts`
  Future<Map<String, dynamic>> createPayoutAccount(
    Map<String, dynamic> data, {
    String? userRole,
  }) async {
    assertHostRoleAuthorized(userRole);
    final response = await _client.dio.post<dynamic>(
      '/api/host/payout-accounts',
      data: data,
    );
    return maskSensitivePayoutMap(_unwrapMap(response.data));
  }

  /// `PATCH /api/host/payout-accounts/:payoutAccountId`
  Future<Map<String, dynamic>> updatePayoutAccount(
    String payoutAccountId,
    Map<String, dynamic> data, {
    String? userRole,
  }) async {
    assertHostRoleAuthorized(userRole);
    final response = await _client.dio.patch<dynamic>(
      '/api/host/payout-accounts/$payoutAccountId',
      data: data,
    );
    return maskSensitivePayoutMap(_unwrapMap(response.data));
  }

  /// `DELETE /api/host/payout-accounts/:payoutAccountId`
  Future<void> deletePayoutAccount(
    String payoutAccountId, {
    String? userRole,
  }) async {
    assertHostRoleAuthorized(userRole);
    await _client.dio.delete<dynamic>(
      '/api/host/payout-accounts/$payoutAccountId',
    );
  }

  /// `GET /api/host/payouts`
  Future<List<Map<String, dynamic>>> getPayouts({
    String? status,
    String? from,
    String? to,
    int page = 1,
    int limit = 50,
  }) async {
    final safeLimit = limit.clamp(1, 50);
    final response = await _client.dio.get<dynamic>(
      '/api/host/payouts',
      queryParameters: {
        if (status != null && status.isNotEmpty && status != 'all')
          'status': status,
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
        'page': page,
        'limit': safeLimit,
      },
    );
    final raw = _extractList(response.data, const ['items', 'payouts', 'data']);
    return raw.map(maskSensitivePayoutMap).toList();
  }

  // CONFLICT-RESOLVED: Giữ cả phương thức phân trang toàn bộ lịch sử chi trả `getMyPayouts` của nhánh refactor và phương thức tạo yêu cầu rút tiền `requestPayout` từ `origin/develop`.
  // Giải thuật phân trang toàn bộ lịch sử đối soát chi trả của Host (page = 1..totalPages, limit = 50, che số tài khoản nhạy cảm):
  /// Tải toàn bộ các trang lịch sử chi trả của Chủ nhà từ `/api/host/payouts`, khử trùng lặp và che giấu số tài khoản nhạy cảm.
  Future<List<Map<String, dynamic>>> getMyPayouts({
    String? status,
    String? from,
    String? to,
    int limit = 50,
    int maxPages = 20,
  }) async {
    final safeLimit = limit.clamp(1, 50);
    final safeMaxPages = maxPages.clamp(1, 50);
    final effectiveStatus =
        (status != null && status.isNotEmpty && status != 'all')
            ? status
            : null;

    final firstResponse = await _client.dio.get<dynamic>(
      '/api/host/payouts',
      queryParameters: {
        if (effectiveStatus != null) 'status': effectiveStatus,
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
        'page': 1,
        'limit': safeLimit,
      },
    );

    final firstItems = _extractList(
      firstResponse.data,
      const ['items', 'payouts', 'data'],
    ).map(maskSensitivePayoutMap).toList();

    final unwrapped = _unwrapMap(firstResponse.data);
    final paginationRaw = unwrapped['pagination'];
    final pagination = paginationRaw is Map<Object?, Object?>
        ? Map<String, dynamic>.from(paginationRaw)
        : null;
    final totalPages = int.tryParse(
          '${pagination?['totalPages'] ?? unwrapped['totalPages'] ?? 1}',
        ) ??
        1;

    if (totalPages <= 1 || firstItems.isEmpty) {
      return firstItems;
    }

    final merged = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    void appendUnique(List<Map<String, dynamic>> pageItems) {
      for (final item in pageItems) {
        final rawId = '${item['payoutId'] ?? item['id'] ?? ''}'.trim();
        if (rawId.isNotEmpty && !seenIds.add(rawId)) {
          continue;
        }
        merged.add(item);
      }
    }

    appendUnique(firstItems);

    final targetPages = totalPages > safeMaxPages ? safeMaxPages : totalPages;
    for (var currentPage = 2; currentPage <= targetPages; currentPage++) {
      final pageItems = await getPayouts(
        status: effectiveStatus,
        from: from,
        to: to,
        page: currentPage,
        limit: safeLimit,
      );
      if (pageItems.isEmpty) break;
      appendUnique(pageItems);
    }

    return merged;
  }

  /// Gửi yêu cầu rút doanh thu khả dụng của Chủ nhà (`POST /api/host/payouts/request`).
  Future<Map<String, dynamic>> requestPayout({
    required double amount,
    int? payoutAccountId,
    String? notes,
  }) async {
    final response = await _client.dio.post<dynamic>(
      '/api/host/payouts/request',
      data: {
        'amount': amount,
        if (payoutAccountId != null) 'payoutAccountId': payoutAccountId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    if (response.data is Map<String, dynamic>) {
      final resMap = response.data as Map<String, dynamic>;
      if (resMap['data'] is Map<String, dynamic>) {
        return maskSensitivePayoutMap(
          resMap['data'] as Map<String, dynamic>,
        );
      }
      return maskSensitivePayoutMap(resMap);
    }
    return <String, dynamic>{};
  }

  /// Hủy yêu cầu rút tiền đang chờ duyệt (`POST /api/host/payouts/:payoutId/cancel`).
  Future<Map<String, dynamic>> cancelPayout(int payoutId) async {
    final response = await _client.dio.post<dynamic>(
      '/api/host/payouts/$payoutId/cancel',
    );
    if (response.data is Map<String, dynamic>) {
      final resMap = response.data as Map<String, dynamic>;
      if (resMap['data'] is Map<String, dynamic>) {
        return maskSensitivePayoutMap(
          resMap['data'] as Map<String, dynamic>,
        );
      }
      return maskSensitivePayoutMap(resMap);
    }
    return <String, dynamic>{};
  }

  // ===========================================================================
  // BUG-13: Revenue Reports (`GET /api/host/reports/revenue`)
  // ===========================================================================

  /// `GET /api/host/reports/revenue`
  Future<Map<String, dynamic>> getRevenueReport({
    String? startDate,
    String? endDate,
    String? from,
    String? to,
    String? group,
    String? listingId,
  }) async {
    final effectiveFrom = from ?? startDate;
    final effectiveTo = to ?? endDate;
    final response = await _client.dio.get<dynamic>(
      '/api/host/reports/revenue',
      queryParameters: {
        if (effectiveFrom != null && effectiveFrom.isNotEmpty)
          'from': effectiveFrom,
        if (effectiveTo != null && effectiveTo.isNotEmpty) 'to': effectiveTo,
        if (group != null && group.isNotEmpty) 'group': group,
        if (listingId != null && listingId.isNotEmpty && listingId != 'all')
          'listingId': listingId,
      },
    );
    return _unwrapMap(response.data);
  }

  /// Tính toán khoảng thời gian chuẩn (`30d`, `90d`, `year`) theo giờ Việt Nam và tải báo cáo doanh thu `HostRevenueReport`.
  Future<HostRevenueReport> getTypedRevenueReport({
    String rangeKey = '30d',
    String? groupOverride,
    String? listingId,
    String? from,
    String? to,
    DateTime? now,
  }) async {
    final toDate =
        (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
    late final DateTime fromDate;
    late final String defaultGroup;

    if (rangeKey == '90d') {
      fromDate = toDate.subtract(const Duration(days: 89));
      defaultGroup = 'day';
    } else if (rangeKey == 'year') {
      fromDate = DateTime(toDate.year - 1, toDate.month, toDate.day);
      defaultGroup = 'month';
    } else {
      fromDate = toDate.subtract(const Duration(days: 29));
      defaultGroup = 'day';
    }

    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final effectiveGroup =
        (groupOverride != null && groupOverride.trim().isNotEmpty)
            ? groupOverride.trim()
            : defaultGroup;
    final effectiveListingId =
        (listingId != null && listingId.trim().isNotEmpty && listingId != 'all')
            ? listingId.trim()
            : null;

    final raw = await getRevenueReport(
      from: (from != null && from.trim().isNotEmpty)
          ? from.trim()
          : fmt(fromDate),
      to: (to != null && to.trim().isNotEmpty) ? to.trim() : fmt(toDate),
      group: effectiveGroup,
      listingId: effectiveListingId,
    );
    return HostRevenueReport.fromJson(raw, listingId: effectiveListingId);
  }

  // ===========================================================================
  // BUG-38: Reviews, Vietnam Banks (`items` key), Host Bank Account & Profile
  // ===========================================================================

  // Giải thuật tải đánh giá chỗ nghỉ dành cho Host với cơ chế dự phòng an toàn:
  // CONFLICT-RESOLVED: Ưu tiên gọi route xác thực /api/host/listings/:listingId/reviews để chỗ nghỉ draft/pending_approval/hidden/rejected không bị lỗi 404; chỉ fallback sang /api/listings/:listingId/reviews khi gặp 404.
  /// Truy xuất danh sách đánh giá khách hàng của chỗ nghỉ `listingId` (ưu tiên đường dẫn nội bộ của Host, dự phòng sang đường dẫn công khai).
  Future<List<Map<String, dynamic>>> getListingReviews(
    String listingId, {
    int page = 1,
    int limit = 50,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit.clamp(1, 50),
    };
    try {
      final response = await _client.dio.get<dynamic>(
        '/api/host/listings/$listingId/reviews',
        queryParameters: queryParams,
      );
      return _extractList(response.data, const ['items', 'reviews', 'data']);
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) {
        rethrow;
      }
      final fallback = await _client.dio.get<dynamic>(
        '/api/listings/$listingId/reviews',
        queryParameters: queryParams,
      );
      return _extractList(fallback.data, const ['items', 'reviews', 'data']);
    }
  }

  /// `POST /api/reviews/:reviewId/reply` with `{ reply }`
  Future<Map<String, dynamic>> replyToReview(
    String reviewId,
    String reply,
  ) async {
    final trimmed = reply.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Nội dung phản hồi không được để trống.');
    }
    final response = await _client.dio.post<dynamic>(
      '/api/reviews/$reviewId/reply',
      data: {'reply': trimmed},
    );
    return _unwrapMap(response.data);
  }

  /// `GET /api/banks/vn` — parses `items` key from backend response.
  Future<List<Map<String, dynamic>>> getVietnameseBanks() async {
    final response = await _client.dio.get<dynamic>('/api/banks/vn');
    return _extractList(response.data, const ['items', 'banks', 'data']);
  }

  /// Typed Vietnam bank list (`GET /api/banks/vn`).
  Future<List<VietnamBank>> getTypedVietnamBanks() async {
    final rawList = await getVietnameseBanks();
    return rawList
        .map(VietnamBank.fromJson)
        .where((b) => b.code.isNotEmpty)
        .toList();
  }

  /// `GET /api/host/bank-account`
  Future<Map<String, dynamic>?> getBankAccount() async {
    try {
      final response = await _client.dio.get<dynamic>('/api/host/bank-account');
      final map = _unwrapMap(response.data);
      if (map.isEmpty) return null;
      if (map.containsKey('bankAccount')) {
        final inner = map['bankAccount'];
        if (inner == null) return null;
        if (inner is Map<Object?, Object?>) {
          return Map<String, dynamic>.from(inner);
        }
      }
      if (map.containsKey('account')) {
        final inner = map['account'];
        if (inner == null) return null;
        if (inner is Map<Object?, Object?>) {
          return Map<String, dynamic>.from(inner);
        }
      }
      if (map['bankCode'] == null && map['accountNumber'] == null) {
        return null;
      }
      return map;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// `PUT /api/host/bank-account`
  Future<Map<String, dynamic>> saveBankAccount(
    Map<String, dynamic> data,
  ) async {
    final account = HostBankAccount.fromJson(data);
    final validationErr = account.validate();
    if (validationErr != null) {
      throw ArgumentError(validationErr);
    }
    final response = await _client.dio.put<dynamic>(
      '/api/host/bank-account',
      data: account.toJson(),
    );
    final map = _unwrapMap(response.data);
    if (map['bankAccount'] is Map<Object?, Object?>) {
      return Map<String, dynamic>.from(
        map['bankAccount'] as Map<Object?, Object?>,
      );
    }
    if (map['account'] is Map<Object?, Object?>) {
      return Map<String, dynamic>.from(
        map['account'] as Map<Object?, Object?>,
      );
    }
    return map;
  }

  /// `GET /api/users/me`
  Future<Map<String, dynamic>> getHostProfile() async {
    final response = await _client.dio.get<dynamic>('/api/users/me');
    final map = _unwrapMap(response.data);
    if (map['user'] is Map<Object?, Object?>) {
      return Map<String, dynamic>.from(map['user'] as Map<Object?, Object?>);
    }
    return map;
  }

  /// `PATCH /api/users/me`
  Future<Map<String, dynamic>> updateHostProfile({
    required String fullName,
    String? phone,
  }) async {
    final trimmedName = fullName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Họ tên không được để trống.');
    }
    final response = await _client.dio.patch<dynamic>(
      '/api/users/me',
      data: {
        'fullName': trimmedName,
        'phone':
            (phone != null && phone.trim().isNotEmpty) ? phone.trim() : null,
      },
    );
    final map = _unwrapMap(response.data);
    if (map['user'] is Map<Object?, Object?>) {
      return Map<String, dynamic>.from(map['user'] as Map<Object?, Object?>);
    }
    return map;
  }

  /// `PATCH /api/users/me/avatar`
  Future<Map<String, dynamic>> updateHostAvatar({
    required String url,
    String? key,
  }) async {
    final response = await _client.dio.patch<dynamic>(
      '/api/users/me/avatar',
      data: {
        'url': url,
        if (key != null) 'key': key,
      },
    );
    final map = _unwrapMap(response.data);
    if (map['user'] is Map<Object?, Object?>) {
      return Map<String, dynamic>.from(map['user'] as Map<Object?, Object?>);
    }
    return map;
  }

  // ===========================================================================
  // Host Conversations / Messages (`/api/conversations?scope=host`)
  // ===========================================================================

  /// `GET /api/conversations?scope=host`
  Future<List<Map<String, dynamic>>> getHostConversations({
    int page = 1,
    int limit = 50,
    bool? unreadOnly,
  }) async {
    final response = await _client.dio.get<dynamic>(
      '/api/conversations',
      queryParameters: {
        'scope': 'host',
        'page': page,
        'limit': limit.clamp(1, 100),
        if (unreadOnly != null) 'unreadOnly': unreadOnly,
      },
    );
    return _extractList(
      response.data,
      const ['items', 'conversations', 'data'],
    );
  }

  /// `GET /api/conversations/:conversationId/messages`
  Future<List<Map<String, dynamic>>> getConversationMessages(
    String conversationId, {
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _client.dio.get<dynamic>(
      '/api/conversations/$conversationId/messages',
      queryParameters: {
        'page': page,
        'limit': limit.clamp(1, 100),
      },
    );
    return _extractList(response.data, const ['items', 'messages', 'data']);
  }

  // Giải thuật mở hoặc tái sử dụng hội thoại hỗ trợ thực với Quản trị viên:
  // CONFLICT-RESOLVED: Tạo conversation ID số thực qua POST /api/conversations thay vì gửi tới khóa giả lập 'admin_support'.
  /// Mở mới hoặc truy xuất hội thoại hỗ trợ trực tiếp với Quản trị viên qua `POST /api/conversations` (`{"support": true}`).
  Future<Map<String, dynamic>> openSupportConversation({
    String? firstMessage,
  }) async {
    final trimmedMessage = firstMessage?.trim();
    final response = await _client.dio.post<dynamic>(
      '/api/conversations',
      data: <String, dynamic>{
        'support': true,
        if (trimmedMessage != null && trimmedMessage.isNotEmpty)
          'firstMessage': trimmedMessage,
      },
    );
    final map = _unwrapMap(response.data);
    if (map['conversation'] is Map<Object?, Object?>) {
      return Map<String, dynamic>.from(
        map['conversation'] as Map<Object?, Object?>,
      );
    }
    return map;
  }

  /// `PATCH /api/conversations/:conversationId/read`
  Future<void> markConversationRead(String conversationId) async {
    final trimmed = conversationId.trim();
    if (!isNumericHostConversationId(trimmed)) {
      return;
    }
    await _client.dio.patch<dynamic>('/api/conversations/$trimmed/read');
  }

  /// `POST /api/conversations/:conversationId/messages`
  Future<Map<String, dynamic>> sendConversationMessage(
    String conversationId,
    String content, {
    String messageType = 'text',
    List<Map<String, dynamic>>? attachments,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty && (attachments == null || attachments.isEmpty)) {
      throw ArgumentError('Nội dung tin nhắn không được để trống.');
    }
    final response = await _client.dio.post<dynamic>(
      '/api/conversations/$conversationId/messages',
      data: {
        'content': trimmed,
        'messageType': messageType,
        if (attachments != null && attachments.isNotEmpty)
          'attachments': attachments,
      },
    );
    return _unwrapMap(response.data);
  }

  /// Tải luồng byte ảnh giấy tờ tùy thân lên `POST /api/ai/id-card-vision/extract` để trích xuất thông tin OCR tự động.
  Future<HostIdentityAiResult> analyzeIdentityCard({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) async {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: MediaType.parse(
          mimeType.isNotEmpty ? mimeType : 'image/jpeg',
        ),
      ),
    });

    final response = await _client.dio.post<dynamic>(
      '/api/ai/id-card-vision/extract',
      data: formData,
    );

    final map = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : Map<String, dynamic>.from(response.data as Map<Object?, Object?>);

    final data = map['data'] is Map<String, dynamic>
        ? map['data'] as Map<String, dynamic>
        : Map<String, dynamic>.from(
            (map['data'] as Map<Object?, Object?>?) ?? <String, dynamic>{},
          );

    return HostIdentityAiResult.fromJson(data);
  }

  // ===========================================================================
  // Google Sheets Agency Mode (`/api/host/sheet-sync/*` & Listing Restore)
  // ===========================================================================

  /// Áp đặt kiểm tra vai trò Chủ nhà độc quyền (`role == 'host'`), từ chối cả khách vãng lai (`401`) lẫn vai trò khác (`403`) khớp `requireHostOnly` của Backend.
  void assertStrictHostOnlyRoleAuthorized([String? userRole]) {
    if (userRole == null && _roleResolver == null) return;
    final effectiveRole = userRole ?? _roleResolver?.call();
    if (effectiveRole == null || effectiveRole.trim().isEmpty) {
      throw HostAuthorizationException(
        'Vui lòng đăng nhập bằng tài khoản Chủ nhà (Host) để quản lý đồng bộ Google Sheets.',
        statusCode: 401,
      );
    }
    if (effectiveRole.trim().toLowerCase() != 'host') {
      throw HostAuthorizationException(
        'Tài khoản "$effectiveRole" không có quyền truy cập cấu hình Google Sheets của Chủ nhà.',
        statusCode: 403,
        userRole: effectiveRole,
      );
    }
  }

  /// Khôi phục chỗ nghỉ đã xóa mềm qua `POST /api/host/listings/:listingId/restore` và giữ nguyên mã `listingId` gốc bất biến.
  Future<Map<String, dynamic>> restoreHostListing(
    String listingId, {
    String? userRole,
  }) async {
    assertHostRoleAuthorized(userRole);
    final trimmed = listingId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Mã căn cần khôi phục không hợp lệ.');
    }
    final response = await _client.dio.post<dynamic>(
      '/api/host/listings/$trimmed/restore',
    );
    final map = _unwrapMap(response.data);
    final listing = map['listing'] is Map<Object?, Object?>
        ? Map<String, dynamic>.from(map['listing'] as Map<Object?, Object?>)
        : map;
    return _normalizeListingMap(listing);
  }

  /// `GET /api/host/sheet-sync/status`
  Future<HostSheetSyncStatusPayload> getHostSheetSyncStatus({
    String? userRole,
  }) async {
    assertStrictHostOnlyRoleAuthorized(userRole);
    final response = await _client.dio.get<dynamic>(
      '/api/host/sheet-sync/status',
    );
    return HostSheetSyncStatusPayload.fromJson(_unwrapMap(response.data));
  }

  /// `POST /api/host/sheet-sync/connect`
  Future<HostSheetSyncStatusPayload> connectHostSheet({
    required String spreadsheetUrlOrId,
    String? hostEditorEmail,
    bool autoSyncEnabled = true,
    bool strictBookingPrecheck = true,
    bool initializeImmediately = true,
    String? userRole,
  }) async {
    assertStrictHostOnlyRoleAuthorized(userRole);
    final urlValidationError = validateGoogleSheetInput(spreadsheetUrlOrId);
    if (urlValidationError != null) {
      throw ArgumentError(urlValidationError);
    }
    final emailValidationError = validateOptionalEditorEmail(hostEditorEmail);
    if (emailValidationError != null) {
      throw ArgumentError(emailValidationError);
    }

    final trimmedEmail = hostEditorEmail?.trim();
    final response = await _client.dio.post<dynamic>(
      '/api/host/sheet-sync/connect',
      data: <String, dynamic>{
        'spreadsheetUrlOrId': spreadsheetUrlOrId.trim(),
        if (trimmedEmail != null && trimmedEmail.isNotEmpty)
          'hostEditorEmail': trimmedEmail,
        'autoSyncEnabled': autoSyncEnabled,
        'strictBookingPrecheck': strictBookingPrecheck,
        'initializeImmediately': initializeImmediately,
      },
    );
    return HostSheetSyncStatusPayload.fromJson(_unwrapMap(response.data));
  }

  /// `POST /api/host/sheet-sync/verify-permissions`
  Future<HostSheetSyncStatusPayload> verifyHostSheetPermissions({
    String? userRole,
  }) async {
    assertStrictHostOnlyRoleAuthorized(userRole);
    final response = await _client.dio.post<dynamic>(
      '/api/host/sheet-sync/verify-permissions',
    );
    return HostSheetSyncStatusPayload.fromJson(_unwrapMap(response.data));
  }

  /// `POST /api/host/sheet-sync/init-calendar`
  Future<HostSheetSyncStatusPayload> initializeHostSheetCalendar({
    String? userRole,
  }) async {
    assertStrictHostOnlyRoleAuthorized(userRole);
    final response = await _client.dio.post<dynamic>(
      '/api/host/sheet-sync/init-calendar',
    );
    return HostSheetSyncStatusPayload.fromJson(_unwrapMap(response.data));
  }

  /// `POST /api/host/sheet-sync/sync-now`
  Future<HostSheetSyncStatusPayload> syncHostSheetNow({
    String? userRole,
  }) async {
    assertStrictHostOnlyRoleAuthorized(userRole);
    final response = await _client.dio.post<dynamic>(
      '/api/host/sheet-sync/sync-now',
    );
    return HostSheetSyncStatusPayload.fromJson(_unwrapMap(response.data));
  }

  /// `PATCH /api/host/sheet-sync/settings`
  Future<HostSheetSyncStatusPayload> updateHostSheetSettings({
    String? hostEditorEmail,
    bool? autoSyncEnabled,
    bool? strictBookingPrecheck,
    String? userRole,
  }) async {
    assertStrictHostOnlyRoleAuthorized(userRole);
    if (hostEditorEmail != null) {
      final emailErr = validateOptionalEditorEmail(hostEditorEmail);
      if (emailErr != null) {
        throw ArgumentError(emailErr);
      }
    }
    final response = await _client.dio.patch<dynamic>(
      '/api/host/sheet-sync/settings',
      data: <String, dynamic>{
        if (hostEditorEmail != null) 'hostEditorEmail': hostEditorEmail.trim(),
        if (autoSyncEnabled != null) 'autoSyncEnabled': autoSyncEnabled,
        if (strictBookingPrecheck != null)
          'strictBookingPrecheck': strictBookingPrecheck,
      },
    );
    return HostSheetSyncStatusPayload.fromJson(_unwrapMap(response.data));
  }

  /// `DELETE /api/host/sheet-sync/disconnect`
  Future<HostSheetSyncStatusPayload> disconnectHostSheet({
    String? userRole,
  }) async {
    assertStrictHostOnlyRoleAuthorized(userRole);
    final response = await _client.dio.delete<dynamic>(
      '/api/host/sheet-sync/disconnect',
    );
    return HostSheetSyncStatusPayload.fromJson(_unwrapMap(response.data));
  }

  /// `GET /api/host/sheet-sync/conflicts`
  Future<List<HostSheetWarningItem>> getHostSheetConflicts({
    String? status,
    int? listingId,
    int page = 1,
    int limit = 20,
    String? userRole,
  }) async {
    assertStrictHostOnlyRoleAuthorized(userRole);
    final response = await _client.dio.get<dynamic>(
      '/api/host/sheet-sync/conflicts',
      queryParameters: <String, dynamic>{
        if (status != null && status.isNotEmpty) 'status': status,
        if (listingId != null) 'listingId': listingId,
        'page': page < 1 ? 1 : page,
        'limit': limit.clamp(1, 50),
      },
    );
    final rawItems = _extractList(
      response.data,
      const ['items', 'conflicts', 'data'],
    );
    return rawItems.map(HostSheetWarningItem.fromJson).toList();
  }

  /// `POST /api/host/sheet-sync/conflicts/:conflictId/resolve`
  Future<HostSheetSyncStatusPayload> resolveHostSheetConflict({
    required int conflictId,
    required String action,
    String? userRole,
  }) async {
    assertStrictHostOnlyRoleAuthorized(userRole);
    const allowedActions = <String>{
      'keep_locked',
      'unlock_if_safe',
      'undo_bulk_change',
      'repair_structure',
    };
    if (conflictId <= 0) {
      throw ArgumentError('Mã cảnh báo xung đột không hợp lệ.');
    }
    if (!allowedActions.contains(action)) {
      throw ArgumentError('Thao tác xử lý xung đột không hợp lệ.');
    }
    final response = await _client.dio.post<dynamic>(
      '/api/host/sheet-sync/conflicts/$conflictId/resolve',
      data: <String, dynamic>{'action': action},
    );
    return HostSheetSyncStatusPayload.fromJson(_unwrapMap(response.data));
  }

  /// `GET /api/host/sheet-sync/logs`
  Future<List<HostSheetChangeLogItem>> getHostSheetChangeLogs({
    int? listingId,
    String? search,
    int page = 1,
    int limit = 20,
    String? userRole,
  }) async {
    assertStrictHostOnlyRoleAuthorized(userRole);
    final trimmedSearch = search?.trim();
    final response = await _client.dio.get<dynamic>(
      '/api/host/sheet-sync/logs',
      queryParameters: <String, dynamic>{
        if (listingId != null) 'listingId': listingId,
        if (trimmedSearch != null && trimmedSearch.isNotEmpty)
          'search': trimmedSearch,
        'page': page < 1 ? 1 : page,
        'limit': limit.clamp(1, 50),
      },
    );
    final rawItems = _extractList(
      response.data,
      const ['items', 'logs', 'data'],
    );
    return rawItems.map(HostSheetChangeLogItem.fromJson).toList();
  }
}
