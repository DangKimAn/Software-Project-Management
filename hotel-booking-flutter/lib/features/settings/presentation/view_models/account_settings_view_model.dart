import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/providers.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/network/dio_client.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/view_models/auth_notifier.dart';

enum AccountSyncStatus {
  idle,
  loading,
  success,
  offline,
  error,
  unauthorized,
}

class AccountSyncState {
  final AccountSyncStatus status;
  final String? message;
  final String? errorCode;
  final User? syncedUser;

  const AccountSyncState({
    this.status = AccountSyncStatus.idle,
    this.message,
    this.errorCode,
    this.syncedUser,
  });

  bool get isLoading => status == AccountSyncStatus.loading;
  bool get isOffline => status == AccountSyncStatus.offline;
  bool get isError => status == AccountSyncStatus.error;
  bool get isUnauthorized => status == AccountSyncStatus.unauthorized;

  AccountSyncState copyWith({
    AccountSyncStatus? status,
    String? message,
    String? errorCode,
    User? syncedUser,
    bool clearMessage = false,
    bool clearSyncedUser = false,
  }) {
    return AccountSyncState(
      status: status ?? this.status,
      message: clearMessage ? null : (message ?? this.message),
      errorCode: clearMessage ? null : (errorCode ?? this.errorCode),
      syncedUser: clearSyncedUser ? null : (syncedUser ?? this.syncedUser),
    );
  }
}

/// Parses a [User] from merged `/api/auth/me` and `/api/users/me` payloads,
/// ensuring real verification flags (`isVerified`, `isEmailVerified`, `isPhoneVerified`,
/// `emailVerifiedAt`) from the backend are faithfully preserved and never hardcoded.
User parseAccountUserFromApiJson(
  Map<String, dynamic> json, {
  User? fallbackUser,
}) {
  final base = User.fromJson(json);
  final profile = json['profile'] is Map<String, dynamic>
      ? json['profile'] as Map<String, dynamic>
      : const <String, dynamic>{};

  bool? explicitVerified;
  if (json['isVerified'] is bool) {
    explicitVerified = json['isVerified'] as bool;
  } else if (profile['isVerified'] is bool) {
    explicitVerified = profile['isVerified'] as bool;
  } else if (json['isEmailVerified'] is bool ||
      json['is_email_verified'] != null ||
      json['emailVerifiedAt'] != null ||
      json['isPhoneVerified'] is bool ||
      json['is_phone_verified'] != null) {
    final emailVer = json['isEmailVerified'] == true ||
        json['is_email_verified'] == 1 ||
        json['is_email_verified'] == true ||
        (json['emailVerifiedAt'] != null &&
            json['emailVerifiedAt'].toString().trim().isNotEmpty);
    final phoneVer = json['isPhoneVerified'] == true ||
        json['is_phone_verified'] == 1 ||
        json['is_phone_verified'] == true;
    explicitVerified = emailVer || phoneVer;
  }

  final resolvedVerified =
      explicitVerified ?? (fallbackUser?.isVerified ?? base.isVerified);

  return base.copyWith(
    isVerified: resolvedVerified,
  );
}

/// Maps any thrown error or [AppFailure] into a user-safe, PII-free [AccountSyncState].
/// Never mislabels a 500 server error as an offline network failure.
AccountSyncState mapFailureToAccountSyncState(
  Object error, {
  User? existingUser,
}) {
  final AppFailure failure =
      error is AppFailure ? error : DioClient.handleError(error);

  if (failure is NetworkFailure) {
    return AccountSyncState(
      status: AccountSyncStatus.offline,
      message: failure.message.trim().isNotEmpty
          ? failure.message
          : 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng và thử lại.',
      errorCode: failure.code.isNotEmpty ? failure.code : 'NETWORK_ERROR',
      syncedUser: existingUser,
    );
  }

  if (failure is AuthFailure) {
    final code =
        (failure.code.isNotEmpty ? failure.code : 'UNAUTHORIZED').toUpperCase();
    final isForbidden =
        code == 'FORBIDDEN' || code == '403' || failure.statusCode == 403;
    return AccountSyncState(
      status: AccountSyncStatus.unauthorized,
      message: failure.message.trim().isNotEmpty
          ? failure.message
          : (isForbidden
              ? 'Bạn không có quyền truy cập tài nguyên này (403).'
              : 'Phiên đăng nhập đã hết hạn hoặc không hợp lệ (401). Vui lòng đăng nhập lại.'),
      errorCode: code,
      syncedUser: isForbidden ? existingUser : null,
    );
  }

  return AccountSyncState(
    status: AccountSyncStatus.error,
    message: failure.message.trim().isNotEmpty
        ? failure.message
        : 'Máy chủ đang gặp sự cố tạm thời. Vui lòng thử lại sau.',
    errorCode: failure.code.isNotEmpty ? failure.code : 'SERVER_ERROR',
    syncedUser: existingUser,
  );
}

