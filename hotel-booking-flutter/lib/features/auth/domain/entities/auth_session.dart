import 'user.dart';

class AuthSession {
  final String token;
  final User user;

  const AuthSession({
    required this.token,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final token =
        json['token']?.toString() ?? json['accessToken']?.toString() ?? '';
    final userJson = json['user'] as Map<String, dynamic>? ?? {};
    return AuthSession(
      token: token,
      user: User.fromJson(userJson),
    );
  }
}
