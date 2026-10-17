import '../entities/auth_session.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<AuthSession> login({
    required String identifier,
    required String password,
  });

  Future<AuthSession> loginWithGoogle({
    required String idToken,
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
  });

  Future<User> updateAvatar({
    required String url,
    String? key,
  });

  Future<void> logout();
}
