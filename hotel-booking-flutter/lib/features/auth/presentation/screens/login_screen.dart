import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../app/di/providers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_semantic_icons.dart';
import '../../../../shared/widgets/app_text_field.dart';

import '../../domain/entities/user.dart';
import '../view_models/auth_notifier.dart';
import '../validation/auth_validation.dart';

/// Màn hình đăng nhập người dùng (`/dang-nhap`), hỗ trợ xác thực bằng Email/Số điện thoại kèm mật khẩu
/// hoặc đăng nhập một chạm qua Google OAuth, đồng thời điều hướng an toàn theo tham số `redirectTo`.
class LoginScreen extends ConsumerStatefulWidget {
  /// Đường dẫn nội bộ cần chuyển hướng tới sau khi đăng nhập thành công (nếu vượt qua kiểm tra an toàn).
  final String? redirectTo;

  /// Khởi tạo `LoginScreen`.
  const LoginScreen({super.key, this.redirectTo});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _resolveLoginErrorMessage(Object error) {
    if (error is AppFailure) {
      return error.message;
    }
    final raw = error.toString().replaceFirst('Exception: ', '');
    final lower = raw.toLowerCase();
    if (lower.contains('invalid credentials')) {
      return 'Email/SĐT hoặc mật khẩu không đúng.';
    }
    if (lower.contains('temporarily locked') || lower.contains('423')) {
      return 'Tài khoản tạm thời bị khóa. Vui lòng thử lại sau.';
    }
    if (lower.contains('validation error')) {
      return 'Thông tin đăng nhập không hợp lệ.';
    }
    return raw;
  }

  void _navigateAfterAuth(User user) {
    final target = AuthNotifier.resolvePostAuthRedirectPath(
      user,
      redirectTo: widget.redirectTo,
    );
    context.go(target);
  }

