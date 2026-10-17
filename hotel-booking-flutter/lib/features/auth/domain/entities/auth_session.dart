import 'user.dart';

class AuthSession {
  final String token;
  final String? refreshToken;
  final User user;
  final bool isNewUser;

  const AuthSession({
    required this.token,
    required this.user,
    this.refreshToken,
    this.isNewUser = false,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final token = (json['token']?.toString().trim().isNotEmpty == true
            ? json['token']?.toString().trim()
            : json['accessToken']?.toString().trim()) ??
        '';
    final rawRefresh = json['refreshToken']?.toString().trim();
    final userJson = (json['user'] is Map<String, dynamic>)
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    return AuthSession(
      token: token,
      refreshToken:
          (rawRefresh != null && rawRefresh.isNotEmpty) ? rawRefresh : null,
      user: User.fromJson(userJson),
      isNewUser: json['isNewUser'] == true,
    );
  }
}
