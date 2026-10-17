import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../errors/app_failure.dart';
import '../logging/app_logger.dart';
import '../security/secure_storage_service.dart';
import 'dio_adapter.dart';

class PaginationMeta {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const PaginationMeta({
    this.page = 1,
    this.limit = 20,
    this.total = 0,
    this.totalPages = 1,
  });

  int get totalItems => total;
  bool get hasPrev => page > 1;
  bool get hasNext => page < totalPages;

  factory PaginationMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PaginationMeta();
    final page = (json['page'] as num?)?.toInt() ?? 1;
    final limit = (json['limit'] as num?)?.toInt() ?? 20;
    final total = ((json['total'] ?? json['totalItems']) as num?)?.toInt() ?? 0;
    final totalPages = (json['totalPages'] as num?)?.toInt() ??
        (limit > 0 ? ((total + limit - 1) ~/ limit).clamp(1, 999999) : 1);
    return PaginationMeta(
      page: page,
      limit: limit,
      total: total,
      totalPages: totalPages,
    );
  }
}

class PaginatedResult<T> {
  final List<T> items;
  final PaginationMeta pagination;

  const PaginatedResult({
    required this.items,
    this.pagination = const PaginationMeta(),
  });
}

typedef SessionRefreshedCallback = void Function(
  String accessToken,
  Map<String, dynamic>? userJson,
);

class DioClient {
  final Dio _dio;
  final SecureStorageService? _secureStorage;
  void Function()? onSessionExpired;
  SessionRefreshedCallback? onSessionRefreshed;
  final Set<void Function()> _sessionExpiredListeners = <void Function()>{};
  final Set<SessionRefreshedCallback> _sessionRefreshedListeners =
      <SessionRefreshedCallback>{};

  Completer<String?>? _refreshCompleter;
  CancelToken? _refreshCancelToken;
  final Set<CancelToken> _activeSessionCancelTokens = <CancelToken>{};
  int _sessionEpoch = 0;

