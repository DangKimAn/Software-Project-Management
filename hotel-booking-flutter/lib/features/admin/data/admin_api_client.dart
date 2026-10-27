import 'package:dio/dio.dart';

class AdminRevenuePoint {
  const AdminRevenuePoint({
    required this.period,
    required this.grossRevenue,
    this.platformRevenue = 0,
    this.hostRevenue = 0,
    this.bookingCount = 0,
  });

  final String period;
  final double grossRevenue;
  final double platformRevenue;
  final double hostRevenue;
  final int bookingCount;

  factory AdminRevenuePoint.fromJson(Map<String, dynamic> json) {
    return AdminRevenuePoint(
      period: '${json['period'] ?? json['date'] ?? ''}',
      grossRevenue: double.tryParse('${json['grossRevenue'] ?? 0}') ?? 0,
      platformRevenue: double.tryParse('${json['platformRevenue'] ?? 0}') ?? 0,
      hostRevenue: double.tryParse('${json['hostRevenue'] ?? 0}') ?? 0,
      bookingCount: int.tryParse('${json['bookingCount'] ?? 0}') ?? 0,
    );
  }
}

class AdminOverviewStats {
  const AdminOverviewStats({
    required this.users,
    required this.pendingListings,
    required this.grossRevenue,
    required this.bookings,
    required this.hosts,
    required this.activeListings,
    this.platformRevenue = 0,
    this.hostRevenue = 0,
    this.pendingBookings = 0,
    this.paidBookings = 0,
    this.completedBookings = 0,
    this.cancelledBookings = 0,
    this.activeHosts = 0,
    this.verifiedHosts = 0,
    this.listingsCreated = 0,
    this.inactiveListings = 0,
    this.revenueSeries = const [],
    this.from = '',
    this.to = '',
    this.group = 'day',
  });

  final int users;
  final int pendingListings;
  final double grossRevenue;
  final double platformRevenue;
  final double hostRevenue;
  final int bookings;
  final int pendingBookings;
  final int paidBookings;
  final int completedBookings;
  final int cancelledBookings;
  final int hosts;
  final int activeHosts;
  final int verifiedHosts;
  final int activeListings;
  final int listingsCreated;
  final int inactiveListings;
  final List<AdminRevenuePoint> revenueSeries;
  final String from;
  final String to;
  final String group;

  bool get hasAnyActivity =>
      users > 0 ||
      pendingListings > 0 ||
      grossRevenue > 0 ||
      bookings > 0 ||
      hosts > 0 ||
      activeListings > 0 ||
      listingsCreated > 0 ||
      revenueSeries.isNotEmpty;
}

class AdminPaginatedResult<T> {
  const AdminPaginatedResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<T> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
}

class AdminModerationPolicy {
  const AdminModerationPolicy._();

  static const List<String> supportedRoles = <String>[
    'guest',
    'host',
    'moderator',
    'admin',
  ];

  static bool isAdminRole({
    String? primaryRole,
    Iterable<String> roles = const <String>[],
  }) {
    if (primaryRole != null && primaryRole.trim().toLowerCase() == 'admin') {
      return true;
    }
    return roles.any((r) => r.trim().toLowerCase() == 'admin');
  }

  static bool isModeratorOrAdminRole({
    String? primaryRole,
    Iterable<String> roles = const <String>[],
  }) {
    if (isAdminRole(primaryRole: primaryRole, roles: roles)) {
      return true;
    }
    if (primaryRole != null &&
        primaryRole.trim().toLowerCase() == 'moderator') {
      return true;
    }
    return roles.any((r) => r.trim().toLowerCase() == 'moderator');
  }

  static String? validateListingApprove({
    required Set<String> viewedListingIds,
    required String listingId,
    required bool canModerate,
  }) {
    if (!canModerate) {
      return 'Bạn không có quyền kiểm duyệt bài đăng (403).';
    }
    if (!viewedListingIds.contains(listingId)) {
      return 'Vui lòng xem chi tiết căn trước khi duyệt.';
    }
    return null;
  }

