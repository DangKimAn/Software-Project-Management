import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final DioClient _client;
  final SecureStorageService _storage;

  const AuthRepositoryImpl(this._client, this._storage);

  Future<AuthSession> _parseAndPersistSession(
    Response<Map<String, dynamic>> response,
  ) async {
    final body = response.data;
    final data = (body?['data'] as Map<String, dynamic>?) ?? body ?? {};
    final session = AuthSession.fromJson(data);

    if (session.token.trim().isEmpty || session.user.id.trim().isEmpty) {
      throw const AuthFailure(
        'Phản hồi xác thực từ máy chủ không hợp lệ.',
        'INVALID_AUTH_SESSION',
      );
    }

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
      await _client.dio.post<Map<String, dynamic>>(
        '/api/auth/forgot-password',
        data: {
          'identifier': identifier.trim(),
        },
        options:
            Options(extra: const <String, dynamic>{'skipAuthRefresh': true}),
      );
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
      await _client.dio.post<Map<String, dynamic>>(
        '/api/auth/reset-password',
        data: {
          'identifier': identifier.trim(),
          'otp': otp.trim(),
          'newPassword': newPassword,
        },
        options:
            Options(extra: const <String, dynamic>{'skipAuthRefresh': true}),
      );
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<String?> refreshSession() {
    return _client.refreshAccessToken();
  }

  @override
  Future<User?> getCurrentUser() async {
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
      final data = (body?['data'] as Map<String, dynamic>?) ?? body;
      if (data == null) return null;
      final userJson = (data['user'] as Map<String, dynamic>?) ?? data;
      var user = User.fromJson(userJson);
      if (user.id.trim().isEmpty) {
        await _storage.clearAuthSession();
        return null;
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
      if (mapped is AuthFailure) {
        await _storage.clearAuthSession();
      }
      return null;
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