  DioClient({
    Dio? dio,
    HttpClientAdapter? httpClientAdapter,
    SecureStorageService? secureStorage,
    this.onSessionExpired,
    this.onSessionRefreshed,
  })  : _secureStorage = secureStorage,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: AppConstants.connectTimeout,
                receiveTimeout: AppConstants.receiveTimeout,
                sendTimeout: AppConstants.sendTimeout,
                headers: const {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ) {
    if (httpClientAdapter != null) {
      _dio.httpClientAdapter = httpClientAdapter;
    } else if (dio == null) {
      configurePlatformDio(_dio);
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _handleRequest,
        onResponse: _handleResponse,
        onError: _handleDioError,
      ),
    );
  }

  Dio get dio => _dio;

  void addSessionExpiredListener(void Function() listener) {
    _sessionExpiredListeners.add(listener);
  }

  void removeSessionExpiredListener(void Function() listener) {
    _sessionExpiredListeners.remove(listener);
  }

  void addSessionRefreshedListener(SessionRefreshedCallback listener) {
    _sessionRefreshedListeners.add(listener);
  }

  void removeSessionRefreshedListener(SessionRefreshedCallback listener) {
    _sessionRefreshedListeners.remove(listener);
  }

  void _notifySessionExpired() {
    onSessionExpired?.call();
    for (final listener
        in List<void Function()>.from(_sessionExpiredListeners)) {
      try {
        listener();
      } catch (_) {}
    }
  }

  void _notifySessionRefreshed(
    String accessToken,
    Map<String, dynamic>? userJson,
  ) {
    onSessionRefreshed?.call(accessToken, userJson);
    for (final listener
        in List<SessionRefreshedCallback>.from(_sessionRefreshedListeners)) {
      try {
        listener(accessToken, userJson);
      } catch (_) {}
    }
  }

  /// Creates and tracks a session-scoped [CancelToken] that is automatically
  /// cancelled if the user logs out or the session expires.
  CancelToken createSessionCancelToken() {
    final token = CancelToken();
    _activeSessionCancelTokens.add(token);
    token.whenCancel.whenComplete(() {
      _activeSessionCancelTokens.remove(token);
    });
    return token;
  }

  /// Executes or joins the single-flight refresh token request.
  Future<String?> refreshAccessToken() async {
    try {
      return await _refreshAccessTokenOnce();
    } catch (_) {
      return null;
    }
  }

  /// Aborts all in-flight refresh and authenticated session requests upon logout.
  Future<void> abortSession({
    String reason = 'Session terminated by logout',
    bool clearStorage = false,
  }) async {
    _sessionEpoch++;
    if (_refreshCancelToken != null && !_refreshCancelToken!.isCancelled) {
      _refreshCancelToken!.cancel(reason);
    }
    _refreshCancelToken = null;

    final pendingCompleter = _refreshCompleter;
    _refreshCompleter = null;
    if (pendingCompleter != null && !pendingCompleter.isCompleted) {
      pendingCompleter.completeError(
        const AuthFailure('Phiên đăng nhập đã kết thúc.', 'SESSION_ABORTED'),
      );
    }

    final activeTokens = List<CancelToken>.from(_activeSessionCancelTokens);
    _activeSessionCancelTokens.clear();
    for (final token in activeTokens) {
      if (!token.isCancelled) {
        token.cancel(reason);
      }
    }

    if (clearStorage && _secureStorage != null) {
      await _secureStorage.clearAuthSession();
    }
  }

  static bool _isAuthPathWithoutAutoRefresh(String path) {
    final normalized = path.toLowerCase();
    return normalized.contains('/api/auth/refresh') ||
        normalized.contains('/api/auth/login') ||
        normalized.contains('/api/auth/register') ||
        normalized.contains('/api/auth/google') ||
        normalized.contains('/api/auth/logout') ||
        normalized.contains('/api/auth/forgot-password') ||
        normalized.contains('/api/auth/reset-password') ||
        normalized.contains('/api/auth/send-otp') ||
        normalized.contains('/api/auth/verify-email') ||
        normalized.contains('/api/auth/verify-phone');
  }

  static bool _isAuthCookieTargetPath(String path) {
    final normalized = path.toLowerCase();
    return normalized.contains('/api/auth/refresh') ||
        normalized.contains('/api/auth/logout') ||
        normalized.startsWith('/api/auth');
  }

  Future<void> _handleRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers.putIfAbsent('Accept', () => 'application/json');
    if (options.data != null && options.data is! FormData) {
      options.headers.putIfAbsent('Content-Type', () => 'application/json');
    }

    // On Flutter Web, instruct browser XHR/fetch to include HttpOnly cookies.
    if (kIsWeb) {
      options.extra.putIfAbsent('withCredentials', () => true);
    }

    // Track session cancel token if caller did not provide one on authenticated routes.
    if (options.cancelToken == null &&
        !options.path.toLowerCase().contains('/api/auth/logout') &&
        options.extra['skipSessionCancel'] != true) {
      final sessionToken = createSessionCancelToken();
      options.cancelToken = sessionToken;
    }

    final skipAuthToken = options.extra['skipAuthToken'] == true;
    if (_secureStorage != null && !skipAuthToken) {
      try {
        final token = await _secureStorage.getAuthToken();
        if (token != null &&
            token.isNotEmpty &&
            !options.headers.containsKey('Authorization')) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      } catch (_) {
        // Ignore storage read errors in request interceptor
      }
    }

    // On native platforms (!kIsWeb), attach stored refreshToken cookie to /api/auth/* requests.
    if (!kIsWeb &&
        _secureStorage != null &&
        _isAuthCookieTargetPath(options.path)) {
      try {
        final refreshCookie = await _secureStorage.getRefreshCookie();
        final refreshBodyToken = await _secureStorage.getRefreshToken();
        final effectiveCookieValue =
            (refreshCookie != null && refreshCookie.isNotEmpty)
                ? refreshCookie
                : refreshBodyToken;

        if (effectiveCookieValue != null && effectiveCookieValue.isNotEmpty) {
          final existingCookie = options.headers['Cookie']?.toString() ??
              options.headers['cookie']?.toString() ??
              '';
          if (!existingCookie.contains('refreshToken=')) {
            options.headers['Cookie'] = existingCookie.isEmpty
                ? 'refreshToken=$effectiveCookieValue'
                : '$existingCookie; refreshToken=$effectiveCookieValue';
          }
        }

        // Only send refreshToken in body when explicitly stored via a valid body flow
        // AND backend environment supports it (development).
        if (AppConfig.isDevelopment &&
            refreshBodyToken != null &&
            refreshBodyToken.isNotEmpty &&
            (options.path.toLowerCase().contains('/api/auth/refresh') ||
                options.path.toLowerCase().contains('/api/auth/logout'))) {
          if (options.data == null) {
            options.data = <String, dynamic>{'refreshToken': refreshBodyToken};
          } else if (options.data is Map<String, dynamic>) {
            final mapData = Map<String, dynamic>.from(
              options.data as Map<String, dynamic>,
            );
            mapData.putIfAbsent('refreshToken', () => refreshBodyToken);
            options.data = mapData;
          }
        }
      } catch (_) {
        // Ignore cookie storage read errors
      }
    }

    AppLogger.d('HTTP Request: ${options.method} ${options.uri.path}');
    return handler.next(options);
  }

  Future<void> _handleResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final untrackToken = response.requestOptions.cancelToken;
    if (untrackToken != null) {
      _activeSessionCancelTokens.remove(untrackToken);
    }

    if (_secureStorage != null) {
      try {
        final setCookieHeaders =
            response.headers['set-cookie'] ?? response.headers['Set-Cookie'];
        if (setCookieHeaders != null && setCookieHeaders.isNotEmpty) {
          await _secureStorage.syncRefreshCookieFromHeaders(setCookieHeaders);
        }

        // If an auth endpoint explicitly returned a refreshToken in its response body, persist it securely.
        if (_isAuthCookieTargetPath(response.requestOptions.path) &&
            response.data is Map<String, dynamic>) {
          final body = response.data as Map<String, dynamic>;
          final data = (body['data'] is Map<String, dynamic>)
              ? body['data'] as Map<String, dynamic>
              : body;
          final bodyRefreshToken = data['refreshToken']?.toString().trim();
          if (bodyRefreshToken != null && bodyRefreshToken.isNotEmpty) {
            await _secureStorage.saveRefreshToken(bodyRefreshToken);
          }
        }
      } catch (_) {
        // Ignore storage write errors in response interceptor
      }
    }

    AppLogger.d(
      'HTTP Response [${response.statusCode}]: ${response.requestOptions.uri.path}',
    );
    return handler.next(response);
  }

  Future<void> _handleDioError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final untrackToken = error.requestOptions.cancelToken;
    if (untrackToken != null) {
      _activeSessionCancelTokens.remove(untrackToken);
    }

    final statusCode = error.response?.statusCode;
    final reqOptions = error.requestOptions;
    final skipRefresh = reqOptions.extra['skipAuthRefresh'] == true;
    final alreadyRetried = reqOptions.extra['retried'] == true;
    final isNonRefreshableAuth = _isAuthPathWithoutAutoRefresh(reqOptions.path);

    if (statusCode == 401 &&
        !skipRefresh &&
        !alreadyRetried &&
        !isNonRefreshableAuth &&
        (_secureStorage != null || kIsWeb)) {
      final epochBeforeRefresh = _sessionEpoch;
      String? newToken;
      try {
        newToken = await _refreshAccessTokenOnce();
      } catch (_) {
        // Refresh failed; _refreshAccessTokenOnce already cleared session and notified once.
        AppLogger.w(
          'HTTP Error [$statusCode]: ${error.requestOptions.uri.path}',
        );
        return handler.next(error);
      }

      if (newToken != null &&
          newToken.isNotEmpty &&
          _sessionEpoch == epochBeforeRefresh) {
        final retryExtra = Map<String, dynamic>.from(reqOptions.extra)
          ..['retried'] = true;
        final retryHeaders = Map<String, dynamic>.from(reqOptions.headers)
          ..['Authorization'] = 'Bearer $newToken';

        final retryOptions = reqOptions.copyWith(
          extra: retryExtra,
          headers: retryHeaders,
          cancelToken: createSessionCancelToken(),
        );

        try {
          final retryResponse = await _dio.fetch<dynamic>(retryOptions);
          return handler.resolve(retryResponse);
        } on DioException catch (retryError) {
          return handler.next(retryError);
        } catch (unexpectedError) {
          return handler.next(
            DioException(
              requestOptions: retryOptions,
              error: unexpectedError,
            ),
          );
        }
      }
    }

    AppLogger.w(
      'HTTP Error [$statusCode]: ${error.requestOptions.uri.path}',
    );
    return handler.next(error);
  }

  /// Single-flight refresh token lock matching `refreshAccessTokenOnce` in `apiClient.ts`.
  /// Ensures concurrent 401 responses share a single `POST /api/auth/refresh` call.
  Future<String?> _refreshAccessTokenOnce() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<String?>();
    // Prevent unhandled async error when no secondary caller is awaiting completer.future yet.
    completer.future.ignore();
    _refreshCompleter = completer;

    final epochAtStart = _sessionEpoch;
    final refreshCancelToken = CancelToken();
    _refreshCancelToken = refreshCancelToken;

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: <String, dynamic>{},
        cancelToken: refreshCancelToken,
        options: Options(
          extra: const {
            'skipAuthRefresh': true,
            'skipAuthToken': true,
            'skipSessionCancel': true,
          },
        ),
      );

      if (_sessionEpoch != epochAtStart) {
        throw const AuthFailure(
          'Phiên đăng nhập đã kết thúc.',
          'SESSION_ABORTED',
        );
      }

      final unwrapped = unwrapEnvelope(response.data);
      final data = unwrapped is Map<String, dynamic>
          ? unwrapped
          : (response.data?['data'] as Map<String, dynamic>?) ?? response.data;
      final newToken =
          (data?['accessToken'] ?? data?['token'])?.toString().trim() ?? '';

      if (newToken.isEmpty) {
        throw const AuthFailure(
          'Phiên đăng nhập đã hết hạn.',
          'SESSION_EXPIRED',
        );
      }

      await _secureStorage?.saveAuthToken(newToken);
      final userJson = data?['user'] is Map<String, dynamic>
          ? data!['user'] as Map<String, dynamic>
          : null;
      _notifySessionRefreshed(newToken, userJson);

      if (!completer.isCompleted) {
        completer.complete(newToken);
      }
      return newToken;
    } catch (e) {
      final wasAbortedByLogout = _sessionEpoch != epochAtStart ||
          (e is DioException && e.type == DioExceptionType.cancel);

      if (!wasAbortedByLogout) {
        await _secureStorage?.clearAuthSession();
        _notifySessionExpired();
      }

      if (!completer.isCompleted) {
        completer.completeError(e);
      }
      rethrow;
    } finally {
      if (identical(_refreshCompleter, completer)) {
        _refreshCompleter = null;
      }
      if (identical(_refreshCancelToken, refreshCancelToken)) {
        _refreshCancelToken = null;
      }
    }
  }

  /// Unwraps `{ success, message, data, code, details, errors }` envelope.
  static dynamic unwrapEnvelope(dynamic responseBody) {
    if (responseBody is Map<String, dynamic>) {
      if (responseBody['success'] == false) {
        final msg = responseBody['message']?.toString() ??
            'Không thể thực hiện yêu cầu.';
        final code = responseBody['code']?.toString() ?? 'API_ERROR';
        final details = responseBody['details'] ?? responseBody['errors'];
        final fieldErrors = _parseFieldErrors(details, responseBody['errors']);
        throw ValidationFailure(
          msg,
          code: code,
          details: details,
          fieldErrors: fieldErrors,
        );
      }
      if (responseBody.containsKey('data')) {
        return responseBody['data'];
      }
    }
    return responseBody;
  }

  static PaginatedResult<T> parsePaginated<T>(
    dynamic responseBody,
    T Function(Map<String, dynamic>) mapper,
  ) {
    final data = unwrapEnvelope(responseBody);
    List<dynamic> rawItems = const [];
    Map<String, dynamic>? rawPagination;

    if (data is Map<String, dynamic>) {
      if (data['items'] is List) {
        rawItems = data['items'] as List<dynamic>;
      } else if (data['listings'] is List) {
        rawItems = data['listings'] as List<dynamic>;
      } else if (data['bookings'] is List) {
        rawItems = data['bookings'] as List<dynamic>;
      } else if (data['users'] is List) {
        rawItems = data['users'] as List<dynamic>;
      } else if (data['applications'] is List) {
        rawItems = data['applications'] as List<dynamic>;
      }
      if (data['pagination'] is Map<String, dynamic>) {
        rawPagination = data['pagination'] as Map<String, dynamic>;
      }
    } else if (data is List) {
      rawItems = data;
    }

    if (rawPagination == null &&
        responseBody is Map<String, dynamic> &&
        responseBody['meta'] is Map<String, dynamic>) {
      rawPagination = responseBody['meta'] as Map<String, dynamic>;
    }

    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(mapper)
        .toList(growable: false);

    return PaginatedResult<T>(
      items: items,
      pagination: PaginationMeta.fromJson(rawPagination),
    );
  }

  static List<ApiFieldError> _parseFieldErrors(
    dynamic details,
    dynamic legacyErrors,
  ) {
    final source = details is List
        ? details
        : (legacyErrors is List ? legacyErrors : const <dynamic>[]);
    final result = <ApiFieldError>[];
    for (final item in source) {
      if (item is Map<String, dynamic>) {
        result.add(ApiFieldError.fromJson(item));
      }
    }
    return result;
  }

  /// Translates DioException into clean typed AppFailure without converting HTTP errors to success.
  static AppFailure handleError(dynamic error) {
    if (error is AppFailure) {
      return error;
    }
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return const NetworkFailure();
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final rawData = error.response?.data;
          final mapData =
              rawData is Map<String, dynamic> ? rawData : <String, dynamic>{};
          final code = mapData['code']?.toString() ?? 'HTTP_$statusCode';
          final details = mapData['details'] ?? mapData['errors'];
          final fieldErrors = _parseFieldErrors(details, mapData['errors']);
          final serverMessage = mapData['message']?.toString();

          if (statusCode == 401 || statusCode == 403) {
            return AuthFailure(
              serverMessage ??
                  (statusCode == 403
                      ? 'Bạn không có quyền truy cập chức năng này.'
                      : 'Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại.'),
              code,
              statusCode ?? 401,
            );
          } else if (statusCode == 404) {
            return NotFoundFailure(
              serverMessage ?? 'Không tìm thấy dữ liệu yêu cầu.',
            );
          } else if (statusCode == 409) {
            return ConflictFailure(
              serverMessage ?? 'Dữ liệu xung đột hoặc đã được xử lý.',
              code: code,
              details: details,
              fieldErrors: fieldErrors,
            );
          } else if (statusCode == 400 ||
              statusCode == 410 ||
              statusCode == 422 ||
              statusCode == 423) {
            final firstFieldError =
                fieldErrors.isNotEmpty ? fieldErrors.first.msg : null;
            return ValidationFailure(
              firstFieldError ??
                  serverMessage ??
                  'Thông tin gửi lên không hợp lệ.',
              statusCode: statusCode,
              code: code,
              details: details,
              fieldErrors: fieldErrors,
            );
          } else if (statusCode == 429) {
            return RateLimitFailure(
              serverMessage ??
                  'Bạn đã thao tác quá nhanh. Vui lòng thử lại sau ít phút.',
            );
          }

          return ServerFailure(
            serverMessage ?? 'Lỗi máy chủ ($statusCode). Vui lòng thử lại sau.',
            statusCode: statusCode,
            code: code,
            details: details,
            fieldErrors: fieldErrors,
          );
        case DioExceptionType.cancel:
          return const ValidationFailure('Yêu cầu đã bị hủy.');
        default:
          return NetworkFailure(
            error.message ??
                'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng.',
          );
      }
    }
    return UnknownFailure(error.toString());
  }
}