  // Giải thuật xử lý đăng nhập bằng mật khẩu (`_handleLogin`):
  // Kiểm tra biểu mẫu cục bộ qua `AuthValidation`, gửi yêu cầu đăng nhập tới `AuthNotifier`,
  // điều hướng theo quyền nếu thành công hoặc ánh xạ lỗi từng trường dữ liệu trả về từ máy chủ.
  Future<void> _handleLogin() async {
    if (_isLoading) return;
    setState(() {
      _errorMessage = null;
      _fieldErrors = {};
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await ref.read(authNotifierProvider.notifier).login(
            _identifierController.text.trim(),
            _passwordController.text,
          );
      if (mounted) {
        _navigateAfterAuth(user);
      }
    } catch (e) {
      if (mounted) {
        _fieldErrors = AuthValidation.fieldErrors(e);
        _formKey.currentState?.validate();
        setState(() {
          _errorMessage = _resolveLoginErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user =
          await ref.read(authNotifierProvider.notifier).signInWithGoogle();
      if (mounted) {
        _navigateAfterAuth(user);
      }
    } on GoogleSignInCancelledException {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _resolveLoginErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeL10n =
        lookupAppLocalizations(Locale(ref.watch(localeProvider)));
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: activeL10n.ctaBack,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.iconStrong),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s20,
              vertical: AppSpacing.s16,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.s24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBase,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeL10n.authWelcomeBack,
                          style: AppTypography.display
                              .copyWith(color: AppColors.textStrong),
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Text(
                          activeL10n.authLoginSubtitle,
                          style: AppTypography.body
                              .copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: AppSpacing.s24),
                        if (_errorMessage != null) ...[
                          Semantics(
                            liveRegion: true,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.s12),
                              margin:
                                  const EdgeInsets.only(bottom: AppSpacing.s16),
                              decoration: BoxDecoration(
                                color: AppColors.errorSoft,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    LucideIcons.circleAlert,
                                    color: AppColors.iconStrong,
                                    size: 20,
                                  ),
                                  const SizedBox(width: AppSpacing.s8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: AppTypography.caption
                                          .copyWith(color: AppColors.errorRed),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        AppTextField(
                          controller: _identifierController,
                          readOnly: _isLoading,
                          labelText: activeL10n.authIdentifierLabel,
                          hintText: activeL10n.authIdentifierHint,
                          prefixIcon: const Icon(
                            LucideIcons.userRound,
                            size: 20,
                            color: AppColors.iconMuted,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                            AutofillHints.telephoneNumber,
                          ],
                          onChanged: (_) {
                            if (_errorMessage != null ||
                                _fieldErrors.containsKey('identifier')) {
                              setState(() {
                                _errorMessage = null;
                                _fieldErrors.remove('identifier');
                                _formKey.currentState?.validate();
                              });
                            }
                          },
                          validator: (value) =>
                              _fieldErrors['identifier'] ??
                              AuthValidation.loginIdentifier(value),
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        AppTextField(
                          controller: _passwordController,
                          readOnly: _isLoading,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _handleLogin(),
                          labelText: activeL10n.authPasswordLabel,
                          hintText: activeL10n.authPasswordHint,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.password],
                          onChanged: (_) {
                            if (_errorMessage != null ||
                                _fieldErrors.containsKey('password')) {
                              setState(() {
                                _errorMessage = null;
                                _fieldErrors.remove('password');
                                _formKey.currentState?.validate();
                              });
                            }
                          },
                          prefixIcon: const Icon(
                            LucideIcons.lock,
                            size: 20,
                            color: AppColors.iconMuted,
                          ),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? activeL10n.authShowPasswordTooltip
                                : activeL10n.authHidePasswordTooltip,
                            constraints: const BoxConstraints(
                                minWidth: 48, minHeight: 48),
                            icon: Icon(
                              _obscurePassword
                                  ? LucideIcons.eyeOff
                                  : LucideIcons.eye,
                              size: 20,
                              color: AppColors.iconStrong,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          validator: (value) {
                            if (_fieldErrors['password'] != null) {
                              return _fieldErrors['password'];
                            }
                            if (value == null || value.trim().length < 8) {
                              return 'Mật khẩu cần ít nhất 8 ký tự';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: _isLoading
                                  ? null
                                  : () => setState(
                                        () => _rememberMe = !_rememberMe,
                                      ),
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(minHeight: 48),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        key: const Key(
                                          'login_remember_me_checkbox',
                                        ),
                                        value: _rememberMe,
                                        activeColor: AppColors.primary,
                                        onChanged: _isLoading
                                            ? null
                                            : (val) => setState(
                                                  () =>
                                                      _rememberMe = val ?? true,
                                                ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        activeL10n.authRememberMe,
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.textStrong,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.push('/quen-mat-khau'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.s8,
                                ),
                                minimumSize: const Size(48, 48),
                              ),
                              child: Text(
                                activeL10n.authForgotQuestionTitle,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textStrong,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        AppButton(
                          text: _isLoading
                              ? activeL10n.authSigningIn
                              : activeL10n.authLoginTitle,
                          isLoading: _isLoading,
                          icon: const Icon(
                            LucideIcons.arrowRight,
                            size: 18,
                            color: Colors.white,
                          ),
                          onPressed: _handleLogin,
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                activeL10n.authOrDivider,
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.textMuted),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        AppButton.secondary(
                          text: activeL10n.authGoogleLoginBtn,
                          icon: const AppBrandIcon.googleLogo(size: 20),
                          onPressed: _isLoading ? null : _handleGoogleLogin,
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                activeL10n.authNoAccountYet,
                                style: AppTypography.body
                                    .copyWith(color: AppColors.textMuted),
                              ),
                              TextButton(
                                onPressed: () {
                                  final redirect = widget.redirectTo?.trim();
                                  if (redirect != null &&
                                      AuthNotifier.isSafeRedirectPath(
                                          redirect)) {
                                    context.push(
                                      Uri(
                                        path: '/dang-ky',
                                        queryParameters: <String, String>{
                                          'redirectTo': redirect,
                                        },
                                      ).toString(),
                                    );
                                  } else {
                                    context.push('/dang-ky');
                                  }
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  minimumSize: const Size(48, 48),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  activeL10n.authRegisterBtn,
                                  style: AppTypography.body.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