  static String? validateListingReject({
    required Set<String> viewedListingIds,
    required String listingId,
    required bool canModerate,
    String? reason,
  }) {
    if (!canModerate) {
      return 'Bạn không có quyền kiểm duyệt bài đăng (403).';
    }
    if (!viewedListingIds.contains(listingId)) {
      return 'Vui lòng xem chi tiết căn trước khi từ chối.';
    }
    if (reason != null && reason.trim().isEmpty) {
      return 'Vui lòng nhập lý do từ chối.';
    }
    return null;
  }

  static String? validateUserStatusMutation({
    required bool isActorAdmin,
    required String? actorId,
    required String targetUserId,
  }) {
    if (!isActorAdmin) {
      return 'Chỉ Quản trị viên (Admin) mới có quyền khóa hoặc mở khóa tài khoản.';
    }
    if (actorId != null && actorId.isNotEmpty && actorId == targetUserId) {
      return 'Bạn không thể tự khóa tài khoản của chính mình.';
    }
    return null;
  }

  static String? validateRoleMutation({
    required bool isActorAdmin,
    required String? actorId,
    required String targetUserId,
    required String nextRole,
  }) {
    if (!isActorAdmin) {
      return 'Chỉ Quản trị viên (Admin) mới có quyền thay đổi vai trò.';
    }
    if (!supportedRoles.contains(nextRole)) {
      return 'Vai trò không hợp lệ.';
    }
    if (actorId != null &&
        actorId.isNotEmpty &&
        actorId == targetUserId &&
        nextRole != 'admin') {
      return 'Bạn không thể tự hạ quyền Admin của chính mình.';
    }
    return null;
  }
}

class AdminRepository {
  AdminRepository(this._dio);

  static const int maxUsersPageLimit = 100;
  static const int maxListingsPageLimit = 50;

  final Dio _dio;

  static bool _isNetworkLikeObject(Object? obj) {
    if (obj == null) return false;
    final typeName = obj.runtimeType.toString();
    return typeName.contains('NetworkFailure') ||
        typeName.contains('OfflineFailure') ||
        typeName.contains('ConnectionRefusedFailure') ||
        typeName.contains('TimeoutFailure') ||
        typeName.contains('SocketException');
  }

  static bool isOfflineError(Object error) {
    if (_isNetworkLikeObject(error)) {
      return true;
    }
    if (error is DioException) {
      if (error.response != null) {
        return false;
      }
      if (_isNetworkLikeObject(error.error)) {
        return true;
      }
      return error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout;
    }
    return false;
  }

  static int? extractStatusCode(Object error) {
    if (error is DioException) {
      return error.response?.statusCode;
    }
    return null;
  }

