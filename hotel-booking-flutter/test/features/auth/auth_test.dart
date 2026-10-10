import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/auth_session.dart';
import 'package:hotel_booking_flutter/features/auth/domain/entities/user.dart';

void main() {
  group('Auth Domain Tests', () {
    test('User.fromJson correctly parses guest user payload', () {
      final json = {
        'id': 101,
        'email': 'guest@example.com',
        'firstName': 'Nguyen',
        'lastName': 'An',
        'role': 'guest',
        'phone': '0901234567',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'isVerified': true,
      };

      final user = User.fromJson(json);

      expect(user.id, '101');
      expect(user.email, 'guest@example.com');
      expect(user.fullName, 'Nguyen An');
      expect(user.isHost, isFalse);
      expect(user.isAdmin, isFalse);
      expect(user.isVerified, isTrue);
    });

    test('User.fromJson correctly parses host user role', () {
      final json = {
        'userId': 202,
        'email': 'host@example.com',
        'firstName': 'Tran',
        'lastName': 'Host',
        'role': 'host',
      };

      final user = User.fromJson(json);

      expect(user.id, '202');
      expect(user.isHost, isTrue);
      expect(user.isAdmin, isFalse);
    });

    test('AuthSession.fromJson parses access token and nested user', () {
      final json = {
        'token': 'jwt_access_token_xyz',
        'user': {
          'id': 303,
          'email': 'user@example.com',
          'firstName': 'Le',
          'lastName': 'Binh',
          'role': 'guest',
        },
      };

      final session = AuthSession.fromJson(json);

      expect(session.token, 'jwt_access_token_xyz');
      expect(session.user.id, '303');
      expect(session.user.fullName, 'Le Binh');
    });
  });
}
