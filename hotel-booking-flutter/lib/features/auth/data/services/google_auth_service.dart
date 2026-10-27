import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/logging/app_logger.dart';

/// Exception thrown when the user explicitly cancels the Google Sign-In picker.
class GoogleSignInCancelledException implements Exception {
  final String message;
  final String code;

  const GoogleSignInCancelledException([
    this.message = 'Đã hủy đăng nhập Google.',
  ]) : code = 'GOOGLE_SIGN_IN_CANCELLED';

  @override
  String toString() => message;
}

/// Official Google Sign-In SDK wrapper for Android, iOS, and Flutter Web.
///
/// Obtains a verified Google OpenID Connect `idToken` from the native/web
/// Google Identity SDK to be exchanged with the Express backend at
/// `POST /api/auth/google`.
class GoogleAuthService {
  final GoogleSignIn? _customGoogleSignIn;
  final bool _enforceConfigGuard;
  GoogleSignIn? _lazyGoogleSignIn;

  GoogleAuthService({
    GoogleSignIn? googleSignIn,
    bool? enforceConfigGuard,
  })  : _customGoogleSignIn = googleSignIn,
        _enforceConfigGuard = enforceConfigGuard ?? (googleSignIn == null);

  GoogleSignIn _resolveClient() {
    if (_customGoogleSignIn != null) {
      return _customGoogleSignIn;
    }
    if (_lazyGoogleSignIn != null) {
      return _lazyGoogleSignIn!;
    }

    final webOrDefaultClientId = AppConfig.effectiveGoogleClientId;
    final serverClientId = AppConfig.effectiveGoogleServerClientId;
    final iosClientId = AppConfig.googleIosClientId.trim();

    if (kIsWeb) {
      _lazyGoogleSignIn = GoogleSignIn(
        clientId: webOrDefaultClientId.isNotEmpty ? webOrDefaultClientId : null,
        scopes: const <String>['email', 'profile', 'openid'],
      );
      return _lazyGoogleSignIn!;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final effectiveIosClientId = iosClientId.isNotEmpty
          ? iosClientId
          : (webOrDefaultClientId.isNotEmpty ? webOrDefaultClientId : null);
      _lazyGoogleSignIn = GoogleSignIn(
        clientId: effectiveIosClientId,
        serverClientId: serverClientId.isNotEmpty ? serverClientId : null,
        scopes: const <String>['email', 'profile', 'openid'],
      );
      return _lazyGoogleSignIn!;
    }

    // Android & other native platforms: serverClientId (Web OAuth 2.0 Client ID)
    // is required so Google Play Services issues an ID token verifiable by the
    // Express backend's GOOGLE_CLIENT_ID audience check.
    _lazyGoogleSignIn = GoogleSignIn(
      serverClientId: serverClientId.isNotEmpty ? serverClientId : null,
      scopes: const <String>['email', 'profile', 'openid'],
    );
    return _lazyGoogleSignIn!;
  }

  /// Launches the interactive Google Sign-In flow and returns a non-empty
  /// Google `idToken` ready for `POST /api/auth/google`.
  Future<String> obtainIdToken() async {
    if (_enforceConfigGuard) {
      if (kIsWeb && !AppConfig.isGoogleOAuthConfigured) {
        throw const ValidationFailure(
          'Chưa cấu hình GOOGLE_CLIENT_ID cho môi trường Web. '
          'Vui lòng truyền --dart-define=GOOGLE_CLIENT_ID=<web-client-id>.',
          code: 'GOOGLE_CLIENT_ID_MISSING',
        );
      }

      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          AppConfig.effectiveGoogleServerClientId.isEmpty) {
        throw const ValidationFailure(
          'Chưa cấu hình GOOGLE_CLIENT_ID / GOOGLE_SERVER_CLIENT_ID. '
          'Vui lòng cấu hình OAuth Web Client ID từ môi trường để nhận Google ID Token.',
          code: 'GOOGLE_SERVER_CLIENT_ID_MISSING',
        );
      }

      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS) &&
          !AppConfig.isGoogleOAuthConfigured) {
        throw const ValidationFailure(
          'Chưa cấu hình GOOGLE_IOS_CLIENT_ID / GOOGLE_CLIENT_ID cho iOS.',
          code: 'GOOGLE_IOS_CLIENT_ID_MISSING',
        );
      }
    }

    final googleSignIn = _resolveClient();

    try {
      // Clear previous cached selection so user can choose an account cleanly.
      try {
        await googleSignIn.signOut();
      } catch (_) {
        // Ignore sign-out errors before interactive sign-in.
      }

      final account = await googleSignIn.signIn();
      if (account == null) {
        throw const GoogleSignInCancelledException();
      }

      final auth = await account.authentication;
      final idToken = auth.idToken?.trim();
      if (idToken == null || idToken.isEmpty) {
        throw const AuthFailure(
          'Không nhận được Google ID Token hợp lệ từ Google SDK. '
              'Vui lòng kiểm tra cấu hình GOOGLE_SERVER_CLIENT_ID và SHA-1 fingerprint.',
          'GOOGLE_ID_TOKEN_EMPTY',
        );
      }

      return idToken;
    } on GoogleSignInCancelledException {
      rethrow;
    } on AppFailure {
      rethrow;
    } on PlatformException catch (e) {
      AppLogger.w('Google Sign-In platform failure');
      final normalizedCode = e.code.toLowerCase();
      if (normalizedCode.contains('canceled') ||
          normalizedCode.contains('cancelled') ||
          normalizedCode == GoogleSignIn.kSignInCanceledError) {
        throw const GoogleSignInCancelledException();
      }
      if (normalizedCode.contains('network') ||
          normalizedCode == GoogleSignIn.kNetworkError) {
        throw const NetworkFailure(
          'Không thể kết nối tới Google. Vui lòng kiểm tra kết nối mạng và thử lại.',
        );
      }
      AppLogger.e(
        'Google Sign-In failed',
      );
      throw AuthFailure(
        e.message?.trim().isNotEmpty == true
            ? 'Đăng nhập Google thất bại: ${e.message}'
            : 'Đăng nhập Google thất bại (${e.code}). Vui lòng kiểm tra cấu hình OAuth.',
        e.code,
      );
    } catch (_) {
      AppLogger.e(
        'Unexpected Google Sign-In error',
      );
      throw const UnknownFailure(
        'Không thể hoàn tất đăng nhập Google. Vui lòng thử lại.',
      );
    }
  }

  /// Signs out from the local Google SDK session without throwing if not signed in.
  Future<void> signOut() async {
    final client = _customGoogleSignIn ?? _lazyGoogleSignIn;
    if (client == null) return;
    try {
      await client.signOut();
    } catch (_) {
      AppLogger.d('Google SDK signOut failed');
    }
  }
}