  static String sanitizeSensitiveText(String input) {
    if (input.isEmpty) return input;
    var sanitized = input.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
      'Bearer [REDACTED]',
    );
    sanitized = sanitized.replaceAll(
      RegExp(
        r'([?&](?:token|access_token|refresh_token|signature|X-Amz-Signature|X-Amz-Credential)=)[^&\s]+',
        caseSensitive: false,
      ),
      r'$1[REDACTED]',
    );
    return sanitized;
  }

  static String maskKycIdentifier(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '—';
    if (trimmed.contains('*')) return trimmed;
    if (trimmed.length <= 4) {
      return '*' * trimmed.length;
    }
    final suffix = trimmed.substring(trimmed.length - 4);
    return '***$suffix';
  }

  static String extractErrorMessage(
    Object error, [
    String fallback = 'Đã xảy ra lỗi. Vui lòng thử lại.',
  ]) {
    if (isOfflineError(error)) {
      return 'Không thể kết nối máy chủ. Vui lòng kiểm tra kết nối mạng và thử lại.';
    }
    if (error is DioException) {
      final status = error.response?.statusCode;
      final data = error.response?.data;
      if (data is Map) {
        final rawList = data['errors'] is List
            ? data['errors'] as List
            : (data['details'] is List ? data['details'] as List : null);
        if (rawList != null && rawList.isNotEmpty) {
          final msgs = rawList
              .map((e) {
                if (e is Map) {
                  return '${e['msg'] ?? e['message'] ?? e['error'] ?? ''}'
                      .trim();
                }
                return '$e'.trim();
              })
              .where((s) => s.isNotEmpty)
              .toList();
          if (msgs.isNotEmpty) {
            return sanitizeSensitiveText(msgs.join('; '));
          }
        }
        final msg = '${data['message'] ?? data['error'] ?? ''}'.trim();
        if (msg.isNotEmpty) {
          return sanitizeSensitiveText(msg);
        }
      }
      if (status == 401) {
        return 'Phiên đăng nhập đã hết hạn hoặc chưa xác thực (401).';
      }
      if (status == 403) {
        return 'Bạn không có quyền thực hiện thao tác này (403).';
      }
      if (status == 404) {
        return 'Không tìm thấy dữ liệu yêu cầu (404).';
      }
      if (status == 409) {
        return 'Dữ liệu đã thay đổi hoặc xung đột trạng thái (409). Vui lòng tải lại.';
      }
      if (status == 422 || status == 400) {
        return 'Dữ liệu gửi lên không hợp lệ ($status).';
      }
      if (status == 429) {
        return 'Thao tác quá nhanh, vui lòng thử lại sau ít phút (429).';
      }
      if (status != null && status >= 500) {
        return 'Máy chủ đang gặp sự cố ($status). Vui lòng thử lại sau.';
      }
      final nested = error.error;
      if (nested != null && nested is! Exception && nested is! Error) {
        final nestedText = '$nested'.trim();
        if (nestedText.isNotEmpty) {
          return sanitizeSensitiveText(nestedText);
        }
      }
    }
    return fallback;
  }

  Map<String, dynamic> _unwrapMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      if (raw['data'] is Map<String, dynamic>) {
        return raw['data'] as Map<String, dynamic>;
      }
      return raw;
    }
    if (raw is Map) {
      final casted = Map<String, dynamic>.from(raw);
      if (casted['data'] is Map) {
        return Map<String, dynamic>.from(casted['data'] as Map);
      }
      return casted;
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _extractItems(dynamic raw) {
    final map = _unwrapMap(raw);
    final candidates = [
      map['items'],
      map['listings'],
      map['users'],
      map['applications'],
      map['verifications'],
      map['payouts'],
      if (raw is Map) raw['data'],
      raw,
    ];
    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return const [];
  }

  int _extractTotal(dynamic raw) {
    final map = _unwrapMap(raw);
    final pagination = map['pagination'];
    if (pagination is Map && pagination['total'] != null) {
      return int.tryParse('${pagination['total']}') ?? 0;
    }
    if (map['total'] != null) {
      return int.tryParse('${map['total']}') ?? 0;
    }
    return _extractItems(raw).length;
  }

  AdminPaginatedResult<Map<String, dynamic>> _extractPaginated(
    dynamic raw, {
    required int fallbackPage,
    required int fallbackLimit,
  }) {
    final items = _extractItems(raw);
    final map = _unwrapMap(raw);
    final pagination = map['pagination'] is Map
        ? Map<String, dynamic>.from(map['pagination'] as Map)
        : const <String, dynamic>{};
    final page = int.tryParse('${pagination['page'] ?? map['page'] ?? ''}') ??
        fallbackPage;
    final limit =
        int.tryParse('${pagination['limit'] ?? map['limit'] ?? ''}') ??
            fallbackLimit;
    final total = _extractTotal(raw);
    final computedPages = limit > 0 ? ((total + limit - 1) ~/ limit) : 1;
    final totalPages = int.tryParse(
          '${pagination['totalPages'] ?? map['totalPages'] ?? ''}',
        ) ??
        (computedPages < 1 ? 1 : computedPages);
    return AdminPaginatedResult<Map<String, dynamic>>(
      items: items,
      page: page,
      limit: limit,
      total: total,
      totalPages: totalPages < 1 ? 1 : totalPages,
    );
  }

  static String _formatDateIso(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  // ── Overview Reports ──
  Future<AdminOverviewStats> getOverviewStats({
    int days = 30,
    String? from,
    String? to,
    String group = 'day',
  }) async {
    final vietnamNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    final today = DateTime.utc(
      vietnamNow.year,
      vietnamNow.month,
      vietnamNow.day,
    );
    final safeDays = days < 1 ? 30 : days;
    final startDate = today.subtract(Duration(days: safeDays - 1));
    final resolvedFrom = (from != null && from.trim().isNotEmpty)
        ? from.trim()
        : _formatDateIso(startDate);
    final resolvedTo = (to != null && to.trim().isNotEmpty)
        ? to.trim()
        : _formatDateIso(today);
    final resolvedGroup =
        ['day', 'month', 'year'].contains(group) ? group : 'day';

    final rangeQuery = {
      'from': resolvedFrom,
      'to': resolvedTo,
      'group': resolvedGroup,
    };

    final results = await Future.wait([
      _dio.get<dynamic>(
        '/api/users',
        queryParameters: const {'page': 1, 'limit': 1},
      ),
      _dio.get<dynamic>(
        '/api/admin/listings/pending',
        queryParameters: const {'page': 1, 'limit': 1},
      ),
      _dio.get<dynamic>(
        '/api/admin/reports/revenue',
        queryParameters: rangeQuery,
      ),
      _dio.get<dynamic>(
        '/api/admin/reports/bookings',
        queryParameters: rangeQuery,
      ),
      _dio.get<dynamic>(
        '/api/admin/reports/listings',
        queryParameters: rangeQuery,
      ),
      _dio.get<dynamic>(
        '/api/admin/reports/hosts',
        queryParameters: rangeQuery,
      ),
    ]);

    final usersCount = _extractTotal(results[0].data);
    final pendingListingsCount = _extractTotal(results[1].data);
    final revenueMap = _unwrapMap(results[2].data);
    final bookingsMap = _unwrapMap(results[3].data);
    final listingsMap = _unwrapMap(results[4].data);
    final hostsMap = _unwrapMap(results[5].data);

    final revTotals = revenueMap['totals'] is Map
        ? Map<String, dynamic>.from(revenueMap['totals'] as Map)
        : revenueMap;
    final bookTotals = bookingsMap['totals'] is Map
        ? Map<String, dynamic>.from(bookingsMap['totals'] as Map)
        : bookingsMap;
    final listTotals = listingsMap['totals'] is Map
        ? Map<String, dynamic>.from(listingsMap['totals'] as Map)
        : listingsMap;
    final hostTotals = hostsMap['totals'] is Map
        ? Map<String, dynamic>.from(hostsMap['totals'] as Map)
        : hostsMap;

    final hostsCount = int.tryParse(
          '${hostTotals['totalHosts'] ?? hostTotals['hostsCreated'] ?? hostTotals['activeHosts'] ?? hostTotals['approvedHosts'] ?? hostTotals['verifiedHosts'] ?? 0}',
        ) ??
        0;
    final activeHostsCount = int.tryParse(
          '${hostTotals['activeHosts'] ?? hostTotals['approvedHosts'] ?? hostTotals['totalHosts'] ?? hostsCount}',
        ) ??
        0;
    final verifiedHostsCount = int.tryParse(
          '${hostTotals['verifiedHosts'] ?? hostTotals['approvedHosts'] ?? 0}',
        ) ??
        0;

    final rawSeries = revenueMap['series'];
    final revenueSeries = rawSeries is List
        ? rawSeries
            .whereType<Map<dynamic, dynamic>>()
            .map(
              (e) => AdminRevenuePoint.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList()
        : const <AdminRevenuePoint>[];

    return AdminOverviewStats(
      users: usersCount,
      pendingListings: pendingListingsCount,
      grossRevenue: double.tryParse('${revTotals['grossRevenue'] ?? 0}') ?? 0,
      platformRevenue:
          double.tryParse('${revTotals['platformRevenue'] ?? 0}') ?? 0,
      hostRevenue: double.tryParse('${revTotals['hostRevenue'] ?? 0}') ?? 0,
      bookings: int.tryParse('${bookTotals['totalBookings'] ?? 0}') ?? 0,
      pendingBookings:
          int.tryParse('${bookTotals['pendingBookings'] ?? 0}') ?? 0,
      paidBookings: int.tryParse('${bookTotals['paidBookings'] ?? 0}') ?? 0,
      completedBookings:
          int.tryParse('${bookTotals['completedBookings'] ?? 0}') ?? 0,
      cancelledBookings:
          int.tryParse('${bookTotals['cancelledBookings'] ?? 0}') ?? 0,
      hosts: hostsCount,
      activeHosts: activeHostsCount,
      verifiedHosts: verifiedHostsCount,
      activeListings: int.tryParse('${listTotals['activeListings'] ?? 0}') ?? 0,
      listingsCreated:
          int.tryParse('${listTotals['listingsCreated'] ?? 0}') ?? 0,
      inactiveListings:
          int.tryParse('${listTotals['inactiveListings'] ?? 0}') ?? 0,
      revenueSeries: revenueSeries,
      from: resolvedFrom,
      to: resolvedTo,
      group: resolvedGroup,
    );
  }

  // ── Users & Roles ──
  Future<AdminPaginatedResult<Map<String, dynamic>>> getAdminUsersPaginated({
    int page = 1,
    int limit = maxUsersPageLimit,
    String? search,
    String? role,
    String? status,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit.clamp(1, maxUsersPageLimit);
    final res = await _dio.get<dynamic>(
      '/api/users',
      queryParameters: {
        'page': safePage,
        'limit': safeLimit,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (role != null && role != 'all' && role.trim().isNotEmpty)
          'role': role.trim(),
        if (status != null && status != 'all' && status.trim().isNotEmpty)
          'status': status.trim(),
      },
    );
    return _extractPaginated(
      res.data,
      fallbackPage: safePage,
      fallbackLimit: safeLimit,
    );
  }

  Future<List<Map<String, dynamic>>> getAdminUsers({
    int page = 1,
    int limit = maxUsersPageLimit,
    String? search,
    String? role,
    String? status,
  }) async {
    final paginated = await getAdminUsersPaginated(
      page: page,
      limit: limit,
      search: search,
      role: role,
      status: status,
    );
    return paginated.items;
  }

  Future<Map<String, dynamic>> updateAdminUserStatus(
    String userId,
    String status,
  ) async {
    final normalizedStatus =
        status.trim().toLowerCase() == 'blocked' ? 'suspended' : status.trim();
    final res = await _dio.patch<dynamic>(
      '/api/users/$userId/status',
      data: {'status': normalizedStatus},
    );
    return _unwrapMap(res.data);
  }

  Future<Map<String, dynamic>> updateAdminUser(
    String userId,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.patch<dynamic>(
      '/api/users/$userId',
      data: payload,
    );
    return _unwrapMap(res.data);
  }

  // ── Listing Moderation & AI Image Vision ──
  Future<AdminPaginatedResult<Map<String, dynamic>>>
      getPendingListingsPaginated({
    int page = 1,
    int limit = maxListingsPageLimit,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit.clamp(1, maxListingsPageLimit);
    final res = await _dio.get<dynamic>(
      '/api/admin/listings/pending',
      queryParameters: {
        'page': safePage,
        'limit': safeLimit,
      },
    );
    return _extractPaginated(
      res.data,
      fallbackPage: safePage,
      fallbackLimit: safeLimit,
    );
  }

  Future<List<Map<String, dynamic>>> getPendingListings({
    int page = 1,
    int limit = maxListingsPageLimit,
  }) async {
    final paginated = await getPendingListingsPaginated(
      page: page,
      limit: limit,
    );
    return paginated.items;
  }

  Future<Map<String, dynamic>> getAdminListingDetail(String listingId) async {
    final res = await _dio.get<dynamic>('/api/admin/listings/$listingId');
    return _unwrapMap(res.data);
  }

  Future<void> approveListing(String listingId) async {
    await _dio.patch<dynamic>('/api/admin/listings/$listingId/approve');
  }

  Future<void> rejectListing(String listingId, String reason) async {
    await _dio.patch<dynamic>(
      '/api/admin/listings/$listingId/reject',
      data: {'reason': reason.trim()},
    );
  }

  Future<Map<String, dynamic>> reanalyzeListingImage(String imageId) async {
    final res =
        await _dio.post<dynamic>('/api/admin/images/$imageId/reanalyze');
    return _unwrapMap(res.data);
  }

  Future<Map<String, dynamic>> analyzeAllListingImages(
    String listingId, {
    bool force = true,
  }) async {
    final res = await _dio.post<dynamic>(
      '/api/ai/listings/$listingId/analyze-images',
      queryParameters: {'force': force},
    );
    return _unwrapMap(res.data);
  }

  // ── Host Applications ──
  Future<AdminPaginatedResult<Map<String, dynamic>>>
      getAdminHostApplicationsPaginated({
    String status = 'pending',
    int page = 1,
    int limit = 50,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit.clamp(1, 100);
    final res = await _dio.get<dynamic>(
      '/api/admin/host-applications',
      queryParameters: {
        'page': safePage,
        'limit': safeLimit,
        if (status != 'all') 'status': status,
      },
    );
    return _extractPaginated(
      res.data,
      fallbackPage: safePage,
      fallbackLimit: safeLimit,
    );
  }

  Future<List<Map<String, dynamic>>> getAdminHostApplications({
    String status = 'pending',
    int page = 1,
    int limit = 50,
  }) async {
    final paginated = await getAdminHostApplicationsPaginated(
      status: status,
      page: page,
      limit: limit,
    );
    return paginated.items;
  }

  Future<Map<String, dynamic>> getAdminHostApplicationDetail(
    String applicationId,
  ) async {
    final res = await _dio.get<dynamic>(
      '/api/admin/host-applications/$applicationId',
    );
    return _unwrapMap(res.data);
  }

  Future<void> approveHostApplication(String applicationId) async {
    await _dio.patch<dynamic>(
      '/api/admin/host-applications/$applicationId/approve',
    );
  }

  Future<void> rejectHostApplication(
    String applicationId,
    String reason,
  ) async {
    await _dio.patch<dynamic>(
      '/api/admin/host-applications/$applicationId/reject',
      data: {'reason': reason.trim()},
    );
  }

  // ── Verifications & Payouts ──
  Future<AdminPaginatedResult<Map<String, dynamic>>>
      getAdminVerificationsPaginated({
    String status = 'all',
    String verificationType = 'all',
    int page = 1,
    int limit = 50,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final safeLimit = limit.clamp(1, 100);
    final res = await _dio.get<dynamic>(
      '/api/admin/verifications',
      queryParameters: {
        'page': safePage,
        'limit': safeLimit,
        if (status != 'all') 'status': status,
        if (verificationType != 'all') 'verificationType': verificationType,
      },
    );
    return _extractPaginated(
      res.data,
      fallbackPage: safePage,
      fallbackLimit: safeLimit,
    );
  }

  Future<List<Map<String, dynamic>>> getAdminVerifications({
    String status = 'all',
    String verificationType = 'all',
    int page = 1,
    int limit = 50,
  }) async {
    final paginated = await getAdminVerificationsPaginated(
      status: status,
      verificationType: verificationType,
      page: page,
      limit: limit,
    );
    return paginated.items;
  }

  Future<void> approveHostVerification(
    String verificationId, {
    String? notes,
  }) async {
    await _dio.patch<dynamic>(
      '/api/admin/verifications/$verificationId/approve',
      data: {if (notes != null) 'notes': notes},
    );
  }

  Future<void> rejectHostVerification(
    String verificationId,
    String reason,
  ) async {
    await _dio.patch<dynamic>(
      '/api/admin/verifications/$verificationId/reject',
      data: {'reason': reason.trim()},
    );
  }
}
