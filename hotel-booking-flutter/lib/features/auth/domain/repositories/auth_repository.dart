import '../entities/auth_session.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<AuthSession> login({
    required String identifier,
    required String password,
  });

  Future<AuthSession> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  });

  Future<void> forgotPassword({
    required String identifier,
  });

  Future<void> resetPassword({
    required String identifier,
    required String otp,
    required String newPassword,
  });

  Future<User?> getCurrentUser();

  Future<void> logout();
}
