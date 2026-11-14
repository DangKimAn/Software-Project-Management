import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Triển khai cụ thể của `AuthRepository` kết hợp `DioClient` và bộ nhớ an toàn `SecureStorageService`.
///
/// Quản lý toàn bộ vòng đời lưu trữ khóa phiên (Access Token, Refresh Token và Refresh Cookie),
/// khôi phục phiên tự động khi khởi động ứng dụng, xác thực Google OAuth và hủy phiên an toàn khi đăng xuất.
class AuthRepositoryImpl implements AuthRepository {
  final DioClient _client;
  final SecureStorageService _storage;

  /// Khởi tạo `AuthRepositoryImpl` với khách mạng `_client` và dịch vụ lưu trữ bảo mật `_storage`.
  const AuthRepositoryImpl(this._client, this._storage);

  // Giải thuật bóc tách và lưu trữ bền vững phiên đăng nhập mới (`_parseAndPersistSession`):
  // Bước 1: Mở khung bao phản hồi API, giải mã `AuthSession` và kiểm tra tính toàn vẹn của `token` cùng `user.id`.
  // Bước 2: Xóa sạch phiên cũ (`clearAuthSession`) để tuyệt đối không kế thừa nhầm Refresh Token của tài khoản trước.
  // Bước 3: Lưu `token` mới, lưu `refreshToken` (nếu có) và đồng bộ header `Set-Cookie` vào kho lưu trữ bảo mật.
  Future<AuthSession> _parseAndPersistSession(
    Response<Map<String, dynamic>> response,
  ) async {
    final body = response.data;
    DioClient.unwrapEnvelope(body);
    final data = (body?['data'] as Map<String, dynamic>?) ?? body ?? {};
    final session = AuthSession.fromJson(data);

    if (session.token.trim().isEmpty || session.user.id.trim().isEmpty) {
      throw const AuthFailure(
        'Phản hồi xác thực từ máy chủ không hợp lệ.',
        'INVALID_AUTH_SESSION',
      );
    }

    // Do not inherit refresh credentials from a previous account.
    await _storage.clearAuthSession();
    await _storage.saveAuthToken(session.token);
    if (session.refreshToken != null && session.refreshToken!.isNotEmpty) {
      await _storage.saveRefreshToken(session.refreshToken!);
    }
    final setCookies =
        response.headers['set-cookie'] ?? response.headers['Set-Cookie'];
    await _storage.syncRefreshCookieFromHeaders(setCookies);
    return session;
  }

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {
          'identifier': identifier.trim(),
          'password': password,
        },
        options:
            Options(extra: const <String, dynamic>{'skipAuthRefresh': true}),
      );
      return await _parseAndPersistSession(response);
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  @override
  Future<AuthSession> loginWithGoogle({required String idToken}) async {
    final trimmedToken = idToken.trim();
    if (trimmedToken.isEmpty) {
      throw const ValidationFailure(
        'Google ID Token không được để trống.',
        code: 'EMPTY_GOOGLE_ID_TOKEN',
      );
    }
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/api/auth/google',
        data: {
          'idToken': trimmedToken,
        },
        options:
            Options(extra: const <String, dynamic>{'skipAuthRefresh': true}),
      );
      return await _parseAndPersistSession(response);
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/api/auth/register',
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        },
        options:
            Options(extra: const <String, dynamic>{'skipAuthRefresh': true}),
      );
      return await _parseAndPersistSession(response);
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  @override
  Future<void> forgotPassword({required String identifier}) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/api/auth/forgot-password',
        data: {
          'identifier': identifier.trim(),
        },
        options:
            Options(extra: const <String, dynamic>{'skipAuthRefresh': true}),
      );
      DioClient.unwrapEnvelope(response.data);
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  @override
  Future<void> resetPassword({
    required String identifier,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/api/auth/reset-password',
        data: {
          'identifier': identifier.trim(),
          'otp': otp.trim(),
          'newPassword': newPassword,
        },
        options:
            Options(extra: const <String, dynamic>{'skipAuthRefresh': true}),
      );
      DioClient.unwrapEnvelope(response.data);
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  /// Làm mới Access Token thông qua cơ chế xoay vòng khóa phiên của `DioClient`.
  Future<String?> refreshSession() {
    return _client.refreshAccessToken();
  }

  /// Khôi phục người dùng hiện hành từ kho khóa bảo mật kết hợp hợp nhất dữ liệu `/api/auth/me` và `/api/users/me`.
  @override
  Future<User?> getCurrentUser() async {
    // Giải thuật khôi phục phiên đăng nhập hiện hành (`getCurrentUser`):
    // Bước 1: Kiểm tra `authToken` trong `SecureStorageService`; nếu trống nhưng còn Refresh Cookie / Refresh Token (hoặc trên Web),
    //         chủ động gọi `refreshAccessToken()` để xin cấp lại Access Token mới trước khi bỏ cuộc.
    // Bước 2: Truy vấn `/api/auth/me` lấy thông tin định danh & vai trò cốt lõi, sau đó gọi bổ sung `/api/users/me`
    //         để hợp nhất đầy đủ các trường hồ sơ mở rộng (`bio`, `location`, `school`, `languages`).
    // Bước 3: Nếu máy chủ trả về lỗi `401` không thể phục hồi, dọn sạch phiên cục bộ và trả về `null`.
    try {
      var token = await _storage.getAuthToken();
      if (token == null || token.trim().isEmpty) {
        final canAttemptRefresh = kIsWeb ||
            await _storage.hasRefreshCookie() ||
            await _storage.hasRefreshToken();
        if (!canAttemptRefresh) {
          return null;
        }
        token = await _client.refreshAccessToken();
        if (token == null || token.trim().isEmpty) {
          return null;
        }
      }

      final response =
          await _client.dio.get<Map<String, dynamic>>('/api/auth/me');
      final body = response.data;
      DioClient.unwrapEnvelope(body);
      final data = (body?['data'] as Map<String, dynamic>?) ?? body;
      if (data == null) {
        throw const ServerFailure(
            'Máy chủ trả về thông tin phiên không hợp lệ.',
            code: 'INVALID_AUTH_USER');
      }
      final userJson = (data['user'] as Map<String, dynamic>?) ?? data;
      var user = User.fromJson(userJson);
      if (user.id.trim().isEmpty) {
        throw const ServerFailure(
            'Máy chủ trả về thông tin phiên không hợp lệ.',
            code: 'INVALID_AUTH_USER');
      }

      try {
        final profileRes =
            await _client.dio.get<Map<String, dynamic>>('/api/users/me');
        final pBody = profileRes.data;
        final pData = (pBody?['data'] as Map<String, dynamic>?) ?? pBody;
        if (pData != null) {
          final mergedJson = <String, dynamic>{
            ...userJson,
            ...pData,
            if (pData['user'] is Map<String, dynamic>)
              ...(pData['user'] as Map<String, dynamic>),
          };
          user = User.fromJson(mergedJson);
        }
      } catch (_) {
        // Keep base /api/auth/me user if /api/users/me is unavailable
      }
      return user;
    } catch (e) {
      final mapped = DioClient.handleError(e);
      if (mapped is AuthFailure && mapped.statusCode == 401) {
        await _storage.clearAuthSession();
        return null;
      }
      throw mapped;
    }
  }

  @override
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
    try {
      final response = await _client.dio.patch<Map<String, dynamic>>(
        '/api/users/me',
        data: {
          if (fullName != null) 'fullName': fullName.trim(),
          if (phone != null) 'phone': phone.trim(),
          if (bio != null) 'bio': bio.trim(),
          if (location != null) 'location': location.trim(),
          if (job != null) 'job': job.trim(),
          if (dreamDestination != null)
            'dreamDestination': dreamDestination.trim(),
          if (school != null) 'school': school.trim(),
          if (languages != null) 'languages': languages,
          if (avatarUrl != null) 'avatarUrl': avatarUrl.trim(),
        },
      );
      final body = response.data;
      final data = (body?['data'] as Map<String, dynamic>?) ?? body ?? {};
      final userJson = (data['user'] as Map<String, dynamic>?) ?? data;
      return User.fromJson(userJson);
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  @override
  Future<User> updateAvatar({
    required String url,
    String? key,
  }) async {
    try {
      final response = await _client.dio.patch<Map<String, dynamic>>(
        '/api/users/me/avatar',
        data: {
          'url': url.trim(),
          if (key != null && key.trim().isNotEmpty) 'key': key.trim(),
        },
      );
      final body = response.data;
      final data = (body?['data'] as Map<String, dynamic>?) ?? body ?? {};
      final userJson = (data['user'] as Map<String, dynamic>?) ?? data;
      return User.fromJson(userJson);
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  @override
  Future<void> logout() async {
    // Immediately cancel any active refresh / session tasks so they cannot
    // overwrite state while logout is in flight.
    await _client.abortSession(clearStorage: false);
    try {
      await _client.dio.post<Map<String, dynamic>>(
        '/api/auth/logout',
        data: const <String, dynamic>{},
        options:
            Options(extra: const <String, dynamic>{'skipAuthRefresh': true}),
      );
    } catch (_) {
      // Ignore network errors on logout; local session will still be cleared.
    } finally {
      await _client.abortSession(clearStorage: true);
    }
  }
}