class AccountSyncNotifier extends StateNotifier<AccountSyncState> {
  final Ref _ref;
  bool _isRefreshing = false;

  AccountSyncNotifier(this._ref) : super(const AccountSyncState());

  /// Synchronizes the current user's profile from `GET /api/auth/me` and `GET /api/users/me`.
  /// Preserves real server vs network vs 401/403 errors so the UI can show accurate
  /// status and a real retry button.
  Future<void> refreshProfile() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    final currentAuthUser = _ref.read(authNotifierProvider).valueOrNull;
    final previousSynced = (state.syncedUser != null &&
            currentAuthUser != null &&
            state.syncedUser!.id == currentAuthUser.id)
        ? state.syncedUser
        : currentAuthUser;

    state = AccountSyncState(
      status: AccountSyncStatus.loading,
      syncedUser: previousSynced,
    );

    try {
      final dio = _ref.read(dioClientProvider).dio;
      final authMeRes = await dio.get<Map<String, dynamic>>(
        '/api/auth/me',
        options: Options(
          extra: const <String, dynamic>{'skipAuthRefresh': false},
        ),
      );

      final authBody = authMeRes.data;
      final authData =
          (authBody?['data'] as Map<String, dynamic>?) ?? authBody ?? {};
      final authUserJson =
          (authData['user'] as Map<String, dynamic>?) ?? authData;

      Map<String, dynamic> mergedJson = <String, dynamic>{
        ...authUserJson,
      };

      try {
        final usersMeRes = await dio.get<Map<String, dynamic>>('/api/users/me');
        final usersBody = usersMeRes.data;
        final usersData =
            (usersBody?['data'] as Map<String, dynamic>?) ?? usersBody;
        if (usersData != null) {
          mergedJson = <String, dynamic>{
            ...mergedJson,
            ...usersData,
            if (usersData['user'] is Map<String, dynamic>)
              ...(usersData['user'] as Map<String, dynamic>),
          };
        }
      } on DioException catch (e) {
        final mapped = DioClient.handleError(e);
        if (mapped is AuthFailure || mapped is NetworkFailure) {
          rethrow;
        }
      }

      final parsedUser = parseAccountUserFromApiJson(
        mergedJson,
        fallbackUser: previousSynced,
      );

      if (parsedUser.id.trim().isEmpty) {
        state = const AccountSyncState(
          status: AccountSyncStatus.unauthorized,
          message: 'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.',
          errorCode: 'UNAUTHORIZED',
        );
        return;
      }

      _ref
          .read(authNotifierProvider.notifier)
          .handleSessionRefreshed(mergedJson);

      if (!mounted) return;
      state = AccountSyncState(
        status: AccountSyncStatus.success,
        syncedUser: parsedUser,
      );
    } catch (e) {
      if (!mounted) return;
      final nextState = mapFailureToAccountSyncState(
        e,
        existingUser: previousSynced,
      );
      state = nextState;
    } finally {
      _isRefreshing = false;
    }
  }

  void clearForUserSwitch() {
    if (!mounted) return;
    state = const AccountSyncState(status: AccountSyncStatus.idle);
  }

  void clearError() {
    if (!mounted) return;
    state = state.copyWith(
      status: AccountSyncStatus.idle,
      clearMessage: true,
    );
  }
}

final accountSyncNotifierProvider =
    StateNotifierProvider<AccountSyncNotifier, AccountSyncState>((ref) {
  final notifier = AccountSyncNotifier(ref);
  ref.listen<String?>(
    authNotifierProvider.select((s) => s.valueOrNull?.id),
    (previous, next) {
      if (previous != next) {
        notifier.clearForUserSwitch();
      }
    },
  );
  return notifier;
});
