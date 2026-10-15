import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/security/secure_storage_service.dart';
import '../domain/host_models.dart';
import '../services/host_file_picker_service.dart';

final hostCurrentUserRoleProvider = Provider<String?>((ref) => 'host');

final hostRepositoryProvider = Provider<HostRepository>((ref) {
  return HostRepository(HostRepository.createDefaultDio());
});

class _HostDioHolder {
  final Dio dio;
  const _HostDioHolder(this.dio);
}

class HostRepository {
  final _HostDioHolder _client;
  final HostR2DirectUploader _r2Uploader;

  HostRepository(
    dynamic clientOrDio, {
    HostR2DirectUploader? r2Uploader,
  })  : _client = _HostDioHolder(_extractDio(clientOrDio)),
        _r2Uploader = r2Uploader ?? HostR2DirectUploader();

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

  String extractErrorMessage(
    Object error, [
    String fallback = 'Đã xảy ra lỗi khi kết nối máy chủ.',
  ]) {
    if (error is ArgumentError) {
      return error.message?.toString() ?? fallback;
    }
    if (error is FormatException) {
      return error.message;
    }
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<Object?, Object?>) {
        final msg = data['message'] ?? data['error'];
        if (msg != null && msg.toString().trim().isNotEmpty) {
          return msg.toString().trim();
        }
        final errors = data['errors'];
        if (errors is List && errors.isNotEmpty) {
          final first = errors.first;
          if (first is Map<Object?, Object?> && first['msg'] != null) {
            return first['msg'].toString();
          }
          return first.toString();
        }
      }
      if (error.message != null && error.message!.trim().isNotEmpty) {
        return error.message!.trim();
      }
    }
    final text = error.toString();
    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }
    return text.isNotEmpty ? text : fallback;
  }

  /// Ensures only authorized roles (`host` or `admin`) can execute Host Portal
  /// mutations when user role metadata is provided.
  void assertHostRoleAuthorized(String? userRole) {
    if (userRole == null) return;
    final normalized = userRole.trim().toLowerCase();
    if (normalized != 'host' && normalized != 'admin') {
      throw StateError(
        'Tài khoản "$userRole" không có quyền thực hiện thao tác dành riêng cho Chủ nhà (Host).',
      );
    }
  }

  // ===========================================================================
  // BUG-10: Host Applications & KYC (`/api/host/applications`)
  // ===========================================================================

  /// `GET /api/host/applications/me`
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

  /// Typed wrapper for `GET /api/host/applications/me`.
  Future<HostApplicationRecord?> getMyApplicationRecord() async {
    final map = await getMyApplication();
    if (map == null) return null;
    return HostApplicationRecord.fromApiResponse(map);
  }

  /// `POST /api/host/applications` using `multipart/form-data`.
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

  /// Submits a Host Application via `POST /api/host/applications`.
  /// Requires real `FormData` (`multipart/form-data`) or a valid [HostKycSubmissionDto].
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

  /// `GET /api/host/applications/me` (with fallback to `GET /api/host/verifications/me`).
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

  // ===========================================================================
  // BUG-11: Host Listings (`GET /api/host/listings/mine`)
  // ===========================================================================

  /// `GET /api/host/listings/mine`
  /// Supported statuses: `draft`, `pending_approval`, `published`, `hidden`, `rejected`.
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

  Map<String, dynamic> _normalizeListingMap(Map<String, dynamic> raw) {
    final copy = Map<String, dynamic>.from(raw);
    final statusEnum = HostListingStatus.fromApi(copy['status']);
    copy['status'] = statusEnum.value;
    copy['id'] = copy['listingId'] ?? copy['id'];
    copy['listingId'] = copy['listingId'] ?? copy['id'];
    return copy;
  }

  /// `GET /api/host/listings/:listingId`
  Future<Map<String, dynamic>> getHostListingById(String id) async {
    final response = await _client.dio.get<dynamic>('/api/host/listings/$id');
    final map = _unwrapMap(response.data);
    final listing = map['listing'] is Map<Object?, Object?>
        ? Map<String, dynamic>.from(map['listing'] as Map<Object?, Object?>)
        : map;
    return _normalizeListingMap(listing);
  }

  /// `POST /api/host/listings`
  Future<Map<String, dynamic>> createHostListing(
    Map<String, dynamic> data,
  ) async {
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

  /// `PATCH /api/host/listings/:listingId`
  Future<Map<String, dynamic>> updateHostListing(
    String id,
    Map<String, dynamic> data,
  ) async {
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

  /// `PATCH /api/host/listings/:listingId` -> `{ status: 'pending_approval' }`
  Future<Map<String, dynamic>> submitListingForApproval(String listingId) {
    return updateHostListing(listingId, const {'status': 'pending_approval'});
  }

  /// `PATCH /api/host/listings/:listingId` -> `{ status: 'hidden' }`
  Future<Map<String, dynamic>> hideHostListing(String listingId) {
    return updateHostListing(listingId, const {'status': 'hidden'});
  }

  /// `PATCH /api/host/listings/:listingId` -> `{ status: 'published' }`
  Future<Map<String, dynamic>> publishHostListing(String listingId) {
    return updateHostListing(listingId, const {'status': 'published'});
  }

  /// `DELETE /api/host/listings/:listingId`
  Future<void> deleteHostListing(String id) async {
    await _client.dio.delete<dynamic>('/api/host/listings/$id');
  }

  Map<String, dynamic> _sanitizeCreateListingPayload(
    Map<String, dynamic> input,
  ) {
    final copy = Map<String, dynamic>.from(input);
    copy['country'] = 'VN';
    copy['currency'] = 'VND';
    copy['propertyType'] =
        HostPropertyType.fromApi(copy['propertyType']).value;
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
    final rawStatus = (copy['status'] ?? 'draft').toString().trim().toLowerCase();
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

  /// `POST /api/uploads/presign`
  Future<HostR2UploadResult> presignUpload({
    required String filename,
    required String contentType,
    String folder = 'listings',
    String? listingId,
  }) async {
    final body = <String, dynamic>{
      'folder': folder,
      'filename': filename,
      'contentType': contentType,
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

  /// Validates [file], requests presigned URL from backend, and uploads raw bytes
  /// directly to R2 via `PUT` without leaking the API Bearer token.
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
  Future<({
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
  Future<({int analyzedCount, int failedCount, List<ExistingListingImage> images})>
      analyzeAllListingImages(
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
    final cleanTags = tags
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
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

  /// `GET /api/host/listings/:listingId/calendar?month=M&year=Y`
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

  /// Map-based calendar getter for `GET /api/host/listings/:listingId/calendar`.
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

  /// `PATCH /api/host/listings/:listingId/calendar/bulk`
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
  }) async {
    final validDates = dates
        .map((d) => d.trim().split('T').first)
        .where((d) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d))
        .toSet()
        .toList()
      ..sort();

    if (validDates.isEmpty) {
      throw ArgumentError('Vui lòng chọn ít nhất một ngày hợp lệ (YYYY-MM-DD).');
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
      includeNullPriceOverride: first.containsKey('priceOverride') &&
          first['priceOverride'] == null,
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
    final safeLimit = limit.clamp(1, 50);
    final response = await _client.dio.get<dynamic>(
      '/api/host/bookings',
      queryParameters: {
        if (status != null && status.isNotEmpty && status != 'all')
          'status': status,
        'page': page,
        'limit': safeLimit,
      },
    );
    return _extractList(response.data, const ['items', 'bookings', 'data']);
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
    final response = await _client.dio.get<dynamic>('/api/host/payout-accounts');
    return _extractList(
      response.data,
      const ['items', 'accounts', 'payoutAccounts', 'data'],
    );
  }

  /// `POST /api/host/payout-accounts`
  Future<Map<String, dynamic>> createPayoutAccount(
    Map<String, dynamic> data,
  ) async {
    final response = await _client.dio.post<dynamic>(
      '/api/host/payout-accounts',
      data: data,
    );
    return _unwrapMap(response.data);
  }

  /// `PATCH /api/host/payout-accounts/:payoutAccountId`
  Future<Map<String, dynamic>> updatePayoutAccount(
    String payoutAccountId,
    Map<String, dynamic> data,
  ) async {
    final response = await _client.dio.patch<dynamic>(
      '/api/host/payout-accounts/$payoutAccountId',
      data: data,
    );
    return _unwrapMap(response.data);
  }

  /// `DELETE /api/host/payout-accounts/:payoutAccountId`
  Future<void> deletePayoutAccount(String payoutAccountId) async {
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
    return _extractList(response.data, const ['items', 'payouts', 'data']);
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
        if (listingId != null && listingId.isNotEmpty) 'listingId': listingId,
      },
    );
    return _unwrapMap(response.data);
  }

  /// Computes date range (`30d`, `90d`, `year`) matching `BaoCao/index.tsx`
  /// and fetches `HostRevenueReport`.
  Future<HostRevenueReport> getTypedRevenueReport({
    String rangeKey = '30d',
    DateTime? now,
  }) async {
    final toDate = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
    late final DateTime fromDate;
    late final String group;

    if (rangeKey == '90d') {
      fromDate = toDate.subtract(const Duration(days: 89));
      group = 'day';
    } else if (rangeKey == 'year') {
      fromDate = DateTime(toDate.year - 1, toDate.month, toDate.day);
      group = 'month';
    } else {
      fromDate = toDate.subtract(const Duration(days: 29));
      group = 'day';
    }

    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final raw = await getRevenueReport(
      from: fmt(fromDate),
      to: fmt(toDate),
      group: group,
    );
    return HostRevenueReport.fromJson(raw);
  }

  // ===========================================================================
  // BUG-38: Reviews, Vietnam Banks (`items` key), Host Bank Account & Profile
  // ===========================================================================

  /// `GET /api/listings/:listingId/reviews`
  Future<List<Map<String, dynamic>>> getListingReviews(
    String listingId, {
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _client.dio.get<dynamic>(
      '/api/listings/$listingId/reviews',
      queryParameters: {
        'page': page,
        'limit': limit.clamp(1, 50),
      },
    );
    return _extractList(response.data, const ['items', 'reviews', 'data']);
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
        'phone': (phone != null && phone.trim().isNotEmpty)
            ? phone.trim()
            : null,
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

  /// `POST /api/conversations/:conversationId/messages`
  Future<Map<String, dynamic>> sendConversationMessage(
    String conversationId,
    String content,
  ) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Nội dung tin nhắn không được để trống.');
    }
    final response = await _client.dio.post<dynamic>(
      '/api/conversations/$conversationId/messages',
      data: {'content': trimmed},
    );
    return _unwrapMap(response.data);
  }
}
