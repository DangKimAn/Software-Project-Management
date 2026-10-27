import 'dart:async';
import 'dart:convert';
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

  static int? _parsePositiveOrZeroInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed) ?? double.tryParse(trimmed)?.toInt();
    }
    return null;
  }

  factory PaginationMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const PaginationMeta();
    final rawPage = _parsePositiveOrZeroInt(
      json['page'] ?? json['currentPage'],
    );
    final rawLimit = _parsePositiveOrZeroInt(
      json['limit'] ?? json['pageSize'] ?? json['perPage'],
    );
    final rawTotal = _parsePositiveOrZeroInt(
      json['total'] ?? json['totalItems'] ?? json['count'],
    );
    final rawTotalPages = _parsePositiveOrZeroInt(
      json['totalPages'] ?? json['pages'],
    );

    final page = (rawPage != null && rawPage > 0) ? rawPage : 1;
    final limit = (rawLimit != null && rawLimit > 0) ? rawLimit : 20;
    final total = (rawTotal != null && rawTotal >= 0) ? rawTotal : 0;
    final computedTotalPages =
        limit > 0 ? ((total + limit - 1) ~/ limit).clamp(1, 999999) : 1;
    final totalPages = (rawTotalPages != null && rawTotalPages > 0)
        ? rawTotalPages
        : computedTotalPages;

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
  final int maxGetRetries;
  final Duration retryBaseDelay;
  final Duration maxRetryDelay;
  final bool retryGetOnTimeout;

  void Function()? onSessionExpired;
  SessionRefreshedCallback? onSessionRefreshed;
  final Set<void Function()> _sessionExpiredListeners = <void Function()>{};
  final Set<SessionRefreshedCallback> _sessionRefreshedListeners =
      <SessionRefreshedCallback>{};

  Completer<String?>? _refreshCompleter;
  CancelToken? _refreshCancelToken;
  final Set<CancelToken> _activeSessionCancelTokens = <CancelToken>{};
  final Map<String, CancelToken> _keyedCancelTokens = <String, CancelToken>{};
  int _sessionEpoch = 0;

  DioClient({
    Dio? dio,
    HttpClientAdapter? httpClientAdapter,
    SecureStorageService? secureStorage,
    this.onSessionExpired,
    this.onSessionRefreshed,
    this.maxGetRetries = 2,
    this.retryBaseDelay = const Duration(milliseconds: 100),
    this.maxRetryDelay = const Duration(seconds: 2),
    this.retryGetOnTimeout = false,
  })  : _secureStorage = secureStorage,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: normalizeBaseUrl(AppConfig.apiBaseUrl),
                connectTimeout: AppConstants.connectTimeout,
                receiveTimeout: AppConstants.receiveTimeout,
                sendTimeout: AppConstants.sendTimeout,
                headers: const {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ) {
    if (_dio.options.baseUrl.isNotEmpty) {
      _dio.options.baseUrl = normalizeBaseUrl(_dio.options.baseUrl);
    }

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

  int get sessionEpoch => _sessionEpoch;

  /// Normalizes a base URL so that trailing slashes and redundant `/api`
  /// suffixes are stripped, ensuring `/api` is joined exactly once.
  static String normalizeBaseUrl(String rawBaseUrl) {
    return AppConfig.normalizeApiBaseUrl(rawBaseUrl);
  }

  /// Normalizes an API request path so that `/api` is present exactly once
  /// (unless the path is an absolute URL or the root `/health` probe).
  static String normalizeApiPath(String rawPath, {String? baseUrl}) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) {
      return '/api';
    }

    // Full URL passed directly to Dio
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final parsed = Uri.tryParse(trimmed);
      if (parsed == null) return trimmed;
      final collapsedPath = parsed.path.replaceAll(
        RegExp(r'^/api(?:/api)+(?=/|$)', caseSensitive: false),
        '/api',
      );
      return parsed.replace(path: collapsedPath).toString();
    }

    var path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    path = path.replaceAll(RegExp(r'/+'), '/');

    // Collapse duplicate `/api/api/...` prefixes
    while (RegExp(r'^/api/api(?=/|$)', caseSensitive: false).hasMatch(path)) {
      path = path.replaceFirst(RegExp(r'^/api', caseSensitive: false), '');
    }

    // Preserve root health check endpoint (`/health`)
    final lowerPath = path.toLowerCase();
    if (lowerPath == '/health' || lowerPath.startsWith('/health?')) {
      return path;
    }

    // Ensure path starts with `/api`
    if (lowerPath != '/api' &&
        !lowerPath.startsWith('/api/') &&
        !lowerPath.startsWith('/api?')) {
      path = '/api$path';
    }

    // If caller explicitly passed a non-normalized baseUrl that still ends with `/api`,
    // strip the leading `/api` from path so `baseUrl + path` still has `/api` once.
    if (baseUrl != null && baseUrl.trim().isNotEmpty) {
      final trimmedBase =
          baseUrl.trim().replaceAll(RegExp(r'/+$'), '').toLowerCase();
      if (trimmedBase.endsWith('/api') &&
          path.toLowerCase().startsWith('/api')) {
        final stripped = path.substring(4);
        return stripped.isEmpty ? '/' : stripped;
      }
    }

    return path;
  }

  /// Builds the normalized full URI for an endpoint, guaranteeing `/api` is joined once.
  static Uri buildEndpointUri(String baseUrl, String path) {
    final cleanBase = normalizeBaseUrl(baseUrl);
    final cleanPath = normalizeApiPath(path);
    return Uri.parse('$cleanBase$cleanPath');
  }

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

  /// Creates a keyed [CancelToken] that automatically cancels any previous
  /// in-flight request sharing the same [requestKey] (e.g. search/filter queries).
  CancelToken createKeyedCancelToken(
    String requestKey, {
    String reason = 'Superseded by newer request',
  }) {
    final normalizedKey = requestKey.trim();
    if (normalizedKey.isEmpty) {
      return createSessionCancelToken();
    }
    final previous = _keyedCancelTokens.remove(normalizedKey);
    if (previous != null && !previous.isCancelled) {
      previous.cancel(reason);
    }
    final token = createSessionCancelToken();
    _keyedCancelTokens[normalizedKey] = token;
    token.whenCancel.whenComplete(() {
      if (identical(_keyedCancelTokens[normalizedKey], token)) {
        _keyedCancelTokens.remove(normalizedKey);
      }
    });
    return token;
  }

  /// Cancels an in-flight request tracked by [requestKey], if any.
  void cancelPendingRequest(
    String requestKey, [
    String reason = 'Request cancelled',
  ]) {
    final normalizedKey = requestKey.trim();
    if (normalizedKey.isEmpty) return;
    final token = _keyedCancelTokens.remove(normalizedKey);
    if (token != null && !token.isCancelled) {
      token.cancel(reason);
    }
  }

  void _untrackRequestTokens(RequestOptions options) {
    final token = options.cancelToken;
    if (token != null) {
      _activeSessionCancelTokens.remove(token);
    }
    final key = (options.extra['requestKey'] ?? options.extra['cancelKey'])
        ?.toString()
        .trim();
    if (key != null &&
        key.isNotEmpty &&
        identical(_keyedCancelTokens[key], token)) {
      _keyedCancelTokens.remove(key);
    }
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

    final keyedTokens = List<CancelToken>.from(_keyedCancelTokens.values);
    _keyedCancelTokens.clear();
    for (final token in keyedTokens) {
      if (!token.isCancelled) {
        token.cancel(reason);
      }
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

  static bool _isIdempotentReadMethod(String method) {
    final upper = method.toUpperCase();
    return upper == 'GET' || upper == 'HEAD' || upper == 'OPTIONS';
  }

  static bool _isMutationOrSensitiveEndpoint(RequestOptions options) {
    if (!_isIdempotentReadMethod(options.method)) {
      return true;
    }
    final path = options.path.toLowerCase();
    return path.contains('/api/payments') || path.contains('/api/bookings');
  }

  /// Determines whether an endpoint is a public read endpoint that must still
  /// work for anonymous users even if a stale token was cleared.
  static bool _isPublicEndpoint(RequestOptions options) {
    if (options.extra['requiresAuth'] == true) return false;
    if (options.extra['publicEndpoint'] == true) return true;

    final method = options.method.toUpperCase();
    final path = options.path.toLowerCase();

    if (method == 'POST' && path.startsWith('/api/search/semantic')) {
      return true;
    }

    if (!_isIdempotentReadMethod(method)) {
      return false;
    }

    if (path == '/health' || path.startsWith('/health?')) {
      return true;
    }

    if (path.startsWith('/api/listings') &&
        !path.startsWith('/api/listings/host') &&
        !path.startsWith('/api/listings/admin')) {
      return true;
    }

    if (path.startsWith('/api/blogs') && !path.startsWith('/api/blogs/admin')) {
      return true;
    }

    if (path.startsWith('/api/amenities') || path.startsWith('/api/banks')) {
      return true;
    }

    return false;
  }

  Future<bool> _canAttemptTokenRefresh() async {
    if (kIsWeb) return true;
    if (_secureStorage == null) return false;
    try {
      final refreshCookie = await _secureStorage.getRefreshCookie();
      if (refreshCookie != null && refreshCookie.trim().isNotEmpty) {
        return true;
      }
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken != null && refreshToken.trim().isNotEmpty) {
        return true;
      }
      final accessToken = await _secureStorage.getAuthToken();
      if (accessToken != null && accessToken.trim().isNotEmpty) {
        return true;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  Future<void> _handleRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.baseUrl.isNotEmpty) {
      options.baseUrl = normalizeBaseUrl(options.baseUrl);
    }
    options.path = normalizeApiPath(options.path);

    options.headers.putIfAbsent('Accept', () => 'application/json');
    if (options.data != null && options.data is! FormData) {
      options.headers.putIfAbsent('Content-Type', () => 'application/json');
    }

    // On Flutter Web, instruct browser XHR/fetch to include HttpOnly cookies.
    if (kIsWeb) {
      options.extra.putIfAbsent('withCredentials', () => true);
    }

    // Automatically cancel stale in-flight request if a requestKey / cancelKey is provided.
    final requestKey =
        (options.extra['requestKey'] ?? options.extra['cancelKey'])
            ?.toString()
            .trim();
    if (requestKey != null &&
        requestKey.isNotEmpty &&
        options.extra['retried'] != true &&
        (options.extra['retryCount'] as int? ?? 0) == 0) {
      options.cancelToken = createKeyedCancelToken(requestKey);
    } else if (options.cancelToken == null &&
        !options.path.toLowerCase().contains('/api/auth/logout') &&
        options.extra['skipSessionCancel'] != true) {
      // Track session cancel token if caller did not provide one on routes.
      final sessionToken = createSessionCancelToken();
      options.cancelToken = sessionToken;
    }

    final skipAuthToken = options.extra['skipAuthToken'] == true ||
        options.extra['publicEndpoint'] == true;
    if (_secureStorage != null && !skipAuthToken) {
      try {
        final token = await _secureStorage.getAuthToken();
        if (token != null &&
            token.trim().isNotEmpty &&
            !options.headers.containsKey('Authorization')) {
          options.headers['Authorization'] = 'Bearer ${token.trim()}';
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
    _untrackRequestTokens(response.requestOptions);

    if (_secureStorage != null) {
      try {
        final setCookieHeaders =
            response.headers['set-cookie'] ?? response.headers['Set-Cookie'];
        if (setCookieHeaders != null && setCookieHeaders.isNotEmpty) {
          await _secureStorage.syncRefreshCookieFromHeaders(setCookieHeaders);
        }

        // If an auth endpoint explicitly returned a refreshToken in its response body, persist it securely.
        if (_isAuthCookieTargetPath(response.requestOptions.path)) {
          final body = _coerceJsonMap(response.data);
          if (body != null) {
            final data = _coerceJsonMap(body['data']) ?? body;
            final bodyRefreshToken = data['refreshToken']?.toString().trim();
            if (bodyRefreshToken != null && bodyRefreshToken.isNotEmpty) {
              await _secureStorage.saveRefreshToken(bodyRefreshToken);
            }
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

  bool _shouldRetryIdempotentGet(DioException error) {
    final reqOptions = error.requestOptions;
    if (reqOptions.extra['disableRetry'] == true) return false;
    if (!_isIdempotentReadMethod(reqOptions.method)) return false;
    if (_isMutationOrSensitiveEndpoint(reqOptions)) return false;
    if (error.type == DioExceptionType.cancel) return false;
    if (reqOptions.cancelToken?.isCancelled == true) return false;

    final maxRetries =
        (reqOptions.extra['maxRetries'] as int?) ?? maxGetRetries;
    final retryCount = (reqOptions.extra['retryCount'] as int?) ?? 0;
    if (retryCount >= maxRetries) return false;

    final statusCode = error.response?.statusCode;
    if (statusCode == 429 ||
        statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504) {
      return true;
    }
    if (statusCode == 500 && reqOptions.extra['retryOn500'] == true) {
      return true;
    }

    final allowTimeoutRetry =
        reqOptions.extra['retryOnTimeout'] == true || retryGetOnTimeout;
    if (allowTimeoutRetry &&
        (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout)) {
      return true;
    }

    return false;
  }

  Duration _computeRetryDelay(DioException error, int retryAttempt) {
    final retryAfterSeconds = _extractRetryAfterSeconds(error.response);
    if (retryAfterSeconds != null && retryAfterSeconds > 0) {
      final headerDelay = Duration(seconds: retryAfterSeconds);
      return headerDelay > maxRetryDelay ? maxRetryDelay : headerDelay;
    }

    final multiplier = 1 << retryAttempt.clamp(0, 6);
    final rawDelay = Duration(
      milliseconds: retryBaseDelay.inMilliseconds * multiplier,
    );
    return rawDelay > maxRetryDelay ? maxRetryDelay : rawDelay;
  }

  Future<void> _handleDioError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    _untrackRequestTokens(error.requestOptions);

    final statusCode = error.response?.statusCode;
    final reqOptions = error.requestOptions;
    final skipRefresh = reqOptions.extra['skipAuthRefresh'] == true;
    final alreadyRetried = reqOptions.extra['retried'] == true;
    final isNonRefreshableAuth = _isAuthPathWithoutAutoRefresh(reqOptions.path);
    final hadAuthHeader = reqOptions.headers.containsKey('Authorization') ||
        reqOptions.headers.containsKey('authorization');

    if (statusCode == 401 &&
        !skipRefresh &&
        !alreadyRetried &&
        !isNonRefreshableAuth &&
        (_secureStorage != null || kIsWeb)) {
      final canRefresh = await _canAttemptTokenRefresh();
      if (canRefresh) {
        final epochBeforeRefresh = _sessionEpoch;
        String? newToken;
        try {
          newToken = await _refreshAccessTokenOnce();
        } catch (_) {
          // If this was a public read endpoint that failed only because an expired
          // Authorization header was attached, retry once anonymously after session clear.
          if (hadAuthHeader &&
              _isPublicEndpoint(reqOptions) &&
              reqOptions.extra['retriedAnonymous'] != true &&
              _sessionEpoch == epochBeforeRefresh) {
            final anonHeaders = Map<String, dynamic>.from(reqOptions.headers)
              ..remove('Authorization')
              ..remove('authorization');
            final anonExtra = Map<String, dynamic>.from(reqOptions.extra)
              ..['retried'] = true
              ..['retriedAnonymous'] = true
              ..['skipAuthToken'] = true
              ..['skipAuthRefresh'] = true;
            final anonOptions = reqOptions.copyWith(
              headers: anonHeaders,
              extra: anonExtra,
              cancelToken: createSessionCancelToken(),
            );
            try {
              final anonResponse = await _dio.fetch<dynamic>(anonOptions);
              return handler.resolve(anonResponse);
            } on DioException catch (anonError) {
              return handler.next(anonError);
            } catch (_) {}
          }

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
    }

    // Automatic exponential backoff retry for idempotent GET requests on 429 / transient 502-504.
    if (_shouldRetryIdempotentGet(error)) {
      final epochBeforeDelay = _sessionEpoch;
      final currentRetryCount = (reqOptions.extra['retryCount'] as int?) ?? 0;
      final delay = _computeRetryDelay(error, currentRetryCount);
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }

      if (_sessionEpoch == epochBeforeDelay &&
          reqOptions.cancelToken?.isCancelled != true) {
        final nextExtra = Map<String, dynamic>.from(reqOptions.extra)
          ..['retryCount'] = currentRetryCount + 1;
        final retryOptions = reqOptions.copyWith(
          extra: nextExtra,
          cancelToken: reqOptions.cancelToken ?? createSessionCancelToken(),
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
            'disableRetry': true,
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
      final data = _coerceJsonMap(unwrapped) ??
          _coerceJsonMap(response.data?['data']) ??
          _coerceJsonMap(response.data);
      final newToken =
          (data?['accessToken'] ?? data?['token'])?.toString().trim() ?? '';

      if (newToken.isEmpty) {
        throw const AuthFailure(
          'Phiên đăng nhập đã hết hạn.',
          'SESSION_EXPIRED',
        );
      }

      await _secureStorage?.saveAuthToken(newToken);
      final userJson = _coerceJsonMap(data?['user']);
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

  static Map<String, dynamic>? _coerceJsonMap(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map<String, dynamic>) return decoded;
          if (decoded is Map) {
            return decoded.map((key, value) => MapEntry(key.toString(), value));
          }
        } catch (_) {
          throw const SerializationFailure(
            'Dữ liệu phản hồi từ máy chủ không đúng định dạng JSON.',
          );
        }
      }
    }
    return null;
  }

  static dynamic _coerceDecodedJson(dynamic raw) {
    if (raw is String) {
      final trimmed = raw.trim();
      if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
          (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
        try {
          return jsonDecode(trimmed);
        } catch (_) {
          throw const SerializationFailure(
            'Dữ liệu phản hồi từ máy chủ không đúng định dạng JSON.',
          );
        }
      }
    }
    if (raw is Map && raw is! Map<String, dynamic>) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return raw;
  }

  /// Unwraps `{ success, message, data, code, details, errors }` envelope.
  static dynamic unwrapEnvelope(dynamic responseBody) {
    final normalizedBody = _coerceDecodedJson(responseBody);
    if (normalizedBody is Map<String, dynamic>) {
      if (normalizedBody['success'] == false) {
        final msg = normalizedBody['message']?.toString() ??
            'Không thể thực hiện yêu cầu.';
        final code = normalizedBody['code']?.toString() ?? 'API_ERROR';
        final details = normalizedBody['details'] ?? normalizedBody['errors'];
        final fieldErrors =
            _parseFieldErrors(details, normalizedBody['errors']);
        throw ValidationFailure(
          msg,
          code: code,
          details: details,
          fieldErrors: fieldErrors,
        );
      }
      if (normalizedBody.containsKey('data')) {
        return normalizedBody['data'];
      }
    }
    return normalizedBody;
  }

  static PaginatedResult<T> parsePaginated<T>(
    dynamic responseBody,
    T Function(Map<String, dynamic>) mapper,
  ) {
    final normalizedRoot = _coerceDecodedJson(responseBody);
    final data = _coerceDecodedJson(unwrapEnvelope(normalizedRoot));
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
      } else if (data['reviews'] is List) {
        rawItems = data['reviews'] as List<dynamic>;
      } else if (data['blogs'] is List) {
        rawItems = data['blogs'] as List<dynamic>;
      } else if (data['conversations'] is List) {
        rawItems = data['conversations'] as List<dynamic>;
      } else if (data['messages'] is List) {
        rawItems = data['messages'] as List<dynamic>;
      }
      rawPagination = _coerceJsonMap(data['pagination']) ??
          _coerceJsonMap(data['meta']) ??
          ((data.containsKey('page') ||
                  data.containsKey('total') ||
                  data.containsKey('totalPages'))
              ? data
              : null);
    } else if (data is List) {
      rawItems = data;
    } else if (data != null) {
      throw const SerializationFailure(
        'Dữ liệu danh sách từ máy chủ không đúng cấu trúc.',
      );
    }

    if (rawPagination == null && normalizedRoot is Map<String, dynamic>) {
      rawPagination = _coerceJsonMap(normalizedRoot['pagination']) ??
          _coerceJsonMap(normalizedRoot['meta']);
    }

    final items = <T>[];
    for (final rawItem in rawItems) {
      final itemMap = _coerceJsonMap(rawItem);
      if (itemMap == null) continue;
      try {
        items.add(mapper(itemMap));
      } catch (e) {
        if (e is AppFailure) rethrow;
        throw SerializationFailure(
          'Không thể đọc dữ liệu mục danh sách từ máy chủ.',
          'SERIALIZATION_ERROR',
          e.toString(),
          e,
        );
      }
    }

    return PaginatedResult<T>(
      items: List<T>.unmodifiable(items),
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
      final mapItem = _coerceJsonMap(item);
      if (mapItem != null) {
        result.add(ApiFieldError.fromJson(mapItem));
      }
    }
    return result;
  }

  static int? _extractRetryAfterSeconds(Response<dynamic>? response) {
    if (response == null) return null;
    final headerValue = response.headers.value('retry-after') ??
        response.headers.value('Retry-After');
    if (headerValue != null && headerValue.trim().isNotEmpty) {
      final parsedInt = int.tryParse(headerValue.trim());
      if (parsedInt != null && parsedInt >= 0) {
        return parsedInt;
      }
    }
    final bodyMap = _coerceJsonMap(response.data);
    final bodyRetryAfter = bodyMap?['retryAfter'] ?? bodyMap?['retry_after'];
    if (bodyRetryAfter is num) {
      return bodyRetryAfter.toInt();
    }
    if (bodyRetryAfter is String) {
      return int.tryParse(bodyRetryAfter.trim());
    }
    return null;
  }

  static NetworkFailure _classifyTransportFailure(DioException error) {
    final combined =
        '${error.message ?? ''} ${error.error ?? ''}'.toLowerCase();

    if (error.type == DioExceptionType.badCertificate ||
        combined.contains('handshakeexception') ||
        combined.contains('certificate_verify_failed') ||
        combined.contains('bad certificate') ||
        combined.contains('tlsv1') ||
        combined.contains('ssl_error') ||
        combined.contains('x509')) {
      return const CertificateFailure();
    }

    if (combined.contains('failed host lookup') ||
        combined.contains('no address associated with hostname') ||
        combined.contains('nodename nor servname provided') ||
        combined.contains('name or service not known') ||
        combined.contains('getaddrinfo') ||
        combined.contains('nxdomain') ||
        combined.contains('errno = 7') ||
        combined.contains('errno = 11001')) {
      return const DnsFailure();
    }

    if (combined.contains('connection refused') ||
        combined.contains('econnrefused') ||
        combined.contains('errno = 111') ||
        combined.contains('errno = 61') ||
        combined.contains('errno = 10061') ||
        combined.contains('connection reset by peer') ||
        combined.contains('econnreset')) {
      return const ConnectionRefusedFailure();
    }

    return const OfflineFailure();
  }

  /// Translates DioException into clean typed AppFailure without converting HTTP errors to success
  /// and without conflating DNS/TLS/timeout/server/serialization failures with device offline.
  static AppFailure handleError(dynamic error) {
    if (error is AppFailure) {
      return error;
    }
    if (error is FormatException || error is TypeError) {
      return SerializationFailure(
        'Dữ liệu phản hồi từ máy chủ không đúng định dạng.',
        'SERIALIZATION_ERROR',
        error.toString(),
        error,
      );
    }
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return const TimeoutFailure(
            'Kết nối đến máy chủ quá thời gian chờ. Vui lòng thử lại.',
            'CONNECT_TIMEOUT',
          );
        case DioExceptionType.sendTimeout:
          return const TimeoutFailure(
            'Gửi dữ liệu đến máy chủ quá thời gian chờ. Vui lòng thử lại.',
            'SEND_TIMEOUT',
          );
        case DioExceptionType.receiveTimeout:
          return const TimeoutFailure(
            'Máy chủ phản hồi quá thời gian chờ. Vui lòng thử lại.',
            'RECEIVE_TIMEOUT',
          );
        case DioExceptionType.badCertificate:
          return const CertificateFailure();
        case DioExceptionType.connectionError:
          return _classifyTransportFailure(error);
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final rawData = error.response?.data;
          Map<String, dynamic> mapData = const <String, dynamic>{};
          if (rawData is Map<String, dynamic>) {
            mapData = rawData;
          } else if (rawData is Map) {
            mapData = rawData.map(
              (key, value) => MapEntry(key.toString(), value),
            );
          } else if (rawData is String) {
            final trimmed = rawData.trim();
            if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
              try {
                final decoded = jsonDecode(trimmed);
                if (decoded is Map) {
                  mapData = decoded.map(
                    (key, value) => MapEntry(key.toString(), value),
                  );
                }
              } catch (_) {}
            }
          }

          final code = mapData['code']?.toString() ?? 'HTTP_$statusCode';
          final details = mapData['details'] ?? mapData['errors'];
          final fieldErrors = _parseFieldErrors(details, mapData['errors']);
          final rawMessage = mapData['message']?.toString().trim();
          final serverMessage =
              (rawMessage != null && rawMessage.isNotEmpty) ? rawMessage : null;

          if (statusCode == 401) {
            return AuthFailure(
              serverMessage ??
                  'Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại.',
              code,
              401,
            );
          } else if (statusCode == 403) {
            return ForbiddenFailure(
              serverMessage ?? 'Bạn không có quyền truy cập chức năng này.',
              code,
            );
          } else if (statusCode == 404) {
            return NotFoundFailure(
              serverMessage ?? 'Không tìm thấy dữ liệu yêu cầu.',
              code,
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
              statusCode == 413 ||
              statusCode == 415 ||
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
            final retryAfter = _extractRetryAfterSeconds(error.response);
            return RateLimitFailure.withRetryAfter(
              serverMessage ??
                  'Bạn đã thao tác quá nhanh. Vui lòng thử lại sau ít phút.',
              code: code,
              retryAfterSeconds: retryAfter,
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
          return const RequestCancelledFailure('Yêu cầu đã bị hủy.');
        default:
          if (error.type.name.toLowerCase().contains('timeout')) {
            return const TimeoutFailure(
              'Xử lý dữ liệu phản hồi quá thời gian chờ. Vui lòng thử lại.',
              'TRANSFORM_TIMEOUT',
            );
          }
          final underlying = error.error;
          if (underlying is AppFailure) {
            return underlying;
          }
          if (underlying is FormatException || underlying is TypeError) {
            return SerializationFailure(
              'Dữ liệu phản hồi từ máy chủ không đúng định dạng.',
              'SERIALIZATION_ERROR',
              underlying.toString(),
              underlying,
            );
          }
          return _classifyTransportFailure(error);
      }
    }
    return UnknownFailure(error.toString());
  }
}
