import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/providers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/socket_service.dart';
import '../../../../core/notifications/push_notification_service.dart';
import '../../../../core/storage/preferences_service.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/services/google_auth_service.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(dioClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthRepositoryImpl(client, storage);
});

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});

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

  Future<void> checkCurrentUser() async {
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

  /// Silently re-verifies the active session when the app resumes from background
  /// without flashing the global loading screen.
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

  /// Invoked when `DioClient` detects an unrecoverable 401/403 during token refresh.
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

  /// Invoked when `DioClient` refreshes the access token and receives updated user claims.
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
      if (mounted && epoch == _authOpEpoch) {
        state = AsyncValue.data(previousUser);
      }
      rethrow;
    }
  }

  /// Authenticates with Google using the official Google Sign-In SDK, then
  /// exchanges the verified `idToken` with `POST /api/auth/google`.
  Future<User> signInWithGoogle() async {
    final idToken = await _googleAuthService.obtainIdToken();
    return loginWithGoogle(idToken);
  }

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
      if (mounted && epoch == _authOpEpoch) {
        state = AsyncValue.data(previousUser);
      }
      rethrow;
    }
  }

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
      if (mounted && epoch == _authOpEpoch) {
        state = AsyncValue.data(previousUser);
      }
      rethrow;
    }
  }

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

  Future<User> updateAvatar({required String url, String? key}) async {
    final updated = await _repository.updateAvatar(url: url, key: key);
    if (mounted) {
      state = AsyncValue.data(updated);
    }
    return updated;
  }

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

  bool get isAuthenticated => state.valueOrNull != null;
  User? get currentUser => state.valueOrNull;

  /// Validates that [redirectTo] is a trusted internal application path and
  /// cannot be abused for open redirects or auth-screen loops.
  static bool isSafeRedirectPath(String? redirectTo) {
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

  static String defaultRouteForUser(User user) {
    if (user.isAdmin) return '/admin';
    if (user.isHost) return '/chu-nha/cho-nghi';
    if (user.isNewHost) return '/tro-thanh-host/trang-thai';
    return '/account/profile';
  }

  /// Resolves post-login redirect route matching `resolvePostAuthRoute` and
  /// role guards in `ProtectedRoute.tsx` / `HostRoute.tsx`.
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

    return candidate;
  }
}

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
