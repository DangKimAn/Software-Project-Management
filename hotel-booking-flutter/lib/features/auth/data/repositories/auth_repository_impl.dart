import '../../../../core/network/dio_client.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final DioClient _client;
  final SecureStorageService _storage;

  const AuthRepositoryImpl(this._client, this._storage);

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
      );
      final body = response.data;
      final data = (body?['data'] as Map<String, dynamic>?) ?? body ?? {};
      final session = AuthSession.fromJson(data);

      if (session.token.isNotEmpty) {
        await _storage.saveAuthToken(session.token);
      }
      return session;
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
      );
      final body = response.data;
      final data = (body?['data'] as Map<String, dynamic>?) ?? body ?? {};
      final session = AuthSession.fromJson(data);

      if (session.token.isNotEmpty) {
        await _storage.saveAuthToken(session.token);
      }
      return session;
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
      );
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  @override
  Future<User?> getCurrentUser() async {
    try {
      final token = await _storage.getAuthToken();
      if (token == null || token.isEmpty) return null;

      final response =
          await _client.dio.get<Map<String, dynamic>>('/api/auth/me');
      final body = response.data;
      final data = (body?['data'] as Map<String, dynamic>?) ?? body;
      if (data == null) return null;
      final userJson = (data['user'] as Map<String, dynamic>?) ?? data;
      return User.fromJson(userJson);
    } catch (e) {
      // If unauthorized, token is expired or invalid
      await _storage.deleteAuthToken();
      return null;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _client.dio.post<Map<String, dynamic>>(
        '/api/auth/logout',
        data: {},
      );
    } catch (_) {
      // Ignore network errors on logout
    } finally {
      await _storage.deleteAuthToken();
    }
  }
}
