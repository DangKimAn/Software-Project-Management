import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/providers.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/socket_service.dart';
import '../../../../core/notifications/push_notification_service.dart';
import '../../../../core/storage/preferences_service.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/services/google_auth_service.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
export '../../data/services/google_auth_service.dart'
    show GoogleSignInCancelledException;

/// Provider khởi tạo kho lưu trữ xác thực `AuthRepository` kết nối mạng và kho khóa bảo mật.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthRepositoryImpl(client, storage);
});

/// Provider cung cấp dịch vụ đăng nhập Google OAuth `GoogleAuthService`.
final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});

/// Bộ quản lý trạng thái xác thực trung tâm của ứng dụng (`AsyncValue<User?>`).
///
/// Điều phối toàn bộ vòng đời phiên người dùng:
/// - Kiểm tra phiên đăng nhập hiện hành khi mở ứng dụng và xác minh ngầm khi ứng dụng quay lại tiền cảnh (`onAppResumed`).
/// - Sử dụng bộ đếm kỷ nguyên `_authOpEpoch` chống ghi đè trạng thái lệch nhịp khi nhiều tác vụ đăng nhập/đăng xuất chạy chồng lấn.
/// - Tự động kết nối / ngắt kết nối kênh Socket.IO thời gian thực, hủy đăng ký thiết bị nhận thông báo đẩy khi đăng xuất,
///   và thẩm định chống lỗ hổng chuyển hướng mở (`isSafeRedirectPath`, `resolvePostAuthRedirectPath`).
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthRepository _repository;
  final PreferencesService? _prefs;
  final SocketService? _socket;
  final GoogleAuthService _googleAuthService;
  final DioClient? _dioClient;
  final PushNotificationService? _pushNotifications;

  int _authOpEpoch = 0;
  bool _isCheckingResume = false;

  static const Set<String> _authEntryPaths = <String>{
    '/dang-nhap',
    '/login',
    '/dang-ky',
    '/register',
    '/quen-mat-khau',
    '/forgot-password',
    '/dat-lai-mat-khau',
    '/reset-password',
  };

  /// Khởi tạo `AuthNotifier`, đăng ký lắng nghe sự kiện hết hạn hoặc làm mới phiên từ `DioClient` và kiểm tra người dùng hiện tại.
  AuthNotifier(
    this._repository, {
    PreferencesService? prefs,
    SocketService? socket,
    GoogleAuthService? googleAuthService,
    DioClient? dioClient,
    PushNotificationService? pushNotifications,
  })  : _prefs = prefs,
        _socket = socket,
        _googleAuthService = googleAuthService ?? GoogleAuthService(),
        _dioClient = dioClient,
        _pushNotifications = pushNotifications,
        super(const AsyncValue.loading()) {
    _dioClient?.addSessionExpiredListener(_onClientSessionExpired);
    _dioClient?.addSessionRefreshedListener(_onClientSessionRefreshed);
    checkCurrentUser();
  }

  void _onClientSessionExpired() {
    handleSessionExpired();
  }

  void _onClientSessionRefreshed(
    String accessToken,
    Map<String, dynamic>? userJson,
  ) {
    handleSessionRefreshed(userJson);
    _socket?.connect();
  }

  @override
  void dispose() {
    _dioClient?.removeSessionExpiredListener(_onClientSessionExpired);
    _dioClient?.removeSessionRefreshedListener(_onClientSessionRefreshed);
    super.dispose();
  }

  /// Truy vấn và khôi phục trạng thái người dùng hiện tại từ kho lưu trữ, đồng thời kích hoạt kết nối Socket.IO nếu hợp lệ.
  Future<void> checkCurrentUser() async {
    // Giải thuật kiểm tra phiên khởi tạo bảo vệ bằng kỷ nguyên `_authOpEpoch` để bỏ qua phản hồi trễ lỗi thời.
    final epoch = ++_authOpEpoch;
    state = const AsyncValue.loading();
    try {
      final user = await _repository.getCurrentUser();
      if (!mounted || epoch != _authOpEpoch) return;
      state = AsyncValue.data(user);
      if (user != null) {
        await _socket?.connect();
      } else {
        _socket?.disconnect();
      }
    } catch (error, stackTrace) {
      if (!mounted || epoch != _authOpEpoch) return;
      _socket?.disconnect();
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Xác minh ngầm phiên đăng nhập khi ứng dụng trở lại tiền cảnh mà không bật màn hình chờ toàn cục.
  Future<void> onAppResumed() async {
    if (!mounted || state.isLoading || _isCheckingResume) return;
    final current = state.valueOrNull;
    if (current == null) return;

    _isCheckingResume = true;
    final epoch = _authOpEpoch;
    try {
      final refreshedUser = await _repository.getCurrentUser();
      if (!mounted || epoch != _authOpEpoch) return;
      if (refreshedUser != null) {
        state = AsyncValue.data(refreshedUser);
        await _socket?.connect();
      } else {
        _socket?.disconnect();
        await _prefs?.clearSessionData();
        state = const AsyncValue.data(null);
      }
    } catch (_) {
      // Ignore transient network errors on resume; DioClient will trigger
      // handleSessionExpired if the refresh token itself was rejected.
    } finally {
      _isCheckingResume = false;
    }
  }

  /// Xử lý dọn dẹp toàn diện trạng thái cục bộ, Socket.IO và phiên Google khi `DioClient` phát hiện lỗi `401`/`403` không thể gia hạn.
  Future<void> handleSessionExpired() async {
    _pushNotifications?.clearLocalSyncState();
    final epoch = ++_authOpEpoch;
    _socket?.disconnect();
    if (mounted) {
      state = const AsyncValue.data(null);
    }
    try {
      await _prefs?.clearSessionData();
    } finally {
      if (mounted && epoch == _authOpEpoch) {
        await _googleAuthService.signOut();
      }
    }
  }

  /// Hợp nhất thông tin vai trò và hồ sơ mới nhận được từ phản hồi gia hạn Access Token vào trạng thái người dùng trên bộ nhớ.
  void handleSessionRefreshed(Map<String, dynamic>? userJson) {
    if (!mounted || userJson == null || userJson.isEmpty) return;
    final refreshed = User.fromJson(userJson);
    if (refreshed.id.trim().isEmpty) return;
    final existing = state.valueOrNull;
    if (existing != null && existing.id == refreshed.id) {
      state = AsyncValue.data(
        existing.copyWith(
          firstName: refreshed.firstName.isNotEmpty
              ? refreshed.firstName
              : existing.firstName,
          lastName: refreshed.lastName.isNotEmpty
              ? refreshed.lastName
              : existing.lastName,
          phone: refreshed.phone ?? existing.phone,
          avatarUrl: userJson.containsKey('avatarUrl')
              ? refreshed.avatarUrl
              : existing.avatarUrl,
          role: userJson.containsKey('role') || userJson.containsKey('roles')
              ? refreshed.role
              : existing.role,
          roles: userJson.containsKey('role') || userJson.containsKey('roles')
              ? refreshed.roles
              : existing.roles,
          status: userJson.containsKey('status')
              ? refreshed.status
              : existing.status,
          isVerified: userJson.containsKey('isVerified')
              ? refreshed.isVerified
              : existing.isVerified,
          isHostVerified: userJson.containsKey('isHostVerified') ||
                  userJson.containsKey('is_host_verified')
              ? refreshed.isHostVerified
              : existing.isHostVerified,
        ),
      );
    } else {
      state = AsyncValue.data(refreshed);
    }
  }

  /// Đăng nhập bằng định danh `identifier` và mật khẩu `password`, cập nhật trạng thái phiên và kết nối Socket.IO.
  Future<User> login(String identifier, String password) async {
    final epoch = ++_authOpEpoch;
    final previousUser = state.valueOrNull;
    try {
      final session = await _repository.login(
        identifier: identifier,
        password: password,
      );
      if (!mounted || epoch != _authOpEpoch) {
        return session.user;
      }
      state = AsyncValue.data(session.user);
      await _socket?.connect();
      return session.user;
    } catch (e) {
      if (mounted && epoch != _authOpEpoch) {
        state = AsyncValue.data(previousUser);
      }
      rethrow;
    }
  }

  /// Mở hộp thoại đăng nhập Google qua `GoogleAuthService` rồi trao đổi `idToken` (hoặc `accessToken` dự phòng trên Web) với `POST /api/auth/google`.
  Future<User> signInWithGoogle() async {
    try {
      final idToken = await _googleAuthService.obtainIdToken();
      return await loginWithGoogle(idToken);
    } on AuthFailure catch (e) {
      if (e.code == 'GOOGLE_WEB_ACCESS_TOKEN_FALLBACK') {
        final fallbackAccessToken =
            _googleAuthService.consumePendingWebAccessToken();
        final repo = _repository;
        if (fallbackAccessToken != null &&
            fallbackAccessToken.isNotEmpty &&
            repo is AuthRepositoryImpl) {
          final epoch = ++_authOpEpoch;
          final previousUser = state.valueOrNull;
          try {
            final session = await repo.loginWithGoogleAccessToken(
              accessToken: fallbackAccessToken,
            );
            if (!mounted || epoch != _authOpEpoch) {
              return session.user;
            }
            state = AsyncValue.data(session.user);
            await _socket?.connect();
            return session.user;
          } catch (innerErr) {
            if (mounted && epoch != _authOpEpoch) {
              state = AsyncValue.data(previousUser);
            }
            rethrow;
          }
        }
      }
      rethrow;
    }
  }

  /// Trao đổi trực tiếp chuỗi `idToken` của Google với máy chủ để mở phiên đăng nhập hệ thống.
  Future<User> loginWithGoogle(String idToken) async {
    final epoch = ++_authOpEpoch;
    final previousUser = state.valueOrNull;
    try {
      final session = await _repository.loginWithGoogle(idToken: idToken);
      if (!mounted || epoch != _authOpEpoch) {
        return session.user;
      }
      state = AsyncValue.data(session.user);
      await _socket?.connect();
      return session.user;
    } catch (e) {
      if (mounted && epoch != _authOpEpoch) {
        state = AsyncValue.data(previousUser);
      }
      rethrow;
    }
  }

  /// Đăng ký tài khoản mới và tự động chuyển sang trạng thái đã đăng nhập ngay khi hoàn tất.
  Future<User> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    final epoch = ++_authOpEpoch;
    final previousUser = state.valueOrNull;
    try {
      final session = await _repository.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );
      if (!mounted || epoch != _authOpEpoch) {
        return session.user;
      }
      state = AsyncValue.data(session.user);
      await _socket?.connect();
      return session.user;
    } catch (e) {
      if (mounted && epoch != _authOpEpoch) {
        state = AsyncValue.data(previousUser);
      }
      rethrow;
    }
  }

  /// Gửi cập nhật thông tin hồ sơ cá nhân lên máy chủ và đồng bộ ngay vào trạng thái `state`.
  Future<User> updateProfile({
    String? fullName,
    String? phone,
    String? bio,
    String? location,
    String? job,
    String? dreamDestination,
    String? school,
    List<String>? languages,
    String? avatarUrl,
  }) async {
    final updated = await _repository.updateProfile(
      fullName: fullName,
      phone: phone,
      bio: bio,
      location: location,
      job: job,
      dreamDestination: dreamDestination,
      school: school,
      languages: languages,
      avatarUrl: avatarUrl,
    );
    if (mounted) {
      state = AsyncValue.data(updated);
    }
    return updated;
  }

  /// Lưu đường dẫn ảnh đại diện mới lên máy chủ và cập nhật thực thể người dùng hiện hành.
  Future<User> updateAvatar({required String url, String? key}) async {
    final updated = await _repository.updateAvatar(url: url, key: key);
    if (mounted) {
      state = AsyncValue.data(updated);
    }
    return updated;
  }

  /// Đồng bộ tức thì đường dẫn ảnh đại diện `url` đã lưu thành công vào bộ nhớ phiên hiện hành.
  void syncLocalAvatarUrl(String url) {
    final trimmed = url.trim();
    if (!mounted || trimmed.isEmpty) return;
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(avatarUrl: trimmed));
  }

  /// Đăng xuất toàn diện: hủy đăng ký thông báo đẩy, ngắt Socket.IO, xóa dữ liệu phiên cục bộ,
  /// thoát Google SDK và thu hồi khóa phiên trên máy chủ.
  Future<void> logout() async {
    await _pushNotifications?.unregisterCurrentDevice();
    final epoch = ++_authOpEpoch;
    _socket?.disconnect();
    // Immediately clear authenticated user state so protected screens stop
    // issuing authenticated requests while logout completes.
    if (mounted) {
      state = const AsyncValue.data(null);
    }
    try {
      await _prefs?.clearSessionData();
    } finally {
      try {
        await _googleAuthService.signOut();
      } finally {
        await _repository.logout();
      }
    }
    if (mounted && epoch == _authOpEpoch) {
      state = const AsyncValue.data(null);
    }
  }

  /// Cho biết hiện tại có phiên người dùng đã đăng nhập hợp lệ hay không.
  bool get isAuthenticated => state.valueOrNull != null;

  /// Thực thể người dùng đang đăng nhập hiện tại (hoặc `null` nếu là khách vãng lai).
  User? get currentUser => state.valueOrNull;

  /// Kiểm tra đường dẫn chuyển hướng `redirectTo` là đường dẫn nội bộ an toàn,
  /// chặn triệt để lỗ hổng Open Redirect (`//`, tên miền ngoài, ký tự điều khiển) và vòng lặp về trang đăng nhập.
  static bool isSafeRedirectPath(String? redirectTo) {
    // Giải thuật thẩm định đường dẫn nội bộ chống Open Redirect:
    // Bắt buộc bắt đầu bằng một dấu `/` duy nhất, không chứa scheme/host/authority hay ký tự xuống dòng,
    // và không trỏ ngược về các tuyến màn hình xác thực (`_authEntryPaths`).
    if (redirectTo == null) return false;
    final candidate = redirectTo.trim();
    if (candidate.isEmpty) return false;
    if (!candidate.startsWith('/')) return false;
    if (candidate.startsWith('//') || candidate.startsWith(r'/\')) {
      return false;
    }
    if (RegExp(r'[\r\n\t]').hasMatch(candidate)) {
      return false;
    }

    final parsed = Uri.tryParse(candidate);
    if (parsed == null) return false;
    if (parsed.hasScheme || parsed.hasAuthority || parsed.host.isNotEmpty) {
      return false;
    }

    final pathOnly = parsed.path.trim();
    if (pathOnly.isEmpty || !pathOnly.startsWith('/')) {
      return false;
    }
    if (_authEntryPaths.contains(pathOnly)) {
      return false;
    }
    return true;
  }

  /// Trả về tuyến điều hướng mặc định sau khi đăng nhập tương ứng với vai trò của `user`.
  static String defaultRouteForUser(User user) {
    if (user.isAdmin) return '/admin';
    if (user.isHost) return '/chu-nha/cho-nghi';
    if (user.isNewHost) return '/tro-thanh-host/trang-thai';
    return '/account/profile';
  }

  /// Phân giải đường dẫn đích sau khi xác thực thành công dựa trên `redirectTo` và quyền vai trò của `user`.
  ///
  /// Nếu `redirectTo` không an toàn hoặc vượt thẩm quyền vai trò (ví dụ khách thường đòi vào `/admin` hay `/chu-nha`),
  /// hệ thống tự động lùi về `defaultRouteForUser(user)`.
  static String resolvePostAuthRedirectPath(User user, {String? redirectTo}) {
    final candidate = redirectTo?.trim() ?? '';
    if (!isSafeRedirectPath(candidate)) {
      return defaultRouteForUser(user);
    }

    final pathOnly = Uri.parse(candidate).path;
    final isAdminTarget =
        pathOnly == '/admin' || pathOnly.startsWith('/admin/');
    final isHostTarget = pathOnly == '/chu-nha' ||
        pathOnly.startsWith('/chu-nha/') ||
        pathOnly == '/host' ||
        pathOnly.startsWith('/host/');

    if (isAdminTarget && !user.isAdmin) {
      return defaultRouteForUser(user);
    }
    if (isHostTarget && (!user.isHost || user.isAdmin)) {
      return defaultRouteForUser(user);
    }
    if (pathOnly == '/' && (user.isAdmin || user.isHost || user.isNewHost)) {
      return defaultRouteForUser(user);
    }

    return candidate;
  }
}

/// Provider toàn cục quản lý trạng thái phiên đăng nhập `AuthNotifier`.
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  final client = ref.watch(dioClientProvider);
  final repository = ref.watch(authRepositoryProvider);
  final googleAuthService = ref.watch(googleAuthServiceProvider);
  PreferencesService? prefs;
  try {
    prefs = ref.watch(preferencesServiceProvider);
  } catch (_) {
    prefs = null;
  }
  final socket = ref.watch(socketServiceProvider);
  final pushNotifications = ref.watch(pushNotificationServiceProvider);
  return AuthNotifier(
    repository,
    prefs: prefs,
    socket: socket,
    googleAuthService: googleAuthService,
    dioClient: client,
    pushNotifications: pushNotifications,
  );
});
