import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/logging/app_logger.dart';

/// Ngoại lệ ném ra khi người dùng chủ động đóng hộp thoại chọn tài khoản Google mà không đăng nhập.
class GoogleSignInCancelledException implements Exception {
  /// Thông báo mô tả thao tác hủy đăng nhập Google.
  final String message;

  /// Mã định danh lỗi nội bộ (`'GOOGLE_SIGN_IN_CANCELLED'`).
  final String code;

  /// Khởi tạo `GoogleSignInCancelledException`.
  const GoogleSignInCancelledException([
    this.message = 'Đã hủy đăng nhập Google.',
  ]) : code = 'GOOGLE_SIGN_IN_CANCELLED';

  @override
  String toString() => message;
}

/// Dịch vụ tích hợp Google Sign-In SDK chính thức trên Android, iOS và Flutter Web.
///
/// Thu thập chuỗi định danh OpenID Connect `idToken` đã ký số từ Google Identity SDK
/// để trao đổi lấy phiên xác thực hệ thống tại điểm cuối `POST /api/auth/google`.
class GoogleAuthService {
  final GoogleSignIn? _customGoogleSignIn;
  final bool _enforceConfigGuard;
  GoogleSignIn? _lazyGoogleSignIn;

  /// Khởi tạo `GoogleAuthService`, cho phép truyền đối tượng `googleSignIn` giả lập khi kiểm thử.
  GoogleAuthService({
    GoogleSignIn? googleSignIn,
    bool? enforceConfigGuard,
  })  : _customGoogleSignIn = googleSignIn,
        _enforceConfigGuard = enforceConfigGuard ?? (googleSignIn == null);

  // Giải thuật khởi tạo lười (`lazy`) đối tượng `GoogleSignIn` phù hợp từng nền tảng:
  // - Trên Web: truyền `clientId` của ứng dụng Web OAuth.
  // - Trên iOS/macOS: kết hợp `iosClientId` và `serverClientId`.
  // - Trên Android: truyền `serverClientId` (Web OAuth 2.0 Client ID) để Google Play Services phát hành `idToken`
  //   khớp trường `audience` khi máy chủ Backend xác thực chữ ký.
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

  /// Mở luồng đăng nhập Google tương tác và trả về chuỗi `idToken` khác rỗng sẵn sàng gửi tới `POST /api/auth/google`.
  ///
  /// Ném `ValidationFailure` nếu thiếu biến môi trường cấu hình OAuth, `GoogleSignInCancelledException`
  /// nếu người dùng tự đóng hộp thoại, hoặc `AuthFailure` / `NetworkFailure` tương ứng với mã lỗi nền tảng (như lỗi SHA-1 mã `10`).
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
      final rawMessage = e.message?.trim() ?? '';
      if (rawMessage.contains('ApiException: 10') ||
          rawMessage.contains(': 10:') ||
          e.code == '10') {
        throw const AuthFailure(
          'Đăng nhập Google thất bại (ApiException 10: DEVELOPER_ERROR). '
              'Chưa đăng ký SHA-1 fingerprint hoặc sai Package Name trên Google Cloud Console.',
          'GOOGLE_DEVELOPER_ERROR_10',
        );
      }
      AppLogger.e(
        'Google Sign-In failed',
      );
      throw AuthFailure(
        rawMessage.isNotEmpty
            ? 'Đăng nhập Google thất bại: $rawMessage'
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

  /// Đăng xuất khỏi phiên đệm cục bộ của Google SDK một cách an toàn mà không ném ngoại lệ nếu chưa đăng nhập.
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
